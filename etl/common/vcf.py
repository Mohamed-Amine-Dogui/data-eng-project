"""
    Common VCF utility functions
"""

from logging import Logger

import json
import os
import requests
from common.consts import (
    VCF_M,
    VCF_E,
    VCF_API_USAGE,
)
from common.lambda_utils import (
    get_header_token,
    sink_s3,
    sink_csv,
    SEPARATOR,
)
from datetime import timedelta, datetime as dt
from typing import Dict, Any, List, Optional, Tuple, Callable

VCF_APIS: str = "https://flashlight-crocodile-{}.apps.emea.vwapps.io/statistics/{}"

VCF_API_ENDPOINT_MAP: Dict[str, str] = {
    VCF_M: VCF_M,
    VCF_E: VCF_E,
    VCF_API_USAGE: "apiusage",
}

API_ENVS = ["sandbox", "production"]
# NOTE: implemented following 3 hashmaps so that they are retro-compatible with previous code
VCF_TOKEN_URL = {
    env: os.environ.get("{}_TOKEN_URL".format(env.upper())) for env in API_ENVS
}

CLIENT_ID_KEY = {env: "{}_CLIENT_ID".format(env.upper()) for env in API_ENVS}

CLIENT_SECRET = {env: "{}_CLIENT_SECRET".format(env.upper()) for env in API_ENVS}


def _get_query_params(date: str) -> Dict[str, str]:
    """Defines query time range for VCF API based on number of days param"""
    return {"from": date, "to": date}


def source_vcf_data(
    url: str,
    token_url: str,
    date: str,
    client_id_key: str = "CLIENT_ID",
    client_secret: str = "CLIENT_SECRET",
) -> Dict[str, Any]:
    """Queries VCF API for data"""
    headers = get_header_token(
        url=token_url, client_id_key=client_id_key, client_secret=client_secret
    )
    params = _get_query_params(date=date)
    try:
        result = requests.get(url, headers=headers, params=params).content
    except Exception as e:
        result = dict(error=str(e))
    return json.loads(result)


def sink_vcf_data(
    data: List[Dict[str, Any]],
    data_type: str,
    env: str,
    processed_date: str,
    bucket: str,
    logger: Logger,
) -> str:
    """Writes CSV locally to /tmp/ and then to S3, returns S3 object path"""

    file_name = "{}_{}_{}_vcf.csv".format(processed_date, data_type, env)
    local_path = os.path.join("/tmp/{}".format(file_name))

    sink_csv(file_name=local_path, data=data)
    logger.info("Successfully sinked to local path: {}".format(local_path))
    s3_prefix = "vcf/{}/{}".format(data_type, env)
    return sink_s3(
        prefix=s3_prefix,
        file_name=file_name,
        local_path=local_path,
        bucket=bucket,
    )


def core_pipeline(
    params: Dict[str, str],
    dates_interval: List[str],
    logger: Logger,
    data_processor: Callable[[Any], Any],
    keys: List[str],
    new_errors: List[Dict[str, str]],
) -> Tuple[List[str], List[Dict[str, str]]]:
    """Core VCF pipeline logic"""
    vcf_type, env, s3_bucket = (
        params["vcf_type"],
        params["env"],
        params["s3_bucket"],
    )
    table_name, custom_delete_stmt = (
        params["table_name"],
        params["custom_delete_stmt"],
    )
    url = VCF_APIS.format(env, VCF_API_ENDPOINT_MAP[vcf_type])
    logger.info(
        "Querying API for URL {} for VCF type {} and range of days: {}".format(
            url, vcf_type, dates_interval
        )
    )
    for day in dates_interval:
        data: Dict[str, Any] = source_vcf_data(
            url=url,
            token_url=VCF_TOKEN_URL[env],
            client_id_key=CLIENT_ID_KEY[env],
            client_secret=CLIENT_SECRET[env],
            date=day,
        )
        error = dict()
        # Note: current API behaviour: either respond w/ nothing, OR return json
        got_errors = isinstance(data, dict) and data.get("error")
        if len(data) == 0 or got_errors:
            error["msg"] = (
                "Failed to retrieve data for {} days ago for VCT type {}; "
                "returned API response was: '{}'".format(day, vcf_type, data)
            )
            logger.error(error["msg"])
            error["date"] = day
            new_errors.append(error)
        else:
            if len(data[0]["clients"]) == 0:
                logger.info("No clients found in the data on the day: " + day)
                continue
            else:
                logger.info("Successfully received data: {}".format(data))
                if isinstance(data, list):
                    data = data[0]

                data: List[Dict[str, str]] = data_processor(data=data, env=env)
                logger.info("Successfully parsed received data: {}".format(data))

                s3_key = sink_vcf_data(
                    data=data,
                    env=env,
                    data_type=vcf_type,
                    processed_date=day,
                    bucket=s3_bucket,
                    logger=logger,
                )
                logger.info(
                    "Successfully received results from API and sinked data to S3 object {}".format(
                        s3_key
                    )
                )
                delete_stmt = "DELETE FROM {table} WHERE date='{date}' AND api_environment='{env}'".format(
                    table=table_name, date=day, env=env
                )
                delete_stmt += custom_delete_stmt
                logger.info(
                    "Adding the following pre-step for redshift to clean redshift table before loading: {}".format(
                        delete_stmt
                    )
                )
                keys.append("{}{}{}".format(s3_key, SEPARATOR, delete_stmt))
    return keys, new_errors


def get_date_interval(
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    days: Optional[int] = None,
):
    """factory for date interval extractor functions for retrieving a date interval"""
    if not from_date and not to_date and not days:
        raise ValueError("Need to specify either from_date and to_date, or days")
    if from_date and to_date:
        return extract_date_interval_from_dates(from_date=from_date, to_date=to_date)
    return extract_date_interval_from_days(days=days)


def extract_date_interval_from_days(days: int) -> List[str]:
    """calculates X days from the current day, where X is a provided param"""
    today = dt.now()
    if days < 2:
        days = 2
    interval = list(reversed(range(1, days)))
    return [(today - timedelta(days=day)).strftime("%Y-%m-%d") for day in interval]


def extract_date_interval_from_dates(from_date: str, to_date: str) -> List[str]:
    """calculates all days within a period between two dates"""
    to_date = dt.strptime(to_date, "%Y-%m-%d").date()
    from_date = dt.strptime(from_date, "%Y-%m-%d").date()
    delta = to_date - from_date
    return [
        (from_date + timedelta(d)).strftime("%Y-%m-%d") for d in range(delta.days + 1)
    ]
