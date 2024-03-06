from logging import Logger

import boto3
import numpy as np
import os
import pandas as pd
import pg8000
import sys
import time
from common.cap_redshift_loading import load_to_redshift, get_table
from common.db_utils import get_pg_client
from common.lambda_utils import (
    pack_results,
    get_ssm_parameter,
    get_payload_and_token,
    get_data,
    remaining_lambda_execution_time,
    SEPARATOR,
)
from datetime import datetime as dt
from typing import Dict, List, Optional, Tuple

DMP_DEFAULT_URL = "http://dmp.apps.emea.vwapps.io/mobility-platform/data"

# job statuses
START = "RUNNING"
SUCCESS = "SUCCESS"
FAIL = "FAILED"

DEFAULT_DB_TABLE = "etl_dmp_job"

MAX_RETRIES = 2
# Default sleep for retrying if other running jobs are executing (in seconds)
DEFAULT_SLEEP = 5
MAX_SLEEPS = 10

# Default number of IDs to query for
DEFAULT_BATCH_SIZE = 1000
# Minimum ids so that the lambda will continue pulling from DMP API
MINIMUM_IDS = 100
# Minimum amount of milliseconds required to issue a COPY command to redshift AND insert
# success status in metadata PG, in milliseconds
MIN_MS = 30000

# Whether to execute in Batch (bounded) or "real-time" (unbounded) API query
UNBOUNDED = "unbounded"
BOUNDED = "bounded"
# NOTE: this assumes kpis are stored in DIFFERENT tables! Be careful and avoid merging kpis in the same table
#       WITHOUT adapting this delete statement
DELETE_STMT = "DELETE FROM {table} WHERE id >='{from_id}' AND id <='{to_id}'"

# default type for dataframe
DEFAULT_DTYPE = {
    "id": int,
    "timestamp": int,
    "country": str,
    "period": str,
    "status_reg": int,
    "status_dp": int,
    "status_app": int,
    "app_installed": int,
    "dp_coupled": int,
    "favourite_dealerId": str,
    "app_date": int,
    "os": str,
    "vwConnectVersion": str,
}


def qry(cursor, query: str, logger: Logger) -> None:
    """DRY"""
    logger.info("Executing insert query: {}".format(query))
    cursor.execute(query)


def qry_and_fetchone(cursor, query: str) -> List[int]:
    """DRY"""
    cursor.execute(query)
    return cursor.fetchone()


def close_db_conn(conn, cur) -> None:
    """DRY db bye bye"""
    try:
        cur.close()
        conn.close()
    except pg8000.core.InterfaceError:
        pass


def get_db_client(
    db_pw_param: str,
    db_user: str,
    db_host: str,
    db_port: str,
    db_name: str,
    auto_commit: bool = False,
    ssl: bool = False,
    dry_run: bool = False,
):
    """Utility func for local testing & prod"""
    if not dry_run:
        pwd = get_ssm_parameter(db_param=db_pw_param)
    else:
        pwd = db_pw_param
    return get_pg_client(
        user=db_user,
        host=db_host,
        port=int(db_port),
        db=db_name,
        pwd=pwd,
        auto_commit=auto_commit,
        ssl=ssl,
    )


def managed_close_db_conn(
    conn, cur, success: bool, logger: Logger, msg: str = ""
) -> None:
    """Utility func to assure no zombie connections are left before throwing exception"""
    if not success:
        conn.rollback()
        close_db_conn(conn, cur)
        raise ValueError("Something went WRONG: {}".format(msg))
    conn.commit()
    logger.info("Commit finished successfully. {}".format(msg))
    close_db_conn(conn, cur)


def validate_qry_int_res(res) -> int:
    """utility function to type validate if results from DB look good"""
    if isinstance(res, int) or isinstance(res, str):
        return int(res)
    if res and isinstance(res, list) and len(res) == 1:
        return int(res[0])
    raise ValueError(
        "DB result '{}' needs to be a integer or integer array".format(res)
    )


def result_extractor(res) -> List[int]:
    """utility func to DRY which extracts as int the 2 results from DB"""
    [from_id, retries] = res
    from_id, retries = validate_qry_int_res(res=from_id), validate_qry_int_res(
        res=retries
    )
    return [from_id, retries]


