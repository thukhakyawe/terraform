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

From your repository root:

mkdir -p .github/workflows

Check:

tree .github

You should see:

.github
└── workflows
9.4 Create Terraform CI workflow

Create:

.github/workflows/terraform-ci.yml

Put this in it:

name: Terraform CI


on:
  pull_request:
    paths:
      - "environments/**"
      - "modules/**"
      - ".github/workflows/**"


  push:
    branches:
      - main
    paths:
      - "environments/**"
      - "modules/**"
      - ".github/workflows/**"


permissions:
  contents: read


jobs:
  terraform:
    name: Terraform Validation
    runs-on: ubuntu-latest


    defaults:
      run:
        working-directory: environments/dev


    steps:
      - name: Checkout
        uses: actions/checkout@v4


      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"


      - name: Terraform Format Check
        run: terraform fmt -check -recursive ../..


      - name: Terraform Init
        run: terraform init -input=false


      - name: Terraform Validate
        run: terraform validate
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

Add this step after Terraform validation:

      - name: Terraform Security Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          scan-ref: .
          severity: HIGH,CRITICAL
          exit-code: "1"

Your workflow becomes:

name: Terraform CI


on:
  pull_request:
    paths:
      - "environments/**"
      - "modules/**"
      - ".github/workflows/**"


  push:
    branches:
      - main
    paths:
      - "environments/**"
      - "modules/**"
      - ".github/workflows/**"


permissions:
  contents: read


jobs:
  terraform:
    name: Terraform Validation
    runs-on: ubuntu-latest


    defaults:
      run:
        working-directory: environments/dev


    steps:
      - name: Checkout
        uses: actions/checkout@v4


      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"


      - name: Terraform Format Check
        run: terraform fmt -check -recursive ../..


      - name: Terraform Init
        run: terraform init -input=false


      - name: Terraform Validate
        run: terraform validate


      - name: Terraform Security Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          scan-ref: .
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

terraform fmt -recursive

Then inspect:

git status

You should see your workflow:

?? .github/workflows/terraform-ci.yml
9.10 Commit the first CI version

Before pushing, inspect:

git diff -- .github/workflows/terraform-ci.yml

Then:

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

If it fails at Terraform Init with an AWS credential/backend error, that's expected at this point. 

Then we'll continue with Phase 9B: AWS IAM + GitHub OIDC, where we'll configure secure passwordless authentication between GitHub Actions and AWS.