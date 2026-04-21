output "function_name" {
  value = aws_lambda_function.document_processor.function_name
}

output "function_arn" {
  value = aws_lambda_function.document_processor.arn
}

output "role_arn" {
  value = aws_iam_role.document_processor.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.document_processor.name
}