def validate_result_list(res: List[int]) -> bool:
    """utility func to DRY validation of DB result set"""
    return (
        res
        and isinstance(res, list)
        and len(res) > 1
        and all((isinstance(res[0], int), isinstance(res[1], int)))
    )


def validate_first_time_job_run(kpi: str, cursor, db_table: str) -> bool:
    """validates if it is the first time a job is running based on DB results"""
    validation_qry = "SELECT count(from_id) FROM {} WHERE kpi='{}';".format(
        db_table, kpi
    )

    row_count = qry_and_fetchone(cursor=cursor, query=validation_qry)
    return validate_qry_int_res(res=row_count) == 0


def get_running_state_jobs_qry(kpi: str, running: bool, db_table: str) -> str:
    return """
        SELECT from_id, retries
        FROM {table}
        WHERE kpi='{kpi}'
            AND status='{status}'
            AND finished_at IS NULL
            AND created_at + (15 * interval '1 minute') {operator} NOW();
    """.format(
        table=db_table, kpi=kpi, status=START, operator=">" if running else "<"
    )


def validate_running_jobs(kpi: str, cursor, db_table: str):
    """validates if there is any job currently running"""
    validation_qry = get_running_state_jobs_qry(
        kpi=kpi, running=True, db_table=db_table
    )
    return qry_and_fetchone(cursor=cursor, query=validation_qry)


def validate_timed_out_jobs(kpi: str, cursor, db_table: str):
    """validates if there is any job timed-out on the DB"""
    validation_qry = get_running_state_jobs_qry(
        kpi=kpi, running=False, db_table=db_table
    )
    return qry_and_fetchone(cursor=cursor, query=validation_qry)


def validate_failed_jobs(kpi: str, cursor, db_table: str):
    validation_qry = """
        SELECT failed.from_id, failed.retries
        FROM (
            SELECT from_id, max(retries) AS retries
            FROM {table}
            WHERE status = '{failed}'
                AND kpi='{kpi}'
                AND finished_at IS NOT NULL
            GROUP BY from_id
            )failed
        LEFT JOIN (
            SELECT from_id, max(retries) AS retries
            FROM {table}
            WHERE (status='{running}' AND kpi='{kpi}' AND finished_at IS NULL)
            OR (status='{success}' AND kpi='{kpi}' AND finished_at IS NOT null)
            GROUP BY from_id
            )running
        ON (failed.from_id = running.from_id
        and failed.retries = running.retries-1 )
        WHERE running.retries IS NULL
    """.format(
        table=db_table, kpi=kpi, running=START, failed=FAIL, success=SUCCESS
    )
    return qry_and_fetchone(cursor=cursor, query=validation_qry)


def insert_new_job(
    kpi: str,
    cursor,
    from_id: int,
    logger: Logger,
    db_table: str,
    retries: int = 0,
) -> List[int]:
    """executes for the first time a job OR a retry for a given id range"""
    insert_qry = """
        INSERT INTO {table} (kpi, from_id, status, created_at, retries)
        VALUES ('{kpi}', {from_id}, '{job_status}', NOW(), {retries})
        RETURNING from_id, retries;
    """.format(
        table=db_table,
        kpi=kpi,
        from_id=from_id,
        job_status=START,
        retries=retries,
    )
    logger.info(insert_qry)
    return qry_and_fetchone(cursor=cursor, query=insert_qry)


def manage_new_job(
    kpi: str,
    cursor,
    from_id: int,
    db_table: str,
    error_msg: str,
    logger: Logger,
    retries: int = 0,
):
    res = insert_new_job(
        kpi=kpi,
        cursor=cursor,
        from_id=from_id,
        db_table=db_table,
        logger=logger,
        retries=retries,
    )
    if not res or not isinstance(res, list) or not len(res or []) == 2:
        raise ValueError(error_msg.format(from_id=from_id, retries=retries, res=res))
    return result_extractor(res)


