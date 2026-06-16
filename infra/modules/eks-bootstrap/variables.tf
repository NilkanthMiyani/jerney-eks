variable "argocd_chart_version" {
  description = "argo-cd Helm chart version"
  type        = string
  default     = "9.5.20" # ArgoCD v3.4.3
}

variable "argocd_apps_chart_version" {
  description = "argocd-apps Helm chart version"
  type        = string
  default     = "2.0.2"
}

variable "eso_chart_version" {
  description = "external-secrets Helm chart version"
  type        = string
  default     = "0.14.0"
}

variable "eso_role_arn" {
  description = "IRSA role ARN annotated onto the ESO ServiceAccount (from irsa module)"
  type        = string
}

variable "aws_region" {
  description = "AWS region used by the ESO ClusterSecretStore"
  type        = string
}

variable "gitops_repo_url" {
  description = "Git repository URL that ArgoCD's root app watches"
  type        = string
}

variable "gitops_target_revision" {
  description = "Git branch/tag the root app tracks (e.g. main, staging, prod)"
  type        = string
  default     = "main"
}

variable "gitops_apps_path" {
  description = "Path within the repo containing the ArgoCD Application manifests"
  type        = string
  default     = "k8s-eks/apps"
}

variable "alb_controller_chart_version" {
  description = "aws-load-balancer-controller Helm chart version"
  type        = string
  default     = "1.11.0"
}

variable "cluster_name" {
  description = "Name of the EKS cluster (used by ALB controller)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed (used by ALB controller)"
  type        = string
}

variable "alb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  type        = string
}
