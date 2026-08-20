Phase 10 — First deployment

Before we apply the infrastructure, let's do one final safety check because this will create 56 AWS resources and will incur AWS costs.

From:

cd terraform-aws-platform/environments/dev

run:

terraform plan

Confirm the summary is still:

Plan: 56 to add, 0 to change, 0 to destroy.

Then check the plan for anything unexpected:

We can now apply

Because this is your first deployment, I recommend saving the exact plan first rather than immediately running a fresh terraform apply.

Run:

terraform plan -out=tfplan

Then verify:

terraform show -no-color tfplan | grep -E "Plan:|will be created|will be destroyed|will be updated"

You should see the same:

Plan: 56 to add, 0 to change, 0 to destroy.

Then, and only then, apply that exact saved plan:

terraform apply tfplan

Terraform will ask for confirmation.

Enter:

yes

Do not use this yet

Don't run:

terraform apply

The saved-plan approach is better here because Terraform explicitly warned:

Terraform can't guarantee to take exactly these actions if you run terraform apply now.

Using:

terraform plan -out=tfplan
terraform show -no-color tfplan | grep -E "Plan:|will be created|will be destroyed|will be updated"
terraform apply tfplan

Step 10.1 — Verify the project is clean

From the repository root:

cd terraform-aws-platform

Run:

terraform -chdir=environments/dev validate

Then:

terraform -chdir=environments/dev fmt -check -recursive ../../

Then:

trivy config . --severity HIGH,CRITICAL

We want:

bootstrap/state            0
environments/dev           0
modules/alb                0
modules/database           0
modules/networking         0

Step 10.2 — Check Git
git status

Make sure you do not commit:

.terraform/
*.tfstate
*.tfstate.*
tfplan
*.tfplan

Check specifically:

git ls-files | grep -E '(\.tfstate|tfplan|\.terraform/)'

Ideally, this returns nothing.

Step 10.3 — Verify the CI workflow

Your workflow should continue to use:

defaults:
  run:
    working-directory: terraform-aws-platform/environments/dev

and Trivy should explicitly scan:

scan-ref: ./terraform-aws-platform

That distinction is important because your repository contains multiple Terraform projects, while terraform-aws-platform is one project within the repository.

Step 10.4 — Commit only the project changes

After the checks pass:

git add terraform-aws-platform .github/workflows/terraform-validate.yml

Review:

git diff --cached --stat

Then:

git diff --cached

Do not commit yet if you see credentials, state files, tfplan, or .terraform directories.

If everything looks correct:

git commit -m "Complete Terraform platform CI validation"

Then push:

git push

GitHub Actions should then run automatically.

