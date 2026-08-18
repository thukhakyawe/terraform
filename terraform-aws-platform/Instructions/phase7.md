Phase 7 — RDS Database Layer

Good. Phase 7 will add the persistent database tier to our platform.

We will keep the same approach as the previous phases:

Build → validate → plan → review → commit. Do not apply yet.

Our architecture will now become:

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
                  ┌─────────┴─────────┐
                  ▼                   ▼
             EC2 / ASG           EC2 / ASG
             Private App         Private App
                  │                   │
                  └─────────┬─────────┘
                            │
                       TCP :5432
                            │
                            ▼
                    ┌───────────────┐
                    │ PostgreSQL RDS│
                    │ Private DB    │
                    │ Subnets       │
                    └───────────────┘

The important security principle is:

Internet → ALB → Application → Database

There should be no direct Internet access to RDS.

7.1 What we will build

Phase 7 will create a new:

modules/database/
├── versions.tf
├── variables.tf
├── main.tf
└── outputs.tf

It will contain:

RDS PostgreSQL
DB subnet group
private DB subnets
database security-group integration
encryption at rest
automated backups
deletion protection configuration
CloudWatch log exports
Secrets Manager-compatible credentials
environment-specific configuration

We'll initially use a small database configuration suitable for a development environment.

7.2 Important design decision: credentials

We will not do this:

password = "MyPassword123"

and we definitely won't put a real password into:

terraform.tfvars

or GitHub.

Instead, we'll use AWS Secrets Manager.

The target architecture is:

                 AWS Secrets Manager
                         │
                         │ credentials
                         ▼
                   PostgreSQL RDS
                         ▲
                         │
                    App / EC2

This gives you a much stronger enterprise example for your GitHub project.

7.3 Create the database module

From the repository root:

mkdir -p modules/database

Check:

tree modules

You should now have:

modules/
├── alb/
├── compute/
├── database/
├── iam/
├── networking/
└── security/
7.4 versions.tf

Create:

modules/database/versions.tf

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
7.5 Database variables

Create:

modules/database/variables.tf

Use:

variable "name" {
  description = "Name prefix for database resources."
  type        = string
}


variable "subnet_ids" {
  description = "Private database subnet IDs."
  type        = list(string)
}


variable "security_group_id" {
  description = "Security group attached to the RDS instance."
  type        = string
}


variable "engine" {
  description = "Database engine."
  type        = string
  default     = "postgres"
}


variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16"
}


variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}


variable "database_name" {
  description = "Initial database name."
  type        = string
  default     = "platform"
}


variable "master_username" {
  description = "Master database username."
  type        = string
  default     = "platformadmin"
}


variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}


variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
  default     = 7
}


variable "multi_az" {
  description = "Whether to deploy the RDS instance in Multi-AZ mode."
  type        = bool
  default     = false
}


variable "deletion_protection" {
  description = "Protect the database from accidental deletion."
  type        = bool
  default     = false
}


variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
7.6 Create the DB subnet group

Open:

modules/database/main.tf

Start with:

resource "aws_db_subnet_group" "this" {
  name = "${var.name}-db-subnet"


  subnet_ids = var.subnet_ids


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-db-subnet"
      Tier = "private-db"
    }
  )
}

This tells RDS:

Only use these private database subnets.

We already created:

10.10.21.0/24
10.10.22.0/24

in Phase 3.

So the database stays in the DB tier.

7.7 Create the Secrets Manager secret

Now add:

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}/database"
  description             = "Database credentials for ${var.name}"
  recovery_window_in_days = 0


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-database-secret"
    }
  )
}
Why recovery_window_in_days = 0?

This is a development environment.

If we later destroy the development environment, we don't want a deleted secret sitting around for 30 days and potentially complicating recreation.

For a real production environment, I would normally use a recovery window rather than immediate deletion.

That's an important distinction to understand for interviews.

7.8 Generate a password

Add:

resource "random_password" "db" {
  length  = 32


  special = true
}

This requires the Random provider.

Update:

modules/database/versions.tf

to:

terraform {
  required_version = ">= 1.10.0"


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }


    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

Now Terraform can generate a strong database password.

7.9 Store the generated password in Secrets Manager

Add:

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id


  secret_string = jsonencode({
    username = var.master_username
    password = random_password.db.result
    database = var.database_name
  })
}

Now the credentials are stored in:

AWS Secrets Manager

rather than Git.

7.10 Create the PostgreSQL RDS instance

Add:

resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"


  engine         = var.engine
  engine_version = var.engine_version


  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp3"


  db_name  = var.database_name
  username = var.master_username
  password = random_password.db.result
  port     = 5432


  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]


  publicly_accessible = false


  storage_encrypted = true


  backup_retention_period = var.backup_retention_period
  backup_window           = "18:00-19:00"
  maintenance_window      = "sun:19:00-sun:20:00"


  multi_az = var.multi_az


  deletion_protection = var.deletion_protection


  skip_final_snapshot = true


  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]


  auto_minor_version_upgrade = true


  copy_tags_to_snapshot = true


  tags = merge(
    var.tags,
    {
      Name = "${var.name}-postgres"
      Tier = "private-db"
    }
  )


  depends_on = [
    aws_secretsmanager_secret_version.db
  ]
}
7.11 Understand the important settings
Private database

