
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
    image  = "${var.acr_name}/grafana:v1"
    cpu    = "1.0"
    memory = "1.5"

    ports {
      port     = 3000
      protocol = "TCP"
    }
    
    # environment_variables ["name=value"]

    # secure_environment_variables ["name=value"]

    volume {
        name = "grafana-storage"
        mount_path = "/var/lib/grafana"
        storage_account_name = var.storage_account_name
        storage_account_key = var.storage_account_key
        share_name = var.share_name
    }
  }
}