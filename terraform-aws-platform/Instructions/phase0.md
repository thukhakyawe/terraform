PHASE 0 — Prerequisites

Before writing Terraform, make sure your machine has:

Required
Git
AWS CLI
Terraform
VS Code
Later
TFLint
Checkov
pre-commit
Docker

You don't need Kubernetes for this project.

0.1 Check Git

Run:

git --version

You should get something like:

git version 2.x.x
0.2 Check AWS CLI
aws --version

Then:

aws sts get-caller-identity

You should get something similar to:

{
    "UserId": "...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/..."
}

Important

Never put AWS access keys in GitHub.

We will make sure:

.aws/
*.tfvars
*.tfstate
*.tfstate.*

are protected by .gitignore.

0.3 Check Terraform
terraform version

For this project, use a modern Terraform release. We'll use:

terraform {
  required_version = ">= 1.10.0"
}

That gives us access to modern Terraform functionality, including S3 state locking.

0.4 Configure AWS

If you already have AWS CLI configured:

aws sts get-caller-identity

and it works, don't change anything.

If not:

aws configure

You'll enter:

AWS Access Key ID
AWS Secret Access Key
Default region
Output format

For your project, I'd use a single region initially, for example:

ap-southeast-1

Then we can make the region configurable later.

---