#########################################
#  Provider configuration
#########################################

provider "esxi" {
  esxi_hostname = var.esxi_env.hostname
  esxi_hostport = var.esxi_env.hostport
  esxi_username = var.esxi_env.username
  esxi_password = var.esxi_env.password
}

#########################################
#  vSwitches
#########################################

#resource "esxi_vswitch" "vSwitch0" {
  #name              = "vSwitch0"
  # Optional - Enable Promiscuous Mode (true/false) - Default false
  #promiscuous_mode  = true
  # Optional - Enable MAC Changes (true/false) - Default false.
  #mac_changes       = true
  # Optional - Enable Forged Transmits (true/false) - Default false.
  #forged_transmits  = true 
#}

#########################################
#  Portgroups
#########################################

resource "esxi_portgroup" "allportgroups" {
  for_each = var.portgroups

  name      = each.value.pg_name
  vswitch   = each.value.pg_vswname
  vlan      = each.value.pg_vlan
}

#########################################
#  Download and modify VM Template
#########################################

locals {
  is_linux = length(regexall(":", lower(abspath(path.cwd)))) > 0
}

provider "null" {}

resource "null_resource" "download_and_extract" {
  count           = local.is_linux ? 1 : 0

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # path where vmtemplates are stored
      $filedlPath = "${var.vmtemplate.vmtemplatepath}"
      # the name of the vmtemplate vagrant box
      $file = "${var.vmtemplate.vmtemplate}"
      # the full path to the vmtemplate vagrant box
      $filePath = Join-Path -Path $filedlPath -ChildPath $file
      # download the vmtemplate vagrant box if it doesn't exist
      if (-Not (Test-Path -Path $filePath)) {
        Invoke-WebRequest -Uri "${var.vmtemplate.vmtemplatedlurl}" -OutFile "$filepath"
      }
        # extract the vagrant box
        tar -xvzf $filePath -C $filedlPath
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}

resource "null_resource" "download_and_extract_lnx" {
  count           = local.is_linux ? 0 : 1
  
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # path where vmtemplates are stored
      filedlPath="${var.vmtemplate.vmtemplatepath}"
      # the name of the vmtemplate vagrant box
      file="${var.vmtemplate.vmtemplate}"
      # the full path to the vmtemplate vagrant box
      filePath="$filedlPath/$file"
      # download the vmtemplate vagrant box if it doesn't exist
      if [ ! -f "$filePath" ]; then
        test -d $filedlPath || mkdir $filedlPath
        curl -o "$filePath" "${var.vmtemplate.vmtemplatedlurl}"
      fi
      # extract the vagrant box
      tar -xvzf "$filePath" -C "$filedlPath"
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "template_nestedvirt" {
  depends_on = [null_resource.download_and_extract]
  count           = local.is_linux ? 1 : 0

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # path where vmtemplates are stored
      $filedlPath="${var.vmtemplate.vmtemplatepath}"
      # the name of the vmtemplate vagrant box
      $file="${var.vmtemplate.vmtemplate}"
      # the full path to the vmtemplate vagrant box
      $filePath="$filedlPath\$file"
      # the name of the vmx file
      $vmxfile=tar -tf $filepath | FINDSTR .vmx
      # strip the path "./" from the vmx file
      $vmxfilerep = $vmxfile -replace "^\./", ""
      # full path to the vmx file
      $vmxfilefull = "$filedlpath/$vmxfilerep"
      # we need to create a file that contains the full path to the vmx file in order to deploy it
      $mypath="$filedlpath/vmxfile.txt"
      # we need to convert the file to UTF-8 without BOM
      # set the full path of the vmx file
      $MyRawString = "$filedlpath/$vmxfilerep"
      # remove any newlines
      $MyRawString = $MyRawString -replace '^\n', ''
      # create UTF-8 object with no BOM
      $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
      # write the UTF-8 file
      [System.IO.File]::WriteAllLines($MyPath, $MyRawString, $Utf8NoBomEncoding)
      # remove any whitespace from the UTF-8 file
      (Get-Content $mypath) -replace '\s', '' | Set-Content $mypath -NoNewline
      # add nested virtualization
      $valueToAdd = 'vhv.enable = "${var.vmtemplate.nestedvirt}"'
      # Check if the line exists in the file
      $lineExists = Get-Content $vmxfilefull | Where-Object { $_ -eq "$valueToAdd" }

      if (-not $lineExists) {
          # Append the line to the vmx file if it doesn't exist
          Add-Content -Path $vmxfilefull -Value ""
          Add-Content -Path $vmxfilefull -Value $valueToAdd
          Write-Host "Line added to the file."
      } else {
          Write-Host "Line already exists in the file."
      }
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}

data "local_file" "vmxfile" {
  depends_on = [
    null_resource.template_nestedvirt,
    null_resource.template_nestedvirt_lnx,
  ]
  filename = "${path.module}/${var.vmtemplate.vmtemplatepath}/vmxfile.txt"
}

resource "null_resource" "template_nestedvirt_lnx" {
  depends_on = [null_resource.template_nestedvirt]
  count      = local.is_linux ? 0 : 1

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
  command = <<-EOT
    filedlPath="${var.vmtemplate.vmtemplatepath}"
    file="${var.vmtemplate.vmtemplate}"
    filePath="$filedlPath/$file"
    valueToAdd='vhv.enable = "${var.vmtemplate.nestedvirt}"'
    vmxfile=$(tar -tf $filePath| grep .vmx)
    echo "" >> "vmtemplates/$vmxfile"
    echo "$valueToAdd" >> "vmtemplates/$vmxfile"
    # strip the path "./" from the vmx file
    vmxfilerep=$(basename $vmxfile)
    # we need to create a file that contains the full path to the vmx file in order to deploy it
    mypath="$filedlPath/vmxfile.txt"
    # set the full path of the vmx file
    MyRawString="$filedlPath/$vmxfilerep"
    # write the path of the vmx file to vmxfile.txt
    echo -n $MyRawString > $mypath
  EOT
  interpreter = ["bash", "-c"]
  }
}

