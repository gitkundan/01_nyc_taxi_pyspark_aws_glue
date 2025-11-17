import boto3
import logging
import requests
import time
from typing import Optional

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger(__name__)

def _find_bronze_bucket(region: str) -> str:
    s3 = boto3.client("s3")
    buckets = s3.list_buckets().get("Buckets", [])
    for b in buckets:
        name = b["Name"]
        loc = boto3.client("s3").get_bucket_location(Bucket=name).get("LocationConstraint")
        bucket_region = loc or "us-east-1"
        if bucket_region == region and name.endswith("-bronze"):
            return name
    raise RuntimeError("No bronze bucket found in region")


class S3ChunkedDownloader:
    def __init__(self, source_url: str, s3_bucket: str, output_key: str, chunk_size: int = 10 * 1024 * 1024, aws_region: Optional[str] = None) -> None:
        self.source_url = source_url
        self.s3_bucket = s3_bucket
        self.output_key = output_key
        self.chunk_size = chunk_size
        self.s3_client = boto3.client("s3", region_name=aws_region)
        self.multipart_upload = None
        self.parts = []
        self.total_size: Optional[int] = None
        self.uploaded_bytes: int = 0
        logger.info(
            f"Initialized downloader bucket={self.s3_bucket} key={self.output_key} region={aws_region} chunk_size={self.chunk_size}"
        )

    def download_and_upload(self) -> None:
        overall_start = time.time()
        try:
            self._initialize_multipart_upload()
            self._process_stream()
            self._complete_multipart_upload()
            overall_elapsed_ms = int((time.time() - overall_start) * 1000)
            logger.info(
                f"Upload completed parts={len(self.parts)} bytes={self.uploaded_bytes} duration_ms={overall_elapsed_ms}"
            )
        except Exception as e:
            logger.error(f"Operation failed: {e}")
            if self.multipart_upload:
                self.s3_client.abort_multipart_upload(Bucket=self.s3_bucket, Key=self.output_key, UploadId=self.multipart_upload["UploadId"])
            raise

    def _initialize_multipart_upload(self) -> None:
        self.multipart_upload = self.s3_client.create_multipart_upload(Bucket=self.s3_bucket, Key=self.output_key)
        logger.info(
            f"Initialized multipart upload upload_id={self.multipart_upload['UploadId']} bucket={self.s3_bucket} key={self.output_key}"
        )

    def _process_stream(self) -> None:
        with requests.Session() as session:
            connect_start = time.time()
            response = session.get(self.source_url, stream=True)
            connect_elapsed_ms = int((time.time() - connect_start) * 1000)
            logger.info(
                f"Source connection established url={self.source_url} status_code={response.status_code} connect_ms={connect_elapsed_ms}"
            )
            response.raise_for_status()
            content_length = response.headers.get("Content-Length")
            self.total_size = int(content_length) if content_length else None
            logger.info(
                f"Content length bytes={self.total_size if self.total_size is not None else 'unknown'}"
            )
            part_number = 1
            for chunk in response.iter_content(chunk_size=self.chunk_size):
                if chunk:
                    part_start = time.time()
                    self._upload_part(part_number, chunk)
                    part_elapsed_ms = int((time.time() - part_start) * 1000)
                    chunk_size_bytes = len(chunk)
                    self.uploaded_bytes += chunk_size_bytes
                    if self.total_size:
                        pct = (self.uploaded_bytes / self.total_size) * 100
                        logger.info(
                            f"Part uploaded part_number={part_number} size_bytes={chunk_size_bytes} elapsed_ms={part_elapsed_ms} progress={self.uploaded_bytes}/{self.total_size} ({pct:.2f}%)"
                        )
                    else:
                        logger.info(
                            f"Part uploaded part_number={part_number} size_bytes={chunk_size_bytes} elapsed_ms={part_elapsed_ms} progress_bytes={self.uploaded_bytes}"
                        )
                    part_number += 1

    def _upload_part(self, part_number: int, chunk: bytes) -> None:
        response = self.s3_client.upload_part(Body=chunk, Bucket=self.s3_bucket, Key=self.output_key, UploadId=self.multipart_upload["UploadId"], PartNumber=part_number)
        self.parts.append({"PartNumber": part_number, "ETag": response["ETag"]})
        logger.info(
            f"Upload part acknowledged part_number={part_number} etag={response['ETag']}"
        )

    def _complete_multipart_upload(self) -> None:
        self.s3_client.complete_multipart_upload(Bucket=self.s3_bucket, Key=self.output_key, UploadId=self.multipart_upload["UploadId"], MultipartUpload={"Parts": self.parts})
        logger.info("Completed multi-part upload")


def main() -> None:
    source_url = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-01.parquet"
    object_key = source_url.split("/")[-1]
    bronze_bucket = _find_bronze_bucket("us-east-1")
    downloader = S3ChunkedDownloader(
        source_url=source_url,
        s3_bucket=bronze_bucket,
        output_key=object_key,
        chunk_size=10 * 1024 * 1024,
        aws_region="us-east-1",
    )
    downloader.download_and_upload()

if __name__ == "__main__":
    main()
