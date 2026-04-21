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

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the chat backend VPC."
  default     = "10.0.0.0/16"
}

variable "chat_instance_type" {
  type        = string
  description = "EC2 instance type hosting the chat Docker container."
  default     = "t3.small"
}

variable "chat_ec2_key_name" {
  type        = string
  description = "Optional EC2 key pair for SSH; leave null to rely on SSM."
  default     = null
}

variable "chat_allowed_ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the chat API port."
  default     = ["0.0.0.0/0"]
}

variable "chat_container_port" {
  type        = number
  description = "TCP port exposed by the chat container."
  default     = 8000
}

variable "chat_image_tag" {
  type        = string
  description = "Image tag pulled from ECR by the EC2 user_data."
  default     = "latest"
}

variable "chat_llm_model" {
  type        = string
  description = "OpenAI model id used by the chat chain."
  default     = "gpt-4o-mini"
}

variable "chat_summary_model" {
  type        = string
  description = "OpenAI model id used by the conversation summarizer."
  default     = "gpt-4o-mini"
}

variable "chat_session_max_requests" {
  type        = number
  description = "Lifetime request cap per session_id (HTTP 429 when exceeded)."
  default     = 10
}
