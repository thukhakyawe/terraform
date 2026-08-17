Phase 4 — Security & IAM
What we're building

The goal is to introduce proper security boundaries around the infrastructure we created in Phase 3.

Our target architecture becomes:

                         Internet
                            │
                            ▼
                    ┌───────────────┐
                    │     ALB       │
                    │ Public Subnet │
                    └───────┬───────┘
                            │
                     HTTP/HTTPS only
                            │
                            ▼
                    ┌───────────────┐
                    │ Application   │
                    │ Private Subnet│
                    └───────┬───────┘
                            │
                       DB port only
                            │
                            ▼
                    ┌───────────────┐
                    │     RDS       │
                    │ Private DB    │
                    └───────────────┘

And IAM:

EC2 / Application
       │
       ▼
 IAM Role
       │
       ├── CloudWatch
       ├── S3
       └── other required AWS APIs

The important principle is:

Do not give resources more network access or AWS permissions than they actually need.

Phase 4 objectives

We'll build:

Security Groups module
ALB security group
Application security group
Database security group
Least-privilege IAM role
IAM instance profile
Optional Lambda execution role
Security-related outputs
Validation and planning
Git commit

We will not build RDS or EC2 yet. Those come in later phases.

4.1 Create the security module

From the repository root:

mkdir -p modules/security
cd modules/security

Create:

modules/security/
├── versions.tf
├── variables.tf
├── main.tf
└── outputs.tf
4.2 versions.tf

Create:

modules/security/versions.tf

Use:

terraform {
  required_version = ">= 1.10.0"


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

Again, don't define the AWS provider inside the module.

4.3 Define security variables

Create:

modules/security/variables.tf

Use:

variable "name" {
  description = "Name prefix for security resources."
  type        = string
}


variable "vpc_id" {
  description = "VPC ID where security groups will be created."
  type        = string
}


variable "app_port" {
  description = "Application listening port."
  type        = number
  default     = 8080
}


variable "db_port" {
  description = "Database listening port."
  type        = number
  default     = 5432
}


variable "tags" {
  description = "Additional tags applied to security resources."
  type        = map(string)
  default     = {}
}

We're using PostgreSQL as our reference database for now.

Later, if we decide to use MySQL, the database port can simply become:

3306

without changing the module structure.

4.4 Create the ALB Security Group

Open:

modules/security/main.tf

Start with:

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for the application load balancer."
  vpc_id      = var.vpc_id


  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-alb-sg"
      Tier = "public"
    }
  )
}

This represents:

Internet
   │
   ├── TCP 80
   └── TCP 443
          │
          ▼
        ALB
4.5 Application Security Group

Now create:

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "Security group for application workloads."
  vpc_id      = var.vpc_id


  ingress {
    description     = "Application traffic from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }


  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-app-sg"
      Tier = "private-app"
    }
  )
}

This is much better than:

Internet → EC2:8080

Instead:

Internet
   │
   ▼
 ALB
   │
   │ 8080
   ▼
 EC2

Only the ALB security group can reach the application on port 8080.

4.6 Database Security Group

Now:

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Security group for database workloads."
  vpc_id      = var.vpc_id


  ingress {
    description     = "PostgreSQL from application workloads"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }


  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-db-sg"
      Tier = "private-db"
    }
  )
}

The important relationship is:

ALB SG
   │
   │ 8080
   ▼
APP SG
   │
   │ 5432
   ▼
DB SG

Notice that the database does not allow:

0.0.0.0/0 → 5432

That's a major security requirement.

4.7 Why Security Group references matter

This:

security_groups = [aws_security_group.app.id]

is preferable to:

cidr_blocks = ["10.10.0.0/16"]

for application-to-database communication.

We're saying:

Allow traffic from workloads belonging to this security group.

rather than:

Allow traffic from every IP in this CIDR.

That creates a much clearer security boundary.

4.8 Create outputs

Create:

modules/security/outputs.tf

Use:

output "alb_security_group_id" {
  description = "Security group ID for the application load balancer."
  value       = aws_security_group.alb.id
}


output "app_security_group_id" {
  description = "Security group ID for application workloads."
  value       = aws_security_group.app.id
}


output "db_security_group_id" {
  description = "Security group ID for database workloads."
  value       = aws_security_group.db.id
}

Later:

ALB module
     ↑
alb_security_group_id


EC2 module
     ↑
app_security_group_id


RDS module
     ↑
db_security_group_id
4.9 Connect Security module to Dev

Now go to:

cd ../../environments/dev

Open:

