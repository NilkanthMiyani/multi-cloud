cluster_name = "prod-gcp"
k8s_version  = "1.36"

gcp_project = ""
# gcp_credentials = ""

gcp_region = "us-central1"
gcp_zone   = "us-central1-a"
project    = "prod-proj"
node_size  = "e2-standard-2"
node_count = 4

tags = {
  "project" = "prod-proj"
  "env"     = "prod"
}
