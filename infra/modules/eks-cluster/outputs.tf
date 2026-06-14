output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_provider" {
  description = "OIDC provider URL without the https:// prefix (for IRSA trust conditions)"
  value       = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer_url" {
  description = "EKS OIDC issuer URL"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "acm_cert_arn" {
  description = "ACM wildcard certificate ARN — used in ALB Ingress annotations"
  value       = var.acm_certificate_arn != "" ? var.acm_certificate_arn : data.aws_acm_certificate.wildcard[0].arn
}

output "node_group_name" {
  description = "Managed node group name"
  value       = aws_eks_node_group.main.node_group_name
}
