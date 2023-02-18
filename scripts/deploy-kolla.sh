#todo
#pub_ip var not working
#/etc/hosts entry must point to 192.168.20.221

# the deployment variable can be either multinode or all-in-one, by default it is all-in-one
cd
deployment="${deployment}"
release="${release}"
virtdir="./$${release}"
network_vlan_ranges="${network_vlan_ranges}"

source $${virtdir}/bin/activate

#generate kolla passwords
kolla-genpwd

#bootstrap servers
time kolla-ansible -i ./$deployment bootstrap-servers
pip3 install docker

# fix /etc/hosts file
#echo 192.168.20.221 seed.fritz.box seed >> /etc/hosts

#run prechecks
time kolla-ansible -i ./$deployment prechecks

#deploy openstack
time kolla-ansible -i ./$deployment deploy

#install openstack cli client
#pip install python-openstackclient

#for ZED
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/${release}

#run post-deploy tasks
time kolla-ansible post-deploy

# Copy, the init-runonce script:
cp $${virtdir}/share/kolla-ansible/init-runonce .

#Modify it to fit your local flat network
#sed -i 's?10.0.2.?"${neutron_ext_net_cidr}"?g' init-runonce
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
  EXT_NET="public1"
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
  echo openstack network create --external --provider-physical-network $network --provider-network-type vlan --provider-segment $vlan public-vlan-$vlan
  openstack network create --external --provider-physical-network $network --provider-network-type vlan --provider-segment $vlan public-vlan-$vlan
  echo openstack subnet create --no-dhcp --allocation-pool $${EXT_NET_RANGE} --network public-vlan-$vlan --subnet-range ${neutron_ext_net_cidr} --gateway ${neutron_ext_net_gw} public-vlan-$vlan-subnet --dns-nameserver ${neutron_ext_net_dns}
  openstack subnet create --no-dhcp --allocation-pool $${EXT_NET_RANGE} --network public-vlan-$vlan --subnet-range ${neutron_ext_net_cidr} --gateway ${neutron_ext_net_gw} public-vlan-$vlan-subnet --dns-nameserver ${neutron_ext_net_dns}
  done
  EXT_NET="public-vlan-$vlan"
  echo openstack router set --external-gateway $EXT_NET demo-router > network_diag.txt
  openstack router set --external-gateway $EXT_NET demo-router
fi

#Run it
./init-runonce

#Download Fedora CoreOS images
#Fedora Coreos 35
#old version doesn't work with local registry and insecure_registry parameter
#curl -k0 https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20211119.3.0/x86_64/fedora-coreos-35.20211119.3.0-openstack.x86_64.qcow2.xz -o fedora-coreos-35.20211119.3.0-openstack.x86_64.qcow2.xz
#unxz fedora-coreos-35.20211119.3.0-openstack.x86_64.qcow2.xz

curl -k0 https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/35.20220424.3.0/x86_64/fedora-coreos-35.20220424.3.0-openstack.x86_64.qcow2.xz -o fedora-coreos-35.20220424.3.0-openstack.x86_64.qcow2.xz
unxz fedora-coreos-35.20220424.3.0-openstack.x86_64.qcow2.xz

#Fedora Coreos 37
curl -k0 https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/37.20221127.3.0/x86_64/fedora-coreos-37.20221127.3.0-openstack.x86_64.qcow2.xz -o fedora-coreos-37.20221127.3.0-openstack.x86_64.qcow2.xz
unxz fedora-coreos-37.20221127.3.0-openstack.x86_64.qcow2.xz

#Upload Fedora Core OS image to glance
openstack image create Fedora-CoreOS-35 \
--public \
--disk-format=qcow2 \
--container-format=bare \
--property os_distro='fedora-coreos' \
--file=fedora-coreos-35.20220424.3.0-openstack.x86_64.qcow2

openstack image create Fedora-CoreOS-37 \
--public \
--disk-format=qcow2 \
--container-format=bare \
--property os_distro='fedora-coreos' \
--file=fedora-coreos-37.20221127.3.0-openstack.x86_64.qcow2

#Create Flavor to use with K8s
openstack flavor create m1.kubernetes.small \
--disk 10 \
--vcpu 1 \
--ram 2048 \
--public \
--description "kubernetes small flavor"

#Install Openstack Magnum CLI client
pip install python-magnumclient python-octaviaclient python-heatclient