environments/dev/main.tf

We already have:

module "networking" {
  ...
}

Add below it:

module "security" {
  source = "../../modules/security"


  name = "${var.project_name}-${var.environment}"


  vpc_id = module.networking.vpc_id


  app_port = 8080
  db_port  = 5432


  tags = {
    Environment = var.environment
  }
}

Now we have module dependency:

networking
     │
     │ vpc_id
     ▼
security

Terraform understands this dependency automatically.

4.10 Add security outputs to Dev

Open:

environments/dev/outputs.tf

Add:

output "alb_security_group_id" {
  description = "ALB security group ID."
  value       = module.security.alb_security_group_id
}


output "app_security_group_id" {
  description = "Application security group ID."
  value       = module.security.app_security_group_id
}


output "db_security_group_id" {
  description = "Database security group ID."
  value       = module.security.db_security_group_id
}
4.11 Now IAM

Networking and security groups control:

NETWORK ACCESS

IAM controls:

AWS API ACCESS

We need both.

For example:

EC2
 │
 ├── Network access → Security Group
 │
 └── AWS API access → IAM Role
4.12 Create IAM module

Create:

mkdir -p ../../modules/iam
cd ../../modules/iam

Directory:

modules/iam/
├── versions.tf
├── variables.tf
├── main.tf
└── outputs.tf
4.13 IAM variables

modules/iam/variables.tf:

variable "name" {
  description = "Name prefix for IAM resources."
  type        = string
}


variable "tags" {
  description = "Additional tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
4.14 EC2 IAM role

Create modules/iam/main.tf:

resource "aws_iam_role" "ec2" {
  name = "${var.name}-ec2-role"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"


    Statement = [
      {
        Effect = "Allow"


        Principal = {
          Service = "ec2.amazonaws.com"
        }


        Action = "sts:AssumeRole"
      }
    ]
  })


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ec2-role"
    }
  )
}

This allows EC2 to assume the role.

4.15 CloudWatch permissions

For our initial platform, EC2 will eventually need to send logs and metrics.

AWS provides a managed policy for this.

Add:

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

This is intentionally limited to the functionality we need.

We're not giving the EC2 instance:

AdministratorAccess

That would completely undermine our least-privilege design.

4.16 SSM access

We also want the ability to manage EC2 instances through Systems Manager rather than opening SSH to the Internet.

Add:

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

This will become particularly useful later.

Our architecture can therefore avoid:

Internet → SSH :22 → EC2

and instead use:

AWS Systems Manager
        │
        ▼
       EC2
4.17 EC2 Instance Profile

EC2 needs an instance profile to use the IAM role.

Add:

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2.name


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ec2-profile"
    }
  )
}

The eventual relationship will be:

EC2
 │
 ▼
Instance Profile
 │
 ▼
IAM Role
 ├── CloudWatch
 └── SSM
4.18 IAM outputs

Create:

modules/iam/outputs.tf

Use:

output "ec2_role_name" {
  description = "Name of the EC2 IAM role."
  value       = aws_iam_role.ec2.name
}


output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role."
  value       = aws_iam_role.ec2.arn
}


output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile."
  value       = aws_iam_instance_profile.ec2.name
}
4.19 Connect IAM to Dev

Go to:

cd ../../environments/dev

Add to:

environments/dev/main.tf
module "iam" {
  source = "../../modules/iam"


  name = "${var.project_name}-${var.environment}"


  tags = {
    Environment = var.environment
  }
}

Then add to outputs.tf:

output "ec2_role_arn" {
  description = "EC2 IAM role ARN."
  value       = module.iam.ec2_role_arn
}


output "ec2_instance_profile_name" {
  description = "EC2 instance profile name."
  value       = module.iam.ec2_instance_profile_name
}
4.20 Format everything

From repository root:

terraform fmt -recursive
4.21 Initialize

From:

environments/dev

run:

terraform init

You should see the new modules:

- iam in ../../modules/iam
- networking in ../../modules/networking
- security in ../../modules/security
4.22 Validate

Run:

terraform validate

Expected:

Success! The configuration is valid.

If you get an error, stop here and send me the complete error.

4.23 Plan — but don't apply

Now:

terraform plan

You should now see additional resources.

Conceptually:

Networking
22 resources


+


Security Groups
3 resources


+


IAM
4 resources

So approximately:

29 resources

The exact count can vary slightly depending on provider behavior and existing resources, so don't worry if it's not exactly 29.

What matters is:

Plan: XX to add, 0 to change, 0 to destroy.