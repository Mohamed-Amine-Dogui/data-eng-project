import boto3
import logging

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    # Get bucket name and object key from the event
    bucket_name = event["Records"][0]["s3"]["bucket"]["name"]
    object_key = event["Records"][0]["s3"]["object"]["key"]

    s3_client = boto3.client("s3")
    try:
        obj = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        sql_script = obj["Body"].read().decode("utf-8")
        logger.info(f"Successfully fetched and decoded SQL script: {object_key}")

        # Log the SQL script content at INFO level
        logger.info(f"SQL Script Content:\n{sql_script}")
    except Exception as e:
        logger.error(
            f"Error fetching SQL script {object_key} from bucket {bucket_name}: {str(e)}"
        )
        return {
            "statusCode": 500,
            "body": f"Error processing SQL script: {object_key}",
        }

    return {
        "statusCode": 200,
        "body": f"Successfully processed SQL script: {object_key}",
    }
