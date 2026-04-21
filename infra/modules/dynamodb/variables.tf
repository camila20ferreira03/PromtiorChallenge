variable "name_prefix" {
  type        = string
  description = "Prefix for the DynamoDB table name."
}

variable "tags" {
  type    = map(string)
  default = {}
}
