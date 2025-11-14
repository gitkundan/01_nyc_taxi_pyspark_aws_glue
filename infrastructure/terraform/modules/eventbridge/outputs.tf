output "rule_name" { value = aws_cloudwatch_event_rule.daily.name }
output "target_id" { value = aws_cloudwatch_event_target.sfn.target_id }
