data "aws_region" "current" {}

output "cluster_name" {
  description = "Name of the provisioned EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster API server."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "kubeconfig_cmd" {
  description = "Command to point kubectl at this cluster."
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.this.name}"
}
