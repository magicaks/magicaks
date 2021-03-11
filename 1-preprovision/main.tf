module "networking" {
  source              = "./networking"
  location            = var.location
  resource_group_name = var.resource_group_name
  resource_suffix     = var.resource_suffix
}
  
# networking resources take time to transition to created state.
resource "time_sleep" "network_creation" {
  create_duration = "60s"

  triggers = {
    subnet_id  = module.networking.k8s_subnet_id
  }
}

module "acr" {
  source              = "./acr"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = time_sleep.network_creation.triggers["subnet_id"]
  resource_suffix     = var.resource_suffix
}

module "kv" {
  source              = "./kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  k8s_subnet_id       = time_sleep.network_creation.triggers["subnet_id"]
  resource_suffix     = var.resource_suffix
  tenant_id           = var.tenant_id
}

resource "azurerm_key_vault_secret" "registry_username" {
  name         = "adminuser"
  value        = module.acr.admin_username
  key_vault_id = module.kv.key_vault_id
}

resource "azurerm_key_vault_secret" "registry_password" {
  name         = "adminpassword"
  value        = module.acr.admin_password
  key_vault_id = module.kv.key_vault_id
}
