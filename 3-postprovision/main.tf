terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "aks-${var.cluster_name}-admin"
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    key = "magicaks-postprovision"
  }
}

resource "kubernetes_namespace" "admin" {
  metadata {
    labels = {created-by = "terraform"}
    name = "admin"
  }
}

module flux {
  source        = "./flux"
  github_user   = var.github_user
  github_pat    = var.github_pat
  admin_repo    = var.k8s_manifest_repo
  workload_repo = var.k8s_workload_repo
}

module "servicebus" {
  source        = "./servicebus"
  cluster_name  = var.cluster_name
  location      = var.location
}

resource "azurerm_key_vault_secret" "sbconnectionstring" {
  name         = "servicebus-connectionstring"
  value        = module.servicebus.primary_connection_string
  key_vault_id = var.key_vault_id

  provisioner "local-exec" {
    command = "${path.cwd}/../utils/expose-secret.sh ${self.name} ${var.key_vault_id} ${var.app_name}"
  }

  depends_on = [module.flux]
}