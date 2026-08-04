# Required for correctness, not just tidiness: a child module that uses a
# resource prefix without declaring its source makes Terraform infer
# `hashicorp/<prefix>`. For digitalocean that registry entry does not exist and
# `terraform init` fails outright, so every module here declares its providers.
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
