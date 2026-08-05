# Multi-cloud, multi-env Terraform driver (single codebase).
#
# The Terraform workspace name is "<cloud>-<env>" (e.g. aws-dev, gcp-stage,
# az-prod). That single name selects BOTH the cloud and the environment, and
# gives each combination its own state file (terraform.tfstate.d/<cloud>-<env>/).
# Inputs come from envs/<cloud>.tfvars, which holds dev, stage and prod together
# under an "envs" map; the env half of the workspace name picks one. These
# targets keep the workspace and the -var-file lined up for you.
#
# Usage — give the verb, then the cloud and env as plain words:
#   make plan aws dev      make apply az stage      make destroy gcp prod
#   make output aws prod   make show do dev
#
#
# Skip the apply/destroy confirmation prompt with AUTO=1:
#   make apply aws prod AUTO=1


TF     := terraform
CLOUDS := aws az gcp do
ENVS   := dev stage prod
VERBS  := help init    fmt validate plan apply destroy output show kubeconfig \
          connect diagnose deploy-addons destroy-addons destroy-all

# Cloud and env are passed as bare goals (make plan aws dev). Pick them out of
# the goals make was invoked with; CLOUD=aws / ENV=dev on the command line still
# work and win. Neither has a default — see guard-args below.
CLOUD ?= $(firstword $(filter $(CLOUDS),$(MAKECMDGOALS)))
ENV   ?= $(firstword $(filter $(ENVS),$(MAKECMDGOALS)))

# Anything on the command line that isn't a verb, a cloud, or an env.
UNKNOWN = $(filter-out $(VERBS) $(CLOUDS) $(ENVS),$(MAKECMDGOALS))
# More than one cloud, env, or verb named at once is also a mistake.
CLOUDN  = $(words $(filter $(CLOUDS),$(MAKECMDGOALS)))
ENVN    = $(words $(filter $(ENVS),$(MAKECMDGOALS)))
VERBN   = $(words $(filter $(VERBS),$(MAKECMDGOALS)))

# One var-file per cloud, carrying all three environments; the workspace's env
# half selects which one applies. See variables.tf ("envs").
WORKSPACE = $(CLOUD)-$(ENV)
VARFILE   = envs/$(CLOUD).tfvars

# The aws CLI cannot read tfvars. Anything that shells out to it — `kubeconfig`,
# `connect`, and the addon layer's exec auth (`aws eks get-token`, run as a
# terraform subprocess) — would otherwise authenticate as whatever
# ~/.aws/credentials holds. If that is a different account you get "No cluster
# found" or a 401, on a cluster that built perfectly.
#
# Expands to a VAR=val prefix when envs/aws.tfvars supplies non-blank keys, and
# to nothing otherwise, leaving the normal credential chain in charge.
AWS_CREDS = $(if $(filter aws,$(CLOUD)),$(shell awk -F'"' \
  '/^aws_access_key/ && $$2 != "" { a = $$2 } \
   /^aws_secret_key/ && $$2 != "" { s = $$2 } \
   END { if (a != "" && s != "") printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s", a, s }' \
  $(VARFILE) 2>/dev/null))

ifeq ($(AUTO),1)
  APPROVE := -auto-approve
endif

.DEFAULT_GOAL := help

.PHONY: help init upgrade fmt validate guard-args workspace \
        plan apply destroy output show $(CLOUDS) $(ENVS)

help:
	@echo "Multi-cloud, multi-env Terraform (single codebase, workspace = <cloud>-<env>)"
	@echo
	@echo "Usage:  make <verb> <cloud> <env>   cloud = aws | az | gcp | do   env = dev | stage | prod"
	@echo "  make plan aws dev     make apply az stage    make destroy gcp prod"
	@echo "  make output do prod   make show gcp dev"
	@echo
	@echo "Teardown:  make destroy-all <cloud> <env>   addons, then the cluster"
	@echo "           (order matters — the addon layer needs a live cluster API)"
	@echo
	@echo "Cloud and env are both required — nothing defaults, typos abort early."
	@echo
	@echo "Options:  AUTO=1   skip the apply/destroy confirmation prompt"
	@echo "Setup:    make init | upgrade | validate | fmt"

