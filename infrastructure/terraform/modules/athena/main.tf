resource "aws_athena_workgroup" "analytics" {
  name        = var.name_prefix != null ? "${var.name_prefix}_wg" : "default_wg"
  description = "Analytics workgroup for ${var.name_prefix}"
  configuration {
    enforce_workgroup_configuration    = false
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 0
    result_configuration {
      output_location = var.output_location
    }
  }
  tags = var.tags
}
