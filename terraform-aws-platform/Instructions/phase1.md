PHASE 1 — Create the repository

Create the repository on GitHub:

terraform-aws-platform

Description:

Production-oriented AWS Infrastructure as Code platform using Terraform, GitLab CI/CD, and reusable modules.

Don't put "beginner", "learning", or "lab" in the repository description.

This is a portfolio engineering project.

1.1 Clone it
git clone https://github.com/thukhakyawe/terraform-aws-platform.git

Then:

cd terraform-aws-platform
1.2 Create the initial structure

Run:

mkdir -p modules/{networking,security,iam,compute,database,monitoring}
mkdir -p environments/{dev,stage,prod}
mkdir -p architecture
mkdir -p docs
mkdir -p scripts
mkdir -p tests

Then:

touch README.md
touch .gitignore
touch .editorconfig
touch .pre-commit-config.yaml
touch .gitlab-ci.yml

You should now have:

terraform-aws-platform/
├── architecture/
├── docs/
├── environments/
│   ├── dev/
│   ├── stage/
│   └── prod/
├── modules/
│   ├── compute/
│   ├── database/
│   ├── iam/
│   ├── monitoring/
│   ├── networking/
│   └── security/
├── scripts/
├── tests/
├── .editorconfig
├── .gitignore
├── .gitlab-ci.yml
├── .pre-commit-config.yaml
└── README.md
PHASE 1.2 — .gitignore

Put this in .gitignore:

# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
.terraform.lock.hcl


# Terraform variables
*.tfvars
*.tfvars.json
!*.tfvars.example


# Crash logs
crash.log
crash.*.log


# Secrets
.env
.env.*
*.pem
*.key


# AWS
.aws/


# IDE
.vscode/
.idea/


# OS
.DS_Store
Thumbs.db


# Python
__pycache__/
*.pyc
.venv/
venv/


# Temporary files
*.tmp
*.temp
One correction

For a real project, I actually recommend committing .terraform.lock.hcl because it pins provider dependency versions.

So change that section to:

# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfplan

Do not ignore .terraform.lock.hcl.

We'll commit it.

PHASE 1.3 — .editorconfig

Put:

root = true


[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2


[*.tf]
indent_size = 2


[*.md]
trim_trailing_whitespace = false

This keeps formatting consistent.

PHASE 1.4 — Terraform foundation

Create:

environments/dev/versions.tf

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


provider "aws" {
  region = var.aws_region


  default_tags {
    tags = {
      Project     = "terraform-aws-platform"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "thukhakyawe"
    }
  }
}

Note: If your installed AWS provider version isn't compatible with ~> 6.0, we'll adjust after running terraform init. Don't blindly change things; show me the error if you get one.

PHASE 1.5 — Variables

Create:

environments/dev/variables.tf
variable "aws_region" {
  description = "AWS region where infrastructure will be deployed."
  type        = string
  default     = "ap-southeast-1"
}


variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}
PHASE 1.6 — Main configuration

Create:

environments/dev/main.tf

For now:

locals {
  name_prefix = "platform-${var.environment}"
}

That's intentionally small.

We're not creating EC2, VPC, or RDS yet.

PHASE 1.7 — Outputs

Create:

environments/dev/outputs.tf

For now:

output "environment" {
  description = "Deployment environment."
  value       = var.environment
}


output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}
PHASE 1.8 — Example variables

Create:

environments/dev/terraform.tfvars.example
aws_region  = "ap-southeast-1"
environment = "dev"

Do not create a real terraform.tfvars yet unless necessary.

The .example file is safe to commit.

PHASE 1.9 — Initialize Terraform

Go into:

cd environments/dev

Run:

terraform init

Then:

terraform fmt -recursive

Then:

terraform validate

You should get:

Success! The configuration is valid.

Then:

terraform plan

At this point, Terraform should have nothing to create, because we haven't added AWS resources yet.

That's intentional.

PHASE 1.10 — Git

Go back to repository root:

cd ../..

Check:

git status

Make sure you're not seeing:

.terraform/
terraform.tfstate

Those should not be committed.

You should see things such as:

.gitignore
.editorconfig
README.md
environments/
modules/
docs/
architecture/

Then:

git add .

Commit:

git commit -m "chore: initialize Terraform platform structure"

Push: