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
#  Portgroups
#########################################

resource "esxi_portgroup" "allportgroups" {
  for_each = var.portgroups
  name      = each.value.pg_name
  vswitch   = each.value.pg_vswname
  vlan      = each.value.pg_vlan
}

#########################################
#  VMs
#########################################

resource "esxi_guest" "all" {
  for_each = var.vms
  guest_name       = each.value["guest_name"]
  disk_store       = each.value["disk_store"]
  boot_disk_size   = each.value["boot_disk_size"]
  memsize 	   = each.value["memsize"]
  numvcpus 	   = each.value["numvcpus"]
  #  Specify an existing guest to clone, an ovf source, or neither to build a bare-metal guest vm.
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
    "metadata"          = base64encode(data.template_file.metadataconfig[each.key].rendered)
    "metadata.encoding" = "base64"
    "userdata"          = base64encode(data.template_file.userdataconfig[each.key].rendered)
    "userdata.encoding" = "base64"
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
    content      = data.template_file.resize_disk[each.key].rendered
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
    content      = data.template_file.multinode.rendered
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
#  Copy Kolla Install Script
#########################################

resource "null_resource" "kolla-install-script" {

  provisioner "file" {
    content      = data.template_file.install-kolla.rendered
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
    content      = data.template_file.deploy-kolla.rendered
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
    content      = data.template_file.activate.rendered
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
