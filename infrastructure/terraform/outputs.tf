output "bronze_bucket" { value = module.s3_data_lake.bronze_bucket }
output "silver_bucket" { value = module.s3_data_lake.silver_bucket }
output "gold_bucket" { value = module.s3_data_lake.gold_bucket }
output "code_bucket" { value = module.s3_data_lake.code_bucket }

output "glue_role_arn" { value = module.glue_bronze_job.glue_role_arn }
output "glue_job_name" { value = module.glue_bronze_job.job_name }

output "glue_database" { value = module.glue_catalog.database_name }

## Phase 2 outputs commented out
# output "state_machine_arn" { value = module.step_functions.state_machine_arn }

# output "event_rule_name" { value = module.eventbridge.rule_name }
# output "event_target_id" { value = module.eventbridge.target_id }

# output "log_group_name" { value = module.cloudwatch_logs.log_group_name }

# output "athena_workgroup_name" { value = module.athena.workgroup_name }

# output "alerts_topic_name" { value = module.sns_alarms.topic_name }
# output "alerts_topic_arn" { value = module.sns_alarms.topic_arn }

# output "lambda_name" { value = module.lambda.lambda_name }
