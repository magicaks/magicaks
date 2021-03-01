output "k8s_subnet_id" {
    value = azurerm_subnet.k8s_subnet.id
}

output "aci_subnet_id" {
    value = azurerm_subnet.aci_subnet.id
}

output "aci_network_profile_id" {
    value = azurerm_network_profile.aci_profile.id
}