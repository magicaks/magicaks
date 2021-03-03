resource "azurerm_kubernetes_cluster" "k8s_cluster" {
    name                = "aks-${var.cluster_name}"
    location            = var.location
    resource_group_name = var.resource_group_name
    dns_prefix          = var.cluster_name

    linux_profile {
        admin_username  = "magicaksadmin"

        ssh_key {
            key_data    = file(var.ssh_public_key)
        }
    }

    default_node_pool {
        name                = "agentpool"
        vm_size             = "Standard_DS2_v2"
        os_disk_size_gb     = 30
        type                = "VirtualMachineScaleSets"
        enable_auto_scaling = true
        vnet_subnet_id      = var.k8s_subnet_id
        min_count           = 1
        max_count           = 5
    }

    identity {
        type                        = "UserAssigned"
        user_assigned_identity_id   = var.user_assigned_identity_resource_id
    }

    addon_profile {
        oms_agent {
            enabled                     = true
            log_analytics_workspace_id  = var.log_analytics_workspace_id
        }

        azure_policy {
            enabled = true
        }
    }

    role_based_access_control {
        azure_active_directory {
            managed                 = true
            tenant_id               = var.aad_tenant_id
            admin_group_object_ids  = [ var.admin_group_object_ids ]
        }
        enabled = true
    }

    network_profile {
        network_plugin  = "kubenet"
        network_policy  = "calico"
    }

    tags = {
        Environment = "Development"
    }

    enable_pod_security_policy  = false
    kubernetes_version          = "1.19.7"
    node_resource_group         = "rg-${var.cluster_name}-node"

    # Download admin credentials locally
    provisioner "local-exec" {
        command = "${path.cwd}/getcreds.sh ${self.resource_group_name} ${self.name}"
    }

    # Setup Azure Policy integration
    provisioner "local-exec" {
        command = "${path.cwd}/azurepolicy.sh ${self.name} ${self.resource_group_name}"
    }
}