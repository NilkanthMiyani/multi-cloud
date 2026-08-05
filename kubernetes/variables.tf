# ------------------------------------------------------------------------
# Cluster identity
# ------------------------------------------------------------------------
# Read from the infra layer's ../envs/<cloud>.tfvars, which carries all three
# environments; locals.tf indexes it with the env half of the workspace name.
#
# That file declares more per-env fields than this layer needs (node sizes,
# CIDRs). Terraform drops object attributes the declared type does not mention,
# so only cluster_name and project are picked up here.
variable "envs" {
  description = "Per-environment cluster identity, keyed by env name (dev | stage | prod)."
  type = map(object({
    cluster_name = string
    project      = optional(string, "")
  }))
}

# These three come from ../envs/<cloud>.tfvars, which the infra layer also
# reads. Their defaults MUST match the infra layer's — a variable that means one
# thing when omitted here and another there would point the two layers at
# different clusters.
variable "region" {
  description = "AWS region holding the cluster. AWS only."
  type        = string
  default     = "us-east-1"
}

variable "gcp_zone" {
  description = "Zone or region of the GKE cluster. GCP only."
  type        = string
  default     = "us-central1-a"
}

variable "gcp_project" {
  description = "GCP project holding the cluster. Blank uses the provider/ADC default."
  type        = string
  default     = ""
}


# ------------------------------------------------------------------------
# Master on/off switches
# ------------------------------------------------------------------------
# Keyed by environment, so one envs/<cloud>.tfvars can run everything in prod
# and nothing in dev. Everything below the toggles is sized identically across
# environments and stays flat. Anything omitted is false.
variable "enabled" {
  description = "Per-service on/off switches, keyed by env name (dev | stage | prod)."
  type = map(object({
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

    # AWS-only; inert on other clouds.
    alb_controller = optional(bool, false)
  }))

  # An env mapped to {} gets every switch false via the optional() defaults
  # above, so an omitted `enabled` block deploys nothing rather than erroring.
  default = {
    dev   = {}
    stage = {}
    prod  = {}
  }

  validation {
    condition     = alltrue([for e in keys(var.enabled) : contains(["dev", "stage", "prod"], e)])
    error_message = "enabled keys must be one of: dev, stage, prod."
  }
}




# ------------------------------------------------------------------------
# AWS EBS CSI driver
# ------------------------------------------------------------------------
# AWS-only. Installed via Helm rather than the EKS managed addon; the IRSA role
# comes from the infra layer. See kubernetes/aws-helm.tf.
variable "ebs_csi" {
  description = "AWS EBS CSI driver configuration."
  type = object({
    chart_version = optional(string, "2.63.1")
    namespace     = optional(string, "kube-system")
    values_extra  = optional(string, "")
  })
  default = {}
}

# ------------------------------------------------------------------------
# AWS Load Balancer Controller
# ------------------------------------------------------------------------
# AWS-only. The IAM role is created by the infra layer; this layer creates the
# ServiceAccount and the Helm release. See kubernetes/aws-helm.tf.
variable "alb_controller" {
  description = "AWS Load Balancer Controller configuration."
  type = object({
    chart_version = optional(string, "3.5.0")
    namespace     = optional(string, "kube-system")
    values_extra  = optional(string, "")
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


# ------------------------------------------------------------------------
# Cloud credentials — same wiring as the infra layer
# ------------------------------------------------------------------------
# Read from ../envs/<cloud>.tfvars, so both layers resolve the same identity
# from one place. Blank falls back to the cloud's ambient chain. Declaring but
# NOT using these was what made the addon layer 401 on DigitalOcean while the
# infra layer authenticated fine off the same file.

variable "aws_access_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "azure_subscription_id" {
  type    = string
  default = ""
}

variable "azure_tenant_id" {
  type    = string
  default = ""
}

variable "azure_client_id" {
  type    = string
  default = ""
}

variable "azure_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "gcp_region" {
  type    = string
  default = ""
}

variable "gcp_credentials" {
  type    = string
  default = ""
}

variable "do_token" {
  type      = string
  default   = ""
  sensitive = true
}


# ------------------------------------------------------------------------
# Infra-only pass-through — NOTHING HERE IS READ
# ------------------------------------------------------------------------
# ../envs/<cloud>.tfvars also carries values only the infra layer needs (node
# sizing, CIDRs). Terraform warns once per value that is set but not declared,
# and a warning list nobody reads hides the ones that matter — "Helm release
# has a failed status" arrives in the same stream.
#
# Adding an infra-only variable to envs/<cloud>.tfvars? Add it here too.

variable "k8s_version" { default = null }
variable "availability_zones_count" { default = null }
variable "subnet_cidr_bits" { default = null }
variable "node_ami_type" { default = null }
variable "public_access_cidrs" { default = null }
variable "location" { default = null }
variable "do_region" { default = null }
variable "do_k8s_version" { default = null }
variable "do_vpc_cidr" { default = null }
