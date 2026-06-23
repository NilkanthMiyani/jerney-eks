# VPC, subnets, IGW, and one NAT gateway per AZ. Everything is keyed by
# AZ name via for_each so adding/removing an AZ never re-indexes resources.

locals {
  # AZ name -> CIDR for each subnet tier, keyed for for_each.
  public_subnets  = { for i, az in local.availability_zones : az => var.public_subnet_cidrs[i] }
  private_subnets = { for i, az in local.availability_zones : az => var.private_subnet_cidrs[i] }
}

# ---- VPC ----
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

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

# ---- Elastic IPs (one per private subnet / AZ, OR just one if single_nat_gateway is true) ----
resource "aws_eip" "nat" {
  for_each = var.single_nat_gateway ? toset([local.availability_zones[0]]) : toset(local.availability_zones)
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-eip-${each.key}"
  })
}

# ---- NAT Gateways ----
resource "aws_nat_gateway" "main" {
  for_each      = var.single_nat_gateway ? toset([local.availability_zones[0]]) : toset(local.availability_zones)
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

  lifecycle {
    precondition {
      condition     = length(var.public_subnet_cidrs) == var.az_count
      error_message = "Public subnet count must equal AZ count."
    }
  }
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

  lifecycle {
    precondition {
      condition     = length(var.private_subnet_cidrs) == var.az_count
      error_message = "Private subnet count must equal AZ count."
    }
  }
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

# ---- Private Route Tables (one per AZ, egress via that AZ's NAT or the single NAT) ----
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[local.availability_zones[0]].id : aws_nat_gateway.main[each.key].id
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
