locals {
  name_prefix = "platform-${var.environment}"
}

module "networking" {
  source = "../../modules/networking"

  name = "${var.project_name}-${var.environment}"

  vpc_cidr = var.vpc_cidr

  availability_zones = var.availability_zones

  public_subnet_cidrs = var.public_subnet_cidrs

  private_app_subnet_cidrs = var.private_app_subnet_cidrs

  private_db_subnet_cidrs = var.private_db_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway

  tags = {
    Environment = var.environment
  }
}

module "security" {
  source = "../../modules/security"

  name = "${var.project_name}-${var.environment}"

  vpc_id = module.networking.vpc_id

  app_port = 8080
  db_port  = 5432

  tags = {
    Environment = var.environment
  }
}


# Connect IAM to Dev
module "iam" {
  source = "../../modules/iam"

  name = "${var.project_name}-${var.environment}"

  tags = {
    Environment = var.environment
  }
}

# Connect ALB to the dev environment
module "alb" {
  source = "../../modules/alb"

  name = "${var.project_name}-${var.environment}"

  vpc_id = module.networking.vpc_id

  public_subnet_ids = module.networking.public_subnet_ids

  security_group_id = module.security.alb_security_group_id

  target_port       = 8080
  health_check_path = "/health"

  tags = {
    Environment = var.environment
  }
}

# Connect Compute to the dev environment
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

# Connect database to dev
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

# Connect monitoring to dev
module "monitoring" {
  source = "../../modules/monitoring"

  name        = "${var.project_name}-${var.environment}"
  environment = var.environment

  alb_arn_suffix = module.alb.alb_arn_suffix

  target_group_arn_suffix = module.alb.target_group_arn_suffix

  autoscaling_group_name = module.compute.autoscaling_group_name

  db_instance_identifier = module.database.db_instance_id

  alarm_email = ""

  tags = {
    Environment = var.environment
  }
}