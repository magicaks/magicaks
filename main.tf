terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    key = "magicaksconsolidated"
  }
}

data "azurerm_subscription" "current" {
}

module "preprovision" {
  source              = "./1-preprovision"
  location            = var.location
  resource_group_name = var.resource_group_name
  resource_suffix     = var.resource_suffix
  tenant_id           = data.azurerm_subscription.current.tenant_id
}

resource "null_resource" "buildgrafana" {

  provisioner "local-exec" {
    command = "./buildgrafana.sh"
  }
}

resource "azurerm_user_assigned_identity" "magicaksmsi" {
  resource_group_name = var.resource_group_name
  location            = var.location

  name = "magicaksmsi"
}

resource "azurerm_role_assignment" "networkcontributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.magicaksmsi.principal_id
}

resource "azurerm_role_assignment" "vmcontributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_user_assigned_identity.magicaksmsi.principal_id
}

module "provision-cluster" {
  source              = "./2-provision-aks"
  cluster_name        = var.cluster_name
  subscription_id     = data.azurerm_subscription.current.id
  aad_tenant_id       = var.aad_tenant_id
  admin_group_object_ids = var.admin_group_object_ids
  k8s_subnet_id          = module.preprovision.k8s_subnet_id
  aci_subnet_id          = module.preprovision.aci_subnet_id
  aci_network_profile_id = module.preprovision.aci_network_profile_id
  acr_name               = module.preprovision.acr_name
  key_vault_id           = module.preprovision.key_vault_id
  grafana_admin_password = var.grafana_admin_password
  cluster_support_db_admin_password = var.cluster_support_db_admin_password
  grafana_image_name                = var.grafana_image_name
  monitoring_reader_sp_client_id    = var.monitoring_reader_sp_client_id
  monitoring_reader_sp_client_secret = var.monitoring_reader_sp_client_secret
  user_assigned_identity_resource_id = azurerm_user_assigned_identity.magicaksmsi.id
  location            = var.location
  tenant_id           = data.azurerm_subscription.current.tenant_id
}
