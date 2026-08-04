cluster_name = "dev-gcp"
k8s_version  = "1.36"

gcp_project     = "my-gcp-project-id"
gcp_credentials = ""

gcp_region = "us-central1"
gcp_zone   = "us-central1-a"
project    = "dev-proj"
node_size  = "e2-small"
node_count = 1

tags = {
  "project" = "dev-proj"
  "env"     = "dev"
}
