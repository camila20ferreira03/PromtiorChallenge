resource "aws_dynamodb_table" "chat" {
  name         = "${var.name_prefix}-chat"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-chat" })
}
