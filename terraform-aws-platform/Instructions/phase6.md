Phase 6 — Compute Layer: EC2 Auto Scaling

Excellent. Now we connect the ALB from Phase 5 to actual application compute.

The goal is to build this:

                         Internet
                            │
                            ▼
                    ┌───────────────┐
                    │      ALB      │
                    │ Public Subnet │
                    └───────┬───────┘
                            │
                       Target Group
                            │
                 ┌──────────┴──────────┐
                 ▼                     ▼
          ┌──────────────┐      ┌──────────────┐
          │   EC2 #1     │      │   EC2 #2     │
          │     AZ-a     │      │     AZ-b     │
          │ Private App  │      │ Private App  │
          └──────┬───────┘      └──────┬───────┘
                 │                     │
                 └──────────┬──────────┘
                            ▼
                           RDS

We'll use an Auto Scaling Group (ASG) rather than manually creating EC2 instances. That's important for your resume because it demonstrates production-oriented infrastructure design.

Phase 6.1 — What we're building

We'll create a new module:

modules/compute/
├── versions.tf
├── variables.tf
├── main.tf
└── outputs.tf

It will contain:

EC2 Launch Template
Auto Scaling Group
Multi-AZ placement
IAM instance profile
ALB target-group attachment
Health checks
Instance bootstrap
Basic application health endpoint

We will use:

min_size     = 2
desired_size = 2
max_size     = 4

So the application starts with two instances, one in each AZ.

Phase 6.2 — Create the module

From your repository root:

mkdir -p modules/compute

Check:

tree modules

You should eventually have:

modules/
├── alb/
├── compute/
├── iam/
├── networking/
└── security/
Phase 6.3 — Create versions.tf

Create:

modules/compute/versions.tf

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
Phase 6.4 — Define compute variables

Create:

modules/compute/variables.tf

Use:

variable "name" {
  description = "Name prefix for compute resources."
  type        = string
}


variable "vpc_id" {
  description = "VPC ID for the application."
  type        = string
}


variable "private_app_subnet_ids" {
  description = "Private application subnet IDs."
  type        = list(string)
}


variable "security_group_id" {
  description = "Security group attached to application instances."
  type        = string
}


variable "target_group_arn" {
  description = "ALB target group ARN."
  type        = string
}


variable "instance_profile_name" {
  description = "IAM instance profile name for EC2."
  type        = string
}


variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}


variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 2
}


variable "desired_size" {
  description = "Desired number of instances."
  type        = number
  default     = 2
}


variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}


variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}
Why t3.micro?

For this project we're deliberately using a small instance type.

The purpose is to demonstrate:

Terraform
ASG
ALB
IAM
networking
health checks
automation

—not to run a production workload.

We'll keep costs controlled.

Phase 6.5 — Find an AMI dynamically

We don't want to hard-code an AMI ID because AMI IDs vary by region and change over time.

In:

modules/compute/main.tf

start with:

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]


  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }


  filter {
    name   = "architecture"
    values = ["x86_64"]
  }


  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }


  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

This lets Terraform discover the latest matching Amazon Linux 2023 AMI.

Phase 6.6 — Create the Launch Template

Add:

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type


  iam_instance_profile {
    name = var.instance_profile_name
  }


  vpc_security_group_ids = [
    var.security_group_id
  ]


  user_data = base64encode(<<-EOF
    #!/bin/bash


    dnf update -y


    dnf install -y python3


    mkdir -p /opt/app


    cat > /opt/app/server.py <<'PYTHON'
    from http.server import BaseHTTPRequestHandler, HTTPServer


    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/health":
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"healthy")
            else:
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"terraform-aws-platform")


        def log_message(self, format, *args):
            return


    server = HTTPServer(("0.0.0.0", 8080), Handler)
    server.serve_forever()
    PYTHON


    cat > /etc/systemd/system/platform-app.service <<'SERVICE'
    [Unit]
    Description=Terraform AWS Platform Application
    After=network.target


    [Service]
    ExecStart=/usr/bin/python3 /opt/app/server.py
    Restart=always
    User=root


    [Install]
    WantedBy=multi-user.target
    SERVICE


    systemctl daemon-reload
    systemctl enable platform-app
    systemctl start platform-app
  EOF
  )


  tag_specifications {
    resource_type = "instance"


    tags = merge(
      var.tags,
      {
        Name = "${var.name}-app"
        Tier = "private-app"
      }
    )
  }


  tag_specifications {
    resource_type = "volume"


    tags = merge(
      var.tags,
      {
        Name = "${var.name}-app-volume"
      }
    )
  }
}
Why are we creating a Python application?

This is deliberately simple.

We don't need to deploy a real business application to prove the infrastructure works.

We need an endpoint:

GET /health

that returns:

200 OK

That allows the ALB to perform a real application-level health check.

This gives us:

ALB
 │
 │ GET /health
 ▼
EC2
 │
 └── Python application
        │
        └── HTTP 200

That's much better than simply demonstrating that EC2 instances exist.

Phase 6.7 — Create the Auto Scaling Group

Continue in main.tf:

