Phase 3 — Enterprise Networking / VPC Module
What we're building

Our target architecture is:

                         Internet
                            │
                            ▼
                    ┌───────────────┐
                    │ Internet      │
                    │ Gateway       │
                    └───────┬───────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
       Public Subnet A             Public Subnet B
              │                           │
              └──────────┬────────────────┘
                         │
                         ▼
                Application Load
                    Balancer
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
       Private App A          Private App B
          Subnet                 Subnet
              │                     │
              └──────────┬──────────┘
                         │
                         ▼
                   Private DB
                  Subnet A/B
                         │
                         ▼
                       RDS

And outbound traffic from private application subnets will go through:

Private App Subnet
       │
       ▼
 NAT Gateway
       │
       ▼
Internet Gateway
       │
       ▼
Internet

This is much closer to a real production architecture than putting everything in public subnets.

3.1 Why we're making this a reusable module

We don't want this:

dev/
   VPC code


stage/
   copied VPC code


prod/
   copied VPC code

That creates duplication.

Instead:

modules/
└── networking/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── versions.tf




environments/
├── dev/
│   └── calls networking module
├── stage/
│   └── calls networking module
└── prod/
    └── calls networking module

The same networking module can therefore be used three times with different variables.

This is one of the things that makes the project valuable for your resume.

3.2 Target directory

Go to your repository root.

Run:

mkdir -p modules/networking

Then:

cd modules/networking

Create:

modules/networking/
├── versions.tf
├── variables.tf
├── main.tf
└── outputs.tf
3.3 Create versions.tf

Create:

modules/networking/versions.tf

Put:

terraform {
  required_version = ">= 1.10.0"


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
Important

Notice that we're not creating an AWS provider here.

The module should not configure:

provider "aws" {}

The environment will provide the provider.

That makes the module reusable.

3.4 Create variables

Create:

modules/networking/variables.tf

We'll make the module configurable rather than hardcoding everything.

variable "name" {
  description = "Name prefix for networking resources."
  type        = string
}


variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}


variable "availability_zones" {
  description = "Availability Zones used by the VPC."
  type        = list(string)
}


variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
}


variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets."
  type        = list(string)
}


variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets."
  type        = list(string)
}


variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateway resources."
  type        = bool
  default     = true
}


variable "tags" {
  description = "Additional tags applied to networking resources."
  type        = map(string)
  default     = {}
}
3.5 Why these variables?

We're deliberately avoiding:

vpc_cidr = "10.0.0.0/16"

directly inside the module.

Instead:

Environment
     │
     │ variables
     ▼
Networking Module

For example:

Dev
10.10.0.0/16
Stage
10.20.0.0/16
Production
10.30.0.0/16

Same module.

Different configuration.

3.6 Create main.tf

Now the important part.

Create:

modules/networking/main.tf

Start with the VPC.

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
Why DNS?

AWS services and internal workloads frequently rely on DNS.

We want:

enable_dns_support   = true
enable_dns_hostnames = true
3.7 Internet Gateway

Add:

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-igw"
    }
  )
}

The Internet Gateway provides internet connectivity for resources in public subnets.

3.8 Public subnets

Now we'll create the public subnets dynamically.

resource "aws_subnet" "public" {
  for_each = {
    for index, az in var.availability_zones :
    az => index
  }


  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = var.public_subnet_cidrs[each.value]
  map_public_ip_on_launch = true


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-${each.key}"
      Tier = "public"
    }
  )
}

This is an important Terraform concept:

for_each

Instead of manually writing:

public_subnet_a
public_subnet_b

we generate them from the availability zone list.

3.9 Private application subnets

Add:

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

Notice:

map_public_ip_on_launch

is not enabled.

Therefore EC2 instances launched here won't automatically receive public IPv4 addresses.

That's exactly what we want.

3.10 Private database subnets

Add:

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

The database tier is completely private.

3.11 Public route table

Create:

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

This creates:

Public subnet
     │
     ▼
Public route table
     │
     ▼
Internet Gateway
     │
     ▼
Internet
3.12 Associate public subnets

Add:

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public


  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
3.13 Elastic IPs for NAT

Now we need NAT Gateway infrastructure.

Create:

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
3.14 NAT Gateways

Create:

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
Why one NAT Gateway per AZ?

For a production-oriented architecture, having one NAT Gateway per AZ improves availability and reduces dependency on a single AZ.

However, it increases cost.

This gives us a good future interview discussion:

"For production, I can use one NAT Gateway per AZ for resilience, while dev could use a single NAT Gateway to reduce cost."

That's exactly the kind of tradeoff you should be able to discuss.

3.15 Private application route tables

Add:

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

Then associate them:

resource "aws_route_table_association" "private_app" {
  for_each = var.enable_nat_gateway ? aws_subnet.private_app : {}


  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

Now:

EC2
 │
 ▼
Private App Subnet
 │
 ▼
NAT Gateway
 │
 ▼
Internet Gateway
 │
 ▼
Internet

The EC2 instance can initiate outbound connections without being directly reachable from the Internet.

3.16 Database route table

Here's an important security principle.

The database doesn't need internet access.

So create a private DB route table without a default internet route.

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-db-rt"
    }
  )
}

Associate it:

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db


  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db.id
}

Therefore:

Database
   │
   ▼
Private DB subnet
   │
   ▼
Private DB route table
   │
   X
   └── No Internet Gateway
   └── No NAT Gateway

That's much better than putting RDS behind a generic private application route table.

3.17 Create outputs