#########################################
#  Upload and modify VM Template
#########################################

resource "esxi_guest" "vmtemplate" {
   depends_on = [
    null_resource.template_nestedvirt,
    null_resource.template_nestedvirt_lnx
  ]

  guest_name         = var.vmtemplate.vmtemplatename
  disk_store         = var.esxi_env.disk_store
  virthwver          = var.vmtemplate.virthwvers

  ovf_source  = data.local_file.vmxfile.content
  #ovf_source  = "vmtemplates/Rocky-9-Vagrant-VMware-9.2-20230513.0.x86_64.vmx"

  
  network_interfaces {
    virtual_network = var.vmtemplate.vmtemplatenetwork
  }

 provisioner "remote-exec" {
    inline = [
      "sleep 5",
      "sudo dnf -y install cloud-init",
      "sleep 5",
      "sudo shutdown now"
    ]
  }
  connection {
    type     = "ssh"
    user     = "vagrant"
    password = "vagrant"
    host     = esxi_guest.vmtemplate.ip_address
  }

  lifecycle {
    prevent_destroy = false
  }
}

#########################################
#  Clone VMs
#########################################

resource "esxi_guest" "all" {

  depends_on = [esxi_guest.vmtemplate]

  for_each = var.vms

  guest_name       = each.value["guest_name"]
  disk_store       = each.value["disk_store"]
  boot_disk_size	 = each.value["boot_disk_size"]
  memsize 			   = each.value["memsize"]
  numvcpus 			   = each.value["numvcpus"]

  clone_from_vm      = each.value["clone_from_vm"]

  dynamic "network_interfaces" {
    for_each = var.portgroups
    content {
      virtual_network = network_interfaces.value.pg_name
	    nic_type = "vmxnet3"
    }
  }

  #########################################
  #  ESXI Guestinfo metadata
  #########################################
  guestinfo = {
    "metadata" = base64gzip(templatefile("${path.module}/nodes/common/vm-metadata.cfg", {
      ip = "${each.value.ip}"
      hostname = "${each.value.hostname}"
      ip = "${each.value.ip}"
      ip_api = "${each.value.ip_api}"
      ip_octavia = "${each.value.ip_octavia}"
      ip_tunnel = "${each.value.ip_tunnel}"
      ip_nfs1 = "${each.value.ip_nfs1}"
      ip_nfs1_netmask = "${each.value.ip_nfs1_netmask}"
      netmask = "${each.value.netmask}"
      gw = "${var.vm_env.gw}"
      dns = "${var.vm_env.dns}"
      dns_search_dom = "${var.vm_env.dns_search_dom}"
    }))
    "metadata.encoding" = "gzip+base64"    
    "userdata" = base64gzip(templatefile("${path.module}/nodes/${each.value.guest_name}/cloudinit/userdata.yaml", {
      ip = "${each.value.ip}"
      hostname = "${each.value.hostname}"
      domain_name = "${each.value.domain_name}"
    }))    
    "userdata.encoding" = "gzip+base64"
}

  provisioner "remote-exec" {
    inline = [
      "test -f /var/done",
      "ls -al /var/done",
      "echo sleeping 20 seconds",
      "sleep 20"
    ]
    connection {
			host = each.value.ip
			type     = "ssh"
			user     = each.value.user
			password = each.value.password
		} 
 }
}

