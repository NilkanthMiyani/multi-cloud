locals {
  # Extract cloud (e.g., aws) from workspace (e.g., aws-dev)
  cloud = split("-", terraform.workspace)[0]

  # Environment tier (dev | stage | prod), for anything that varies by env.
  env = split("-", terraform.workspace)[1]

  # Cluster identity for THIS environment, out of the infra layer's
  # ../envs/<cloud>.tfvars, which carries all three.
  cfg = var.envs[local.env]

  # Service switches for THIS environment. Everything else about a service is
  # sized identically across environments, so only the toggles are env-keyed.
  enabled = var.enabled[local.env]

  # Default StorageClass per cloud. Every addon resolves its class as
  # coalesce(var.<svc>.storage_class, local.storage_class), so a service only
  # names a class when it needs a non-default one. This is what lets the addon
  # layer run anywhere — the previous hardcoded "gp2" left every PVC Pending
  # on GKE, AKS and DOKS.
  #
  #   aws -> standard-sc      created by aws-helm.tf in this layer, backed by
  #                           gp2 but with Retain + WaitForFirstConsumer +
  #                           volume expansion. EKS's stock gp2 is demoted from
  #                           default at the same time. Because this class is
  #                           created here rather than pre-existing, everything
  #                           that provisions a PVC carries
  #                           depends_on = [kubernetes_storage_class_v1.standard_sc]
  #                           — otherwise the PVC would sit Pending until Helm
  #                           gave up.
  #
  #                           Retain means PVs and their EBS volumes SURVIVE a
  #                           destroy. Reclaim them with `kubectl get pv` +
  #                           `kubectl delete pv <name>` or they bill forever.
  #   gcp -> standard-rwo     GKE default, CSI-backed. Preferred over the older
  #                           "standard", which uses the deprecated in-tree
  #                           gce-pd provisioner and binds Immediate rather than
  #                           WaitForFirstConsumer.
  #   az  -> default          AKS default class.
  #   do  -> do-block-storage DOKS default.
  storage_class = {
    aws = "standard-sc"
    gcp = "standard-rwo"
    az  = "default"
    do  = "do-block-storage"
  }[local.cloud]
}
