# Without this block Terraform infers `hashicorp/digitalocean`, which does not
# exist in the registry, and `terraform init` fails before anything else runs.
terraform {
  required_version = ">= 1.5"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.68"
    }
  }
}