#########################################
#  Add /etc/hosts entries
#########################################

resource "null_resource" "new-etc-hosts-script" {
  for_each = var.vms
    provisioner "file" {
      source      = "scripts/new-add-etc-hosts.sh"
      destination = "/home/vagrant/new-add-etc-hosts.sh"
      connection {
        host     = var.vms["seed"].ip
        type     = "ssh"
        user     = var.vms["seed"].user
        password = var.vms["seed"].password
      }
    }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/vagrant/new-add-etc-hosts.sh",
      "/home/vagrant/new-add-etc-hosts.sh ${each.value.hostname} ${each.value.domain_name} ${each.value.ip}",
    ]
    connection {
      host     = var.vms["seed"].ip
      type     = "ssh"
      user     = var.vms["seed"].user
      password = var.vms["seed"].password
    }
  }

  depends_on = [esxi_guest.all["seed"]]
}

#########################################
#  Copy resize_disk.sh script
#########################################

resource "null_resource" "resize-disk-script" {
  for_each = var.vms

  provisioner "file" {
    content = templatefile("${path.module}/scripts/resize_disk.sh",{
    hostname = "${each.value.hostname}"
    domain_name = "${each.value.domain_name}"
    ip = "${each.value.ip}"
  })
    destination = "/home/vagrant/resize_disk.sh"

    connection {
			host = each.value.ip
			type     = "ssh"
			user     = each.value.user
			password = each.value.password
		} 
  }

 provisioner "remote-exec" {
    inline = [
       "chmod +x /home/vagrant/resize_disk.sh",
       "/home/vagrant/resize_disk.sh"
    ]
    connection {
			host = each.value.ip
			type     = "ssh"
			user     = each.value.user
			password = each.value.password
		}
  }

  depends_on = [esxi_guest.all["seed"]]
}

#########################################
# Copy Kolla Inventory File
#########################################

