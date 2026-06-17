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


# ---- 1. ArgoCD + Root App ----
resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.5.20"
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
  version          = "2.0.2"
  namespace        = "argocd"
  create_namespace = false

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
  version          = "0.14.0"
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eso.arn
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
  version          = "1.11.0"
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
    value = aws_vpc.main.id
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
    value = aws_iam_role.alb_controller.arn
  }

  depends_on = [helm_release.argocd]
}

# ---- 2c. Cluster Autoscaler ----
# Discovers the managed node group's ASG via the
# k8s.io/cluster-autoscaler/* tags set in eks-cluster.tf and scales it
# up on pending pods / down on underutilized nodes.
resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = var.ca_chart_version
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler.arn
  }

  depends_on = [
    aws_iam_role_policy.cluster_autoscaler,
    aws_eks_addon.coredns,
  ]
}
