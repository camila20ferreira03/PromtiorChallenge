variable "aws_region" {
  type        = string
  description = "AWS region for all resources."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Short name prefix for globally unique resource names (e.g. S3 buckets)."
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g. dev, prod)."
  default     = "dev"
}