This is critical:

publicly_accessible = false

Therefore:

Internet
   X
   │
   X
 RDS

No direct Internet exposure.

Encryption

We use:

storage_encrypted = true

So database storage is encrypted at rest.

Backup

We have:

backup_retention_period = 7

For development that's enough to demonstrate automated backup configuration without making the architecture unnecessarily expensive.

Storage

We're using:

storage_type = "gp3"

and:

allocated_storage = 20

This is appropriate for a small development environment.

Maximum storage

We also have:

max_allocated_storage = 100

This enables RDS storage autoscaling up to 100 GB.

That's a useful production-oriented configuration.

7.12 Database security

Our RDS security group already exists from Phase 4.

The intended traffic path is:

EC2 App-SG
     │
     │ TCP 5432
     ▼
RDS DB-SG

The DB security group should not allow:

0.0.0.0/0 → 5432

It should only allow the application tier.

Conceptually:

ALB-SG
   │
   ▼
App-SG
   │
   ▼
DB-SG

This is a very important architecture point to mention during an interview.

7.13 Database outputs

Create:

modules/database/outputs.tf

Use:

output "db_instance_id" {
  description = "RDS database instance identifier."
  value       = aws_db_instance.this.id
}


output "db_endpoint" {
  description = "RDS database endpoint."
  value       = aws_db_instance.this.address
}


output "db_port" {
  description = "RDS database port."
  value       = aws_db_instance.this.port
}


output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.this.db_name
}


output "secret_arn" {
  description = "ARN of the database credentials secret."
  value       = aws_secretsmanager_secret.db.arn
}

Notice that we're not outputting the password.

That's intentional.

7.14 Connect database to dev

Open:

environments/dev/main.tf

Add:

module "database" {
  source = "../../modules/database"


  name = "${var.project_name}-${var.environment}"


  subnet_ids = module.networking.private_db_subnet_ids


  security_group_id = module.security.db_security_group_id


  engine         = "postgres"
  engine_version = "16"


  instance_class = "db.t3.micro"


  database_name = "platform"


  master_username = "platformadmin"


  allocated_storage = 20


  backup_retention_period = 7


  multi_az = false


  deletion_protection = false


  tags = {
    Environment = var.environment
  }
}
7.15 Why multi_az = false?

This is an intentional development-cost decision.

For production:

multi_az = true

would be much more appropriate for a critical banking platform.

For our development project:

multi_az = false

keeps the demonstration affordable.

This gives you a useful interview discussion:

"I designed the module to support Multi-AZ deployment, but disabled it for the development environment to control cost."

That's exactly the kind of trade-off an SRE/DevOps engineer should be able to explain.

7.16 Add database outputs

Open:

environments/dev/outputs.tf

Add:

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint."
  value       = module.database.db_endpoint
}


output "db_port" {
  description = "RDS PostgreSQL port."
  value       = module.database.db_port
}


output "db_name" {
  description = "Application database name."
  value       = module.database.db_name
}


output "db_secret_arn" {
  description = "ARN of the database credentials secret."
  value       = module.database.secret_arn
}

Again, no password output.

7.17 Format everything

From the repository root:

terraform fmt -recursive

Then:

cd environments/dev
7.18 Initialize Terraform

Because we're adding the Random provider:

terraform init

You should see something similar to:

Initializing modules...
- database in ../../modules/database


Initializing provider plugins...
- Finding hashicorp/random versions matching "~> 3.7"...
- Installing hashicorp/random...

Your AWS provider should continue using the existing version.

7.19 Validate

Run:

terraform validate

Expected:

Success! The configuration is valid.

If you get an error, stop there and send me the complete error.

7.20 Run the plan

Now:

terraform plan

Do not apply.

We expect additional resources including:

aws_db_subnet_group
aws_secretsmanager_secret
aws_secretsmanager_secret_version
random_password
aws_db_instance

So we're adding approximately 5 resources.

You should therefore expect something around:

Plan: 39 to add, 0 to change, 0 to destroy.

The exact number can differ if your existing module configuration contains additional resources.

The important part is:

0 to change
0 to destroy
7.21 What you MUST inspect in the plan

When you run the plan, look for:

RDS
module.database.aws_db_instance.this

Verify:

engine = "postgres"
port = 5432
publicly_accessible = false
storage_encrypted = true

And:

multi_az = false

for our development environment.

DB subnet group

Look for:

module.database.aws_db_subnet_group.this

It should reference:

private_db_subnet_ids

not public subnets.

Secrets Manager

Look for:

module.database.aws_secretsmanager_secret.db

and:

module.database.aws_secretsmanager_secret_version.db

The generated password should not be printed directly as plaintext in your Terraform configuration.

Terraform may still represent sensitive values in the plan as:

(sensitive value)

That's expected.

7.22 One important security issue to understand

There is a subtle Terraform consideration here.

Even though the password isn't stored in Git, Terraform's state can contain sensitive infrastructure values.

You already solved an important part of this project earlier by using the S3 remote backend.

Therefore, your state is not simply sitting as:

terraform.tfstate

on your laptop.

It is stored in your S3 backend.

Later, when we harden the project, we'll improve the backend configuration further with things such as:

state locking
encryption
restricted IAM access
versioning

This is another reason your project is becoming much more realistic than a basic Terraform exercise.