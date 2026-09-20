output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}

output "db_master_user_secret_arn" {
  description = "ARN do secret no Secrets Manager com usuário/senha do master, gerado pela AWS"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
