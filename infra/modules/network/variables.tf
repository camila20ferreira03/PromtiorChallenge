variable "name_prefix" {
  type        = string
  description = "Prefix for VPC and related resource names."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "tags" {
  type    = map(string)
  default = {}
}
