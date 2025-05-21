# source information about kolla-ansible
source ~/env.sh

# get subnet id of external network
EXT_SUBNET=$(openstack network show $EXT_NET -f value -c subnets | awk -F \' '{print $2}')

# see https://docs.openstack.org/kolla-ansible/yoga/reference/networking/octavia.html for more information
kolla_mod="octavia"
tags="common,horizon,octavia,neutron"
option="--tags"

#Download kolla docker container
time sh ~/deploy-scripts/download-svc.sh $option $kolla_mod

. $HOME/activate.sh
. /etc/kolla/admin-openrc.sh

# Enable Redis for Bobcat 2023.2 or higher
# Octavia requires Redis for the jobboard being enabled, which is default as of Kolla-Ansible 2023.2
# Alternatively, the octavia jobboard can be disabled in the globals.yml
# https://docs.openstack.org/octavia/latest/install/install-amphorav2.html
# enable_octavia_jobboard: "no"
# see: https://bugs.launchpad.net/kolla-ansible/+bug/2046382

# Enable Redis if the release is 2023.2 or higher
if [[ $(echo -e "$release\n2023.2" | sort -V | head -n1) == "2023.2" ]]; then
    sed -i 's/#enable_redis:.*/enable_redis: "yes"/' /etc/kolla/globals.yml
    tags="common,horizon,octavia,neutron,redis"
    kolla_mod2="redis"
    # Download kolla docker container
    time sh ~/deploy-scripts/download-svc.sh $option $kolla_mod2
fi

#Modify octavia.yml
if [ $release = "yoga" ]; then
    sed -e '/octavia_provider_drivers: "amphora:Amphora provider"/ s/^#*/#/' -i /etc/kolla/globals.d/octavia.yml
fi

echo "Generating Octavia certificates..."
kolla-ansible octavia-certificates

# Configure neutron
echo "Configuring neutron..."

if [ "$network_vlan_ranges" = "0" ]; then
    test -d /etc/kolla/config/neutron || mkdir /etc/kolla/config/neutron
    cat > /etc/kolla/config/neutron/ml2_conf.ini << EOF
[ml2_type_flat]
# we need two when using flat networks
flat_networks = physnet1,physnet2
EOF
    sed -i 's/#provider_network_type:.*/provider_network_type: flat/' /etc/kolla/globals.d/octavia.yml
    sed -i 's/#provider_physical_network:.*/provider_physical_network: physnet2/' /etc/kolla/globals.d/octavia.yml
    sed -i 's/provider_segmentation_id:.*/#provider_segmentation_id: "'"${octavia_vlan}"'"/' /etc/kolla/globals.d/octavia.yml
else
    test -d /etc/kolla/config/neutron || mkdir /etc/kolla/config/neutron
    cat > /etc/kolla/config/neutron/ml2_conf.ini << EOF
[ml2_type_vlan]
network_vlan_ranges = $network_vlan_ranges
EOF
    sed -i 's/#provider_network_type:.*/provider_network_type: vlan/' /etc/kolla/globals.d/octavia.yml
    sed -i 's/#provider_physical_network:.*/provider_physical_network: physnet1/' /etc/kolla/globals.d/octavia.yml
    sed -i 's/#provider_segmentation_id:.*/provider_segmentation_id: "'"${octavia_vlan}"'"/' /etc/kolla/globals.d/octavia.yml
fi

echo "Deploying Octavia..."
time sh ~/deploy-scripts/deploy-svc.sh $kolla_mod $tags

#Install Openstack Octavia CLI client
pip install python-octaviaclient

echo "Creating the amphora image..."
echo "Installing Epel repos..."
sudo dnf -y install epel-release
echo "Installing prerequisites..."
sudo dnf install -y debootstrap qemu-img git e2fsprogs policycoreutils-python-utils
echo "Cloning the Octavia git repo..."
git clone https://opendev.org/openstack/octavia -b stable/${release}
echo "Installing diskimage-builder, in a virtual environment..."
python3 -m venv dib-venv
source dib-venv/bin/activate
pip install diskimage-builder
echo "Building the amphora image..."
cd octavia/diskimage-create
./diskimage-create.sh
deactivate
echo "Executing post-deploy..."
cd
. $HOME/activate.sh
kolla-ansible post-deploy
echo "Sourcing octavia user openrc..."
. /etc/kolla/octavia-openrc.sh
echo "Registering amphora image in glance..."
# Uncomment below for raw image conversion if using Ceph as glance backend
#qemu-img convert ./octavia/diskimage-create/amphora-x64-haproxy.qcow2 amphora-x64-haproxy.raw
#openstack image create amphora-x64-haproxy.raw --container-format bare --disk-format raw --private --tag amphora --file ./octavia/diskimage-create/amphora-x64-haproxy.raw --property hw_architecture='x86_64' --property hw_rng_model=virtio
openstack image create amphora-x64-haproxy.qcow2 --container-format bare --disk-format qcow2 --private --tag amphora --file ./octavia/diskimage-create/amphora-x64-haproxy.qcow2 --property hw_architecture='x86_64' --property hw_rng_model=virtio --progress

cat > readme_octavia.txt << EOF

In order to interact with the OpenStack cluster, first run activate.sh and then authenticate:

source ./activate.sh
. /etc/kolla/admin-openrc.sh

To create a loadbalancer run:

openstack loadbalancer create --name lb1 --vip-subnet-id ${EXT_SUBNET}

You can watch the status by running:

openstack loadbalancer list

To see the status of the amphora instance run:

openstack loadbalancer amphora list

To further debug problems you can ssh to one of the control nodes:

ssh control01

Check the octavia logs:

sudo -i
cd /var/log/kolla/octavia

or SSH directly to an amphora instance

ssh -i /etc/kolla/octavia-worker/octavia_ssh_key ubuntu@<amphora_ip>

To delete the loadbalancer run:

openstack loadbalancer delete lb1

If it has children:

openstack loadbalancer delete lb1 --cascade

If it failed deleting:

get octavia mariadb password:

grep octavia_database_password /etc/kolla/passwords.yml

ssh to one of the controller nodes

ssh control01

Switch to the container

sudo docker exec -ti mariadb mysql -u octavia -p octavia

update load_balancer set provisioning_status = 'ERROR' where provisioning_status = 'PENDING_CREATE';
update load_balancer set provisioning_status = 'ERROR' where provisioning_status = 'PENDING_DELETE';
exit;

Now delete the loadbalancer:

openstack loadbalancer delete lb1

EOF

cat readme_octavia.txt

echo "To see this info again, check out readme_octavia.txt."
