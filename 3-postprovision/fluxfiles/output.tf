output "admin_namespace" {
    value = kubernetes_namespace.flux-admin.metadata[0].name
}

output "workload_namespace" {
    value = kubernetes_namespace.flux-workloads.metadata[0].name
}