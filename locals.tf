locals {
  # The target cloud AND environment are encoded in the Terraform workspace
  # name as "<cloud>-<env>" (e.g. aws-dev, gcp-stage, az-prod). Splitting the
  # workspace name gives each cloud+env combination its own state file
  # automatically (terraform.tfstate.d/<cloud>-<env>/), so there is no -state
  # flag to remember.
  #
  # The tobool() fails the run fast on the default workspace (or any typo'd /
  # malformed name) instead of silently creating zero resources; local.cloud is
  # reachable from the resource counts below, so this always evaluates.
  parts = split("-", terraform.workspace)

  valid_workspace = length(local.parts) == 2 && contains(["aws", "az", "gcp", "do"], local.parts[0]) && contains(["dev", "stage", "prod"], local.parts[1])

  cloud = local.valid_workspace ? local.parts[0] : tobool(
  "Select a <cloud>-<env> workspace first, e.g. terraform workspace select aws-dev (cloud = aws|az|gcp|do, env = dev|stage|prod)")

  # Environment name (dev | stage | prod), derived from the workspace. Available
  # as local.env for any env-specific logic (naming, tags, etc.).
  env = local.parts[1]

  # Cloud selection flags. Each resource file gates its resources on the
  # matching flag via count, so only the selected cloud's resources are created.
  is_aws   = local.cloud == "aws" ? 1 : 0
  is_azure = local.cloud == "az" ? 1 : 0
  is_gcp   = local.cloud == "gcp" ? 1 : 0
  is_do    = local.cloud == "do" ? 1 : 0
}
