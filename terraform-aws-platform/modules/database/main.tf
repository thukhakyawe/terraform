# Create the DB subnet group
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

# Create the Secrets Manager secret
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

# Generate a password
resource "random_password" "db" {
  length = 32

  special = true
}


# Store the generated password in Secrets Manager
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.master_username
    password = random_password.db.result
    database = var.database_name
  })
}

# Create the PostgreSQL RDS instance
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