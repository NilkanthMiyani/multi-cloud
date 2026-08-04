module "aws" {
  source = "./modules/aws"
  count  = local.is_aws

  cluster_name             = local.cfg.cluster_name
  k8s_version              = var.k8s_version
  project                  = local.cfg.project
  aws_profile              = var.aws_profile
  node_size                = local.cfg.node_size
  tags                     = local.tags
  availability_zones_count = var.availability_zones_count
  vpc_cidr                 = local.cfg.vpc_cidr
  subnet_cidr_bits         = var.subnet_cidr_bits
  public_access_cidrs      = var.public_access_cidrs
  node_ami_type            = var.node_ami_type
  node_disk_size           = local.cfg.node_disk_size
  node_min_size            = local.cfg.node_min_size
  node_desired_size        = local.cfg.node_desired_size
  node_max_size            = local.cfg.node_max_size
}

module "azure" {
  source = "./modules/azure"
  count  = local.is_azure

  cluster_name        = local.cfg.cluster_name
  k8s_version         = var.k8s_version
  project             = local.cfg.project
  location            = var.location
  node_size           = local.cfg.node_size
  node_count          = local.cfg.node_count
  node_disk_size      = local.cfg.node_disk_size
  azure_client_id     = var.azure_client_id
  azure_client_secret = var.azure_client_secret
  tags                = local.tags
}

module "gcp" {
  source = "./modules/gcp"
  count  = local.is_gcp

  cluster_name = local.cfg.cluster_name
  k8s_version  = var.k8s_version
  project      = local.cfg.project
  gcp_zone     = var.gcp_zone
  node_size    = local.cfg.node_size
  node_count   = local.cfg.node_count
  tags         = local.tags
}

module "do" {
  source = "./modules/do"
  count  = local.is_do

  project        = local.cfg.project
  do_region      = var.do_region
  do_vpc_cidr    = var.do_vpc_cidr
  cluster_name   = local.cfg.cluster_name
  do_k8s_version = var.do_k8s_version
  do_node_size   = local.cfg.do_node_size
  node_count     = local.cfg.node_count
  tags           = local.tags
}