# The cloud and env names are captured into CLOUD / ENV above; as goals they are
# no-ops so that 'make plan aws dev' doesn't complain about unknown targets.
$(CLOUDS):
	@:
$(ENVS):
	@:

# Initialize once. The stamp file is written only after init actually succeeds
# — terraform creates .terraform/ early, so the directory alone would make a
# half-finished init (interrupted download, registry outage) look complete and
# every later run would skip init and fail somewhere more confusing.
STAMP := .terraform/.init-ok

$(STAMP):
	$(TF) init
	@touch $@

init: $(STAMP)

# Force a re-init to pull provider/version changes.
upgrade:
	$(TF) init -upgrade
	@touch $(STAMP)

fmt:
	$(TF) fmt -recursive

# --- internals -------------------------------------------------------------

# Every state-touching target runs this FIRST, before terraform is invoked.
# It rejects unrecognised words, a missing cloud, and a missing env, so a
# mistyped command stops here instead of quietly acting on the wrong target.
guard-args:
	@fail() { echo "$$1"; echo "Usage: make <verb> <aws|az|gcp|do> <dev|stage|prod>"; exit 1; }; \
	if [ -n "$(UNKNOWN)" ]; then fail "Unrecognised: $(UNKNOWN)"; fi; \
	if [ -z "$(CLOUD)" ]; then fail "No cloud named."; fi; \
	if [ -z "$(ENV)" ]; then fail "No env named."; fi; \
	if [ "$(CLOUDN)" -gt 1 ]; then fail "More than one cloud named: $(filter $(CLOUDS),$(MAKECMDGOALS))"; fi; \
	if [ "$(ENVN)" -gt 1 ]; then fail "More than one env named: $(filter $(ENVS),$(MAKECMDGOALS))"; fi; \
	if [ "$(VERBN)" -gt 1 ]; then fail "One verb at a time: $(filter $(VERBS),$(MAKECMDGOALS))"; fi; \
	if [ ! -f "$(VARFILE)" ]; then fail "Missing var-file: $(VARFILE)"; fi

# Select the cloud+env workspace (creating it on first use) so state lands in
# terraform.tfstate.d/<cloud>-<env>/.
#
# The membership test matters: a bare "select || new" would treat ANY select
# failure — corrupt state dir, permissions, backend error — as "doesn't exist
# yet" and quietly create an empty-state workspace, which on apply means
# recreating infrastructure that already exists. Here a select failure stays a
# failure, and creation is deliberate and announced.
#
# Takes the layer directory, because both layers need this: the addon layer
# shares the workspace name and would otherwise reinstall addons into a cluster
# that already has them.
define select_workspace
cd $(1) && if $(TF) workspace list | sed 's/^[* ]*//' | grep -qx '$(WORKSPACE)'; then \
  $(TF) workspace select $(WORKSPACE); \
else \
  echo "==> Creating workspace $(WORKSPACE) in $(1)/ (new, empty state)"; \
  $(TF) workspace new $(WORKSPACE); \
fi
endef

workspace: guard-args $(STAMP)
	@$(call select_workspace,.)

# --- verbs -----------------------------------------------------------------

validate: $(STAMP)
	$(TF) validate

plan: workspace
	$(TF) plan -var-file=$(VARFILE)

