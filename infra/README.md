# Jerney EKS — Terraform Infrastructure

Flat-structured Terraform for the Jerney EKS platform. All resources are defined directly in the `infra/` directory.

For complete setup, deployment, and operational instructions, **please see the [Root README](../README.md)**.

## Layout

```text
infra/
├── bootstrap/                # S3 bucket for remote state (run once)
├── policies/                 # IAM JSON policies
├── networking.tf             # VPC, IGW, NAT, subnets, route tables
├── iam.tf                    # EKS cluster role + node group role
├── eks-cluster.tf            # EKS cluster, OIDC provider, node group, core addons (incl. metrics-server), ACM lookup
├── irsa.tf                   # ESO / ALB Controller / EBS CSI / Cluster Autoscaler IRSA roles + EBS CSI addon
├── secrets.tf                # Secrets Manager secrets
├── bootstrap.tf              # ArgoCD, ALB Controller, ESO, Cluster Autoscaler, gp3 StorageClass
├── locals.tf                 # Local variables
├── variables.tf              # Every knob, no env-specific defaults
├── outputs.tf                # All outputs
├── versions.tf               # Providers + partial backend (no state key)
├── providers.tf              # aws, helm, kubernetes provider configs
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

## Resource dependency graph

```text
networking.tf ──┐
iam.tf ─────────┤
                ├── eks-cluster.tf ── irsa.tf ── bootstrap.tf
secrets.tf ────────────────────────────────────/
```

The classic EKS IRSA cycle (IRSA roles need the OIDC provider → which needs the cluster → which needs the cluster role) is intentionally broken by splitting IAM:

- `iam.tf` creates only the cluster + node roles (no OIDC dependency).
- `eks-cluster.tf` creates the cluster and the OIDC provider.
- `irsa.tf` consumes the OIDC provider and creates the IRSA roles. The `aws-ebs-csi-driver` addon lives here too (not in `eks-cluster.tf`) because it needs its IRSA role at create time — keeping it downstream makes the graph linear and lets everything apply in a single `terraform apply`.

## Notes

- **Autoscaling.** The managed node group carries `k8s.io/cluster-autoscaler/*` auto-discovery tags (`eks-cluster.tf`) so the Cluster Autoscaler (`bootstrap.tf`, using the IRSA role from `irsa.tf`) can scale the ASG on pending pods. Pod-level scaling is handled by HPA in the Jerney chart, backed by the `metrics-server` EKS addon (`eks-cluster.tf`).
- Prod's private-only API endpoint means Terraform must run from inside the VPC (or a peered/VPN network) so the helm/kubernetes providers can reach the cluster. To solve this, you can provision a **Bastion Host** (an EC2 instance) in one of the VPC's public subnets. You can then use SSH port forwarding (`ssh -L`) or AWS Systems Manager (SSM) Session Manager to jump through the bastion to securely run `kubectl` and `terraform apply` against the private cluster.
