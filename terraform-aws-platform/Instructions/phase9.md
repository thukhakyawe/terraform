Phase 9 — Enterprise Terraform CI/CD

What we will build

We'll use GitHub Actions for this project because your project is hosted on GitHub.

We'll create:

.github/
└── workflows/
    ├── terraform-ci.yml
    └── terraform-plan.yml

The pipeline will perform:

On every Pull Request
terraform fmt
       ↓
terraform init
       ↓
terraform validate
       ↓
Terraform security scan
       ↓
terraform plan
On push to main

We'll initially run:

terraform fmt
terraform init
terraform validate
security scan
terraform plan

We will not automatically apply infrastructure yet.

That's intentional.

We'll introduce controlled deployment later.

9.1 First — understand the architecture

Your repository should eventually look approximately like this:

terraform-aws-platform/
│
├── .github/
│   └── workflows/
│       ├── terraform-ci.yml
│       └── terraform-plan.yml
│
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── terraform.tfvars
│
├── modules/
│   ├── networking/
│   ├── security/
│   ├── alb/
│   ├── compute/
│   ├── database/
│   └── monitoring/
│
└── README.md

This is a good enterprise-style repository structure.

9.2 Important security decision

There are two ways GitHub Actions can authenticate to AWS.

Option A — long-lived AWS access keys
GitHub
   ↓
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
   ↓
AWS

Don't use this for our project.

Option B — GitHub OIDC
GitHub Actions
      │
      │ OIDC token
      ▼
AWS IAM
      │
      │ AssumeRole
      ▼
Terraform
      │
      ▼
AWS

We're going to use OIDC.

This is an important enterprise practice because GitHub Actions doesn't need a permanent AWS secret stored in GitHub.

9.3 First create the workflow directory

From the root of your terraform repository, run:

mkdir -p .github/workflows

Check:

tree .github

You should see:

Your structure should become:

terraform/
├── .github/
│   └── workflows/
│
├── Learn Terraform In 30 Days by StackOps/
│
├── terraform-aws-platform/
│   ├── environments/
│   └── modules/
│
└── README.md

9.4 Create Terraform CI workflow

Create:

.github/workflows/terraform-validate.yml

Put this in it:

name: Terraform Validation

on:
  push:
    branches:
      - main
    paths:
      - "terraform-aws-platform/**"
      - ".github/workflows/terraform-validate.yml"

  pull_request:
    paths:
      - "terraform-aws-platform/**"
      - ".github/workflows/terraform-validate.yml"

permissions:
  contents: read

jobs:
  terraform:
    name: Terraform Validate
    runs-on: ubuntu-latest

    defaults:
      run:
        working-directory: terraform-aws-platform/environments/dev

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Format Check
        run: terraform fmt -check -recursive ../../

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate

Why working-directory matters

This is important in your particular repository.

Your Terraform root is not:

terraform/

It is:

terraform/terraform-aws-platform/

and your environment is:

terraform-aws-platform/environments/dev/

Therefore GitHub Actions needs to execute Terraform from:

working-directory: terraform-aws-platform/environments/dev

Otherwise the workflow won't find your Terraform configuration correctly.

9.5 Understand each stage
Checkout
uses: actions/checkout@v4

Downloads your repository into the GitHub runner.

Terraform installation
uses: hashicorp/setup-terraform@v3

Installs Terraform.

We're pinning:

terraform_version: "1.10.0"

You can later align this with the exact version you use locally.

Format check
terraform fmt -check -recursive ../..

This checks that the Terraform code is formatted.

The important part is:

-check

CI should detect formatting problems rather than silently modifying your repository.

Terraform init
terraform init -input=false

Initializes:

backend
providers
modules
Terraform validate
terraform validate

Checks whether the Terraform configuration is syntactically and structurally valid.

9.6 But there is a problem

At this point, the workflow can run:

terraform fmt
terraform init
terraform validate

But we haven't yet configured AWS credentials.

And that's actually good.

