Phase 2 — Remote Terraform State
2.1 What we are building

Right now, Terraform is effectively using local state:

Your laptop
│
├── Terraform code
└── terraform.tfstate

We want:

                    AWS
                     │
             ┌───────▼────────┐
             │   S3 Bucket     │
             │                 │
             │ Terraform State │
             │ Versioning      │
             │ Encryption      │
             │ Locking         │
             └───────▲────────┘
                     │
                     │
Developer ───────────┤
                     │
GitLab CI/CD ────────┘

Eventually:

                    GitLab
                       │
                       ▼
                 Terraform Plan
                       │
                       ▼
                 Terraform Apply
                       │
                       ▼
                S3 Remote State
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
        Dev          Stage         Prod
       State         State         State

This gives us:

centralized state
state locking
state versioning
encryption
safer team collaboration
CI/CD compatibility
isolated state per environment
2.2 Important concept: Bootstrap

There is a small problem.

Terraform needs the S3 bucket before Terraform can use that S3 bucket as its backend.

So we cannot simply say:

"Terraform, create the S3 bucket where your own state will live."

We need a bootstrap layer.

Think of it like this:

Step 1


Bootstrap Terraform
       │
       ▼
Create S3 state bucket




Step 2


Application Terraform
       │
       ▼
Use S3 bucket
       │
       ▼
Store Terraform state

We'll keep the bootstrap infrastructure separate.

2.3 Repository structure after Phase 2

Your repository should become:

terraform-aws-platform/
│
├── bootstrap/
│   └── state/
│       ├── versions.tf
│       ├── variables.tf
│       ├── main.tf
│       └── outputs.tf
│
├── environments/
│   ├── dev/
│   │   ├── versions.tf
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   ├── stage/
│   └── prod/
│
├── modules/
│   ├── networking/
│   ├── security/
│   ├── iam/
│   ├── compute/
│   ├── database/
│   └── monitoring/
│
├── architecture/
├── docs/
├── scripts/
├── tests/
│
├── .gitignore
├── .editorconfig
├── .gitlab-ci.yml
├── .pre-commit-config.yaml
└── README.md
2.4 Create the bootstrap directory

From your repository root:

mkdir -p bootstrap/state

Verify:

find bootstrap -maxdepth 2 -type f

It won't show files yet.

2.5 Create versions.tf

Create:

bootstrap/state/versions.tf

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


provider "aws" {
  region = var.aws_region


  default_tags {
    tags = {
      Project   = "terraform-aws-platform"
      Component = "terraform-state"
      ManagedBy = "Terraform"
    }
  }
}
Why?

This defines:

Terraform version
       +
AWS provider
       +
AWS region
       +
default tags

We want our bootstrap infrastructure managed by Terraform too.

2.6 Create variables.tf

Create:

bootstrap/state/variables.tf

Put:

variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created."
  type        = string
  default     = "ap-southeast-1"
}


variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
  default     = "terraform-aws-platform"
}
2.7 Create main.tf

Now the important part.

Create:

bootstrap/state/main.tf

Start with:

data "aws_caller_identity" "current" {}


data "aws_region" "current" {}

These allow Terraform to know:

AWS Account ID
AWS Region

We'll use the account ID to make the S3 bucket name unique.

2.8 Create the S3 bucket

Add:

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"
}

The resulting bucket might look like:

terraform-aws-platform-tfstate-123456789012

S3 bucket names must be globally unique, so using the AWS account ID helps.

2.9 Block public access

Immediately add:

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id


  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

This is important because Terraform state can contain sensitive infrastructure information.

We don't want this bucket publicly accessible.

2.10 Enable versioning

Add:

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id


  versioning_configuration {
    status = "Enabled"
  }
}

Why?

Suppose:

Version 1
Version 2
Version 3

and something accidentally damages the current state.

S3 versioning allows us to retain previous versions.

For infrastructure state, this is extremely useful for recovery and investigation.

2.11 Enable encryption

Add:

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id


  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

This uses:

SSE-S3

for server-side encryption.

For this portfolio project, that's a reasonable starting point.

Later, when we build the security layer, we can discuss when a customer-managed KMS key makes sense.

