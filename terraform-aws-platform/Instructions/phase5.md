Phase 5 — Load Balancer & Application Layer

Great. Phase 4 is complete, so now we're going to build the application entry point for the platform.

We will continue with the same rule:

No terraform apply yet.

We'll write the Terraform, validate it, run terraform plan, review the architecture, and commit it.

5.1 What we're building

Phase 5 will introduce:

Application Load Balancer (ALB)
ALB target group
ALB listener
Application security-group integration
Health checks
Public-subnet deployment
Outputs for the later compute module

The architecture becomes:

                         Internet
                            │
                     HTTP :80 / HTTPS :443
                            │
                            ▼
                    ┌───────────────┐
                    │      ALB      │
                    │ Public Subnet │
                    │    ALB-SG     │
                    └───────┬───────┘
                            │
                         :8080
                            │
                     Target Group
                            │
                            ▼
                    ┌───────────────┐
                    │ Application   │
                    │ Private Subnet│
                    │    App-SG     │
                    └───────────────┘

The important point is that the ALB is public, but the application workloads remain private.

5.2 Create the ALB module

From your repository root:

mkdir -p modules/alb

You should have:

modules/
├── networking/
├── security/
├── iam/
└── alb/

Inside modules/alb create:

modules/alb/
├── versions.tf
├── variables.tf
├── main.tf
└── outputs.tf
5.3 versions.tf

Create:

modules/alb/versions.tf

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
5.4 Define ALB variables

Create:

modules/alb/variables.tf

Use:

variable "name" {
  description = "Name prefix for ALB resources."
  type        = string
}


variable "vpc_id" {
  description = "VPC ID where the ALB will be deployed."
  type        = string
}


variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB."
  type        = list(string)
}


variable "security_group_id" {
  description = "Security group ID attached to the ALB."
  type        = string
}


variable "target_port" {
  description = "Application target port."
  type        = number
  default     = 8080
}


variable "health_check_path" {
  description = "HTTP path used for target health checks."
  type        = string
  default     = "/health"
}


variable "tags" {
  description = "Additional tags applied to ALB resources."
  type        = map(string)
  default     = {}
}
5.5 Create the Application Load Balancer

Create:

modules/alb/main.tf

Start with:

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"


  security_groups = [
    var.security_group_id
  ]


  subnets = var.public_subnet_ids


  enable_deletion_protection = false


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-alb"
      Tier = "public"
    }
  )
}

Why internal = false?

Because this ALB is our public application entry point.

Internet
   │
   ▼
Public ALB

Later, if we need internal services, we can create an internal ALB separately.

5.6 Create the target group

Add below the ALB:

resource "aws_lb_target_group" "app" {
  name        = "${var.name}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "instance"


  vpc_id = var.vpc_id


  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-app-tg"
      Tier = "private-app"
    }
  )
}

For now we're using:

target_type = "instance"

because our later compute phase will use EC2.

5.7 Why the health check matters

Our ALB won't simply ask:

"Is the EC2 instance running?"

It will ask:

GET /health

and expect:

HTTP 200

So eventually our application should expose:

/health

For example:

GET /health


HTTP/1.1 200 OK

This is a much more meaningful application-level health check.

5.8 Create the ALB listener

Add:

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-http-listener"
    }
  )
}

Our initial traffic flow becomes:

Client
  │
  │ HTTP :80
  ▼
ALB
  │
  │ forward
  ▼
Target Group
  │
  │ HTTP :8080
  ▼
Application
5.9 Why we're starting with HTTP

For the development environment, we're keeping the first implementation simple.

Later, we can add:

Route 53
   │
   ▼
ACM Certificate
   │
   ▼
HTTPS :443
   │
   ▼
ALB

and redirect:

HTTP :80
     ↓
HTTPS :443

That is better handled as a later hardening step rather than making Phase 5 unnecessarily complicated.

5.10 ALB outputs

Create:

modules/alb/outputs.tf

Use:

output "alb_id" {
  description = "Application Load Balancer ID."
  value       = aws_lb.this.id
}


