# ==========================================
# SHARED  —  every gcp environment
# ==========================================

k8s_version = "1.36"

gcp_project = ""

gcp_credentials = ""

gcp_region = "us-central1"



# ==========================================
# PER ENVIRONMENT  —  selected by workspace
# ==========================================
# "make plan gcp dev" selects the dev key. The project/env labels are derived
# from these values and lowercased, as GKE requires.

envs = {
  dev = {
    cluster_name = "dev-gcp"
    project      = "dev-proj"
    node_size    = "e2-small"
    node_count   = 1
  }

  stage = {
    cluster_name = "stage-gcp"
    project      = "stage-proj"
    node_size    = "e2-standard-2"
    node_count   = 2
  }

  prod = {
    cluster_name = "prod-gcp"
    project      = "prod-proj"
    node_size    = "e2-standard-2"
    node_count   = 4
  }
}
