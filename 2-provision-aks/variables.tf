variable "subscription_id" {}
variable "tenant_id" {}

variable resource_group_name {}

variable location {}

variable log_analytics_workspace_name {
    default = "k8sLogAnalyticsWorkspace"
}

variable log_analytics_workspace_sku {
    default = "PerGB2018"
}

variable cluster_name {}

variable "admin_group_object_ids" { }
variable "aad_tenant_id" { }

variable "k8s_subnet_id" { }
variable "aci_subnet_id" { }

variable "aci_network_profile_id" {}
variable "acr_name" {}
variable "key_vault_id" {}

#grafana
variable "grafana_admin_password" {}
variable "cluster_support_db_admin_password" {}
variable "grafana_image_name" {}
variable "monitoring_reader_sp_client_id" {}
variable "monitoring_reader_sp_client_secret" {}
variable "cluster_database_name" {}

variable "user_assigned_identity_resource_id" {}
