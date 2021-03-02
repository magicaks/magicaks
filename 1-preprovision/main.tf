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

resource "azurerm_resource_group" "shared_rg" {
  name     = var.resource_group_name
  location = var.location
}

module "networking" {
  source = "./networking"
  location = var.location
  resource_group_name = azurerm_resource_group.shared_rg.name
  resource_suffix = var.resource_suffix
}

module "acr" {
  source = "./acr"
  location = var.location
  resource_group_name = azurerm_resource_group.shared_rg.name
  subnet_id = module.networking.k8s_subnet_id
  resource_suffix = var.resource_suffix
}

module "kv" {
  source = "./kv"
  location = var.location
  resource_group_name = azurerm_resource_group.shared_rg.name
  k8s_subnet_id = module.networking.k8s_subnet_id
  resource_suffix = var.resource_suffix
  tenant_id = var.tenant_id
}

resource "azurerm_key_vault_secret" "registry_username" {
  name         = "adminuser"
  value        = module.acr.admin_username
  key_vault_id = module.kv.key_vault_id
}

resource "azurerm_key_vault_secret" "registry_password" {
  name         = "adminpassword"
  value        = module.acr.admin_password
  key_vault_id = module.kv.key_vault_id
}
