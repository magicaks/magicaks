
resource "kubernetes_namespace" "admin" {
  metadata {
    labels = {
      created-by = "terraform"
    }
    name = "admin"
  }
}

module flux {
  source = "./flux"
  resource_group_name = var.resource_group_name
  cluster_name = var.cluster_name
  ghuser = var.ghuser
  admin_repo = var.k8s_manifest_repo
  workload_repo = var.k8s_workload_repo
  pat = var.pat
  app_name = var.app_name
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
      "get", "set"
    ]

    storage_permissions = [
      "get", "set"
    ]
  }

  # Access policy for this particular TF run to insert the secret into kv
  access_policy {
    tenant_id = var.tenant_id
    object_id = "3fe3253a-c76e-42aa-ac6a-88a31f287403"

    key_permissions = [
      "get", "create", "delete"
    ]

    secret_permissions = [
      "get", "set", "delete"
    ]

    storage_permissions = [
      "get", "set", "delete"
    ]
  }

  sku_name = "standard"
}

module "servicebus" {  
  source = "./servicebus"
  resource_group_name = var.resource_group_name
  cluster_name = var.cluster_name
  location = var.location
  keyvault_id = azurerm_key_vault.keyvault.id
  keyvault_name = azurerm_key_vault.keyvault.name
}

resource "azurerm_key_vault_secret" "sbconnectionstring" {
  name         = "${var.cluster_name}-servicebus-connectionstring"
  value        = module.servicebus.primary_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id

  provisioner "local-exec" {
    command = "${path.cwd}/../utils/expose-secret.sh ${self.name} ${azurerm_key_vault.keyvault.name} ${var.app_name}"
  }

  depends_on = [module.flux]
}