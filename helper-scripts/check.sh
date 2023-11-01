. /etc/kolla/admin-openrc.sh
openstack volume service list
openstack compute service list
openstack coe service list
openstack hypervisor stats show
openstack hypervisor list

ansible -i multinode -m shell -a 'uptime' all
ansible -i multinode -m shell -a 'docker ps -a' all
ansible -i multinode -m shell -a 'docker ps -a  | grep Exited' all
ansible -i multinode -m shell -a 'docker image ls' all

# on control node (e.g. ssh control01)
docker exec -it openvswitch_vswitchd /bin/bash
ovs-vsctl show