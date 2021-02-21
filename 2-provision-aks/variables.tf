variable resource_group_name {}
variable location {}
variable subscription_id {}
variable tenant_id {}
variable aad_tenant_id { }

variable cluster_name {}
variable admin_group_object_ids { }
variable k8s_subnet_id { }
variable user_assigned_identity_resource_id {}

variable key_vault_id {}

#grafana
variable acr_name {} # ACR from where to pull grafana image
variable grafana_image_name {}
variable grafana_admin_password {}
variable monitoring_reader_sp_client_id {}
variable monitoring_reader_sp_client_secret {}

# postgres
variable cluster_database_name {}
variable cluster_support_db_admin_password {}
variable aci_subnet_id { } # Allow this ACI access to DB
variable aci_network_profile_id {}

variable log_analytics_workspace_name {
    default = "k8sLogAnalyticsWorkspace"
}
variable log_analytics_workspace_sku {
    default = "PerGB2018"
}
