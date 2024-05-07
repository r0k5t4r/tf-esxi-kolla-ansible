output "openstack_ext_vip" {
    description = "OpenStack external VIP (Virtual IP)"
    value = {
        OpenStack_ext_VIP = var.openstack_env.kolla_external_vip_address
    }
}

output "openstack_int_vip" {
    description = "OpenStack internal VIP (Virtual IP)"
    value = {
        OpenStack_int_VIP = var.openstack_env.kolla_internal_vip_address
    }
}

#output "openstack_octavia_vlan" {
#    description = "OpenStack Octavia VLAN"
#    value = {
#        OpenStack_octavia_vlan = var.portgroups["TF-OpenStack-2-Octavia-VLAN"].pg_vlan
#    }
#s}

output "terraform_kolla_ansible_deploy_options" {
    description = "Terraform Kolla-Ansible Deployment Options"
    value = {
        deploy_nfssrv           = var.deploy_env.deploy_nfssrv
        deploy_kolla            = var.deploy_env.deploy_kolla
        install_kolla           = var.deploy_env.install_kolla
        deploy_local_registry   = var.deploy_env.deploy_local_registry
    }
}

output "openstack_horizon" {
    description = "OpenStack Horizon Dashboard URL"
    value = {
        OpenStack_Horizon = "http://${var.openstack_env.kolla_external_vip_address}"
        OpenStack_Horion_Username = "admin"
        OpenStack_Horion_Password = "awk -F = '/OS_PASSWORD/ {print $2}' /etc/kolla/admin-openrc.sh"
    }
}

output "openstack_opensearch" {
    description = "OpenStack OpenSearch Dashboard URL"
    value = {
        OpenStack_Opensearch_Dashboard_URL = "http://${var.openstack_env.kolla_external_vip_address}:5601"
        OpenStack_Opensearch_Username = "opensearch"
        OpenStack_Opensearch_Password = "awk -F : '/opensearch_dashboards_password/ {print $2}' /etc/kolla/passwords.yml"
    }
}

output "openstack_grafana" {
    description = "OpenStack Grafana URL"
    value = {
        OpenStack_Grafana_URL = "http://${var.openstack_env.kolla_external_vip_address}:3000"
        OpenStack_Grafana_Username = "opensearch"
        OpenStack_Grafana_Password = "awk -F : '/opensearch_dashboards_password/ {print $2}' /etc/kolla/passwords.yml"
    }
}

output "vmxfile" {
  value = {
    vmxfile = data.local_file.vmxfile.content
  }
}