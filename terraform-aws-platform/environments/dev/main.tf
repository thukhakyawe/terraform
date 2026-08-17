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