# Document transformation pipeline (Terraform)

Provisions **S3** (raw + processed) and **Lambda** (`document_processor`). The Lambda is invoked **only** by **S3 event notifications** on the **raw** bucket for **`ObjectCreated:Put`** (direct S3 → Lambda).

**Why not EventBridge for ingest?** EventBridge is useful when you need a central event bus, many event sources, or complex routing. For “new object in this bucket → run this Lambda”, **S3 bucket notifications** are enough: fewer moving parts, lower latency, and you still filter by event type (`Put`). Bucket **IAM resource policies** (`aws_s3_bucket_policy`) complement the Lambda role policy so only that role can read **raw** / write **processed**.

Lambda code lives in the repo at [`../lambda/document_processor`](../lambda/document_processor).

## Prerequisites

- Terraform `>= 1.5`
- AWS credentials with permissions to manage S3 (incl. bucket policies), IAM, Lambda, and CloudWatch Logs

## Remote state (required for team workflows)

1. Create an S3 bucket and a DynamoDB table (partition key `LockID`, string) for state locking.
2. Copy [`environments/dev/terraform.tfvars.example`](environments/dev/terraform.tfvars.example) to `terraform.tfvars` in this directory (or pass `-var-file=...`).
3. Edit [`environments/dev/backend.hcl`](environments/dev/backend.hcl) with your bucket name, state key, region, and lock table name.
4. From `infra/`:

   ```bash
   terraform init -backend-config=environments/dev/backend.hcl
   terraform plan
   terraform apply
   ```

## Local init (no remote backend)

For formatting and validation only:

```bash
terraform init -backend=false
terraform validate
```

Before a real apply, re-run `terraform init` with your `backend.hcl`.

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
