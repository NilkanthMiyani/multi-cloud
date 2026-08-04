# --- Per-environment settings ----------------------------------------------
# The workspace is "<cloud>-<env>"; locals.tf splits it and indexes this map
# with the env half. That is what lets envs/<cloud>.tfvars carry dev, stage and
# prod together — "make plan aws dev" selects the "dev" key.
#
# The object is a union across the four clouds: AWS scales its node group with
# min/desired/max, the others use node_count, DO has its own size slug. Every
# field below is optional and defaults to what the flat variable it replaced
# defaulted to, so a cloud omits whatever it does not use.

variable "envs" {
  description = "Per-environment settings, keyed by env name (dev | stage | prod)."
  type = map(object({
    cluster_name = string
    project      = string

    node_size    = optional(string, "t3.medium")   # aws | az | gcp
    do_node_size = optional(string, "s-2vcpu-4gb") # do
    node_count   = optional(number, 2)             # az | gcp | do

    node_disk_size = optional(number, 50) # aws | az

    # EKS managed node group scaling (aws only).
    node_min_size     = optional(number, 3)
    node_desired_size = optional(number, 5)
    node_max_size     = optional(number, 5)

    vpc_cidr = optional(string, "10.1.0.0/16") # aws
  }))

  validation {
    condition     = alltrue([for e in keys(var.envs) : contains(["dev", "stage", "prod"], e)])
    error_message = "envs keys must be one of: dev, stage, prod."
  }
}

variable "k8s_version" {
  description = "Kubernetes control plane version (e.g. 1.30)."
  type        = string
}

# --- Generic (shared across all clouds) ------------------------------------

variable "region" {
  description = "AWS region (e.g. us-east-1). Azure uses var.location; GCP uses var.gcp_region."
  type        = string
  default     = "us-east-1"
}

# Project and Env are derived from the workspace in locals.tf and applied to
# every resource, so they can never drift out of sync with the environment they
# claim to describe. This variable is for anything extra, and merges on top.
variable "tags" {
  description = "Extra tags merged over the derived Project/Env tags. Usually empty."
  type        = map(string)
  default     = {}
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

variable "do_vpc_cidr" {
  description = "CIDR block for the DigitalOcean VPC."
  type        = string
  default     = "10.1.0.0/16"
}
