output "cluster_name" {
  description = "Name of the provisioned DOKS cluster."
  value       = digitalocean_kubernetes_cluster.this.name
}

# DOKS already returns "https://…", so no scheme fix-up is needed here.
output "cluster_endpoint" {
  description = "API server endpoint of the DOKS cluster."
  value       = digitalocean_kubernetes_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster API server."
  value       = digitalocean_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig_cmd" {
  description = "Command to point kubectl at this cluster."
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.this.name}"
}
