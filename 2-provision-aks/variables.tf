variable "client_id" {}
variable "client_secret" {}

variable "agent_count" {
    default = 1
}

variable "ssh_public_key" {
    default = "~/.ssh/id_rsa.pub"
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

variable log_analytics_workspace_name {
    default = "k8sLogAnalyticsWorkspace"
}

variable log_analytics_workspace_location {
    default = "westeurope"
}

variable log_analytics_workspace_sku {
    default = "PerGB2018"
}

variable "aad_client_appid" { }
variable "aad_server_appid" { }
variable "aad_server_app_secret" { }
variable "aad_tenant_id" { }
variable "k8s_subnet_id" { }