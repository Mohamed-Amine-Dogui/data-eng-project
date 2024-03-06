import logging
import sys
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as f
from pyspark.sql import SparkSession, DataFrame
from typing import Tuple

# Version of the glue job
__version__ = "0.1.0"


def read_data(ss: SparkSession, path: str) -> DataFrame:
    """
    Main function that is called to read the data.
    """
    return ss.read.json(path)


def transform_data(ss: SparkSession, df: DataFrame) -> DataFrame:
    """
    Main function that is called to transform the data.
    """
    ss.conf.set("spark.sql.session.timeZone", "UTC")

    df = (
        df.withColumn(
            "event_timestamp_utc",
            f.to_timestamp(f.col("eventDate"), "yyyy-MM-dd'T'HH:mm:ssXXX"),
        )
        .withColumn("observed_unix", f.unix_timestamp(f.col("event_timestamp_utc")))
        .withColumn("observed_year", f.year(f.col("event_timestamp_utc")))
        .withColumn("observed_month", f.month(f.col("event_timestamp_utc")))
        .withColumn("observed_day", f.dayofmonth(f.col("event_timestamp_utc")))
        .withColumnRenamed("signalName", "signal_name")
        .withColumnRenamed("signalValue", "signal_value")
        .withColumn("processed_unix", f.unix_timestamp())
        .select(
            "vin",
            "observed_unix",
            "processed_unix",
            "observed_year",
            "observed_month",
            "observed_day",
            "signal_value",
            "signal_name",
        )
    )
    return df


def write_data(df: DataFrame, target_base_path: str) -> None:
    """
    Main function that is called to sink the data.
    """
    partition_by = ["signal_name", "observed_year", "observed_month"]
    df.repartition(*partition_by).write.mode("append").partitionBy(
        partition_by
    ).parquet(target_base_path)


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


if __name__ == "__main__":
    args = getResolvedOptions(
        sys.argv,
        [
            "JOB_NAME",
            # TODO: add arguments here that will be passed to the glue job
            "source_data_uri",
            "target_data_uri",
        ],
    )

    gc, job, logger = init_job(args)
    ss: SparkSession = gc.spark_session

    # Read data from catalog
    input_df: DataFrame = read_data(ss, args.get("source_data_uri"))

    # Run business logic / transformations
    transformed_df: DataFrame = transform_data(ss, input_df)

    # Save data
    write_data(transformed_df, args.get("target_data_uri"))

    job.commit()
