# This will deploy OpenStack Antelope (2023.2) Release all-in-one node

esxi_env = {
  # **** Adjust this to match your environment *****
  username    = "root"
  password    = "mypass"
  hostname    = "192.168.2.100"
  hostport    = "22"
  disk_store  = "truenas_ssd_01"
}

domain_env = {
  # Currently not used yet, please ignore them.
  user     = ".\\Administrator"
  password = "SuperPassword1!"
  dns_server   = "<dns_server_ip>"
  domain_name = "yourdomain.lab"
}

vmtemplate = {
  vmtemplatepath = "vmtemplates"
  vmtemplate = "Rocky-9-Vagrant-VMware.latest.x86_64.box"
  vmtemplatefull = "vmtemplates/Rocky-9-Vagrant-VMware.latest.x86_64.box"
  vmtemplatename = "template-rocky9"
  vmtemplatedlurl = "https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-Vagrant-VMware.latest.x86_64.box"
  nestedvirt = "TRUE"
  # Change this to 13 when using ESXi 6.x
  # See https://kb.vmware.com/s/article/1003746 for more information
  virthwvers = "17"
  vmtemplatenetwork = "VM Network"
}

vm_env = {
  # **** Adjust this to match your environment *****
  gw = "192.168.2.1"
  dns = "192.168.2.1"
  dns_search_dom = "lan.local"
}

deploy_env = {
  # **** Adjust if you want *****
  # Install Kolla-Ansible
  install_kolla = true
  # Deploy an NFS server on the seed node - will be used by Cinder. Needs install_kolla = true
  deploy_nfssrv = true
  # Deploy OpenStack using Kolla-Ansible
  deploy_kolla = true
  # Use a local docker registry. Use this if you already have a local docker registry.
  use_local_registry = true
  # Deploy a local docker registry on the seed node
  deploy_local_registry = true
  # Pull and push images to a local docker registry. Will be always be done if deploy_local_registry = true.
  pull_local_registry = true
  # Pull and push Magnum images to a local docker registry.
  pull_magnum_local_registry = false
}

openstack_env = {
  # Tested with OpenStack Release Antelope (2023.2)
  # Make sure to also adjust kolla_base_distro = rocky when using Zed or newer!
  release = "2023.2"
  # If you have enough resources you can deploy on multiple nodes, if not use all-in-one
  deployment = "all-in-one"
  # We create virtual networks (portgroups) on the ESXi host for the various OpenStack networks.
  network_interface = "eth00"
  # eth01 will be used for octavia
  neutron_external_interface = "eth03,eth01"
  neutron_bridge_name = "br-ex1,br-ex2"
  api_interface = "eth02"
  # **** Adjust this to match your environment *****
  # I use the following IP address ranges in my Homelab, you should change them accordingly.
  neutron_ext_net_cidr= "192.168.2.0/24"
  # The following two are very important. This the range of IPs that you carve out from your LAN. 
  # OpenStack will deploy an internal DHCP and issue IPs from within that range. 
  # So make sure these IPs are not used on your LAN!!!
  neutron_ext_net_range_start = "192.168.2.230"
  neutron_ext_net_range_end = "192.168.2.250"
  neutron_ext_net_gw = "192.168.2.1"
  neutron_ext_net_dns = "192.168.2.1"
  enable_neutron_dvr = "yes"
  # Required for Octavia Loadbalancer
  enable_neutron_provider_networks = "yes"
  # Adjust this to rocky if you want to use Zed or newer
  kolla_base_distro = "rocky"
  kolla_internal_vip_address = "192.168.20.222"
  # This is the virtual IP where you can reach e.g. the OpenStack Horizon WebUI
  kolla_external_vip_address = "192.168.2.222"
  # If you want to use vlans (trunk) for neutron external network, uncomment below. Make sure to also set pg_vlan=4095 on TF-OpenStack-4-Trunk-V4095 portgroup below. This is to configure the port group as a trunk so that it can carry multiple VLANs.
  #network_vlan_ranges = "physnet1:4:4,physnet1:16:16,physnet1:43:43"
  # If you want to use a flat network as neutron external network use this:
  network_vlan_ranges = "0"
  enable_haproxy = "yes"
  # Use below if you have a NFS server. Highly recommended. If not set enable_cinder = "no".
  enable_cinder = "yes"
  enable_cinder_backend_nfs = "yes"
  cinder_nfs_share = "192.168.2.140:/var/nfs/openstack_volumes"
  cinder_nfs_bkp_share = "192.168.2.140:/var/nfs/openstack_backup"
  # Use a local docker registry
  # If you don't have one, I recommend running a local docker registry on the seed node since its a couple of GB docker images that have to be downloaded. 
  # A central docker registry decreases the deployment time drastically.
  docker_registry_kolla = "192.168.2.140:4000"
  docker_registry_magnum = "192.168.2.140:4000"
  nfs_uid = "42407"
  EXT_NET = "public1"
  # You can now enable the usage of quorum queues in RabbitMQ for all services by setting the variable om_enable_rabbitmq_quorum_queues to true. 
  # Notice that you can’t use quorum queues and high availability at the same time. This is caught by a precheck. 
  # This feature is enabled by default to improve reliability of the messaging queues.
  om_enable_rabbitmq_high_availability = "false"
}
 
