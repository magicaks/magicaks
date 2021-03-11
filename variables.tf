variable "resource_group_name" {}
variable "location" {}
variable "resource_suffix" {}
variable "cluster_name" {}

variable "aad_tenant_id" { }
variable "admin_group_object_ids" { }

variable "cluster_support_db_admin_password" {}

variable "grafana_image_name" { default = "grafana:v1" }
variable "grafana_admin_password" {}

variable "monitoring_reader_sp_client_id" {}
variable "monitoring_reader_sp_client_secret" {}

variable "github_pat" {}
variable "github_user" {}

variable "k8s_manifest_repo" {}
variable "k8s_workload_repo" {}
variable "app_name" {}
