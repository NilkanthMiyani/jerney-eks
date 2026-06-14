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

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

locals {
  # Reusable IRSA assume-role policy builder. Given a service account
  # "namespace:name", returns the trust policy bound to the OIDC sub.
  irsa_trust = {
    for sa in toset([
      "external-secrets:external-secrets",
      "kube-system:aws-load-balancer-controller",
      "kube-system:ebs-csi-controller-sa",
    ]) :
    sa => jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
            "${var.oidc_provider}:sub" = "system:serviceaccount:${sa}"
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
  tags               = var.tags
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

data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${var.alb_controller_policy_version}/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.cluster_name}-alb-controller-policy"
  policy = data.http.alb_controller_policy.response_body
  tags   = var.tags
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller-role"
  assume_role_policy = local.irsa_trust["kube-system:aws-load-balancer-controller"]
  tags               = var.tags
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
  tags               = var.tags
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

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
}
