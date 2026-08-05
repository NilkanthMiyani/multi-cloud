locals {
  gcp_location_flag = length(split("-", google_container_cluster.this.location)) == 3 ? "--zone" : "--region"
}

# GKE returns a bare IP (e.g. "34.170.28.68"), so the scheme is added here.
# Every module emits a full URL, which is what the kubernetes/helm providers'
# `host` argument requires.
output "cluster_endpoint" {
  description = "API server endpoint of the GKE cluster."
  value       = "https://${google_container_cluster.this.endpoint}"
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster API server."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig_cmd" {
  description = "Command to point kubectl at this cluster."
  value = join(" ", [
    "gcloud container clusters get-credentials",
    google_container_cluster.this.name,
    local.gcp_location_flag,
    google_container_cluster.this.location,
    "--project",
    google_container_cluster.this.project,
  ])
}
