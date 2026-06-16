# ==============================================================
# Module: eks-bootstrap
#
# In-cluster bootstrap, applied by Terraform via the helm + kubectl
# providers (configured in the composition and inherited here):
#   1. gp3 StorageClass (default) 
#   2. ArgoCD          (Helm)
#   3. ESO             (Helm — installed by TF so its CRDs exist
#                       before the ClusterSecretStore below)
#   4. ClusterSecretStore (AWS Secrets Manager, via ESO CRD)
#   5. Root App-of-Apps (ArgoCD then syncs everything else)
#
# The root Application is rendered from gitops_* variables so each
# environment can track its own branch (dev=main, staging=staging,
# prod=prod) without committing a different YAML file per env.
# ==============================================================

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# ---- gp3 StorageClass (default) ----
resource "kubectl_manifest" "gp3_storage_class" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: gp3
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
    provisioner: ebs.csi.aws.com
    parameters:
      type: gp3
      fsType: ext4
    reclaimPolicy: Delete
    volumeBindingMode: WaitForFirstConsumer
    allowVolumeExpansion: true
  YAML
}

# Demote the built-in gp2 StorageClass so gp3 is the sole default.
resource "kubectl_manifest" "gp2_not_default" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: gp2
      annotations:
        storageclass.kubernetes.io/is-default-class: "false"
    provisioner: kubernetes.io/aws-ebs
    parameters:
      type: gp2
      fsType: ext4
    reclaimPolicy: Delete
    volumeBindingMode: WaitForFirstConsumer
  YAML
}

# ---- 1. ArgoCD ----
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
    # ArgoCD server runs without TLS — the ALB terminates TLS.
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  set {
    name  = "configs.cm.application\\.instanceLabelKey"
    value = "argocd.argoproj.io/instance"
  }
}

# ---- 2. ESO (Terraform-managed so its CRDs exist for the store below) ----
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_chart_version
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 300

  # IRSA: annotate the ESO ServiceAccount with its IAM role ARN.
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.eso_role_arn
  }
}

# ---- 2b. AWS Load Balancer Controller ----
# Terraform-owned (previously an ArgoCD Application at sync-wave 0). With
# wait = true the controller is fully rolled out before the root App-of-Apps
# is created below, so ArgoCD-managed Ingresses never sync ahead of it.
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

  # IRSA: annotate the controller ServiceAccount with its IAM role ARN.
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.alb_controller_role_arn
  }

  depends_on = [helm_release.argocd]
}

# ---- 3. ESO ClusterSecretStore (AWS Secrets Manager) ----
resource "kubectl_manifest" "eso_cluster_secret_store" {
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: aws-secrets-manager
    spec:
      provider:
        aws:
          service: SecretsManager
          region: ${var.aws_region}
          auth:
            jwt:
              serviceAccountRef:
                name: external-secrets
                namespace: external-secrets
  YAML

  depends_on = [helm_release.external_secrets]
}

# ---- 4. Root App-of-Apps ----
resource "kubectl_manifest" "argocd_root_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: platform
      namespace: argocd
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: ${var.gitops_repo_url}
        targetRevision: ${var.gitops_target_revision}
        path: ${var.gitops_apps_path}
      destination:
        server: https://kubernetes.default.svc
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML

  # Wait for both ArgoCD and the ALB controller: the controller must be
  # running before ArgoCD starts syncing platform Ingresses.
  depends_on = [helm_release.argocd, helm_release.aws_lb_controller]
}
