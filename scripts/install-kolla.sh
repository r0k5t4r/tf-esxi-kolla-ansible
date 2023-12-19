cd
# source information about kolla-ansible
source ~/env.sh

#Install dependencies
sudo dnf install -y python3-devel libffi-devel gcc openssl-devel python3-libselinux

#Install git
sudo dnf install -y git

#Install Python 3.9
sudo dnf install -y python39

#Install sshpass
sudo dnf install -y sshpass

#Create a virtual environment and activate it
python3 -m venv $${virtdir}

source $${virtdir}/bin/activate

#ensure latest version of pip is installed
pip install -U pip

#Install Ansible. Kolla Ansible requires at least Ansible 4 and supports up to 8 with Antelope 2023.1.
case $release in
  2023.1)
  pip install 'ansible>=6,<8'
  ;;
  *)
  pip install 'ansible>=4,<6'
  ;;
esac

#Install Kolla-ansible for deployment or evaluation. If using a virtual environment:
pip install git+https://opendev.org/openstack/kolla-ansible@stable/$${release}

#Create the /etc/kolla directory.
sudo mkdir -p /etc/kolla
sudo chown -R $${USER}:$${USER} /etc/kolla

#Copy globals.yml and passwords.yml to /etc/kolla directory.If using a virtual environment:
cp -r $${virtdir}/share/kolla-ansible/etc_examples/kolla/* /etc/kolla

#Copy all-in-one and multinode inventory files to the current directory. If using a virtual environment:
cp $${virtdir}/share/kolla-ansible/ansible/inventory/* .

#For all-in-one scenario in virtual environment add the following to the very beginning of the inventory:
sed -i "1 i\localhost ansible_python_interpreter=python3" all-in-one

#Install Ansible Galaxy dependencies (Yoga release onwards):
kolla-ansible install-deps

# ansible cfg has to be created from scratch when using pip!!!#
cat > ~/ansible.cfg << EOF
[defaults]
host_key_checking=False
pipelining=True
forks=100
timeout=40
log_path=ansible.log
EOF

#sed -i 's/^#kolla_base_distro:.*/kolla_base_distro: "centos"/g' /etc/kolla/globals.yml
sed -i 's/^#kolla_base_distro:.*/kolla_base_distro: "${kolla_base_distro}"/g' /etc/kolla/globals.yml
sed -i 's/^#kolla_install_type:.*/kolla_install_type: "source"/g' /etc/kolla/globals.yml
sed -i 's/^#kolla_internal_vip_address:.*/kolla_internal_vip_address: "${kolla_internal_vip_address}"/g' /etc/kolla/globals.yml
sed -i 's/^#kolla_external_vip_address:.*/kolla_external_vip_address: "${kolla_external_vip_address}"/g' /etc/kolla/globals.yml
sed -i 's/^#network_interface:.*/network_interface: "${network_interface}"/g' /etc/kolla/globals.yml
sed -i 's/^#neutron_external_interface:.*/neutron_external_interface: "${neutron_external_interface}"/g' /etc/kolla/globals.yml

# enable RabbitMQ HA see: https://docs.openstack.org/kolla-ansible/2023.1/reference/message-queues/rabbitmq.html for more info
echo om_enable_rabbitmq_high_availability: "${om_enable_rabbitmq_high_availability}" >> /etc/kolla/globals.yml

# We need two bridges for octavia when using flat networking
if [ $network_vlan_ranges = 0 ]; then
  grep neutron_bridge_name /etc/kolla/globals.yml || echo neutron_bridge_name: "br-ex1,br-ex2" >> /etc/kolla/globals.yml
else
  grep neutron_bridge_name /etc/kolla/globals.yml || echo neutron_bridge_name: "br-ex1" >> /etc/kolla/globals.yml
fi
sed -i 's/^#enable_haproxy:.*/enable_haproxy: "${enable_haproxy}"/g' /etc/kolla/globals.yml
sed -i 's/^#openstack_release:.*/openstack_release: "'"$${release}"'"/g' /etc/kolla/globals.yml
sed -i 's/^#enable_neutron_provider_networks:.*/enable_neutron_provider_networks: "${enable_neutron_provider_networks}"/g' /etc/kolla/globals.yml
sed -i 's/^#enable_neutron_dvr:.*/enable_neutron_dvr: "${enable_neutron_dvr}"/g' /etc/kolla/globals.yml

