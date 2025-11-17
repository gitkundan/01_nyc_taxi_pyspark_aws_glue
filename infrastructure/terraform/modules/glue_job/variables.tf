variable "name_prefix" { type = string }
variable "component" { type = string }
variable "tags" { type = map(string) }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "egress_cidr_block" { type = string }
variable "code_bucket_name" { type = string }
variable "bronze_bucket_name" { type = string }

# Bulk upload of Glue scripts from local src directory to code bucket
variable "scripts_source_dir" { type = string }
variable "scripts_dest_prefix" { type = string }

# Glue job configuration
variable "job_name" { type = string }
variable "job_script_s3_key" { type = string }
variable "python_shell_version" { type = string }

# Parameters for external NYC TLC copy job
variable "job_default_arguments" { type = map(string) }
