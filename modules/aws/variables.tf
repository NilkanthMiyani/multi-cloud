variable "cluster_name" {
  description = "Name of the managed Kubernetes cluster."
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes control plane version (e.g. 1.30)."
  type        = string
}

variable "project" {
  description = "Name to be used on all the resources as identifier. e.g. Project name, Application name"
  type        = string
}

variable "node_size" {
  description = "Machine type for the default node pool. Cloud-specific: AWS t3.medium"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
}

variable "availability_zones_count" {
  description = "The number of AZs (and public subnets) to spread the cluster across."
  type        = number
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "subnet_cidr_bits" {
  description = "The number of subnet bits for the CIDR."
  type        = number
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint."
  type        = list(string)
}

variable "node_ami_type" {
  description = "AMI type for the EKS managed node group."
  type        = string
}

variable "node_disk_size" {
  description = "OS/disk size (GiB) for each worker node."
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of nodes in the EKS node group."
  type        = number
}

variable "node_desired_size" {
  description = "Desired number of nodes in the EKS node group."
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes in the EKS node group."
  type        = number
}

# Threaded through only so kubeconfig_cmd can carry --profile. The module's own
# API calls use the provider, which the root already configures.
variable "aws_profile" {
  description = "AWS named profile, echoed into the kubeconfig command. Blank omits it."
  type        = string
  default     = ""
}
