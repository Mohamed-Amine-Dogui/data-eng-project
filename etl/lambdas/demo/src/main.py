import json
import csv
import boto3
import os
from io import StringIO
import logging
from datetime import datetime, timedelta

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.ERROR)


def lambda_handler(event, context):
    # Environment variables
    stage = os.environ["stage"]
    print(f"stage: {stage}")
    target_data_bucket = os.environ["TARGET_DATA_BUCKET_NAME"]

    # Create an S3 client
    s3_client = boto3.client("s3")

    # 'yesterday_date' for file naming
    yesterday_date = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")

    # Generate dummy JSON data
    json_data = [
        {"name": "John Doe", "date": "2024-03-10", "order_id": "1001", "price": 150},
        {"name": "Jane Doe", "date": "2024-03-11", "order_id": "1002", "price": 200},
        {"name": "Jim Beam", "date": "2024-03-12", "order_id": "1003", "price": 250},
        {"name": "Jenny Craig", "date": "2024-03-13", "order_id": "1004", "price": 300},
        {
            "name": "Jack Daniels",
            "date": "2024-03-14",
            "order_id": "1005",
            "price": 350,
        },
    ]

    # Convert JSON data to CSV format
    csv_buffer = StringIO()
    csv_writer = csv.writer(csv_buffer)
    csv_writer.writerow(["name", "date", "order_id", "price"])  # Writing the header

    # Writing the data rows
    for row in json_data:
        csv_writer.writerow([row["name"], row["date"], row["order_id"], row["price"]])

    # Resetting buffer position to the beginning
    csv_buffer.seek(0)

    # Upload the CSV file to the S3 bucket
    file_name = f"data_{yesterday_date}.csv"
    try:
        s3_client.put_object(
            Bucket=target_data_bucket, Key=file_name, Body=csv_buffer.getvalue()
        )
        logger.info(f"Successfully uploaded {file_name} to {target_data_bucket}.")
        return {
            "statusCode": 200,
            "body": json.dumps({"message": f"Successfully uploaded {file_name}"}),
        }
    except Exception as e:
        logger.error(f"Failed to upload file to S3: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Failed to upload file"}),
        }
