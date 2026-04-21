variable "name_prefix" {
  type        = string
  description = "Prefix for the ECR repository name."
}

variable "tags" {
  type    = map(string)
  default = {}
}
