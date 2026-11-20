terraform {
  required_version = ">= 1.9"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 8.0" }
    helm   = { source = "hashicorp/helm", version = "~> 3.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }

  # Partial config: the bucket is passed at init time with
  #   terraform init -backend-config="bucket=<PROJECT_ID>-tfstate"
  backend "gcs" {
    prefix = "platform"
  }
}

provider "google" {
  project = var.project_id
}

data "google_client_config" "this" {}

data "google_container_cluster" "obs" {
  name     = var.cluster_name
  location = var.zone
}

# Helm provider 3.x: `kubernetes` and `set_sensitive` are attributes (=), not blocks.
provider "helm" {
  kubernetes = {
    host                   = "https://${data.google_container_cluster.obs.endpoint}"
    token                  = data.google_client_config.this.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.obs.master_auth[0].cluster_ca_certificate)
  }
}

resource "random_password" "grafana" {
  length  = 24
  special = false
}

resource "helm_release" "kps" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.kube_prometheus_stack_version
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 900
  values           = [file("${path.module}/values/kube-prometheus-stack.yaml")]

  set_sensitive = [{
    name  = "grafana.adminPassword"
    value = random_password.grafana.result
  }]
}
