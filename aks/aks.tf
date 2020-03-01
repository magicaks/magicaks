resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "k8s" {
    # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
    name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = var.log_analytics_workspace_location
    resource_group_name = var.resource_group_name
    sku                 = var.log_analytics_workspace_sku
}

resource "azurerm_log_analytics_solution" "k8s" {
    solution_name         = "ContainerInsights"
    location              = azurerm_log_analytics_workspace.k8s.location
    resource_group_name   = var.resource_group_name
    workspace_resource_id = azurerm_log_analytics_workspace.k8s.id
    workspace_name        = azurerm_log_analytics_workspace.k8s.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

resource "azurerm_kubernetes_cluster" "k8s" {
    name                = var.cluster_name
    location            = var.location
    resource_group_name = var.resource_group_name
    dns_prefix          = var.dns_prefix

    linux_profile {
        admin_username = "sakundu"

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
        log_analytics_workspace_id = azurerm_log_analytics_workspace.k8s.id
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

    provisioner "local-exec" {
        command = "${path.cwd}/aks/azurepolicy.sh ${self.name} ${self.resource_group_name}"
  }
}