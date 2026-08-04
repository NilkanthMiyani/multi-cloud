cluster_name = "stage-gcp"
k8s_version  = "1.36"

gcp_project     = "my-gcp-project-id"
gcp_credentials = ""

gcp_region = "us-central1"
gcp_zone   = "us-central1-a"
project    = "stage-proj"
node_size  = "e2-standard-2"
node_count = 2

tags = {
  "project" = "stage-proj"
  "env"     = "stage"
}
