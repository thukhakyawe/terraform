# Day 11: Working with Lists, Maps, and Sets

🧪 Hands-On Lab: Collection Mastery

Let’s build a complex infrastructure using advanced collection techniques!
# Step 1: Create Project

```
mkdir terraform-collections-lab
cd terraform-collections-lab
```

# Step 2: Create variables.tf
```
# variables.tf

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "collections-demo"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "subnet_configurations" {
  description = "List of subnet configurations"
  type = list(object({
    name = string
    cidr = string
    type = string
    tier = string
  }))

  default = [
    { name = "web-1", cidr = "10.0.1.0/24", type = "public", tier = "web" },
    { name = "web-2", cidr = "10.0.2.0/24", type = "public", tier = "web" },
    { name = "app-1", cidr = "10.0.11.0/24", type = "private", tier = "app" },
    { name = "app-2", cidr = "10.0.12.0/24", type = "private", tier = "app" },
    { name = "db-1", cidr = "10.0.21.0/24", type = "private", tier = "db" },
    { name = "db-2", cidr = "10.0.22.0/24", type = "private", tier = "db" }
  ]
}

variable "instance_configs" {
  description = "Instance configurations per tier"
  type = map(object({
    instance_type = string
    count         = number
    user_data     = string
  }))

  default = {
    web = {
      instance_type = "t2.micro"
      count         = 2
      user_data     = "#!/bin/bash\\necho 'Web Server' > /var/www/html/index.html"
    }
    app = {
      instance_type = "t2.small"
      count         = 2
      user_data     = "#!/bin/bash\\necho 'App Server'"
    }
  }
}

variable "common_tags" {
  type = map(string)
  default = {
    Project   = "Collections Demo"
    ManagedBy = "Terraform"
  }
}
```

# Step 3: Create locals.tf
```
# locals.tf

locals {
  # Filter subnets by type
  public_subnets = [
    for subnet in var.subnet_configurations :
    subnet if subnet.type == "public"
  ]

  private_subnets = [
    for subnet in var.subnet_configurations :
    subnet if subnet.type == "private"
  ]

  # Group subnets by tier
  subnets_by_tier = {
    for tier in distinct([for s in var.subnet_configurations : s.tier]) :
    tier => [
      for subnet in var.subnet_configurations :
      subnet if subnet.tier == tier
    ]
  }

  # Create subnet map for easy lookup
  subnet_map = {
    for subnet in var.subnet_configurations :
    subnet.name => subnet
  }

  # Get all tiers
  all_tiers = distinct([for s in var.subnet_configurations : s.tier])

  # Get all CIDR blocks
  all_cidrs = [for s in var.subnet_configurations : s.cidr]

  # Distribute subnets across AZs
  subnet_az_mapping = {
    for idx, subnet in var.subnet_configurations :
    subnet.name => var.availability_zones[idx % length(var.availability_zones)]
  }

  # Create security group rules matrix
  tier_connectivity = {
    web = ["app"]
    app = ["db"]
    db  = []
  }

  # Flatten instance deployments
  instance_deployments = flatten([
    for tier, config in var.instance_configs : [
      for i in range(config.count) : {
        tier          = tier
        index         = i
        instance_type = config.instance_type
        user_data     = config.user_data
        subnet        = local.subnets_by_tier[tier][i % length(local.subnets_by_tier[tier])].name
      }
    ]
  ])

  # Create deployment map
  deployment_map = {
    for deployment in local.instance_deployments :
    "${deployment.tier}-${deployment.index}" => deployment
  }

  # Calculate network statistics
  network_stats = {
    total_subnets    = length(var.subnet_configurations)
    public_subnets   = length(local.public_subnets)
    private_subnets  = length(local.private_subnets)
    tiers            = length(local.all_tiers)
    total_instances  = sum([for c in var.instance_configs : c.count])
    azs_used         = length(var.availability_zones)
  }

  # Merge tags for each tier
  tier_tags = {
    for tier in local.all_tiers :
    tier => merge(
      var.common_tags,
      { Tier = tier }
    )
  }
}
```

# Step 4: Create main.tf
```
# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# Subnets using for_each
resource "aws_subnet" "subnets" {
  for_each = local.subnet_map

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = local.subnet_az_mapping[each.key]
  map_public_ip_on_launch = each.value.type == "public"

  tags = merge(local.tier_tags[each.value.tier], {
    Name = "${var.project_name}-${each.key}"
    Type = each.value.type
  })
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  count = length(local.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  for_each = {
    for subnet in local.public_subnets :
    subnet.name => aws_subnet.subnets[subnet.name].id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.public[0].id
}

# Security Groups per tier
resource "aws_security_group" "tier_sgs" {
  for_each = toset(local.all_tiers)

  name        = "${var.project_name}-${each.key}-sg"
  description = "Security group for ${each.key} tier"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tier_tags[each.key], {
    Name = "${var.project_name}-${each.key}-sg"
  })
}

# AMI Data Source
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EC2 Instances
resource "aws_instance" "instances" {
  for_each = local.deployment_map

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = each.value.instance_type
  subnet_id              = aws_subnet.subnets[each.value.subnet].id
  vpc_security_group_ids = [aws_security_group.tier_sgs[each.value.tier].id]
  user_data              = each.value.user_data

  tags = merge(local.tier_tags[each.value.tier], {
    Name  = "${var.project_name}-${each.key}"
    Index = each.value.index
  })
}
```

# Step 5: Create outputs.tf
```
# outputs.tf

output "network_statistics" {
  description = "Network statistics"
  value       = local.network_stats
}

output "subnets_by_tier" {
  description = "Subnets grouped by tier"
  value = {
    for tier, subnets in local.subnets_by_tier :
    tier => [for s in subnets : s.name]
  }
}

output "subnet_details" {
  description = "Detailed subnet information"
  value = {
    for name, subnet in aws_subnet.subnets :
    name => {
      id   = subnet.id
      cidr = subnet.cidr_block
      az   = subnet.availability_zone
    }
  }
}

output "instance_distribution" {
  description = "Instances per tier"
  value = {
    for tier in local.all_tiers :
    tier => length([
      for key, inst in local.deployment_map :
      inst if inst.tier == tier
    ])
  }
}

output "instance_ips_by_tier" {
  description = "Instance IPs grouped by tier"
  value = {
    for tier in local.all_tiers :
    tier => [
      for key, instance in aws_instance.instances :
      instance.private_ip if local.deployment_map[key].tier == tier
    ]
  }
}

output "all_instance_ips" {
  description = "All instance IPs"
  value       = values(aws_instance.instances)[*].private_ip
}

output "tier_security_groups" {
  description = "Security group IDs per tier"
  value = {
    for tier, sg in aws_security_group.tier_sgs :
    tier => sg.id
  }
}
```

# Step 6: Deploy and Explore

# Initialize
terraform init
# Plan and review the collections magic!
terraform plan
# Apply
terraform apply -auto-approve

![alt text](image.png)

# View outputs
terraform output network_statistics
terraform output subnets_by_tier
terraform output instance_distribution
terraform output instance_ips_by_tier

![alt text](image-1.png)

# Clean up
terraform destroy -auto-approve

![alt text](image-2.png)


📝 Summary

Today I learned:

✅ For expressions (list, map transformations)

✅ Splat expressions for attribute extraction

✅ Essential collection functions

✅ Advanced filtering and grouping

✅ Complex data transformations

✅ Dynamic infrastructure patterns


This lab was built using [StackOps - Diary](https://stackopsdiary.site/day-11-working-with-lists-maps-and-sets).


