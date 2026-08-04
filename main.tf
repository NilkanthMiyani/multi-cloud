module "aws" {
  source = "./modules/aws"
  count  = local.is_aws

  cluster_name             = var.cluster_name
  k8s_version              = var.k8s_version
  project                  = var.project
  node_size                = var.node_size
  tags                     = var.tags
  availability_zones_count = var.availability_zones_count
  vpc_cidr                 = var.vpc_cidr
  subnet_cidr_bits         = var.subnet_cidr_bits
  public_access_cidrs      = var.public_access_cidrs
  node_ami_type            = var.node_ami_type
  node_disk_size           = var.node_disk_size
  node_min_size            = var.node_min_size
  node_desired_size        = var.node_desired_size
  node_max_size            = var.node_max_size
}

module "azure" {
  source = "./modules/azure"
  count  = local.is_azure

  cluster_name        = var.cluster_name
  k8s_version         = var.k8s_version
  project             = var.project
  location            = var.location
  node_size           = var.node_size
  node_count          = var.node_count
  node_disk_size      = var.node_disk_size
  azure_client_id     = var.azure_client_id
  azure_client_secret = var.azure_client_secret
  tags                = var.tags
}

module "gcp" {
  source = "./modules/gcp"
  count  = local.is_gcp

  cluster_name = var.cluster_name
  k8s_version  = var.k8s_version
  project      = var.project
  gcp_zone     = var.gcp_zone
  node_size    = var.node_size
  node_count   = var.node_count
  tags         = var.tags
}

module "do" {
  source = "./modules/do"
  count  = local.is_do

  project        = var.project
  do_region      = var.do_region
  do_vpc_cidr    = var.do_vpc_cidr
  cluster_name   = var.cluster_name
  do_k8s_version = var.do_k8s_version
  do_node_size   = var.do_node_size
  node_count     = var.node_count
  tags           = var.tags
}
