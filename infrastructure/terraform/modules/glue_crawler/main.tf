resource "aws_glue_crawler" "this" {
  name          = "${var.name_prefix}-crawler"
  role          = var.role_arn
  database_name = var.database_name
  s3_target {
    path = var.s3_target_path
  }
  configuration = jsonencode({
    Version  = 1.0,
    Grouping = { TableLevelConfiguration = 3 }
  })
  tags = var.tags
}
