# from etl.glue.fstream_glue.main import (
#     read_data,
#     create_subscription_df,
#     create_msg_header_df,
#     create_checkpoint_dataframe,
#     create_general_info_dataframe,
#     create_parts_dataframe,
#     union_dataframes,
# )
#
# from tests.setup.test_case import TestTable, TestCase
# import localstack_client
# import localstack_client.session
# from contextlib import contextmanager
# import sys
# import os
# from datetime import datetime
# from unittest.mock import call
# import boto3
# from botocore.stub import Stubber
# from pyspark.sql.types import StructType, StructField, StringType, IntegerType
# from pyspark.sql import SparkSession
# from tests.setup import spark_session
# from tests.setup.test_case import TestTable, TestCase
# from pyspark.sql.types import StructType, StructField, StringType, IntegerType
# import pytest
#
#
# CHECKPOINT_SCHEMA_PATH = "tests/data/schema/fstream_schemas/CHECKPOINT.json"
# GENERAL_INFORMATION_SCHEMA_PATH = (
#     "tests/data/schema/fstream_schemas/GENERAL_INFORMATION.json"
# )
# PARTS_SCHEMA_PATH = "tests/data/schema/fstream_schemas/PARTS.json"
# schema_list = [
#     CHECKPOINT_SCHEMA_PATH,
#     GENERAL_INFORMATION_SCHEMA_PATH,
#     PARTS_SCHEMA_PATH,
# ]
#
#
# @contextmanager
# def bucket(name):
#     s3_client = boto3.client("s3")
#     s3_resource = boto3.resource("s3")
#     s3_client.create_bucket(
#         Bucket=name, CreateBucketConfiguration={"LocationConstraint": "eu-west-1"}
#     )
#     print("\nBucket: create")
#     try:
#         yield name
#     finally:
#         bucket = s3_resource.Bucket(name)
#         for obj in bucket.objects.all():
#             obj.delete()
#         bucket.delete()
#         print("Bucket: cleanup")
#
#
# def create_localstack_client_session():
#     env_hostname = os.environ.get("LOCALSTACK_HOSTNAME")
#     env_aws_access_key_id = os.environ.get("AWS_ACCESS_KEY_ID")
#     env_aws_secret_access_key = os.environ.get("AWS_SECRET_ACCESS_KEY")
#     env_region_name = os.environ.get("AWS_DEFAULT_REGION")
#
#     session_ls = localstack_client.session.Session(
#         localstack_host=env_hostname,
#         aws_access_key_id=env_aws_access_key_id,
#         aws_secret_access_key=env_aws_secret_access_key,
#         region_name=env_region_name,
#     )
#     return session_ls
#
#
# def create_testing_pyspark_session() -> SparkSession:
#     """
#     Returns SparkSession connecting to local context the extrajava
#     session is to generate the metastore_db and derby.log into .tmp/ directory
#     """
#     tmp_dir = os.path.abspath(".tmp/")
#     os.environ["PYSPARK_PYTHON"] = sys.executable
#     os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable
#     return (
#         SparkSession.builder.master("local[1]")
#         .appName("local-spark-tests_unit")
#         .config("spark.driver.extraJavaOptions", "-Dderby.system.home=" + tmp_dir)
#         .config("spark.sql.warehouse.dir", tmp_dir)
#         .config("spark.hadoop.fs.s3.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
#         .config("spark.hadoop.fs.s3a.endpoint", "mock-aws:4566")
#         .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")
#         .config("spark.hadoop.fs.s3a.fast.upload", "true")
#         .config("spark.hadoop.fs.s3a.path.style.access", "true")
#         .config("spark.hadoop.fs.s3a.fast.upload.buffer", "bytebuffer")
#         .config("spark.hadoop.fs.s3a.change.detection.mode", "none")
#         .config(
#             "spark.hadoop.fs.s3a.aws.credentials.provider",
#             "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider",
#         )
#         .getOrCreate()
#     )
#
#
# event_timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
#
#
# class TestFstream:
#     def test_union_dataframes(self) -> None:
#         """
#         Unit test for the `union_dataframes` function. This test validates if the function returns the expected
#         dataframe when two dataframes are unioned.
#
#         Raises:
#         - AssertionError: If the `result_df` doesn't match the `expected_df`.
#         """
#
#         # Create a PySpark session
#         ss = create_testing_pyspark_session()
#
#         # Define the test data
#         schema = StructType(
#             [
#                 StructField("name", StringType(), True),
#                 StructField("age", IntegerType(), True),
#                 StructField("country", StringType(), True),
#             ]
#         )
#         partial_data = [("Johanes", 17, "Germany"), ("Alice", 29, "Canada")]
#         final_data = [("Mo", 31, "Tunisia"), ("Lisa", 23, "Montenegro")]
#
#         # Create the input dataframes
#         partial_df = ss.createDataFrame(partial_data, schema=schema)
#         final_df = ss.createDataFrame(final_data, schema=schema)
#
#         # Call the function under test
#         result_df = union_dataframes(partial_df, final_df)
#         result_df.show()
#
#         # Define the expected output dataframe
#         expected_data = [
#             ("Mo", 31, "Tunisia"),
#             ("Lisa", 23, "Montenegro"),
#             ("Johanes", 17, "Germany"),
#             ("Alice", 29, "Canada"),
#         ]
#         expected_df = ss.createDataFrame(expected_data, schema=schema)
#         expected_df.show()
#
#         # Assert the results
#         assert result_df.collect() == expected_df.collect()
#
#     def test_read_data(self) -> None:
#         """
#         Test function for reading data into PySpark DataFrames.
#
#         This function tests the `read_data` function, which reads JSON files from disk and converts them into PySpark
#         DataFrames using the specified schema. For each test case, the function checks that the resulting DataFrame has
#         the expected number of rows.
#
#         Raises
#         ------
#         AssertionError
#             If any of the test cases fail.
#
#         """
#
#         session = create_testing_pyspark_session()
#         test_table = TestTable(
#             [
#                 TestCase(have="tests/data/fstream_input/input_checkpoint.json", want=2),
#                 TestCase(
#                     have="tests/data/fstream_input/input_general_information.json",
#                     want=2,
#                 ),
#                 TestCase(have="tests/data/fstream_input/input_parts.json", want=2),
#             ]
#         )
#
#         for test_case, schema_path in zip(test_table.test_cases, schema_list):
#             input_df = read_data(session, test_case.have, schema_path)
#             assert input_df.count() == test_case.want
#
#     def test_create_checkpoint_dataframe(self) -> None:
#         """
#         Test the create_checkpoint_dataframe function by creating a PySpark session and reading in
#         a test input DataFrame using the read_data function. Then, the function under test is called
#         with the event_timestamp and the test input DataFrame to create a checkpoint DataFrame.
#
#         Finally, an assertion is made that the checkpoint DataFrame has the expected count of 20 rows.
#
#         """
#         ss = create_testing_pyspark_session()
#
#         data2 = [
#             ("186 ABG8072022", "0188469185522"),
#             ("186 ABC8072022", "0188469185522"),
#         ]
#
#         schema = StructType(
#             [
#                 StructField("commission_number", StringType(), True),
#                 StructField("ifa_order_key", StringType(), True),
#             ]
#         )
#
#         filter_brand_df = ss.createDataFrame(data=data2, schema=schema)
#
#         test_input_df = read_data(
#             ss,
#             "tests/data/fstream_input/input_checkpoint.json",
#             CHECKPOINT_SCHEMA_PATH,
#         )
#         checkpoint_df = create_checkpoint_dataframe(
#             event_timestamp, test_input_df, filter_brand_df
#         )
#
#         assert checkpoint_df.count() == 20
#
#     def test_create_general_info_dataframe(self) -> None:
#         """
#         Test the create_general_info_dataframe function by creating a PySpark session and reading in
#         a test input DataFrame using the read_data function. Then, the function under test is called
#         with the event_timestamp and the test input DataFrame to create a checkpoint DataFrame.
#
#         Finally, an assertion is made that the checkpoint DataFrame has the expected count of 2 rows.
#
#         """
#         ss = create_testing_pyspark_session()
#
#         test_input_df = read_data(
#             ss,
#             "tests/data/fstream_input/input_general_information.json",
#             GENERAL_INFORMATION_SCHEMA_PATH,
#         )
#         general_info_df = create_general_info_dataframe(
#             event_timestamp, test_input_df, None
#         )
#
#         assert general_info_df.count() == 2
#
#     def test_create_parts_dataframe(self) -> None:
#         """
#         Test the create_parts_dataframe function by creating a PySpark session and reading in
#         a test input DataFrame using the read_data function. Then, the function under test is called
#         with the event_timestamp and the test input DataFrame to create a checkpoint DataFrame.
#
#         Finally, an assertion is made that the checkpoint DataFrame has the expected count of 8 rows.
#
#         """
#         ss = create_testing_pyspark_session()
#
#         data2 = [
#             ("186 ABG8072022", "0188469185522"),
#             ("186 ABC8072022", "0188469185522"),
#         ]
#
#         schema = StructType(
#             [
#                 StructField("commission_number", StringType(), True),
#                 StructField("ifa_order_key", StringType(), True),
#             ]
#         )
#
#         filter_brand_df = ss.createDataFrame(data=data2, schema=schema)
#
#         test_input_df = read_data(
#             ss, "tests/data/fstream_input/input_parts.json", PARTS_SCHEMA_PATH
#         )
#         parts_df = create_parts_dataframe(
#             event_timestamp, test_input_df, filter_brand_df
#         )
#
#         assert parts_df.count() == 8
#
#     def test_create_subscription_df(self):
#
#         prefix = "GENERAL_INFORMATION"
#
#         # Define test data
#         ss = create_testing_pyspark_session()
#         my_json_path = "tests/data/fstream_input/input_general_information.json"
#         df = read_data(ss, my_json_path, GENERAL_INFORMATION_SCHEMA_PATH)
#
#         general_info_df = create_general_info_dataframe(event_timestamp, df, None)
#
#         # Call the function under test
#         result_df = create_subscription_df(general_info_df, prefix)
#
#         # Assert the expected output
#         expected_columns = [
#             "index",
#             "event_timestamp",
#             "msg_type",
#             "commission_number",
#             "start_of_subscription",
#             "start_of_unsubscription",
#             "ifa_order_key",
#         ]
#         print("*** test_create_subscription_df ***")
#         print("***********************************")
#         assert result_df.columns == expected_columns
#         assert result_df.count() == 2
#
#         # Asert that the 'msg_type' column contains the expected value:
#         assert result_df.select("msg_type").distinct().collect()[0]["msg_type"] in [
#             "GENERAL_INFORMATION",
#             "CHECKPOINT",
#             "PARTS",
#         ]
#
#     def test_create_msg_header_df(self):
#         print("*********************************")
#         prefix = "MSG_HEADER"
#
#         # Define test data
#         ss = create_testing_pyspark_session()
#         my_json_path = "tests/data/fstream_input/input_general_information.json"
#         df = read_data(ss, my_json_path, GENERAL_INFORMATION_SCHEMA_PATH)
#
#         general_info_df = create_general_info_dataframe(event_timestamp, df, None)
#         # Call the function under test
#         result_df = create_msg_header_df(general_info_df, prefix)
#
#         # Assert the expected output
#         expected_columns = [
#             "index",
#             "fk_subscription",
#             "event_timestamp",
#             "msg_type",
#             "commission_number",
#             "source_timestamp",
#             "msg_timestamp",
#             "ifa_order_key",
#             "filename",
#         ]
#         print("*** test_create_msg_header_df ***")
#         print("*********************************")
#         assert result_df.columns == expected_columns
#         assert result_df.count() == 2
#
#         # Asert that the 'msg_type' column contains the expected value:
#         assert result_df.select("msg_type").distinct().collect()[0]["msg_type"] in [
#             "GENERAL_INFORMATION",
#             "CHECKPOINT",
#             "PARTS",
#         ]
