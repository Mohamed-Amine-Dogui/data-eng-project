import boto3
import os

import logging
from logging import Logger
import time

logger: Logger = logging.getLogger()
logger.setLevel(logging.INFO)


def select_redshift(query, dbname, user, cluster_id, client):

    try:
        statement = client.execute_statement(
            Database=dbname,
            DbUser=user,
            Sql=query,
            ClusterIdentifier=cluster_id,
            WithEvent=True,
        )

        query_id = statement.get("Id")
        while client.describe_statement(Id=query_id).get("Status") != "FINISHED":
            time.sleep(0.5)
            if client.describe_statement(Id=query_id).get("Status") == "FAILED":
                raise Exception(
                    f"Query execution failed: {client.describe_statement(Id=query_id).get('Error')}"
                )
    except Exception as e:
        logger.error(f"Exception while executing redshift query: {e}")
        raise e

    print(f" Query execution succeed")
    return client.get_statement_result(Id=query_id)


def lambda_handler(event, context):

    ## Redshift environment var
    sns_arn = os.environ["sns_arn"]
    ## Redshift environment var
    redshift_cluster_id = os.environ["CLUSTER_ID"]
    redshift_name = os.environ["REDSHIFT_DB_NAME"]
    redshift_user = os.environ["REDSHIFT_USER"]
    stage = os.environ["stage"]
    country = event["COUNTRY"]

    sns_client = boto3.client("sns")
    redshift_client = boto3.client("redshift-data")

    query_no_msg = f"select distinct * from pde_vwn.vehicle where commission_number in (select distinct commission_number from pde_vwn.pde_pt where dealership_country = '{country}') and ifa_order_key is null"
    total_num_rows = select_redshift(
        query_no_msg, redshift_name, redshift_user, redshift_cluster_id, redshift_client
    ).get("TotalNumRows")

    if total_num_rows > 0:
        print("Notifying subscribers")
        msg_body = (
            f"Dear Subscriber, \n\nThis email is from {stage.upper()}-{country}-Production Tracker Monitoring. \n\nThere are {total_num_rows} commission numbers that have not received a message from fstream {country}. Please contact the responsible contact person."
            f"\n\nQuery for retrieving commission numbers:\n\n {query_no_msg}"
        )

        subject = f"{stage.upper()}-{country}-Production Tracker Monitoring - Missing messages from Fstream"
        print(subject)
        sns_client.publish(
            TargetArn=sns_arn,
            Message=msg_body,
            Subject=subject,
            MessageAttributes={"epic": {"DataType": "String", "StringValue": subject}},
        )

    query_no_update = f"select distinct * from pde_vwn.vehicle where commission_number in (select distinct commission_number from pde_vwn.pde_pt where dealership_country = '{country}') and datediff(day, event_timestamp, CURRENT_DATE) > 1"

    total_num_rows = select_redshift(
        query_no_update,
        redshift_name,
        redshift_user,
        redshift_cluster_id,
        redshift_client,
    ).get("TotalNumRows")

    if total_num_rows > 0:
        print("Notifying subscribers")
        msg_body = (
            f"Dear Subscriber, \n\nThis email is from {stage.upper()}-{country}-Production Tracker Monitoring. \n\nThere are {total_num_rows} commission numbers that have not received an update message from fstream {country}. Please contact the responsible contact person."
            f"\n\nQuery for retrieving commission numbers:\n\n {query_no_update}"
        )
        subject = f"{stage.upper()}-{country}-Production Tracker Monitoring - Missing updates from Fstream"
        sns_client.publish(
            TargetArn=sns_arn,
            Message=msg_body,
            Subject=subject,
            MessageAttributes={"epic": {"DataType": "String", "StringValue": subject}},
        )