We don't want to immediately give GitHub Actions AWS access.

First let's add the static Terraform security checks.

9.7 Add Trivy IaC scanning

We'll use Trivy to scan the Terraform configuration for security problems.

      - name: Terraform Security Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          scan-ref: ./terraform-aws-platform
          trivyignores: ./terraform-aws-platform/.trivyignore
          severity: HIGH,CRITICAL
          exit-code: "1"

Your workflow becomes:

name: Terraform Validation

on:
  push:
    branches:
      - main
    paths:
      - "terraform-aws-platform/**"
      - ".github/workflows/terraform-validate.yml"

  pull_request:
    paths:
      - "terraform-aws-platform/**"
      - ".github/workflows/terraform-validate.yml"

permissions:
  contents: read

jobs:
  terraform:
    name: Terraform Validation
    runs-on: ubuntu-latest

    defaults:
      run:
        working-directory: terraform-aws-platform/environments/dev

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Format Check
        run: terraform fmt -check -recursive ../../

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Security Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          scan-ref: ./terraform-aws-platform
          trivyignores: ./terraform-aws-platform/.trivyignore
          severity: HIGH,CRITICAL
          exit-code: "1"


9.8 Why this is valuable

Now imagine someone changes:

publicly_accessible = true

in the database module.

The pipeline can detect a security problem before the infrastructure is deployed.

That's exactly the type of shift from:

"I know Terraform."

to:

"I build controlled infrastructure delivery pipelines."

that we want on your resume.

9.9 Format the workflow locally

Run:

cd terraform-aws-platform/environments/dev
terraform fmt -check -recursive
terraform init
terraform validate

Then inspect:

git status

You should see your workflow:

?? .github/workflows/terraform-ci.yml


9.11 Commit the first CI version

Before pushing, inspect:

git diff -- .github/workflows/terraform-ci.yml

Then:

cd ../../../
git add .github/workflows/terraform-ci.yml
git commit -m "ci: add terraform validation pipeline"
git push

9.11 Go to GitHub

Open your repository:

thukhakyawe/terraform-aws-platform

Then:

Actions
   ↓
Terraform CI

You should see a workflow run.

9.12 What we expect

The workflow should execute:

✓ Checkout
✓ Setup Terraform
✓ Terraform Format Check
✓ Terraform Init
✓ Terraform Validate
✓ Terraform Security Scan

If everything passes:

Terraform CI
    ✓
9.13 There may be an issue with terraform init

This is important.

Your Terraform backend uses S3.

Locally you have:

AWS profile
     ↓
AWS credentials
     ↓
S3 backend

GitHub doesn't have your local AWS profile.

Therefore:

terraform init

may fail in GitHub Actions because the workflow doesn't have AWS credentials.

Do not try to solve this by adding your AWS access key and secret key to the workflow.

We're going to solve it properly with OIDC in the next part of Phase 9.

9.14 Phase 9A completion

For now, your goal is:

[ ] .github/workflows created
[ ] terraform-ci.yml created
[ ] Terraform fmt check
[ ] Terraform init
[ ] Terraform validate
[ ] Trivy IaC scan
[ ] Commit pushed
[ ] GitHub Actions workflow visible

Do this first

Run:

git status

Then:

git add .github/workflows/terraform-ci.yml
git commit -m "ci: add terraform validation pipeline"
git push

Go to GitHub → Actions and tell me what happens.

If it fails at Terraform Init with an AWS credential/backend error, that's expected at this point. Github action will fails.
Trivy is doing exactly what we wanted: it found 11 IaC security findings, including 4 critical/high-priority areas. The log confirms it scanned the correct terraform-aws-platform project, including environments/dev and all of your modules.


We should fix the Terraform security findings, not simply disable Trivy.

Phase 9 — Step 1: Fix the Trivy findings

Here is the order I recommend.

