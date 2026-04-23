variable "name_prefix" {
  type        = string
  description = "Prefix for RDS, SG, and secret resource names."
}

variable "vpc_id" {
  type        = string
  description = "VPC to place the RDS security group in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the DB subnet group. With publicly_accessible=true these should be public subnets across >=2 AZs."
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security group IDs allowed to connect to Postgres inside the VPC (e.g. the EC2 chat SG)."
  default     = []
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to connect to Postgres (used for the non-VPC embedding Lambda; defaults to open so AWS Lambda egress IPs can reach it)."
  default     = ["0.0.0.0/0"]
}

variable "publicly_accessible" {
  type        = bool
  description = "Assign a public IP so non-VPC callers (the embedding Lambda) can reach the DB."
  default     = true
}

variable "engine_version" {
  type        = string
  description = <<-EOT
    Postgres engine version. pgvector is supported from 15.2+; 16.x is current.
    Older minors (e.g. 16.3, 16.4) are deprecated by AWS and fail with
    "Cannot find version X.Y for postgres" — use a currently supported minor
    (aws rds describe-db-engine-versions --engine postgres).
  EOT
  default     = "16.8"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GB."
  default     = 20
}

variable "db_name" {
  type        = string
  description = "Initial database name."
  default     = "promtior"
}

variable "username" {
  type        = string
  description = "Master username."
  default     = "promtior_admin"
}

variable "port" {
  type        = number
  description = "Postgres TCP port."
  default     = 5432
}

variable "tags" {
  type    = map(string)
  default = {}
}
