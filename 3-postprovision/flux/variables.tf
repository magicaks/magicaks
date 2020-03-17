variable resource_group_name {
    default = "k8s"
}

variable cluster_name {
    default = "k8s"
}

variable ghuser {}

variable admin_repo {}
variable workload_repo {}

variable pat {}

variable flux_recreate {
    default = false
}
