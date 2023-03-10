#cloud variables

variable "esxi_env" {
    type = object({
        hostname = string
        username = string
        password = string
        hostport = number
    })
}

variable "domain_env" {
    type = object({
        dns_server = string
        user = string
        password = string
        domain_name = string
    })
}

variable "vm_env" {
    type = object({
        gw = string
        dns = string
        dns_search_dom = string
    })
}

variable "openstack_env" {
    type = object ({
        release = string
        deployment = string
        network_interface = string
        neutron_external_interface = string
        api_interface = string
        neutron_ext_net_cidr = string
        neutron_ext_net_range_start = string
        neutron_ext_net_range_end = string
        neutron_ext_net_gw = string
        neutron_ext_net_dns = string
        cinder_nfs_share = string
        cinder_nfs_bkp_share = string
        kolla_base_distro = string
        kolla_internal_vip_address = string
        kolla_external_vip_address = string
        network_vlan_ranges = string
        enable_haproxy = string
        enable_cinder = string
        enable_cinder_backend_nfs = string
        docker_registry_kolla = string
        docker_registry_magnum = string
        enable_neutron_dvr = string
        enable_neutron_provider_networks = string
    })
}

variable "portgroups" {
    type = map(object({
        pg_name = string
        pg_vswname = string
        pg_vlan = string
     }))
}

variable "vms" {
    type = map(object({
        numvcpus = number
        memsize = number
        guest_name = string
        disk_store = string
        boot_disk_size = number
        user = string
        password = string
        clone_from_vm = string
        hostname = string
        domain_name = string
        ip = string
        ip_api = string
        ip_octavia = string
        ip_tunnel = string
        ip_nfs1 = string
        ip_nfs1_netmask = string
        netmask = string
        nic_type = string
    }))
    default = {
      "key" = {
        boot_disk_size = "100"
        clone_from_vm = "value"
        disk_store = "value"
        domain_name = "lan.local"
        guest_name = "value"
        hostname = "value"
        ip = "value"
        ip_api = "value"
        ip_octavia = "value"
        ip_tunnel = "value"
        ip_nfs1 = "value"
        ip_nfs1_netmask = "255.255.255.0"
        memsize = "8192"
        netmask = "value"
        nic_type = "value"
        numvcpus = "1"
        password = "value"
        user = "value"
      }
    }
}
