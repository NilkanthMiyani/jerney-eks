# ==============================================================
# Module: iam
#
# Base IAM roles that do NOT depend on the cluster OIDC provider:
#   - EKS cluster control-plane role
#   - EKS managed node group role
#
# IRSA roles (ESO, ALB Controller, EBS CSI) live in modules/irsa
# because they need the OIDC provider that only exists after the
# cluster is created. Keeping base roles here lets the cluster be
# built without a dependency cycle.
# ==============================================================

# ---- EKS Cluster IAM Role ----
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ---- EKS Node Group IAM Role ----
resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

locals {
  node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}

resource "aws_iam_role_policy_attachment" "eks_node_policies" {
  for_each   = toset(local.node_policies)
  policy_arn = each.value
  role       = aws_iam_role.eks_nodes.name
}
