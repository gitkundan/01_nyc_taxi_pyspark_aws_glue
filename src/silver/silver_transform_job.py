import sys
import json
import logging
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp, lit, year, month

logger = logging.getLogger("silver_transform")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# Glue job name: 02_transform_silver

args = getResolvedOptions(sys.argv, [
    "JOB_NAME",
    "SILVER_BUCKET",
    "INPUT_PREFIX",
    "OUTPUT_PREFIX",
    "SCHEMA_PATH",
])

spark = SparkSession.builder.appName(args["JOB_NAME"]).getOrCreate()
glue = GlueContext(spark)
job = Job(glue)
job.init(args["JOB_NAME"], args)

src_path = f"s3://{args['SILVER_BUCKET']}/{args['INPUT_PREFIX']}"
dst_path = f"s3://{args['SILVER_BUCKET']}/{args['OUTPUT_PREFIX']}"

df = spark.read.parquet(src_path)
logger.info("read_rows=%d src=%s", df.count(), src_path)

# Load column schema from JSON and cast
schema_json = spark.read.text(args["SCHEMA_PATH"]).collect()[0][0]
spec = json.loads(schema_json)
typed = df
for colspec in spec.get("columns", []):
    name = colspec["name"]
    dtype = colspec["type"].lower()
    if dtype == "timestamp":
        typed = typed.withColumn(name, to_timestamp(col(name)))
    else:
        typed = typed.withColumn(name, col(name).cast(dtype))

# Rule: exceptions where not present in Jan-2025
with_year_month = typed.withColumn("year", year(col("pickup_datetime"))).withColumn("month", month(col("pickup_datetime")))
exceptions = with_year_month.filter(~((col("year") == lit(2025)) & (col("month") == lit(1))))
valid = with_year_month.filter((col("year") == lit(2025)) & (col("month") == lit(1)))

valid.write.mode("overwrite").parquet(dst_path)
exceptions.write.mode("overwrite").parquet(f"{dst_path}exceptions.parquet")
logger.info("wrote_valid_rows=%d dst=%s", valid.count(), dst_path)
logger.info("wrote_exception_rows=%d dst=%s", exceptions.count(), f"{dst_path}exceptions.parquet")

job.commit()
