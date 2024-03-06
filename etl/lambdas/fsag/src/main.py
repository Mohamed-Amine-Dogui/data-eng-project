import boto3
import os
from io import StringIO
import pandas as pd
import io
import re
from datetime import datetime, timedelta
import time
import logging
from logging import Logger
from dateutil import parser

from decimal import Decimal

# Allow to display the hole pandas dataframe when we print
pd.set_option("display.max_columns", None)
pd.set_option("display.max_colwidth", None)
pd.set_option("display.width", None)

# Cloudwatch metric param
namespace = "VWN/Fasttrack"
category = "Interface"
sub_category = "FastTrack"
version = "1"


logger: Logger = logging.getLogger()
logger.setLevel(logging.ERROR)


def load_to_redshift(
    client,
    dbname,
    table_name,
    user,
    cluster_id,
    redshift_schema,
    file_to_copy,
    redshift_iam_role,
):
    """
    Load data from an S3 parquet file into a Redshift table using the COPY command.

    Args:
        client (object): A Redshift data client object.
        dbname (str): The name of the Redshift database.
        table_name (str): The name of the Redshift table.
        user (str): The database user for executing the COPY command.
        cluster_id (str): The identifier of the Redshift cluster.
        redshift_schema (str): The Redshift schema where the table resides.
        file_to_copy (str): The S3 file path to copy data from.
        redshift_iam_role (str): The IAM role ARN for accessing S3 and executing COPY.

    Returns:
        str: The status of the executed statement.

    Raises:
        Exception: If the COPY statement execution fails.
    """

    query = (
        f"COPY {redshift_schema}.{table_name} "
        f"FROM '{file_to_copy}' "
        f"CREDENTIALS 'aws_iam_role={redshift_iam_role}' "
        f"FORMAT AS PARQUET;"
    )

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
        print("sleeping")
        if client.describe_statement(Id=query_id).get("Status") == "FAILED":
            raise Exception(f"Query failed: {client.describe_statement(Id=query_id)}")

    return client.describe_statement(Id=query_id).get("Status")


def select_query_to_df(client, dbname, cluster_id, user, myquery, keys):
    """
    This method executes a SQL query on an Amazon Redshift cluster using the Amazon Redshift Data API
    and transforms the results into a Pandas DataFrame.

    Parameters:
    - client: a Boto3 client for the Amazon Redshift Data API
    - dbname: the name of the Amazon Redshift database to query
    - cluster_id: the ID of the Amazon Redshift cluster to query
    - user: the user to connect to the Amazon Redshift cluster as
    - myquery: the SQL query to execute on the Amazon Redshift cluster
    - keys: a list of the names of the columns to expect in the resulting DataFrame
    """

    statement = client.execute_statement(
        Database=dbname,
        DbUser=user,
        Sql=myquery,
        ClusterIdentifier=cluster_id,
        WithEvent=True,
    )
    query_id = statement.get("Id")

    while client.describe_statement(Id=query_id).get("Status") != "FINISHED":
        time.sleep(0.5)
        print("sleeping")
        if client.describe_statement(Id=query_id).get("Status") == "FAILED":
            raise Exception(f"Query failed: {client.describe_statement(Id=query_id)}")

    result = client.get_statement_result(Id=query_id)

    # convert the result to a list of rows
    rows = []
    for record in result["Records"]:
        values = []
        for item in record:
            if item.get("stringValue") is not None:
                values.append(item.get("stringValue"))
            elif item.get("longValue") is not None:
                values.append(item.get("longValue"))
            elif item.get("doubleValue") is not None:
                values.append(item.get("doubleValue"))
            elif item.get("booleanValue") is not None:
                values.append(item.get("booleanValue"))
            elif item.get("isNull"):
                values.append(None)
        row_dict = dict(zip(keys, values))
        rows.append(row_dict)

    # Convert  dictionary to Pandas DataFrame
    pandas_df = pd.DataFrame.from_dict(rows)

    return pandas_df


