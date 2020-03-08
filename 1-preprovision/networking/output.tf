output "k8s_subnet_id" {
    value = azurerm_subnet.k8s-subnet.id
}

output "network_profile_id" {
    value = azurerm_network_profile.aciprofile.id
}