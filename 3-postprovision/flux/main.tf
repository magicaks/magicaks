provider "kubernetes" {
}

provider "helm" {
  kubernetes {
  }
}

provider "github" {
  token = var.pat
  individual = "false"
  organization = var.ghuser
}

resource "kubernetes_namespace" "flux-admin" {
  metadata {
    labels = {
      created-by = "terraform"
    }
    name = "flux-admin"
  }
}

data "helm_repository" "incubator" {
  name = "fluxcd"
  url  = "https://charts.fluxcd.io"
}

resource "helm_release" "flux-admin" {
  name  = "flux-admin"
  chart = "fluxcd/flux"
  namespace = kubernetes_namespace.flux-admin.metadata[0].name
   values = [
    file("${path.cwd}/flux/values.yaml")
  ]

  
  set {
    name = "git.url"
    value = "git@github.com:${var.ghuser}/${var.admin_repo}.git"
  }

  set {
    name = "git.user"
    value = var.ghuser
  }

  set {
    name = "git.email"
    value = "${var.ghuser}@users.noreply.github.com"
  }

  set {
    name = "git.path"
    value = "dev"
  }

  depends_on = [kubernetes_namespace.flux-admin]
}

data "external" "flux_admin_key" {
  program = ["sh", "${path.cwd}/flux/fluxkey.sh"]
  query = {
    namespace = kubernetes_namespace.flux-admin.metadata[0].name
  }

  depends_on = [helm_release.flux-admin]
}

# Add a deploy key
resource "github_repository_deploy_key" "flux-admin" {
  title      = "flux-admin-${formatdate("D-M-YY", timestamp())}"
  repository = var.admin_repo
  key        = data.external.flux_admin_key.result["key"]
  read_only  = "false"

  depends_on = [helm_release.flux-admin]
}

resource "kubernetes_namespace" "flux-workloads" {
  metadata {
    labels = {
      created-by = "terraform"
    }
    name = "flux-workloads"
  }
}

resource "helm_release" "flux-workloads" {
  name  = "flux-workloads"
  chart = "fluxcd/flux"
  namespace = kubernetes_namespace.flux-workloads.metadata[0].name
   values = [
    file("${path.cwd}/flux/values.yaml"),
    file("${path.cwd}/flux/values-workloads.yaml")
  ]

  
  set {
    name = "git.url"
    value = "git@github.com:${var.ghuser}/${var.workload_repo}.git"
  }

  set {
    name = "git.user"
    value = var.ghuser
  }

  set {
    name = "git.email"
    value = "${var.ghuser}@users.noreply.github.com"
  }

  set {
    name = "git.path"
    value = "dev"
  }

  depends_on = [kubernetes_namespace.flux-admin, 
                helm_release.flux-admin]
}

data "external" "flux_workload_key" {
  program = ["sh", "${path.cwd}/flux/fluxkey.sh"]
  query = {
    namespace = kubernetes_namespace.flux-workloads.metadata[0].name
  }
  depends_on = [helm_release.flux-workloads]
}

# Add a deploy key
resource "github_repository_deploy_key" "flux-workloads" {
  title      = "flux-workloads-${formatdate("D-M-YY", timestamp())}"
  repository = var.workload_repo
  key        = data.external.flux_workload_key.result["key"]
  read_only  = "false"

  depends_on = [helm_release.flux-workloads]
}
