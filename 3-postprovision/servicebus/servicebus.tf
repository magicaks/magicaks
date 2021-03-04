resource "azurerm_servicebus_namespace" "servicebus" {
  name                = "aks-${var.cluster_name}-servicebus"
  location            = var.location
  resource_group_name = "rg-${var.cluster_name}"
  sku                 = "Standard"

  tags = {
    source      = "terraform"
    environment = "Development"
  }
}