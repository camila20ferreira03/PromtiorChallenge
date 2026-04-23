variable "name_prefix" {
  type        = string
  description = "Prefix for Lambda function and IAM resources."
}

variable "raw_bucket_name" {
  type = string
}

variable "raw_bucket_arn" {
  type = string
}

variable "processed_bucket_name" {
  type = string
}

variable "processed_bucket_arn" {
  type = string
}

variable "chunk_size" {
  type        = number
  description = "Target chunk size (chars) for RecursiveCharacterTextSplitter."
  default     = 1000
}

variable "chunk_overlap" {
  type        = number
  description = "Overlap (chars) between consecutive chunks."
  default     = 150
}

variable "max_input_mb" {
  type        = number
  description = "Max raw object size (MB) the Lambda will try to process; larger objects are skipped."
  default     = 20
}

variable "processed_bucket_id" {
  type        = string
  description = "Processed bucket id (name) for the S3->embedding Lambda notification."
}

variable "openai_secret_arn" {
  type        = string
  description = "Secrets Manager ARN holding the OpenAI API key, consumed by the embedding Lambda."
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN holding the RDS Postgres credentials (JSON)."
}

variable "embedding_model" {
  type        = string
  description = "OpenAI embedding model id."
  default     = "text-embedding-3-small"
}

variable "pgvector_collection" {
  type        = string
  description = "langchain_postgres PGVector collection name."
  default     = "promtior_docs"
}

variable "embedding_memory_mb" {
  type        = number
  description = "Memory allocation for the embedding Lambda."
  default     = 1024
}

variable "embedding_timeout_s" {
  type        = number
  description = "Timeout for the embedding Lambda."
  default     = 300
}

variable "tags" {
  type    = map(string)
  default = {}
}
