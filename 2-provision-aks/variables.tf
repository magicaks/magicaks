variable "cluster_name" {}
variable "location" {}
variable "subscription_id" {}
variable "tenant_id" {}
variable "aad_tenant_id" { }

variable "admin_group_object_ids" { }

variable "k8s_subnet_id" { }
variable "aci_subnet_id" { }

variable "aci_network_profile_id" {}
variable "acr_name" {}
variable "key_vault_id" {}

#grafana
variable "grafana_admin_password" {}
variable "cluster_support_db_admin_password" {}
variable "grafana_image_name" { default = "grafana:v1" }
variable "monitoring_reader_sp_client_id" {}
variable "monitoring_reader_sp_client_secret" {}

variable "user_assigned_identity_resource_id" {}

variable "log_analytics_workspace_name" { default = "k8sLogAnalyticsWorkspace" }
variable "log_analytics_workspace_sku" { default = "PerGB2018" }
