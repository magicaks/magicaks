provider "kubernetes" {
}

provider "helm" {
  kubernetes {
  }
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

  provisioner "local-exec" {
    command = "${path.cwd}/flux/install-keys.sh ${var.ghuser} ${var.admin_repo} ${var.pat} ${kubernetes_namespace.flux-admin.metadata[0].name}"
  }

  depends_on = [kubernetes_namespace.flux-admin]
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

  provisioner "local-exec" {
    command = "${path.cwd}/flux/install-keys.sh ${var.ghuser} ${var.workload_repo} ${var.pat} ${kubernetes_namespace.flux-workloads.metadata[0].name}"
  }

  depends_on = [kubernetes_namespace.flux-admin, 
                helm_release.flux-admin,
                kubernetes_namespace.flux-workloads]
}