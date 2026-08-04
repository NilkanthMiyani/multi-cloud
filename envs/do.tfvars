# ==========================================
# SHARED  —  every do environment
# ==========================================

k8s_version = "1.33"

do_token = ""

do_region   = "blr1"
do_vpc_cidr = "10.1.0.0/16"

do_k8s_version = "1.33.1-do.0"


# ==========================================
# PER ENVIRONMENT  —  selected by workspace
# ==========================================
# "make plan do dev" selects the dev key. Project/Env tags are derived from
# these values, so there is nothing else to keep in sync.

envs = {
  dev = {
    cluster_name = "dev-do"
    project      = "dev-proj"
    do_node_size = "s-1vcpu-2gb"
    node_count   = 1
  }

  stage = {
    cluster_name = "stage-do"
    project      = "stage-proj"
    do_node_size = "s-2vcpu-4gb"
    node_count   = 2
  }

  prod = {
    cluster_name = "prod-do"
    project      = "prod-proj"
    do_node_size = "s-2vcpu-4gb"
    node_count   = 3
  }
}
