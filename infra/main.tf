locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "s3" {
  source      = "./modules/s3"
  name_prefix = local.name_prefix
  tags        = {}
}

module "lambda" {
  source = "./modules/lambda"

  name_prefix           = local.name_prefix
  raw_bucket_name       = module.s3.raw_bucket_name
  raw_bucket_arn        = module.s3.raw_bucket_arn
  processed_bucket_name = module.s3.processed_bucket_name
  processed_bucket_arn  = module.s3.processed_bucket_arn
  tags                  = {}

  depends_on = [module.s3]
}

# Disparo S3 -> Lambda sin EventBridge: S3 puede notificar directamente a Lambda cuando se crea un objeto.
# EventBridge aporta un bus central y reglas complejas entre muchas fuentes; aqui solo hace falta
# ObjectCreated (Put / multipart) en un unico bucket; aws_s3_bucket_notification lo cubre.
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

# Politicas de bucket: restringen quien puede leer raw / escribir processed al rol de la Lambda (defensa en profundidad ademas del IAM del rol).
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
    sid    = "AllowLambdaWriteProcessed"
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
