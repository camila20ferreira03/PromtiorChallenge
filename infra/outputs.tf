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
