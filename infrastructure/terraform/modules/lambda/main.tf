resource "aws_lambda_function" "notifier" {
  function_name = "${var.name_prefix}-notifier"
  role          = var.role_arn
  handler       = var.handler
  runtime       = var.runtime
  filename      = var.package_path
  timeout       = 30
  environment {
    variables = var.env
  }
  tags = var.tags
}