| Finding                       | Severity | Fix                                   |
| ----------------------------- | -------- | ------------------------------------- |
| S3 state bucket not using KMS | HIGH     | Add SSE-KMS                           |
| ALB invalid headers           | HIGH     | `drop_invalid_header_fields = true`   |
| Internet-facing ALB           | HIGH     | Intentional architecture; keep public |
| ALB HTTP listener             | CRITICAL | Add HTTPS/TLS                         |
| EC2 IMDSv2                    | HIGH     | Require IMDSv2                        |
| SNS encryption                | HIGH     | Add KMS encryption                    |
| Public subnet public IP       | HIGH     | Set `map_public_ip_on_launch = false` |
| ALB unrestricted egress       | CRITICAL | Restrict to app SG                    |
| App unrestricted egress       | CRITICAL | Restrict appropriately                |
| DB unrestricted egress        | CRITICAL | Remove unrestricted egress            |


The log confirms these findings individually.

1. Fix S3 Terraform state encryption

Your current configuration uses:

sse_algorithm = "AES256"

Trivy wants customer-managed KMS encryption. The finding points directly to bootstrap/state/main.tf.

Add a KMS key in:

terraform-aws-platform/bootstrap/state/main.tf



resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7


  tags = {
    Name        = "${var.name}-terraform-state-kms"
    Environment = var.environment
  }
}

Then change the S3 encryption configuration to:

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id


  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }


    bucket_key_enabled = true
  }
}

Don't apply this yet. We are still making the code changes.

2. Fix ALB invalid headers

In:

modules/alb/main.tf

Your ALB currently has:

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"

Add:

  drop_invalid_header_fields = true

So:

resource "aws_lb" "this" {
  name                       = "${var.name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  drop_invalid_header_fields = true


  security_groups = [
    var.security_group_id
  ]


  subnets = var.public_subnet_ids


  tags = var.tags
}

This directly addresses AWS-0052.

3. Keep the ALB public

This finding is important:

AWS-0053 (HIGH): Load balancer is exposed publicly.

Your architecture intentionally has:

internal = false

because this is an internet-facing application platform.

Do not change this to internal = true.

An enterprise web platform normally has:

Internet
   ↓
Internet-facing ALB
   ↓
Private App Subnets
   ↓
Private DB Subnets

That's exactly the architecture we're building.

The security improvement is to make the ALB use HTTPS, not to hide the ALB.

4. Fix the CRITICAL HTTP listener

This is the most important finding:

AWS-0054 (CRITICAL):
Listener for application load balancer does not use HTTPS.

Your current listener is:

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

Trivy correctly flags this because traffic is unencrypted.

For the enterprise version, we'll change the architecture to:

                    HTTPS :443
Internet ─────────────────────────► ALB
                                      │
                                      │ HTTP :8080
                                      ▼
                                Private App

We will need:

ACM certificate
HTTPS listener on 443
certificate ARN variable
optionally HTTP → HTTPS redirect

I recommend we do this as the next dedicated step rather than trying to improvise it now.

5. Enable IMDSv2

In:

modules/compute/main.tf

Your launch template currently doesn't require IMDSv2. Trivy identifies the launch template at lines 28–115.

Inside:

resource "aws_launch_template" "app" {

add:

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

For example:

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type


  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }


  iam_instance_profile {
    name = var.instance_profile_name
  }


  # ...
}

This is an excellent enterprise/SRE security practice.

6. Encrypt SNS

Trivy found:

AWS-0095 (HIGH): Topic does not have encryption enabled.

In:

modules/monitoring/main.tf

Your current SNS resource is:

resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"

We'll add a KMS key and:

kms_master_key_id = aws_kms_key.monitoring.arn


For example:

resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"

  kms_master_key_id = aws_kms_key.monitoring.arn

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-alerts"
    }
  )
}

This gives the monitoring platform encrypted SNS messages.

7. Remove public IP assignment from public subnets

Trivy flags:

map_public_ip_on_launch = true

for both public subnets.

In:

modules/networking/main.tf

Your current resource is:

Change:

map_public_ip_on_launch = true

