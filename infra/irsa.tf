# ==============================================================
# Module: irsa
#
# IAM Roles for Service Accounts (IRSA) that depend on the cluster
# OIDC provider, plus the EBS CSI driver addon (which needs its
# IRSA role at create time):
#   - External Secrets Operator (ESO)
#   - AWS Load Balancer Controller
#   - Amazon EBS CSI Driver  + aws-ebs-csi-driver addon
#
# Inputs oidc_provider / oidc_provider_arn come from the eks-cluster
# module, giving the linear graph: eks-cluster -> irsa -> eks-bootstrap.
# ==============================================================



locals {
  # Reusable IRSA assume-role policy builder. Given a service account
  # "namespace:name", returns the trust policy bound to the OIDC sub.
  irsa_trust = {
    for sa in toset([
      "external-secrets:external-secrets",
      "kube-system:aws-load-balancer-controller",
      "kube-system:ebs-csi-controller-sa",
      "kube-system:cluster-autoscaler",
    ]) :
    sa => jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:${sa}"
          }
        }
      }]
    })
  }
}

# ==============================================================
# IRSA: External Secrets Operator
# ==============================================================

resource "aws_iam_role" "eso" {
  name               = "${var.cluster_name}-eso-role"
  assume_role_policy = local.irsa_trust["external-secrets:external-secrets"]
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "eso_secrets_read" {
  name = "eso-secrets-read"
  role = aws_iam_role.eso.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets",
      ]
      Resource = "*"
    }]
  })
}

# ==============================================================
# IRSA: AWS Load Balancer Controller
# ==============================================================

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.cluster_name}-alb-controller-policy"
  policy = file("${path.module}/policies/alb-controller.json")
  tags   = local.common_tags
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller-role"
  assume_role_policy = local.irsa_trust["kube-system:aws-load-balancer-controller"]
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.alb_controller.name
}

# ==============================================================
# IRSA: Amazon EBS CSI Driver + addon
# ==============================================================

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = local.irsa_trust["kube-system:ebs-csi-controller-sa"]
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

# EBS CSI driver addon — wired to the IRSA role above. Placed here
# (not in eks-cluster) so the role exists at addon create time.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
}

# ==============================================================
# IRSA: Cluster Autoscaler
# ==============================================================

resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.cluster_name}-cluster-autoscaler-role"
  assume_role_policy = local.irsa_trust["kube-system:cluster-autoscaler"]
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name = "cluster-autoscaler"
  role = aws_iam_role.cluster_autoscaler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ClusterAutoscalerActions"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      },
      {
        Sid    = "ClusterAutoscalerReadOnly"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup",
        ]
        Resource = "*"
      },
    ]
  })
}
