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
    resource_group_name = var.k8s_rg_name
    location = var.location
    client_id = var.client_id
    client_secret = var.client_secret
}

module flux {
  source = "./flux"
  k8s_rg_name = module.aks.rgname
  cluster_name = module.aks.name
  ghuser = var.ghuser
  repo = var.k8s_manifest_repo
  pat = var.pat
  flux_recreate = true
}

resource "azurerm_eventgrid_domain" "eventgrid" {
  name                = "magicaks-eventgrid"
  location            = var.location
  resource_group_name = var.k8s_rg_name

  tags = {
    environment = "Devlopment"
  }
}

module "expose_event_grid" {
  source = "./expose_event_grid_in_k8s"
  endpoint = azurerm_eventgrid_domain.eventgrid.endpoint
}
