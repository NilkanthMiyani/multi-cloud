# ------------------------------------------------------------------------
# AWS StorageClasses (EBS CSI)
# ------------------------------------------------------------------------

locals {
  aws_storage = local.cloud == "aws" ? 1 : 0
}

resource "kubernetes_storage_class_v1" "standard_sc" {
  count = local.aws_storage

  metadata {
    name = "standard-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type = "gp2"
  }

  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
}

resource "kubernetes_annotations" "disable_gp2" {
  count = local.aws_storage

  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  force = true

  depends_on = [kubernetes_storage_class_v1.standard_sc]
}
