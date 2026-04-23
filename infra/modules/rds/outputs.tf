output "endpoint" {
  description = "host:port for Postgres clients."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "DNS-only address (no port)."
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "username" {
  value = aws_db_instance.this.username
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "secret_arn" {
  value     = aws_secretsmanager_secret.db.arn
  sensitive = true
}
