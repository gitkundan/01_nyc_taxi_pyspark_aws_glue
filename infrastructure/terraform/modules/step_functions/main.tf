resource "aws_sfn_state_machine" "pipeline" {
  name       = "${var.name_prefix}-pipeline"
  role_arn   = var.role_arn
  definition = file(var.definition_path)
  tags       = var.tags
}
