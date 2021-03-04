data "external" "flux_admin_key" {
  program = ["bash", "${path.cwd}/fluxfiles/fluxkey.sh"]
  query = {
    namespace = var.admin_namespace
  }
}

data "external" "flux_workload_key" {
  program = ["bash", "${path.cwd}/fluxfiles/fluxkey.sh"]
  query = {
    namespace = var.workload_namespace
  }
}

# Add a deploy key
resource "github_repository_deploy_key" "flux-admin" {
  title      = "flux-admin-${formatdate("D-M-YY", timestamp())}"
  repository = var.admin_repo
  key        = data.external.flux_admin_key.result["key"]
  read_only  = "false"
}

# Add a deploy key
resource "github_repository_deploy_key" "flux-workloads" {
  title      = "flux-workloads-${formatdate("D-M-YY", timestamp())}"
  repository = var.workload_repo
  key        = data.external.flux_workload_key.result["key"]
  read_only  = "false"
}
