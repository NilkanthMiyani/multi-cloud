# ==========================================
# SERVICE CONFIGURATION
# ==========================================
#
# One object variable per addon. Every field is optional() with a default, so an
# environment lists only what it changes.
#
# The surface here is deliberately narrow: a field exists only if an env
# actually sets it, or if it is load-bearing. Anything a chart needs but nobody
# varies (service type, metrics, plugin lists, node selectors, db/user names)
# is a literal in the matching *-helm.tf instead of a knob nobody turns.
#
# Every service therefore carries:
#
#   chart_version   pinned; charts otherwise float on every apply
#   namespace
#   storage_size / storage_class    storage_class = null falls back to
#                                   local.storage_class for the cloud (locals.tf)
#   resources       null = emit nothing, let the chart's own preset apply
#   values_extra    raw YAML merged LAST, so any unmodelled chart setting can
#                   be reached without editing the .tf
#
# plus its own shape (replicas / size / architecture) and, where the chart
# supports it, existing_secret to point at a pre-created Secret instead of
# having Terraform generate the password into state.

# ------------------------------------------------------------------------
# Master on/off switches
# ------------------------------------------------------------------------
variable "enabled" {
  description = "Per-service on/off switches. Anything omitted is false."
  type = object({
    redis         = optional(bool, false)
    rabbitmq      = optional(bool, false)
    elasticsearch = optional(bool, false)
    cassandra     = optional(bool, false)
    mongodb       = optional(bool, false)
    postgresql    = optional(bool, false)
    clickhouse    = optional(bool, false)
    mysql         = optional(bool, false)
    meilisearch   = optional(bool, false)
    typesense     = optional(bool, false)
  })
  default = {}
}


