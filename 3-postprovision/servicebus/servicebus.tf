resource "azurerm_servicebus_namespace" "servicebus" {
  name                = "${var.cluster_name}-servicebus2"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  tags = {
    source = "terraform"
    environment = "Development"
  }
}