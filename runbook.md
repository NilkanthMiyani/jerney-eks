# Jerney EKS GitOps Runbook

This repository uses a strict **Single-Branch Kustomize** architecture for GitOps (Industry Standard "Pattern B"). 
Everything lives entirely on the `main` branch. Environment separation is achieved using Kustomize overlays and environment-specific Helm value files.

## Environment Architecture

- **Base Config:** `k8s-eks/apps/base/jerney.yaml` defines the core ArgoCD application.
- **Dev Overlay:** `k8s-eks/apps/dev/kustomization.yaml` dynamically patches the app to use `values-dev.yaml`.
- **Staging Overlay:** `k8s-eks/apps/staging/kustomization.yaml` dynamically patches the app to use `values-staging.yaml`.
- **Prod Overlay:** `k8s-eks/apps/prod/kustomization.yaml` dynamically patches the app to use `values-prod.yaml`.

*Terraform configures each cluster to point its root ArgoCD app to the corresponding overlay path.*

## Promotion Workflow

Promoting code between environments is a single-line PR change! You never have to mess with git branch propagation or target revisions.

### 1. Dev Deployment (Continuous)
When a developer merges code in the application repository, the CI pipeline builds and pushes a new Docker image (e.g., `8175f40`).
You update the tag in `k8s-eks/helm/jerney/values-dev.yaml`:
```yaml
image:
  backend:
    tag: "8175f40"
  frontend:
    tag: "8175f40"
```
Once merged to `main`, the Dev cluster automatically syncs the new image.

### 2. Staging Promotion
When testing in Dev passes and QA is ready, you copy the verified tag from `values-dev.yaml` into `k8s-eks/helm/jerney/values-staging.yaml`. 
Submit a PR. Once merged, the Staging cluster auto-syncs.

### 3. Production Promotion
When Staging is signed off, you copy the verified tag into `k8s-eks/helm/jerney/values-prod.yaml`. 
Submit a PR. Once merged, Production auto-syncs.

## Emergency Hotfixes

If production crashes and requires an immediate rollback or hotfix image:
1. Bypass the normal flow.
2. Update the tag directly in `values-prod.yaml` on the `main` branch.
3. Prod will sync within 3 minutes.
4. Backfill the new tag into `values-dev.yaml` and `values-staging.yaml` afterward to keep environments perfectly in sync.
