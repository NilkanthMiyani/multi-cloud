# ------------------------------------------------------------------------
# 8. MySQL
# ------------------------------------------------------------------------

locals {
  mysql_resources = var.mysql.resources != null ? { resources = var.mysql.resources } : {}

  mysql_create_secret = var.enabled.mysql && var.mysql.existing_secret == null

  mysql_secret_name = (
    var.mysql.existing_secret != null
    ? var.mysql.existing_secret
    : one(kubernetes_secret.mysql_auth[*].metadata[0].name)
  )

  mysql_storage_class = coalesce(var.mysql.storage_class, local.storage_class)
}

resource "kubernetes_namespace" "mysql" {
  count = var.enabled.mysql ? 1 : 0
  metadata {
    name = var.mysql.namespace
  }
}

resource "random_password" "mysql_password" {
  count   = local.mysql_create_secret ? 1 : 0
  length  = 16
  special = false
}

resource "random_password" "mysql_root_password" {
  count   = local.mysql_create_secret ? 1 : 0
  length  = 16
  special = false
}

# Only consumed when architecture = "replication", but the chart validates the
# key's presence whenever an existing secret is supplied.
resource "random_password" "mysql_replication_password" {
  count   = local.mysql_create_secret ? 1 : 0
  length  = 16
  special = false
}

resource "kubernetes_secret" "mysql_auth" {
  count = local.mysql_create_secret ? 1 : 0
  metadata {
    name      = "mysql-auth"
    namespace = kubernetes_namespace.mysql[0].metadata[0].name
  }
  data = {
    "mysql-password"             = random_password.mysql_password[0].result
    "mysql-root-password"        = random_password.mysql_root_password[0].result
    "mysql-replication-password" = random_password.mysql_replication_password[0].result
  }
}

resource "helm_release" "mysql" {
  count            = var.enabled.mysql ? 1 : 0
  name             = "mysql"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "mysql"
  version          = var.mysql.chart_version
  namespace        = kubernetes_namespace.mysql[0].metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      global = {
        security = {
          allowInsecureImages = var.mysql.allow_insecure_images
        }
      }

      # null fields are dropped rather than emitted as `registry: null`,
      # so an unset override means "leave the chart default alone".
      image = { for k, v in {
        registry   = var.mysql.image_registry
        repository = var.mysql.image_repository
        tag        = var.mysql.image_tag
      } : k => v if v != null }

      architecture = var.mysql.architecture

      auth = {
        database       = "my_database"
        username       = "db_user"
        existingSecret = local.mysql_secret_name
      }

      metrics = {
        enabled = false
      }

      primary = merge({
        service = {
          type = "ClusterIP"
        }
        persistence = {
          enabled      = true
          storageClass = local.mysql_storage_class
          size         = var.mysql.storage_size
        }
      }, local.mysql_resources)

      secondary = merge({
        replicaCount = var.mysql.architecture == "replication" ? var.mysql.secondary_replicas : 0
        persistence = {
          enabled      = true
          storageClass = local.mysql_storage_class
          size         = var.mysql.storage_size
        }
      }, local.mysql_resources)
    }),

    var.mysql.values_extra,
  ]

  # standard-sc is created by this same layer; a PVC naming a class that
  # does not exist yet sits Pending until Helm times out. Empty list on
  # non-aws workspaces (count = 0), so this imposes no ordering there.
  depends_on = [kubernetes_storage_class_v1.standard_sc]

}