2.12 Add lifecycle protection

This is an important Terraform practice.

Add:

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"


  lifecycle {
    prevent_destroy = true
  }
}

Now the full bucket resource becomes:

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"


  lifecycle {
    prevent_destroy = true
  }
}
Why?

Imagine someone runs:

terraform destroy

We don't want the command to accidentally delete the bucket containing the Terraform state.

This demonstrates an important infrastructure principle:

Protect critical infrastructure from accidental destruction.

2.13 Create outputs

Create:

bootstrap/state/outputs.tf

Put:

output "terraform_state_bucket_name" {
  description = "Name of the S3 bucket used for Terraform state."
  value       = aws_s3_bucket.terraform_state.bucket
}


output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

These outputs make it easy to retrieve the backend bucket information.

2.14 Your bootstrap files

At this point:

bootstrap/state/
├── versions.tf
├── variables.tf
├── main.tf
└── outputs.tf

And main.tf should contain approximately:

data "aws_caller_identity" "current" {}


data "aws_region" "current" {}


resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"


  lifecycle {
    prevent_destroy = true
  }
}


resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id


  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id


  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id


  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
2.15 Initialize bootstrap Terraform

Now:

cd bootstrap/state

Run:

terraform init

Then:

terraform fmt

Then:

terraform validate

You should get:

Success! The configuration is valid.
2.16 Run Terraform Plan

Now:

terraform plan

Terraform should show resources similar to:

aws_s3_bucket.terraform_state
aws_s3_bucket_public_access_block.terraform_state
aws_s3_bucket_versioning.terraform_state
aws_s3_bucket_server_side_encryption_configuration.terraform_state

You should see something like:

Plan: 4 to add, 0 to change, 0 to destroy.

The exact count can vary with provider behavior, so don't worry if Terraform represents some resources differently.

Important

Do not run terraform apply yet if your AWS account has restrictions or if you want me to review the plan first.

For this phase, I'd like you to inspect the plan.

2.17 If the plan looks correct

Run:

terraform apply

Terraform will ask:

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.


  Enter a value:

Type:

yes
2.18 Verify the bucket

Run:

terraform output

You should see something like:

terraform_state_bucket_arn = "arn:aws:s3:::terraform-aws-platform-tfstate-123456789012"
terraform_state_bucket_name = "terraform-aws-platform-tfstate-123456789012"

Then:

aws s3 ls

You should see your bucket.

You can also check:

aws s3api get-bucket-versioning \
  --bucket YOUR_BUCKET_NAME

Expected:

{
    "Status": "Enabled"
}

Check encryption:

aws s3api get-bucket-encryption \
  --bucket YOUR_BUCKET_NAME
2.19 Now configure the Dev backend

This is the critical transition.

Create:

environments/dev/backend.tf

Use:

terraform {
  backend "s3" {
    bucket = "YOUR_BUCKET_NAME"
    key    = "environments/dev/terraform.tfstate"
    region = "ap-southeast-1"


    use_lockfile = true
  }
}

Replace:

YOUR_BUCKET_NAME

with the actual bucket name created by Terraform.

For example:

terraform {
  backend "s3" {
    bucket = "terraform-aws-platform-tfstate-123456789012"
    key    = "environments/dev/terraform.tfstate"
    region = "ap-southeast-1"


    use_lockfile = true
  }
}
Why the key matters

This gives us:

S3 bucket
│
└── environments/
    ├── dev/
    │   └── terraform.tfstate
    │
    ├── stage/
    │   └── terraform.tfstate
    │
    └── prod/
        └── terraform.tfstate

This keeps environments isolated.

2.20 Reinitialize Dev Terraform

Go to:

cd ../../environments/dev

Then:

terraform init

Terraform should detect that the backend configuration has changed.

If Terraform asks whether you want to migrate existing state, you'll see a message about moving state to the new backend.

Because your Phase 1 configuration has essentially no infrastructure state yet, the migration should be straightforward.

If asked:

Do you want to copy existing state to the new backend?

answer:

yes
2.21 Verify remote state

Run:

terraform plan

Then:

