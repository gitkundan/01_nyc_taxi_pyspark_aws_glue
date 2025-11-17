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
  source          = "./modules/networking"
  name            = local.name_prefix
  cidr_block      = var.vpc_cidr
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets
  tags            = var.tags
}

module "s3_data_lake" {
  source      = "./modules/s3_data_lake"
  name_prefix = local.name_prefix
  tags        = var.tags
}

module "glue_catalog" {
  source        = "./modules/glue_catalog"
  database_name = var.database_name
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
  source         = "./modules/iam"
  name_prefix    = local.name_prefix
  tags           = var.tags
  oidc_subject   = var.oidc_subject
  aws_account_id = var.aws_account_id
}

## Bronze Glue Job: 01_ingest_raw_file (Python shell)
module "glue_bronze_job" {
  source                = "./modules/glue_job"
  name_prefix           = local.name_prefix
  component             = "bronze"
  tags                  = var.tags
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.vpc.private_subnet_ids[0]
  egress_cidr_block     = "0.0.0.0/0"
  code_bucket_name      = module.s3_data_lake.code_bucket
  bronze_bucket_name    = module.s3_data_lake.bronze_bucket
  scripts_source_dir    = "${path.module}/../..//src"
  scripts_dest_prefix   = "glue/scripts"
  job_name              = "${var.job_name_prefix}_ingest_into_bronze"
  job_script_s3_key     = "glue/scripts/bronze/bronze_ingestion_job.py"
  python_shell_version  = "3.9"
  job_default_arguments = {}
}

## Silver Glue Job removed per requirement to keep only Python shell job




module "athena" {
  source          = "./modules/athena"
  name_prefix     = local.name_prefix
  output_location = var.athena_output_location
  tags            = var.tags
}
