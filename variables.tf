variable "client_id" {}
variable "client_secret" {}
variable tenant_id {}

variable "agent_count" {
    default = 1
}

variable "dns_prefix" {
    default = "sakunduk8s"
}

variable cluster_name {
    default = "k8s"
}

variable resource_group_name {
    default = "k8s"
}

variable location {
    default = "West Europe"
}

variable ghuser {
    default = "sachinkundu"
}

variable k8s_manifest_repo {}

variable pat {}

variable flux_recreate {
    default = false
}

variable "aad_client_appid" { }
variable "aad_server_appid" { }
variable "aad_server_app_secret" { }
variable "aad_tenant_id" { }
variable "k8s_subnet_id" { }