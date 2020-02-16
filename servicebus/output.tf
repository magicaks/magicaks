output "primary_connection_string" {
    value = azurerm_servicebus_namespace.servicebus.default_primary_connection_string
}
