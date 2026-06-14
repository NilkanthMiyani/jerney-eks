variable "argocd_chart_version" {
  description = "argo-cd Helm chart version"
  type        = string
  default     = "9.5.20" # ArgoCD v3.4.3
  nullable    = false
}

variable "eso_chart_version" {
  description = "external-secrets Helm chart version"
  type        = string
  default     = "0.14.0"
  nullable    = false
}

variable "eso_role_arn" {
  description = "IRSA role ARN annotated onto the ESO ServiceAccount (from irsa module)"
  type        = string
  nullable    = false
}

variable "aws_region" {
  description = "AWS region used by the ESO ClusterSecretStore"
  type        = string
  nullable    = false
}

variable "gitops_repo_url" {
  description = "Git repository URL that ArgoCD's root app watches"
  type        = string
  nullable    = false
}

variable "gitops_target_revision" {
  description = "Git branch/tag the root app tracks (e.g. main, staging, prod)"
  type        = string
  default     = "main"
  nullable    = false
}

variable "gitops_apps_path" {
  description = "Path within the repo containing the ArgoCD Application manifests"
  type        = string
  default     = "k8s-eks/apps"
  nullable    = false
}
