# ==============================================================
# Module: eks-bootstrap
#
# In-cluster bootstrap, applied by Terraform via the helm and
# kubernetes providers:
#   1. gp3 StorageClass (default)
#   2. ArgoCD          (Helm + Root App-of-Apps)
#   3. ESO             (Helm + CRDs; ClusterSecretStore lives in gitops)
#   4. AWS Load Balancer Controller (Helm)
# ==============================================================

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# ---- gp3 StorageClass (default) ----
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}

# Demote the built-in gp2 StorageClass so gp3 is the sole default.
# EKS ships gp2 on every cluster, so we patch the existing object's annotation
# instead of creating it (which collides with "gp2 already exists").
resource "kubernetes_annotations" "gp2_not_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force = true
}

# ---- 1. ArgoCD + Root App ----
resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  set {
    name  = "configs.cm.application\\.instanceLabelKey"
    value = "argocd.argoproj.io/instance"
  }

}

# ---- 1b. Root App-of-Apps (via argocd-apps chart) ----
resource "helm_release" "argocd_apps" {
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  version          = var.argocd_apps_chart_version
  namespace        = "argocd"
  create_namespace = false

  # argocd-apps chart v2.x expects `applications` as a map keyed by app name,
  # not a list (a list makes the index `0` the metadata.name -> unmarshal error).
  values = [
    yamlencode({
      applications = {
        platform = {
          namespace = "argocd"
          finalizers = [
            "resources-finalizer.argocd.argoproj.io"
          ]
          project = "default"
          source = {
            repoURL        = var.gitops_repo_url
            targetRevision = var.gitops_target_revision
            path           = var.gitops_apps_path
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
          }
        }
      }
    })
  ]

  depends_on = [helm_release.argocd]
}

# ---- 2. ESO (operator + CRDs only; ClusterSecretStore is in gitops) ----
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_chart_version
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.eso_role_arn
  }

  # Only the ESO operator + CRDs are installed here. The ClusterSecretStore
  # (a custom resource) lives in gitops (k8s-eks/platform/external-secrets) and
  # is reconciled by the `platform-secrets` ArgoCD app *after* these CRDs exist
  # -- a CR cannot live in the same Helm release as the CRD that defines it.
  values = [
    yamlencode({
      installCRDs = true
    })
  ]
}

# ---- 2b. AWS Load Balancer Controller ----
resource "helm_release" "aws_lb_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = var.alb_controller_chart_version
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.alb_controller_role_arn
  }

  depends_on = [helm_release.argocd]
}
