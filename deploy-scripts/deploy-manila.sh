# source information about kolla-ansible
source ~/env.sh

# see https://docs.openstack.org/kolla-ansible/2023.1/reference/storage/manila-guide.html for more information
kolla_mod="manila"
tags="common,horizon,manila"
option="--tags"
MANILAIMG="manila-service-image-master.qcow2"
MANILAIMGDLURL="https://tarballs.opendev.org/openstack/manila-image-elements/images/$MANILAIMG"

#Download kolla docker container
sh ~/deploy-scripts/download-svc.sh $kolla_mod

#Create magnum.conf file. In this file you can define additional settings for Magnum
cat > /etc/kolla/config/manila-share.conf << EOF
[generic]
service_instance_flavor_id = 2
EOF

. $HOME/activate.sh
. /etc/kolla/admin-openrc.sh

case $release in
  2023.1)
    ;;
  *)
    ;;
esac

#Deploy kolla svc
sh ~/deploy-scripts/deploy-svc.sh $kolla_mod $tags

#Install Openstack Magnum CLI client
pip install python-manilaclient

#Create a default share type before running manila-share service:
manila type-create default_share_type True

#Create a manila share server image to the Image service:
curl -O $MANILAIMGDLURL

#Upload manila share server image to glance
echo "Uploading manila share server image to Glance..."
openstack image create manila-service-image \
--public \
--disk-format=qcow2 \
--container-format=bare \
--property os_distro='fedora-coreos' \
--file=$MANILAIMG --progress

#Create a shared network
manila share-network-create --name demo-share-network1 \
  --neutron-net-id $(openstack subnet show demo-subnet -f value -c "id") \
  --neutron-subnet-id $(openstack subnet show demo-subnet -f value -c "network_id")