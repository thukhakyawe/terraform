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