def update_finished_db(
    kpi: str,
    from_id: int,
    to_id: Optional[int],
    success: bool,
    cursor,
    retries: int,
    returning: str,
    db_table: str,
    logger: Logger,
    details: Optional[str] = None,
):
    """Updates a job status in the DB"""

    to_id_update = "" if not to_id else ",to_id={}".format(to_id)
    details_update = (
        "" if not details else ",details='{}'".format(details.replace("'", ""))
    )
    update_qry = """
        UPDATE {table} SET status = '{status}',
        finished_at = NOW() {to_id} {details}
        WHERE kpi='{kpi}' AND from_id = {from_id} AND retries = {retries}
        RETURNING {returning};
    """.format(
        table=db_table,
        status=SUCCESS if success else FAIL,
        kpi=kpi,
        from_id=from_id,
        to_id=to_id_update,
        details=details_update,
        retries=retries,
        returning=returning,
    )
    logger.info(update_qry)
    return qry_and_fetchone(cursor=cursor, query=update_qry)


def manage_timed_out_jobs(
    kpi: str, from_id: int, retries: int, db_table: str, cursor, logger: Logger
) -> List[int]:
    """
    handles a particular job that is in a stale state (lambda timed out without
    updating state to "FAILED")
    Note: doesn't care how many retries there need to be;
    """
    logger.warning(
        "Detected a stale job (kpi: '{}', from_id '{}', retries: '{}'), thus starting by updating "
        "it's status to failed".format(kpi, from_id, retries)
    )
    # 1a) update existing row to status failed, return retries column
    retries = update_finished_db(
        kpi=kpi,
        from_id=from_id,
        to_id=None,
        retries=retries,
        db_table=db_table,
        logger=logger,
        success=False,
        cursor=cursor,
        returning="retries",
        details="STALE JOB",
    )
    retries = validate_qry_int_res(res=retries)
    logger.info("Creating a new retry ({}) for same job".format(retries + 1))
    # 1b) create a new retry, add the previous retries + 1
    error_msg = "Failed to retry a failed job for from_id {from_id} for retry nr. {retries}; res: {res}"
    return manage_new_job(
        kpi=kpi,
        cursor=cursor,
        from_id=from_id,
        db_table=db_table,
        logger=logger,
        error_msg=error_msg,
        retries=retries + 1,
    )


def manage_failed_jobs(
    kpi: str, from_id: int, retries: int, db_table: str, cursor, logger: Logger
):
    """handles a particular job that failed in the past (if number of
    retries smaller that MAX_RETRIES"""
    logger.warning(
        "Detected a failed job (kpi: '{}', from_id '{}', retries: '{}'), "
        "thus restarting at the same point 'from_id'".format(kpi, from_id, retries)
    )

    error_msg = "Failed to update failed job from_id {from_id} for retry nr. {retries}; res: {res}"
    return manage_new_job(
        kpi=kpi,
        cursor=cursor,
        db_table=db_table,
        from_id=from_id,
        error_msg=error_msg,
        logger=logger,
        retries=retries + 1,
    )


def manage_job_finish(
    kpi: str,
    from_id: int,
    to_id: Optional[int],
    retries: int,
    db_conn_props: Dict[str, str],
    db_table: str,
    success: bool,
    logger: Logger,
    details: Optional[str] = None,
    dry_run: bool = False,
) -> bool:
    """Update DB with final job status"""
    conn, cur = get_db_client(dry_run=dry_run, **db_conn_props)
    returned_to_id = update_finished_db(
        kpi=kpi,
        from_id=from_id,
        to_id=to_id,
        retries=retries,
        db_table=db_table,
        details=details,
        success=success,
        logger=logger,
        cursor=cur,
        returning="to_id",
    )
    final_success = (
        returned_to_id
        and isinstance(returned_to_id, list)
        and len(returned_to_id) > 0
        and returned_to_id[0] == to_id
    )
    if final_success:
        conn.commit()
    else:
        conn.rollback()
    close_db_conn(conn=conn, cur=cur)
    return final_success


