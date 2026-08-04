cluster_name = "prod-do"
k8s_version  = "1.33" # unused by DOKS (see do_k8s_version), required by the shared variable
project      = "prod-proj"

do_token       = ""
do_region      = "blr1"
do_k8s_version = "1.33.1-do.0"
do_node_size   = "s-2vcpu-4gb"
node_count     = 3

tags = {
  "Project" = "prod-proj"
  "Env"     = "prod"
}
