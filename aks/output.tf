output "cluster_username" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.username}"
}

output "cluster_password" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.password}"
}

output "host" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.host}"
}

output "rgname" {
    value = "${azurerm_resource_group.k8s.name}"
}

output "name" {
    value = "${azurerm_kubernetes_cluster.k8s.name}"
}