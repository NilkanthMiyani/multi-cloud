# ------------------------------------------------------------------------
# Redis
# ------------------------------------------------------------------------

locals {
  redis_resources = var.redis.resources != null ? { resources = var.redis.resources } : {}

  redis_create_secret = var.enabled.redis && var.redis.existing_secret == null

  redis_secret_name = (
    var.redis.existing_secret != null
    ? var.redis.existing_secret
    : one(kubernetes_secret.redis_auth[*].metadata[0].name)
  )

  redis_storage_class = coalesce(var.redis.storage_class, local.storage_class)

  # "standalone" is a single master, so the replica count is forced to 0
  # regardless of what the env asked for.
  redis_replica_count = var.redis.architecture == "replication" ? var.redis.replicas : 0

  redis_config = <<-EOT
    # Enable AOF https://redis.io/topics/persistence#append-only-file
    appendonly yes
    # Disable RDB persistence, AOF persistence already enabled.
    save ""
    notify-keyspace-events KEA
  EOT
}

resource "kubernetes_namespace" "redis" {
  count = var.enabled.redis ? 1 : 0
  metadata {
    name = var.redis.namespace
  }
}

resource "random_password" "redis_password" {
  count   = local.redis_create_secret ? 1 : 0
  length  = 16
  special = false
}

resource "kubernetes_secret" "redis_auth" {
  count = local.redis_create_secret ? 1 : 0
  metadata {
    name      = "redis-auth"
    namespace = kubernetes_namespace.redis[0].metadata[0].name
  }
  data = {
    (var.redis.existing_secret_key) = random_password.redis_password[0].result
  }
}

resource "helm_release" "redis" {
  count            = var.enabled.redis ? 1 : 0
  name             = "redis"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "redis"
  version          = var.redis.chart_version
  namespace        = kubernetes_namespace.redis[0].metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      architecture = var.redis.architecture

      global = {
        security = {
          allowInsecureImages = var.redis.allow_insecure_images
        }
      }

      # null fields are dropped rather than emitted as `registry: null`,
      # so an unset override means "leave the chart default alone".
      image = { for k, v in {
        registry   = var.redis.image_registry
        repository = var.redis.image_repository
        tag        = var.redis.image_tag
      } : k => v if v != null }

      cluster = {
        enabled    = var.redis.architecture == "replication"
        slaveCount = local.redis_replica_count
      }

      sentinel = {
        enabled = false
      }

      auth = {
        existingSecret            = local.redis_secret_name
        existingSecretPasswordKey = var.redis.existing_secret_key
      }

      metrics = {
        enabled = false
      }

      master = merge({
        disableCommands = ["FLUSHALL"]
        service = {
          type = "ClusterIP"
        }
        persistence = {
          enabled      = true
          storageClass = local.redis_storage_class
          size         = var.redis.storage_size
        }
      }, local.redis_resources)

      replica = merge({
        replicaCount = local.redis_replica_count
        persistence = {
          enabled      = true
          storageClass = local.redis_storage_class
          size         = var.redis.storage_size
        }
      }, local.redis_resources)

      commonConfiguration = local.redis_config
    }),

    # Merged last, so it overrides anything computed above.
    var.redis.values_extra,
  ]

  depends_on = [kubernetes_storage_class_v1.standard_sc]

}
