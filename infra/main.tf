locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "s3" {
  source      = "./modules/s3"
  name_prefix = local.name_prefix
  tags        = {}
}

module "network" {
  source = "./modules/network"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  tags        = {}
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
  tags        = {}
}

module "dynamodb" {
  source = "./modules/dynamodb"

  name_prefix = local.name_prefix
  tags        = {}
}

module "rds" {
  source = "./modules/rds"

  name_prefix = local.name_prefix
  vpc_id      = module.network.vpc_id
  subnet_ids  = module.network.public_subnet_ids

  # Lambda stays non-VPC (simpler), so allow ingress from the public internet on 5432.
  # Strong random password + TLS keeps the blast radius manageable for this challenge.
  allowed_cidr_blocks = ["0.0.0.0/0"]
  publicly_accessible = true

  tags = {}
}

module "ec2" {
  source = "./modules/ec2"

  name_prefix           = local.name_prefix
  vpc_id                = module.network.vpc_id
  subnet_id             = module.network.public_subnet_ids[0]
  instance_type         = var.chat_instance_type
  ec2_key_name          = var.chat_ec2_key_name
  allowed_ingress_cidrs = var.chat_allowed_ingress_cidrs
  container_port        = var.chat_container_port
  container_image       = "${module.ecr.repository_url}:${var.chat_image_tag}"

  chat_table_name = module.dynamodb.table_name
  chat_table_arn  = module.dynamodb.table_arn

  ecr_repository_arn = module.ecr.repository_arn

  db_secret_arn       = module.rds.secret_arn
  embedding_model     = var.embedding_model
  pgvector_collection = var.pgvector_collection
  retrieval_k         = var.retrieval_k

  llm_model     = var.chat_llm_model
  summary_model = var.chat_summary_model

  cors_allow_origins = join(",", var.chat_cors_allow_origins)

  tags = {}
}

module "lambda" {
  source = "./modules/lambda"

  name_prefix           = local.name_prefix
  raw_bucket_name       = module.s3.raw_bucket_name
  raw_bucket_arn        = module.s3.raw_bucket_arn
  processed_bucket_name = module.s3.processed_bucket_name
  processed_bucket_arn  = module.s3.processed_bucket_arn
  processed_bucket_id   = module.s3.processed_bucket_id

  openai_secret_arn   = module.ec2.openai_secret_arn
  db_secret_arn       = module.rds.secret_arn
  embedding_model     = var.embedding_model
  pgvector_collection = var.pgvector_collection

  tags = {}

  depends_on = [module.s3, module.ec2, module.rds]
}

# Raw bucket -> document processor Lambda (PDF/HTML -> JSONL).
resource "aws_lambda_permission" "s3_raw_invoke" {
  statement_id  = "AllowExecutionFromS3Raw"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3.raw_bucket_arn
}

resource "aws_s3_bucket_notification" "raw_lambda" {
  bucket = module.s3.raw_bucket_id

  lambda_function {
    lambda_function_arn = module.lambda.function_arn
    events              = ["s3:ObjectCreated:Put"]
  }

  depends_on = [aws_lambda_permission.s3_raw_invoke]
}

# Bucket policies: defense-in-depth on top of the per-role IAM policies.
data "aws_iam_policy_document" "raw_bucket_lambda" {
  statement {
    sid    = "AllowLambdaListRaw"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.lambda.role_arn]
    }
    actions = [
      "s3:ListBucket",
    ]
    resources = [module.s3.raw_bucket_arn]
  }

  statement {
    sid    = "AllowLambdaGetRawObjects"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.lambda.role_arn]
    }
    actions = [
      "s3:GetObject",
    ]
    resources = ["${module.s3.raw_bucket_arn}/*"]
  }
}

data "aws_iam_policy_document" "processed_bucket_lambda" {
  statement {
    sid    = "AllowDocumentProcessorWrite"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.lambda.role_arn]
    }
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${module.s3.processed_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "AllowEmbeddingProcessorRead"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.lambda.embedding_role_arn]
    }
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${module.s3.processed_bucket_arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "raw" {
  bucket = module.s3.raw_bucket_id
  policy = data.aws_iam_policy_document.raw_bucket_lambda.json

  depends_on = [module.lambda]
}

resource "aws_s3_bucket_policy" "processed" {
  bucket = module.s3.processed_bucket_id
  policy = data.aws_iam_policy_document.processed_bucket_lambda.json

  depends_on = [module.lambda]
}

module "cloudfront_frontend" {
  source = "./modules/cloudfront_frontend"

  name_prefix        = local.name_prefix
  chat_origin_domain = module.ec2.instance_public_dns
  chat_origin_port   = var.chat_container_port
  tags               = {}

  # NOTE: intentionally no `depends_on = [module.ec2]`.
  # The chat_origin_domain reference already chains the dependency, and an explicit
  # module-level depends_on forces every data source (e.g. aws_caller_identity) to be
  # read during apply whenever module.ec2 changes, which in turn makes the bucket name
  # "known after apply" and triggers a full frontend S3 bucket replacement.
}
