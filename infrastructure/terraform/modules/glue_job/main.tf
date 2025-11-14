resource "aws_iam_role" "glue_role" {
  name               = "${var.name_prefix}-glue-role"
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

# Optional: attach AWS managed policy for full S3 access
resource "aws_iam_role_policy_attachment" "glue_s3_full_access" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Network: run Glue inside VPC subnet via a Glue connection
resource "aws_security_group" "glue_job" {
  name        = "${var.name_prefix}-glue-sg"
  description = "Security group for Glue job network access"
  vpc_id      = var.vpc_id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

resource "aws_glue_connection" "vpc" {
  name            = "${var.name_prefix}-glue-vpc"
  connection_type = "NETWORK"
  connection_properties = {
    JDBC_ENFORCE_SSL = "false"
  }
  physical_connection_requirements {
    availability_zone      = data.aws_subnet.selected.availability_zone
    subnet_id              = var.subnet_id
    security_group_id_list = [aws_security_group.glue_job.id]
  }
  depends_on = [aws_security_group.glue_job]
}

# Upload the local Python script to the code bucket
resource "aws_s3_object" "bronze_script" {
  bucket       = var.code_bucket_name
  key          = var.script_s3_key
  source       = var.script_source_path
  content_type = "text/x-python"
  etag         = filemd5(var.script_source_path)
}

resource "aws_glue_job" "bronze" {
  name        = "${var.name_prefix}-bronze"
  role_arn    = aws_iam_role.glue_role.arn
  connections = [aws_glue_connection.vpc.name]
  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.code_bucket_name}/${var.script_s3_key}"
  }
  glue_version      = "5.0"
  number_of_workers = 2
  worker_type       = "G.1X"
  default_arguments = {
    "--enable-job-insights" = "true"
    "--enable-metrics"      = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--BRONZE_BUCKET"       = var.bronze_bucket_name
    "--SILVER_BUCKET"       = var.silver_bucket_name
    "--INPUT_KEY"           = var.input_key
    "--OUTPUT_PREFIX"       = var.output_prefix
    "--DB_NAME"             = var.db_name
    "--TABLE_NAME"          = var.table_name
  }
  tags       = var.tags
  depends_on = [aws_s3_object.bronze_script]
}
