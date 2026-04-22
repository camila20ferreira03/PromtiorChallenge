data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Official Amazon Linux 2023 (kernel default, x86_64) — avoids ECS-optimized AMIs
# that match broad "al2023-ami-*-x86_64" and spawn a crashing ecs-agent container.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_secretsmanager_secret" "openai" {
  name        = "${var.name_prefix}-openai-api-key"
  description = "OpenAI API key consumed by the chat backend at runtime."

  tags = merge(var.tags, { Name = "${var.name_prefix}-openai-api-key" })
}

resource "aws_security_group" "chat" {
  name        = "${var.name_prefix}-chat-sg"
  description = "Ingress for chat API (port ${var.container_port}) and egress all."
  vpc_id      = var.vpc_id

  ingress {
    description = "Chat API"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-chat-sg" })
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "chat" {
  name               = "${var.name_prefix}-chat-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = merge(var.tags, { Name = "${var.name_prefix}-chat-ec2" })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.chat.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "chat_inline" {
  statement {
    sid    = "DynamoDBChatTable"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      var.chat_table_arn,
      "${var.chat_table_arn}/index/*",
    ]
  }

  statement {
    sid    = "OpenAISecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.openai.arn]
  }

  statement {
    sid    = "ListProcessed"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [var.processed_bucket_arn]
  }

  statement {
    sid    = "ReadProcessedObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = ["${var.processed_bucket_arn}/*"]
  }

  statement {
    sid    = "ECRAuthToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "chat" {
  name   = "chat-runtime"
  role   = aws_iam_role.chat.id
  policy = data.aws_iam_policy_document.chat_inline.json
}

resource "aws_iam_instance_profile" "chat" {
  name = "${var.name_prefix}-chat-ec2"
  role = aws_iam_role.chat.name
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    exec > >(tee -a /var/log/chat-bootstrap.log) 2>&1
    echo "=== chat bootstrap $(date -Is) ==="

    # Do not `dnf install curl` — it conflicts with the default curl-minimal on AL2023.
    dnf install -y docker unzip
    if ! command -v aws >/dev/null 2>&1; then
      curl -fSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
      unzip -oq /tmp/awscliv2.zip -d /tmp
      /tmp/aws/install --update
    fi
    systemctl enable --now docker

    AWS_REGION="${data.aws_region.current.name}"
    ECR_REGISTRY="${data.aws_caller_identity.current.account_id}.dkr.ecr.$${AWS_REGION}.amazonaws.com"
    IMAGE="${var.container_image}"

    aws --version
    docker --version

    aws ecr get-login-password --region "$${AWS_REGION}" \
      | docker login --username AWS --password-stdin "$${ECR_REGISTRY}"

    docker pull "$${IMAGE}"

    docker rm -f chat-api 2>/dev/null || true
    docker run -d \
      --name chat-api \
      --restart unless-stopped \
      -p ${var.container_port}:${var.container_port} \
      -e AWS_REGION="$${AWS_REGION}" \
      -e CHAT_TABLE_NAME="${var.chat_table_name}" \
      -e PROCESSED_BUCKET="${var.processed_bucket_name}" \
      -e OPENAI_SECRET_ARN="${aws_secretsmanager_secret.openai.arn}" \
      -e LLM_MODEL="${var.llm_model}" \
      -e SUMMARY_MODEL="${var.summary_model}" \
      -e SESSION_MAX_REQUESTS="${var.session_max_requests}" \
      -e CORS_ALLOW_ORIGINS="${var.cors_allow_origins}" \
      -e PORT="${var.container_port}" \
      "$${IMAGE}"

    echo "=== chat bootstrap done $(date -Is) ==="
  EOT
}

resource "aws_instance" "chat" {
  ami                         = trimspace(data.aws_ssm_parameter.al2023_ami.value)
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.chat.id]
  iam_instance_profile        = aws_iam_instance_profile.chat.name
  associate_public_ip_address = true
  key_name                    = var.ec2_key_name

  user_data                   = local.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-chat" })
}
