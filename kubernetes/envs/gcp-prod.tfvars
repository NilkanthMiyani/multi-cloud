# ==========================================
# SERVICE TOGGLES  (gcp-prod)
# ==========================================

enabled = {
  redis         = true
  rabbitmq      = true
  elasticsearch = true
  cassandra     = true
  mongodb       = true
  postgresql    = true
  clickhouse    = true
  mysql         = true
  meilisearch   = true
  typesense     = true
}

# ==========================================
# SERVICE CONFIGURATION
# ==========================================

redis = {
  architecture  = "standalone"
  replicas      = 0
  storage_size  = "8Gi"
  storage_class = "standard-rwo"
}

rabbitmq = {
  replicas      = 1
  storage_size  = "8Gi"
  storage_class = "standard-rwo"
}

elasticsearch = {
  replicas             = 1
  minimum_master_nodes = 1
  anti_affinity        = "soft"
  storage_size         = "10Gi"
  storage_class        = "standard-rwo"
  heap_size            = "1g"

  resources = {
    requests = { cpu = "512m", memory = "1Gi" }
    limits   = { cpu = "1000m", memory = "2Gi" }
  }
}

cassandra = {
  size               = 1
  storage_size       = "5Gi"
  storage_class      = "standard-rwo"
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
  storage_class = "standard"
}

postgresql = {
  architecture  = "standalone"
  storage_size  = "8Gi"
  storage_class = "standard"
}

clickhouse = {
  shards         = 1
  replicas       = 1
  keeper_enabled = false
  storage_size   = "50Gi"
  storage_class  = "standard"

  resources = {
    requests = { cpu = "500m", memory = "1Gi" }
    limits   = { cpu = "1500m", memory = "3Gi" }
  }
}

mysql = {
  architecture  = "standalone"
  storage_size  = "8Gi"
  storage_class = "standard"
}

meilisearch = {
  replicas      = 1
  storage_size  = "10Gi"
  storage_class = "standard"
}

typesense = {
  replicas      = 1
  storage_size  = "10Gi"
  storage_class = "standard"
}
