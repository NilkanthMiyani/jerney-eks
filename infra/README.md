# Jerney EKS — Terraform Infrastructure

Modular, multi-environment Terraform for the Jerney EKS platform. Resource
modules are environment-agnostic; each environment is a thin composition with
its own remote state.

## Layout

```
infra/
├── bootstrap/                # S3 bucket + DynamoDB lock for remote state (run once)
├── modules/                  # Reusable, env-agnostic resource modules
│   ├── networking/           # VPC, IGW, NAT, subnets (for_each by AZ), route tables
│   ├── iam/                  # EKS cluster role + node group role
│   ├── eks-cluster/          # EKS cluster, OIDC provider, node group, core addons, ACM lookup
│   ├── irsa/                 # ESO / ALB Controller / EBS CSI IRSA roles + EBS CSI addon
│   ├── secrets-manager/      # Secrets Manager secrets (for_each over a map)
│   └── eks-bootstrap/        # ArgoCD, ESO, ClusterSecretStore, gp3 StorageClass, root app
└── environments/             # One composition per environment, separate state
    ├── dev/
    ├── staging/
    └── prod/
```

## Module dependency graph

```
networking ──┐
iam ─────────┤
             ├── eks_cluster ── irsa ── eks_bootstrap
secrets_manager ───────────────────────/
```

The classic EKS IRSA cycle (IRSA roles need the OIDC provider → which needs the
cluster → which needs the cluster role) is broken by splitting IAM:

- `iam` creates only the cluster + node roles (no OIDC dependency).
- `eks-cluster` creates the cluster and the OIDC provider, and outputs it.
- `irsa` consumes the OIDC provider and creates the IRSA roles. The
  `aws-ebs-csi-driver` addon lives here too (not in `eks-cluster`) because it
  needs its IRSA role at create time — keeping it downstream makes the graph
  linear and lets everything apply in a single `terraform apply`.

## Usage

```bash
# 0. One-time: create the remote-state backend
cd infra/bootstrap
terraform init && terraform apply
terraform output state_bucket_name          # copy this value

# 1. Pick an environment and point its backend at the bucket
cd ../environments/dev
#    edit versions.tf -> backend "s3" { bucket = "jerney-tfstate-XXXXXX" }

# 2. Supply secrets
cp terraform.tfvars.example terraform.tfvars
#    edit terraform.tfvars with real values

# 3. Plan / apply
terraform init
terraform plan
terraform apply

# 4. Configure kubectl (command is also a terraform output)
aws eks update-kubeconfig --name jerney-eks-dev --region ap-south-1 --profile nilkanthaws9
```

Repeat steps 1–4 in `environments/staging` and `environments/prod`. Each
environment keeps its own `terraform.tfstate` in the shared bucket under a
distinct key, so applies are fully isolated (independent blast radius).

## Environment differences

| Setting                 | Dev            | Staging         | Prod                |
|-------------------------|----------------|-----------------|---------------------|
| State key               | `dev/…`        | `staging/…`     | `prod/…`            |
| Cluster name            | jerney-eks-dev | jerney-eks-stg  | jerney-eks-prod     |
| VPC CIDR                | 10.0.0.0/16    | 10.1.0.0/16     | 10.2.0.0/16         |
| Node instance types     | t3.medium      | t3.medium       | t3.large            |
| Capacity type           | SPOT           | SPOT            | ON_DEMAND           |
| Min / Max nodes         | 2 / 5          | 2 / 4           | 3 / 10              |
| Disk size               | 30 GB          | 50 GB           | 100 GB              |
| Secret recovery window  | 0 days         | 7 days          | 30 days             |
| Public API endpoint     | true           | true            | false (VPC/VPN only)|
| GitOps branch           | main           | staging         | prod                |

All of these are plain variables with per-environment defaults in each
`variables.tf`; the `main.tf` wiring is identical across the three
environments. Override any non-secret default in `terraform.tfvars` if needed.

## Notes

- `*.tfvars` is git-ignored; only `*.tfvars.example` is committed. Never commit
  real secret values.
- Prod's private-only API endpoint means Terraform must run from inside the VPC
  (or a peered/VPN network) so the helm/kubectl providers can reach the cluster.
