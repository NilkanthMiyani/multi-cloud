variable "cluster_name" {
  description = "Name of the managed Kubernetes cluster."
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes control plane version."
  type        = string
}

variable "project" {
  description = "Name to be used on all the resources as identifier."
  type        = string
}

variable "gcp_zone" {
  description = "GCP location for the GKE cluster."
  type        = string
}

variable "node_size" {
  description = "Machine type for the default node pool."
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
