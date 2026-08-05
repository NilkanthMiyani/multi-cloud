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

# ------------------------------------------------------------------------
# Cloud providers — used only to look up the cluster (data-sources.tf)
# ------------------------------------------------------------------------
# Credentials are wired exactly as the infra layer wires them, from the same
# ../envs/<cloud>.tfvars. Blank falls back to the ambient chain (env vars,
# aws configure, az login, gcloud ADC, DIGITALOCEAN_TOKEN).

provider "aws" {
  region     = var.region != "" ? var.region : null
  access_key = var.aws_access_key != "" ? var.aws_access_key : null
  secret_key = var.aws_secret_key != "" ? var.aws_secret_key : null
}

provider "google" {
  project     = var.gcp_project != "" ? var.gcp_project : null
  region      = var.gcp_region != "" ? var.gcp_region : null
  credentials = var.gcp_credentials != "" ? file(var.gcp_credentials) : null
}

provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id != "" ? var.azure_subscription_id : null
  tenant_id       = var.azure_tenant_id != "" ? var.azure_tenant_id : null
  client_id       = var.azure_client_id != "" ? var.azure_client_id : null
  client_secret   = var.azure_client_secret != "" ? var.azure_client_secret : null
}

provider "digitalocean" {
  token = var.do_token != "" ? var.do_token : null
}


# ------------------------------------------------------------------------
# Kubernetes providers — connect straight to the cluster API
# ------------------------------------------------------------------------
# Endpoint and CA come from the cloud lookup in data-sources.tf; exec mints a
# fresh token per API call via the cloud's own CLI, so nothing expires
# mid-apply. Nothing here reads ~/.kube/config, which is not tied to the
# selected workspace — planning aws-dev while the current context was GCP once
# proposed writing a StorageClass into the wrong cluster.

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
