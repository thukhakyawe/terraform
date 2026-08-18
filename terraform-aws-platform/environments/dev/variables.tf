variable "aws_region" {
  description = "AWS region where infrastructure will be deployed."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name."
  type        = string
  default     = "terraform-aws-platform"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the development VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones used by the development environment."
  type        = list(string)

  default = [
    "ap-southeast-1a",
    "ap-southeast-1b"
  ]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs."

  type = list(string)

  default = [
    "10.10.1.0/24",
    "10.10.2.0/24"
  ]
}

variable "private_app_subnet_cidrs" {
  description = "Private application subnet CIDRs."

  type = list(string)

  default = [
    "10.10.11.0/24",
    "10.10.12.0/24"
  ]
}

variable "private_db_subnet_cidrs" {
  description = "Private database subnet CIDRs."

  type = list(string)

  default = [
    "10.10.21.0/24",
    "10.10.22.0/24"
  ]
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateways."
  type        = bool
  default     = true
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
  description = "Whether RDS deletion protection is enabled."
  type        = bool
  default     = false
}