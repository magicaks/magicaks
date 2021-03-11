variable "resource_group_name" {}
variable "location" {}
variable "resource_suffix" {}
variable "cluster_name" {}
variable "aad_tenant_id" { }
variable "admin_group_object_ids" { }
variable "grafana_admin_password" {}
variable "cluster_support_db_admin_password" {}
variable "grafana_image_name" { default = "grafana:v1" }
variable "monitoring_reader_sp_client_id" {}
variable "monitoring_reader_sp_client_secret" {}