def new_job(kpi: str, cursor, logger: Logger, db_table: str):
    """Starts a new job for a new range of Ids (note: assumes no previous
    timed out OR failed jobs exist)"""
    # get previous job maximum ID
    control_query = "SELECT max(to_id) FROM {} WHERE kpi = '{}';".format(db_table, kpi)
    max_id_prev = qry_and_fetchone(cursor=cursor, query=control_query)
    max_id_prev = validate_qry_int_res(max_id_prev)
    from_id = max_id_prev + 1
    logger.info(
        "New from_id is {from_id} and previous to_id was {to_id};".format(
            from_id=from_id, to_id=max_id_prev
        )
    )
    error_msg = (
        "Failed to add a new job from_id {from_id} for retry nr. {retries}; res: {res}"
    )
    return manage_new_job(
        kpi=kpi,
        cursor=cursor,
        from_id=from_id,
        db_table=db_table,
        error_msg=error_msg,
        logger=logger,
        retries=0,
    )


def control_flow_get_id(
    kpi: str,
    cursor,
    logger: Logger,
    initial_from_id: int,
    db_table: str,
    sleep_retry_count: int = 0,
) -> List[int]:
    """Core Business logic to retrieve current IDs to use for querying DMP"""
    if validate_first_time_job_run(kpi=kpi, cursor=cursor, db_table=db_table):
        logger.info(
            "Executing job for first time, thus starting at ID: '{}'".format(
                initial_from_id
            )
        )
        error_msg = "Failed to create first time job for from_id {from_id}, retry nr. {retries}; res: {res}"
        return manage_new_job(
            kpi=kpi,
            cursor=cursor,
            db_table=db_table,
            from_id=initial_from_id,
            logger=logger,
            error_msg=error_msg,
        )

    # Is there another job currently running
    running_jobs = validate_running_jobs(kpi=kpi, cursor=cursor, db_table=db_table)
    if validate_result_list(res=running_jobs):
        if sleep_retry_count < MAX_SLEEPS:
            logger.warning(
                "Currently another job is running. Sleeping {} seconds".format(
                    DEFAULT_SLEEP
                )
            )
            time.sleep(DEFAULT_SLEEP)
            return control_flow_get_id(
                kpi=kpi,
                cursor=cursor,
                db_table=db_table,
                logger=logger,
                initial_from_id=initial_from_id,
                sleep_retry_count=sleep_retry_count + 1,
            )
        logger.warning("Achieved maximum amount of sleep retries. Aborting this job.")
        sys.exit(0)

    # Validate if there is any long-standing stale job (more than 5 mins, when lambda already ended)
    timed_out_jobs = validate_timed_out_jobs(kpi=kpi, cursor=cursor, db_table=db_table)
    if validate_result_list(res=timed_out_jobs):
        return manage_timed_out_jobs(
            kpi=kpi,
            cursor=cursor,
            db_table=db_table,
            from_id=timed_out_jobs[0],
            logger=logger,
            retries=timed_out_jobs[1],
        )

    # Validate if there are any failed jobs
    failed_jobs = validate_failed_jobs(kpi=kpi, cursor=cursor, db_table=db_table)
    if validate_result_list(res=failed_jobs):
        return manage_failed_jobs(
            kpi=kpi,
            cursor=cursor,
            from_id=failed_jobs[0],
            logger=logger,
            retries=failed_jobs[1],
            db_table=db_table,
        )

    logger.info(
        "Did not find any Stale (timed-out) job, nor any failed job; thus a new job can be started"
    )
    return new_job(kpi=kpi, cursor=cursor, db_table=db_table, logger=logger)


def get_id(
    kpi: str,
    mode: str,
    initial_from_id: int,
    db_table: str,
    logger: Logger,
    db_conn_props: Dict[str, str],
    dry_run: bool,
) -> List[int]:
    """Retrieves new Id that will be the starting point to query DMP API, along with nr. of retries"""
    logger.info(
        "Retrieving db client with dry-run mode set to '{}' and with credentials properties: {}".format(
            dry_run, db_conn_props
        )
    )
    conn, cur = get_db_client(dry_run=dry_run, **db_conn_props)
    result = control_flow_get_id(
        kpi=kpi,
        cursor=cur,
        db_table=db_table,
        logger=logger,
        initial_from_id=initial_from_id,
    )
    if not result or not isinstance(result, list) or not len(result or []) == 2:
        raise ValueError(
            "Returned id and retries from DB is NOT workable ({}), exiting.".format(
                result
            )
        )
    [from_id, retries] = result
    logger.info(
        "After querying in '{}' mode, obtained from_id is '{}', "
        "with number of retries '{}'".format(mode, from_id, retries)
    )
    from_id, retries = validate_qry_int_res(res=from_id), validate_qry_int_res(
        res=retries
    )
    managed_close_db_conn(conn=conn, cur=cur, logger=logger, success=True)
    return [from_id, retries]


