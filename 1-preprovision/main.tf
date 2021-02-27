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
    key = "magicaks-preprovision"
  }
}

resource "azurerm_resource_group" "longlasting" {
  name     = var.resource_group_name
  location = var.location
}

module "networking" {
  source = "./networking"
  location = var.location
  resource_group_name = azurerm_resource_group.longlasting.name
  cluster_name = var.cluster_name
}

module "acr" {
  source = "./acr"
  location = var.location
  resource_group_name = azurerm_resource_group.longlasting.name
  subnet_id = module.networking.k8s_subnet_id
  cluster_name = var.cluster_name
}

module "kv" {
  source = "./kv"
  location = var.location
  resource_group_name = azurerm_resource_group.longlasting.name
  k8s_subnet_id = module.networking.k8s_subnet_id
  cluster_name = var.cluster_name
  tenant_id = var.tenant_id
}

resource "azurerm_key_vault_secret" "registryusername" {
  name         = "adminuser"
  value        = module.acr.admin_username
  key_vault_id = module.kv.id
}

resource "azurerm_key_vault_secret" "registrypassword" {
  name         = "adminpassword"
  value        = module.acr.admin_password
  key_vault_id = module.kv.id
}
