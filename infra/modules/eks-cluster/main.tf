# ==============================================================
# Module: eks-cluster
#
# EKS control plane + OIDC provider (for IRSA) + managed node group
# + core EKS addons that need no IRSA role (vpc-cni, coredns,
# kube-proxy). It also looks up the ACM wildcard certificate used
# by ALB Ingress annotations.
#
# The aws-ebs-csi-driver addon is intentionally NOT here: it needs
# an IRSA role created in modules/irsa, which in turn needs this
# module's OIDC outputs. Keeping it downstream avoids a dependency
# cycle (eks-cluster -> irsa -> eks-cluster).
# ==============================================================



# ---- ACM Certificate ----
# The ALB terminates TLS using this existing wildcard cert (no cert-manager).
# If acm_certificate_arn is set, it is used directly; otherwise the cert is
# looked up by domain_name.
data "aws_acm_certificate" "wildcard" {
  count       = var.acm_certificate_arn == "" ? 1 : 0
  domain      = var.domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

# ---- EKS Cluster ----
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = var.tags
}

# ---- EKS Access Entry for the Creator ----
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "creator" {
  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = data.aws_caller_identity.current.arn
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "creator" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.creator.principal_arn

  access_scope {
    type = "cluster"
  }
}

# ---- OIDC Provider for IRSA ----
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

# ---- EKS Managed Node Group ----
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = var.node_role_arn

  # Nodes run in private subnets — egress via NAT Gateway.
  subnet_ids = var.private_subnet_ids

  capacity_type  = var.capacity_type
  instance_types = var.node_instance_types
  disk_size      = var.disk_size_gb

  scaling_config {
    min_size     = var.min_node_count
    max_size     = var.max_node_count
    desired_size = var.min_node_count
  }

  update_config {
    max_unavailable = 1
  }

  labels = var.node_labels

  tags = var.tags
}

# ==============================================================
# Core EKS Addons (no IRSA role required)
# ==============================================================

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}