# ------------------------------------------------------------------------
# 1. Redis
# ------------------------------------------------------------------------
variable "redis" {
  description = "Redis addon configuration."
  type = object({
    chart_version = optional(string, "23.2.12")
    namespace     = optional(string, "redis")

    # "standalone" ignores replicas; "replication" is 1 master + replicas.
    architecture = optional(string, "standalone")
    replicas     = optional(number, 0)

    storage_size  = optional(string, "8Gi")
    storage_class = optional(string, null)

    # null generates a random_password + Secret. Name a pre-created Secret to
    # keep the password out of Terraform state.
    existing_secret     = optional(string, null)
    existing_secret_key = optional(string, "redis-password")

    image_registry        = optional(string, null)
    image_repository      = optional(string, null)
    image_tag             = optional(string, null)
    allow_insecure_images = optional(bool, false)

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}

  validation {
    condition     = contains(["standalone", "replication"], var.redis.architecture)
    error_message = "redis.architecture must be \"standalone\" or \"replication\"."
  }

  validation {
    condition     = var.redis.architecture != "replication" || var.redis.replicas > 0
    error_message = "redis.architecture = \"replication\" requires redis.replicas > 0."
  }
}


# ------------------------------------------------------------------------
# 2. RabbitMQ
# ------------------------------------------------------------------------
variable "rabbitmq" {
  description = "RabbitMQ addon configuration."
  type = object({
    chart_version = optional(string, "15.0.0")
    namespace     = optional(string, "rabbitmq")

    replicas = optional(number, 1)

    storage_size  = optional(string, "8Gi")
    storage_class = optional(string, null)

    existing_secret = optional(string, null)

    image_registry        = optional(string, null)
    image_repository      = optional(string, "bitnamilegacy/rabbitmq")
    image_tag             = optional(string, null)
    allow_insecure_images = optional(bool, true)

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}
}


# ------------------------------------------------------------------------
# 3. Elasticsearch
# ------------------------------------------------------------------------
variable "elasticsearch" {
  description = "Elasticsearch addon configuration."
  type = object({
    chart_version = optional(string, "7.17.3")
    namespace     = optional(string, "elastic-namespace")

    replicas             = optional(number, 1)
    minimum_master_nodes = optional(number, 1)
    anti_affinity        = optional(string, "soft")

    storage_size  = optional(string, "10Gi")
    storage_class = optional(string, null)

    # Should be <= 50% of resources.limits.memory when resources is set.
    heap_size = optional(string, "1g")

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}

  validation {
    condition     = contains(["soft", "hard"], var.elasticsearch.anti_affinity)
    error_message = "elasticsearch.anti_affinity must be \"soft\" or \"hard\"."
  }
}


# ------------------------------------------------------------------------
# 4. Cassandra (k8ssandra-operator + K8ssandraCluster CR)
# ------------------------------------------------------------------------
variable "cassandra" {
  description = "Cassandra / k8ssandra addon configuration."
  type = object({
    chart_version = optional(string, "1.19.0")
    namespace     = optional(string, "k8ssandra-operator")

    # cert-manager is a hard dependency of k8ssandra-operator. Pinned because it
    # was previously installed with no version, floating on every apply.
    cert_manager_version = optional(string, "v1.21.1")

    cluster_name    = optional(string, "cassandra")
    datacenter_name = optional(string, "datacenter1")
    server_version  = optional(string, "3.11.14")

    size          = optional(number, 1)
    storage_size  = optional(string, "5Gi")
    storage_class = optional(string, null)

    heap_size     = optional(string, "512Mi")
    mgmt_api_heap = optional(string, "64Mi")

    stargate_enabled   = optional(bool, true)
    stargate_size      = optional(number, 1)
    stargate_heap_size = optional(string, "384Mi")

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}
}


# ------------------------------------------------------------------------
# 5. MongoDB (community-operator + MongoDBCommunity CR)
# ------------------------------------------------------------------------
variable "mongodb" {
  description = "MongoDB addon configuration."
  type = object({
    chart_version = optional(string, "0.10.0")
    namespace     = optional(string, "mongo-namespace")

    # Server version, distinct from the operator's chart_version above.
    server_version = optional(string, "6.0.13")
    members        = optional(number, 1)

    storage_size  = optional(string, "10Gi")
    storage_class = optional(string, null)

    existing_secret = optional(string, null)

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}
}


# ------------------------------------------------------------------------
# 6. PostgreSQL
# ------------------------------------------------------------------------
variable "postgresql" {
  description = "PostgreSQL addon configuration."
  type = object({
    # Served from the classic HTTP index, not the OCI registry — 15.5.3 exists
    # only there. See the repository setting in postgresql-helm.tf.
    chart_version = optional(string, "15.5.3")
    namespace     = optional(string, "postgresql")

    architecture = optional(string, "standalone")
    replicas     = optional(number, 0)

    storage_size  = optional(string, "8Gi")
    storage_class = optional(string, null)

    existing_secret = optional(string, null)

    image_registry        = optional(string, null)
    image_repository      = optional(string, "bitnamilegacy/postgresql")
    image_tag             = optional(string, "16.2.0-debian-12-r9")
    allow_insecure_images = optional(bool, false)

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}

  validation {
    condition     = contains(["standalone", "replication"], var.postgresql.architecture)
    error_message = "postgresql.architecture must be \"standalone\" or \"replication\"."
  }
}


# ------------------------------------------------------------------------
# 7. ClickHouse
# ------------------------------------------------------------------------
variable "clickhouse" {
  description = "ClickHouse addon configuration."
  type = object({
    chart_version = optional(string, "9.4.4")
    namespace     = optional(string, "clickhouse")

    shards         = optional(number, 1)
    replicas       = optional(number, 1)
    keeper_enabled = optional(bool, false)

    storage_size  = optional(string, "50Gi")
    storage_class = optional(string, null)

    existing_secret     = optional(string, null)
    existing_secret_key = optional(string, "admin-password")

    image_registry        = optional(string, "docker.io")
    image_repository      = optional(string, "bitnamilegacy/clickhouse")
    image_tag             = optional(string, null)
    allow_insecure_images = optional(bool, true)

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}
}


# ------------------------------------------------------------------------
# 8. MySQL
# ------------------------------------------------------------------------
variable "mysql" {
  description = "MySQL addon configuration."
  type = object({
    chart_version = optional(string, "14.0.3")
    namespace     = optional(string, "mysql")

    architecture       = optional(string, "standalone")
    secondary_replicas = optional(number, 0)

    storage_size  = optional(string, "8Gi")
    storage_class = optional(string, null)

    existing_secret = optional(string, null)

    image_registry        = optional(string, "docker.io")
    image_repository      = optional(string, "bitnamilegacy/mysql")
    image_tag             = optional(string, null)
    allow_insecure_images = optional(bool, false)

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}

  validation {
    condition     = contains(["standalone", "replication"], var.mysql.architecture)
    error_message = "mysql.architecture must be \"standalone\" or \"replication\"."
  }
}


# ------------------------------------------------------------------------
# 9. Meilisearch
# ------------------------------------------------------------------------
variable "meilisearch" {
  description = "Meilisearch addon configuration."
  type = object({
    chart_version = optional(string, "0.35.0")
    namespace     = optional(string, "meilisearch")

    replicas = optional(number, 1)

    storage_size  = optional(string, "10Gi")
    storage_class = optional(string, null)

    existing_secret = optional(string, null)

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}
}


# ------------------------------------------------------------------------
# 10. Typesense (operator + TypesenseOperator CR)
# ------------------------------------------------------------------------
variable "typesense" {
  description = "Typesense addon configuration."
  type = object({
    chart_version = optional(string, "0.1.0")
    namespace     = optional(string, "typesense")

    replicas  = optional(number, 1)
    image     = optional(string, "typesense/typesense")
    image_tag = optional(string, "28.0")

    storage_size  = optional(string, "10Gi")
    storage_class = optional(string, null)

    existing_secret = optional(string, null)

    resources    = optional(any, null)
    values_extra = optional(string, "")
  })
  default = {}
}
