variable "name_prefix" {
  type        = string
  description = "Prefix for IAM, SG, and EC2 resource names."
}

variable "vpc_id" {
  type        = string
  description = "VPC to place the chat security group in."
}

variable "subnet_id" {
  type        = string
  description = "Public subnet to launch the EC2 instance in."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the chat backend."
  default     = "t3.small"
}

variable "ec2_key_name" {
  type        = string
  description = "Optional EC2 key pair name for SSH (SSM is preferred)."
  default     = null
}

variable "allowed_ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the chat API port."
  default     = ["0.0.0.0/0"]
}

variable "container_port" {
  type        = number
  description = "TCP port exposed by the chat container."
  default     = 8000
}

variable "container_image" {
  type        = string
  description = "Full image URI (e.g. <account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>) the instance should pull and run."
}

variable "chat_table_name" {
  type        = string
  description = "DynamoDB table name for chat sessions/messages."
}

variable "chat_table_arn" {
  type        = string
  description = "DynamoDB table ARN for IAM scoping."
}

variable "processed_bucket_name" {
  type        = string
  description = "S3 bucket with processed chunks consumed by the chat backend."
}

variable "processed_bucket_arn" {
  type        = string
  description = "S3 bucket ARN for IAM scoping."
}

variable "ecr_repository_arn" {
  type        = string
  description = "ECR repository ARN hosting the chat image."
}

variable "llm_model" {
  type        = string
  description = "OpenAI model id used by the chat chain."
  default     = "gpt-4o-mini"
}

variable "summary_model" {
  type        = string
  description = "OpenAI model id used by the summarizer."
  default     = "gpt-4o-mini"
}

variable "session_max_requests" {
  type        = number
  description = "Lifetime request cap per session_id."
  default     = 10
}

variable "tags" {
  type    = map(string)
  default = {}
}