resource "aws_autoscaling_group" "app" {
  name = "${var.name}-app-asg"


  min_size         = var.min_size
  desired_capacity = var.desired_size
  max_size         = var.max_size


  vpc_zone_identifier = var.private_app_subnet_ids


  target_group_arns = [
    var.target_group_arn
  ]


  health_check_type         = "ELB"
  health_check_grace_period = 180


  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }


  instance_refresh {
    strategy = "Rolling"


    preferences {
      min_healthy_percentage = 50
    }
  }


  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }


  tag {
    key                 = "Environment"
    value               = lookup(var.tags, "Environment", "unknown")
    propagate_at_launch = true
  }


  tag {
    key                 = "Tier"
    value               = "private-app"
    propagate_at_launch = true
  }


  lifecycle {
    create_before_destroy = true
  }
}
Phase 6.8 — Understand the ASG

This is an important interview concept.

We're saying:

min = 2
desired = 2
max = 4

Therefore:

Normal state:


AZ-a                    AZ-b
 EC2                     EC2
  │                       │
  └──────── ASG ──────────┘

If an instance fails:

AZ-a                    AZ-b
 EC2 ❌                  EC2
  │                       │
  └──────── ASG ──────────┘
             │
             ▼
         New EC2

The ASG replaces unhealthy capacity.

Phase 6.9 — Why health_check_type = "ELB"?

This is important.

We don't only want:

EC2 instance = running

We want:

EC2 instance
      │
      ▼
Application responds
      │
      ▼
/health = HTTP 200
      │
      ▼
ALB considers target healthy

That means our infrastructure is checking application health, not merely infrastructure health.

Phase 6.10 — Add outputs

Create:

modules/compute/outputs.tf

Use:

output "autoscaling_group_name" {
  description = "Application Auto Scaling Group name."
  value       = aws_autoscaling_group.app.name
}


output "launch_template_id" {
  description = "Application Launch Template ID."
  value       = aws_launch_template.app.id
}


output "launch_template_version" {
  description = "Application Launch Template version."
  value       = aws_launch_template.app.latest_version
}


output "ami_id" {
  description = "Amazon Linux AMI used by the application."
  value       = data.aws_ami.amazon_linux.id
}
Phase 6.11 — Connect Compute to the dev environment

Now open:

environments/dev/main.tf

Add:

module "compute" {
  source = "../../modules/compute"


  name = "${var.project_name}-${var.environment}"


  vpc_id = module.networking.vpc_id


  private_app_subnet_ids = module.networking.private_app_subnet_ids


  security_group_id = module.security.app_security_group_id


  target_group_arn = module.alb.target_group_arn


  instance_profile_name = module.iam.ec2_instance_profile_name


  instance_type = "t3.micro"


  min_size     = 2
  desired_size = 2
  max_size     = 4


  tags = {
    Environment = var.environment
  }
}

This is the key integration:

Networking
    │
    ├── private_app_subnet_ids
    │
    ▼
Compute


Security
    │
    └── app_security_group_id
             │
             ▼
          Compute


IAM
 │
 └── instance_profile
          │
          ▼
       Compute


ALB
 │
 └── target_group_arn
          │
          ▼
       Compute

Terraform now has the complete dependency graph.

Phase 6.12 — Add compute outputs

Open:

environments/dev/outputs.tf

Add:

output "autoscaling_group_name" {
  description = "Application Auto Scaling Group name."
  value       = module.compute.autoscaling_group_name
}


output "launch_template_id" {
  description = "Application Launch Template ID."
  value       = module.compute.launch_template_id
}


output "application_ami_id" {
  description = "Amazon Linux AMI used by the application."
  value       = module.compute.ami_id
}
Phase 6.13 — Format

From the repository root:

terraform fmt -recursive

Then:

cd environments/dev
Phase 6.14 — Initialize

Run:

terraform init

You should see Terraform discover:

- compute in ../../modules/compute
Phase 6.15 — Validate

Run:

terraform validate

Expected:

Success! The configuration is valid.

If you get an error, stop here and send me the complete error.

Phase 6.16 — Plan

Now:

terraform plan

Do not apply.

The plan should now include resources such as:

aws_launch_template.app
aws_autoscaling_group.app

And the total should increase from:

32

to approximately:

34

because we're adding two Terraform-managed resources for the compute layer.

The actual count can vary depending on your existing configuration, so don't worry if it's slightly different.

The critical requirement is:

0 to destroy

and no unexpected modifications to Phase 2–5 infrastructure.

Phase 6.17 — What to inspect carefully

When you run the plan, find:

module.compute.aws_launch_template.app

Check that it contains:

instance_type = "t3.micro"

and that it uses:

module.iam.ec2_instance_profile_name

Also check:

vpc_security_group_ids

is using your app security group.

Then find:

module.compute.aws_autoscaling_group.app

and verify:

min_size         = 2
desired_capacity = 2
max_size         = 4

Also verify that:

vpc_zone_identifier

contains your private application subnets.

This is extremely important.

We do not want:

ALB → public EC2

We want:

Internet
   │
   ▼
Public ALB
   │
   ▼
Private EC2
Phase 6.18 — Don't apply yet

Even though this phase is designed to work, do not run:

terraform apply

There are two reasons.

First, we're still building the project.

Second, once you apply Phase 6, AWS will actually create:

2 EC2 instances
an Auto Scaling Group
a Launch Template
associated networking

and therefore start generating AWS costs.

We'll continue building the remaining infrastructure before deciding when to deploy.