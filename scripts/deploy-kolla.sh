cd
# source information about kolla-ansible
source ~/env.sh

source $${virtdir}/bin/activate

#generate kolla passwords
kolla-genpwd

#bootstrap servers
time kolla-ansible -i ./$deployment bootstrap-servers
pip3 install docker

#run prechecks
time kolla-ansible -i ./$deployment prechecks

#deploy openstack
time kolla-ansible -i ./$deployment deploy

#install openstack client
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/${release}

#run post-deploy tasks
time kolla-ansible post-deploy

# Copy, the init-runonce script:
cp $${virtdir}/share/kolla-ansible/init-runonce .

#Modify it to fit your local flat network
sed -i "s?10.0.2.0/24?${neutron_ext_net_cidr}?g" init-runonce
sed -i "s?start=10.0.2.150,end=10.0.2.199?start=${neutron_ext_net_range_start},end=${neutron_ext_net_range_end}?g" init-runonce
sed -i "s?10.0.2.1?${neutron_ext_net_gw}?g" init-runonce
#change DNS of subnet demo-network
sed -i "s?8.8.8.8?${neutron_ext_net_dns}?g" init-runonce

#source credentials
. /etc/kolla/admin-openrc.sh

#Check if external VLANs are set. If yes, do not create the public network from the init-runonce script.
if [ $network_vlan_ranges = 0 ]; then
  echo "’network_vlan_ranges’ variable is not set. creating external network from init-runonce script"
  #EXT_NET="public1"
  EXT_NET="${EXT_NET}"
else
  echo "’network_vlan_ranges’ variable is set. not creating external network from init-runonce script"
  export ENABLE_EXT_NET=0
  #for net in $(echo $network_vlan_ranges | tr , '\n')
  # for now we will only create the first network listed in network_vlan_ranges. If multiple networks should be created we need to have a hash variable, so that for each network
  # we also have a corresponding gw, range start end etc.
  for net in $(echo $network_vlan_ranges | awk -F, '{print $1}')
  do
  network=$(echo $net | awk -F: '{print $1}')
  echo $network
  vlan=$(echo $net | awk -F: '{print $2}')
  echo $vlan
  EXT_NET_RANGE=start=${neutron_ext_net_range_start},end=${neutron_ext_net_range_end}
  sed -i "s?start=10.0.2.150,end=10.0.2.199?start=${neutron_ext_net_range_start},end=${neutron_ext_net_range_end}?g" init-runonce
  EXT_NET="public-vlan-$vlan"
  EXT_SUBNET="public-vlan-$vlan-subnet"
  #echo EXT_NET="public-vlan-$vlan" >> ~/env.sh
  echo EXT_SUBNET="public-vlan-$vlan-subnet" >> ~/env.sh
  echo openstack network create --external --provider-physical-network $network --provider-network-type vlan --provider-segment $vlan $EXT_NET
  openstack network create --external --provider-physical-network $network --provider-network-type vlan --provider-segment $vlan $EXT_NET
  echo openstack subnet create --no-dhcp --allocation-pool $${EXT_NET_RANGE} --network public-vlan-$vlan --subnet-range ${neutron_ext_net_cidr} --gateway ${neutron_ext_net_gw} $EXT_SUBNET --dns-nameserver ${neutron_ext_net_dns}
  openstack subnet create --no-dhcp --allocation-pool $${EXT_NET_RANGE} --network public-vlan-$vlan --subnet-range ${neutron_ext_net_cidr} --gateway ${neutron_ext_net_gw} $EXT_SUBNET --dns-nameserver ${neutron_ext_net_dns}
  done
  
fi

#Run it
./init-runonce

#Set external gateway of router
if [ $network_vlan_ranges != 0 ]; then
  echo openstack router set --external-gateway $EXT_NET demo-router > network_diag.txt
  openstack router set --external-gateway $EXT_NET demo-router
fi

cat > readme.txt << EOF

In order to interact with the OpenStack cluster, first run activate.sh and then authenticate:

source ./activate.sh
. /etc/kolla/admin-openrc.sh

To check if Nova compute service is up and running run:

openstack compute service list

To show the status of all compute nodes run:

openstack hypervisor list

To deploy a demo instance, run:

openstack server create \\
    --image cirros \\
    --flavor m1.tiny \\
    --key-name mykey \\
    --network demo-net \\
    demo1

To show running instances run:

openstack server list --long

To show console of instance run:

openstack console log show demo1 | tail -40

To show some usage stats run:

openstack hypervisor stats show

To create a floating IP run:

openstack floating ip create $EXT_NET

To show all floating IPs run:

openstack floating ip list

To attach a floating IP to your instance run:

openstack server add floating ip demo1 \$(openstack floating ip list -f value -c "Floating IP Address")

To deploy additional services like Magnum, Octavia etc. take a look in folder deploy-scripts.

For example to deploy Magnum simply run:

sh deploy-scripts/deploy-magnum.sh

EOF

cat readme.txt

echo "To see this info again, check out readme.txt."