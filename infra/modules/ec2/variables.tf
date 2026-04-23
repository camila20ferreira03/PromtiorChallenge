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

variable "ecr_repository_arn" {
  type        = string
  description = "ECR repository ARN hosting the chat image."
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN with RDS Postgres credentials (JSON: host, port, dbname, username, password)."
}

variable "embedding_model" {
  type        = string
  description = "OpenAI embedding model id used at query time (must match what the embedding Lambda wrote)."
  default     = "text-embedding-3-small"
}

variable "pgvector_collection" {
  type        = string
  description = "langchain_postgres PGVector collection name (logical grouping inside the DB)."
  default     = "promtior_docs"
}

variable "retrieval_k" {
  type        = number
  description = "Number of top chunks retrieved per user query."
  default     = 6
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

variable "root_volume_size_gb" {
  type        = number
  description = "Root EBS volume size (GB). Must be >= the AMI snapshot size; AL2023 ships a 30 GB snapshot."
  default     = 30
}

variable "cors_allow_origins" {
  type        = string
  description = "Comma-separated browser origins for CORS (e.g. https://d123.cloudfront.net,http://localhost:5173)."
  default     = "http://localhost:5173,http://127.0.0.1:5173"
}

variable "tags" {
  type    = map(string)
  default = {}
}
