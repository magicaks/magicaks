
data "azurerm_key_vault_secret" "registry_username" {
  name      = "adminuser"
  key_vault_id = var.key_vault_id
}

data "azurerm_key_vault_secret" "registry_password" {
  name      = "adminpassword"
  key_vault_id = var.key_vault_id
}

resource "azurerm_container_group" "grafana" {
  name                = "grafana"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  ip_address_type     = "Private"
  network_profile_id = var.aci_network_profile_id
  
  image_registry_credential {
    username = data.azurerm_key_vault_secret.registry_username.value
    password = data.azurerm_key_vault_secret.registry_password.value
    server = "${var.acr_name}.azurecr.io"
  }
  
  diagnostics {
    log_analytics {
        log_type = "ContainerInsights"
        workspace_id = var.log_analytics_workspace_id
        workspace_key = var.log_analytics_workspace_key

    }
  }

  restart_policy = "Always"

  container {
    name   = "grafana"
    image  = "${var.acr_name}.azurecr.io/${var.image_name}"
    cpu    = "1.0"
    memory = "1.5"

    ports {
      port     = 3000
      protocol = "TCP"
    }
    
    environment_variables = {
                              "SUBSCRIPTION_ID" = var.subscription_id, 
                              "TENANT_ID" = var.tenant_id,
                              "CLIENT_ID" = var.client_id
                              "LOG_ANALYTICS_WORKSPACE" = var.log_analytics_workspace_id
                              "GF_DATABASE_TYPE" = "postgres"
                              "GF_DATABASE_USER" = "psqladmin@cluster-support-db"
                              "GF_DATABASE_HOST" = "${var.db_host}:5432"
                              "GF_DATABASE_PASSWORD" = var.db_password
                              "GF_DATABASE_NAME" = var.db_name
                              "GF_DATABASE_SSL_MODE" = "require"
                              "GF_DATABASE_LOG_QUERIES" = "true"
                            }

    secure_environment_variables = {"CLIENT_SECRET" = var.client_secret}
  }
}