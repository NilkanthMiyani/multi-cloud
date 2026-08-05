# AKS returns a bare FQDN, so the scheme is added here — every module emits a
# full URL for the providers' `host` argument.
output "cluster_endpoint" {
  description = "API server endpoint of the AKS cluster."
  value       = "https://${azurerm_kubernetes_cluster.this.fqdn}"
}

# Needed by the root kubeconfig_cmd — `az aks get-credentials` takes the
# resource group, which only exists inside this module.
output "resource_group_name" {
  description = "Name of the resource group holding the cluster."
  value       = azurerm_resource_group.this.name
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster API server."
  value       = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "kubeconfig_cmd" {
  description = "Command to point kubectl at this cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.this.name} --overwrite-existing"
}
