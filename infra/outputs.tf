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

output "embedding_lambda_function_name" {
  description = "Embedding processor Lambda function name."
  value       = module.lambda.embedding_function_name
}

output "embedding_lambda_log_group_name" {
  description = "CloudWatch log group for the embedding processor."
  value       = module.lambda.embedding_log_group_name
}

output "pgvector_endpoint" {
  description = "RDS Postgres endpoint (host:port) backing pgvector."
  value       = module.rds.endpoint
}

output "pgvector_db_name" {
  description = "Initial database name used by pgvector."
  value       = module.rds.db_name
}

output "pgvector_secret_arn" {
  description = "Secrets Manager ARN holding RDS credentials (JSON)."
  value       = module.rds.secret_arn
  sensitive   = true
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

output "frontend_bucket_name" {
  description = "Upload the Vite build: aws s3 sync ../frontend/dist/ s3://<this> --delete"
  value       = module.cloudfront_frontend.bucket_name
}

output "frontend_cloudfront_domain" {
  description = "HTTPS URL host for the SPA; add https://<this> to chat_cors_allow_origins and re-apply."
  value       = module.cloudfront_frontend.domain_name
}

output "frontend_cloudfront_url" {
  description = "Base URL for the deployed UI (build frontend with VITE_CHAT_API_URL empty for same-origin API calls)."
  value       = "https://${module.cloudfront_frontend.domain_name}"
}

output "frontend_cloudfront_distribution_id" {
  description = "Use for cache invalidation after uploading new assets."
  value       = module.cloudfront_frontend.distribution_id
}
