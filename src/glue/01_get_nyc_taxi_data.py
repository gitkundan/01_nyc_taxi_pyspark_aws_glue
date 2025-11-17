import sys
import logging
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession

logger = logging.getLogger("get_nyc_taxi_data")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

args = getResolvedOptions(sys.argv, [
    "JOB_NAME",
    "SOURCE_BUCKET",
    "DEST_BUCKET",
    "DEST_PREFIX",
    "SOURCE_KEY",
])

spark = SparkSession.builder.appName(args["JOB_NAME"]).getOrCreate()
glue = GlueContext(spark)
job = Job(glue)
job.init(args["JOB_NAME"], args)

source_path = f"s3://{args['SOURCE_BUCKET']}/{args['SOURCE_KEY']}"
filename = args['SOURCE_KEY'].split('/')[-1]
dest_path = f"s3://{args['DEST_BUCKET']}/{args['DEST_PREFIX']}{filename}"

logger.info("Copying %s -> %s", source_path, dest_path)

df = spark.read.parquet(source_path)
count = df.count()
logger.info("read_rows=%d src=%s", count, source_path)
df.write.mode("overwrite").parquet(dest_path)
logger.info("wrote_rows=%d dst=%s", count, dest_path)

job.commit()
