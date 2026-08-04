# ------------------------------------------------------------------------
#  RabbitMQ
# ------------------------------------------------------------------------

locals {
  rabbitmq_resources = var.rabbitmq.resources != null ? { resources = var.rabbitmq.resources } : {}

  rabbitmq_create_secret = var.enabled.rabbitmq && var.rabbitmq.existing_secret == null

  rabbitmq_secret_name = (
    var.rabbitmq.existing_secret != null
    ? var.rabbitmq.existing_secret
    : one(kubernetes_secret.rabbitmq_auth[*].metadata[0].name)
  )

  rabbitmq_storage_class = coalesce(var.rabbitmq.storage_class, local.storage_class)
}

resource "kubernetes_namespace" "rabbitmq" {
  count = var.enabled.rabbitmq ? 1 : 0
  metadata {
    name = var.rabbitmq.namespace
  }
}

resource "random_password" "rabbitmq_password" {
  count   = local.rabbitmq_create_secret ? 1 : 0
  length  = 16
  special = false
}

# The chart also needs an Erlang cookie. Left unset, each pod generates its own
# and a restarted multi-node cluster cannot re-form.
resource "random_password" "rabbitmq_erlang_cookie" {
  count   = local.rabbitmq_create_secret ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret" "rabbitmq_auth" {
  count = local.rabbitmq_create_secret ? 1 : 0
  metadata {
    name      = "rabbitmq-auth"
    namespace = kubernetes_namespace.rabbitmq[0].metadata[0].name
  }
  data = {
    "rabbitmq-password"      = random_password.rabbitmq_password[0].result
    "rabbitmq-erlang-cookie" = random_password.rabbitmq_erlang_cookie[0].result
  }
}

resource "helm_release" "rabbitmq" {
  count            = var.enabled.rabbitmq ? 1 : 0
  name             = "rabbitmq"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "rabbitmq"
  version          = var.rabbitmq.chart_version
  namespace        = kubernetes_namespace.rabbitmq[0].metadata[0].name
  create_namespace = false

  values = [
    yamlencode(merge({
      global = {
        security = {
          allowInsecureImages = var.rabbitmq.allow_insecure_images
        }
      }

      # null fields are dropped rather than emitted as `registry: null`,
      # so an unset override means "leave the chart default alone".
      image = { for k, v in {
        registry   = var.rabbitmq.image_registry
        repository = var.rabbitmq.image_repository
        tag        = var.rabbitmq.image_tag
      } : k => v if v != null }

      replicaCount = var.rabbitmq.replicas

      auth = {
        username                  = "user"
        existingPasswordSecret    = local.rabbitmq_secret_name
        existingSecretPasswordKey = "rabbitmq-password"
        existingErlangSecret      = local.rabbitmq_secret_name
        existingSecretErlangKey   = "rabbitmq-erlang-cookie"
      }

      extraPlugins = ""

      metrics = {
        enabled = false
      }

      service = {
        type = "ClusterIP"
      }

      persistence = {
        enabled      = true
        storageClass = local.rabbitmq_storage_class
        size         = var.rabbitmq.storage_size
      }

    }, local.rabbitmq_resources)),

    var.rabbitmq.values_extra,
  ]
}
