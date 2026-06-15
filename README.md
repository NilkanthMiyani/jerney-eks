# Jerney — EKS

Production-style Amazon Elastic Kubernetes Service (EKS) deployment of the Jerney application. Built as a counterpart to the GKE and AKS implementations for hands-on AWS learning.

![Architecture](docs/architecture.svg)

---

## Stack

| Layer | Technology | Notes |
|---|---|---|
| Infra | **Terraform** | EKS cluster, VPC, Security Groups, IAM Roles for Service Accounts (IRSA), Secrets Manager |
| GitOps | **ArgoCD** | App-of-Apps pattern, auto-syncs with GitHub |
| Ingress | **AWS Load Balancer Controller** | Provisions an Application Load Balancer (ALB) |
| TLS | **AWS Certificate Manager (ACM)** | TLS terminated at the ALB |
| Secrets | **External Secrets Operator** | Syncs AWS Secrets Manager → K8s Secrets (via IRSA) |
| App | **Jerney** | React frontend + Node.js backend + PostgreSQL |
| Observability | **kube-prometheus-stack** | Prometheus + Alertmanager + Grafana |
| Logs | **Loki + Promtail** | Log aggregation, surfaced in Grafana |

---

## Repository Structure

```text
jerney-eks/
├── docs/
│   └── architecture.svg              # High-level architecture diagram
├── infra/
│   ├── bootstrap/                    # Step 1: S3 Bucket for Terraform remote state
│   ├── modules/                      # Reusable, single-responsibility resource modules
│   │   ├── networking/               # VPC + Subnets + Internet/NAT Gateways
│   │   ├── iam/                      # IAM Roles for EKS
│   │   ├── eks-cluster/              # EKS cluster + Managed Node Groups + OIDC
│   │   ├── irsa/                     # IAM Roles for Service Accounts (ALB Controller, ESO, EBS CSI)
│   │   ├── secrets-manager/          # AWS Secrets Manager secrets
│   │   └── eks-bootstrap/            # In-cluster bootstrap (ArgoCD, gp3 StorageClass)
│   └── environments/                 # Step 2: Compositions — one per env, separate state
│       ├── dev/                      # main.tf wires modules; versions.tf pins S3 backend
│       ├── staging/                  # Prod-like hardening at reduced scale
│       └── prod/                     # Production configuration
└── k8s-eks/
    ├── apps/                         # ArgoCD Application CRs (App-of-Apps)
    │   ├── root-app.yaml             # Seeded by Terraform
    │   ├── aws-lb-controller.yaml    # wave 0
    │   ├── external-secrets.yaml     # wave 0
    │   ├── platform-config.yaml      # wave 0 — namespaces + resource quotas
    │   ├── platform-secrets.yaml     # wave 1
    │   ├── prometheus-stack.yaml     # wave 1
    │   ├── jerney.yaml               # wave 1
    │   ├── loki-stack.yaml           # wave 2
    │   └── ingress-apps.yaml         # wave 2 — Ingress resources
    ├── helm/jerney/                  # Jerney application Helm chart
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    └── platform/
        ├── governance/               # ResourceQuotas + LimitRanges per namespace
        ├── ingress/                  # Ingress resource definitions
        ├── external-secrets/         # ExternalSecret CRs
        ├── prometheus-stack/         # Helm values
        └── loki-stack/               # Helm values
```

> The Terraform code is **modular**: `modules/` holds reusable resources with no environment-specific hardcoding. Each `environments/<env>` composition wires them together with its own `terraform.tfvars` and its own remote state key in S3. A mistake in dev can never affect prod state.

---

## How It Works

**Secrets Flow:** AWS Secrets Manager → ESO (authenticates via IAM Roles for Service Accounts) → Kubernetes Secrets → Pods. No static AWS credentials exist inside the cluster.

**Traffic Flow:** Internet → Application Load Balancer (managed by AWS LB Controller) → NodePorts → Pods. TLS is terminated at the ALB using certificates from AWS Certificate Manager (ACM).

**Deployment Flow:** `git push` → ArgoCD detects diff → syncs in wave order (0 → 1 → 2).

---

## Setup

### Prerequisites

```bash
aws --version       # AWS CLI
terraform --version # >= 1.5
kubectl
helm
```

