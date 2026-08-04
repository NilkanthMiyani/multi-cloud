# Multi-Cloud Kubernetes

Terraform for a managed Kubernetes cluster on **AWS (EKS)**, **Azure (AKS)**, **GCP (GKE)** or **DigitalOcean (DOKS)**, plus optional databases.

| layer | path | builds |
|---|---|---|
| infra | `.` | VPC, cluster, node pool, IAM |
| addons | `kubernetes/` | Redis, RabbitMQ, Elasticsearch, Cassandra, MongoDB, PostgreSQL, ClickHouse, MySQL, Meilisearch, Typesense, AWS Load Balancer Controller |

Workspace name is `<cloud>-<env>` and selects both. Inputs come from `envs/<cloud>.tfvars`, which holds all three environments under an `envs` map.

```
cloud = aws | az | gcp | do          env = dev | stage | prod
```

## Prerequisites

Terraform >= 1.5, `kubectl`, `helm`, plus your cloud's CLI:

| cloud | auth | addon CLI |
|---|---|---|
| AWS | `aws configure`, or set `aws_access_key`/`aws_secret_key` in tfvars | `aws` |
| Azure | `az login` + `export ARM_SUBSCRIPTION_ID=<id>` | `kubelogin` |
| GCP | `gcloud auth application-default login`, set `gcp_project` | `gke-gcloud-auth-plugin` |
| DigitalOcean | `export DIGITALOCEAN_TOKEN=<token>` | `doctl` |

## Usage

```bash
make init                      # once per checkout

make plan   aws dev
make apply  aws dev            # cluster + kubeconfig + verify access
make deploy-addons aws dev     # databases
make destroy-all  aws dev      # addons, then cluster
```

| command | does |
|---|---|
| `make plan/apply/destroy <cloud> <env>` | the cluster |
| `make deploy-addons <cloud> <env>` | databases enabled in `kubernetes/envs/` |
| `make destroy-addons <cloud> <env>` | remove addons, keep the cluster |
| `make destroy-all <cloud> <env>` | addons then cluster, in the required order |
| `make connect <cloud> <env>` | write kubeconfig and verify it works |
| `make diagnose <cloud> <env>` | why `kubectl` can't reach the cluster |
| `make output` / `show` / `kubeconfig` | outputs, state, kubeconfig |
| `make fmt` / `validate` / `upgrade` | format, validate, re-init |

`AUTO=1` skips the apply/destroy prompt. Cloud and env are both required.

## Configuration

`envs/<cloud>.tfvars` — shared values at the top, per-environment under `envs`:

```hcl
region      = "us-east-1"
k8s_version = "1.36"

envs = {
  dev   = { cluster_name = "dev-aws",   project = "dev-proj",   node_size = "t3.small"  }
  stage = { cluster_name = "stage-aws", project = "stage-proj", node_size = "t3.medium" }
  prod  = { cluster_name = "prod-aws",  project = "prod-proj",  node_size = "t3.medium" }
}
```

`Project`/`Env` tags are derived automatically. `var.tags` adds extras.

## Enabling a database

`kubernetes/envs/<cloud>.tfvars` — toggles are per-environment, sizing is shared:

```hcl
enabled = {
  dev   = { redis = true, postgresql = true }
  stage = { }
  prod  = { }
}

redis = {
  architecture  = "standalone"
  storage_size  = "8Gi"
  storage_class = "standard-sc"
}
```

Then `make deploy-addons <cloud> <env>`. Defaults live in `kubernetes/variables.tf`; a tfvars entry lists only what it changes.

`storage_class` per cloud: `standard-sc` (AWS, created by the addon layer), `standard-rwo` (GCP), `default` (Azure), `do-block-storage` (DO).

## Credentials

Passwords are generated with `random_password` and written to Secrets.

```bash
while read -r ns secret; do
  kubectl get secret "$secret" -n "$ns" -o json 2>/dev/null | jq -r --arg s "$ns/$secret" '
    (.data // {}) | to_entries[] | "\($s)\t\(.key)\t\(.value|@base64d)"'
done <<'LIST' | column -t -s $'\t'
redis               redis-auth
rabbitmq            rabbitmq-auth
k8ssandra-operator  cassandra-superuser
mongo-namespace     root-password
postgresql          postgresql-auth
clickhouse          clickhouse-auth
mysql               mysql-auth
meilisearch         meilisearch-auth
typesense           typesense-apikey
LIST
```

| service | namespace | secret | keys |
|---|---|---|---|
| redis | `redis` | `redis-auth` | `redis-password` |
| rabbitmq | `rabbitmq` | `rabbitmq-auth` | `rabbitmq-password`, `rabbitmq-erlang-cookie` |
| cassandra | `k8ssandra-operator` | `cassandra-superuser` | `username`, `password` |
| mongodb | `mongo-namespace` | `root-password` | `password` |
| postgresql | `postgresql` | `postgresql-auth` | `password`, `postgres-password` |
| clickhouse | `clickhouse` | `clickhouse-auth` | `admin-password` |
| mysql | `mysql` | `mysql-auth` | `mysql-password`, `mysql-root-password`, `mysql-replication-password` |
| meilisearch | `meilisearch` | `meilisearch-auth` | `MEILI_MASTER_KEY` |
| typesense | `typesense` | `typesense-apikey` | `apikey` |

Elasticsearch has none — chart 7.17.3 runs with security off. Cassandra's secret is created by k8ssandra and renames with `cassandra.cluster_name`.

```bash
kubectl get secret redis-auth -n redis -o jsonpath='{.data.redis-password}' | base64 -d; echo
kubectl port-forward -n rabbitmq svc/rabbitmq 15672:15672
```

## Layout

```
├── main.tf providers.tf variables.tf outputs.tf locals.tf
├── envs/<cloud>.tfvars                dev+stage+prod cluster config
├── modules/{aws,azure,gcp,do}/        one per cloud
└── kubernetes/
    ├── variables.tf locals.tf providers.tf data-sources.tf
    ├── <service>-helm.tf              one per database
    └── envs/<cloud>.tfvars            toggles + sizing
```

## Notes

- **AWS:** `make` injects `aws_access_key`/`aws_secret_key` from tfvars into the `aws` CLI, but the kubeconfig doesn't carry them. For bare `kubectl`, export the same keys or run `aws configure`.
- **AWS:** `standard-sc` uses `reclaim_policy = Retain`, so EBS volumes survive `destroy` and keep billing. `destroy-all` prints the command to list them.
- **Teardown order matters.** The addon layer talks to the live cluster API. If the cluster goes first, delete its state by hand: `rm -rf kubernetes/terraform.tfstate.d/<cloud>-<env>/`.
- A namespace stuck `Terminating` is a finalizer waiting on a deleted operator — `kubectl get ns <ns> -o jsonpath='{.status.conditions}'`.
- The addon layer reads the infra var-file for cluster identity, so Terraform warns about the infra-only values in it. Expected.
- State is local and gitignored: no locking or sharing, and generated passwords sit in plaintext. Move to a remote backend before real use.
- Bitnami charts pin `bitnamilegacy/*` images because the public catalog moved behind a paid tier.
