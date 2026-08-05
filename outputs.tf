# Resources live inside the per-cloud modules, so the root cannot reference them
# directly — everything has to come back out through a module output.
#
# Each module is instantiated with count, so `module.aws` is a LIST of zero or
# one objects. one() collapses that to the value or null; coalesce() then picks
# whichever cloud is live. try() guards the all-null case (`terraform output`
# against fresh, pre-apply state), where coalesce() would otherwise error.

output "cluster_name" {
  description = "Name of the provisioned cluster."
  value       = local.cfg.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint of the provisioned cluster."
  value = try(coalesce(
    one(module.aws[*].cluster_endpoint),
    one(module.azure[*].cluster_endpoint),
    one(module.gcp[*].cluster_endpoint),
    one(module.do[*].cluster_endpoint),
  ), null)
}

output "kubeconfig_cmd" {
  description = "The command to update kubeconfig for this cluster."
  value = try(coalesce(
    one(module.aws[*].kubeconfig_cmd),
    one(module.azure[*].kubeconfig_cmd),
    one(module.gcp[*].kubeconfig_cmd),
    one(module.do[*].kubeconfig_cmd),
  ), "echo 'Cluster not found'")
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster API server."
  sensitive   = true
  value = try(coalesce(
    one(module.aws[*].cluster_ca_certificate),
    one(module.azure[*].cluster_ca_certificate),
    one(module.gcp[*].cluster_ca_certificate),
    one(module.do[*].cluster_ca_certificate),
  ), null)
}

# Azure-only; null on every other cloud. `az aks get-credentials` needs it, and
# it is otherwise unreachable from the root.
output "resource_group_name" {
  description = "Resource group holding the cluster (Azure only)."
  value       = one(module.azure[*].resource_group_name)
}

# AWS-only; null on every other cloud. The addon layer finds these roles by
# name, so nothing consumes them — they are here to be read when an IRSA
# binding needs checking.
output "lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller (AWS only)."
  value       = one(module.aws[*].lb_controller_role_arn)
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI driver (AWS only)."
  value       = one(module.aws[*].ebs_csi_role_arn)
}