def query_dmp_data(
    kpi: str,
    from_id: int,
    mode: str,
    logger: Logger,
    dmp_base_url: str,
    batch_size: int = DEFAULT_BATCH_SIZE,
    client_id_key: str = "DMP_CLIENT_ID",
    client_secret: str = "DMP_CLIENT_SECRET",
    dry_run: bool = False,
    to_id: Optional[int] = None,
) -> List[Dict[str, str]]:
    # security bureaucracies
    logger.info("Getting DMP token")
    token = (
        get_payload_and_token(client_id_key=client_id_key, client_secret=client_secret)
        if not dry_run
        else "mock-token"
    )

    header = {"Authorization": "Bearer {}".format(token)}
    base_url = "{}/{}".format(dmp_base_url, kpi)

    if isinstance(to_id, int):
        if to_id <= from_id:
            raise ValueError(
                "Provided to_id ('{}') is smaller than from_id ('{}') - "
                "please provide a valid range".format(to_id, from_id)
            )
        params = {"q": '{id:{$rg:"' + str(from_id) + "," + str(to_id) + '"}}'}
    elif mode == UNBOUNDED:
        params = {"q": "{id:{$gt:" + str(from_id) + "}}"}
    else:
        params = {
            "q": '{id:{$rg:"' + str(from_id) + "," + str(from_id + batch_size) + '"}}'
        }

    logger.info(
        'Querying API for url {} with params {} for KPI: {} from ID {} in "{}" mode'.format(
            base_url, params, kpi, from_id, mode
        )
    )
    if not dry_run:
        result_list = get_data(url=base_url, header=header, params=params)
    else:
        result_list = [
            {
                "id": 215282436,
                "timestamp": 1518813418792,
                "country": "someCountry",
                "period": "somePeriod",
                "status_reg": 0,
                "status_dp": 0,
                "status_app": 0,
                "app_installed": 1,
                "dp_coupled": 1,
                "favourite_dealerId": "someFavouriteDealer",
                "app_date": 1518813418604,
            },
            {
                "id": 215283436,
                "timestamp": 1518813418993,
                "country": "someCountry2",
                "period": "somePeriod2",
                "status_reg": 1,
                "status_dp": 1,
                "status_app": 1,
                "app_installed": 1,
                "dp_coupled": 1,
                "favourite_dealerId2": "someFavouriteDealer2",
                "app_date": 1518813418960,
            },
            {
                "id": 215284436,
                "timestamp": 1518864581943,
                "country": "someCountry3",
                "period": "somePeriod3",
                "status_reg": 0,
                "status_dp": 0,
                "status_app": 0,
                "app_installed": 1,
                "dp_coupled": 0,
                "favourite_dealerId3": "someFavouriteDealer3",
                "app_date": 1518839347905,
            },
            {
                "id": 215285436,
                "timestamp": 1518864582249,
                "country": "someCountry4",
                "period": "somePeriod4",
                "status_reg": 0,
                "status_dp": 0,
                "status_app": 1,
                "app_installed": 1,
                "dp_coupled": 0,
                "favourite_dealerId4": "someFavouriteDealer4",
                "app_date": 1518839348213,
            },
        ]
    len_res = len(result_list)
    logger.info(
        "Request result length is {} and first records (max 50) are: {}".format(
            len_res, result_list[0 : (len_res if len_res < 50 else 49)]
        )
    )
    return result_list


# for some situation to process the raw data first if necessary
#   1. situation: 2020.03.10, new api changed the data type of col status_reg and other 3 to double => not needed any more
def process_result(result_list):
    for entry in result_list:
        if not entry:
            return
        else:
            entry["status_reg"] = int(entry["status_reg"]) if entry["status_reg"] else 0
            entry["status_dp"] = int(entry["status_dp"]) if entry["status_dp"] else 0
            entry["status_app"] = int(entry["status_app"]) if entry["status_app"] else 0
            entry["app_installed"] = (
                int(entry["app_installed"]) if entry["app_installed"] else 0
            )