#Create cluster template
openstack coe cluster template create k8s-flan-small-35 \
--image Fedora-CoreOS-35 \
--keypair mykey \
--external-network $${EXT_NET} \
--fixed-network demo-net \
--fixed-subnet demo-subnet \
--dns-nameserver ${neutron_ext_net_dns} \
--flavor m1.kubernetes.small \
--master-flavor m1.kubernetes.small \
--volume-driver cinder \
--docker-volume-size 5 \
--network-driver flannel \
--docker-storage-driver overlay2 \
--coe kubernetes \
--labels csi_snapshotter_tag=v4.0.1

#Create cluster template with k8s version 1.21.11
openstack coe cluster template create k8s-flan-small-35-1.21.11 \
--image Fedora-CoreOS-35 \
--keypair mykey \
--external-network $${EXT_NET} \
--fixed-network demo-net \
--fixed-subnet demo-subnet \
--dns-nameserver ${neutron_ext_net_dns} \
--flavor m1.kubernetes.small \
--master-flavor m1.kubernetes.small \
--volume-driver cinder \
--docker-volume-size 10 \
--network-driver flannel \
--docker-storage-driver overlay2 \
--coe kubernetes \
--labels kube_tag=v1.21.11-rancher1,hyperkube_prefix=docker.io/rancher/,csi_snapshotter_tag=v4.0.1

#Create cluster template with k8s and containerd CRI
openstack coe cluster template create k8s-flan-small-containerd \
--image Fedora-CoreOS-35 \
--keypair mykey \
--external-network $${EXT_NET} \
--fixed-network demo-net \
--fixed-subnet demo-subnet \
--dns-nameserver ${neutron_ext_net_dns} \
--flavor m1.kubernetes.small \
--master-flavor m1.kubernetes.small \
--volume-driver cinder \
--docker-volume-size 10 \
--network-driver flannel \
--docker-storage-driver overlay2 \
--coe kubernetes \
--labels container_runtime=containerd,csi_snapshotter_tag=v4.0.1

#Create cluster template using local docker registry
openstack coe cluster template create k8s-flan-small-35-local-reg \
--image Fedora-CoreOS-35 \
--keypair mykey \
--external-network $${EXT_NET} \
--fixed-network demo-net \
--fixed-subnet demo-subnet \
--dns-nameserver ${neutron_ext_net_dns} \
--flavor m1.kubernetes.small \
--master-flavor m1.kubernetes.small \
--volume-driver cinder \
--docker-volume-size 5 \
--network-driver flannel \
--docker-storage-driver overlay2 \
--coe kubernetes \
--labels container_infra_prefix=${docker_registry_magnum}/,csi_snapshotter_tag=v4.0.1

#Create cluster template
openstack coe cluster template create k8s-flan-small-37 \
--image Fedora-CoreOS-37 \
--keypair mykey \
--external-network $${EXT_NET} \
--fixed-network demo-net \
--fixed-subnet demo-subnet \
--dns-nameserver ${neutron_ext_net_dns} \
--flavor m1.kubernetes.small \
--master-flavor m1.kubernetes.small \
--volume-driver cinder \
--docker-volume-size 5 \
--network-driver flannel \
--docker-storage-driver overlay2 \
--coe kubernetes \
--labels csi_snapshotter_tag=v4.0.1

#Create cluster template using local docker registry
openstack coe cluster template create k8s-flan-small-37-local-reg \
--image Fedora-CoreOS-37 \
--keypair mykey \
--external-network $${EXT_NET} \
--fixed-network demo-net \
--fixed-subnet demo-subnet \
--dns-nameserver ${neutron_ext_net_dns} \
--flavor m1.kubernetes.small \
--master-flavor m1.kubernetes.small \
--volume-driver cinder \
--docker-volume-size 5 \
--network-driver flannel \
--docker-storage-driver overlay2 \
--coe kubernetes \
--labels container_infra_prefix=${docker_registry_magnum}/,csi_snapshotter_tag=v4.0.1

cat | tee -a readme.txt <<EOF

In order to interact with the OpenStack cluster, first run activate.sh and then authenticate:

source ./activate.sh
. /etc/kolla/admin-openrc.sh

To deploy a demo instance, run:

openstack server create \\
    --image cirros \\
    --flavor m1.tiny \\
    --key-name mykey \\
    --network demo-net \\
    demo1

To deploy demo K8s clusters, run:

+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
!!! Currently there is no way to set the insecure_registry parameter via the OpenStack Client so please adjust it in the Magnum cluster templates using the Horizon WebUI before running the commands below !!! 
Please use only the IP and port when specifying the insecure registry: <IP_of_container_registry>:<port> e.g. 192.168.2.2:4000
+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

