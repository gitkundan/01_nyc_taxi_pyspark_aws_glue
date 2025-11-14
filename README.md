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
  - `vpc/`: creates VPC and public subnets
    - Inputs: `name`, `cidr_block`, `tags`, `public_subnets`
    - Outputs: `vpc_id`, `public_subnet_ids`
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
