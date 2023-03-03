#todo
#pub_ip var not working
#/etc/hosts entry must point to 192.168.20.221

# the deployment variable can be either multinode or all-in-one, by default it is all-in-one
cd
deployment="${deployment}"
release="${release}"
virtdir="./$${release}"
network_vlan_ranges="${network_vlan_ranges}"

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

#Install Ansible. Kolla Ansible requires at least Ansible 4 and supports up to 5.
pip install 'ansible>=4,<6'

#Install Kolla-ansible for deployment or evaluation. If using a virtual environment:
pip install git+https://opendev.org/openstack/kolla-ansible@stable/$${release}

#sudo dnf install -y python3-pip
#sudo dnf install -y sshpass
#sudo pip3 install -U pip
#sudo yum -y install epel-release
# Install Ansible. Kolla Ansible requires at least Ansible 2.10 and supports up to 4.
#sudo pip3 install -U 'ansible<3.0'
#sudo pip3 install --ignore-installed PyYAML kolla-ansible

#Create the /etc/kolla directory.
sudo mkdir -p /etc/kolla
sudo chown -R $${USER}:$${USER} /etc/kolla

#Copy globals.yml and passwords.yml to /etc/kolla directory.If using a virtual environment:
cp -r $${virtdir}/share/kolla-ansible/etc_examples/kolla/* /etc/kolla

#Copy all-in-one and multinode inventory files to the current directory. If using a virtual environment:
cp $${virtdir}/share/kolla-ansible/ansible/inventory/* .

#For all-in-one scenario in virtual environment add the following to the very beginning of the inventory:
#sed -i "1 i\localhost ansible_python_interpreter=~/$${release}/bin/python" all-in-one
sed -i "1 i\localhost ansible_python_interpreter=python3" all-in-one

#Install Ansible Galaxy dependencies (Yoga release onwards):
kolla-ansible install-deps

#If not using a virtual environment, run:
#cp -r /usr/local/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
#cp /usr/local/share/kolla-ansible/ansible/inventory/* ~

#sudo sed -i '/^\[defaults\]/a host_key_checking=False\npipelining=True\nforks=100\ntimeout=40' /etc/ansible/ansible.cfg
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
sed -i 's/^#enable_haproxy:.*/enable_haproxy: "${enable_haproxy}"/g' /etc/kolla/globals.yml
sed -i 's/^#openstack_release:.*/openstack_release: "'"$${release}"'"/g' /etc/kolla/globals.yml
sed -i 's/^#enable_neutron_provider_networks:.*/enable_neutron_provider_networks: "'"$${enable_neutron_provider_networks}"'"/g' /etc/kolla/globals.yml
sed -i 's/^#enable_dvr:.*/enable_dvr: "'"$${enable_dvr}"'"/g' /etc/kolla/globals.yml

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
#sed -i 's?^#cinder_backup_share:.*?cinder_backup_share: "192.168.2.2:/odroidxu4/openstack_backup"?g' /etc/kolla/globals.yml
sed -i 's?^#cinder_backup_share:.*?cinder_backup_share: "${cinder_nfs_bkp_share}"?g' /etc/kolla/globals.yml
sed -i 's/^#cinder_backup_mount_options_nfs:.*/cinder_backup_mount_options_nfs: "vers=3"/g' /etc/kolla/globals.yml

#Enable Magnum - Container Orchestration Engine
sed -i 's/^#enable_magnum:.*/enable_magnum: "yes"/g' /etc/kolla/globals.yml

#Create magnum.conf file. In this file you can define additional settings for Magnum
cat > /etc/kolla/config/magnum.conf << EOF
[trust]
cluster_user_trust = True
EOF

