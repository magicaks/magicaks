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
}

module "servicebus" {  
  source = "./servicebus"
  resource_group_name = var.resource_group_name
  cluster_name = var.cluster_name
  location = var.location
}

resource "azurerm_key_vault_secret" "sbconnectionstring" {
  name         = "servicebus-connectionstring"
  value        = module.servicebus.primary_connection_string
  key_vault_id = var.key_vault_id

  provisioner "local-exec" {
    command = "${path.cwd}/../utils/expose-secret.sh ${self.name} magicaks-keyvault ${var.app_name}"
  }

  depends_on = [module.flux]
}