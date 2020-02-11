provider "azurerm" {
    version = "~>1.5"
}

terraform {
  backend "azurerm" {
    container_name = "tfstate"
    key = "magicaks"
    storage_account_name = "longlasting"
  }
}

module "aks" {
    source = "./aks"
    agent_count = var.agent_count
    dns_prefix = var.dns_prefix
    cluster_name = var.cluster_name
    resource_group_name = var.resource_group_name
    location = var.location
    client_id = var.client_id
    client_secret = var.client_secret
}

module flux {
  source = "./flux"
  resource_group_name = module.aks.rgname
  cluster_name = module.aks.name
  ghuser = var.ghuser
  repo = var.k8s_manifest_repo
  pat = var.pat
  flux_recreate = true
}

resource "azurerm_servicebus_namespace" "servicebus" {
  name                = "${var.cluster_name}-servicebus"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  tags = {
    source = "terraform"
    environment = "Development"
  }
}