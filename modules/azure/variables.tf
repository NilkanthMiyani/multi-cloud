variable "cluster_name" {
  description = "Name of the managed Kubernetes cluster."
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes control plane version (e.g. 1.30)."
  type        = string
}

variable "project" {
  description = "Name to be used on all the resources as identifier."
  type        = string
}

variable "location" {
  description = "Azure location/region. e.g. eastus."
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

variable "node_disk_size" {
  description = "OS/disk size (GiB) for each worker node."
  type        = number
}

variable "azure_client_id" {
  description = "Azure client id."
  type        = string
}

variable "azure_client_secret" {
  description = "Azure client secret."
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
}
