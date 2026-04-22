variable "name_prefix" {
  type        = string
  description = "Resource name prefix (e.g. promtior-challenge-dev)."
}

variable "chat_origin_domain" {
  type        = string
  description = "Public DNS name of the chat EC2 (e.g. ec2-...amazonaws.com)."
}

variable "chat_origin_port" {
  type        = number
  description = "HTTP port of the chat API on EC2."
  default     = 8000
}

variable "tags" {
  type    = map(string)
  default = {}
}
