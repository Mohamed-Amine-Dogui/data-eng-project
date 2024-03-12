import logging
import os
import sys
from datetime import datetime, timedelta
from typing import Tuple

import boto3
from awsglue import DynamicFrame
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql import functions as f
from pyspark.sql.functions import current_date
from pyspark.sql.types import StructType, StructField, StringType, IntegerType


# Version of the glue job
__version__ = "0.2.0"


def create_df():
    # Dummy data generation
    data = [
        {"name": "John Doe", "date": "2024-03-10", "order_id": 1001, "price": 150},
        {"name": "Jane Doe", "date": "2024-03-11", "order_id": 1002, "price": 200},
        {"name": "Jim Beam", "date": "2024-03-12", "order_id": 1003, "price": 250},
        {"name": "Jenny Craig", "date": "2024-03-13", "order_id": 1004, "price": 300},
        {"name": "Jack Daniels", "date": "2024-03-14", "order_id": 1005, "price": 350},
    ]

    # Define the schema corresponding to the data structure
    schema = StructType(
        [
            StructField("name", StringType(), True),
            StructField(
                "date", StringType(), True
            ),  # or DateType() if converting string to date
            StructField("order_id", IntegerType(), True),
            StructField("price", IntegerType(), True),
        ]
    )

    # Create DataFrame
    df = ss.createDataFrame(data, schema)

    return df


def init_job(job_args: dict) -> Tuple[GlueContext, Job, logging.Logger]:
    """
    Initialize glue job
    :param job_args: Arguments
    :return: glue_context, job
    """
    # Initialize glue_context
    sc: SparkContext = SparkContext()
    glue_context: GlueContext = GlueContext(sc)

    # Initialize job
    job = Job(glue_context)
    job.init(job_args["JOB_NAME"], job_args)

    # Logger
    logger: logging.Logger = glue_context.get_logger()
    logger.info("Glue job '{}' started...".format(job_args["JOB_NAME"]))
    for key, value in job_args.items():
        logger.info(f"Parameter '{key}': {value}")

    return glue_context, job, logger


### TODO
if __name__ == "__main__":
    args = getResolvedOptions(
        sys.argv,
        [
            "JOB_NAME",
            "TARGET_BUCKET_NAME",
            "STAGE",
        ],
    )
    target_bucket_name = args["TARGET_BUCKET_NAME"]
    stage = args["STAGE"]

    target_s3_path = os.path.join("s3://", target_bucket_name, "processed_data")

    gc, job, logger = init_job(args)
    # build a spark session
    ss: SparkSession = gc.spark_session

    # get current timestamp in this format "%Y-%m-%d"
    event_timestamp = current_date()

    s3 = boto3.resource("s3")
    client = boto3.client("s3")
    bucket = s3.Bucket(target_bucket_name)

    # Define the S3 path where the CSV file will be saved
    s3_output_path = os.path.join(
        "s3://", target_bucket_name, f"data_{datetime.now().strftime('%Y-%m-%d')}.csv"
    )

    df = create_df()
    df.write.mode("overwrite").csv(s3_output_path, header=True)

    # Commit the job to indicate completion
    job.commit()
    logger.info(f"CSV file successfully written to {s3_output_path}")

    job.commit()
