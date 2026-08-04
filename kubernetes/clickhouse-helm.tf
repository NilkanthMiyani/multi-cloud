# ------------------------------------------------------------------------
#  Clickhouse
# ------------------------------------------------------------------------

locals {
  clickhouse_resources = merge(
    var.clickhouse.resources != null ? { resources = var.clickhouse.resources } : {},
    var.clickhouse.resources != null ? { resourcesPreset = "none" } : {},
  )

  clickhouse_create_secret = var.enabled.clickhouse && var.clickhouse.existing_secret == null

  clickhouse_secret_name = (
    var.clickhouse.existing_secret != null
    ? var.clickhouse.existing_secret
    : one(kubernetes_secret.clickhouse_auth[*].metadata[0].name)
  )

  clickhouse_storage_class = coalesce(var.clickhouse.storage_class, local.storage_class)
}

resource "kubernetes_namespace" "clickhouse" {
  count = var.enabled.clickhouse ? 1 : 0
  metadata {
    name = var.clickhouse.namespace
  }
}

resource "random_password" "clickhouse_password" {
  count   = local.clickhouse_create_secret ? 1 : 0
  length  = 16
  special = false
}

resource "kubernetes_secret" "clickhouse_auth" {
  count = local.clickhouse_create_secret ? 1 : 0
  metadata {
    name      = "clickhouse-auth"
    namespace = kubernetes_namespace.clickhouse[0].metadata[0].name
  }
  data = {
    (var.clickhouse.existing_secret_key) = random_password.clickhouse_password[0].result
  }
}

resource "helm_release" "clickhouse" {
  count            = var.enabled.clickhouse ? 1 : 0
  name             = "clickhouse"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "clickhouse"
  version          = var.clickhouse.chart_version
  namespace        = kubernetes_namespace.clickhouse[0].metadata[0].name
  create_namespace = false

  values = [
    yamlencode(merge({
      global = {
        security = {
          allowInsecureImages = var.clickhouse.allow_insecure_images
        }
      }

      # null fields are dropped rather than emitted as `registry: null`,
      # so an unset override means "leave the chart default alone".
      image = { for k, v in {
        registry   = var.clickhouse.image_registry
        repository = var.clickhouse.image_repository
        tag        = var.clickhouse.image_tag
      } : k => v if v != null }

      shards       = var.clickhouse.shards
      replicaCount = var.clickhouse.replicas

      keeper = {
        enabled      = var.clickhouse.keeper_enabled
        replicaCount = 3
      }

      auth = {
        username          = "default"
        existingSecret    = local.clickhouse_secret_name
        existingSecretKey = var.clickhouse.existing_secret_key
      }

      metrics = {
        enabled = false
      }

      persistence = {
        enabled      = true
        storageClass = local.clickhouse_storage_class
        size         = var.clickhouse.storage_size
      }


      service = {
        type = "ClusterIP"
      }
    }, local.clickhouse_resources)),

    var.clickhouse.values_extra,
  ]

  # standard-sc is created by this same layer; a PVC naming a class that
  # does not exist yet sits Pending until Helm times out. Empty list on
  # non-aws workspaces (count = 0), so this imposes no ordering there.
  depends_on = [kubernetes_storage_class_v1.standard_sc]

}
