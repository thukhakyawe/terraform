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
