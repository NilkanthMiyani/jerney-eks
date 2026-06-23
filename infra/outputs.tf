# ==============================================================
# EKS Infra Outputs
# ==============================================================

# ---- Cluster connection ----
output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.jerney_ekscluster.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.jerney_ekscluster.endpoint
}

output "cluster_ca_data" {
  description = "Base64-encoded cluster CA certificate"
  value       = aws_eks_cluster.jerney_ekscluster.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Cluster security group created and managed by EKS"
  value       = aws_eks_cluster.jerney_ekscluster.vpc_config[0].cluster_security_group_id
}

# ---- Security groups ----
output "node_security_group_id" {
  description = "Security group attached to the worker nodes"
  value       = aws_security_group.jerney_nodegroup.id
}

# ---- OIDC provider (IRSA) ----
output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "IAM OIDC provider URL (issuer) for IRSA"
  value       = aws_iam_openid_connect_provider.eks.url
}

# ---- IRSA role ARNs ----
output "ebs_csi_role_arn" {
  description = "IRSA role ARN for the EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}

# ---- Networking ----
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = [for s in aws_subnet.private : s.id]
}

# ---- ECR ----
output "ecr_repository_urls" {
  description = "ECR repository URLs for the Jerney images"
  value       = { for k, r in aws_ecr_repository.jerney : k => r.repository_url }
}

# ---- Kubeconfig command ----
output "kubeconfig_command" {
  description = "Command to configure kubectl and update your local context"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.jerney_ekscluster.name} --profile ${var.aws_profile}"
}
