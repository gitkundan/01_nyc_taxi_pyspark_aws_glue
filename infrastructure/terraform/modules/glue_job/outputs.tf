output "glue_role_arn" { value = aws_iam_role.glue_role.arn }
output "job_name" { value = aws_glue_job.this.name }
