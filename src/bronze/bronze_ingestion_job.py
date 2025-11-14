import sys
import logging
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType
from pyspark.sql.functions import col, trim, upper, length, regexp_extract

logger = logging.getLogger("bronze_ingestion")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

args = getResolvedOptions(sys.argv, [
    "JOB_NAME",
    "BRONZE_BUCKET",
    "SILVER_BUCKET",
    "INPUT_KEY",
    "OUTPUT_PREFIX",
    "DB_NAME",
    "TABLE_NAME",
])

spark = SparkSession.builder.appName(args["JOB_NAME"]).getOrCreate()
glue = GlueContext(spark)
job = Job(glue)
job.init(args["JOB_NAME"], args)

schema = StructType([
    StructField("country_code", StringType(), False),
    StructField("country_name", StringType(), True),
    StructField("currency_code", StringType(), False),
    StructField("currency_name", StringType(), True),
])

src_path = f"s3://{args['BRONZE_BUCKET']}/{args['INPUT_KEY']}"
dst_path = f"s3://{args['SILVER_BUCKET']}/{args['OUTPUT_PREFIX']}"
invalid_dst_path = f"s3://{args['BRONZE_BUCKET']}/seeds/country_code_currency_mapping_invalid/"

df = (
    spark.read.schema(schema)
    .option("header", "true")
    .csv(src_path)
)

total = df.count()
logger.info("read_rows=%d src=%s", total, src_path)

clean = (
    df.select(
        trim(col("country_code")).alias("country_code"),
        trim(col("country_name")).alias("country_name"),
        upper(trim(col("currency_code"))).alias("currency_code"),
        trim(col("currency_name")).alias("currency_name"),
    )
)

valid_cc = regexp_extract(col("country_code"), r"^[A-Za-z]{2,3}$", 0) != ""
valid_cur = regexp_extract(col("currency_code"), r"^[A-Z]{3}$", 0) != ""
is_valid = valid_cc & valid_cur

valid_df = clean.filter(is_valid)
invalid_df = clean.filter(~is_valid)

valid = valid_df.count()
invalid = invalid_df.count()
logger.info("valid_rows=%d invalid_rows=%d", valid, invalid)

valid_df.write.mode("overwrite").parquet(dst_path)
logger.info("wrote_rows=%d dst=%s", valid, dst_path)

# Write invalid rows to quarantine in Bronze
invalid_df.write.mode("overwrite").parquet(invalid_dst_path)
logger.info("quarantined_rows=%d dst=%s", invalid, invalid_dst_path)

# Update Glue Catalog: valid table
from awsglue.dynamicframe import DynamicFrame
valid_dyn = DynamicFrame.fromDF(valid_df, glue, "valid_country_currency")
valid_sink = glue.getSink(
    path=dst_path,
    connection_type="s3",
    updateBehavior="LOG",
    enableUpdateCatalog=True,
    partitionKeys=[],
)
valid_sink.setCatalogInfo(catalogDatabase=args["DB_NAME"], catalogTableName=args["TABLE_NAME"])
valid_sink.setFormat("glueparquet")
valid_sink.writeFrame(valid_dyn)

# Update Glue Catalog: invalid table (optional)
invalid_dyn = DynamicFrame.fromDF(invalid_df, glue, "invalid_country_currency")
invalid_sink = glue.getSink(
    path=invalid_dst_path,
    connection_type="s3",
    updateBehavior="LOG",
    enableUpdateCatalog=True,
    partitionKeys=[],
)
invalid_sink.setCatalogInfo(catalogDatabase=args["DB_NAME"], catalogTableName=f"{args['TABLE_NAME']}_invalid")
invalid_sink.setFormat("glueparquet")
invalid_sink.writeFrame(invalid_dyn)

# Create/Update Glue Catalog table via DynamicFrame write
dyn = DynamicFrame.fromDF(valid_df, glue, "country_currency")
glue_context = glue
glue_context.write_dynamic_frame.from_options(
    frame=dyn,
    connection_type="s3",
    connection_options={
        "path": dst_path,
        "partitionKeys": []
    },
    format="glueparquet",
    format_options={
        "compression": "snappy"
    },
    transformation_ctx="write_to_silver"
)

job.commit()
