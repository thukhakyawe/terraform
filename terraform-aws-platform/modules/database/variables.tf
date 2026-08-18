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
