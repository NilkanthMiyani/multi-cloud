cluster_name = "stage-aws"
k8s_version  = "1.36"

aws_access_key = ""
aws_secret_key = ""

region                   = "us-east-1"
availability_zones_count = 2
project                  = "stage-proj"
vpc_cidr                 = "10.20.0.0/16"
subnet_cidr_bits         = 8

node_size         = "t3.medium"
node_ami_type     = "AL2023_x86_64_STANDARD"
node_disk_size    = 40
node_min_size     = 2
node_desired_size = 2
node_max_size     = 3

public_access_cidrs = ["0.0.0.0/0"]

tags = {
  "Project" = "stage-proj"
  "Env"     = "stage"
}