resource "null_resource" "kolla-inventory" {

  provisioner "file" {
    content = templatefile("${path.module}/scripts/multinode-${var.openstack_env.release}",{
    
    release = var.openstack_env.release
    deployment = var.openstack_env.deployment
    network_interface = var.openstack_env.network_interface
    neutron_external_interface = var.openstack_env.neutron_external_interface
    api_interface = var.openstack_env.api_interface
  })
    destination = "/home/vagrant/multinode.mod"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#########################################
#  Copy Kolla env.sh Script
#########################################

resource "null_resource" "kolla-env-script" {

  provisioner "file" {
    content = templatefile("${path.module}/scripts/env.sh",{
    release = var.openstack_env.release
    deployment = var.openstack_env.deployment
    network_interface = var.openstack_env.network_interface
    neutron_external_interface = var.openstack_env.neutron_external_interface
    neutron_ext_net_cidr = var.openstack_env.neutron_ext_net_cidr
    neutron_ext_net_range_start = var.openstack_env.neutron_ext_net_range_start
    neutron_ext_net_range_end = var.openstack_env.neutron_ext_net_range_end
    neutron_ext_net_gw = var.openstack_env.neutron_ext_net_gw
    neutron_ext_net_dns = var.openstack_env.neutron_ext_net_dns
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
    nfs_uid = var.openstack_env.nfs_uid
    EXT_NET = var.openstack_env.EXT_NET
    octavia_vlan = var.portgroups["TF-OpenStack-2-Octavia-VLAN"].pg_vlan
    deploy_local_registry = var.deploy_env.deploy_local_registry
  })
    destination = "/home/vagrant/env.sh"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#########################################
#  Copy Kolla Install Script
#########################################

resource "null_resource" "kolla-install-script" {

  provisioner "file" {
    content = templatefile("${path.module}/scripts/install-kolla.sh",{
    release = var.openstack_env.release
    deployment = var.openstack_env.deployment
    network_interface = var.openstack_env.network_interface
    neutron_external_interface = var.openstack_env.neutron_external_interface
    neutron_bridge_name = var.openstack_env.neutron_bridge_name
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
    nfs_uid = var.openstack_env.nfs_uid
    EXT_NET = var.openstack_env.EXT_NET
    deploy_local_registry = var.deploy_env.deploy_local_registry
  })
    destination = "/home/vagrant/install-kolla.sh"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#########################################
# Copy Kolla Deploy Script
#########################################

resource "null_resource" "kolla-deploy-script" {

  provisioner "file" {
    content = templatefile("${path.module}/scripts/deploy-kolla.sh",{
    release = var.openstack_env.release
    deployment = var.openstack_env.deployment
    network_interface = var.openstack_env.network_interface
    neutron_external_interface = var.openstack_env.neutron_external_interface
    neutron_bridge_name = var.openstack_env.neutron_bridge_name
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
    nfs_uid = var.openstack_env.nfs_uid
    EXT_NET = var.openstack_env.EXT_NET
  })
    destination = "/home/vagrant/deploy-kolla.sh"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#########################################
#  Copy Activate Script
#########################################

resource "null_resource" "activate-script" {

  provisioner "file" {
    content = templatefile("${path.module}/scripts/activate.sh",{
    release = var.openstack_env.release
    deployment = var.openstack_env.deployment
  })
    destination = "/home/vagrant/activate.sh"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#############################################################
#  Copy additional Kolla-Ansible Service Configuration Files
#############################################################

resource "null_resource" "kolla-services-config-files" {

  provisioner "file" {
    source      = "kolla-svc-config"
    destination = "/home/vagrant/kolla-svc-config"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#############################################################
#  Copy additional Kolla-Ansible Service Deployment Scripts
#############################################################

resource "null_resource" "kolla-deploy-services-files" {

  provisioner "file" {
    source      = "deploy-scripts"
    destination = "/home/vagrant/deploy-scripts"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#############################################################
#  Copy additional Kolla-Ansible Service globals.d Files
#############################################################

resource "null_resource" "kolla-services-globalsd-files" {

  provisioner "file" {
    source      = "globals.d"
    destination = "/home/vagrant/globals.d"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#############################################################
#  Copy additional helper-scripts
#############################################################

resource "null_resource" "helper-scripts-files" {

  provisioner "file" {
    source      = "helper-scripts"
    destination = "/home/vagrant/helper-scripts"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#############################################################
#  Copy additional install-scripts
#############################################################

resource "null_resource" "install-scripts-files" {

  provisioner "file" {
    source      = "install-scripts"
    destination = "/home/vagrant/install-scripts"

    connection {
      host = var.vms["seed"].ip
                        type     = "ssh"
                        user     = var.vms["seed"].user
                        password = var.vms["seed"].password
    }
  }
  depends_on = [esxi_guest.all["seed"]]
}

#############################################################
#  Install Kolla-Ansible
#############################################################

resource "null_resource" "install-kolla-ansible" {
  count = var.deploy_env.install_kolla ? 1 : 0
  depends_on = [esxi_guest.all["seed"]]

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/vagrant/install-kolla.sh",
      "/home/vagrant/install-kolla.sh",
    ]
    connection {
      host     = var.vms["seed"].ip
      type     = "ssh"
      user     = var.vms["seed"].user
      password = var.vms["seed"].password
    }
  }
}

#############################################################
#  Install NFS Server on Seed Node
#############################################################

resource "null_resource" "install-nfs-server" {
  count = var.deploy_env.deploy_nfssrv ? 1 : 0
  depends_on = [null_resource.install-kolla-ansible]

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/vagrant/install-scripts/deploy_nfssrv.sh",
      "/home/vagrant/install-scripts/deploy_nfssrv.sh",
    ]
    connection {
      host     = var.vms["seed"].ip
      type     = "ssh"
      user     = var.vms["seed"].user
      password = var.vms["seed"].password
    }
  }
}

#############################################################
#  Deploy Kolla-Ansible
#############################################################

resource "null_resource" "deploy-kolla-ansible" {
  count = var.deploy_env.deploy_kolla ? 1 : 0

  depends_on = [
    null_resource.install-nfs-server,
    null_resource.install-kolla-ansible
    ]

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/vagrant/deploy-kolla.sh",
      "/home/vagrant/deploy-kolla.sh",
    ]
    connection {
      host     = var.vms["seed"].ip
      type     = "ssh"
      user     = var.vms["seed"].user
      password = var.vms["seed"].password
    }
  }

}