Now create:

modules/networking/outputs.tf

Put:

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}


output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}


output "public_subnet_ids" {
  description = "IDs of public subnets."
  value       = [for subnet in aws_subnet.public : subnet.id]
}


output "private_app_subnet_ids" {
  description = "IDs of private application subnets."
  value       = [for subnet in aws_subnet.private_app : subnet.id]
}


output "private_db_subnet_ids" {
  description = "IDs of private database subnets."
  value       = [for subnet in aws_subnet.private_db : subnet.id]
}


output "availability_zones" {
  description = "Availability Zones used by the network."
  value       = var.availability_zones
}

These outputs will be consumed later by:

ALB
EC2
RDS
Security Groups
Monitoring
3.18 Now connect the module to Dev

This is where the reusable module becomes useful.

Open:

environments/dev/main.tf

Replace the current simple configuration with:

module "networking" {
  source = "../../modules/networking"


  name = "${var.project_name}-${var.environment}"


  vpc_cidr = var.vpc_cidr


  availability_zones = var.availability_zones


  public_subnet_cidrs = var.public_subnet_cidrs


  private_app_subnet_cidrs = var.private_app_subnet_cidrs


  private_db_subnet_cidrs = var.private_db_subnet_cidrs


  enable_nat_gateway = var.enable_nat_gateway


  tags = {
    Environment = var.environment
  }
}
3.19 Add Dev variables

Open:

environments/dev/variables.tf

Add:

variable "project_name" {
  description = "Project name."
  type        = string
  default     = "terraform-aws-platform"
}


variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}


variable "vpc_cidr" {
  description = "CIDR block for the development VPC."
  type        = string
  default     = "10.10.0.0/16"
}


variable "availability_zones" {
  description = "Availability Zones used by the development environment."
  type        = list(string)


  default = [
    "ap-southeast-1a",
    "ap-southeast-1b"
  ]
}


variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs."


  type = list(string)


  default = [
    "10.10.1.0/24",
    "10.10.2.0/24"
  ]
}


variable "private_app_subnet_cidrs" {
  description = "Private application subnet CIDRs."


  type = list(string)


  default = [
    "10.10.11.0/24",
    "10.10.12.0/24"
  ]
}


variable "private_db_subnet_cidrs" {
  description = "Private database subnet CIDRs."


  type = list(string)


  default = [
    "10.10.21.0/24",
    "10.10.22.0/24"
  ]
}


variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateways."
  type        = bool
  default     = true
}
3.20 Why these CIDRs?

We're creating:

VPC
10.10.0.0/16

Inside:

Public
10.10.1.0/24
10.10.2.0/24


Private App
10.10.11.0/24
10.10.12.0/24


Private DB
10.10.21.0/24
10.10.22.0/24

Visually:

10.10.0.0/16
│
├── 10.10.1.0/24    Public AZ-A
├── 10.10.2.0/24    Public AZ-B
│
├── 10.10.11.0/24   App AZ-A
├── 10.10.12.0/24   App AZ-B
│
├── 10.10.21.0/24   DB AZ-A
└── 10.10.22.0/24   DB AZ-B

This gives us a clean tiered network.

3.21 Add module outputs to Dev

Open:

environments/dev/outputs.tf

Add:

output "vpc_id" {
  description = "Development VPC ID."
  value       = module.networking.vpc_id
}


output "public_subnet_ids" {
  description = "Development public subnet IDs."
  value       = module.networking.public_subnet_ids
}


output "private_app_subnet_ids" {
  description = "Development private application subnet IDs."
  value       = module.networking.private_app_subnet_ids
}


output "private_db_subnet_ids" {
  description = "Development private database subnet IDs."
  value       = module.networking.private_db_subnet_ids
}
3.22 Initialize Terraform again

Go to:

cd environments/dev

Then:

terraform init

Terraform should detect the new module:

Initializing modules...
- networking in ../../modules/networking
3.23 Format everything

From repository root:

terraform fmt -recursive
3.24 Validate

Go back to:

cd environments/dev

Run:

terraform validate

Expected:

Success! The configuration is valid.

If you get an error here, stop and send me the exact error.

Don't continue to apply.

3.25 Run the plan

Now:

terraform plan

This time the plan should be much larger.

You'll see resources such as:

aws_vpc
aws_internet_gateway
aws_subnet
aws_route_table
aws_route_table_association
aws_eip
aws_nat_gateway

Because we're creating the actual network.

You should not apply yet.

First inspect the plan.

Important: NAT Gateway cost

This is the first phase where you need to be conscious of AWS cost.

NAT Gateways are not free.

We're deliberately building a production-oriented architecture, but because this is your hands-on portfolio project, we don't necessarily need to leave NAT Gateways running continuously.

For the initial test, we can:

enable_nat_gateway = true

to verify the architecture.

Then later we can decide whether your dev environment should use:

enable_nat_gateway = false

or a lower-cost architecture.

Don't blindly leave expensive resources running.

3.26 AWS architecture verification

After eventually applying the network, we'll verify:

VPC
10.10.0.0/16
Public
10.10.1.0/24
10.10.2.0/24
Application
10.10.11.0/24
10.10.12.0/24
Database
10.10.21.0/24
10.10.22.0/24

And:

Public
   │
   ▼
Internet Gateway


Private App
   │
   ▼
NAT Gateway
   │
   ▼
Internet Gateway


Private DB
   │
   X
No internet route

3.27 Don't apply yet

At this exact point, your next command should be:

terraform plan