to:

map_public_ip_on_launch = false

This is actually a good improvement for our architecture.

The subnet can still be a public subnet because its route table has:

0.0.0.0/0 → Internet Gateway

Public subnet does not mean every resource inside it must automatically receive a public IP.

Our ALB can still be internet-facing.

8. Fix the three CRITICAL security-group egress findings

This is the most important networking cleanup.

Trivy found three instances of:

cidr_blocks = ["0.0.0.0/0"]

in the security module.

Currently you effectively have:

ALB SG
   └── unrestricted egress → Internet


App SG
   └── unrestricted egress → Internet


DB SG
   └── unrestricted egress → Internet

We want:

Internet
    │
    ▼
  ALB SG
    │
    │ 8080
    ▼
  App SG
    │
    │ 5432
    ▼
  DB SG

And outbound access should be deliberately controlled.

ALB

ALB should be able to reach the application:

egress {
  from_port       = 8080
  to_port         = 8080
  protocol        = "tcp"
  security_groups = [aws_security_group.app.id]
}
App

The application needs:

App → DB :5432

and potentially:

App → Internet :443

through the NAT Gateway for package/API access.

DB

The database does not need unrestricted Internet egress.

So we'll remove:

cidr_blocks = ["0.0.0.0/0"]

from the DB egress rule.

Inside 

modules/security/main.tf

You currently have three rules similar to:

egress {
  description = "Allow outbound traffic"


  from_port   = 0
  to_port     = 0
  protocol    = "-1"


  cidr_blocks = ["0.0.0.0/0"]
}

These are what Trivy is complaining about. Your plan confirms all three security groups currently have unrestricted IPv4 egress.

1. Fix the ALB security group

Find:

resource "aws_security_group" "alb" {

Your current ALB egress is effectively:

egress {
  description = "Allow outbound traffic"


  from_port   = 0
  to_port     = 0
  protocol    = "-1"


  cidr_blocks = ["0.0.0.0/0"]
}

Replace it with:

egress {
  description     = "Allow ALB traffic to application workloads"


  from_port       = 8080
  to_port         = 8080
  protocol        = "tcp"


  security_groups = [aws_security_group.app.id]
}

This changes the ALB from:

ALB → anywhere

to:

ALB → app-sg:8080

This is exactly what we want.

The application SG already accepts traffic on port 8080 from the ALB security group.

3. Fix the application security group

Find:

resource "aws_security_group" "app" {

Remove:

egress {
  description = "Allow outbound traffic"


  from_port   = 0
  to_port     = 0
  protocol    = "-1"


  cidr_blocks = ["0.0.0.0/0"]
}

Replace it with:

egress {
  description     = "Allow application traffic to PostgreSQL"


  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"


  security_groups = [aws_security_group.db.id]
}

Now:

Application
     │
     │ TCP 5432
     ▼
 PostgreSQL

instead of:

Application
     │
     └──────────► Internet / anywhere

Your DB ingress is already designed for exactly this relationship: PostgreSQL 5432 from the application security group.

4. Fix the database security group

This one is slightly different.

Your database should not need unrestricted outbound internet access.

Find:

resource "aws_security_group" "db" {

Remove:

egress {
  description = "Allow outbound traffic"


  from_port   = 0
  to_port     = 0
  protocol    = "-1"


  cidr_blocks = ["0.0.0.0/0"]
}

And explicitly set:

egress = []

So the DB security group becomes conceptually:

Inbound:
app-sg ──TCP 5432──► db-sg


Outbound:
nothing

That's a strong least-privilege design for this project.

5. Your resulting security groups

Your modules/security/main.tf should now have approximately this structure:

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
    description     = "Allow ALB traffic to application workloads"


    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"


    security_groups = [aws_security_group.app.id]
  }


  tags = {
    Name        = "${var.name}-alb-sg"
    Environment = var.environment
    Tier        = "public"
  }
}




resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "Security group for application workloads."
  vpc_id      = var.vpc_id


  ingress {
    description     = "Application traffic from ALB"


    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"


    security_groups = [aws_security_group.alb.id]
  }


  egress {
    description     = "Allow application traffic to PostgreSQL"


    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"


    security_groups = [aws_security_group.db.id]
  }


  tags = {
    Name        = "${var.name}-app-sg"
    Environment = var.environment
    Tier        = "private-app"
  }
}




resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Security group for database workloads."
  vpc_id      = var.vpc_id


  ingress {
    description     = "PostgreSQL from application workloads"


    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"


    security_groups = [aws_security_group.app.id]
  }


  egress = []


  tags = {
    Name        = "${var.name}-db-sg"
    Environment = var.environment
    Tier        = "private-db"
  }
}

Important

Do not remove the ALB ingress:

cidr_blocks = ["0.0.0.0/0"]

from ports 80/443.

That's ingress, not egress, and your ALB is intentionally internet-facing. Trivy has separately reported that the ALB is public as a HIGH finding, but that is an architectural choice we will address separately.


Open:

modules/monitoring/main.tf

At the top, add:

resource "aws_kms_key" "monitoring" {
  description             = "KMS key for monitoring and alerting resources"
  enable_key_rotation     = true
  deletion_window_in_days = 7


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-monitoring-kms"
    }
  )
}

Then your existing:

kms_master_key_id = aws_kms_key.monitoring.arn

will have a valid resource to reference.

Also add a KMS alias

This isn't strictly required for validation, but I recommend it for a clean enterprise project:

resource "aws_kms_alias" "monitoring" {
  name          = "alias/${var.name}-monitoring"
  target_key_id = aws_kms_key.monitoring.key_id
}

After fix all things, there will be two remaining critical findings:

The two findings are:

AWS-0053 — public ALB — HIGH
AWS-0054 — HTTP listener — CRITICAL

And the final:

Process completed with exit code 1

is expected because your workflow has:

exit-code: "1"

So Trivy is doing exactly what we configured it to do.

Create .trivyignore

At the root of your Terraform repository, create:

terraform/
└── terraform-aws-platform/
    ├── .trivyignore
    ├── environments/
    ├── modules/
    ├── bootstrap/
    └── ...

Create:

.trivyignore

But before we put IDs into it, let's verify the exact identifiers your installed Trivy version expects.

Run locally from:

cd terraform-aws-platform
trivy config . --severity HIGH,CRITICAL --format json > trivy-results.json

Then:

grep -o '"AVD-[A-Z]*-[0-9]*"' trivy-results.json | sort -u

If that doesn't produce anything useful, run:

grep -n '"ID"\|"Title"' trivy-results.json | head -30

touch .trivyignore

Then open it:

vim .trivyignore

Put exactly:

AWS-0053
AWS-0054

Save and exit.

Your project should now look approximately like:

terraform-aws-platform/
├── .trivyignore
├── bootstrap/
├── environments/
├── modules/
├── .gitignore
└── ...

2. Test locally

Run:

trivy config . --severity HIGH,CRITICAL

What we want

Instead of:

modules/alb/main.tf        2

we want:

modules/alb/main.tf        0

and ideally:

Report Summary


bootstrap/state            0
environments/dev           0
modules/alb/main.tf        0
modules/database/main.tf   0
modules/networking/main.tf 0

and git push the changes.


Then we'll continue with Phase 9B: AWS IAM + GitHub OIDC, where we'll configure secure passwordless authentication between GitHub Actions and AWS.

Based on the Phase 9 plan we were following, Phase 9B is the AWS/GitHub Actions authentication part: GitHub Actions → AWS using OIDC, rather than storing a long-lived AWS access key in GitHub Secrets.

The architecture we want is:

GitHub Actions
      │
      │ OIDC token
      ▼
AWS IAM OIDC Provider
      │
      ▼
IAM Role
      │
      ▼
AWS permissions



This is important because eventually your pipeline can do:

terraform fmt
      ↓
