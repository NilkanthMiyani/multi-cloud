cluster_name = "prod-azure"
k8s_version  = "1.36"

azure_subscription_id = ""
azure_tenant_id       = ""
azure_client_id       = "dummy"
azure_client_secret   = "dummy"

location       = "eastus"
project        = "prod-proj"
node_size      = "Standard_D2s_v3"
node_count     = 3
node_disk_size = 40

tags = {
  "Project" = "prod-proj"
  "Env"     = "prod"
}
