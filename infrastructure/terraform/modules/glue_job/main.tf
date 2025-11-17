resource "aws_iam_role" "glue_role" {
  name               = "${var.name_prefix}-${var.component}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "glue_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

## Removed AmazonS3FullAccess; rely on AWSGlueServiceRole and bucket policies/least privilege

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${var.code_bucket_name}/glue/scripts/*",
      "arn:aws:s3:::${var.code_bucket_name}/glue/schemas/*",
    ]
  }

  statement {
    actions = ["s3:PutObject"]
    resources = [
      "arn:aws:s3:::${var.bronze_bucket_name}/*",
    ]
  }
  statement {
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }
  statement {
    actions   = ["s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::*"]
  }
}

resource "aws_iam_policy" "s3_access" {
  name   = "${var.name_prefix}-${var.component}-glue-s3"
  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_role_policy_attachment" "glue_s3_access" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Network: run Glue inside VPC subnet via a Glue connection
resource "aws_security_group" "glue_job" {
  name        = "${var.name_prefix}-${var.component}-glue-sg"
  description = "Security group for Glue job network access"
  vpc_id      = var.vpc_id
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.egress_cidr_block]
  }
  tags = var.tags
}


data "aws_subnet" "selected" {
  id = var.subnet_id
}

resource "aws_glue_connection" "vpc" {
  name            = "${var.name_prefix}-${var.component}-glue-vpc"
  connection_type = "NETWORK"
  physical_connection_requirements {
    availability_zone      = data.aws_subnet.selected.availability_zone
    subnet_id              = var.subnet_id
    security_group_id_list = [aws_security_group.glue_job.id]
  }
}

locals {
  scripts = fileset(var.scripts_source_dir, "**/*.py")
}

resource "aws_s3_object" "glue_scripts" {
  for_each     = toset(local.scripts)
  bucket       = var.code_bucket_name
  key          = "${var.scripts_dest_prefix}/${each.value}"
  source       = "${var.scripts_source_dir}/${each.value}"
  content_type = "text/x-python"
  etag         = filemd5("${var.scripts_source_dir}/${each.value}")
}



# Glue job: 01_get_nyc_taxi_data (manual-run)
resource "aws_glue_job" "this" {
  name        = var.job_name
  role_arn    = aws_iam_role.glue_role.arn
  connections = [aws_glue_connection.vpc.name]
  command {
    name            = "pythonshell"
    script_location = "s3://${var.code_bucket_name}/${var.job_script_s3_key}"
    python_version  = var.python_shell_version
  }
  max_capacity = 1
  default_arguments = merge(
    {
      "--enable-metrics"                   = "true",
      "--enable-continuous-cloudwatch-log" = "true",
    },
    var.job_default_arguments
  )
  tags       = var.tags
  depends_on = [aws_s3_object.glue_scripts]
}
