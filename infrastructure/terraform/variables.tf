variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "default"
}

# name uniquely created for s3 uniqueness
// this will be part of bucket name
variable "name_prefix" {
  type    = string
  default = "nyc-taxi"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "nyc-taxi"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# VPC and Subnet
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_public_subnets" {
  type = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

## Glue Catalog
variable "database_name" {
  type    = string
  default = "nyc_taxi"
}

variable "bronze_location" {
  type    = string
  default = "s3://nyc-taxi-bronze/bronze/"
}

variable "bronze_columns" {
  type = list(object({ name = string, type = string }))
  default = [
    { name = "vendor_id", type = "string" },
    { name = "pickup_datetime", type = "timestamp" },
    { name = "dropoff_datetime", type = "timestamp" },
    { name = "passenger_count", type = "int" }
  ]
}

## Glue Job
variable "data_bucket_prefix" {
  type    = string
  default = "nyc-taxi-data"
}

variable "code_bucket_prefix" {
  type    = string
  default = "nyc-taxi-code"
}

variable "script_location_bronze" {
  type    = string
  default = "s3://nyc-taxi-code/glue/scripts/bronze.py"
}

## IAM
variable "oidc_subject" {
  type    = string
  default = "repo:your_org/your_repo:ref:refs/heads/*"
}

############################################
# Phase 2 variables (commented out)
############################################

## Glue DQ (phase 2)
variable "bronze_ruleset_path" { type = string }

# ## Step Functions (phase 2)
# variable "sfn_role_arn" { type = string }
# variable "step_functions_definition_path" { type = string }

# ## EventBridge (phase 2)
# variable "cron" { type = string }

# ## CloudWatch Logs (phase 2)
# variable "retention_days" { type = number }

## Athena
variable "athena_output_location" {
  type    = string
  default = "s3://nyc-taxi-code/athena-results/"
}

# ## Lambda (phase 2)
# variable "lambda_role_arn" { type = string }
# variable "lambda_handler" { type = string }
# variable "lambda_runtime" { type = string }
# variable "lambda_package_path" { type = string }
# variable "lambda_env" { type = map(string) }
