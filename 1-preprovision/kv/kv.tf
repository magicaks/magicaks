data "azurerm_client_config" "current" {
}

resource "azurerm_key_vault" "keyvault" {
  name                        = "${var.cluster_name}-keyvault"
  location                    = var.location
  tenant_id                   = var.tenant_id
  resource_group_name         = var.resource_group_name
  
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true

  # TODO check and confirm the iffyness of this block!
  network_acls {
    bypass = "AzureServices"
    default_action = "Allow"
    virtual_network_subnet_ids = [var.k8s_subnet_id]
  }

  # Access policy for service principal credentials on the cluster to access kv.
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.client_id

    key_permissions = [
      "get", "create"
    ]

    secret_permissions = [
      "get", "set", "recover", "purge"
    ]

    storage_permissions = [
      "get", "set"
    ]
  }

  # Access policy for this particular TF run to insert the secret into kv
  access_policy {
    tenant_id = var.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "get", "create", "delete"
    ]

    secret_permissions = [
      "get", "set", "delete", "recover", "purge"
    ]

    storage_permissions = [
      "get", "set", "delete"
    ]
  }

  sku_name = "standard"
}
