# ------------------------------------------------------------------------
# Elasticsearch
# ------------------------------------------------------------------------

locals {
  elasticsearch_resources = var.elasticsearch.resources != null ? { resources = var.elasticsearch.resources } : {}

  elasticsearch_storage_class = coalesce(var.elasticsearch.storage_class, local.storage_class)
}

resource "kubernetes_namespace" "elasticsearch" {
  count = local.enabled.elasticsearch ? 1 : 0
  metadata {
    name = var.elasticsearch.namespace
  }
}

resource "helm_release" "elasticsearch" {
  count            = local.enabled.elasticsearch ? 1 : 0
  name             = "elasticsearch"
  repository       = "https://helm.elastic.co"
  chart            = "elasticsearch"
  version          = var.elasticsearch.chart_version
  namespace        = kubernetes_namespace.elasticsearch[0].metadata[0].name
  create_namespace = false

  values = [
    yamlencode(merge({
      replicas           = var.elasticsearch.replicas
      minimumMasterNodes = var.elasticsearch.minimum_master_nodes
      antiAffinity       = var.elasticsearch.anti_affinity

      esJavaOpts = "-Xmx${var.elasticsearch.heap_size} -Xms${var.elasticsearch.heap_size}"


      service = {
        type = "ClusterIP"
      }

      persistence = {
        enabled = true
      }

      volumeClaimTemplate = {
        accessModes      = ["ReadWriteOnce"]
        storageClassName = local.elasticsearch_storage_class
        resources = {
          requests = {
            storage = var.elasticsearch.storage_size
          }
        }
      }
    }, local.elasticsearch_resources)),

    var.elasticsearch.values_extra,
  ]

  depends_on = [kubernetes_storage_class_v1.standard_sc, helm_release.alb_controller]

}
