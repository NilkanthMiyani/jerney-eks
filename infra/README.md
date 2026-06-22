# Jerney EKS — Terraform Infrastructure

- VPC, subnets, Internet Gateway, NAT Gateway(s), route tables
- EKS control plane (control-plane logging enabled)
- OIDC provider for IRSA
- Managed node group
- EKS managed addons: `vpc-cni`, `coredns`, `kube-proxy`, `metrics-server`, `aws-ebs-csi-driver`
- IRSA IAM role (created, not attached to any workload): EBS CSI
- ECR repositories for the app images (`jerney-frontend`, `jerney-backend`)

## Layout

```text
infra/
├── bootstrap/                # S3 bucket for remote state (run once)
├── vpc.tf                    # VPC, IGW, NAT (single or per-AZ), subnets, route tables
├── iam.tf                    # EKS cluster role, node group role, EBS CSI IRSA role
├── eks.tf                    # EKS cluster (logging), OIDC, node group, managed addons
├── ecr.tf                    # ECR repos for the app images
├── locals.tf                 # Local variables (tags, AZs)
├── variables.tf              # Every knob, no env-specific defaults
├── outputs.tf                # Contract consumed by the bootstrap stage
├── versions.tf               # required_providers (aws, tls) + S3 backend
├── providers.tf              # aws provider config only
├── dev.tfvars.example        # Dev environment variables template
├── staging.tfvars.example    # Staging environment variables template
└── prod.tfvars.example       # Prod environment variables template
```

## Outputs (the handoff to bootstrap)

| Output | Purpose |
|---|---|
| `cluster_name`, `cluster_endpoint`, `cluster_ca_data` | kubeconfig / API access for bootstrap |
| `cluster_security_group_id` | Cluster SG for any add-on that needs it |
| `oidc_provider_arn`, `oidc_provider_url` | Build IRSA trust for additional service accounts |
| `ebs_csi_role_arn` | Annotate the EBS CSI service account (`eks.amazonaws.com/role-arn`) |
| `ecr_repository_urls` | App image repos for the bootstrap stage / CI |
| `vpc_id`, `public_subnets`, `private_subnets` | Networking references |
| `kubeconfig_command` | Convenience for connecting kubectl |

## Usage

Use **Terraform Workspaces** so each environment's state is isolated.

```bash
cd infra/

# 1. Initialize (run once)
terraform init

# 2. Fresh setup: create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# 3. Select the target workspace
terraform workspace select dev

# 4. Plan and apply with the environment's variables
terraform plan  -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

## Prod hardening knobs

- **NAT gateways** — one NAT per AZ (HA by default). Non-prod cost is controlled by `az_count` (fewer AZs = fewer NATs), not by a NAT toggle.
- **`endpoint_public_access` / `public_access_cidrs`** — keep the API endpoint private in prod, or restrict the public endpoint to known CIDRs. Never leave prod open to `0.0.0.0/0`.
- **Control-plane logging** — all log types (`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`) are shipped to CloudWatch.

## Resource dependency graph

```text
vpc.tf ──┐
iam.tf ──┼── eks.tf ── (managed addons, incl. EBS CSI wired to the IRSA role in iam.tf)
```

Terraform orders these from the resource references, not the file names: `eks.tf` creates the
cluster and OIDC provider, and the EBS CSI IRSA role in `iam.tf` references that OIDC provider, so
it is created after the cluster. The base cluster/node roles in `iam.tf` have no OIDC dependency,
so there is no cycle and the whole layer applies in a single `terraform apply`.

## Destroy

Because Terraform no longer manages anything inside the cluster, destroy is a plain
`terraform destroy` — there is no helm/kubernetes provider to lose auth mid-destroy, and no
`state rm` workaround.

```bash
cd infra/
terraform workspace select dev
terraform destroy -var-file="dev.tfvars"
```

> Note: ALBs/NLBs + their security groups (AWS LB Controller) and EBS volumes (EBS CSI, for PVCs)
> are created **at runtime by in-cluster controllers** and aren't tracked in any Terraform state.
> Before destroying the cluster, delete the app's `Ingress`/`Service`/`PVC` objects **while their
> controllers are still running** so the controllers deprovision the AWS resources — then sweep for
> any orphaned ALBs / SGs / volumes.
