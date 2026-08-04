cluster_name = "dev-aws"
k8s_version  = "1.36"

aws_access_key = ""
aws_secret_key = ""

region                   = "us-east-1"
availability_zones_count = 2
project                  = "dev-proj"
vpc_cidr                 = "10.10.0.0/16"
subnet_cidr_bits         = 8

node_size         = "t3.small"
node_ami_type     = "AL2023_x86_64_STANDARD"
node_disk_size    = 30
node_min_size     = 1
node_desired_size = 1
node_max_size     = 2

public_access_cidrs = ["0.0.0.0/0"]

tags = {
  "Project" = "dev-proj"
  "Env"     = "dev"
}
