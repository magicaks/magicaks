terraform {
  backend "azurerm" {
    key = "magicaks-provision"
  }
}

resource "azurerm_resource_group" "cluster_rg" {
  name     = "rg-${var.cluster_name}"
  location = var.location
}

resource "azurerm_policy_assignment" "base_k8s_policy" {
  name                 = "basek8spolicy"
  scope                = azurerm_resource_group.cluster_rg.id
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/a8640138-9b0a-4a28-b8cb-1666c838647d"
  description          = ""
  display_name         = "Kubernetes cluster pod security baseline standards for Linux-based workloads"
  parameters = <<PARAMETERS
{
  "excludedNamespaces": {
    "value": ["kube-system","gatekeeper-system","admin"]
  }
}
PARAMETERS
}

resource "azurerm_postgresql_server" "cluster_support_db" {
  name                              = "psql-${var.cluster_name}"
  location                          = azurerm_resource_group.cluster_rg.location
  resource_group_name               = azurerm_resource_group.cluster_rg.name

  sku_name                          = "GP_Gen5_4"
  version                           = "9.6"
  storage_mb                        = 640000

  backup_retention_days             = 7
  geo_redundant_backup_enabled      = true
  auto_grow_enabled                 = true

  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"

  administrator_login               = "psqladmin"
  administrator_login_password      = var.cluster_support_db_admin_password
}

resource "azurerm_postgresql_database" "grafana_db" {
  name                = "grafana"
  resource_group_name = azurerm_postgresql_server.cluster_support_db.resource_group_name
  server_name         = azurerm_postgresql_server.cluster_support_db.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_virtual_network_rule" "aci_access_rule" {
  name                = "aciaccess"
  resource_group_name = azurerm_postgresql_server.cluster_support_db.resource_group_name
  server_name         = azurerm_postgresql_server.cluster_support_db.name
  subnet_id           = var.aci_subnet_id
}

resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "k8s_analytics_workspace" {
    name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = var.location
    resource_group_name = azurerm_resource_group.cluster_rg.name
    sku                 = var.log_analytics_workspace_sku
}

resource "azurerm_log_analytics_solution" "k8s_analytics_solution" {
    solution_name         = "ContainerInsights"
    location              = azurerm_log_analytics_workspace.k8s_analytics_workspace.location
    resource_group_name   = azurerm_resource_group.cluster_rg.name
    workspace_resource_id = azurerm_log_analytics_workspace.k8s_analytics_workspace.id
    workspace_name        = azurerm_log_analytics_workspace.k8s_analytics_workspace.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

module "aks" {
  source                              = "./aks"
  resource_group_name                 = azurerm_resource_group.cluster_rg.name
  location                            = var.location
  cluster_name                        = var.cluster_name
  k8s_subnet_id                       = var.k8s_subnet_id
  admin_group_object_ids              = var.admin_group_object_ids
  aad_tenant_id                       = var.aad_tenant_id
  log_analytics_workspace_id          = azurerm_log_analytics_workspace.k8s_analytics_workspace.id
  user_assigned_identity_resource_id  = var.user_assigned_identity_resource_id
}

resource "azurerm_key_vault_access_policy" "cluster_msi_read" {
  key_vault_id        = var.key_vault_id
  tenant_id           = var.tenant_id
  object_id           = module.aks.cluster_object_id
  secret_permissions  = ["Get"]
}

module "grafana" {
  source                      = "./grafana"
  location                    = var.location
  resource_group_name 	      = azurerm_resource_group.cluster_rg.name

  # send container logs to the same log analytics workspace as the cluster.
  log_analytics_workspace_id  = azurerm_log_analytics_workspace.k8s_analytics_workspace.workspace_id
  log_analytics_workspace_key = azurerm_log_analytics_workspace.k8s_analytics_workspace.primary_shared_key

  # where is the custom grafana image
  acr_name                    = var.acr_name
  image_name                  = var.grafana_image_name
  grafana_admin_password      = var.grafana_admin_password

  # postgres info
  db_host                     = azurerm_postgresql_server.cluster_support_db.fqdn
  db_name                     = azurerm_postgresql_database.grafana_db.name
  db_user                     = "${azurerm_postgresql_server.cluster_support_db.administrator_login}@${azurerm_postgresql_server.cluster_support_db.name}"
  db_password                 = var.cluster_support_db_admin_password

  # delegated subnet for aci, hence a network profile
  aci_network_profile_id      = var.aci_network_profile_id

  # credentials for acr
  key_vault_id                = var.key_vault_id

  # information for connecting to the cluster from grafana.
  subscription_id             = var.subscription_id
  tenant_id                   = var.tenant_id

  # service principal for monitoring
  client_id                   = var.monitoring_reader_sp_client_id
  client_secret               = var.monitoring_reader_sp_client_secret
}