def store_dmp_date(
    kpi: str,
    from_id: int,
    to_id: int,
    result_list: List[Dict[str, str]],
    kpi_cols: List[str],
    logger: Logger,
    s3_bucket: str,
    s3_prefix: str,
    dry_run: bool = False,
) -> str:
    """Handles storing locally and in S3 the DMP retrieved data"""

    # changed the default dtype to object because sometimes
    # the object can be empty, and by default the dataframe will convert all other values to float
    # (i.e. 0 => 0.0)
    # 2020.03.10
    out = pd.DataFrame(result_list, dtype=object)

    # prepare pandas DF
    logger.info("Preparing pandas DF")
    # complete_out = pd.DataFrame(np.empty((len(out), len(KPI_COL_MAP[kpi])), dtype=np.unicode),
    #                             columns=KPI_COL_MAP[kpi])
    complete_out = pd.DataFrame(
        np.empty((len(out), len(kpi_cols)), dtype=np.unicode), columns=kpi_cols
    )

    # force the data type (otherwise bug issue because the pandas will convert the int to double)
    # complete_out.astype(DEFAULT_DTYPE)

    # Copy the data from out to complete_out
    #   (when the predefined columns not matching with the raw data, this step make sure
    #   that all the cols from raw data will be copied into the output dataframe complete_out)
    out_columns = list(out.keys())
    for c in out_columns:
        complete_out[c] = out[c]

    # write to file
    _partial_file_name = "{kpi}_from_id_{from_id}_to_id_{to_id}".format(
        kpi=kpi, from_id=from_id, to_id=to_id
    )
    file_name = os.path.join("/tmp", _partial_file_name + ".csv")
    logger.info("Writing into file path {}".format(file_name))
    # dmp_data_csv = complete_out.to_csv(file_name, encoding="utf-8", index=False)

    # Push to S3
    logger.info("Pushing results into S3")
    processed_date = dt.now()
    date_partition = dt.today().strftime("%Y/%m/%d")
    s3_key = (
        s3_prefix
        + "/"
        + kpi
        + "/"
        + date_partition
        + "/"
        + _partial_file_name
        + "_"
        + processed_date.isoformat()
        + ".csv"
    )

    logger.info("Pushing key '{}' to S3 bucket '{}'".format(s3_key, s3_bucket))
    if not dry_run:
        s3 = boto3.resource("s3")
        s3.Bucket(s3_bucket).upload_s3_file(file_name, s3_key)

    return s3_key


def _get_delete_stmt(s3_key: str, from_id: int, to_id: int, logger: Logger) -> str:
    table_name, _ = get_table(key=s3_key, logger=logger)
    delete_stmt = DELETE_STMT.format(table=table_name, from_id=from_id, to_id=to_id)
    return "{}{}{}".format(s3_key, SEPARATOR, delete_stmt)


def _sink_to_s3(
    kpi: str,
    from_id: int,
    to_id: int,
    result_list: List[Dict[str, str]],
    kpi_cols: List[str],
    s3_bucket: str,
    s3_prefix: str,
    logger: Logger,
    dry_run: bool = False,
) -> Tuple[str, str]:
    logger.info(
        "Casting a result set of size '{}' and with last offset id '{}' to pd df".format(
            len(result_list), to_id
        )
    )
    s3_key = store_dmp_date(
        kpi=kpi,
        from_id=from_id,
        to_id=int(to_id),
        result_list=result_list,
        kpi_cols=kpi_cols,
        s3_prefix=s3_prefix,
        logger=logger,
        s3_bucket=s3_bucket,
        dry_run=dry_run,
    )
    logger.info(
        "Stored file in s3 as object key {}. Loading into Redshift...".format(s3_key)
    )

    file = _get_delete_stmt(s3_key=s3_key, from_id=from_id, to_id=to_id, logger=logger)
    envelop_s3_key = pack_results(files=[file], bucket=s3_bucket)
    return s3_key, envelop_s3_key


