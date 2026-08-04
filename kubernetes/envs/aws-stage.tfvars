# ==========================================
# SERVICE TOGGLES  (aws-stage)
# ==========================================

enabled = {
  redis         = false
  rabbitmq      = false
  elasticsearch = false
  cassandra     = false
  mongodb       = false
  postgresql    = false
  clickhouse    = false
  mysql         = false
  meilisearch   = false
  typesense     = false
}

# ==========================================
# SERVICE CONFIGURATION
# ==========================================

redis = {
  architecture  = "standalone"
  replicas      = 0
  storage_size  = "8Gi"
  storage_class = "standard-sc"
}

rabbitmq = {
  replicas      = 1
  storage_size  = "8Gi"
  storage_class = "standard-sc"
}

elasticsearch = {
  replicas             = 1
  minimum_master_nodes = 1
  anti_affinity        = "soft"
  storage_size         = "10Gi"
  storage_class        = "standard-sc"
  heap_size            = "1g"

  resources = {
    requests = { cpu = "512m", memory = "1Gi" }
    limits   = { cpu = "1000m", memory = "2Gi" }
  }
}

cassandra = {
  size               = 1
  storage_size       = "5Gi"
  storage_class      = "standard-sc"
  heap_size          = "512Mi"
  stargate_enabled   = true
  stargate_size      = 1
  stargate_heap_size = "384Mi"
  mgmt_api_heap      = "64Mi"

  resources = {
    requests = { cpu = "1", memory = "2Gi" }
    limits   = { cpu = "2", memory = "2Gi" }
  }
}

mongodb = {
  members       = 1
  storage_size  = "10Gi"
  storage_class = "standard-sc"
}

postgresql = {
  architecture  = "standalone"
  storage_size  = "8Gi"
  storage_class = "standard-sc"
}

clickhouse = {
  shards         = 1
  replicas       = 1
  keeper_enabled = false
  storage_size   = "50Gi"
  storage_class  = "standard-sc"

  resources = {
    requests = { cpu = "500m", memory = "1Gi" }
    limits   = { cpu = "1500m", memory = "3Gi" }
  }
}

mysql = {
  architecture  = "standalone"
  storage_size  = "8Gi"
  storage_class = "standard-sc"
}

meilisearch = {
  replicas      = 1
  storage_size  = "10Gi"
  storage_class = "standard-sc"
}

typesense = {
  replicas      = 1
  storage_size  = "10Gi"
  storage_class = "standard-sc"
}
