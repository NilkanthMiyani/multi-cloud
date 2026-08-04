# ------------------------------------------------------------------------
# PostgreSQL
# ------------------------------------------------------------------------

locals {
  postgresql_resources = var.postgresql.resources != null ? { resources = var.postgresql.resources } : {}

  postgresql_create_secret = var.enabled.postgresql && var.postgresql.existing_secret == null

  postgresql_secret_name = (
    var.postgresql.existing_secret != null
    ? var.postgresql.existing_secret
    : one(kubernetes_secret.postgresql_auth[*].metadata[0].name)
  )

  postgresql_storage_class = coalesce(var.postgresql.storage_class, local.storage_class)
}

resource "kubernetes_namespace" "postgresql" {
  count = var.enabled.postgresql ? 1 : 0
  metadata {
    name = var.postgresql.namespace
  }
}

resource "random_password" "postgresql_password" {
  count   = local.postgresql_create_secret ? 1 : 0
  length  = 16
  special = false
}

resource "random_password" "postgresql_admin_password" {
  count   = local.postgresql_create_secret ? 1 : 0
  length  = 16
  special = false
}

resource "kubernetes_secret" "postgresql_auth" {
  count = local.postgresql_create_secret ? 1 : 0
  metadata {
    name      = "postgresql-auth"
    namespace = kubernetes_namespace.postgresql[0].metadata[0].name
  }
  data = {
    "password"          = random_password.postgresql_password[0].result
    "postgres-password" = random_password.postgresql_admin_password[0].result
  }
}

resource "helm_release" "postgresql" {
  count            = var.enabled.postgresql ? 1 : 0
  name             = "postgresql"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "postgresql"
  version          = var.postgresql.chart_version
  namespace        = kubernetes_namespace.postgresql[0].metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      global = {
        security = {
          allowInsecureImages = var.postgresql.allow_insecure_images
        }
      }

      # null fields are dropped rather than emitted as `registry: null`,
      # so an unset override means "leave the chart default alone".
      image = { for k, v in {
        registry   = var.postgresql.image_registry
        repository = var.postgresql.image_repository
        tag        = var.postgresql.image_tag
      } : k => v if v != null }

      architecture = var.postgresql.architecture

      auth = {
        database       = "app"
        username       = "app"
        existingSecret = local.postgresql_secret_name
        secretKeys = {
          adminPasswordKey = "postgres-password"
          userPasswordKey  = "password"
        }
      }

      metrics = {
        enabled = false
      }

      primary = merge(
        {
          service = {
            type = "ClusterIP"
          }
          persistence = {
            enabled      = true
            storageClass = local.postgresql_storage_class
            size         = var.postgresql.storage_size
          }
        },
        local.postgresql_resources,
      )

      readReplicas = merge({
        replicaCount = var.postgresql.architecture == "replication" ? var.postgresql.replicas : 0
        persistence = {
          enabled      = true
          storageClass = local.postgresql_storage_class
          size         = var.postgresql.storage_size
        }
      }, local.postgresql_resources)
    }),

    var.postgresql.values_extra,
  ]
}
