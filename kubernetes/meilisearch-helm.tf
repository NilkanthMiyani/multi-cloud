# ------------------------------------------------------------------------
# Meilisearch
# ------------------------------------------------------------------------

locals {
  meilisearch_resources = var.meilisearch.resources != null ? { resources = var.meilisearch.resources } : {}

  meilisearch_create_secret = var.enabled.meilisearch && var.meilisearch.existing_secret == null

  meilisearch_secret_name = (
    var.meilisearch.existing_secret != null
    ? var.meilisearch.existing_secret
    : one(kubernetes_secret.meilisearch_auth[*].metadata[0].name)
  )

  meilisearch_storage_class = coalesce(var.meilisearch.storage_class, local.storage_class)
}

resource "kubernetes_namespace" "meilisearch" {
  count = var.enabled.meilisearch ? 1 : 0
  metadata {
    name = var.meilisearch.namespace
  }
}

resource "random_password" "meili_master_key" {
  count   = local.meilisearch_create_secret ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret" "meilisearch_auth" {
  count = local.meilisearch_create_secret ? 1 : 0
  metadata {
    name      = "meilisearch-auth"
    namespace = kubernetes_namespace.meilisearch[0].metadata[0].name
  }
  data = {
    "MEILI_MASTER_KEY" = random_password.meili_master_key[0].result
  }
}

resource "helm_release" "meilisearch" {
  count            = var.enabled.meilisearch ? 1 : 0
  name             = "meilisearch"
  repository       = "https://meilisearch.github.io/meilisearch-kubernetes"
  chart            = "meilisearch"
  version          = var.meilisearch.chart_version
  namespace        = kubernetes_namespace.meilisearch[0].metadata[0].name
  create_namespace = false

  values = [
    yamlencode(merge({
      replicaCount = var.meilisearch.replicas

      environment = {
        MEILI_ENV          = "production"
        MEILI_NO_ANALYTICS = "true"
      }

      envFrom = [
        {
          secretRef = {
            name = local.meilisearch_secret_name
          }
        }
      ]

      service = {
        type = "ClusterIP"
        port = 7700
      }

      persistence = {
        enabled      = true
        storageClass = local.meilisearch_storage_class
        size         = var.meilisearch.storage_size
      }

    }, local.meilisearch_resources)),

    var.meilisearch.values_extra,
  ]

  # standard-sc is created by this same layer; a PVC naming a class that
  # does not exist yet sits Pending until Helm times out. Empty list on
  # non-aws workspaces (count = 0), so this imposes no ordering there.
  depends_on = [kubernetes_storage_class_v1.standard_sc]

}