# Prints the connect command instead of running it. Which profile/login this
# workstation uses is not something Terraform can know, and guessing it is what
# produced "cluster not found" and 401s before. Shown once, run once, and the
# kubeconfig remembers it.
#
# The addon layer is unaffected either way: it finds the cluster through its
# cloud API and authenticates via exec, never through kubeconfig.
apply: workspace
	$(TF) apply $(APPROVE) -var-file=$(VARFILE)
	@echo
	@echo "════════════════════════════════════════════════════════════"
	@echo " Connect to your cluster:"
	@echo
	@CMD="$$($(TF) output -raw kubeconfig_cmd 2>/dev/null)"; \
	if [ -z "$$CMD" ]; then \
	  echo "   (no cluster in state — nothing to connect to)"; \
	elif [ "$(CLOUD)" = "aws" ]; then \
	  echo "   $$CMD --profile <YOUR_PROFILE>"; \
	  echo; \
	  echo " No named profile yet? Create one, then rerun the line above:"; \
	  echo; \
	  echo "   aws configure --profile <YOUR_PROFILE>"; \
	else \
	  echo "   $$CMD"; \
	fi
	@echo
	@echo " Then verify:   kubectl get nodes"
	@echo " Or let make do it:   make connect $(CLOUD) $(ENV)"
	@echo "════════════════════════════════════════════════════════════"

destroy: workspace
	$(TF) destroy $(APPROVE) -var-file=$(VARFILE)

output: workspace
	$(TF) output

show: workspace
	$(TF) show

# The empty/not-found guard matters: with no cluster in state the output is
# blank, and running a blank command silently does nothing instead of saying the
# cluster isn't there.
kubeconfig: workspace
	@CMD="$$($(TF) output -raw kubeconfig_cmd 2>/dev/null)"; \
	case "$$CMD" in \
	  ""|*"not found"*) \
	    echo "No cluster in state for $(WORKSPACE) — run: make apply $(CLOUD) $(ENV)"; \
	    exit 1;; \
	esac; \
	$(AWS_CREDS) $$CMD

# Prove the kubeconfig actually works.
#
# `update-kubeconfig` (and the gcloud/az/doctl equivalents) only WRITE A FILE —
# they never contact the cluster, so they report success even when the resulting
# context cannot authenticate. The failure then surfaces much later, during
# deploy-addons, as an opaque "Unauthorized" with nothing pointing at the cause.
# One API call here turns that into a named problem.
connect: kubeconfig
	@echo "==> Verifying cluster access for $(WORKSPACE)"
	@if $(AWS_CREDS) kubectl get nodes >/dev/null 2>&1; then \
	  echo "    OK — $$($(AWS_CREDS) kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready') node(s) Ready"; \
	else \
	  echo "    FAILED — kubectl cannot reach the cluster."; echo; \
	  $(MAKE) --no-print-directory diagnose CLOUD=$(CLOUD) ENV=$(ENV); \
	  exit 1; \
	fi
	@# The check above used the keys make injects. Your shell has no such prefix,
	@# so re-run it bare — otherwise make reports OK on a kubeconfig that gives
	@# plain kubectl a 401, which is a false green.
	@if [ -n "$(AWS_CREDS)" ] && ! kubectl get nodes >/dev/null 2>&1; then \
	  echo; \
	  echo "    NOTE — plain 'kubectl' cannot authenticate, only make can."; \
	  echo "    Keys in $(VARFILE) are never written into the kubeconfig, so"; \
	  echo "    kubectl re-runs 'aws eks get-token' against ~/.aws/credentials."; \
	  echo "    For bare kubectl, export the same keys in your shell."; \
	fi

