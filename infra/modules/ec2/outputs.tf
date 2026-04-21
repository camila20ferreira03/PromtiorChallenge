output "instance_id" {
  value = aws_instance.chat.id
}

output "instance_public_ip" {
  value = aws_instance.chat.public_ip
}

output "instance_public_dns" {
  value = aws_instance.chat.public_dns
}

output "security_group_id" {
  value = aws_security_group.chat.id
}

output "role_arn" {
  value = aws_iam_role.chat.arn
}

output "openai_secret_arn" {
  value     = aws_secretsmanager_secret.openai.arn
  sensitive = true
}
