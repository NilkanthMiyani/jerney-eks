output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "kubeconfig_command" {
  description = "Command to configure kubectl and update your local context"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name} --profile ${var.aws_profile}"
}