def db_assisted_create_dmp_file(
    kpi: str,
    mode: str,
    context,
    logger: Logger,
    db_conn_props: Dict[str, str],
    dwh_conn_props: Dict[str, str],
    s3_bucket: str,
    s3_prefix: str,
    dmp_base_url: str,
    kpi_cols: List[str],
    initial_from_id: int,
    client_id_key: str,
    client_secret: str,
    job_db_table: str,
    batch_size: int = DEFAULT_BATCH_SIZE,
    max_retries: int = MAX_RETRIES,
    minimum_ids: int = MINIMUM_IDS,
    dry_run: bool = False,
):
    """
    Controls the full flow for DMP workflow using a DB to sync offset and results state:

    1) Get starting last ID to pull data (which either starts a new job or recovers from a failed/stale job)
    2) sink data into S3
    3) check if there is time left to load both in Redshift and commit into postgres
      (since these are not atomic ops); if so, then execute the following sequentially:
      A) load into Redshift
      B) write in jobs metadata DB confirmation of successfull job

    """
    logger.info("Running pipeline with dry-run mode set to {}".format(dry_run))
    # step 1) query IDS
    result = get_id(
        kpi=kpi,
        mode=mode,
        logger=logger,
        db_table=job_db_table,
        initial_from_id=initial_from_id,
        db_conn_props=db_conn_props,
        dry_run=dry_run,
    )
    if not result or not isinstance(result, list) or not len(result or []) == 2:
        raise ValueError(
            "Returned list of IDs is NOT workable ({}), exiting.".format(result)
        )
    [from_id, retries] = result
    if retries >= max_retries:
        mode = BOUNDED
        logger.warning(
            "Number of retries ('{}') exceeds the default ('{}'), thus querying in '{}' "
            "mode with a batch size of {};".format(
                retries, max_retries, mode, batch_size
            )
        )
    logger.info(
        "Querying DMP for KPI '{}' starting at ID: {} in mode '{}';".format(
            kpi, from_id, mode
        )
    )
    result_list = query_dmp_data(
        kpi=kpi,
        from_id=from_id,
        mode=mode,
        logger=logger,
        client_id_key=client_id_key,
        client_secret=client_secret,
        dmp_base_url=dmp_base_url,
        batch_size=batch_size,
        dry_run=dry_run,
    )

    # result_list = process_result(result_list)

    if not result_list or len(result_list or []) == 0:
        logger.warning("Result is empty: {}; exiting".format(result_list))
        manage_job_finish(
            kpi=kpi,
            from_id=from_id,
            to_id=None,
            retries=retries,
            db_table=job_db_table,
            dry_run=dry_run,
            db_conn_props=db_conn_props,
            logger=logger,
            success=False,
            details="Result from DMP API is empty",
        )
        return

    # Getting last obtained ID from results:
    last_to_id = max([int(item.get("id", 0)) for item in result_list])
    if not last_to_id or last_to_id == 0 or last_to_id < from_id:
        err_msg = (
            "Last ID retrieved is invalid (from_id={from_id}, to_id={to_id})".format(
                from_id=from_id, to_id=last_to_id
            )
        )
        manage_job_finish(
            kpi=kpi,
            from_id=from_id,
            to_id=None,
            retries=retries,
            db_table=job_db_table,
            logger=logger,
            db_conn_props=db_conn_props,
            success=False,
            details=err_msg,
            dry_run=dry_run,
        )
        raise ValueError(
            err_msg + "please check result list: {res}".format(res=result_list)
        )

    if last_to_id - from_id < minimum_ids:
        exit_msg = (
            "The number of remaining Ids is too small (from_id {}, to_id {}, diff {}), thus "
            "halting infinite execution or purpose. Nothing to worry about, you can safely ignore "
            "this 'failed' state".format(from_id, last_to_id, last_to_id - from_id)
        )
        logger.info(exit_msg)
        manage_job_finish(
            kpi=kpi,
            from_id=from_id,
            to_id=None,
            retries=retries,
            db_table=job_db_table,
            logger=logger,
            db_conn_props=db_conn_props,
            success=False,
            details=exit_msg,
            dry_run=dry_run,
        )
        return

    s3_key, envelop_s3_key = _sink_to_s3(
        kpi=kpi,
        from_id=from_id,
        to_id=last_to_id,
        result_list=result_list,
        kpi_cols=kpi_cols,
        s3_bucket=s3_bucket,
        s3_prefix=s3_prefix,
        logger=logger,
        dry_run=dry_run,
    )

    if remaining_lambda_execution_time(context, min_ms=MIN_MS):
        results = load_to_redshift(
            event=envelop_s3_key,
            db_host=dwh_conn_props["DWH_HOST"],
            db_port=dwh_conn_props["DWH_PORT"],
            db_name=dwh_conn_props["DWH_NAME"],
            db_user=dwh_conn_props["DWH_USER"],
            db_param=dwh_conn_props["DWH_PW_PARAM"],
            iam_role=dwh_conn_props["IAM_ROLE"],
            logger=logger,
            dry_run=dry_run,
        )
        logger.info(
            "Finished COPY Command in Redshift successfully. Updating DB with successful job status..."
        )
        while True:
            success = manage_job_finish(
                kpi=kpi,
                from_id=from_id,
                to_id=int(last_to_id),
                db_table=job_db_table,
                logger=logger,
                dry_run=dry_run,
                retries=retries,
                db_conn_props=db_conn_props,
                success=True,
                details=s3_key,
            )
            if success:
                break
            logger.error(
                "Failed to update metadata DB with success status for s3 key '{}' "
                "although data was already loaded into Redshift!!! Retrying ...".format(
                    s3_key
                )
            )
            time.sleep(1)

        logger.info("Finished import to redshift for key: {}".format(s3_key))
        return results

    fail_msg = (
        "Remaining time is less than the minimum "
        "defined ({}), thus failing lambda so that the same IDs are repeated in a retry execution".format(
            MIN_MS
        )
    )
    logger.warning(fail_msg)
    manage_job_finish(
        kpi=kpi,
        from_id=from_id,
        to_id=None,
        retries=retries,
        db_conn_props=db_conn_props,
        success=False,
        details=fail_msg,
        db_table=job_db_table,
        logger=logger,
        dry_run=dry_run,
    )
    sys.exit(1)


