output "raw_bucket_name" {
  description = "S3 bucket for raw document ingest."
  value       = module.s3.raw_bucket_name
}

output "processed_bucket_name" {
  description = "S3 bucket for processed document output."
  value       = module.s3.processed_bucket_name
}

output "lambda_function_name" {
  description = "Document processor Lambda function name."
  value       = module.lambda.function_name
}

output "lambda_log_group_name" {
  description = "CloudWatch log group for the document processor."
  value       = module.lambda.log_group_name
}

output "chat_table_name" {
  description = "DynamoDB table storing chat sessions and messages."
  value       = module.dynamodb.table_name
}

output "chat_ecr_repository_url" {
  description = "ECR repository URL hosting the chat API image."
  value       = module.ecr.repository_url
}

output "chat_instance_public_dns" {
  description = "Public DNS of the chat EC2 instance."
  value       = module.ec2.instance_public_dns
}

output "chat_instance_public_ip" {
  description = "Public IP of the chat EC2 instance."
  value       = module.ec2.instance_public_ip
}

output "chat_openai_secret_arn" {
  description = "Secrets Manager ARN holding the OpenAI API key."
  value       = module.ec2.openai_secret_arn
  sensitive   = true
}
