variable "resource_group_name" {}
variable "location" {}
variable "agent_count" {
    default = 1
}

variable "ssh_public_key" {
    default = "~/.ssh/id_rsa.pub"
}

variable "dns_prefix" { }

variable cluster_name { }

variable "log_analytics_workspace_id" {}

variable "aad_tenant_id" {}
variable "k8s_subnet_id" {}
variable "admin_group_object_ids" {}
variable "user_assigned_identity_resource_id" {}