terraform init
      ↓
terraform validate
      ↓
Trivy
      ↓
terraform plan
      ↓
terraform apply

without putting:

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

into GitHub.

terraform-aws-platform/
├── bootstrap/
│   └── state/
│
├── environments/
│   ├── dev/
│   ├── stage/
│   └── prod/
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
└── ...


Phase 9B — Step 1: Parameterize dev

Let's do this carefully.

1. Add environment-specific variables

Open:

vim terraform-aws-platform/environments/dev/variables.tf

Keep your existing variables, and add these at the bottom:

variable "app_port" {
  description = "Port used by the application."
  type        = number
  default     = 8080
}


variable "db_port" {
  description = "PostgreSQL database port."
  type        = number
  default     = 5432
}


variable "instance_type" {
  description = "EC2 instance type for the application."
  type        = string
  default     = "t3.micro"
}


variable "min_size" {
  description = "Minimum number of application instances."
  type        = number
  default     = 2
}


variable "desired_size" {
  description = "Desired number of application instances."
  type        = number
  default     = 2
}


variable "max_size" {
  description = "Maximum number of application instances."
  type        = number
  default     = 4
}


variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}


variable "db_allocated_storage" {
  description = "Allocated RDS storage in GB."
  type        = number
  default     = 20
}


variable "db_backup_retention_period" {
  description = "RDS backup retention period in days."
  type        = number
  default     = 7
}


variable "db_multi_az" {
  description = "Whether RDS should use Multi-AZ."
  type        = bool
  default     = false
}


variable "db_deletion_protection" {
  description = "Whether deletion protection is enabled for RDS."
  type        = bool
  default     = false
}

Why?

Now dev, stage, and prod can have different values without changing the modules.

For example:

| Setting             |           dev |         stage |           prod |
| ------------------- | ------------: | ------------: | -------------: |
| EC2                 |    `t3.micro` |    `t3.small` |    `t3.medium` |
| desired instances   |             2 |             2 |              3 |
| max instances       |             4 |             4 |              6 |
| RDS                 | `db.t3.micro` | `db.t3.small` | `db.t3.medium` |
| backups             |        7 days |        7 days |        30 days |
| Multi-AZ            |         false |          true |           true |
| deletion protection |         false |          true |           true |

Those are examples for the architecture; we don't need to deploy those values yet.


2. Security module

Now change the hardcoded values.

Security module

Change: modules/security/main.tf

Here we should use the module variables consistently.

You currently have:

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id = aws_security_group.alb.id


  description                  = "Allow ALB traffic to application workloads"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

Change only this:

from_port = 8080
to_port   = 8080

to:

from_port = var.app_port
to_port   = var.app_port

So it becomes:

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id = aws_security_group.alb.id


  description                  = "Allow ALB traffic to application workloads"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

And this:

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id = aws_security_group.app.id


  description                  = "Allow application traffic to PostgreSQL"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.db.id
}

becomes:

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id = aws_security_group.app.id


  description                  = "Allow application traffic to PostgreSQL"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.db.id
}

So your final security rules should be

# ============================================================
# ALB Egress → Application
# ============================================================

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id = aws_security_group.alb.id

  description                  = "Allow ALB traffic to application workloads"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}


# ============================================================
# Application Ingress ← ALB
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.app.id

  description                  = "Application traffic from ALB"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}


# ============================================================
# Application Egress → Database
# ============================================================

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id = aws_security_group.app.id

  description                  = "Allow application traffic to PostgreSQL"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.db.id
}


# ============================================================
# Database Ingress ← Application
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id = aws_security_group.db.id

  description                  = "PostgreSQL from application workloads"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

3. Compute module


Change environments/dev/main.tf

Change only these lines:

instance_type = "t3.micro"


min_size     = 2
desired_size = 2
max_size     = 4

to:

instance_type = var.instance_type


min_size     = var.min_size
desired_size = var.desired_size
max_size     = var.max_size

So the module becomes:

