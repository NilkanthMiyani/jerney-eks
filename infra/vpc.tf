# ==============================================================
# VPC + all networking primitives for an EKS cluster:
#   VPC, Internet Gateway, NAT Gateways, public subnets (for ALB)
#   and private subnets (for nodes), route tables and associations.
#
# One NAT gateway per AZ: egress for each AZ's private subnet routes
# through that AZ's own NAT, so a single AZ outage can't cut egress for
# the others. Non-prod cost scales with the number of AZs (fewer AZs =
# fewer NATs), configured in tfvars — there is no NAT toggle.
#
# Every NAT / EIP / route-table resource is keyed by AZ name via
# for_each (matching the subnets), so adding or removing an AZ never
# re-indexes — and therefore never destroys — existing resources.
# ==============================================================

locals {
  # Map AZ name -> CIDR for each subnet tier. The environment passes
  # availability_zones and the parallel *_subnet_cidrs lists; we zip
  # them into stable, name-keyed maps for for_each.
  public_subnets  = { for i, az in local.availability_zones : az => var.public_subnet_cidrs[i] }
  private_subnets = { for i, az in local.availability_zones : az => var.private_subnet_cidrs[i] }
}

# ---- VPC ----
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # required for EKS

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# ---- Internet Gateway ----
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# ---- Elastic IPs (one per private subnet / AZ) ----
resource "aws_eip" "nat" {
  for_each = aws_subnet.private
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-eip-${each.key}"
  })
}

# ---- NAT Gateways (one per AZ, in that AZ's public subnet) ----
resource "aws_nat_gateway" "main" {
  for_each      = aws_subnet.private
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.main]
}

# ---- Public Subnets (for ALB) ----
# Tagged kubernetes.io/role/elb so the AWS LB Controller discovers them.
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                        = "${var.cluster_name}-public-${each.key}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# ---- Private Subnets (for EKS nodes) ----
# Tagged kubernetes.io/role/internal-elb for internal load balancer discovery.
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(local.common_tags, {
    Name                                        = "${var.cluster_name}-private-${each.key}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# ---- Route Tables ----
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

# ---- Private Route Tables (one per AZ, egress via that AZ's NAT) ----
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-private-rt-${each.key}"
  })
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
