# Deploy OpenStack Yoga or Zed on a single ESXi node, no vCenter required, with Kolla-Ansible using Terraform and Cloud-init

This terraform manifest can deploy an all-in-one or multinode node OpenStack Cloud on an ESXi host. It will take complete care of this, by deploying the VMs, creating the necessary port groups, by default on vSwitch0 and also it will provide multiple scripts to install kolla-ansible and to deploy the OpenStack cloud.

In order to use this code you must have:
1. An ESXi host with some free resources (RAM,CPU,DISK)
1. A prepared Rocky Linux 8.x template for OpenStack release Yoga or Rocky Linux 9.x for OpenStack release Zed (I used the official Rocky Linux 8 https://app.vagrantup.com/rockylinux/boxes/8 or Rock Linux 9 https://app.vagrantup.com/rockylinux/boxes/9 boxes)
2. Furthermroe the template needs to have:
  Nested virtualization enabled! Otherwise you need to change kvm to qemu in Kolla. Currently it is not possible to enable nested virtualization via the VMware ESXi Terraform plugin.
  cloud-init installed (dnf install cloud-init)
3. A terraform.tfvars file. I have added 4 exmple files:

   - terraform.tfvars.yoga.all-in-one
   - terraform.tfvars.yoga.multinode
   - terraform.tfvars.zed.all-in-one
   - terraform.tfvars.zed.multinode

Below is the contents of the terraform.tfvars.yoga.multinode. It will deploy a total of 5 VMs (3 control and 2 compute nodes). The following services will be enabled:
  - Cinder: NFS
  - Magnum
  - terraform.tfvars.zed.all-in-one
  - terraform.tfvars.zed.multinode

Feel free to change the IP addresses and various settings to your neeeds. You need to at least adjust the ESXi username, password and hostname. Be sure to read the comments before using the file. The following example works fine for me:

```ruby
esxi_env = {
    # Adjust this
    username    = "root"
    password    = "mypass"
    hostname    = "192.168.2.100"
    hostport    = "22"
}

domain_env = {
    # Currently not used yet, please ignore them.
    user     = ".\\Administrator"
    password = "SuperPassword1!"
    dns_server   = "<dns_server_ip>"
    domain_name = "yourdomain.lab"
}

vm_env = {
    # Adjust this
    gw = "192.168.2.1"
    dns = "192.168.2.1"
    dns_search_dom = "lan.local"
}

openstack_env = {
        # The manifest is tested with Yoga and Zed
        # Make sure to also adjust kolla_base_distro = rocky when using zed!
        release = "yoga"
        # If you have enough resources you can deploy on multiple nodes, if not use all-in-one
        deployment = "multinode"
        # We create virtual networks (portgroups) on the ESXi host for the various OpenStack networks.
        network_interface = "eth00"
        neutron_external_interface = "eth03"
        api_interface = "eth02"
        # I use the following IP address ranges in my Homelab, you should change them accordingly.
        neutron_ext_net_cidr= "192.168.2.0/24"
        # The following two are very important. This the range of IPs that you carve out from your LAN. OpenStack will deploy an internal DHCP and issue IPs from within that range. So make sure these IPs are not used on your LAN!!!
        neutron_ext_net_range_start = "192.168.2.230"
        neutron_ext_net_range_end = "192.168.2.250"
        neutron_ext_net_gw = "192.168.2.1"
        neutron_ext_net_dns = "192.168.2.1"
        enable_neutron_dvr = "yes"
        # Required for Octavia Loadbalancer
        enable_neutron_provider_networks = "yes"
        # Adjust this to rocky if you want to use Zed
        kolla_base_distro = "centos"
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
        cinder_nfs_share = "192.168.2.2:/mnt/zpool0/openstack_volumes"
        cinder_nfs_bkp_share = "192.168.2.2:/mnt/zpool0/openstack_backup"
        # I recommend running a local docker registry on the seed node since its a couple of GB docker images that have to be downloaded. A central docker registry decreases the deployment time drastically.
        docker_registry_kolla = "192.168.2.140:4000"
        docker_registry_magnum = "192.168.2.140:4000"
}
 
# You can leave below as is. Adjust only if you know what you are doing. :)
# !!!the actual order of the vmnics is by alphabet descending!!!
# it is best to use numbers when possible
# or if a portgroup is preferred as eth0, make sure that the first letters of the other portgroups are in alphabetical order before the first letter of the preferred portgroup
portgroups = {
       "TF-OpenStack-1-default-V4" = {
         pg_name = "TF-OpenStack-1-default-V4"
         pg_vlan = "0"
         pg_vswname = "vSwitch0"
       }
       "TF-OpenStack-2-Octavia-V43" = {
         pg_name = "TF-OpenStack-2-Octavia-V43"
         pg_vlan = "43"
         pg_vswname = "vSwitch0"
       }
       "TF-OpenStack-3-API-V20" = {
         pg_name = "TF-OpenStack-3-API-V20"
         pg_vlan = "20"
         pg_vswname = "vSwitch0"
       }
       "TF-OpenStack-4-Trunk-V4095" = {
         pg_name = "TF-OpenStack-4-Trunk-V4095"
         # Set pg_vlan = 0 if you want to use flat network for neutron external network
         # Set pg_vlan = 4095 if you want to use vlans for neutron external network
         pg_vlan = "0"
         pg_vswname = "vSwitch0"
       }
       "TF-OpenStack-5-Tunnel-V50" = {
         pg_name = "TF-OpenStack-5-Tunnel-V50"
         pg_vlan = "50"
         pg_vswname = "vSwitch0"
       }
       "TF-OpenStack-6-NFS-V9" = {
         pg_name = "TF-OpenStack-6-NFS-V9"
         pg_vlan = "9"
         pg_vswname = "vSwitch0"
       }
}
 
# Finally we declare the VMs that we want to deploy. If you want to use all-in-one, you can remove all but the seed node.
vms = {
  seed = {
        boot_disk_size = 100
        clone_from_vm = "template-rocky8"
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
control01 = {
        boot_disk_size = 100
        clone_from_vm = "template-rocky8"
        disk_store = "truenas_ssd_01"
        domain_name = "lan.local"
        guest_name = "control01"
        hostname = "control01"
        ip = "192.168.2.141"
        ip_api = "192.168.20.141"
        ip_octavia = "192.168.43.141"
        ip_tunnel = "192.168.50.141"
        ip_nfs1 = "192.168.9.141"
        ip_nfs1_netmask = "255.255.255.0"
        memsize = 16384
        netmask = "255.255.255.0"
        numvcpus = 4
        password = "vagrant"
        user = "vagrant"
        nic_type = "vmxnet3"
    }
control02 = {
        boot_disk_size = 100
        clone_from_vm = "template-rocky8"
        disk_store = "truenas_ssd_01"
        domain_name = "lan.local"
        guest_name = "control02"
        hostname = "control02"
        ip = "192.168.2.142"
        ip_api = "192.168.20.142"
        ip_octavia = "192.168.43.142"
        ip_tunnel = "192.168.50.142"
        ip_nfs1 = "192.168.9.142"
        ip_nfs1_netmask = "255.255.255.0"
        memsize = 16384
        netmask = "255.255.255.0"
        numvcpus = 4
        password = "vagrant"
        user = "vagrant"
        nic_type = "vmxnet3"
    }
control03 = {
        boot_disk_size = 100
        clone_from_vm = "template-rocky8"
        disk_store = "truenas_ssd_01"
        domain_name = "lan.local"
        guest_name = "control03"
        hostname = "control03"
        ip = "192.168.2.143"
        ip_api = "192.168.20.143"
        ip_octavia = "192.168.43.143"
        ip_tunnel = "192.168.50.143"
        ip_nfs1 = "192.168.9.143"
        ip_nfs1_netmask = "255.255.255.0"
        memsize = 16384
        netmask = "255.255.255.0"
        numvcpus = 4
        password = "vagrant"
        user = "vagrant"
        nic_type = "vmxnet3"
    }
compute01 = {
        boot_disk_size = 100
        clone_from_vm = "template-rocky8"
        disk_store = "truenas_ssd_01"
        domain_name = "lan.local"
        guest_name = "compute01"
        hostname = "compute01"
        ip = "192.168.2.144"
        ip_api = "192.168.20.144"
        ip_octavia = "192.168.43.144"
        ip_tunnel = "192.168.50.144"
        ip_nfs1 = "192.168.9.144"
        ip_nfs1_netmask = "255.255.255.0"
        memsize = 12288
        netmask = "255.255.255.0"
        numvcpus = 4
        password = "vagrant"
        user = "vagrant"
        nic_type = "vmxnet3"
    }
compute02 = {
        boot_disk_size = 100
        clone_from_vm = "template-rocky8"
        disk_store = "truenas_ssd_01"
        domain_name = "lan.local"
        guest_name = "compute02"
        hostname = "compute02"
        ip = "192.168.2.145"
        ip_api = "192.168.20.145"
        ip_octavia = "192.168.43.145"
        ip_tunnel = "192.168.50.145"
        ip_nfs1 = "192.168.9.145"
        ip_nfs1_netmask = "255.255.255.0"
        memsize = 12288
        netmask = "255.255.255.0"
        numvcpus = 4
        password = "vagrant"
        user = "vagrant"
        nic_type = "vmxnet3"
    }
}
```
In order to run this:
1. clone the git repo
2. cd into the cloned directory
3. choose one of the example terraform.tfvars.* file e.g. terraform.tfvars.yoga.multinode or create your very own.
4. run:
```ruby
 terraform init
```
5. run: 
```ruby
terraform plan -var-file terraform.tfvars.yoga.multinode
```
6. run:
```ruby
terraform apply -var-file terraform.tfvars.yoga.multinode
```
After the deployment ssh to the seed node and run the following commands:

```ruby
sh -vvv install-kolla.sh
sh -vvv deploy-kolla.sh
```

This will install kolla-ansible and deploy an OpenStack Cloud. After the deployment, check out the readme.txt. This contains various hints and some example configurations.
Have fun. :)