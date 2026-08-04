# ==========================================
# SHARED  —  every aws environment
# ==========================================

k8s_version = "1.36"

# Blank uses the standard credential chain (env vars, shared config, instance
# profile). Never commit real keys here.
aws_access_key = ""
aws_secret_key = ""

region                   = "us-east-1"
availability_zones_count = 2
subnet_cidr_bits         = 8

node_ami_type       = "AL2023_x86_64_STANDARD"
public_access_cidrs = ["0.0.0.0/0"]


# ==========================================
# PER ENVIRONMENT  —  selected by workspace
# ==========================================
# "make plan aws dev" selects the dev key. Project/Env tags are derived from
# these values, so there is nothing else to keep in sync.

envs = {
  dev = {
    cluster_name = "dev-aws"
    project      = "dev-proj"
    vpc_cidr     = "10.10.0.0/16"

    node_size         = "t3.small"
    node_disk_size    = 30
    node_min_size     = 1
    node_desired_size = 1
    node_max_size     = 2
  }

  stage = {
    cluster_name = "stage-aws"
    project      = "stage-proj"
    vpc_cidr     = "10.20.0.0/16"

    node_size         = "t3.medium"
    node_disk_size    = 40
    node_min_size     = 2
    node_desired_size = 2
    node_max_size     = 3
  }

  prod = {
    cluster_name = "prod-aws"
    project      = "prod-proj"
    vpc_cidr     = "10.1.0.0/16"

    node_size         = "t3.medium"
    node_disk_size    = 50
    node_min_size     = 3
    node_desired_size = 5
    node_max_size     = 5
  }
}
