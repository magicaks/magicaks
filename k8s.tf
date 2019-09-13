resource "azurerm_resource_group" "k8s" {
    name     = "${var.resource_group_name}"
    location = "${var.location}"
}

resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "k8s" {
    # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
    name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = "${var.log_analytics_workspace_location}"
    resource_group_name = "${azurerm_resource_group.k8s.name}"
    sku                 = "${var.log_analytics_workspace_sku}"
}

resource "azurerm_log_analytics_solution" "k8s" {
    solution_name         = "ContainerInsights"
    location              = "${azurerm_log_analytics_workspace.k8s.location}"
    resource_group_name   = "${azurerm_resource_group.k8s.name}"
    workspace_resource_id = "${azurerm_log_analytics_workspace.k8s.id}"
    workspace_name        = "${azurerm_log_analytics_workspace.k8s.name}"

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

resource "azurerm_virtual_network" "k8s-vnet" {
  name                = "k8s-vnet"
  location            = "${azurerm_resource_group.k8s.location}"
  resource_group_name = "${azurerm_resource_group.k8s.name}"
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "k8s-subnet" {
  name                 = "k8s-subnet"
  resource_group_name  = "${azurerm_resource_group.k8s.name}"
  address_prefix       = "10.1.0.0/24"
  virtual_network_name = "${azurerm_virtual_network.k8s-vnet.name}"
}

resource "azurerm_kubernetes_cluster" "k8s" {
    name                = "${var.cluster_name}"
    location            = "${azurerm_resource_group.k8s.location}"
    resource_group_name = "${azurerm_resource_group.k8s.name}"
    dns_prefix          = "${var.dns_prefix}"

    linux_profile {
        admin_username = "sakundu"

        ssh_key {
            key_data = "${file("${var.ssh_public_key}")}"
        }
    }

    agent_pool_profile {
        name            = "agentpool"
        count           = "${var.agent_count}"
        vm_size         = "Standard_DS2_v2"
        os_type         = "Linux"
        os_disk_size_gb = 30
        type = "VirtualMachineScaleSets"
        enable_auto_scaling = true
        vnet_subnet_id = "${azurerm_subnet.k8s-subnet.id}"
        min_count = 1
        max_count = 5
    }

    service_principal {
        client_id     = "${var.client_id}"
        client_secret = "${var.client_secret}"
    }

    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = "${azurerm_log_analytics_workspace.k8s.id}"
        }
    }

    role_based_access_control {
        enabled = true
    }
    
    network_profile {
        network_plugin = "azure"
    }

    tags = {
        Environment = "Development"
    }
}

module "flux" {
  source = "flux"

  gitops_ssh_url       = "${var.gitops_ssh_url}"
  gitops_ssh_key       = "${var.gitops_ssh_key}"
  gitops_path          = "${var.gitops_path}"
  gitops_poll_interval = "${var.gitops_poll_interval}"
  gitops_url_branch    = "${var.gitops_url_branch}"
  enable_flux          = "${var.enable_flux}"
  flux_recreate        = "${var.flux_recreate}"
  kubeconfig_complete  = "${module.aks.kubeconfig_done}"
  kubeconfig_filename  = "${var.kubeconfig_filename}"
  flux_clone_dir       = "${var.cluster_name}-flux"
  acr_enabled          = "${var.acr_enabled}"
  gc_enabled           = "${var.gc_enabled}"
}