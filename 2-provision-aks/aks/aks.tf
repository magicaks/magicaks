
resource "azurerm_kubernetes_cluster" "k8s" {
    name                = var.cluster_name
    location            = var.location
    resource_group_name = var.resource_group_name
    dns_prefix          = var.dns_prefix

    linux_profile {
        admin_username = "magicaksadmin"

        ssh_key {
            key_data = file(var.ssh_public_key)
        }
    }

    default_node_pool {
        name            = "agentpool"
        vm_size         = "Standard_DS2_v2"
        os_disk_size_gb = 30
        type = "VirtualMachineScaleSets"
        enable_auto_scaling = true
        vnet_subnet_id = var.k8s_subnet_id
        min_count = 1
        max_count = 5
    }

    service_principal {
        client_id     = var.client_id
        client_secret = var.client_secret
    }

    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = var.log_analytics_workspace_id
        }

        azure_policy {
            enabled = true
        }
    }

    role_based_access_control {
        azure_active_directory {
            client_app_id     = var.aad_client_appid
            server_app_id     = var.aad_server_appid
            server_app_secret = var.aad_server_app_secret
            tenant_id         = var.aad_tenant_id
        }
        enabled = true
    }    
    network_profile {
        network_plugin = "kubenet"
    }

    tags = {
        Environment = "Development"
    }

    enable_pod_security_policy = true
    kubernetes_version = "1.17.0"

    node_resource_group = "${var.resource_group_name}-node-rg"

    # Download admin credentials locally
    provisioner "local-exec" {
        command = "${path.cwd}/getcreds.sh ${self.resource_group_name} ${self.name}"
    }

    # Setup Azure Policy integration
    provisioner "local-exec" {
        command = "${path.cwd}/azurepolicy.sh ${self.name} ${self.resource_group_name}"
    }
}