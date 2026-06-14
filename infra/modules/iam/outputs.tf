output "cluster_role_arn" {
  description = "ARN of the EKS cluster control-plane role"
  value       = aws_iam_role.eks_cluster.arn
}

output "node_role_arn" {
  description = "ARN of the EKS managed node group role"
  value       = aws_iam_role.eks_nodes.arn
}
