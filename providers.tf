terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.68"
    }
  }
}


provider "aws" {
  region = var.region

  # Blank keys fall back to the standard AWS credential chain (env vars, shared
  # config/credentials file, instance profile, etc.).
  access_key = var.aws_access_key != "" ? var.aws_access_key : null
  secret_key = var.aws_secret_key != "" ? var.aws_secret_key : null
}

provider "azurerm" {
  features {}

  # Blank values fall back to `az login` / ARM_* environment variables.
  subscription_id = var.azure_subscription_id != "" ? var.azure_subscription_id : null
  tenant_id       = var.azure_tenant_id != "" ? var.azure_tenant_id : null
  client_id       = var.azure_client_id != "" ? var.azure_client_id : null
  client_secret   = var.azure_client_secret != "" ? var.azure_client_secret : null
}

provider "google" {
  project = var.gcp_project != "" ? var.gcp_project : null
  region  = var.gcp_region

  # Blank credentials fall back to Application Default Credentials.
  credentials = var.gcp_credentials != "" ? file(var.gcp_credentials) : null
}

provider "digitalocean" {
  # Blank token falls back to the DIGITALOCEAN_TOKEN / DIGITALOCEAN_ACCESS_TOKEN
  # environment variables.
  token = var.do_token != "" ? var.do_token : null
}
