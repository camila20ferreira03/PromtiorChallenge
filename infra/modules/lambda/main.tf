locals {
  # Pre-built zips produced by the developer (see scripts/build-lambda-*.sh).
  lambda_zip_path           = "${path.module}/../../../lambda/document_processor/build/document_processor.zip"
  embedding_lambda_zip_path = "${path.module}/../../../lambda/embedding_processor/build/embedding_processor.zip"
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

# --------------------------------------------------------------------------
# Embedding processor: S3 (processed/*.chunks.jsonl) -> OpenAI embeddings -> RDS pgvector.
# --------------------------------------------------------------------------

resource "aws_iam_role" "embedding_processor" {
  name               = "${var.name_prefix}-embedding-processor"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = merge(var.tags, { Name = "${var.name_prefix}-embedding-processor" })
}

data "aws_iam_policy_document" "embedding_processor_inline" {
  statement {
    sid       = "ReadProcessed"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.processed_bucket_arn}/*"]
  }

  statement {
    sid    = "ReadSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      var.openai_secret_arn,
      var.db_secret_arn,
    ]
  }
}

resource "aws_iam_role_policy" "embedding_processor_inline" {
  name   = "embedding-processor-runtime"
  role   = aws_iam_role.embedding_processor.id
  policy = data.aws_iam_policy_document.embedding_processor_inline.json
}

resource "aws_iam_role_policy_attachment" "embedding_processor_logs" {
  role       = aws_iam_role.embedding_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "embedding_processor" {
  name              = "/aws/lambda/${var.name_prefix}-embedding-processor"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_lambda_function" "embedding_processor" {
  function_name    = "${var.name_prefix}-embedding-processor"
  role             = aws_iam_role.embedding_processor.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = local.embedding_lambda_zip_path
  source_code_hash = filebase64sha256(local.embedding_lambda_zip_path)

  timeout     = var.embedding_timeout_s
  memory_size = var.embedding_memory_mb

  # NOTE: no `reserved_concurrent_executions`. Reserving even 1 slot fails in
  # accounts where UnreservedConcurrentExecution is already at its 10-slot floor.
  # The handler is idempotent (delete-by-source_id + add_documents), so parallel
  # invocations on different source_ids are safe; concurrent runs on the same
  # source_id would just re-do the same upsert.

  environment {
    variables = {
      PROCESSED_BUCKET    = var.processed_bucket_name
      OPENAI_SECRET_ARN   = var.openai_secret_arn
      DB_SECRET_ARN       = var.db_secret_arn
      EMBEDDING_MODEL     = var.embedding_model
      PGVECTOR_COLLECTION = var.pgvector_collection
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.embedding_processor_logs,
    aws_cloudwatch_log_group.embedding_processor,
  ]

  tags = merge(var.tags, { Name = "${var.name_prefix}-embedding-processor" })
}

resource "aws_lambda_permission" "s3_processed_invoke" {
  statement_id  = "AllowExecutionFromS3Processed"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.embedding_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.processed_bucket_arn
}

resource "aws_s3_bucket_notification" "processed_lambda" {
  bucket = var.processed_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.embedding_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "processed/"
    filter_suffix       = ".chunks.jsonl"
  }

  depends_on = [aws_lambda_permission.s3_processed_invoke]
}
