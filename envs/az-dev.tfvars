cluster_name = "dev-azure"
k8s_version  = "1.36"

azure_subscription_id = ""
azure_tenant_id       = ""
azure_client_id       = "dummy"
azure_client_secret   = "dummy"

location       = "eastus"
project        = "dev-proj"
node_size      = "Standard_B2s"
node_count     = 1
node_disk_size = 30

tags = {
  "Project" = "dev-proj"
  "Env"     = "dev"
}
