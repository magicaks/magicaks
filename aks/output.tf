output "name" {
    value = "${azurerm_kubernetes_cluster.k8s.name}"
}

output "subnet_id" {
    value = "${azurerm_subnet.k8s-subnet.id}"
}