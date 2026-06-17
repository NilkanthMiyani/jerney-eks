# ==============================================================
# Module: networking
#
# VPC + all networking primitives for an EKS cluster:
#   VPC, Internet Gateway, single NAT Gateway (cost-optimized),
#   public subnets (for ALB) and private subnets (for nodes),
#   route tables and associations.
#
# Subnets use for_each keyed by AZ name (not count) so that adding
# or removing an AZ never re-indexes — and therefore never destroys —
# existing subnets.
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

# ---- Elastic IP for NAT Gateway ----
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-eip"
  })
}

# ---- NAT Gateway (single — cost saving, ~$32/mo vs ~$96/mo for 3-AZ HA) ----
# Lives in the first public subnet; private subnets route egress through it.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.availability_zones[0]].id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat"
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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-private-rt"
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
  route_table_id = aws_route_table.private.id
}
