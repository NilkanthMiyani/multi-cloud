# ------------------------------------------------------------------------
# 5. MongoDB (community-operator)
# ------------------------------------------------------------------------

locals {
  mongodb_resources = var.mongodb.resources != null ? { resources = var.mongodb.resources } : {}

  mongodb_create_secret = var.enabled.mongodb && var.mongodb.existing_secret == null

  mongodb_secret_name = (
    var.mongodb.existing_secret != null
    ? var.mongodb.existing_secret
    : one(kubernetes_secret.mongodb_auth[*].metadata[0].name)
  )

  mongodb_storage_class = coalesce(var.mongodb.storage_class, local.storage_class)
}

resource "kubernetes_namespace" "mongodb" {
  count = var.enabled.mongodb ? 1 : 0
  metadata {
    name = var.mongodb.namespace
  }
}

resource "helm_release" "mongodb_operator" {
  count            = var.enabled.mongodb ? 1 : 0
  name             = "community-operator"
  repository       = "https://mongodb.github.io/helm-charts"
  chart            = "community-operator"
  version          = var.mongodb.chart_version
  namespace        = kubernetes_namespace.mongodb[0].metadata[0].name
  create_namespace = false

  values = [
    var.mongodb.values_extra,
  ]
}

resource "random_password" "mongodb_password" {
  count   = local.mongodb_create_secret ? 1 : 0
  length  = 16
  special = false
}

resource "kubernetes_secret" "mongodb_auth" {
  count = local.mongodb_create_secret ? 1 : 0
  metadata {
    name      = "root-password"
    namespace = kubernetes_namespace.mongodb[0].metadata[0].name
  }
  data = {
    "password" = random_password.mongodb_password[0].result
  }
}

resource "kubectl_manifest" "mongodb_cluster" {
  count = var.enabled.mongodb ? 1 : 0
  yaml_body = yamlencode({
    "apiVersion" = "mongodbcommunity.mongodb.com/v1"
    "kind"       = "MongoDBCommunity"
    "metadata" = {
      "name"      = "mongodb"
      "namespace" = kubernetes_namespace.mongodb[0].metadata[0].name
    }
    "spec" = {
      "members" = var.mongodb.members
      "type"    = "ReplicaSet"
      "version" = var.mongodb.server_version
      "security" = {
        "authentication" = {
          "modes" = ["SCRAM"]
        }
      }
      "users" = [
        {
          "name" = "root"
          "db"   = "admin"
          "passwordSecretRef" = {
            "name" = local.mongodb_secret_name
          }
          "roles" = [
            { "name" = "atlasAdmin", "db" = "admin" },
            { "name" = "clusterAdmin", "db" = "admin" },
            { "name" = "userAdminAnyDatabase", "db" = "admin" },
            { "name" = "dbAdminAnyDatabase", "db" = "admin" },
            { "name" = "readWriteAnyDatabase", "db" = "admin" },
            { "name" = "root", "db" = "admin" },
          ]
          "scramCredentialsSecretName" = "my-scram"
        }
      ]
      "additionalMongodConfig" = {
        "storage.wiredTiger.engineConfig.journalCompressor" = "zlib"
      }

      # Previously absent entirely, so volume size/class and pod resources fell
      # back to operator defaults with no way to influence them from an env.
      "statefulSet" = {
        "spec" = {
          "volumeClaimTemplates" = [
            {
              "metadata" = { "name" = "data-volume" }
              "spec" = {
                "accessModes"      = ["ReadWriteOnce"]
                "storageClassName" = local.mongodb_storage_class
                "resources" = {
                  "requests" = { "storage" = var.mongodb.storage_size }
                }
              }
            }
          ]
          "template" = {
            "spec" = {
              "containers" = [
                merge({ "name" = "mongod" }, local.mongodb_resources)
              ]
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.mongodb_operator,
    kubernetes_secret.mongodb_auth
  ]
}