# You can leave below as is. Adjust only if you know what you are doing. :)
# !!!the actual order of the vmnics is by alphabet descending!!!
# it is best to use numbers when possible
# or if a portgroup is preferred as eth0, make sure that the first letters of the other portgroups are in alphabetical order before the first letter of the preferred portgroup
portgroups = {
  # eth00
  "TF-OpenStack-1-default-V4" = {
    pg_name = "TF-OpenStack-1-default-V4"
    pg_vlan = "0"
    pg_vswname = "vSwitch0"
  }
  # eth01 / br-ex2
  "TF-OpenStack-2-Octavia-VLAN" = {
    pg_name = "TF-OpenStack-2-Octavia-VLAN"
    pg_vlan = "43"
    pg_vswname = "vSwitch0"
  }
  # eth02
  "TF-OpenStack-3-API-V20" = {
    pg_name = "TF-OpenStack-3-API-V20"
    pg_vlan = "20"
    pg_vswname = "vSwitch0"
  }
  # eth03 / br-ex1
  "TF-OpenStack-4-Trunk-V4095" = {
    pg_name = "TF-OpenStack-4-Trunk-V4095"
    # Set pg_vlan = 0 if you want to use flat network for neutron external network
    # Set pg_vlan = 4095 if you want to use vlans for neutron external network
    pg_vlan = "0"
    pg_vswname = "vSwitch0"
  }
  # eth04
  "TF-OpenStack-5-Tunnel-V50" = {
    pg_name = "TF-OpenStack-5-Tunnel-V50"
    pg_vlan = "50"
    pg_vswname = "vSwitch0"
  }
  # eth05
  "TF-OpenStack-6-NFS-V9" = {
    pg_name = "TF-OpenStack-6-NFS-V9"
    pg_vlan = "9"
    pg_vswname = "vSwitch0"
  }
  # eth06 / Octavia on seed and control nodes
  "TF-OpenStack-7-Octavia-V43" = {
    pg_name = "TF-OpenStack-7-Octavia-V43"
    pg_vlan = "43"
    pg_vswname = "vSwitch0"
  }
}
 
# Finally we declare the VMs that we want to deploy. If you want to use all-in-one, you can remove all but the seed node.
vms = {
  seed = {
    boot_disk_size = 100
    clone_from_vm = "template-rocky9"
    disk_store = "truenas_ssd_01"
    domain_name = "lan.local"
    guest_name = "seed"
    hostname = "seed"
    ip = "192.168.2.140"
    ip_api = "192.168.20.140"
    ip_octavia = "192.168.43.140"
    ip_tunnel = "192.168.50.140"
    ip_nfs1 = "192.168.9.140"
    ip_nfs1_netmask = "255.255.255.0"
    memsize = 8192
    netmask = "255.255.255.0"
    numvcpus = 4
    password = "vagrant"
    user = "vagrant"
    nic_type = "vmxnet3"
  }
}