#Display globals.yml settings
grep ^[^#] /etc/kolla/globals.yml

# docker install script doesn't work on Rocky
# ERROR: Unsupported distribution 'rocky'
#curl -sSL https://get.docker.io | sudo bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
#sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
# we need to install docker version < 23.x for ZUN to work
sudo dnf install -y python3-dnf-plugin-versionlock
sudo dnf versionlock -y install docker-ce-20.10.23-3.el8.x86_64 docker-ce-cli-20.10.23-3.el8.x86_64 containerd.io docker-compose-plugin
sudo systemctl --now enable docker
#sudo systemctl daemon-reload
#sudo systemctl restart docker
#sudo systemctl enable docker
sudo pip3 install docker
sudo mkdir -p /var/lib/registry
sudo docker run -d \
 --name registry \
 --restart=always \
 -p 4000:5000 \
 -v registry:/var/lib/registry \
 registry:2

kolla-ansible -i all-in-one pull

# push all image to local registry, e.g.:
#     docker tag kolla/centos-binary-heat-api:3.0.1 \
#         localhost:4000/kolla/centos-binary-heat-api:3.0.1
#     docker push localhost:4000/kolla/centos-binary-heat-api:3.0.1

#cat <<EOT > push_docker_img.sh

#create script to push docker images to central docker registry
#currently not used!!!
cat > ~/push_docker_img.sh << EOF
docker images | grep kolla | grep -v local | awk '{print \$1,\$2}' | while read -r image tag; do
        newimg=\`echo \$${image} | cut -d / -f2-\`
        docker tag \$${image}:\$${tag} localhost:4000/\$${newimg}:\$${tag}
        docker push localhost:4000/\$${newimg}:\$${tag}
done
EOF
sudo sh push_docker_img.sh

# create file containing all containers required by magnum
# see "container_infra_prefix" at https://docs.openstack.org/magnum/yoga/user/ for more info
# there are a few containers missing in the doc above, they have been added in addition
cat > magnum_docker_images.txt << EOF
docker.io/coredns/coredns:1.3.1
docker.io/coredns/coredns:1.6.6
docker.io/coredns/coredns:1.9.3
quay.io/coreos/etcd:v3.4.6
docker.io/k8scloudprovider/k8s-keystone-auth:v1.18.0
docker.io/k8scloudprovider/openstack-cloud-controller-manager:v1.18.0
docker.io/k8scloudprovider/openstack-cloud-controller-manager:v1.23.1
gcr.io/google_containers/pause:3.1
docker.io/openstackmagnum/kubernetes-apiserver
docker.io/openstackmagnum/kubernetes-controller-manager
docker.io/openstackmagnum/kubernetes-kubelet
docker.io/openstackmagnum/kubernetes-proxy
docker.io/openstackmagnum/kubernetes-scheduler
k8s.gcr.io/hyperkube:v1.18.2
docker.io/grafana/grafana:5.1.5
docker.io/prom/node-exporter:latest
docker.io/prom/prometheus:latest
docker.io/traefik:v1.7.28
gcr.io/google_containers/kubernetes-dashboard-amd64:v1.5.1
kubernetesui/dashboard:v2.0.0
gcr.io/google_containers/metrics-server-amd64:v0.3.6
k8s.gcr.io/metrics-server/metrics-server:v0.5.2
k8s.gcr.io/node-problem-detector:v0.6.2
docker.io/planetlabs/draino:abf028a
docker.io/openstackmagnum/cluster-autoscaler:v1.18.1
quay.io/calico/cni:v3.13.1
quay.io/calico/pod2daemon-flexvol:v3.13.1
quay.io/calico/kube-controllers:v3.13.1
quay.io/calico/node:v3.13.1
quay.io/coreos/flannel-cni:v0.15.1
quay.io/coreos/flannel-cni:v0.3.0
rancher/coreos-flannel-cni:v0.3.0
quay.io/coreos/flannel:v0.12.0-amd64
quay.io/coreos/flannel:v0.15.1
quay.io/coreos/flannel:v0.18.1
quay.io/coreos/flannel:v0.3.0
quay.io/prometheus/alertmanager:v0.20.0
docker.io/squareup/ghostunnel:v1.5.2
docker.io/jettech/kube-webhook-certgen:v1.0.0
quay.io/prometheus/prometheus:v2.15.2
docker.io/k8scloudprovider/cinder-csi-plugin:v1.18.0
quay.io/k8scsi/csi-attacher:v2.0.0
quay.io/k8scsi/csi-attacher:v2.2.0
quay.io/k8scsi/csi-provisioner:v1.4.0
quay.io/k8scsi/csi-snapshotter:v1.2.2
quay.io/k8scsi/csi-resizer:v0.3.0
quay.io/k8scsi/csi-resizer:v0.3.1
quay.io/k8scsi/csi-node-driver-registrar:v1.1.0
quay.io/coreos/etcd:v3.4.6
rancher/hyperkube:v1.23.3-rancher1
rancher/hyperkube:v1.21.7-rancher1
rancher/hyperkube:v1.21.11-rancher1
rancher/hyperkube:v1.23.8-rancher1
kubernetesui/metrics-scraper:v1.0.4
gcr.io/google-containers/cluster-proportional-autoscaler-amd64:1.1.2
openstackmagnum/heat-container-agent:wallaby-stable-1
rancher/hyperkube:v1.23.15-rancher1
k8scloudprovider/openstack-cloud-controller-manager:v1.23.1
prom/prometheus:v1.8.2
openstack-cloud-controller-manager:v1.23.1
prom/prometheus:v1.8.2
grafana/grafana:5.1.5
prom/node-exporter:v0.15.2
kubernetesui/dashboard:v2.0.0
mirrorgooglecontainers/heapster-amd64:v1.4.2
kubernetesui/metrics-scraper:v1.0.4
k8s.gcr.io/metrics-server/metrics-server:v0.5.2
k8s.gcr.io/sig-storage/csi-snapshotter:v4.0.1
k8s.gcr.io/sig-storage/csi-snapshotter:v4.2.1
k8scloudprovider/openstack-cloud-controller-manager:v1.23.4
k8scloudprovider/k8s-keystone-auth:v1.23.4
k8scloudprovider/cinder-csi-plugin:v1.23.4
k8scloudprovider/magnum-auto-healer:v1.23.4
k8scloudprovider/octavia-ingress-controller:v1.23.4
k8s.gcr.io/sig-storage/csi-attacher:v3.3.0
k8s.gcr.io/sig-storage/csi-provisioner:v3.0.0
k8s.gcr.io/sig-storage/csi-resizer:v1.3.0
k8s.gcr.io/sig-storage/csi-snapshotter:v4.2.1
k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.4.0
k8s.gcr.io/sig-storage/livenessprobe:v2.5.0
openstackmagnum/cluster-autoscaler:v1.22.0
EOF

# pull all magnum container images
for img in `cat magnum_docker_images.txt`; do echo sudo docker pull $img; sudo docker pull $img;done

# create script to pull kolla docker images to central docker registry
cat > ~/pull_kolla_docker_img.sh << EOF
REGISTRY="localhost:4000"
echo "Disabling local docker registry in /etc/kolla/globals.yml..."
sed -i 's/^docker_registry:.*/#docker_registry: '"$${REGISTRY}"'/g' /etc/kolla/globals.yml
sed -i 's/^docker_registry_insecure:.*/#docker_registry_insecure: yes/g' /etc/kolla/globals.yml
echo "Pulling Kolla-Ansible containers to localhost..."
kolla-ansible -i all-in-one pull
echo "Enabling local docker registry in /etc/kolla/globals.yml..."
sed -i 's/^#docker_registry:.*/docker_registry: '"$${REGISTRY}"'/g' /etc/kolla/globals.yml
sed -i 's/^#docker_registry_insecure:.*/docker_registry_insecure: yes/g' /etc/kolla/globals.yml
echo "All done. Now run sudo sh -v push_docker_img.sh in order to push the docker images to the local docker registry."
EOF

# create script to push magnum docker images to central docker registry
cat > ~/push_magnum_docker_img.sh << EOF
docker images --format "{{.Repository}} {{.Tag}}" | grep -v $${release} | grep -v local | while read -r image tag; do
#docker images | grep -v yoga | grep -v local | awk '{print \$1,\$2}' | while read -r image tag; do
        #newimg=\`echo \$${image} | cut -d / -f2-\`
        newimg=\`echo \$${image} | rev | cut -d / -f 1 | rev\`
        echo docker tag \$${image}:\$${tag} localhost:4000/\$${newimg}:\$${tag}
        docker tag \$${image}:\$${tag} localhost:4000/\$${newimg}:\$${tag}
        echo docker push localhost:4000/\$${newimg}:\$${tag}
        docker push localhost:4000/\$${newimg}:\$${tag}
done
EOF
sudo sh push_magnum_docker_img.sh

# show images pushed to local docker registry
curl -X GET http://${docker_registry_magnum}/v2/_catalog | python3 -m json.tool

#sed -i 's/^#docker_registry:.*/docker_registry: 192.168.2.210:4000\/quay.io/g' /etc/kolla/globals.yml
sed -i 's/^#docker_registry:.*/docker_registry: "${docker_registry_kolla}"/g' /etc/kolla/globals.yml
sed -i 's/^#docker_registry_insecure:.*/docker_registry_insecure: yes/g' /etc/kolla/globals.yml

cp /home/vagrant/$deployment.mod ~/$deployment

#ansible -i $deployment compute,control -m shell -a "yum -y update" -b
#ansible -i $deployment compute,control --forks 1 -m reboot

# buildup /etc/hosts file
#echo 192.168.2.210 seed.fritz.box seed | sudo tee -a /etc/hosts
#echo 192.168.2.211 control01.fritz.box control01 | sudo tee -a /etc/hosts
#echo 192.168.2.212 compute01.fritz.box compute01 | sudo tee -a /etc/hosts

#try to ping all nodes
#ansible -i $deployment all -m ping

#install and configure chrony
ansible -i $deployment all -m shell -a "systemctl enable chronyd; systemctl restart chronyd" -b
