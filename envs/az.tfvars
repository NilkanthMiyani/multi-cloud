# ==========================================
# SHARED  —  every az environment
# ==========================================

k8s_version = "1.36"

azure_subscription_id = ""
azure_tenant_id       = ""
azure_client_id       = "dummy"
azure_client_secret   = "dummy"

location = "eastus"


# ==========================================
# PER ENVIRONMENT  —  selected by workspace
# ==========================================
# "make plan az dev" selects the dev key. Project/Env tags are derived from
# these values, so there is nothing else to keep in sync.

envs = {
  dev = {
    cluster_name   = "dev-azure"
    project        = "dev-proj"
    node_size      = "Standard_B2s"
    node_count     = 1
    node_disk_size = 30
  }

  stage = {
    cluster_name   = "stage-azure"
    project        = "stage-proj"
    node_size      = "Standard_D2s_v3"
    node_count     = 2
    node_disk_size = 40
  }

  prod = {
    cluster_name   = "prod-azure"
    project        = "prod-proj"
    node_size      = "Standard_D2s_v3"
    node_count     = 3
    node_disk_size = 40
  }
}