#Enable central logging
sed -i 's/^#enable_central_logging:.*/enable_central_logging: "yes"/g' /etc/kolla/globals.yml
sed -i 's/^#enable_elasticsearch_curator:.*/enable_elasticsearch_curator: "yes"/g' /etc/kolla/globals.yml

#Enable Grafana and Prometheus
sed -i 's/^#enable_grafana:.*/enable_grafana: "yes"/g' /etc/kolla/globals.yml
sed -i 's/^#enable_prometheus:.*/enable_prometheus: "yes"/g' /etc/kolla/globals.yml

#Enable Cinder
sed -i 's/^#enable_cinder:.*/enable_cinder: "${enable_cinder}"/g' /etc/kolla/globals.yml

#Enable Cinder NFS Backend
sed -i 's/^#enable_cinder_backend_nfs:.*/enable_cinder_backend_nfs: "${enable_cinder_backend_nfs}"/g' /etc/kolla/globals.yml

#Create nfs_shares file. In this file you can define the nfs exports that shall be mounted
mkdir -p /etc/kolla/config/cinder
cat > /etc/kolla/config/cinder/nfs_shares << EOF
#HOST:SHARE
#192.168.2.2:/odroidxu4/openstack_volumes -o nfsvers=3
${cinder_nfs_share}
EOF

#Create ml2_conf.ini file. In this file you can define the vlan ranges for the neutron_external_interface
#if [ -z ${network_vlan_ranges} ]; then
if [ $network_vlan_ranges = 0 ]; then
  echo "’network_vlan_ranges’ variable is not set"
else
  echo "’network_vlan_ranges is set and the value of network_vlan_ranges=$network_vlan_ranges"
  mkdir -p /etc/kolla/config/neutron
  cat > /etc/kolla/config/neutron/ml2_conf.ini << EOF
[ml2_type_vlan]
network_vlan_ranges = ${network_vlan_ranges}
EOF
fi

#Enable Cinder Backup NFS Backend
sed -i 's/^#cinder_backup_driver:.*/cinder_backup_driver: "nfs"/g' /etc/kolla/globals.yml
sed -i 's?^#cinder_backup_share:.*?cinder_backup_share: "${cinder_nfs_bkp_share}"?g' /etc/kolla/globals.yml
sed -i 's/^#cinder_backup_mount_options_nfs:.*/cinder_backup_mount_options_nfs: "vers=3"/g' /etc/kolla/globals.yml

#Enable Magnum - Container Orchestration Engine
#sed -i 's/^#enable_magnum:.*/enable_magnum: "yes"/g' /etc/kolla/globals.yml

#Create magnum.conf file. In this file you can define additional settings for Magnum
#cat > /etc/kolla/config/magnum.conf << EOF
#[trust]
#cluster_user_trust = True
#EOF

