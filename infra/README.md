# Jerney EKS — Terraform Infrastructure

- VPC, subnets, Internet Gateway, NAT Gateway(s), route tables
- EKS control plane (control-plane logging enabled)
- OIDC provider for IRSA
- Managed node group (with an explicit launch template so workloads get a self-managed node SG)
- IRSA IAM role (created, not attached to any workload): EBS CSI
- DevOps IAM Group, Role, and EKS Access Entry for fast team onboarding
- ECR repositories for the app images (`jerney-frontend`, `jerney-backend`)

## Layout

```text
infra/
├── bootstrap/                # S3 bucket for remote state (run once)
├── vpc.tf                    # VPC, IGW, NAT (single or per-AZ), subnets, route tables
├── iam.tf                    # EKS cluster role, node group role, EBS CSI IRSA role, DevOps group & role
├── eks.tf                    # EKS cluster (logging), OIDC, node group, EBS CSI addon, Access Entries
├── security-groups.tf        # Explicit node security group (one rule per resource)
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
| `cluster_security_group_id` | EKS-managed cluster SG for any add-on that needs it |
| `node_security_group_id` | Explicit node SG attached to the workers |
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

- **NAT gateways** — one NAT per AZ (HA by default), or a single shared NAT Gateway for cost (`single_nat_gateway = true`). Note: managed NAT Gateways do not support security groups; egress control for them is via route tables and subnet NACLs.
- **`endpoint_public_access` / `public_access_cidrs`** — prod defaults to a private-only endpoint (`endpoint_public_access = false`). Where a public endpoint is enabled (dev/staging), it must be restricted to known office/VPN CIDRs — `0.0.0.0/0` is never allowed. Note: while the endpoint is private, `public_access_cidrs` must stay at the AWS default (`0.0.0.0/0`); it is ignored in that mode.
- **Security groups** — an explicit node SG is declared in `security-groups.tf` rather than relying on the EKS-managed cluster SG alone. Each rule is a standalone `aws_security_group_rule` for reviewability. Node egress is open as an intentional baseline to tighten later. The ALB's SG is created and managed by the AWS LB Controller at runtime, so it is intentionally not pre-declared here.
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

## Onboarding New Engineers

This cluster uses a fast onboarding model via AWS IAM Groups. **No Terraform changes are required** when adding or removing engineers.

To onboard a new engineer:
1. In the AWS Console, create a new IAM User for the engineer (or use AWS SSO).
2. Add the user to the **DevOps** IAM Group.
3. Have the engineer configure their local AWS credentials. The cleanest approach is to define a base profile with their keys, and a secondary profile that automatically assumes the DevOps role.

   In `~/.aws/config` (or `credentials`):
   ```ini
   [profile personal]
   aws_access_key_id=...
   aws_secret_access_key=...

   [profile eks-admin]
   role_arn = arn:aws:iam::<your-account-id>:role/<cluster_name>-devops-role
   source_profile = personal
   ```

4. Have the engineer update their kubeconfig using the new `eks-admin` profile. Because the profile is configured to assume the role, the CLI handles the authentication swap automatically:

   ```bash
   aws eks update-kubeconfig \
     --region <your-region> \
     --name <cluster_name> \
     --profile eks-admin
   ```

5. The engineer can now run `kubectl get nodes` to verify access.
