provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "kubernetes_namespace" "flux-admin" {
  metadata {
    labels  = {created-by = "terraform"}
    name    = "flux-admin"
  }
}

resource "helm_release" "flux-admin" {
  name        = "flux-admin"
  chart       = "flux"
  repository  = "https://charts.fluxcd.io/"
  namespace   = kubernetes_namespace.flux-admin.metadata[0].name
   values     = [file("${path.cwd}/fluxfiles/values.yaml")]

  set {
    name  = "git.url"
    value = "git@github.com:${var.github_user}/${var.admin_repo}.git"
  }

  set {
    name  = "git.user"
    value = var.github_user
  }

  set {
    name  = "git.email"
    value = "${var.github_user}@users.noreply.github.com"
  }

  set {
    name  = "git.path"
    value = "dev"
  }

  set {
    name  = "git.pollInterval"
    value = "2m"
  }

  set {
    name  = "sync.timeout"
    value = "2m"
  }

  depends_on = [kubernetes_namespace.flux-admin]
}

resource "kubernetes_namespace" "flux-workloads" {
  metadata {
    labels  = {created-by = "terraform"}
    name    = "flux-workloads"
  }
}

resource "helm_release" "flux-workloads" {
  name        = "flux-workloads"
  chart       = "flux"
  repository  = "https://charts.fluxcd.io/"
  namespace   = kubernetes_namespace.flux-workloads.metadata[0].name
  values      = [
    file("${path.cwd}/fluxfiles/values.yaml"),
    file("${path.cwd}/fluxfiles/values-workloads.yaml")
  ]

  set {
    name  = "git.url"
    value = "git@github.com:${var.github_user}/${var.workload_repo}.git"
  }

  set {
    name  = "git.user"
    value = var.github_user
  }

  set {
    name  = "git.email"
    value = "${var.github_user}@users.noreply.github.com"
  }

  set {
    name  = "git.path"
    value = "dev"
  }

  set {
    name  = "git.pollInterval"
    value = "2m"
  }

  set {
    name  = "sync.timeout"
    value = "2m"
  }

  depends_on = [kubernetes_namespace.flux-admin, helm_release.flux-admin]
}
