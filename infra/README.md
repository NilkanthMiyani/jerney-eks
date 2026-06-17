# Jerney EKS — Terraform Infrastructure

Modular Terraform for the Jerney EKS platform. Resource modules are environment-agnostic; the entire infrastructure is wired together in the root `infra/` directory using the Single Composition pattern.

For complete setup, deployment, and operational instructions, **please see the [Root README](../README.md)**.

## Layout

```text
infra/
├── bootstrap/                # S3 bucket for remote state (run once)
├── modules/                  # Reusable, env-agnostic resource modules
│   ├── networking/           # VPC, IGW, NAT, subnets (for_each by AZ), route tables
│   ├── iam/                  # EKS cluster role + node group role
│   ├── eks-cluster/          # EKS cluster, OIDC provider, node group, core addons, ACM lookup
│   ├── irsa/                 # ESO / ALB Controller / EBS CSI IRSA roles + EBS CSI addon
│   ├── secrets-manager/      # Secrets Manager secrets
│   └── eks-bootstrap/        # ArgoCD, ALB Controller, ESO, gp3 StorageClass
├── main.tf                   # The Single Composition (wires modules together)
├── dev.tfvars.example        # Dev environment variables template
├── staging.tfvars.example    # Staging environment variables template
└── prod.tfvars.example       # Prod environment variables template
```

## Usage

To apply infrastructure, navigate to the `infra/` directory and use **Terraform Workspaces**. This ensures the state is isolated per environment.

```bash
cd ./

# 1. Initialize (run once)
terraform init

# 2. Fresh Setup: Create the workspaces for the first time
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# 3. Switch to the target workspace
terraform workspace select dev

# 4. Plan and apply the environment using its variables
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

*(Note: Secrets like `postgres_password` must be passed via environment variables before running the script. See the root README for the full deployment guide).*

## Module dependency graph

```text
networking ──┐
iam ─────────┤
             ├── eks_cluster ── irsa ── eks_bootstrap
secrets_manager ───────────────────────/
```

The classic EKS IRSA cycle (IRSA roles need the OIDC provider → which needs the cluster → which needs the cluster role) is intentionally broken by splitting IAM:

- `iam` creates only the cluster + node roles (no OIDC dependency).
- `eks-cluster` creates the cluster and the OIDC provider, and outputs it.
- `irsa` consumes the OIDC provider and creates the IRSA roles. The `aws-ebs-csi-driver` addon lives here too (not in `eks-cluster`) because it needs its IRSA role at create time — keeping it downstream makes the graph linear and lets everything apply in a single `terraform apply`.

## Notes

- Prod's private-only API endpoint means Terraform must run from inside the VPC (or a peered/VPN network) so the helm/kubernetes providers can reach the cluster. To solve this, you can provision a **Bastion Host** (an EC2 instance) in one of the VPC's public subnets. You can then use SSH port forwarding (`ssh -L`) or AWS Systems Manager (SSM) Session Manager to jump through the bastion to securely run `kubectl` and `terraform apply` against the private cluster.
