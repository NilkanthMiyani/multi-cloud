# ------------------------------------------------------------------------
# Cluster lookup
# ------------------------------------------------------------------------

data "aws_eks_cluster" "this" {
  count = local.cloud == "aws" ? 1 : 0
  name  = local.cfg.cluster_name
}

data "google_container_cluster" "this" {
  count    = local.cloud == "gcp" ? 1 : 0
  name     = local.cfg.cluster_name
  location = var.gcp_zone
}

data "azurerm_kubernetes_cluster" "this" {
  count = local.cloud == "az" ? 1 : 0
  name  = local.cfg.cluster_name

  resource_group_name = "${local.cfg.project}-rg"
}

data "digitalocean_kubernetes_cluster" "this" {
  count = local.cloud == "do" ? 1 : 0
  name  = local.cfg.cluster_name
}

locals {
  # EKS and DOKS return "https://…"; GKE returns a bare IP and AKS a bare FQDN,
  # so those two get the scheme added. The providers' `host` needs a full URL.
  cluster_endpoint = coalesce(
    one(data.aws_eks_cluster.this[*].endpoint),
    one([for c in data.google_container_cluster.this : "https://${c.endpoint}"]),
    one([for c in data.azurerm_kubernetes_cluster.this : "https://${c.fqdn}"]),
    one(data.digitalocean_kubernetes_cluster.this[*].endpoint),
  )

  # Every cloud hands this back base64-encoded; the providers want the PEM.
  cluster_ca_certificate = base64decode(coalesce(
    one(data.aws_eks_cluster.this[*].certificate_authority[0].data),
    one(data.google_container_cluster.this[*].master_auth[0].cluster_ca_certificate),
    one(data.azurerm_kubernetes_cluster.this[*].kube_config[0].cluster_ca_certificate),
    one(data.digitalocean_kubernetes_cluster.this[*].kube_config[0].cluster_ca_certificate),
  ))

  # Per-cloud exec plugin. Each mints a short-lived token on every API call, so
  # nothing can expire mid-apply the way a baked-in kubeconfig token can.
  #
  #   aws  --region is explicit; without it the CLI uses its own default, which
  #        may be a different region than the cluster.
  #   do   exec-credential takes the cluster UUID, not its name.
  exec_auth = {
    aws = {
      command = "aws"
      args = [
        "--region", var.region,
        "eks", "get-token",
        "--cluster-name", local.cfg.cluster_name,
        "--output", "json",
      ]
    }
    gcp = {
      command = "gke-gcloud-auth-plugin"
      args    = []
    }
    az = {
      command = "kubelogin"
      args = [
        "get-token",
        "--login", "azurecli",
        # Well-known AKS AAD server application ID.
        "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
      ]
    }
    do = {
      command = "doctl"
      args = [
        "kubernetes", "cluster", "kubeconfig", "exec-credential",
        "--version", "v1beta1",
        one(data.digitalocean_kubernetes_cluster.this[*].id),
      ]
    }
  }[local.cloud]
}
