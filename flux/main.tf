resource "null_resource" "deploy_flux" {
  provisioner "local-exec" {
      command = "${path.module}/flux.sh ${var.resource_group_name} ${var.cluster_name} ${var.ghuser} ${var.repo} ${var.pat}" 
  }

  triggers = {
    flux_recreate = var.flux_recreate
  }
}
