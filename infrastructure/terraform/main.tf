terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  # Stable, stateful unique suffix
  unique_suffix = random_id.suffix.hex
  name_prefix   = "${var.name_prefix}-${local.unique_suffix}"
}

module "vpc" {
  source         = "./modules/vpc"
  name           = local.name_prefix
  cidr_block     = var.vpc_cidr
  public_subnets = var.vpc_public_subnets
  tags           = var.tags
}

module "s3_data_lake" {
  source      = "./modules/s3_data_lake"
  name_prefix = local.name_prefix
  tags        = var.tags
}

# Upload seed CSV to Bronze bucket
resource "aws_s3_object" "seed_country_currency" {
  bucket       = module.s3_data_lake.bronze_bucket
  key          = "seeds/country_code_currency_mapping.csv"
  source       = "${path.module}/../..//src/seeds/country_code_currency_mapping.csv"
  content_type = "text/csv"
  etag         = filemd5("${path.module}/../..//src/seeds/country_code_currency_mapping.csv")
}

module "glue_catalog" {
  source          = "./modules/glue_catalog"
  database_name   = var.database_name
  bronze_location = "s3://${module.s3_data_lake.bronze_bucket}/bronze/"
  bronze_columns  = var.bronze_columns
}

# module "glue_dq" {
#   source              = "./modules/glue_dq"
#   name_prefix         = var.name_prefix
#   bronze_ruleset_path = var.bronze_ruleset_path
#   tags                = var.tags
# }

# module "glue_dq" {
#   source              = "./modules/glue_dq"
#   name_prefix         = var.name_prefix
#   bronze_ruleset_path = var.bronze_ruleset_path
#   tags                = var.tags
# }

module "iam" {
  source       = "./modules/iam"
  name_prefix  = local.name_prefix
  tags         = var.tags
  oidc_subject = var.oidc_subject
}

module "glue_job" {
  source                 = "./modules/glue_job"
  name_prefix            = local.name_prefix
  tags                   = var.tags
  data_bucket_prefix     = var.data_bucket_prefix
  code_bucket_prefix     = var.code_bucket_prefix
  script_location_bronze = var.script_location_bronze
  vpc_id                 = module.vpc.vpc_id
  subnet_id              = module.vpc.public_subnet_ids[0]
  egress_cidr_block      = var.vpc_cidr
  code_bucket_name       = module.s3_data_lake.code_bucket
  script_s3_key          = "glue/scripts/bronze_ingestion_job.py"
  script_source_path     = "${path.module}/../..//src/bronze/bronze_ingestion_job.py"
  bronze_bucket_name     = module.s3_data_lake.bronze_bucket
  silver_bucket_name     = module.s3_data_lake.silver_bucket
  input_key              = "seeds/country_code_currency_mapping.csv"
  output_prefix          = "seeds/country_code_currency_mapping/"
  db_name                = module.glue_catalog.database_name
  table_name             = "country_currency"
  depends_on             = [aws_s3_object.seed_country_currency]
}

# Glue crawler to scan Silver seeds prefix
module "glue_crawler" {
  source         = "./modules/glue_crawler"
  name_prefix    = local.name_prefix
  database_name  = module.glue_catalog.database_name
  role_arn       = module.glue_job.glue_role_arn
  s3_target_path = "s3://${module.s3_data_lake.silver_bucket}/seeds/country_code_currency_mapping/"
  tags           = var.tags
}

# module "step_functions" {
#   source          = "./modules/step_functions"
#   name_prefix     = var.name_prefix
#   role_arn        = var.sfn_role_arn
#   definition_path = var.step_functions_definition_path
#   tags            = var.tags
# }

# module "eventbridge" {
#   source            = "./modules/eventbridge"
#   name_prefix       = var.name_prefix
#   cron              = var.cron
#   state_machine_arn = module.step_functions.state_machine_arn
#   tags              = var.tags
# }

# module "cloudwatch_logs" {
#   source         = "./modules/cloudwatch_logs"
#   name_prefix    = var.name_prefix
#   retention_days = var.retention_days
#   tags           = var.tags
# }

module "athena" {
  source          = "./modules/athena"
  name_prefix     = local.name_prefix
  output_location = var.athena_output_location
  tags            = var.tags
}

# module "sns_alarms" {
#   source      = "./modules/sns_alarms"
#   name_prefix = var.name_prefix
#   tags        = var.tags
# }

# module "lambda" {
#   source       = "./modules/lambda"
#   name_prefix  = var.name_prefix
#   role_arn     = var.lambda_role_arn
#   handler      = var.lambda_handler
#   runtime      = var.lambda_runtime
#   package_path = var.lambda_package_path
#   env          = var.lambda_env
#   tags         = var.tags
# }
