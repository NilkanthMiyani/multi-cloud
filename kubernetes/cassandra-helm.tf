# ------------------------------------------------------------------------
# Cassandra (k8ssandra-operator)
# ------------------------------------------------------------------------

locals {
  cassandra_resources = var.cassandra.resources != null ? { resources = var.cassandra.resources } : {}

  cassandra_storage_class = coalesce(var.cassandra.storage_class, local.storage_class)

  cassandra_datacenter = merge(
    {
      "metadata" = {
        "name" = var.cassandra.datacenter_name
      }
      "size" = var.cassandra.size
      "storageConfig" = {
        "cassandraDataVolumeClaimSpec" = {
          "storageClassName" = local.cassandra_storage_class
          "accessModes"      = ["ReadWriteOnce"]
          "resources" = {
            "requests" = {
              "storage" = var.cassandra.storage_size
            }
          }
        }
      }
      "config" = {
        "jvmOptions" = {
          "heap_initial_size" = var.cassandra.heap_size
          "heap_max_size"     = var.cassandra.heap_size
          "gc"                = "G1GC"
        }
      }
    },
    var.cassandra.stargate_enabled ? {
      "stargate" = {
        "size"     = var.cassandra.stargate_size
        "heapSize" = var.cassandra.stargate_heap_size
        "livenessProbe" = {
          "initialDelaySeconds" = 100
          "periodSeconds"       = 10
          "failureThreshold"    = 20
          "successThreshold"    = 1
          "timeoutSeconds"      = 20
        }
        "readinessProbe" = {
          "initialDelaySeconds" = 100
          "periodSeconds"       = 10
          "failureThreshold"    = 20
          "successThreshold"    = 1
          "timeoutSeconds"      = 20
        }
      }
    } : {},
  )
}

resource "helm_release" "cert_manager" {
  count            = var.enabled.cassandra ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cassandra.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "k8ssandra_operator" {
  count            = var.enabled.cassandra ? 1 : 0
  name             = "k8ssandra-operator"
  repository       = "https://helm.k8ssandra.io/stable"
  chart            = "k8ssandra-operator"
  version          = var.cassandra.chart_version
  namespace        = var.cassandra.namespace
  create_namespace = true

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "cassandra_cluster" {
  count = var.enabled.cassandra ? 1 : 0
  yaml_body = yamlencode({
    "apiVersion" = "k8ssandra.io/v1alpha1"
    "kind"       = "K8ssandraCluster"
    "metadata" = {
      "name"      = var.cassandra.cluster_name
      "namespace" = var.cassandra.namespace
    }
    "spec" = {
      "cassandra" = merge({
        "serverVersion" = var.cassandra.server_version
        "clusterName"   = var.cassandra.cluster_name
        "telemetry" = {
          "mcac" = {
            "enabled" = false
          }
          "vector" = {
            "enabled" = true
            "components" = {
              "sinks" = [
                {
                  "name"   = "void"
                  "type"   = "blackhole"
                  "inputs" = ["cassandra_metrics"]
                }
              ]
            }
            "scrapeInterval" = "30s"
            "resources" = {
              "requests" = {
                "cpu"    = "100m"
                "memory" = "128Mi"
              }
              "limits" = {
                "cpu"    = "100m"
                "memory" = "128Mi"
              }
            }
          }
        }
        "datacenters" = [local.cassandra_datacenter]
        "mgmtAPIHeap" = var.cassandra.mgmt_api_heap
      }, local.cassandra_resources)
    }
  })

  depends_on = [helm_release.k8ssandra_operator]
}
