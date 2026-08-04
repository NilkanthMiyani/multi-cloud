# Multi-Cloud Kubernetes

Terraform that provisions a managed Kubernetes cluster on **AWS (EKS)**, **Azure (AKS)**, **GCP (GKE)** or **DigitalOcean (DOKS)**, then optionally deploys databases into it.

Two layers:

| layer | path | builds |
|---|---|---|
| infra | `.` | VPC, cluster, node pool, IAM |
| addons | `kubernetes/` | Redis, RabbitMQ, Elasticsearch, Cassandra, MongoDB, PostgreSQL, ClickHouse, MySQL, Meilisearch, Typesense |

The Terraform workspace name is `<cloud>-<env>` and selects both. Each combination gets its own state and reads `envs/<cloud>-<env>.tfvars`.

```
cloud = aws | az | gcp | do          env = dev | stage | prod
```

## Prerequisites

- Terraform >= 1.5, `kubectl`, `helm`
- CLI + credentials for the cloud you are targeting

| cloud | auth |
|---|---|
| AWS | `aws configure` (or `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) |
| Azure | `az login` + `export ARM_SUBSCRIPTION_ID=<id>` |
| GCP | `gcloud auth application-default login`, set `gcp_project` in tfvars |
| DigitalOcean | `export DIGITALOCEAN_TOKEN=<token>` |

## Usage

```
make <verb> <cloud> <env>
```

Both words are required — nothing defaults, and a typo aborts before Terraform runs.

```bash
make init                      # once per checkout

make plan   aws dev
make apply  aws dev            # prompts; add AUTO=1 to skip
make output aws dev
make destroy aws dev
```

| command | does |
|---|---|
| `make init` | initialize Terraform |
| `make plan <cloud> <env>` | show the plan |
| `make apply <cloud> <env>` | build the cluster, then update kubeconfig |
| `make deploy-addons <cloud> <env>` | deploy the databases enabled in `kubernetes/envs/` |
| `make destroy <cloud> <env>` | tear the cluster down |
| `make output` / `show` / `kubeconfig` | outputs, state, kubeconfig command |
| `make fmt` / `validate` / `upgrade` | format, validate, re-init with `-upgrade` |

`AUTO=1` skips the apply/destroy confirmation.

## Full run

```bash
make apply aws dev             # 1. cluster (also writes kubeconfig)
make deploy-addons aws dev     # 2. databases
```

Step 2 is a no-op until you turn something on.

## Enabling a database

Edit `kubernetes/envs/<cloud>-<env>.tfvars`. The toggle block at the top is the only thing you normally touch:

```hcl
enabled = {
  redis      = true
  postgresql = true
  mysql      = false
  # ...
}
```

Then `make deploy-addons <cloud> <env>`.

Sizing lives below the toggles and is **identical across dev/stage/prod** — only `storage_class` differs per cloud (`gp2`, `standard-rwo`, `default`, `do-block-storage`). Defaults for everything else are in `kubernetes/variables.tf`; a tfvars entry only lists what it changes:

```hcl
redis = {
  architecture  = "standalone"
  storage_size  = "8Gi"
  storage_class = "gp2"
}
```

## Credentials

Terraform generates each database password with `random_password` and writes a Secret; charts reference it by name.

### All of them at once

Prints every credential for whichever services are deployed, skipping the rest. Needs `jq`.

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

```
redis/redis-auth                        redis-password          <16-char generated>
rabbitmq/rabbitmq-auth                  rabbitmq-password       <16-char generated>
k8ssandra-operator/cassandra-superuser  password                <20-char generated>
...
```

### One at a time

```bash
kubectl get secret redis-auth -n redis -o jsonpath='{.data.redis-password}' | base64 -d; echo
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

Elasticsearch is absent because chart 7.17.3 runs with security off — no credentials exist.

Cassandra's secret is named `<cluster_name>-superuser` and is created by k8ssandra, not Terraform; it changes if you change `cassandra.cluster_name`. Everything else in the table is Terraform-managed.

### Connecting

```bash
kubectl exec -it -n redis redis-master-0 -- \
  redis-cli -a "$(kubectl get secret redis-auth -n redis -o jsonpath='{.data.redis-password}' | base64 -d)"

kubectl port-forward -n postgresql svc/postgresql 5432:5432
kubectl port-forward -n rabbitmq   svc/rabbitmq   15672:15672   # management UI
```


## Teardown

**Addons first.** The addon state points at in-cluster objects; if the cluster goes first, Terraform can't reach the API server to clean up.

```bash
cd kubernetes
terraform workspace select aws-dev
terraform destroy -var-file=envs/aws-dev.tfvars
cd ..
make destroy aws dev
```

If the cluster is already gone, drop the stale state instead: `rm -rf kubernetes/terraform.tfstate.d/<cloud>-<env>/`.

## Layout

```
├── main.tf providers.tf variables.tf outputs.tf locals.tf
├── envs/<cloud>-<env>.tfvars          cluster size, region, CIDRs
├── modules/{aws,azure,gcp,do}/        one per cloud
└── kubernetes/
    ├── variables.tf locals.tf providers.tf
    ├── <service>-helm.tf              one per database
    └── envs/<cloud>-<env>.tfvars      toggles + sizing
```

## Known gaps

- **State is local.** `terraform.tfstate.d/` is gitignored, so there is no locking or sharing, and generated passwords sit in plaintext state. Move to a remote backend before real use.
- **No `destroy-addons` target** — use the manual sequence above.
- **Bitnami charts** pin `bitnamilegacy/*` images because the public catalog moved behind a paid tier. Mirror them into your own registry and set `image_registry` / `image_repository`.
