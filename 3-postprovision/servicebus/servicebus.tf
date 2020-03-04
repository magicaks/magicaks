resource "azurerm_servicebus_namespace" "servicebus" {
  name                = "${var.cluster_name}-servicebus"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  tags = {
    source = "terraform"
    environment = "Development"
  }
}