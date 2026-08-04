terraform {
  required_version = ">= 1.5"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    # Only used to look up the cluster (data-sources.tf). All four are
    # declared because any workspace may select any cloud; only the one
    # matching the workspace actually reads anything.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.68"
    }
  }
}

# Cloud providers, configured only enough to resolve the cluster lookup.
# Credentials come from the ambient chain (env vars, aws configure, az login,
# gcloud ADC, DIGITALOCEAN_TOKEN) exactly as the infra layer's do.

provider "aws" {
  region = var.region != "" ? var.region : null
}

provider "google" {
  project = var.gcp_project != "" ? var.gcp_project : null
}

provider "azurerm" {
  features {}
}

provider "digitalocean" {}

# All three providers connect straight to the cluster API. Endpoint and CA come
# from the infra layer's state for THIS workspace (see remote-state.tf), and the
# exec block mints a fresh token on every API call via the cloud's own CLI.
#
# Previously these read ~/.kube/config, which is not tied to the selected
# workspace: planning aws-dev while the current context was the GCP cluster
# proposed writing a StorageClass into GCP. Nothing here reads that file now, so
# the addon layer can only ever talk to the cluster the workspace names.
#
# exec also avoids the expiry problem — a kubeconfig token baked in at plan time
# can go stale during a long apply.

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca_certificate

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = local.exec_auth.command
    args        = local.exec_auth.args
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = local.cluster_ca_certificate

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = local.exec_auth.command
      args        = local.exec_auth.args
    }
  }
}

provider "kubectl" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = local.cluster_ca_certificate

  # Without this the provider still falls back to ~/.kube/config.
  load_config_file = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = local.exec_auth.command
    args        = local.exec_auth.args
  }
}
