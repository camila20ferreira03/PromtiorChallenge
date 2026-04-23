terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-pgvector"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.name_prefix}-pgvector" })
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-pgvector-sg"
  description = "Ingress on ${var.port} from chat EC2 + Lambda egress; egress to all."
  vpc_id      = var.vpc_id

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-pgvector-sg" })
}

resource "aws_security_group_rule" "ingress_from_sg" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = each.value
  description              = "Postgres from caller SG"
}

resource "aws_security_group_rule" "ingress_from_cidr" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  security_group_id = aws_security_group.this.id
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Postgres from external CIDR (Lambda non-VPC egress)"
}

# RDS rejects characters like '/', '@', '"', and spaces in master passwords.
resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-pgvector"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.username
  password = random_password.master.result
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = var.publicly_accessible

  skip_final_snapshot        = true
  deletion_protection        = false
  backup_retention_period    = 1
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-pgvector" })
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name_prefix}-pgvector-credentials"
  description = "RDS Postgres credentials for the pgvector-backed chat RAG."

  tags = merge(var.tags, { Name = "${var.name_prefix}-pgvector-credentials" })
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = aws_db_instance.this.db_name
    username = aws_db_instance.this.username
    password = random_password.master.result
  })
}
