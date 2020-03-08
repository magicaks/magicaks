output "admin_username" {
    value = azurerm_container_registry.acr.admin_username
}

output "admin_password" {
    value = azurerm_container_registry.acr.admin_password
}

output "login_server" {
    value = azurerm_container_registry.acr.login_server
}