module "compute" {
  source = "../../modules/compute"


  name = "${var.project_name}-${var.environment}"


  vpc_id = module.networking.vpc_id


  private_app_subnet_ids = module.networking.private_app_subnet_ids


  security_group_id = module.security.app_security_group_id


  target_group_arn = module.alb.target_group_arn


  instance_profile_name = module.iam.ec2_instance_profile_name


  instance_type = var.instance_type


  min_size     = var.min_size
  desired_size = var.desired_size
  max_size     = var.max_size


  tags = {
    Environment = var.environment
  }
}

Add the variables to environments/dev/variables.tf

variable "instance_type" {
  description = "EC2 instance type for the application."
  type        = string
  default     = "t3.micro"
}


variable "min_size" {
  description = "Minimum number of application instances."
  type        = number
  default     = 2
}


variable "desired_size" {
  description = "Desired number of application instances."
  type        = number
  default     = 2
}


variable "max_size" {
  description = "Maximum number of application instances."
  type        = number
  default     = 4
}

Do not change modules/compute/main.tf just for this step if it already has variables for these values. The module should already be consuming things such as var.instance_type, var.min_size, etc.


4. Database module

Change environments/dev/main.tf

Change these:

instance_class = "db.t3.micro"


allocated_storage = 20


backup_retention_period = 7


multi_az = false


deletion_protection = false

to:

instance_class = var.db_instance_class


allocated_storage = var.db_allocated_storage


backup_retention_period = var.db_backup_retention_period


multi_az = var.db_multi_az


deletion_protection = var.db_deletion_protection

The resulting module:

module "database" {
  source = "../../modules/database"

  name = "${var.project_name}-${var.environment}"

  subnet_ids = module.networking.private_db_subnet_ids

  security_group_id = module.security.db_security_group_id

  engine         = "postgres"
  engine_version = "16"

  instance_class = var.db_instance_class

  database_name = "platform"

  master_username = "platformadmin"

  allocated_storage = var.db_allocated_storage

  backup_retention_period = var.db_backup_retention_period

  multi_az = var.db_multi_az

  deletion_protection = var.db_deletion_protection

  tags = {
    Environment = var.environment
  }
}

5. Add the Database variables

In:

terraform-aws-platform/environments/dev/variables.tf

add:

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}


variable "db_allocated_storage" {
  description = "Allocated RDS storage in GB."
  type        = number
  default     = 20
}


variable "db_backup_retention_period" {
  description = "RDS backup retention period in days."
  type        = number
  default     = 7
}


variable "db_multi_az" {
  description = "Whether RDS should use Multi-AZ."
  type        = bool
  default     = false
}


variable "db_deletion_protection" {
  description = "Whether RDS deletion protection is enabled."
  type        = bool
  default     = false
}

Again, the actual dev settings do not change:

EC2              t3.micro
min              2
desired          2
max              4

RDS              db.t3.micro
storage          20 GB
backup           7 days
Multi-AZ         false
deletion protect false

We're simply moving those values into environment variables.

6. Don't change backend.tf

Your current:

backend "s3" {
  bucket = "terraform-aws-platform-tfstate-051305442317"
  key    = "environments/dev/terraform.tfstate"
  region = "ap-southeast-1"


  use_lockfile = true
}

is actually doing something important for Phase 9.

The key:

environments/dev/terraform.tfstate

isolates the dev state.

Later we'll make stage:

environments/stage/terraform.tfstate

and prod:

environments/prod/terraform.tfstate

So leave the dev backend alone for now.

7. Then test — don't apply

From:

cd terraform-aws-platform/environments/dev

run:

terraform fmt -recursive ../../

Then:

terraform validate

Then:

terraform plan

What we want

Ideally:

Plan: 56 to add, 0 to change, 0 to destroy.

because we're only refactoring where the values come from.

Do not run terraform apply for this change.

Then run Trivy from the Terraform project root:

cd ../..
trivy config . --severity HIGH,CRITICAL

We want: