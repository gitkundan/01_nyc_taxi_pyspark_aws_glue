resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${var.name_prefix}-daily"
  schedule_expression = var.cron
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "sfn" {
  rule      = aws_cloudwatch_event_rule.daily.name
  target_id = "${var.name_prefix}-sfn"
  arn       = var.state_machine_arn
}
