locals {
  # Pre-built zip produced by the developer (see scripts/build-lambda-document-processor.sh).
  lambda_zip_path = "${path.module}/../../../lambda/document_processor/build/document_processor.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "document_processor" {
  name               = "${var.name_prefix}-document-processor"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = merge(var.tags, { Name = "${var.name_prefix}-document-processor" })
}

data "aws_iam_policy_document" "lambda_s3" {
  statement {
    sid    = "ListRaw"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [var.raw_bucket_arn]
  }

  statement {
    sid    = "ReadRawObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = ["${var.raw_bucket_arn}/*"]
  }

  statement {
    sid    = "WriteProcessed"
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${var.processed_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "document_processor_s3" {
  name   = "s3-raw-processed"
  role   = aws_iam_role.document_processor.id
  policy = data.aws_iam_policy_document.lambda_s3.json
}

resource "aws_iam_role_policy_attachment" "document_processor_logs" {
  role       = aws_iam_role.document_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "document_processor" {
  name              = "/aws/lambda/${var.name_prefix}-document-processor"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_lambda_function" "document_processor" {
  function_name    = "${var.name_prefix}-document-processor"
  role             = aws_iam_role.document_processor.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = local.lambda_zip_path
  source_code_hash = filebase64sha256(local.lambda_zip_path)

  timeout     = 180
  memory_size = 1024

  environment {
    variables = {
      RAW_BUCKET       = var.raw_bucket_name
      PROCESSED_BUCKET = var.processed_bucket_name
      CHUNK_SIZE       = tostring(var.chunk_size)
      CHUNK_OVERLAP    = tostring(var.chunk_overlap)
      MAX_INPUT_MB     = tostring(var.max_input_mb)
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.document_processor_logs,
    aws_cloudwatch_log_group.document_processor,
  ]

  tags = merge(var.tags, { Name = "${var.name_prefix}-document-processor" })
}
