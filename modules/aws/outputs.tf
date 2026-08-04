data "aws_region" "current" {}

output "cluster_name" {
  description = "Name of the provisioned EKS cluster."
  value       = aws_eks_cluster.this.name
}

# EKS already returns "https://…", so no scheme fix-up is needed here.
output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = aws_eks_cluster.this.endpoint
}

# The addon layer looks these up by name rather than consuming the outputs, so
# it stays decoupled from infra state. Exposed for `terraform output` and for
# anything that does want to wire them directly.
output "lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account."
  value       = module.lb_role.iam_role_arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN used by the EBS CSI driver addon."
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster API server."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

# --profile is what makes plain `kubectl` work afterwards: update-kubeconfig
# writes it into the context's exec env, so kubectl re-runs `aws eks get-token`
# under the same identity Terraform used. Without it kubectl falls back to
# whatever ~/.aws/credentials holds, which may be a different account.
output "kubeconfig_cmd" {
  description = "Command to point kubectl at this cluster."
  value = join(" ", compact([
    "aws eks update-kubeconfig",
    "--region", data.aws_region.current.name,
    "--name", aws_eks_cluster.this.name,
    var.aws_profile != "" ? "--profile ${var.aws_profile}" : "",
  ]))
}