To deploy a demo K8s cluster based on Fedora CoreOS 35 with 2 nodes and 1 master, run:

openstack coe cluster create \\
    --cluster-template k8s-flan-small-35 \\
    --master-count 1 \\
    --node-count 2 \\
    --keypair mykey \\
    k8s-flannel-small-35

To deploy a demo K8s v1.21.11 cluster based on Fedora CoreOS 35 with 2 nodes and 1 master, run:

openstack coe cluster create \\
    --cluster-template k8s-flan-small-35-1.21.11 \\
    --master-count 1 \\
    --node-count 2 \\
    --keypair mykey \\
    k8s-flannel-small-35-1.21.11

To deploy a demo K8s cluster based on Fedora CoreOS 35 with 2 nodes and 1 master and containerd as runtime, run:

openstack coe cluster create \\
    --cluster-template k8s-flan-small-35-containerd \\
    --master-count 1 \\
    --node-count 2 \\
    --keypair mykey \\
    k8s-flannel-small-35-containerd

To deploy a demo K8s cluster based on Fedora CoreOS 35 using a local insecure registry with 2 nodes and 1 master, run:

openstack coe cluster create \\
    --cluster-template k8s-flan-small-35-local-reg \\
    --master-count 1 \\
    --node-count 2 \\
    --keypair mykey \\
    k8s-flannel-small-35-local-reg

To deploy a demo K8s cluster based on Fedora CoreOS 37 using a local insecure registry with 2 nodes and 1 master, run:

openstack coe cluster create \\
    --cluster-template k8s-flan-small-37-local-reg \\
    --master-count 1 \\
    --node-count 2 \\
    --keypair mykey \\
    k8s-flannel-small-37-local-reg

If you want to measure the time on how long it takes to deploy a K8s cluster, run the following:

time while [ -n \$(openstack coe cluster list | grep k8s-flannel-small-35-local-reg | grep -w HEALTHY) ] ; do echo cluster not ready yet; done

You can check the overall deployment status with:

openstack coe cluster list

In case the cluster is in an unhealthy state like shown in the example below:

(yoga) [vagrant@seed ~]$ kubectl get nodes -o wide
NAME                                        STATUS     ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP    OS-IMAGE                        KERNEL-VERSION          CONTAINER-RUNTIME
k8s-test-37-loc-reg-r7juxkqsxysk-master-0   NotReady   master   15h   v1.23.3   10.0.0.46     172.28.4.139   Fedora CoreOS 37.20221127.3.0   6.0.9-300.fc37.x86_64   docker://20.10.20
k8s-test-37-loc-reg-r7juxkqsxysk-node-0     NotReady   <none>   15h   v1.23.3   10.0.0.236    172.28.4.133   Fedora CoreOS 37.20221127.3.0   6.0.9-300.fc37.x86_64   docker://20.10.20
(yoga) [vagrant@seed ~]$ openstack coe cluster list
+--------------------------------------+---------------------+---------+------------+--------------+-----------------+---------------+
| uuid                                 | name                | keypair | node_count | master_count | status          | health_status |
+--------------------------------------+---------------------+---------+------------+--------------+-----------------+---------------+
| 31d36f6b-5760-4c47-a3ac-65b885ff1259 | k8s-test-37-loc-reg | mykey   |          1 |            1 | CREATE_COMPLETE | UNHEALTHY     |
+--------------------------------------+---------------------+---------+------------+--------------+-----------------+---------------+

You can use the following commands to further debug the cluster creation:

ssh <floating ip of master node> -l core
ssh <floating ip of worker node> -l core

kubectl get nodes -o wide

kubectl get pods -A

if you see a failed pod, you can dig further with:

kubectl describe -n kube-system pod kube-flannel-ds-8469v

Once connected to the K8s master instance check systemctl --failed and tail the heat logs

sudo -i
tail -f /var/log/heat-config/heat-config-script/*.log

To download the K8s cluster config run

openstack coe cluster config k8s-flannel-small-35-local-reg

To interact with the K8s cluster we need kubectl and probably helm. For this we can simply use Arkade:

curl -sLS https://get.arkade.dev | sudo sh
arkade get kubectl@v1.23.3 \
export PATH=$PATH:~/.arkade/bin
export KUBECONFIG=~/config
helm
EOF

echo "To see this info again, check out readme.txt."
