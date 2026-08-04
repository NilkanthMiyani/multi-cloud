resource "digitalocean_vpc" "this" {
  name     = "${var.project}-vpc"
  region   = var.do_region
  ip_range = var.do_vpc_cidr
}

resource "digitalocean_kubernetes_cluster" "this" {
  name     = var.cluster_name
  region   = var.do_region
  version  = var.do_k8s_version
  vpc_uuid = digitalocean_vpc.this.id

  node_pool {
    name       = var.project
    size       = var.do_node_size
    node_count = var.node_count
  }

  tags = [for k, v in var.tags : "${k}:${v}"]
}
