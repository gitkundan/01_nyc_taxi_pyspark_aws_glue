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

variable "vpc_private_subnets" {
  type = list(string)
  default = [
    "10.0.101.0/24",
    "10.0.102.0/24"
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


## IAM
variable "oidc_subject" {
  type    = string
  default = "repo:your_org/your_repo:ref:refs/heads/*"
}

variable "aws_account_id" {
  type = string
}

############################################
# Phase 2 variables (commented out)
############################################









## Athena
variable "athena_output_location" {
  type    = string
  default = "s3://nyc-taxi-code/athena-results/"
}



## Glue job naming
variable "job_name_prefix" {
  type    = string
  default = "dev"
}
