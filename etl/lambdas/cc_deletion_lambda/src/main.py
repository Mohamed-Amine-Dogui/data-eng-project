import boto3
import os
from datetime import datetime

import time
import pandas as pd

import logging
from logging import Logger

logger: Logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_table_names(schema_name, dbname, user, cluster_id, client):
    ## select table_name
    ## from information_schema.tables
    ## where table_schema = 'cdp_vwn'  -- put schema name here
    logger.info(f"Getting table names.")

    query = f"SELECT table_name from information_schema.tables where table_schema = '{schema_name}';"
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
                logging.exception(
                    f"Query execution failed: {client.describe_statement(Id=query_id).get('Error')}"
                )
    except Exception as e:
        logger.error(f"Exception while executing redshift query: {e}")
        raise e

    return client.get_statement_result(Id=query_id).get("Records")


def delete_from_redshift(
    redshift_schema, dbname, user, cluster_id, client, tables, general_duration
):
    todays_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
    for table in tables:
        logger.info(f"Deleting from {table}")

        query = f"DELETE FROM {redshift_schema}.{table} WHERE datediff(day, timestamp_of_dataset, '{todays_date}' ) >= {general_duration} "

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
                    logging.exception(
                        f"Query execution failed: {client.describe_statement(Id=query_id).get('Error')}"
                    )

            resultRows = client.describe_statement(Id=query_id).get("ResultRows")
            logger.info(
                f"Records deleted from {redshift_schema}.{table} : {resultRows} "
            )

        except Exception as e:
            logger.error(f"Exception while executing redshift query: {e}")
            raise e

    return client.describe_statement(Id=query_id).get("Status")


def update_columns_redshift(
    redshift_schema, dbname, user, cluster_id, client, tables, columns, duration
):
    todays_date = pd.Timestamp.now()

    column_list = columns.split(",")
    update_statement = " = Null, ".join(column_list) + " = Null"

    for table in tables:
        logger.info(f"Updating table {table}")
        query = f"UPDATE {redshift_schema}.{table} SET {update_statement} WHERE datediff(day, event_timestamp, '{todays_date}' ) >= {duration} "

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
                    logging.exception(
                        f"Query execution failed: {client.describe_statement(Id=query_id).get('Error')}"
                    )
        except Exception as e:
            logger.error(f"Exception while executing redshift query: {e}")
            raise e

    return client.describe_statement(Id=query_id).get("Status")


def to_list(result) -> list:
    """
    :param result: the result from get_statement_result
    :return: list

    This is intended to be used to convert a one column of type string result of a select statement into a list.
    """
    # TODO generalize it using list(row.values())
    values = []
    # print(f"Data row: {row}")
    for item in result:
        values.append(item[0].get("stringValue"))

    return values


def lambda_handler(event, context):

    ## Redshift environment var
    redshift_cluster_id = os.environ["CLUSTER_ID"]
    redshift_name = os.environ["REDSHIFT_DB_NAME"]
    redshift_user = os.environ["REDSHIFT_USER"]

    ## payload from step function
    redshift_schema = event["schema"]
    general_duration = event["general_duration"]
    columns = event["columns"]

    ## redshift boto3 client
    redshift_client = boto3.client("redshift-data")

    logger.info(f"Listing table names in schema: {redshift_schema}")

    ## get table names existing in current schema
    tables = to_list(
        get_table_names(
            redshift_schema,
            redshift_name,
            redshift_user,
            redshift_cluster_id,
            redshift_client,
        )
    )

    if tables is not None:
        logger.info(f"Preparing deletion from: {redshift_schema}")
        ## delete from redshift all rows based on general deletion duration
        delete_from_redshift(
            redshift_schema,
            redshift_name,
            redshift_user,
            redshift_cluster_id,
            redshift_client,
            tables,
            general_duration,
        )

        ## delete using specific columns, loop based on key (which is the duration)
        if columns:
            for duration in columns:
                cols = columns[duration]
                update_columns_redshift(
                    redshift_schema,
                    redshift_name,
                    redshift_user,
                    redshift_cluster_id,
                    redshift_client,
                    tables,
                    cols,
                    duration,
                )
    else:
        logger.error("No tables found in the specified schema.")
