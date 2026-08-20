# Terraform AWS Platform

A modular AWS infrastructure platform built with Terraform.

The project demonstrates how to design, provision, validate, secure, monitor, and document a multi-tier AWS environment using Infrastructure as Code.

> **Current status:** Terraform configuration and CI validation are complete. The development environment has been validated with `terraform plan`, but AWS resources have not been provisioned with `terraform apply` to avoid unnecessary infrastructure costs.

---

## Architecture

The platform is designed as a three-tier AWS architecture:

- Public tier — Application Load Balancer
- Private application tier — EC2 instances managed by an Auto Scaling Group
- Private database tier — Amazon RDS PostgreSQL
- Monitoring tier — Amazon CloudWatch, SNS, and KMS
- Identity and access — IAM roles and instance profiles
- Management access — AWS Systems Manager Session Manager

The networking layer contains:

- One VPC
- Two Availability Zones
- Two public subnets
- Two private application subnets
- Two private database subnets
- Internet Gateway
- NAT Gateways
- Public and private route tables

---

## Architecture Flow

```text
                         Internet
                            |
                            v
                +-----------------------+
                | Application Load      |
                | Balancer              |
                | Public Subnets        |
                +-----------+-----------+
                            |
                            | HTTP
                            v
                +-----------------------+
                | EC2 Auto Scaling      |
                | Application Tier      |
                | Private Subnets       |
                +-----------+-----------+
                            |
                            | PostgreSQL
                            v
                +-----------------------+
                | Amazon RDS PostgreSQL |
                | Private DB Subnets    |
                +-----------------------+


        Monitoring
            |
            +---- CloudWatch
            |
            +---- SNS
            |
            +---- KMS



| Technology                    | Purpose                          |
| ----------------------------- | -------------------------------- |
| Terraform                     | Infrastructure as Code           |
| AWS VPC                       | Network architecture             |
| AWS EC2                       | Application workloads            |
| AWS Auto Scaling              | Application scaling              |
| AWS Application Load Balancer | Application traffic distribution |
| Amazon RDS PostgreSQL         | Relational database              |
| AWS IAM                       | Identity and access management   |
| AWS Systems Manager           | Instance management              |
| Amazon CloudWatch             | Monitoring and alarms            |
| Amazon SNS                    | Alert notifications              |
| AWS KMS                       | Encryption key management        |
| Amazon S3                     | Terraform remote state           |
| GitHub Actions                | CI validation                    |
| Trivy                         | Terraform security scanning      |


Repository Structure

terraform-aws-platform/
│
├── bootstrap/
│   └── state/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
│
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── backend.tf
│       └── versions.tf
│
├── modules/
│   ├── alb/
│   ├── compute/
│   ├── database/
│   ├── iam/
│   ├── monitoring/
│   ├── networking/
│   └── security/
│
├── Instructions/
│   ├── phase0.md
│   ├── phase1.md
│   ├── phase2.md
│   ├── phase3.md
│   ├── phase4.md
│   ├── phase5.md
│   ├── phase6.md
│   ├── phase7.md
│   ├── phase8.md
│   └── phase9.md
│
├── docs/
│
├── .github/
│   └── workflows/
│       └── terraform-validate.yml
│
├── .gitignore
├── .pre-commit-config.yaml
├── README.md
└── .trivyignore


Terraform Modules
Networking

Creates the foundational AWS network:

VPC
Public subnets
Private application subnets
Private database subnets
Internet Gateway
NAT Gateways
Route tables
Route table associations
Security

Creates separate security groups for:

Application Load Balancer
Application workloads
Database

Traffic is restricted between tiers using security-group references.

The database is not directly exposed to the public internet.

IAM

Creates the EC2 IAM role and instance profile used by application workloads.

Permissions include access required for:

AWS Systems Manager
CloudWatch monitoring
Application Load Balancer

Creates:

Application Load Balancer
Target group
HTTP listener

The ALB sends application traffic to the EC2 target group.

Compute

Creates:

EC2 Launch Template
EC2 Auto Scaling Group

The application instances run in private application subnets.

Current development configuration:

Instance type: t3.micro
Minimum:       2
Desired:       2
Maximum:       4
Database

Creates:

Amazon RDS PostgreSQL
DB subnet group
Secrets Manager secret
Random database password

Current development configuration:

Engine:           PostgreSQL
Version:          16
Instance class:   db.t3.micro
Storage:          20 GB
Multi-AZ:         false
Backup retention: 7 days
Database:         platform
Monitoring

Creates:

CloudWatch dashboard
CloudWatch alarms
SNS topic
Customer-managed KMS key

Monitored components include:

ALB
Application Load Balancer target health
ALB latency
ALB 5xx errors
Auto Scaling Group CPU
RDS CPU
RDS connections
RDS free storage
AWS Region

The development environment currently uses:

ap-southeast-1

The region is configurable through the Terraform variable:

variable "aws_region"
Prerequisites

Install and configure:

Git
AWS CLI
Terraform
Trivy

Verify:

git --version
aws --version
terraform version
trivy --version

Verify AWS authentication:

aws sts get-caller-identity

AWS credentials must never be committed to this repository.

Terraform Validation

The project uses Terraform validation and security scanning through GitHub Actions.

The CI pipeline performs:

Terraform formatting check
Terraform initialization
Terraform validation
Terraform security scanning with Trivy

Run locally:

cd environments/dev


terraform fmt -check -recursive ../../
terraform init -backend=false
terraform validate

Run the security scan:

cd ../..


trivy config . --severity HIGH,CRITICAL
Terraform Plan

The development environment can be planned without provisioning AWS infrastructure:

cd environments/dev


terraform init
terraform plan -out=tfplan

The current plan contains:

56 resources to add
0 resources to change
0 resources to destroy

The plan has been reviewed successfully.

No terraform apply has been executed for the development environment.

Deployment

To deploy the development environment:

cd environments/dev


terraform init
terraform plan -out=tfplan
terraform apply tfplan

Before applying infrastructure, review the estimated AWS costs and confirm that the environment should be provisioned.

After deployment:

terraform output
Destroy

To remove the development infrastructure:

cd environments/dev


terraform destroy

Always review the destroy plan before confirming.

Remote State

The development environment uses an Amazon S3 backend for Terraform state.

The backend configuration stores state under:

environments/dev/terraform.tfstate

Terraform state must not be committed to Git.

State files may contain sensitive infrastructure information and should be protected appropriately.

Security

Security controls include:

Separate security groups for ALB, application, and database tiers
Database access restricted to the application security group
Application instances placed in private subnets
Database placed in private subnets
No public SSH requirement
AWS Systems Manager used for instance management
IAM roles instead of embedded AWS credentials
RDS credentials stored in AWS Secrets Manager
RDS storage encryption
EBS encryption
KMS for monitoring-related encryption
Trivy Terraform security scanning
Terraform state excluded from source control

Security rules are intentionally restricted to required tier-to-tier traffic.

Monitoring

CloudWatch provides infrastructure monitoring for:

ALB availability and errors
ALB latency
Target health
EC2 Auto Scaling CPU utilization
RDS CPU utilization
RDS connections
RDS free storage

SNS is used as the notification mechanism for alarms.

The development environment currently does not configure an alert email address.

Cost Considerations

This project intentionally uses relatively small development instance types:

EC2: t3.micro
RDS: db.t3.micro
RDS storage: 20 GB

However, the architecture includes resources that can generate AWS charges, including:

NAT Gateways
Application Load Balancer
EC2 instances
RDS
Elastic IP addresses
CloudWatch
KMS
SNS
S3

Domain and HTTPS

A custom domain has not yet been configured.

The current ALB configuration uses an HTTP listener.

HTTPS/TLS termination with an ACM certificate and custom domain is therefore a future enhancement.

The architecture is intentionally documented in its current implemented state rather than claiming HTTPS functionality that has not been configured.

Project Status
Completed

Modular Terraform architecture
VPC and subnet architecture
Public and private network tiers
NAT Gateways
Security groups
IAM roles and instance profile
Application Load Balancer
EC2 Auto Scaling Group
RDS PostgreSQL
Secrets Manager integration
CloudWatch monitoring
SNS notification infrastructure
KMS integration
Terraform remote state
Terraform validation
Trivy security scanning
GitHub Actions CI validation
Terraform plan validation

Not Yet Implemented
Custom domain
ACM certificate
HTTPS listener
Production deployment
Production environment
Actual application deployment
Live alert testing

