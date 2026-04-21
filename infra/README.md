# Document transformation pipeline (Terraform)

Provisions **S3** (raw + processed) and **Lambda** (`document_processor`). The Lambda is invoked **only** by **S3 event notifications** on the **raw** bucket for **`ObjectCreated:Put`** (direct S3 → Lambda).

**Why not EventBridge for ingest?** EventBridge is useful when you need a central event bus, many event sources, or complex routing. For “new object in this bucket → run this Lambda”, **S3 bucket notifications** are enough: fewer moving parts, lower latency, and you still filter by event type (`Put`). Bucket **IAM resource policies** (`aws_s3_bucket_policy`) complement the Lambda role policy so only that role can read **raw** / write **processed**.

Lambda code lives in the repo at [`../lambda/document_processor`](../lambda/document_processor).

## Prerequisites

- Terraform `>= 1.5`
- AWS credentials with permissions to manage S3 (incl. bucket policies), IAM, Lambda, and CloudWatch Logs

## State and locks (local only)

This project uses the **default local backend**: `terraform.tfstate`, `terraform.tfstate.backup`, `.terraform/`, `.terraform.lock.hcl`, and transient `.terraform.tfstate.lock.info` all live in `infra/` and are **git‑ignored**. Do not commit them — they can contain bucket names, ARNs, and account IDs.

1. Copy [`terraform.tfvars.example`](terraform.tfvars.example) to `terraform.tfvars` (also ignored). Terraform auto-loads any `terraform.tfvars` next to the root module, so no `-var-file` flag is needed.
2. From `infra/`:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

The lock file `.terraform.tfstate.lock.info` appears only while a command runs and prevents concurrent changes on the same machine.

## Variables

| Name           | Description                          | Default      |
|----------------|--------------------------------------|--------------|
| `aws_region`   | AWS region                           | `us-east-1` |
| `project_name` | Prefix for resource names (required) | —            |
| `environment`  | Environment suffix                   | `dev`        |

## Outputs

After apply: raw/processed bucket names, Lambda function name, and log group name.

## Testing S3 ingest

Upload a file to the **raw** bucket (output `raw_bucket_name`) using `PutObject`. S3 should invoke Lambda; check the **processed** bucket and CloudWatch logs.

**Supported inputs:** PDF and HTML (detected by magic bytes → `Content-Type` → extension). **Output:** one JSONL file per source at `s3://<processed_bucket>/processed/<source-key>.chunks.jsonl`, with one `{"text", "metadata"}` object per chunk.