def filter_by_vin_consent(transfer_df, vins_with_consent):
    # This will keep only the rows where the "vehicleIdentificationNumber" is present in both DataFrames
    merged_df = transfer_df.merge(
        vins_with_consent,
        left_on="vehicleIdentificationNumber",
        right_on="vehicle_vin",
        how="inner",
    )

    # Check if the merged DataFrame is not empty
    if not merged_df.empty:
        # Select only the needed columns
        filtered_df = merged_df[
            [
                "vehicleIdentificationNumber",
                "subscriptionVehicleCategory",
                "product",
                "inceptionDate",
                "contractEndDate",
                "duration",
            ]
        ]
        return filtered_df
    else:
        return None


def generate_test_data():

    data = {
        "vehicle_identification_number": ["TEST"],
        "subscription_vehicle_category": ["VOLKSWAGEN"],
        "product": ["Leasing"],
        "inception_date": [
            pd.to_datetime(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        ],
        "contract_end_date": [
            pd.to_datetime(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        ],
        "duration": [36.0],
        "event_timestamp": [
            pd.to_datetime(datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        ],
        "filename": ["dummy_file_name"],
    }

    schema = {
        "vehicle_identification_number": "bpchar",
        "subscription_vehicle_category": "varchar",
        "product": "varchar",
        "inception_date": "timestamp",
        "contract_end_date": "timestamp",
        "duration": "float8",
        "event_timestamp": "timestamp",
        "filename": "varchar",
    }

    df = pd.DataFrame(data, columns=schema.keys())

    return df


def send_sns_notification(
    sns_arn, sns_client, stage, yesterday_date, fsag_data_bucket, source_folder_prefix
):
    """
    Send an SNS (Simple Notification Service) notification to inform subscribers about the absence of a file upload.

    Args:
        sns_arn (str): The Amazon Resource Name (ARN) of the SNS topic to which the notification will be sent.
        sns_client (boto3.client): An initialized AWS SNS client.
        stage (str): The stage or environment identifier (e.g., 'dev', 'prd').
        yesterday_date (str): The date for which the absence of a file upload is reported.
        fsag_data_bucket (str): The name of the S3 bucket where the file upload is expected.
        source_folder_prefix (str): The prefix of the source folder within the S3 bucket.

    Returns:
        None
    """
    date = datetime.strptime(yesterday_date, "%Y%m%d").strftime("%d.%m.%Y")
    message_body = (
        f"Dear Subscriber, \n\n This email is from DE-Fast Track Monitoring. "
        f'\n\nThere is no file uploaded on {date} in the Bucket "{fsag_data_bucket}" under the folder {source_folder_prefix} .'
        f"\n Please reach out to the responsible contact person."
        f"\n\n Best regards"
    )

    logger.info("Notifying subscribers")
    subject = f"{stage.upper()}-DE-Fast Track Monitoring"
    sns_client.publish(
        TargetArn=sns_arn,
        Message=message_body,
        Subject=subject,
        MessageAttributes={"epic": {"DataType": "String", "StringValue": subject}},
    )


def publish_metric(
    cw_client,
    namespace,
    category,
    sub_category,
    version,
    context,
    stage,
    metric_name,
    value,
    unit,
):
    """
    Category Sub-Category Context Version Environment
    Interface Fast Track filename_2 1 PRD

    """
    cw_client.put_metric_data(
        Namespace=namespace,
        MetricData=[
            {
                "MetricName": metric_name,
                "Dimensions": [
                    {
                        "Name": "Category",
                        "Value": category,
                    },
                    {
                        "Name": "Sub-Category",
                        "Value": sub_category,
                    },
                    {
                        "Name": "Context",
                        "Value": context,
                    },
                    {
                        "Name": "Version",
                        "Value": version,
                    },
                    {
                        "Name": "Environment",
                        "Value": stage,
                    },
                ],
                "Timestamp": datetime.now(),
                "Value": value,
                "Unit": unit,
            },
        ],
    )


def publish_metrics(metrics_dict, cw_client, key_to_copy, stage):

    for key, value in metrics_dict.items():
        publish_metric(
            cw_client,
            namespace,
            category,
            sub_category,
            version,
            key_to_copy,
            stage,
            key,
            value,
            "Count",
        )


def create_kpi_df(metrics_dict, key_to_copy, unit, stage):
    kpi_df = None
    data = None
    timestamp = datetime.now()
    # cast all values to
    if metrics_dict is not None:
        for key, value in metrics_dict.items():
            if data is None:
                data = [
                    [
                        key,
                        Decimal("{:.4f}".format(value)),
                        unit,
                        timestamp,
                        category,
                        sub_category,
                        key_to_copy,
                        version,
                        stage,
                    ]
                ]
            else:
                data.append(
                    [
                        key,
                        Decimal("{:.4f}".format(value)),
                        unit,
                        timestamp,
                        category,
                        sub_category,
                        key_to_copy,
                        version,
                        stage,
                    ]
                )

    kpi_df = pd.DataFrame(
        data,
        columns=[
            "kpi_name",
            "kpi_value",
            "unit",
            "kpi_timestamp",
            "category",
            "sub_category",
            "context",
            "version",
            "environment",
        ],
    )

    print(kpi_df)

    return kpi_df


def transform_df(filtered_df, key_to_copy):
    final_df = filtered_df.rename(
        columns={
            "inceptionDate": "inception_date",
            "subscriptionVehicleCategory": "subscription_vehicle_category",
            "contractEndDate": "contract_end_date",
            "vehicleIdentificationNumber": "vehicle_identification_number",
        }
    )

    # convert string to datetime & numeric -> if not able to convert leave it as null
    final_df["inception_date"] = pd.to_datetime(
        final_df["inception_date"], errors="coerce"
    )

    final_df["contract_end_date"] = pd.to_datetime(
        final_df["contract_end_date"], errors="coerce"
    )

    final_df["duration"] = pd.to_numeric(
        final_df["duration"], errors="coerce", downcast="float"
    )

    final_df["event_timestamp"] = pd.to_datetime(
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    )

    final_df["inception_date"] = final_df["inception_date"].values.astype(
        "datetime64[us]"
    )
    final_df["contract_end_date"] = final_df["contract_end_date"].values.astype(
        "datetime64[us]"
    )
    final_df["event_timestamp"] = final_df["event_timestamp"].values.astype(
        "datetime64[us]"
    )

    final_df["filename"] = key_to_copy

    cols = [
        "vehicle_identification_number",
        "subscription_vehicle_category",
        "product",
        "inception_date",
        "contract_end_date",
        "duration",
        "event_timestamp",
        "filename",
    ]
    final_df = final_df[cols]

    return final_df


def calc_transfer_df_metrics(transfer_df, key_related_metrics_dict):
    """
    OPS_FT_3DI_31_contracts-in-FSAG-file
    count amount of records in FSAG file in etl/lambdas/fsag/src/main.py
    """
    count_contracts = 0
    unique_vins_fsag_file = 0

    if transfer_df is not None and not transfer_df.empty:
        count_contracts = len(transfer_df.index)
        """
        OPS_FT_3DI_31_contracts-in-FSAG-file-unique-VIN
        count amount of unique VINs in FSAG file in etl/lambdas/fsag/src/main.py
        """
        unique_vins_fsag_file = transfer_df["vehicleIdentificationNumber"].nunique()

    key_related_metrics_dict["OPS_FT_3DI_31_contracts-in-FSAG-file"] = count_contracts

    key_related_metrics_dict[
        "OPS_FT_3DI_31_contracts-in-FSAG-file-unique-VIN"
    ] = unique_vins_fsag_file

    return key_related_metrics_dict


def calc_vins_with_consent_metrics(vins_with_consent, key_related_metrics_dict):
    """
    OPS_FT_3DI-34_customers-with-IDK-consent-in-total
    count amount of IDK records with FSAG consent
    """
    customers_with_idk_consent = 0

    if vins_with_consent is not None and not vins_with_consent.empty:
        customers_with_idk_consent = vins_with_consent["vehicle_vin"].nunique()

    key_related_metrics_dict[
        "OPS_FT_3DI-34_customers-with-IDK-consent-in-total"
    ] = customers_with_idk_consent

    return key_related_metrics_dict


def calc_filtered_df_metrics(filtered_df, key_related_metrics_dict):
    """
    OPS_FT_3DI_32_contracts-in-FSAG-file-with-IDK-consent
    count amount of unique VINs in FSAG file that have positive IDK/CarNet joins
    """
    unique_vins_with_consent = 0
    if filtered_df is not None and not filtered_df.empty:
        unique_vins_with_consent = filtered_df["vehicleIdentificationNumber"].nunique()

    key_related_metrics_dict[
        "OPS_FT_3DI_32_contracts-in-FSAG-file-with-IDK-consent"
    ] = unique_vins_with_consent

    return key_related_metrics_dict


def calc_unique_vins_without_consent_metrics(
    unique_vins_fsag_file, unique_vins_with_consent, key_related_metrics_dict
):
    """
    OPS_FT_3DI-33_contract-in-FSAG-file-without-IDK-consent
    count amount of unique VINs in FSAG file that do NOT have positive IDK/CarNet joins
    """

    unique_vins_without_consent = unique_vins_fsag_file - unique_vins_with_consent
    key_related_metrics_dict[
        "OPS_FT_3DI-33_contract-in-FSAG-file-without-IDK-consent"
    ] = unique_vins_without_consent

    return key_related_metrics_dict


def calc_vins_without_consent_metric(
    generic_metrics_dict,
    redshift_schema,
    client_id_array,
    permission_userrole,
    redshift_client,
    redshift_name,
    redshift_cluster_id,
    redshift_user,
):

    """
    OPS_FT_3DI-33ax_contracts-in-RS-without-IDK-consent
    count the amount of contracts in the RedShift database that should no longer be in there because the initial consent of the IDK user is no longer valid
    """

    get_vins_without_consent_query = (
        f"SELECT * FROM {redshift_schema}.contract_staging where vehicle_identification_number not in (SELECT vehicle_vin "
        f"FROM vwredshift.carnet_vwn.user_mgmt "
        f"INNER Join vwredshift.idk_data.consent_document "
        f"ON vwredshift.carnet_vwn.user_mgmt.aopuser_ssoid = vwredshift.idk_data.consent_document.cust_id "
        f"INNER JOIN vwredshift.idk_data.customer"
        f" ON vwredshift.carnet_vwn.user_mgmt.aopuser_ssoid = vwredshift.idk_data.customer.cust_id "
        f"WHERE client_id_array LIKE  '%{client_id_array}%'"
        f" AND carnet_vwn.user_mgmt.permission_userrole = '{permission_userrole}'"
        f" AND consent_document.is_latest=1"
        f" AND customer.is_deleted_flag=0)"
    )
    print(f"get_vins_without_consent_query: {get_vins_without_consent_query}")

    ## get vins with consent in a dataframe
    vins_without_consent = select_query_to_df(
        redshift_client,
        redshift_name,
        redshift_cluster_id,
        redshift_user,
        get_vins_without_consent_query,
        ["vehicle_identification_number"],
    )

    customers_without_idk_consent = 0
    if vins_without_consent is not None and not vins_without_consent.empty:
        customers_without_idk_consent = vins_without_consent[
            "vehicle_identification_number"
        ].nunique()

    generic_metrics_dict[
        "OPS_FT_3DI-33ax_contracts-in-RS-without-IDK-consent"
    ] = customers_without_idk_consent

    return generic_metrics_dict


def calc_newly_added_vins_metric(
    generic_metrics_dict,
    redshift_schema,
    client_id_array,
    permission_userrole,
    redshift_client,
    redshift_name,
    redshift_cluster_id,
    redshift_user,
):
    """
    OPS_FT_3DI-32a_contract-in-FSAG-file-with-IDK-consent-RS-unknown
    count amount of unique VINs in FSAG file that have positive IDK/CarNet joins - plus VIN is NOT already in RS
    """

    select_newly_added_vins_query = (
        f"SELECT vehicle_identification_number from {redshift_schema}.contract_staging "
        f"WHERE DATE_CMP(TRUNC(event_timestamp), CURRENT_DATE) = 0  "
        f"AND vehicle_identification_number NOT IN (SELECT vehicle_identification_number "
        f"FROM {redshift_schema}.contract_staging "
        f"WHERE DATE_CMP(TRUNC(event_timestamp), CURRENT_DATE) != 0)"
    )

    print(f"select_newly_added_vins_query: {select_newly_added_vins_query}")

    newly_added_vins = select_query_to_df(
        redshift_client,
        redshift_name,
        redshift_cluster_id,
        redshift_user,
        select_newly_added_vins_query,
        ["vehicle_identification_number"],
    )

    newly_added_vins_count = 0

    if newly_added_vins is not None and not newly_added_vins.empty:
        newly_added_vins_count = newly_added_vins[
            "vehicle_identification_number"
        ].nunique()

    generic_metrics_dict[
        "OPS_FT_3DI-32a_contract-in-FSAG-file-with-IDK-consent-RS-unknown"
    ] = newly_added_vins_count

    return generic_metrics_dict


def calc_existing_vins_metric(
    generic_metrics_dict,
    redshift_schema,
    client_id_array,
    permission_userrole,
    redshift_client,
    redshift_name,
    redshift_cluster_id,
    redshift_user,
):
    """
    OPS_FT_3DI-32a_contract-in-FSAG-file-with-IDK-consent-RS-known
    count amount of unique VINs in FSAG file that have positive IDK/CarNet joins - plus VIN is already in RS
    """
    select_existing_vins_query = (
        f"SELECT vehicle_identification_number from {redshift_schema}.contract_staging "
        f"WHERE DATE_CMP(TRUNC(event_timestamp), CURRENT_DATE) = 0  "
        f"AND vehicle_identification_number IN (SELECT vehicle_identification_number "
        f"FROM {redshift_schema}.contract_staging "
        f"WHERE DATE_CMP(TRUNC(event_timestamp), CURRENT_DATE) != 0)"
    )

    print(f"select_existing_vins_query: {select_existing_vins_query}")

    existing_vins = select_query_to_df(
        redshift_client,
        redshift_name,
        redshift_cluster_id,
        redshift_user,
        select_existing_vins_query,
        ["vehicle_vin"],
    )
    existing_vins_count = 0
    if existing_vins is not None and not existing_vins.empty:
        existing_vins_count = existing_vins["vehicle_vin"].nunique()

    generic_metrics_dict[
        "OPS_FT_3DI-32a_contract-in-FSAG-file-with-IDK-consent-RS-known"
    ] = existing_vins_count

    return generic_metrics_dict


"""
alarm_description   = "Lambda function Failures"
comparison_operator = "GreaterThanOrEqualToThreshold"
evaluation_periods  = "1"
metric_name         = "Errors"
namespace           = "AWS/Lambda"
period              = "900" # seconds = 15 minutes
statistic           = "Sum"
threshold           = "1"
dimensions = {
    FunctionName = each.value
}
treat_missing_data = "notBreaching"
actions_enabled    = true
"""


def put_metric_alarm(client, alarm_name, description, metric_name):

    client.put_metric_alarm(
        AlarmName=alarm_name,
        AlarmDescription=description,
        ComparisonOperator="LessThanOrEqualToThreshold",
        EvaluationPeriods=1,
        MetricName=metric_name,
        Namespace=namespace,
        Period=900,
        Statistic="Minimum",
        Threshold=0,
        TreatMissingData="notBreaching",
        ActionsEnabled=True
        # AlarmActions=[
        #    'string',
        # ]
    )


def write_parquet(s3_client, final_df, target_data_bucket, folder, parquet_target_key):
    # write parquet
    with io.BytesIO() as parquet_buffer:
        key = os.path.join(folder, parquet_target_key)

        parquet_file_path = os.path.join(f"s3://{target_data_bucket}", key)

        logger.info(f"Write dataframe to parquet to {parquet_file_path}")

        final_df.to_parquet(parquet_buffer, index=False)
        transfer_response = s3_client.put_object(
            Bucket=target_data_bucket,
            Key=key,
            Body=parquet_buffer.getvalue(),
        )

        status = transfer_response.get("ResponseMetadata", {}).get("HTTPStatusCode")
    return status


def lambda_handler(event, context):

    # Redshift environment var
    redshift_cluster_id = os.environ["CLUSTER_ID"]
    redshift_name = os.environ["REDSHIFT_DB_NAME"]
    redshift_user = os.environ["REDSHIFT_USER"]
    redshift_iam_role = os.environ["REDSHIFT_IAM_ROLE"]
    redshift_schema = os.environ["REDSHIFT_SCHEMA"]
    fsag_data_bucket = os.environ["FSAG_DATA_BUCKET_NAME"]
    sns_arn = os.environ["sns_arn"]
    stage = os.environ["stage"]
    target_data_bucket = os.environ["TARGET_DATA_BUCKET_NAME"]
    # target_data_bucket_path = os.environ["TARGET_DATA_BUCKET_PATH"]
    source_folder_prefix = "VWN/DE/"

    sns_client = boto3.client("sns")
    s3_client = boto3.client("s3")
    redshift_client = boto3.client("redshift-data")
    cw_client = boto3.client("cloudwatch")

    kpi_df = None

    client_id_array: str = "6a7833d9-016e-4d40-b12a-eee33f6dd199@apps_vw-dilab_com"
    permission_userrole: str = "PRIMARY"
    get_vins_with_consent_query = (
        f"SELECT vehicle_vin "
        f"FROM vwredshift.carnet_vwn.user_mgmt "
        f"INNER Join vwredshift.idk_data.consent_document "
        f"ON vwredshift.carnet_vwn.user_mgmt.aopuser_ssoid = vwredshift.idk_data.consent_document.cust_id "
        f"INNER JOIN vwredshift.idk_data.customer"
        f" ON vwredshift.carnet_vwn.user_mgmt.aopuser_ssoid = vwredshift.idk_data.customer.cust_id "
        f"WHERE client_id_array LIKE  '%{client_id_array}%'"
        f" AND carnet_vwn.user_mgmt.permission_userrole = '{permission_userrole}'"
        f" AND consent_document.is_latest=1"
        f" AND customer.is_deleted_flag=0 "
    )
    print(f"get_vins_with_consent_query: {get_vins_with_consent_query}")

    needed_columns = [
        "vehicleIdentificationNumber",
        "subscriptionVehicleCategory",
        "product",
        "inceptionDate",
        "contractEndDate",
        "duration",
    ]

    # response will contain the object (csv files) in the s3 of fsag account
    response = s3_client.list_objects(
        Bucket=fsag_data_bucket, Prefix=source_folder_prefix
    )
    response_contents = response.get("Contents")
    yesterday_date = (datetime.now() - timedelta(days=1)).strftime("%Y%m%d")
    yesterday_date_regex = (
        source_folder_prefix + re.escape(yesterday_date) + r"_VWN_DE_Checkout\.csv"
    )

    generic_metrics_dict = {
        "OPS_FT_3DI-33ax_contracts-in-RS-without-IDK-consent": None,
        "OPS_FT_3DI-32a_contract-in-FSAG-file-with-IDK-consent-RS-unknown": None,
        "OPS_FT_3DI-32a_contract-in-FSAG-file-with-IDK-consent-RS-known": None,
    }

    key_related_metrics_dict = {
        "OPS_FT_3DI_31_contracts-in-FSAG-file": None,
        "OPS_FT_3DI_31_contracts-in-FSAG-file-unique-VIN": None,
        "OPS_FT_3DI-34_customers-with-IDK-consent-in-total": None,
        "OPS_FT_3DI_32_contracts-in-FSAG-file-with-IDK-consent": None,
        "OPS_FT_3DI-33_contract-in-FSAG-file-without-IDK-consent": None,
    }

    if response_contents is not None:
        # files_in_fsag_data_bucket is a list strings (name of the csv files ) that have this naming pattern YYYYMMDD_VWN_DE_Checkout
        files_in_fsag_data_bucket = [element["Key"] for element in response_contents]
        print(f"Files available in fsag data bucket: {files_in_fsag_data_bucket}")

        files_to_copy = []
        for element in response_contents:
            if element["Size"] > 0 and not element["Key"].endswith(
                "/"
            ):  # Skip directories
                if re.match(yesterday_date_regex, element["Key"]):
                    files_to_copy.append(element["Key"])

        logger.info(f"Files to copy: {files_to_copy}")

        if files_to_copy:
            for key_to_copy in files_to_copy:
                # csv_target_key = key_to_copy.split("/")[-1]
                parquet_target_key = (
                    key_to_copy.split("/")[-1].split(".")[0] + ".parquet"
                )

                response_get = s3_client.get_object(
                    Bucket=fsag_data_bucket, Key=key_to_copy
                )
                logger.info(f"Processing: {key_to_copy}")
                body = response_get["Body"]
                csv_string = body.read().decode("utf-8")
                status = response.get("ResponseMetadata", {}).get("HTTPStatusCode")

                if status == 200:
                    logger.info(f"Successful S3 get_object response. Status - {status}")
                    fsag_data_df = pd.read_csv(
                        StringIO(csv_string), sep=",", dtype="str"
                    )
                    logger.info("Successfully read into dataframe")

                    try:
                        transfer_df = fsag_data_df[needed_columns]
                    except Exception as e:
                        logger.error(f"Exception while filtering the columns")
                        raise e

                    ## get vins with consent in a dataframe
                    vins_with_consent = select_query_to_df(
                        redshift_client,
                        redshift_name,
                        redshift_cluster_id,
                        redshift_user,
                        get_vins_with_consent_query,
                        ["vehicle_vin"],
                    )

                    if vins_with_consent is not None and not vins_with_consent.empty:
                        ## select only vins with consent
                        filtered_df = filter_by_vin_consent(
                            transfer_df, vins_with_consent
                        )
                    else:
                        filtered_df = None
                        logger.info("No vins with consent.")

                    # calculate metrics
                    key_related_metrics_dict = calc_transfer_df_metrics(
                        transfer_df, key_related_metrics_dict
                    )
                    key_related_metrics_dict = calc_vins_with_consent_metrics(
                        vins_with_consent, key_related_metrics_dict
                    )
                    key_related_metrics_dict = calc_filtered_df_metrics(
                        filtered_df, key_related_metrics_dict
                    )
                    key_related_metrics_dict = calc_unique_vins_without_consent_metrics(
                        key_related_metrics_dict[
                            "OPS_FT_3DI_31_contracts-in-FSAG-file-unique-VIN"
                        ],
                        key_related_metrics_dict[
                            "OPS_FT_3DI_32_contracts-in-FSAG-file-with-IDK-consent"
                        ],
                        key_related_metrics_dict,
                    )

                    # publish metrics to cloudwatch
                    publish_metrics(
                        key_related_metrics_dict, cw_client, key_to_copy, stage
                    )

                    # create kpi df
                    kpi_df = create_kpi_df(
                        key_related_metrics_dict, key_to_copy, "Count", stage
                    )

                    if filtered_df is not None:
                        final_df = transform_df(filtered_df, key_to_copy)

                        status = write_parquet(
                            s3_client,
                            final_df,
                            target_data_bucket,
                            "processed_data",
                            parquet_target_key,
                        )

                        # Copy to Redshift
                        if status == 200:
                            logger.info(
                                f"Successful S3 put parquet file. Response status - {status}"
                            )

                            parquet_file_path = os.path.join(
                                f"s3://{target_data_bucket}",
                                "processed_data",
                                parquet_target_key,
                            )
                            ## load to redshift
                            res = load_to_redshift(
                                redshift_client,
                                redshift_name,
                                "contract_staging",
                                redshift_user,
                                redshift_cluster_id,
                                redshift_schema,
                                parquet_file_path,
                                redshift_iam_role,
                            )
                            logger.info(f"Query execution status: {res}")

                        else:
                            logger.error(
                                f"Unsuccessful S3 put_object response. Status - {status}"
                            )
                            raise Exception(
                                f"Failure while writing data frame to {parquet_file_path}"
                            )

                    else:
                        logger.info("No data with consent")

                else:
                    logger.error(
                        f"Unsuccessful S3 get_object response. Status - {status}"
                    )
                    raise Exception(f"Failure while reading input file.")
        else:
            send_sns_notification(
                sns_arn,
                sns_client,
                stage,
                yesterday_date,
                fsag_data_bucket,
                source_folder_prefix,
            )
            logger.info(
                f"No new data found in {fsag_data_bucket}/{source_folder_prefix}/ for {yesterday_date_regex} "
            )
    else:
        logger.info(f"No data found in {fsag_data_bucket}/{source_folder_prefix}/ ")

    ## extra monitoring

    # calculate metrics
    generic_metrics_dict = calc_vins_without_consent_metric(
        generic_metrics_dict,
        redshift_schema,
        client_id_array,
        permission_userrole,
        redshift_client,
        redshift_name,
        redshift_cluster_id,
        redshift_user,
    )
    generic_metrics_dict = calc_newly_added_vins_metric(
        generic_metrics_dict,
        redshift_schema,
        client_id_array,
        permission_userrole,
        redshift_client,
        redshift_name,
        redshift_cluster_id,
        redshift_user,
    )
    generic_metrics_dict = calc_existing_vins_metric(
        generic_metrics_dict,
        redshift_schema,
        client_id_array,
        permission_userrole,
        redshift_client,
        redshift_name,
        redshift_cluster_id,
        redshift_user,
    )

    # publish metrics to cloudwatch
    publish_metrics(generic_metrics_dict, cw_client, "n/a", stage)

    try:
        final_dict = generic_metrics_dict
        final_dict.update(key_related_metrics_dict)
        # create kpi df
        kpi_df = create_kpi_df(final_dict, "n/a", "Count", stage)

        parquet_target_key = f"kpis_{datetime.now()}.parquet"
        status = write_parquet(
            s3_client, kpi_df, target_data_bucket, "kpis/processed", parquet_target_key
        )

        logger.info(f"Successful S3 put parquet file. Response status - {status}")

        parquet_file_path = os.path.join(
            f"s3://{target_data_bucket}", "kpis/processed", parquet_target_key
        )

        if status == 200:
            load_to_redshift(
                redshift_client,
                redshift_name,
                "vwn_monitoring",
                redshift_user,
                redshift_cluster_id,
                "vwn_general",
                parquet_file_path,
                redshift_iam_role,
            )

    except Exception as e:
        logger.error(f"Error when updating kpi table.")
        raise e

    put_metric_alarm(
        cw_client,
        "OPS_FT_3DI_32_contracts-in-FSAG-file-with-IDK-consent_alarm",
        "in alarm when there are no contracts with consent",
        "OPS_FT_3DI_32_contracts-in-FSAG-file-with-IDK-consent",
    )
