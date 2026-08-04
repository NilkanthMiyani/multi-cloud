# ------------------------------------------------------------------------
# AWS cluster addons
# ------------------------------------------------------------------------

locals {
  aws_storage    = local.cloud == "aws" ? 1 : 0
  alb_controller = local.cloud == "aws" && local.enabled.alb_controller ? 1 : 0
}


# ------------------------------------------------------------------------
# EBS CSI driver + StorageClasses
# ------------------------------------------------------------------------
#
data "aws_iam_role" "ebs_csi" {
  count = local.aws_storage
  name  = "${local.cfg.project}-ebs-csi-driver"
}

resource "helm_release" "ebs_csi_driver" {
  count      = local.aws_storage
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = var.ebs_csi.chart_version
  namespace  = var.ebs_csi.namespace

  values = [
    yamlencode({
      controller = {
        serviceAccount = {
          create = true
          name   = "ebs-csi-controller-sa"
          annotations = {
            "eks.amazonaws.com/role-arn" = data.aws_iam_role.ebs_csi[0].arn
          }
        }
      }
    }),

    var.ebs_csi.values_extra,
  ]
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

  depends_on = [helm_release.ebs_csi_driver]
}

# EKS ships gp2 marked as the cluster default. Two default classes is undefined
# behaviour, so demote it once standard-sc exists.
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


# ------------------------------------------------------------------------
# Load Balancer Controller
# ------------------------------------------------------------------------
data "aws_iam_role" "alb_controller" {
  count = local.alb_controller
  name  = "${local.cfg.project}-eks-lb"
}

resource "kubernetes_service_account_v1" "alb_controller" {
  count = local.alb_controller

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = var.alb_controller.namespace

    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }

    annotations = {
      "eks.amazonaws.com/role-arn"               = data.aws_iam_role.alb_controller[0].arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

resource "helm_release" "alb_controller" {
  count      = local.alb_controller
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller.chart_version
  namespace  = var.alb_controller.namespace

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account_v1.alb_controller[0].metadata[0].name
  }

  set {
    name  = "clusterName"
    value = data.aws_eks_cluster.this[0].name
  }

  set {
    name  = "vpcId"
    value = data.aws_eks_cluster.this[0].vpc_config[0].vpc_id
  }

  set {
    name  = "region"
    value = var.region
  }

  values = [var.alb_controller.values_extra]
}