Ensure your AWS CLI is configured with the correct profile (e.g., `nilkanthaws9`).

---

### Step 1 — Bootstrap remote state

```bash
cd infra/bootstrap/
terraform init
terraform apply
```

Note the `state_bucket_name` output — you'll need it in Step 2. State locking is handled natively by Terraform via S3 (`use_lockfile = true`), so no DynamoDB table is required.

---

### Step 2 — Deploy an environment

Pick the environment you want to deploy (`dev`, `staging`, or `prod`):

```bash
cd infra/environments/dev/
```

Edit `versions.tf` and update the `bucket` field in the backend block to the S3 bucket name created in Step 1.

Configure your environment-specific non-secret variables in `terraform.tfvars`. Pass your secrets dynamically at apply time:

```bash
terraform init
terraform apply \
  -var="postgres_password=your-postgres-password" \
  -var="grafana_admin_password=your-grafana-password" \
  -var="alertmanager_smtp_key=your-smtp-key"
```

This provisions the VPC, EKS cluster, Managed Node Groups, IAM Roles, Secrets Manager, and bootstraps ArgoCD via the Helm provider. It takes ~15 minutes.

---

### Step 3 — Connect kubectl

Update your local kubeconfig to interact with the new cluster (adjust region/name/profile as needed):

```bash
aws eks update-kubeconfig --region ap-south-1 --name jerney-eks-dev --profile nilkanthaws9
kubectl get nodes
```

---

### Step 4 — Point DNS

The AWS Load Balancer Controller will provision an Application Load Balancer based on the Ingress resources. Find the ALB DNS name:

```bash
kubectl get ingress -n jerney
# Note the ADDRESS column (e.g., k8s-jerneyplatform-xxx.elb.amazonaws.com)
```

In your DNS provider, create CNAME records pointing to the ALB DNS name:

```text
argocd.nilkanthprojects.site  →  CNAME  →  k8s-jerneyplatform-xxx.elb.amazonaws.com
grafana.nilkanthprojects.site →  CNAME  →  k8s-jerneyplatform-xxx.elb.amazonaws.com
jerney.nilkanthprojects.site  →  CNAME  →  k8s-jerneyplatform-xxx.elb.amazonaws.com
```

---

### Step 5 — Verify

```bash
# Verify ArgoCD is syncing all apps
kubectl get apps -n argocd

# Verify Secrets synced from AWS Secrets Manager
kubectl get externalsecrets -A

# Verify all pods are healthy
kubectl get pods -A
```

Access the ArgoCD UI by navigating to your configured domain (or via port-forwarding):
```bash
kubectl port-forward svc/argo-cd-argocd-server 8080:80 -n argocd
# Username: admin
# Password:
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
```

---

## Day-2 Operations

### Update application image

Edit `k8s-eks/helm/jerney/values.yaml`, change the `image.backend.tag` or `image.frontend.tag`, and push to GitHub. ArgoCD will detect the change and perform a rolling update automatically.

### Rotate a secret

Update the secret value in AWS Secrets Manager:
```bash
aws secretsmanager put-secret-value \
  --secret-id jerney-postgres-password \
  --secret-string "new-password" \
  --profile nilkanthaws9 \
  --region ap-south-1
```

Force ESO to refresh the Kubernetes secret immediately:
```bash
kubectl annotate externalsecret jerney-db-credentials \
  -n jerney force-sync=$(date +%s) --overwrite
```

### ⚠️ Destroy everything (Important)

> **WARNING:** The AWS Load Balancer Controller provisions an ALB *outside* of Terraform. If you run `terraform destroy` while the ALB still exists, AWS will prevent Terraform from destroying the Internet Gateway, causing Terraform to hang indefinitely.

**Before running `terraform destroy`, you MUST clean up the ALB:**

1. Delete the ArgoCD ingress apps (this tells the ALB controller to delete the ALB):
   ```bash
   kubectl delete app ingress-apps -n argocd
   # Wait a minute or two for the ALB to be fully de-provisioned in AWS
   ```
2. Destroy the Terraform environment:
   ```bash
   cd infra/environments/dev
   terraform destroy
   ```
3. Destroy the bootstrap infrastructure (only after all environments are gone):
   ```bash
   cd ../../bootstrap
   terraform destroy
   ```
