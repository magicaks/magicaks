provider "azurerm" {
    version = "~>1.5"
}

terraform {
  backend "azurerm" {
    container_name = "tfstate"
    key = "magicaks-cluster"
    storage_account_name = "longlasting"
  }
}

resource "azurerm_resource_group" "rg" {
    name     = var.resource_group_name
    location = var.location
}

resource "azurerm_storage_account" "clustertempstorage" {
  name                     = "clustertempstorage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "grafanastorage" {
  name                 = "grafanastorage"
  storage_account_name = azurerm_storage_account.clustertempstorage.name
  quota                = 50
}

resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "k8s" {
    name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = var.log_analytics_workspace_location
    resource_group_name = var.resource_group_name
    sku                 = var.log_analytics_workspace_sku
}

resource "azurerm_log_analytics_solution" "k8s" {
    solution_name         = "ContainerInsights"
    location              = azurerm_log_analytics_workspace.k8s.location
    resource_group_name   = var.resource_group_name
    workspace_resource_id = azurerm_log_analytics_workspace.k8s.workspace_id
    workspace_name        = azurerm_log_analytics_workspace.k8s.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

module "aks" {
  source = "./aks"
  resource_group_name = azurerm_resource_group.rg.name
  location = var.location
  k8s_subnet_id = var.k8s_subnet_id
  client_id = var.client_id
  client_secret = var.client_secret
  aad_client_appid = var.aad_client_appid
  aad_server_appid = var.aad_server_appid
  aad_server_app_secret = var.aad_server_app_secret
  aad_tenant_id =var.aad_tenant_id
  cluster_name = var.cluster_name
  dns_prefix = var.dns_prefix
  log_analytics_workspace_id = azurerm_log_analytics_workspace.k8s.workspace_id
}

module "grafana" {
  source = "./grafana"
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.k8s.id
  log_analytics_workspace_key = azurerm_log_analytics_workspace.k8s.primary_shared_key
  grafana_admin_password = var.grafana_admin_password
  storage_account_name = azurerm_storage_account.clustertempstorage.name
  storage_account_key = azurerm_storage_account.clustertempstorage.primary_access_key
  share_name = azurerm_storage_share.grafanastorage.name
  aci_network_profile_id = var.aci_network_profile_id
  acr_name = var.acr_name
  key_vault_id = var.key_vault_id
}