#Display globals.yml settings
grep ^[^#] /etc/kolla/globals.yml

# docker install script doesn't work on Rocky
# ERROR: Unsupported distribution 'rocky'
#curl -sSL https://get.docker.io | sudo bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
cat << EOF | sudo tee -a /etc/docker/daemon.json
{
    "bridge": "none",
    "default-ulimits": {
        "nofile": {
            "hard": 1048576,
            "name": "nofile",
            "soft": 1048576
        }
    },
    "insecure-registries": [
        "${docker_registry_kolla}"
    ],
    "ip-forward": false,
    "iptables": false
}
EOF
# we need to install docker version < 23.x for ZUN to work
#sudo dnf install -y python3-dnf-plugin-versionlock
#sudo dnf -y install docker-ce-20.10.23-3.el8.x86_64 docker-ce-cli-20.10.23-3.el8.x86_64 containerd.io docker-compose-plugin
#sudo dnf versionlock docker-ce-20.10.23-3.el8.x86_64 docker-ce-cli-20.10.23-3.el8.x86_64 containerd.io docker-compose-plugin
sudo systemctl --now enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker
if [ $deploy_local_registry = true ]; then
  sudo mkdir -p /var/lib/registry
  sudo docker run -d \
  --name registry \
  --restart=always \
  -p 4000:5000 \
  -v registry:/var/lib/registry \
  registry:2
fi

#kolla-ansible -i all-in-one pull

# create script to pull kolla docker images to central docker registry
cat > ~/pull_kolla_docker_img.sh << EOF
REGISTRY="${docker_registry_kolla}"
option="$${1}"
kolla_mod="$${2}"
echo "Disabling local docker registry in /etc/kolla/globals.yml..."
sed -i 's/^docker_registry:.*/#docker_registry: "${docker_registry_kolla}"/g' /etc/kolla/globals.yml
sed -i 's/^docker_registry_insecure:.*/#docker_registry_insecure: yes/g' /etc/kolla/globals.yml
echo "Pulling Kolla-Ansible containers to localhost..."
. ./activate.sh
kolla-ansible -i all-in-one pull $option $kolla_mod
echo "Enabling local docker registry in /etc/kolla/globals.yml..."
sed -i 's/^#docker_registry:.*/docker_registry: "${docker_registry_kolla}"/g' /etc/kolla/globals.yml
sed -i 's/^#docker_registry_insecure:.*/docker_registry_insecure: yes/g' /etc/kolla/globals.yml
echo "All done. Now run sudo sh -v push_docker_img.sh in order to push the docker images to the local docker registry."
EOF

# install docker dependencies
sudo pip3 install docker

# pull docker images if local registry is deployed or pull_local_registry is set to true.
if [ $deploy_local_registry = true ] || [ $pull_local_registry = true ]; then
  sh -v pull_kolla_docker_img.sh
fi

# create script to push docker images to central docker registry and execute
cat > ~/push_docker_img.sh << EOF
docker images | grep kolla | grep -v local | awk '{print \$1,\$2}' | while read -r image tag; do
          newimg=\`echo \$${image} | cut -d / -f2-\`
          docker tag \$${image}:\$${tag} ${docker_registry_kolla}/\$${newimg}:\$${tag}
          docker push ${docker_registry_kolla}/\$${newimg}:\$${tag}
done
EOF

# push docker images to local registry if local registry is deployed or pull_local_registry is set to true.
if [ $deploy_local_registry = true ] || [ $pull_local_registry = true ]; then
  sudo sh push_docker_img.sh
  # show images pushed to local docker registry
  curl -X GET http://${docker_registry_magnum}/v2/_catalog | python3 -m json.tool
fi

cp /home/vagrant/$deployment.mod ~/$deployment

#try to ping all nodes
ansible -i $deployment all -m ping

#install and configure chrony
ansible -i $deployment all -m shell -a "systemctl enable chronyd; systemctl restart chronyd" -b

# versionlock docker version 20.x
# see https://www.roksblog.de/kolla-ansible-zun-and-kuryr-container/ for more information
#ansible -i $deployment all -m shell -a "dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo" -b
#ansible -i $deployment all -m shell -a "ver="el$(grep '^VERSION_ID' /etc/os-release | awk -F'=' ' gsub(/"/,"") { print $2}' | cut -d . -f1)";dnf install -y python3-dnf-plugin-versionlock; dnf -y remove docker-buildx-plugin; dnf -y install docker-ce-20.10.23-3.$ver.x86_64 docker-ce-cli-20.10.23-3.$ver.x86_64 docker-ce-rootless-extras-20.10.23-3.$ver.x86_64;dnf versionlock docker-ce-20.10.23-3.$ver.x86_64 docker-ce-cli-20.10.23-3.$ver.x86_64 docker-ce-rootless-extras-20.10.23-3.$ver.x86_64 containerd.io docker-compose-plugin" -b
#echo 'docker_apt_package_pin: "5:20.*"' >> /etc/kolla/globals.yml
#echo 'docker_yum_package_pin: "20.*"' >> /etc/kolla/globals.yml