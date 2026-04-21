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

variable "tags" {
  type    = map(string)
  default = {}
}
