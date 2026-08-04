locals {
  # Extract cloud (e.g., aws) from workspace (e.g., aws-dev)
  cloud = split("-", terraform.workspace)[0]

  # Environment tier (dev | stage | prod), for anything that varies by env.
  env = split("-", terraform.workspace)[1]

  # Default StorageClass per cloud. Every addon resolves its class as
  # coalesce(var.<svc>.storage_class, local.storage_class), so a service only
  # names a class when it needs a non-default one. This is what lets the addon
  # layer run anywhere — the previous hardcoded "gp2" left every PVC Pending
  # on GKE, AKS and DOKS.
  #
  #   aws -> gp2              pre-created by EKS. Note modules/aws/addon.tf
  #                           creates "standard-sc" and demotes gp2; when that
  #                           moves into this layer, change this to standard-sc.
  #   gcp -> standard-rwo     GKE default, CSI-backed. Preferred over the older
  #                           "standard", which uses the deprecated in-tree
  #                           gce-pd provisioner and binds Immediate rather than
  #                           WaitForFirstConsumer.
  #   az  -> default          AKS default class.
  #   do  -> do-block-storage DOKS default.
  storage_class = {
    aws = "gp2"
    gcp = "standard-rwo"
    az  = "default"
    do  = "do-block-storage"
  }[local.cloud]
}
