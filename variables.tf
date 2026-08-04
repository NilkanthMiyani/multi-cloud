variable "cluster_name" {
  description = "Name of the managed Kubernetes cluster."
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes control plane version (e.g. 1.30)."
  type        = string
}

# --- Generic (shared across all clouds) ------------------------------------

variable "project" {
  description = "Name to be used on all the resources as identifier. e.g. Project name, Application name"
  type        = string
  default     = "prod-prod"
}

variable "region" {
  description = "AWS region (e.g. us-east-1). Azure uses var.location; GCP uses var.gcp_region."
  type        = string
  default     = "us-east-1"
}

variable "node_size" {
  description = "Machine type for the default node pool. Cloud-specific: AWS t3.medium, Azure Standard_D2s_v3, GCP e2-standard-2."
  type        = string
  default     = "t3.medium"
}

variable "node_count" {
  description = "Number of nodes in the default node pool."
  type        = number
  default     = 2
}

variable "tags" {
  description = "A map of tags to add to all resources. GCP labels must be lowercase, so the gcp workspace's tfvars uses lowercase keys/values."
  type        = map(string)
  default = {
    "project" = "prod-prod"
  }
}

# --- AWS / EKS -------------------------------------------------------------
# Flat variables (only consumed in the "aws" workspace).

variable "aws_access_key" {
  description = "AWS access key. Leave blank to use the standard credential chain (env vars, shared config, instance profile)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret key. Leave blank to use the standard credential chain (env vars, shared config, instance profile)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "availability_zones_count" {
  description = "The number of AZs (and public subnets) to spread the cluster across."
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.1.0.0/16"
}

variable "subnet_cidr_bits" {
  description = "The number of subnet bits for the CIDR. For example, specifying a value 8 for this parameter will create a CIDR with a mask of /24."
  type        = number
  default     = 8
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_ami_type" {
  description = "AMI type for the EKS managed node group (e.g. AL2023_x86_64_STANDARD)."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_disk_size" {
  description = "OS/disk size (GiB) for each worker node (EKS disk_size / AKS os_disk_size_gb)."
  type        = number
  default     = 50
}

variable "node_min_size" {
  description = "Minimum number of nodes in the EKS node group."
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of nodes in the EKS node group."
  type        = number
  default     = 5
}

variable "node_max_size" {
  description = "Maximum number of nodes in the EKS node group."
  type        = number
  default     = 5
}

# --- Azure / AKS -----------------------------------------------------------
# Flat variables (only consumed in the "az" workspace).

variable "location" {
  description = "Azure location/region. e.g. eastus."
  type        = string
  default     = "eastus"
}

variable "azure_subscription_id" {
  description = "Azure subscription id. Leave blank to use ARM_SUBSCRIPTION_ID / az login context."
  type        = string
  default     = ""
}

variable "azure_tenant_id" {
  description = "Azure tenant id (service-principal auth). Leave blank to use az login / env vars."
  type        = string
  default     = ""
}

variable "azure_client_id" {
  description = "Azure client (app) id (service-principal auth). Leave blank to use az login / env vars."
  type        = string
  default     = ""
}

variable "azure_client_secret" {
  description = "Azure client secret (service-principal auth). Leave blank to use az login / env vars."
  type        = string
  default     = ""
  sensitive   = true
}

# --- GCP / GKE -------------------------------------------------------------
# Flat variables (only consumed in the "gcp" workspace).

variable "gcp_region" {
  description = "GCP region for the google provider (e.g. us-central1)."
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP location for the GKE cluster and node pool. A zone (e.g. us-central1-a) creates a cheaper zonal cluster where node_count is the total node count. A region (e.g. us-central1) creates a regional cluster where node_count is applied PER zone (x3 by default)."
  type        = string
  default     = "us-central1-a"
}

variable "gcp_project" {
  description = "GCP project id to create the cluster in."
  type        = string
  default     = ""
}

variable "gcp_credentials" {
  description = "Path to a GCP service-account key JSON file. Leave blank to use Application Default Credentials (gcloud auth)."
  type        = string
  default     = ""
}

# --- DigitalOcean / DOKS ---------------------------------------------------
# Flat variables (only consumed in the "do" workspace).

variable "do_token" {
  description = "DigitalOcean API token. Leave blank to use DIGITALOCEAN_TOKEN / DIGITALOCEAN_ACCESS_TOKEN env vars."
  type        = string
  default     = ""
  sensitive   = true
}

variable "do_region" {
  description = "DigitalOcean region slug for the cluster (e.g. blr1, nyc1)."
  type        = string
  default     = "blr1"
}

variable "do_k8s_version" {
  description = "DOKS Kubernetes version slug (DigitalOcean-specific, e.g. 1.36.0-do.3). List valid values with `doctl kubernetes options versions`."
  type        = string
  default     = "1.36.0-do.3"
}

variable "do_node_size" {
  description = "Droplet size slug for the default node pool (e.g. s-2vcpu-4gb)."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "do_vpc_cidr" {
  description = "CIDR block for the DigitalOcean VPC."
  type        = string
  default     = "10.1.0.0/16"
}
