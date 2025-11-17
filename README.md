# 01_nyc_taxi_pyspark_aws_glue
NYC Taxi Dataset ETL project using pyspark in aws glue

## Terraform Infrastructure

Confirm identity: aws sts get-caller-identity before running Terraform
- Root module (`infrastructure/terraform`):
  - `main.tf`: wires providers and composes all child modules with environment-scoped inputs
  - `variables.tf`: declares root variables used to drive modules
  - `outputs.tf`: exposes key values like bucket names, Glue job role, state machine ARN, etc.
  - `env/`: environment overrides via `*.tfvars` (`local_dev.tfvars`, `dev.tfvars`, `uat.tfvars`, `prod.tfvars`)

- Modules (`infrastructure/terraform/modules/*`): each module is self-contained with `main.tf`, `variables.tf`, `outputs.tf`.
- `vpc/`: creates VPC, public and private subnets, NAT gateway, and routes
  - Inputs: `name`, `cidr_block`, `tags`, `public_subnets`, `private_subnets`
  - Outputs: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`
  - `s3_data_lake/`: creates Bronze, Silver, Gold, and Code buckets with public access blocked and SSE-S3
    - Inputs: `name_prefix`, `tags`
    - Outputs: bucket IDs for each layer
  - `glue_job/`: provisions IAM Role/Policy for Glue and a Bronze Glue job
    - Inputs: `name_prefix`, `tags`, `data_bucket_prefix`, `code_bucket_prefix`, `script_location_bronze`
    - Outputs: `glue_role_arn`, `bronze_job_name`
  - `glue_catalog/`: defines Glue database and Bronze table schema
    - Inputs: `database_name`, `bronze_location`, `bronze_columns`
    - Output: `database_name`
  - `glue_dq/`: registers Glue Data Quality ruleset
    - Inputs: `name_prefix`, `bronze_ruleset_path`, `tags`
    - Output: `bronze_ruleset_name`
  - `step_functions/`: creates the state machine from ASL JSON
    - Inputs: `name_prefix`, `role_arn`, `definition_path`, `tags`
    - Output: `state_machine_arn`
  - `eventbridge/`: schedules daily 08:00 UTC trigger targeting Step Functions
    - Inputs: `name_prefix`, `cron`, `state_machine_arn`, `tags`
    - Outputs: `rule_name`, `target_id`
  - `cloudwatch_logs/`: creates Glue log group with retention
    - Inputs: `name_prefix`, `retention_days`, `tags`
    - Output: `log_group_name`
  - `athena/`: sets up an Athena workgroup with result location
    - Inputs: `name_prefix`, `output_location`, `tags`
    - Output: `workgroup_name`
  - `sns_alarms/`: creates alerts topic
    - Inputs: `name_prefix`, `tags`
    - Outputs: `topic_name`, `topic_arn`
  - `lambda/`: creates notifier Lambda
    - Inputs: `name_prefix`, `role_arn`, `handler`, `runtime`, `package_path`, `env`, `tags`
    - Output: `lambda_name`

## Makefile (Terraform)

- Located at project root: `Makefile`
- Usage (ENV selects `infrastructure/terraform/env/<ENV>.tfvars`):
  - `make tf-init ENV=local_dev`
  - `make tf-fmt ENV=local_dev`
  - `make tf-validate ENV=local_dev`
  - `make tf-plan ENV=local_dev`
  - `make tf-apply ENV=dev`
  - `make tf-destroy ENV=uat`

Prerequisites: valid AWS credentials configured (env vars or profile). Bucket names must be globally unique; adjust `name_prefix` per environment/account before apply.
## Running the Bronze Ingestion Job

Start the Glue Python shell job to download the parquet file from CloudFront and upload it to your Bronze bucket via multipart upload. The job name is provisioned by Terraform from `infrastructure/terraform/modules/glue_job/main.tf` and exposed via the root output `glue_job_name`:

```
aws glue start-job-run --job-name dev_ingest_into_bronze

Notes:
- The job command is defined in `infrastructure/terraform/modules/glue_job/main.tf:142-149` with `name = "pythonshell"` and `script_location` pointing to the uploaded script in the Code bucket.
- Default arguments include metrics and CloudWatch logging as seen in `infrastructure/terraform/modules/glue_job/main.tf:150-157`.
- Schemas uploaded to the Code bucket set `content_type = "application/json"` (`infrastructure/terraform/modules/glue_job/main.tf:132`).
- If you hit `ConcurrentRunsExceededException`, list and stop active runs, then retry:
  aws glue get-job-runs --job-name dev_ingest_into_bronze --max-results 5
  aws glue batch-stop-job-run --job-name dev_ingest_into_bronze --job-run-ids <ids>
  aws glue start-job-run --job-name dev_ingest_into_bronze
```

The job now auto-discovers the Bronze bucket in-region via the AWS SDK; no bucket argument is required.

## Networking Architecture (Glue in Private Subnet)

Glue job ENIs are provisioned in a private subnet. Outbound access to S3 and public APIs flows through a NAT Gateway in a public subnet, then an Internet Gateway to the public internet.

Flow: `Glue job → Private Subnet → NAT Gateway (in public subnet) → Internet Gateway → Public Internet`

Key components:
- Private subnets: `map_public_ip_on_launch = false`, associated with a private route table
- NAT Gateway: created in the first public subnet with an Elastic IP
- Internet Gateway: attached to the VPC, targeted by the public route table
- Route tables:
  - Public route table: `0.0.0.0/0` → IGW
  - Private route table: `0.0.0.0/0` → NAT
- Security group: self-referencing TCP ingress, egress allows all outbound (`protocol = -1`)

Notes:
- No S3 VPC endpoint is provisioned; S3 access uses NAT egress.

# Local Development
- For local development of pyspark use [SQLFrame](https://github.com/eakmanrq/sqlframe) library
- For tuorial on pyspark use this [tutorial](https://colab.research.google.com/drive/1G894WS7ltIUTusWWmsCnF_zQhQqZCDOc)

# Further Reading
- [Learning Spark](https://learning.oreilly.com/library/view/learning-spark-2nd/9781492050032)
- [Glue](https://learning.oreilly.com/library/view/serverless-etl-and/9781800564985/)

# Future Projects
- Stock market data : https://marketstack.com/pricing with with Data Vault 2.0 modeling in Silver and Kimball dimensional modeling in Gold
- Use aws s3 endpoint avoiding public internet