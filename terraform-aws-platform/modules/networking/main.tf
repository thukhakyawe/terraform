# Start with VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-igw"
    }
  )
}

# Public subnets
resource "aws_subnet" "public" {
  for_each = {
    for index, az in var.availability_zones :
    az => index
  }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = var.public_subnet_cidrs[each.value]
  map_public_ip_on_launch = falsh

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-${each.key}"
      Tier = "public"
    }
  )
}

# Private application subnets
resource "aws_subnet" "private_app" {
  for_each = {
    for index, az in var.availability_zones :
    az => index
  }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = var.private_app_subnet_cidrs[each.value]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-app-${each.key}"
      Tier = "private-app"
    }
  )
}

# Private database subnets
resource "aws_subnet" "private_db" {
  for_each = {
    for index, az in var.availability_zones :
    az => index
  }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = var.private_db_subnet_cidrs[each.value]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-db-${each.key}"
      Tier = "private-db"
    }
  )
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-rt"
    }
  )
}

# Associate public subnets
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Elastic IPs for NAT
resource "aws_eip" "nat" {
  for_each = var.enable_nat_gateway ? aws_subnet.public : {}

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-eip-${each.key}"
    }
  )
}

# NAT Gateways
resource "aws_nat_gateway" "this" {
  for_each = var.enable_nat_gateway ? aws_subnet.public : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  depends_on = [
    aws_internet_gateway.this
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-nat-${each.key}"
    }
  )
}

# Private application route tables
resource "aws_route_table" "private_app" {
  for_each = var.enable_nat_gateway ? aws_subnet.private_app : {}

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-app-rt-${each.key}"
    }
  )
}

resource "aws_route_table_association" "private_app" {
  for_each = var.enable_nat_gateway ? aws_subnet.private_app : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

# Database route table

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-db-rt"
    }
  )
}

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db.id
}

