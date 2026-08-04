variable "project" {
  description = "Name to be used on all the resources as identifier."
  type        = string
}

variable "do_region" {
  description = "DigitalOcean region."
  type        = string
}

variable "do_vpc_cidr" {
  description = "CIDR block for the DigitalOcean VPC."
  type        = string
}

variable "cluster_name" {
  description = "Name of the managed Kubernetes cluster."
  type        = string
}

variable "do_k8s_version" {
  description = "DOKS Kubernetes version."
  type        = string
}

variable "do_node_size" {
  description = "Droplet size slug for the default node pool."
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the default node pool."
  type        = number
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
}
