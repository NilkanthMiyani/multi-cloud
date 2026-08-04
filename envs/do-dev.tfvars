cluster_name = "dev-do"
k8s_version  = "1.33" # unused by DOKS (see do_k8s_version), required by the shared variable
project      = "dev-proj"

do_token       = ""
do_region      = "blr1"
do_k8s_version = "1.33.1-do.0"
do_node_size   = "s-1vcpu-2gb"
node_count     = 1

tags = {
  "Project" = "dev-proj"
  "Env"     = "dev"
}
