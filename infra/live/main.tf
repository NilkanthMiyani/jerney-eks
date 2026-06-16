# ==============================================================
# Single Composition: jerney-eks
#
# Wires the resource modules into a single cluster.
# All environment-specific values come from variables
# (see variables.tf and the respective .tfvars files).
#
# Dependency graph:
#   networking ──┐
#   iam ─────────┤
#                ├── eks_cluster ── irsa ── eks_bootstrap
#   secrets_manager ───────────────────────/
# ==============================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  common_tags = {
    env     = var.environment
    project = "jerney"
  }
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "networking" {
  source = "../modules/networking"

  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = local.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.common_tags
}

module "iam" {
  source = "../modules/iam"

  cluster_name = var.cluster_name
  tags         = local.common_tags
}

module "eks_cluster" {
  source = "../modules/eks-cluster"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  cluster_role_arn   = module.iam.cluster_role_arn
  node_role_arn      = module.iam.node_role_arn

  subnet_ids         = concat(module.networking.public_subnet_ids, module.networking.private_subnet_ids)
  private_subnet_ids = module.networking.private_subnet_ids

  node_instance_types    = var.node_instance_types
  capacity_type          = var.capacity_type
  min_node_count         = var.min_node_count
  max_node_count         = var.max_node_count
  disk_size_gb           = var.disk_size_gb
  endpoint_public_access = var.endpoint_public_access
  domain_name            = var.domain_name
  acm_certificate_arn    = var.acm_certificate_arn

  node_labels = local.common_tags
  tags        = local.common_tags
}

module "irsa" {
  source = "../modules/irsa"

  cluster_name      = var.cluster_name
  oidc_provider     = module.eks_cluster.oidc_provider
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  tags              = local.common_tags
}

module "secrets_manager" {
  source = "../modules/secrets-manager"

  secrets = {
    "jerney-postgres-password"      = var.postgres_password
    "jerney-grafana-admin-password" = var.grafana_admin_password
    "jerney-alertmanager-smtp-key"  = var.alertmanager_smtp_key
  }
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = local.common_tags
}

module "eks_bootstrap" {
  source = "../modules/eks-bootstrap"

  eso_role_arn            = module.irsa.eso_role_arn
  aws_region              = var.aws_region
  gitops_repo_url         = var.gitops_repo_url
  gitops_target_revision  = var.gitops_target_revision
  gitops_apps_path        = var.gitops_apps_path
  cluster_name            = module.eks_cluster.cluster_name
  vpc_id                  = module.networking.vpc_id
  alb_controller_role_arn = module.irsa.alb_controller_role_arn

  depends_on = [module.irsa, module.secrets_manager]
}