def simple_create_dmp_file(
    kpi: str,
    from_id: int,
    to_id: int,
    client_id_key: str,
    client_secret: str,
    dmp_base_url: str,
    kpi_cols: List[str],
    s3_bucket: str,
    s3_prefix: str,
    dwh_conn_props: Dict[str, str],
    logger: Logger,
    batch_size: int = DEFAULT_BATCH_SIZE,
    dry_run: bool = False,
):
    """
    Simplified creation of DMP file, useful ONLY for manual pipeline re-runs
    Note: it is recommended to avoid running this option concurrently with more instances for the same kpi

    """
    logger.info(
        "Querying DMP for KPI '{}' starting at ID: '{}' until ID: '{}';".format(
            kpi, from_id, to_id
        )
    )
    result_list = query_dmp_data(
        kpi=kpi,
        from_id=from_id,
        mode=BOUNDED,
        logger=logger,
        client_id_key=client_id_key,
        client_secret=client_secret,
        dmp_base_url=dmp_base_url,
        batch_size=batch_size,
        dry_run=dry_run,
    )
    s3_key, envelop_s3_key = _sink_to_s3(
        kpi=kpi,
        from_id=from_id,
        to_id=to_id,
        result_list=result_list,
        kpi_cols=kpi_cols,
        s3_bucket=s3_bucket,
        s3_prefix=s3_prefix,
        logger=logger,
        dry_run=dry_run,
    )
    results = load_to_redshift(
        event=envelop_s3_key,
        db_host=dwh_conn_props["DWH_HOST"],
        db_port=dwh_conn_props["DWH_PORT"],
        db_name=dwh_conn_props["DWH_NAME"],
        db_user=dwh_conn_props["DWH_USER"],
        db_param=dwh_conn_props["DWH_PW_PARAM"],
        iam_role=dwh_conn_props["IAM_ROLE"],
        logger=logger,
        dry_run=dry_run,
    )
    logger.info(
        "Finished COPY Command in Redshift successfully for id range: [{},{}]".format(
            from_id, to_id
        )
    )
    return results
