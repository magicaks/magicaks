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

resource "azurerm_resource_group" "rg" {
    name     = var.resource_group_name
    location = var.location
}

module "aks" {
    source = "./aks"
    agent_count = var.agent_count
    dns_prefix = var.dns_prefix
    cluster_name = var.cluster_name
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    client_id = var.client_id
    client_secret = var.client_secret
    aad_client_appid = var.aad_client_appid
    aad_server_appid = var.aad_server_appid
    aad_server_app_secret = var.aad_server_app_secret
    aad_tenant_id = var.aad_tenant_id
    k8s_subnet_id = var.k8s_subnet_id
}

