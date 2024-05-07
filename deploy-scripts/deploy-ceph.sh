# source information about kolla-ansible
source ~/env.sh

# get subnet id of external network
EXT_SUBNET=$(openstack network show $EXT_NET -f value -c subnets | awk -F \' '{print $2}')

# see https://docs.openstack.org/kolla-ansible/yoga/reference/networking/octavia.html for more information
kolla_mod="manila"
tags="glance,cinder,nova,manila"
option="--tags"

#Download kolla docker container
#time sh ~/deploy-scripts/download-svc.sh $option $kolla_mod

. $HOME/activate.sh
. /etc/kolla/admin-openrc.sh

#if [ $release = "2023.2" ]; then
#    sed -i 's/#enable_redis:.*/enable_redis: "yes"/' /etc/kolla/globals.yml
#    tags="common,horizon,octavia,neutron,redis"
#    kolla_mod2="redis"
    #Download kolla docker container
#    time sh ~/deploy-scripts/download-svc.sh $option $kolla_mod2
#fi

#Modify octavia.yml
#if [ $release = "yoga" ]; then
#    sed -e '/octavia_provider_drivers: "amphora:Amphora provider"/ s/^#*/#/' -i /etc/kolla/globals.d/octavia.yml
#fi

# Create folders for ceph config files
mkdir -p /etc/kolla/config/glance
mkdir -p /etc/kolla/config/cinder/cinder-volume
mkdir -p /etc/kolla/config/cinder/cinder-backup
mkdir /etc/kolla/config/nova
mkdir /etc/kolla/config/manila

# Enable ceph for glance
sed -i 's/^#glance_backend_ceph:.*/glance_backend_ceph: "yes"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_glance_keyring:.*/ceph_glance_keyring: "ceph.client.glance.keyring"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_glance_user:.*/ceph_glance_user: "glance"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_glance_pool_name:.*/ceph_glance_pool_name: "images"/g' /etc/kolla/globals.yml

# Enable ceph for cinder volumes
sed -i 's/^#enable_cinder:.*/enable_cinder: "yes"/g' /etc/kolla/globals.yml
sed -i 's/^#enable_cinder_backup:.*/enable_cinder_backup: "yes"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_cinder_keyring:.*/ceph_cinder_keyring: "ceph.client.cinder.keyring"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_cinder_user:.*/ceph_cinder_user: "cinder"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_cinder_pool_name:.*/ceph_cinder_pool_name: "volumes"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_cinder_backup_keyring:.*/ceph_cinder_backup_keyring: "ceph.client.cinder-backup.keyring"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_cinder_backup_user:.*/ceph_cinder_backup_user: "cinder-backup"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_cinder_backup_pool_name:.*/ceph_cinder_backup_pool_name: "backups"/g' /etc/kolla/globals.yml
#sed -i 's/^#ceph_nova_keyring:.*/ceph_nova_keyring: "{{ ceph_cinder_keyring }}"/g' /etc/kolla/globals.yml

# Enable ceph for nova ephemeral disks
sed -i 's/^#nova_backend_ceph:.*/nova_backend_ceph: "yes"/g' /etc/kolla/globals.yml
sed -i 's/^#ceph_nova_keyring:.*/ceph_nova_keyring: "client.nova.keyring"/g' /etc/kolla/globals.yml

# Enable ceph for manila
sed -i 's/^#enable_manila:.*/enable_manila: "yes"/g' /etc/kolla/globals.yml
sed -i 's/^#enable_manila_backend_cephfs_native:.*/enable_manila_backend_cephfs_native: "yes"/g' /etc/kolla/globals.yml

cat > /etc/kolla/config/manila-share.conf << EOF
[generic]
service_instance_flavor_id = 2
EOF

# fix ceph.conf
# Commands like ceph config generate-minimal-conf generate configuration files that have leading tabs. These tabs break Kolla Ansible’s ini parser.
# Be sure to remove the leading tabs from your ceph.conf files when copying them in the following sections.
find /etc/kolla -type f -name 'ceph.conf' -exec sed -i 's/^[[:space:]]*//' {} +

cat > readme_ceph.txt << EOF

EOF

cat readme_ceph.txt

echo "To see this info again, check out readme_ceph.txt."