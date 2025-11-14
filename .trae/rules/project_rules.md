# General Rules
opening a new terminal and executing jobs will require user to enter password; give sufficient time to user for this

# Terraform rules

- Prefer small, composable modules. Keep `main.tf`, `variables.tf`, `outputs.tf`, and `versions.tf` per module.
- Use a remote backend (e.g., `S3` with `DynamoDB` locks) and separate state per environment.
- Pin provider versions in `versions.tf` with `required_providers`; pin Terraform in `required_version`.
- Treat inputs as typed contracts. Add `validation` on variables and mark secrets `sensitive = true`.
- Never hardcode credentials or ARNs. Pass via variables, data sources, or environment.
- Name resources predictably: `project-env-component-purpose`. Tag every resource with `Environment`, `Project`, `Owner`.
- Use `depends_on` sparingly; prefer implicit references via arguments.
- Quality gates: run `terraform fmt -check`, `terraform validate`, `terraform plan -out tfplan.bin` before applying. Prefer `tflint` and `checkov` if available.
- Debug with `TF_LOG=INFO` and `TF_LOG_PATH=terraform.log`; inspect diffs via `terraform show tfplan.bin`.

```tf
# Example: Glue job module wiring (moderate comments)
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "job_name" {
  type        = string
  description = "Logical name of the Glue job"
  validation {
    condition     = length(var.job_name) > 2
    error_message = "job_name must be at least 3 characters."
  }
}

variable "script_s3_path" {
  type        = string
  description = "S3 URI to the Glue script (s3://bucket/key.py)"
}

variable "role_arn" {
  type        = string
  description = "IAM role ARN assumed by the Glue job"
  sensitive   = true
}

locals {
  common_tags = {
    Project     = "nyc-taxi"
    Environment = "${terraform.workspace}"
    ManagedBy   = "terraform"
  }
}

resource "aws_glue_job" "this" {
  name     = var.job_name
  role_arn = var.role_arn

  command {
    script_location = var.script_s3_path
    python_version  = "3"
  }

  glue_version     = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"   # Better observability
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--TempDir"                           = "s3://my-bucket/tmp/"
  }

  tags = local.common_tags
}
```

# Pyspark rules

- Prefer the DataFrame API and Spark SQL over RDDs; avoid Python UDFs unless necessary.
- Define explicit schemas for ingestion; avoid `inferSchema=true` in production.
- Partition data intentionally; pick column order and types to match downstream queries.
- Tune shuffles: set `spark.sql.shuffle.partitions` thoughtfully; prefer `broadcast` joins when safe.
- Use `repartition()` for upscaling parallelism and `coalesce()` for downscaling writes.
- Add structured logging via Python `logging`; log input paths, counts, and partitioning.
- Fail fast on bad input; validate columns and dtypes before transformations.
- Keep business logic in small, testable functions; minimize side effects.
- Validate with `.explain(mode="formatted")`, `.printSchema()`, and representative samples.
- Test locally with a `SparkSession` in `local[*]` and real-world edge cases.

```python
# Skeleton: robust Spark job (moderate comments)
import argparse
import logging
from typing import Tuple

from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import col, to_timestamp, year, month, dayofmonth
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, TimestampType

logger = logging.getLogger("nyc_taxi")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

SCHEMA = StructType([
    StructField("vendor_id", StringType(), False),
    StructField("pickup_datetime", StringType(), False),
    StructField("dropoff_datetime", StringType(), False),
    StructField("passenger_count", IntegerType(), True),
])

def build_spark(app_name: str) -> SparkSession:
    return (
        SparkSession.builder
        .appName(app_name)
        .config("spark.sql.shuffle.partitions", "200")
        .config("spark.sql.adaptive.enabled", "true")
        .getOrCreate()
    )

def read_source(spark: SparkSession, input_path: str) -> DataFrame:
    df = (
        spark.read.schema(SCHEMA)
        .option("header", "true")
        .csv(input_path)
    )
    logger.info("Read %d rows from %s", df.count(), input_path)
    return df

def transform(df: DataFrame) -> DataFrame:
    out = (
        df
        .withColumn("pickup_ts", to_timestamp(col("pickup_datetime")))
        .withColumn("dropoff_ts", to_timestamp(col("dropoff_datetime")))
        .withColumn("year", year(col("pickup_ts")))
        .withColumn("month", month(col("pickup_ts")))
        .withColumn("day", dayofmonth(col("pickup_ts")))
    )
    out.explain(mode="formatted")  # Aids debuggability
    return out

def write_s3(df: DataFrame, output_path: str) -> None:
    (
        df.repartition("year", "month")
        .write.mode("overwrite")
        .partitionBy("year", "month", "day")
        .parquet(output_path)
    )
    logger.info("Wrote output to %s", output_path)

def main(args: argparse.Namespace) -> int:
    spark = build_spark("nyc_taxi_transform")
    try:
        src = read_source(spark, args.input)
        dst = transform(src)
        write_s3(dst, args.output)
        return 0
    finally:
        spark.stop()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    exit(main(parser.parse_args()))
```

# AWS Glue rules

- Prefer Glue 4.0 or newer; Python 3.10; use `GlueContext` and convert `DynamicFrame` to DataFrame when needed.
- Pass parameters via `getResolvedOptions`; enable job bookmarks for incremental loads.
- Use catalog sources with pushdown predicates; partition outputs and set a temporary S3 directory.
- Log to CloudWatch (`--enable-continuous-cloudwatch-log=true`); include metrics counters.
- Keep IAM least-privilege; encrypt S3 buckets and logs; never hardcode secrets.
- Size DPUs conservatively and scale after profiling; avoid unnecessary conversions between DynamicFrame and DataFrame.
- Validate schemas at the edge and track bad-record counts.

```python
# Skeleton: Glue job with bookmarks and logging (moderate comments)
import sys
import logging
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession

logger = logging.getLogger("glue")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

args = getResolvedOptions(sys.argv, [
    "JOB_NAME", "SOURCE_DB", "SOURCE_TABLE", "OUTPUT_S3"
])

spark = SparkSession.builder.appName(args["JOB_NAME"]).getOrCreate()
glue = GlueContext(spark)
job = Job(glue)
job.init(args["JOB_NAME"], args)

dyf = glue.create_dynamic_frame.from_catalog(
    database=args["SOURCE_DB"],
    table_name=args["SOURCE_TABLE"],
    push_down_predicate="year>=2024",  # Example predicate for incremental reads
)

df = dyf.toDF()
logger.info("Input count: %d", df.count())

# Example transformation: rename and partition
out = df.withColumnRenamed("vendor_id", "vendor")

out.write.mode("overwrite").partitionBy("year", "month").parquet(args["OUTPUT_S3"])
logger.info("Wrote output to %s", args["OUTPUT_S3"])

job.commit()
```

```tf
# Terraform: wiring default arguments for the Glue job
resource "aws_glue_job" "nyc_taxi" {
  name        = "nyc-taxi-transform"
  role_arn    = var.role_arn
  glue_version = "4.0"

  command {
    script_location = var.script_s3_path
    python_version  = "3"
  }

  default_arguments = {
    "--enable-continuous-cloudwatch-log" = "true"
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--SOURCE_DB"                         = "nyc_taxi"
    "--SOURCE_TABLE"                      = "rides"
    "--OUTPUT_S3"                         = "s3://my-bucket/nyc-taxi/out/"
  }
}
```
