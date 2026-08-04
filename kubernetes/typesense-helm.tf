# ------------------------------------------------------------------------
# Typesense
# ------------------------------------------------------------------------

locals {
  typesense_resources = var.typesense.resources != null ? { resources = var.typesense.resources } : {}

  typesense_create_secret = local.enabled.typesense && var.typesense.existing_secret == null

  typesense_secret_name = (
    var.typesense.existing_secret != null
    ? var.typesense.existing_secret
    : one(kubernetes_secret.typesense_auth[*].metadata[0].name)
  )

  typesense_storage_class = coalesce(var.typesense.storage_class, local.storage_class)
}

resource "kubernetes_namespace" "typesense" {
  count = local.enabled.typesense ? 1 : 0
  metadata {
    name = var.typesense.namespace

    annotations = {
      "meta.helm.sh/release-name"      = "typesense-operator"
      "meta.helm.sh/release-namespace" = var.typesense.namespace
    }

    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }
}

resource "helm_release" "typesense_operator" {
  count            = local.enabled.typesense ? 1 : 0
  name             = "typesense-operator"
  repository       = "https://sai3010.github.io/Typesense-Kubernetes-Operator-Charts/"
  chart            = "typesense-kubernetes-operator"
  version          = var.typesense.chart_version
  namespace        = kubernetes_namespace.typesense[0].metadata[0].name
  create_namespace = false
  depends_on       = [kubernetes_namespace.typesense]

  values = [
    yamlencode({
      namespace = kubernetes_namespace.typesense[0].metadata[0].name
    }),

    var.typesense.values_extra,
  ]
}

resource "random_password" "typesense_apikey" {
  count   = local.typesense_create_secret ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret" "typesense_auth" {
  count = local.typesense_create_secret ? 1 : 0
  metadata {
    name      = "typesense-apikey"
    namespace = kubernetes_namespace.typesense[0].metadata[0].name
  }
  data = {
    "apikey" = random_password.typesense_apikey[0].result
  }
}

resource "kubectl_manifest" "typesense_cluster" {
  count = local.enabled.typesense ? 1 : 0
  yaml_body = yamlencode({
    "apiVersion" = "typesenseproject.org/v1"
    "kind"       = "TypesenseOperator"
    "metadata" = {
      "name"      = "typesense-operator"
      "namespace" = kubernetes_namespace.typesense[0].metadata[0].name
    }
    "spec" = merge({
      "replicas" = var.typesense.replicas
      "image"    = "${var.typesense.image}:${var.typesense.image_tag}"
      "env" = [
        {
          "name" = "APIKEY"
          "valueFrom" = {
            "secretKeyRef" = {
              "name" = local.typesense_secret_name
              "key"  = "apikey"
            }
          }
        }
      ]
      "storageClass" = {
        "name" = local.typesense_storage_class
        "size" = var.typesense.storage_size
      }
    }, local.typesense_resources)
    "config" = {
      "secret" = {
        "name"      = local.typesense_secret_name
        "namespace" = kubernetes_namespace.typesense[0].metadata[0].name
      }
      "env" = {
        "TYPESENSE_ENABLE_CORS" = "true"
      }
    }
  })

  depends_on = [
    helm_release.alb_controller,
    helm_release.typesense_operator,
    kubernetes_secret.typesense_auth,
    kubernetes_storage_class_v1.standard_sc,
  ]
}
