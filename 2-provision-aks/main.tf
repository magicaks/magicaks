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
    resource_group_name  = "magicaks"
    container_name = "tfstate"
    key = "magicaks-cluster"
    storage_account_name = "longlasting"
  }
}

resource "azurerm_resource_group" "rg" {
    name     = var.resource_group_name
    location = var.location
}

resource "azurerm_postgresql_server" "clustersupportdb" {
  name                = var.cluster_database_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name   = "GP_Gen5_4"
  version    = "9.6"
  storage_mb = 640000

  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  public_network_access_enabled    = true
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"

  administrator_login          = "psqladmin"
  administrator_login_password = var.cluster_support_db_admin_password
}

resource "azurerm_postgresql_database" "grafana" {
  name                = "grafana"
  resource_group_name = azurerm_postgresql_server.clustersupportdb.resource_group_name
  server_name         = azurerm_postgresql_server.clustersupportdb.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_virtual_network_rule" "aciaccess" {
  name                                 = "aciaccess"
  resource_group_name                  = azurerm_postgresql_server.clustersupportdb.resource_group_name
  server_name                          = azurerm_postgresql_server.clustersupportdb.name
  subnet_id                            = var.aci_subnet_id
}

resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "k8s" {
    name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
    sku                 = var.log_analytics_workspace_sku
}

resource "azurerm_log_analytics_solution" "k8s" {
    solution_name         = "ContainerInsights"
    location              = azurerm_log_analytics_workspace.k8s.location
    resource_group_name   = azurerm_resource_group.rg.name
    workspace_resource_id = azurerm_log_analytics_workspace.k8s.id
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
  cluster_name = var.cluster_name
  dns_prefix = var.cluster_name
  
  k8s_subnet_id = var.k8s_subnet_id
  
  admin_group_object_ids = var.admin_group_object_ids
  aad_tenant_id = var.aad_tenant_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.k8s.id
  user_assigned_identity_resource_id = var.user_assigned_identity_resource_id
}

resource "azurerm_key_vault_access_policy" "clustermsiread" {
  key_vault_id = var.key_vault_id
  tenant_id    = var.tenant_id
  object_id    =  module.aks.object_id

  secret_permissions = [
    "Get",
  ]
}

module "grafana" {
  source = "./grafana"
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  
  # Send container logs to the same log analytics workspace as the cluster.
  log_analytics_workspace_id = azurerm_log_analytics_workspace.k8s.workspace_id
  log_analytics_workspace_key = azurerm_log_analytics_workspace.k8s.primary_shared_key


  grafana_admin_password = var.grafana_admin_password
  
  db_host = azurerm_postgresql_server.clustersupportdb.fqdn
  db_password = var.cluster_support_db_admin_password
  db_name = azurerm_postgresql_database.grafana.name
  
  # delegated subnet for aci, hence a network profile
  aci_network_profile_id = var.aci_network_profile_id
  
  # Where is the custom grafana image
  acr_name = var.acr_name

  #Credentials for acr are stored here
  key_vault_id = var.key_vault_id
  
  # Information for connecting to the cluster from grafana.
  subscription_id = var.subscription_id
  tenant_id = var.tenant_id
  
  client_id = var.monitoring_reader_sp_client_id
  client_secret = var.monitoring_reader_sp_client_secret
  
  image_name = var.grafana_image_name
}