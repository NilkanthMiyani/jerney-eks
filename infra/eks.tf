# ==============================================================
# EKS control plane + OIDC provider (for IRSA) + managed node group
# + the aws-ebs-csi-driver managed addon.
# ==============================================================

# ---- EKS Cluster ----
resource "aws_eks_cluster" "jerney_ekscluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = concat([for s in aws_subnet.public : s.id], [for s in aws_subnet.private : s.id])
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = local.common_tags
}

# ---- EKS Access Entry for the Creator ----
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "creator" {
  cluster_name  = aws_eks_cluster.jerney_ekscluster.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "creator" {
  cluster_name  = aws_eks_cluster.jerney_ekscluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.creator.principal_arn

  access_scope {
    type = "cluster"
  }
}

# ---- OIDC Provider for IRSA ----
data "tls_certificate" "eks" {
  url = aws_eks_cluster.jerney_ekscluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.jerney_ekscluster.identity[0].oidc[0].issuer

  tags = local.common_tags
}



# Launch Template for EKS Node Group - allows attaching custom security groups
resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"

  vpc_security_group_ids = [
    aws_security_group.jerney_nodegroup.id,
    aws_eks_cluster.jerney_ekscluster.vpc_config[0].cluster_security_group_id,
  ]

  # disk_size cannot be set on the node group when a launch template is used,
  # so the root volume is defined here instead.
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = var.disk_size_gb
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.cluster_name}-node" })
  }

  tags = local.common_tags
}

# ---- EKS Managed Node Group ----
resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.jerney_ekscluster.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn

  # Nodes run in private subnets — egress via NAT Gateway.
  subnet_ids = [for s in aws_subnet.private : s.id]

  # instance_types stays on the node group (the launch template deliberately
  # omits an instance type so a SPOT list of types is allowed).
  capacity_type  = var.capacity_type
  instance_types = var.node_instance_types

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    min_size     = var.min_node_count
    max_size     = var.max_node_count
    desired_size = var.min_node_count
  }

  update_config {
    max_unavailable = 1
  }

  labels = local.common_tags

  tags = local.common_tags
}

# ==============================================================
# EKS Managed Addons
# ==============================================================

# aws-ebs-csi-driver — wired via IRSA
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.jerney_ekscluster.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  # Wait for nodes before reconciling so the controller has somewhere to run.
  depends_on = [
    aws_eks_node_group.nodes,
    aws_iam_role_policy_attachment.ebs_csi,
  ]
}

# metrics-server — serves the metrics.k8s.io API that HPA reads.
# It does NOT need EKS Pod Identity because it only talks to Kubernetes, not AWS APIs.
resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.jerney_ekscluster.name
  addon_name   = "metrics-server"

  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  depends_on = [aws_eks_node_group.nodes]
}
