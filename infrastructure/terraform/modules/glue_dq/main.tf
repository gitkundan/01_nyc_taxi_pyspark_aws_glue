resource "aws_glue_data_quality_ruleset" "bronze" {
  name    = "${var.name_prefix}_bronze_ruleset"
  ruleset = file(var.bronze_ruleset_path)
  tags    = var.tags
}
