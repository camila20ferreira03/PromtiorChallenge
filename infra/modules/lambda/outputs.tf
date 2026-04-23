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

output "embedding_function_name" {
  value = aws_lambda_function.embedding_processor.function_name
}

output "embedding_function_arn" {
  value = aws_lambda_function.embedding_processor.arn
}

output "embedding_role_arn" {
  value = aws_iam_role.embedding_processor.arn
}

output "embedding_log_group_name" {
  value = aws_cloudwatch_log_group.embedding_processor.name
}
