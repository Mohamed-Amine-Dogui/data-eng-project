import boto3
import os
import json
from json import dumps

import logging
from logging import Logger
from datetime import datetime

logger: Logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

print("Loading function")


def lambda_handler(event, context):

    fstream_s3_bucket = os.environ["FSTREAM_S3_BUCKET"]
    country = "DE"

    for record in event["Records"]:

        msg_type = "unknown"
        payload = record["body"]
        payload_dict = json.loads(payload)

        if "type" in payload_dict.keys():
            msg_type = payload_dict["type"]

        if msg_type == "unknown":
            print(f"payload_dict: {payload_dict}")

        now = datetime.now()
        dt_string = now.strftime("%Y-%m-%d--%H:%M:%S.%f")
        folder_name = now.strftime("%Y-%m-%d")
        message_key = f"{dt_string}--{msg_type.lower()}.json"

        json_body = json.dumps(payload_dict, default=str)

        if msg_type == "unknown":
            print(f"payload_dict: {payload_dict}")

        try:
            client = boto3.client("s3")
            key_path = os.path.join(country, folder_name, msg_type, message_key)
            # key_path = os.path.join(folder_name, msg_type, message_key)
            client.put_object(
                Bucket=fstream_s3_bucket,
                Key=key_path,
                Body=json_body,
            )

            print("S3 upload success !")

            return {"status": 200, "body": "S3 upload success"}

        except Exception as e:

            print("Client connection to S3 failed because ", e)

            return {"status": 500, "body": "S3 upload failed"}
