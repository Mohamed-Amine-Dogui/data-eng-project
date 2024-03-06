import boto3
import os
import json

import logging
from logging import Logger

logger: Logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

print("Loading sns push lambda function")


def lambda_handler(event, context):
    """
    "jobName": <jobName>,
    "message": <message>,
    "jr_id": <jr_id>,
    "subject": "${upper(var.stage)}-DE-Production Tracker Monitoring",
    "country": "DE",
    "stage": "${var.stage}"

    "name": <name>,
    "event": <event>,
    "region": <region>,
    "executionArn": <executionArn>,
    "subject": "${upper(var.stage)}-DE-Production Tracker Monitoring",
    "country": "DE",
    "stage": "${var.stage}"


    "event": <event>,
    "metricname": <metricname>,
    "name": <name>,
    "namespace": <namespace>,
    "subject": "${upper(var.stage)}-DE-Production Tracker Monitoring",
    "country": "DE",
    "stage": "${var.stage}"

    """
    logger.info("Lambda triggered by Amazon EventBridge Rule.")
    sns_arn = os.environ["SNS_TOPIC_ARN"]
    resource = event["resource"]

    rerun_msg = """\n\nIn order to rerun please provide the date value in Step Function Job Arguments as below:
                   \n\n--date_prefix: YYYYMMDD
    """
    print(event)
    if resource == "GlueJob":
        try:
            jobName = event["jobName"]
            message = event["message"]
            subject = event["subject"]
            jr_id = event["jr_id"]

            if ("CDP" not in subject) and ("OKM" not in subject):
                output_msg = f"""Dear Subscriber,
                                 \n\nThis email is from {subject}. Glue Job {jobName} has FAILED with message:\n\n{message}
                                 \n\nSee job run: https://eu-west-1.console.aws.amazon.com/gluestudio/home?region=eu-west-1#/job/{jobName}/run/{jr_id}
                                 {rerun_msg}
                              """
            else:
                output_msg = f"""Dear Subscriber,
                                 \n\nThis email is from {subject}. Glue Job {jobName} has FAILED with message:\n\n{message}
                                 \n\nSee job run: https://eu-west-1.console.aws.amazon.com/gluestudio/home?region=eu-west-1#/job/{jobName}/run/{jr_id}
                              """
        except Exception as e:
            logger.error("Error while reading event.")
            raise e

    elif resource == "StepFunction":
        try:
            name = event["name"]
            st_event = event["event"]
            region = event["region"]
            executionArn = event["executionArn"]
            subject = event["subject"]

            # TODO add 'rerun' option as input
            if ("CDP" not in subject) and ("OKM" not in subject):
                output_msg = f"""Dear Subscriber,
                                 \n\nThis email is from {subject}. Step Function {name} has {st_event}.
                                 \n\nSee job run: https://{region}.console.aws.amazon.com/states/home?region={region}#/v2/executions/details/{executionArn}
                                 {rerun_msg}
                              """
            else:
                output_msg = f"""Dear Subscriber,
                                 \n\nThis email is from {subject}. Step Function {name} has {event}.
                                 \n\nSee job run: https://{region}.console.aws.amazon.com/states/home?region={region}#/v2/executions/details/{executionArn}
                              """
        except Exception as e:
            logger.error("Error while reading event.")
            raise e

    elif resource == "Lambda":
        try:
            subject = event["subject"]
            namespace = event["namespace"]
            name = event["name"]
            metricname = event["metricname"]

            output_msg = f"""Dear Subscriber,
                            \n\nThis email is from {subject}.
                            \n\nThis is an alarm to inform you that {namespace} function {name} has failed with {metricname}
                          """
        except Exception as e:
            logger.error("Error while reading event.")
            raise e
    try:
        sns_client = boto3.client("sns")
        response = sns_client.publish(
            TargetArn=sns_arn,
            Message=output_msg,
            Subject=subject,
            MessageAttributes={"epic": {"DataType": "String", "StringValue": subject}},
        )

        logger.info(f"Message sent to SNS: {response}")

    except Exception as e:
        logger.error(f"An error occurred while publishing message to SNS.")
        raise e
