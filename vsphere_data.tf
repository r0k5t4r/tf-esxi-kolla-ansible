data template_file "metadataconfig" {
  for_each = var.vms

  # Main cloud-config configuration file.
  template = file("${path.module}/nodes/common/vm-metadata.cfg")
  vars = {
    ip = "${each.value.ip}"
    ip_api = "${each.value.ip_api}"
    ip_octavia = "${each.value.ip_octavia}"
    ip_tunnel = "${each.value.ip_tunnel}"
    ip_nfs1 = "${each.value.ip_nfs1}"
    ip_nfs1_netmask = "${each.value.ip_nfs1_netmask}"
    netmask = "${each.value.netmask}"
    hostname = "${each.value.hostname}"
    instance_id = "${each.value.guest_name}"
    gw = "${var.vm_env.gw}"
    dns = "${var.vm_env.dns}"
    dns_search_dom = "${var.vm_env.dns_search_dom}"
  }
}

data template_file "userdataconfig" {
  for_each = var.vms
  template = file("${path.module}/nodes/${each.value.guest_name}/cloudinit/userdata.yaml")
  vars = {
    ip = "${each.value.ip}"
    hostname = "${each.value.hostname}"
    domain_name = "${each.value.domain_name}"
  }
}

data template_file "kickstartconfig" {
  for_each = var.vms
  # Main cloud-config configuration file.
  template = file("${path.module}/nodes/common/kickstart.yaml")
  vars = {
    user = "${each.value.user}"
    password = "${each.value.password}"
  }
}

data template_file "multinode" {
  template = file("${path.module}/scripts/multinode-${var.openstack_env.release}")
  vars = {
    release = var.openstack_env.release
    deployment = var.openstack_env.deployment
    network_interface = var.openstack_env.network_interface
    neutron_external_interface = var.openstack_env.neutron_external_interface
    api_interface = var.openstack_env.api_interface
  }
}

data template_file "install-kolla" {
  template = file("${path.module}/scripts/install-kolla.sh")
  vars = {
    release = var.openstack_env.release
    deployment = var.openstack_env.deployment
    network_interface = var.openstack_env.network_interface
    neutron_external_interface = var.openstack_env.neutron_external_interface
    neutron_ext_net_cidr = var.openstack_env.neutron_ext_net_cidr
    neutron_ext_net_range_start = var.openstack_env.neutron_ext_net_range_start
    neutron_ext_net_range_end = var.openstack_env.neutron_ext_net_range_end
    neutron_ext_net_gw = var.openstack_env.neutron_ext_net_gw
    cinder_nfs_share = var.openstack_env.cinder_nfs_share
    cinder_nfs_bkp_share = var.openstack_env.cinder_nfs_bkp_share
    kolla_base_distro = var.openstack_env.kolla_base_distro
    kolla_internal_vip_address = var.openstack_env.kolla_internal_vip_address
    kolla_external_vip_address = var.openstack_env.kolla_external_vip_address
    network_vlan_ranges = var.openstack_env.network_vlan_ranges
    enable_haproxy = var.openstack_env.enable_haproxy
    enable_cinder = var.openstack_env.enable_cinder
    enable_cinder_backend_nfs = var.openstack_env.enable_cinder_backend_nfs
    docker_registry_kolla = var.openstack_env.docker_registry_kolla
    docker_registry_magnum = var.openstack_env.docker_registry_magnum
    enable_neutron_dvr = var.openstack_env.enable_neutron_dvr
    enable_neutron_provider_networks = var.openstack_env.enable_neutron_provider_networks
  }
}

data template_file "deploy-kolla" {
  template = file("${path.module}/scripts/deploy-kolla.sh")
  vars = {
    release = var.openstack_env.release
    deployment = var.openstack_env.deployment
    network_interface = var.openstack_env.network_interface
    neutron_external_interface = var.openstack_env.neutron_external_interface
    neutron_ext_net_cidr = var.openstack_env.neutron_ext_net_cidr
    neutron_ext_net_range_start = var.openstack_env.neutron_ext_net_range_start
    neutron_ext_net_range_end = var.openstack_env.neutron_ext_net_range_end
    neutron_ext_net_gw = var.openstack_env.neutron_ext_net_gw
    cinder_nfs_share = var.openstack_env.cinder_nfs_share
    cinder_nfs_bkp_share = var.openstack_env.cinder_nfs_bkp_share
    kolla_internal_vip_address = var.openstack_env.kolla_internal_vip_address
    kolla_external_vip_address = var.openstack_env.kolla_external_vip_address
    network_vlan_ranges = var.openstack_env.network_vlan_ranges
    neutron_ext_net_dns = var.openstack_env.neutron_ext_net_dns
    docker_registry_kolla = var.openstack_env.docker_registry_kolla
    docker_registry_magnum = var.openstack_env.docker_registry_magnum
    enable_neutron_dvr = var.openstack_env.enable_neutron_dvr
    enable_neutron_provider_networks = var.openstack_env.enable_neutron_provider_networks
  }
}

data template_file "activate" {
  # Kolla Ansible inventory configuration file.
  template = file("${path.module}/scripts/activate.sh")
  vars = {
    release = var.openstack_env.release
    deployment = var.openstack_env.deployment
  }
}

data template_file "resize_disk" {
  for_each = var.vms
  template = file("${path.module}/scripts/resize_disk.sh")
  vars = {
    hostname = "${each.value.hostname}"
    domain_name = "${each.value.domain_name}"
    ip = "${each.value.ip}"
  }
}

data template_file "check" {
  template = file("${path.module}/scripts/check.sh")
  vars = {
  }
}
