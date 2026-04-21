data "aws_caller_identity" "current" {}

locals {
  raw_bucket_name       = "${var.name_prefix}-raw-${data.aws_caller_identity.current.account_id}"
  processed_bucket_name = "${var.name_prefix}-processed-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "raw" {
  bucket = local.raw_bucket_name

  tags = merge(var.tags, { Name = local.raw_bucket_name, Role = "raw-ingest" })
}

resource "aws_s3_bucket" "processed" {
  bucket = local.processed_bucket_name

  tags = merge(var.tags, { Name = local.processed_bucket_name, Role = "processed-output" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
