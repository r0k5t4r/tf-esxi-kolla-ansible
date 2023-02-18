openstack image create Fedora-CoreOS-37 \
--public \
--disk-format=qcow2 \
--container-format=bare \
--property os_distro='fedora-coreos' \
--file=fedora-coreos-37.20221127.3.0-openstack.x86_64.qcow2