aws s3 ls s3://YOUR_BUCKET_NAME/environments/dev/

You should eventually see:

terraform.tfstate

That's the key moment.

Your Terraform state is now:

Developer
    │
    ▼
Terraform
    │
    ▼
S3
    │
    └── environments/dev/terraform.tfstate

rather than:

Developer
    │
    ▼
terraform.tfstate
2.22 Check your local directory

From:

environments/dev

you should not treat:

terraform.tfstate

as your source of truth anymore.

The remote backend is now authoritative.

2.23 Security verification

Run:

aws s3api get-public-access-block \
  --bucket YOUR_BUCKET_NAME

You want:

{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
}

Also verify versioning:

aws s3api get-bucket-versioning \
  --bucket YOUR_BUCKET_NAME

And encryption:

aws s3api get-bucket-encryption \
  --bucket YOUR_BUCKET_NAME
2.24 Important security observation

Terraform state can contain more information than people expect.

It may include:

resource IDs
network information
configuration
database metadata
resource attributes

Therefore:

Terraform state should be treated as sensitive infrastructure data.

This is one of the reasons we're implementing:

private S3
encryption
versioning
restricted IAM
state locking
2.25 Update .gitignore

Make sure your root .gitignore contains:

.terraform/
*.tfstate
*.tfstate.*
*.tfplan

But do not ignore:

.terraform.lock.hcl

We want the provider lock file committed.

2.26 Git verification

From repository root:

cd ../..

Run:

git status

You should not see:

terraform.tfstate
.terraform/

You should see your source files.

Then:

git diff

Review the changes.

Then:

git add bootstrap/ environments/dev/ .gitignore

Commit:

git commit -m "feat(terraform): configure remote state backend"

Push:

git push origin main
2.27 Phase 2 architecture

At the end of this phase, your architecture is:

                         GitHub
                           │
                           │ Terraform code
                           ▼
                    ┌──────────────┐
                    │ Developer /  │
                    │ GitLab CI/CD │
                    └──────┬───────┘
                           │
                           │ Terraform
                           ▼
                 ┌────────────────────┐
                 │    AWS S3          │
                 │                    │
                 │ Terraform State    │
                 │                    │
                 │ Encryption         │
                 │ Versioning         │
                 │ State Locking      │
                 └────────────────────┘

Later we'll add:

S3 State
   │
   ├── dev
   ├── stage
   └── prod
2.28 What you can say in an interview

After completing this phase, you should be able to explain:

Why remote state?

"I moved Terraform state from local storage to an encrypted, versioned S3 backend so infrastructure state can be safely shared across engineers and CI/CD."

Why separate state by environment?

"I use separate backend keys for dev, stage, and production to isolate state and reduce the risk of one environment affecting another."

Why versioning?

"S3 versioning provides recovery and auditability if the state is accidentally modified or corrupted."

Why locking?

"State locking prevents concurrent Terraform operations from modifying the same state simultaneously."

Why bootstrap?

"The backend infrastructure has to exist before Terraform can use it as its own backend, so I separate backend provisioning into a bootstrap layer."

Those are much stronger interview answers than simply saying:

"I know Terraform."

Phase 2 — Definition of Done

Don't move to Phase 3 until these are true:

[ ] bootstrap/state created
[ ] S3 state bucket created
[ ] Public access blocked
[ ] S3 encryption enabled
[ ] S3 versioning enabled
[ ] State locking configured
[ ] Dev backend configured
[ ] Dev Terraform initialized successfully
[ ] Dev state stored remotely
[ ] AWS verification completed
[ ] .gitignore verified
[ ] .terraform/ not committed
[ ] terraform.tfstate not committed
[ ] Git commit created
[ ] GitHub push completed
Your immediate next action

Do not jump ahead to networking yet.

Work through:

2.1 → 2.26 in order.

If you encounter an error during terraform init, terraform plan, or terraform apply, paste the exact error here. Don't try random fixes—we'll troubleshoot it together.

Once Phase 2 is working, we'll move to Phase 3: Enterprise Networking Module, where we'll build the VPC, public/private subnets, routing, NAT, and the network architecture that will support ALB → EC2 → RDS.