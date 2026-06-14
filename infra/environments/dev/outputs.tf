output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks_cluster.cluster_endpoint
  sensitive   = true
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "node_group_name" {
  description = "Managed node group name"
  value       = module.eks_cluster.node_group_name
}

output "oidc_provider_url" {
  description = "EKS OIDC issuer URL"
  value       = module.eks_cluster.oidc_issuer_url
}

output "acm_cert_arn" {
  description = "ACM wildcard certificate ARN — used in ALB Ingress annotations"
  value       = module.eks_cluster.acm_cert_arn
}

output "eso_role_arn" {
  description = "IRSA role ARN for External Secrets Operator"
  value       = module.irsa.eso_role_arn
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  value       = module.irsa.alb_controller_role_arn
}

output "secret_arns" {
  description = "Map of Secrets Manager secret name => ARN"
  value       = module.secrets_manager.secret_arns
}

output "kubectl_config_command" {
  description = "Run this after apply to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region} --profile ${var.aws_profile}"
}
