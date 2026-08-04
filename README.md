# Multi-Cloud Kubernetes

Terraform that provisions a managed Kubernetes cluster on **AWS (EKS)**, **Azure (AKS)**, **GCP (GKE)** or **DigitalOcean (DOKS)**, then optionally deploys databases into it.

Two layers:

| layer | path | builds |
|---|---|---|
| infra | `.` | VPC, cluster, node pool, IAM |
| addons | `kubernetes/` | Redis, RabbitMQ, Elasticsearch, Cassandra, MongoDB, PostgreSQL, ClickHouse, MySQL, Meilisearch, Typesense, AWS Load Balancer Controller |

A few addons span both layers: the AWS Load Balancer Controller's IAM role is
created by the infra layer and its ServiceAccount + Helm release by the addon
layer, which finds the role by name. Same split as the AWS StorageClass —
anything that calls a cloud API lives in `.`, anything that calls the Kubernetes
API lives in `kubernetes/`.

The Terraform workspace name is `<cloud>-<env>` and selects both. Each combination gets its own state. Inputs come from `envs/<cloud>.tfvars`, which carries all three environments under an `envs` map — the env half of the workspace name picks one.

```
cloud = aws | az | gcp | do          env = dev | stage | prod
```

Anything identical across the three environments sits at the top of the file;
anything that differs goes under `envs`:

```hcl
region      = "us-east-1"            # shared by dev, stage and prod
k8s_version = "1.36"

envs = {
  dev   = { cluster_name = "dev-aws",   project = "dev-proj",   node_size = "t3.small"  }
  stage = { cluster_name = "stage-aws", project = "stage-proj", node_size = "t3.medium" }
  prod  = { cluster_name = "prod-aws",  project = "prod-proj",  node_size = "t3.medium" }
}
```

`Project` and `Env` tags are derived from `project` and the workspace, so there
is no tag block to keep in sync. `var.tags` merges extras on top if you need
them (GCP gets lowercase `project`/`env` labels, as GKE requires).

## Prerequisites

- Terraform >= 1.5, `kubectl`, `helm`
- CLI + credentials for the cloud you are targeting

| cloud | auth | also needed for addons |
|---|---|---|
| AWS | `aws configure` (or `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) | `aws` CLI |
| Azure | `az login` + `export ARM_SUBSCRIPTION_ID=<id>` | `kubelogin` (`az aks install-cli`) |
| GCP | `gcloud auth application-default login`, set `gcp_project` in tfvars | `gke-gcloud-auth-plugin` (`gcloud components install gke-gcloud-auth-plugin`) |
| DigitalOcean | `export DIGITALOCEAN_TOKEN=<token>` | `doctl` (`doctl auth init`) |


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
| `make connect <cloud> <env>` | write the kubeconfig **and prove it works** |
| `make destroy <cloud> <env>` | tear the cluster down |
| `make destroy-addons <cloud> <env>` | remove the addons, keep the cluster |
| `make destroy-all <cloud> <env>` | addons then cluster, in the required order |
| `make output` / `show` / `kubeconfig` | outputs, state, kubeconfig command |
| `make fmt` / `validate` / `upgrade` | format, validate, re-init with `-upgrade` |

`AUTO=1` skips the apply/destroy confirmation.

## Full run

```bash
make apply aws dev             # 1. cluster (also writes kubeconfig)
make deploy-addons aws dev     # 2. databases
```

Step 2 is a no-op until you turn something on.

`make apply` finishes by running `make connect`, which writes the kubeconfig and
then actually calls the cluster. This matters because `aws eks update-kubeconfig`
(and the gcloud/az/doctl equivalents) only *write a file* — they never contact
the cluster, so they report success even when the context that results cannot
authenticate. Without the check the failure surfaces much later, during
`deploy-addons`, as an opaque `Unauthorized`.

If it fails, `make diagnose <cloud> <env>` names the cause:

```
  context         : arn:aws:eks:ap-south-1:310318659882:cluster/prod-aws
  cluster account : 310318659882
  CLI account     : 216731772708

  ACCOUNT MISMATCH — the cluster lives in 310318659882, the CLI authenticates as 216731772708.
  get-token still mints a valid token, so EKS returns 401 rather than 'not found'.
  Fix: make connect aws prod AWS_PROFILE=<profile for account 310318659882>
```

It distinguishes four cases: no credentials, wrong AWS account, a context
pointing at a different cluster entirely, and credentials that are correct but
whose IAM principal is missing from the cluster's access entries.

**On AWS, pass `AWS_PROFILE` if you want plain `kubectl` to work.** With keys in
`envs/aws.tfvars`, `make` injects them for its own commands, but the kubeconfig
it writes carries no credentials — `kubectl` re-runs `aws eks get-token` in your
shell against `~/.aws/credentials`, which may be a different account. `connect`
checks for exactly this and warns rather than reporting a false OK:

```bash
make apply aws prod AWS_PROFILE=multicloud    # bakes AWS_PROFILE into the kubeconfig
```

## Enabling a database

Edit `kubernetes/envs/<cloud>.tfvars`. The toggle block at the top is the only thing you normally touch, and it is keyed by environment:

```hcl
enabled = {
  dev = {
    redis      = true
    postgresql = true
    mysql      = false
    # ...
  }
  stage = { ... }
  prod  = { ... }
}
```

Then `make deploy-addons <cloud> <env>`.

Sizing lives below the toggles. It is **identical across dev/stage/prod**, so unlike the toggles it is declared once and not env-keyed — only `storage_class` differs per cloud (`standard-sc`, `standard-rwo`, `default`, `do-block-storage`). Defaults for everything else are in `kubernetes/variables.tf`; a tfvars entry only lists what it changes:

```hcl
redis = {
  architecture  = "standalone"
  storage_size  = "8Gi"
  storage_class = "standard-sc"
}
```

On AWS, `standard-sc` is created by the addon layer itself ([`aws-helm.tf`](kubernetes/aws-helm.tf)) — gp2-backed but with `Retain`, `WaitForFirstConsumer` and volume expansion, and it demotes EKS's stock `gp2` from default at the same time. The other three clouds use their built-in default class.

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

```bash
make destroy-all aws dev       # addons, then the cluster
```

**Order matters, which is why this is one target.** The addon layer's providers
authenticate against the live cluster API, so once the cluster is gone Terraform
cannot reach the addons to clean them up — and the state has to be deleted by
hand. Run the two halves separately with `make destroy-addons` / `make destroy`
if you want to keep the cluster.

If the cluster is already gone, drop the stale addon state instead:
`rm -rf kubernetes/terraform.tfstate.d/<cloud>-<env>/`.

Two things that can stall it:

- **A namespace stuck `Terminating`** means a finalizer is waiting on an
  operator that is already deleted. `kubectl get ns <ns> -o jsonpath='{.status.conditions}'`
  names what is blocking; the usual culprits are custom resources whose operator
  went first, and orphaned cluster-scoped webhooks that reject the patch used to
  clear them.
- **On AWS, EBS volumes survive.** `standard-sc` sets `reclaim_policy = Retain`
  deliberately, so PVs outlive the cluster and keep billing. `destroy-all`
  prints the command to list them.

## Layout

```
├── main.tf providers.tf variables.tf outputs.tf locals.tf
├── envs/<cloud>.tfvars                dev+stage+prod: sizes, region, CIDRs
├── modules/{aws,azure,gcp,do}/        one per cloud
└── kubernetes/
    ├── variables.tf locals.tf providers.tf
    ├── <service>-helm.tf              one per database
    └── envs/<cloud>.tfvars            per-env toggles + shared sizing
```

