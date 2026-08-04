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
VERBS  := help init    fmt validate plan apply destroy output show kubeconfig deploy-addons

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

apply: workspace
	$(TF) apply $(APPROVE) -var-file=$(VARFILE)
	@$(MAKE) --no-print-directory kubeconfig CLOUD=$(CLOUD) ENV=$(ENV)

destroy: workspace
	$(TF) destroy $(APPROVE) -var-file=$(VARFILE)

output: workspace
	$(TF) output

show: workspace
	$(TF) show

kubeconfig: workspace
	@eval "$$($(TF) output -raw kubeconfig_cmd)"

# ---------------------------------------------------------
# Master Addon Deployment
# ---------------------------------------------------------
deploy-addons: kubeconfig
	@echo "Deploying addons via Terraform for $(WORKSPACE)..."
	cd kubernetes && terraform init
	@$(call select_workspace,kubernetes)
	# This layer reads the infra var-file for the cluster's identity and declares
	# only the few fields it needs, so Terraform warns about the rest. Expected —
	# -compact-warnings keeps it to one line.
	cd kubernetes && terraform apply -compact-warnings -var-file="../envs/$(CLOUD).tfvars" -var-file="envs/$(CLOUD).tfvars" -auto-approve


