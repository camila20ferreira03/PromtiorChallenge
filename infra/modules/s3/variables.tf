variable "name_prefix" {
  type        = string
  description = "Prefix for S3 bucket names; account ID is appended for global uniqueness."
}

variable "tags" {
  type        = map(string)
  description = "Extra tags for S3 buckets."
  default     = {}
}