# Named causes and their fixes, rather than a generic "check your credentials".
diagnose:
	@ctx="$$(kubectl config current-context 2>/dev/null)"; \
	echo "  context : $${ctx:-<none set>}"; \
	if [ "$(CLOUD)" = "aws" ]; then \
	  want="$$(printf '%s' "$$ctx" | sed -n 's/^arn:aws:eks:[^:]*:\([0-9]*\):.*/\1/p')"; \
	  have="$$($(AWS_CREDS) aws sts get-caller-identity --query Account --output text 2>/dev/null)"; \
	  echo "  cluster account : $${want:-<unknown>}"; \
	  echo "  CLI account     : $${have:-<not authenticated>}"; \
	  if [ -z "$$have" ]; then \
	    echo; echo "  The aws CLI has no working credentials."; \
	    echo "  Fix: set aws_access_key/aws_secret_key in $(VARFILE), or run aws configure."; \
	  elif [ -z "$$want" ]; then \
	    echo; echo "  WRONG CONTEXT — the current context is not an EKS cluster, so kubectl"; \
	    echo "  is pointed at a different cluster entirely (possibly another cloud)."; \
	    echo "  Fix: make kubeconfig $(CLOUD) $(ENV)"; \
	  elif [ "$$want" != "$$have" ]; then \
	    echo; echo "  ACCOUNT MISMATCH — the cluster lives in $$want, the CLI authenticates as $$have."; \
	    echo "  get-token still mints a valid token, so EKS returns 401 rather than 'not found'."; \
	    echo "  Fix: set aws_access_key/aws_secret_key in $(VARFILE) to keys for"; \
	    echo "       account $$want, then re-run: make connect $(CLOUD) $(ENV)"; \
	  else \
	    echo; echo "  Credentials match, so this is authorization, not authentication:"; \
	    echo "  the IAM principal is not in the cluster's access entries."; \
	    echo "  Check: aws eks list-access-entries --region <region> --cluster-name <name>"; \
	  fi; \
	else \
	  echo "  Fix: confirm the auth plugin for $(CLOUD) is installed and logged in"; \
	  echo "  (gcp: gke-gcloud-auth-plugin | az: kubelogin | do: doctl) — see README Prerequisites."; \
	fi

# ---------------------------------------------------------
# Master Addon Deployment
# ---------------------------------------------------------
# Deliberately does NOT depend on kubeconfig. This layer finds the cluster
# through its cloud API and authenticates via exec (see data-sources.tf), so it
# never reads ~/.kube/config. Regenerating it here would overwrite whatever
# context the operator set up — dropping a --profile they added by hand, which
# leaves kubectl on the ambient credentials and returns "Unauthorized".
deploy-addons: guard-args
	@echo "Deploying addons via Terraform for $(WORKSPACE)..."
	cd kubernetes && terraform init
	@$(call select_workspace,kubernetes)
	# This layer reads the infra var-file for the cluster's identity and declares
	# only the few fields it needs, so Terraform warns about the infra-only
	# values in it. Expected, and shown in full so a real warning is not lost
	# among them.
	@cd kubernetes && $(AWS_CREDS) terraform apply $(APPROVE) -var-file="../envs/$(CLOUD).tfvars" -var-file="envs/$(CLOUD).tfvars"

# Tear the addons out while the cluster API is still reachable. Once the
# cluster is gone this cannot run at all — the providers authenticate against
# the live API — and the only way out is deleting the state by hand.
destroy-addons: guard-args
	cd kubernetes && terraform init
	@$(call select_workspace,kubernetes)
	@cd kubernetes && $(AWS_CREDS) terraform destroy $(APPROVE) \
	  -var-file="../envs/$(CLOUD).tfvars" -var-file="envs/$(CLOUD).tfvars"

# The whole environment, in the only order that works.
destroy-all: destroy-addons
	@$(MAKE) --no-print-directory destroy CLOUD=$(CLOUD) ENV=$(ENV) AUTO=$(AUTO)
ifeq ($(CLOUD),aws)
	@echo
	@echo "==> standard-sc uses reclaim_policy = Retain, so EBS volumes OUTLIVE"
	@echo "    this destroy and keep billing. List and remove them with:"
	@echo "      aws ec2 describe-volumes --region <region> \\"
	@echo "        --filters Name=status,Values=available \\"
	@echo "        --query 'Volumes[].[VolumeId,Size,Tags[?Key==\`kubernetes.io/created-for/pvc/name\`].Value|[0]]' --output table"
endif


