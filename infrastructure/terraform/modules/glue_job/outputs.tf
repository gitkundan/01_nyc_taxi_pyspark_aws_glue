output "glue_role_arn" { value = aws_iam_role.glue_role.arn }
output "bronze_job_name" { value = aws_glue_job.bronze.name }