output "alb_arn" {
  description = "Application Load Balancer ARN."
  value       = aws_lb.this.arn
}


output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.this.dns_name
}


output "target_group_arn" {
  description = "Application target group ARN."
  value       = aws_lb_target_group.app.arn
}


output "target_group_name" {
  description = "Application target group name."
  value       = aws_lb_target_group.app.name
}

These outputs will be consumed by the compute module later.

5.11 Connect ALB to the dev environment

Go to:

cd environments/dev

Open:

environments/dev/main.tf

Add:

module "alb" {
  source = "../../modules/alb"


  name = "${var.project_name}-${var.environment}"


  vpc_id = module.networking.vpc_id


  public_subnet_ids = module.networking.public_subnet_ids


  security_group_id = module.security.alb_security_group_id


  target_port       = 8080
  health_check_path = "/health"


  tags = {
    Environment = var.environment
  }
}

Notice the dependencies:

networking
    │
    ├── vpc_id
    │
    └── public_subnet_ids
          │
          ▼
         ALB


security
    │
    └── alb_security_group_id
                │
                ▼
               ALB

Terraform automatically understands these dependencies because the values come from module outputs.

5.12 Add ALB outputs to dev

Open:

environments/dev/outputs.tf

Add:

output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = module.alb.alb_dns_name
}


output "alb_arn" {
  description = "ARN of the application load balancer."
  value       = module.alb.alb_arn
}


output "target_group_arn" {
  description = "ARN of the application target group."
  value       = module.alb.target_group_arn
}
5.13 Check the module structure

Your project should now look approximately like:

terraform-aws-platform/
│
├── environments/
│   └── dev/
│       ├── backend.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── variables.tf
│       ├── versions.tf
│       └── terraform.tfvars
│
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   │
│   ├── security/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   │
│   ├── iam/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   │
│   └── alb/
│       ├── main.tf
│       ├── outputs.tf
│       ├── variables.tf
│       └── versions.tf
│
└── README.md
5.14 Format the Terraform

From the repository root:

terraform fmt -recursive

You should see Terraform formatting the files if anything needed adjustment.

5.15 Initialize Terraform

From:

environments/dev

run:

terraform init

Because we added a new module, Terraform should recognize:

- alb in ../../modules/alb

You may see something similar to:

Initializing modules...
- alb in ../../modules/alb
- iam in ../../modules/iam
- networking in ../../modules/networking
- security in ../../modules/security
5.16 Validate

Run:

terraform validate

Expected:

Success! The configuration is valid.

If validation fails, don't move forward. Send me the complete error.

5.17 Run the plan

Now:

terraform plan

Do not run:

terraform apply

We are still building the platform.

What you should expect

Previously:

Plan: 29 to add, 0 to change, 0 to destroy.

Now you'll have additional ALB resources.

At minimum, you should see:

aws_lb
aws_lb_target_group
aws_lb_listener

So the plan should be roughly:

29 existing planned resources
+
3 ALB resources
=
32 resources

Again, don't worry if the exact number differs slightly.

The important result is:

0 to change
0 to destroy

and the ALB resources should be present.

5.18 Important security check

Look carefully at the plan.

The ALB should use:

terraform-aws-platform-dev-alb-sg

Your application target group should use:

8080

And the architecture should effectively be:

Internet
   │
   │ 80
   ▼
ALB
   │
   │ 8080
   ▼
Application

There should not be an application security-group rule allowing:

0.0.0.0/0 → 8080

Our Phase 4 design should still enforce:

ALB-SG → App-SG
5.19 One architectural improvement to keep in mind

We are deliberately creating the ALB before the EC2 instances.

Therefore, initially:

ALB
 │
 ▼
Target Group
 │
 └── no registered instances yet

That's completely fine.

Phase 6 will create the compute layer and register instances with this target group.

Eventually:

                         Internet
                            │
                            ▼
                         ALB :80
                            │
                     Target Group
                      /          \
                     /            \
                EC2 AZ-a       EC2 AZ-b
                   │               │
                   └──────┬────────┘
                          │
                         RDS

That will give the project a much stronger high-availability story.