from logging import Logger

import urllib
from typing import List, Optional, Tuple, Dict, Any, Union

# Allow for seamless unit testing
from common.db_utils import redshift_build_copy_cmd, get_pg_client
from common.lambda_utils import get_ssm_parameter
from common.consts import (
    DMP,
    SKODA_DMP,
    VCF,
    WE_EXP,
    AUTO_IMP,
    PROPS,
    TABLE,
    LOAD_PARAMS,
    CARNET_TABLE,
    PREPROCESS_DELETE,
)


def get_table(key: str, logger: Logger) -> Tuple[Optional[str], Optional[str]]:
    """Busines logic to retrieve the correct table to
    forward data to via S3 key object"""
    key_split: List[str] = key.split("/")
    logger.info(
        "Infering redshift table name and statement props from key: {}".format(
            key_split
        )
    )
    _table = key_split[0]
    if LOAD_PARAMS.get(_table):
        data = LOAD_PARAMS[_table]
        if _table in [DMP, SKODA_DMP, VCF, WE_EXP]:
            kpi: str = key_split[1]
            return data[kpi][TABLE], data[kpi][PROPS]
        if _table == AUTO_IMP:
            # it is established that file_name should be name of target table
            table_name = key_split[1]
            return table_name, data[PROPS]

        return data[TABLE], data[PROPS]
    logger.warning("Table {} not defined".format(_table))
    return None, None


def _filter_tables(filter_key_criteria: str = CARNET_TABLE) -> List[str]:
    """optionally filter tables based on a criteria"""
    return [
        LOAD_PARAMS[tbl][TABLE]
        for tbl in list(
            filter(
                lambda x: LOAD_PARAMS[x].get(filter_key_criteria),
                LOAD_PARAMS.keys(),
            )
        )
    ]


def _get_carnet_tables() -> List[str]:
    """Utility function to allow easy addition of CARNET tables in LOAD_PARAMS
    without having to update code"""
    return _filter_tables(filter_key_criteria=CARNET_TABLE)


def _get_pre_process(table: str, logger: Logger) -> Optional[str]:
    """
    Optional Redshift pre-processing SQL statement for a given table;

    Note: in order to keep the job idempotent, avoid - IF possible -
    truncating CARNET tables,
          and preferred delete statement in order to have possibility of a
          transaction (and potentially rollback)
    """
    if table in _get_carnet_tables() or table in _filter_tables(
        filter_key_criteria=PREPROCESS_DELETE
    ):
        logger.info(
            "Adding delete statement as a pre-processing step for table {}".format(
                table
            )
        )
        return "DELETE FROM {}".format(table)


def process_records(
    records: List[Dict[str, Any]],
    step_function_triggered: bool,
    cur,
    conn,
    logger: Logger,
    iam_role: str,
    dry_run: bool = False,
) -> Dict[str, Union[List[Optional[Any]], List[Optional[Exception]]]]:
    """Packs records"""
    exc = None
    success, errors = [], []
    for record in records:
        s3_data = record.get("s3", {})
        bucket = s3_data.get("bucket", {}).get("name")
        key = s3_data.get("object", {}).get("key")
        delete_query = s3_data.get("delete_query")
        logger.info(
            "Extracted the following path: {}/{}; potential pre-delete stmt: {}".format(
                bucket, key, delete_query
            )
        )
        if not step_function_triggered:
            key = urllib.parse.unquote_plus(key, encoding="utf-8")

        table, options = get_table(key=key, logger=logger)
        if table and options:
            prepossess_step: Optional[str] = (
                _get_pre_process(table=table, logger=logger) or delete_query
            )
            query = redshift_build_copy_cmd(
                table=table,
                bucket=bucket,
                key=key,
                iam_role=iam_role,
                options=options,
            )
            logger.info(query)

            if not dry_run:
                try:
                    if prepossess_step:
                        cur.execute(prepossess_step)
                    cur.execute(query)
                    conn.commit()
                    success.append(key)
                except Exception as e:
                    logger.error(
                        "Failed while dealing with key: {}/{} -> {}".format(
                            bucket, key, e
                        )
                    )
                    errors.append(key)
                    conn.rollback()
                    exc = e
        else:
            logger.warning("No table defined, nothing to do")

    results = {
        "success": success,
        "errors": errors,
        "exceptions": [exc],
    }
    return results


def load_to_redshift(
    event,
    db_host: str,
    db_port: str,
    db_name: str,
    db_user: str,
    db_param: str,
    iam_role: str,
    logger: Logger,
    dry_run: bool = False,
):
    """issues copy command in redshift for a given s3 key"""
    step_function_triggered = event.get("StepFunctionTriggered")
    records = event.get("Records")
    db_password = (
        get_ssm_parameter(db_param=db_param, with_decryption=True)
        if not dry_run
        else db_param
    )
    conn, cur = get_pg_client(
        user=db_user,
        host=db_host,
        port=int(db_port),
        db=db_name,
        pwd=db_password,
        auto_commit=False,
        ssl=False,
    )

    results = process_records(
        records=records,
        step_function_triggered=step_function_triggered,
        cur=cur,
        conn=conn,
        logger=logger,
        iam_role=iam_role,
        dry_run=dry_run,
    )
    if results.get("exceptions")[0]:
        errors = results.get("errors")
        logger.error(
            "S3 key [{}] failed to be imported into Redshift: {}".format(
                records, errors
            )
        )
        raise results.get("exceptions")[0]
    return results


def create_or_update_redshift(
    event,
    db_host: str,
    db_port: str,
    db_name: str,
    db_user: str,
    db_pw_param: str,
    iam_role: str,
    logger: Logger,
):
    records = event.get("Records")
    db_password = get_ssm_parameter(db_param=db_pw_param, with_decryption=True)
    conn, cur = get_pg_client(
        user=db_user,
        host=db_host,
        port=int(db_port),
        db=db_name,
        pwd=db_password,
        auto_commit=False,
        ssl=False,
    )

    for record in records:
        s3_data = record.get("s3", {})
        bucket = s3_data.get("bucket", {}).get("name")
        key = s3_data.get("object", {}).get("key")
        logger.info("Extracted the following path: {}/{}".format(bucket, key))

    # Case 1: If the UUID is not present in the table already, simply insert the data

    # Case 2: If the UUID exists->
    # Case 2.1: Some columns are empty in the row but incoming data has values for them along with updated values for some other columns.
    # Possible approach, identify non empty columns in the new data and update those columns in the table

    # Case 2.2: All columns are filled in the table, incoming data has updated values.
    # Possible approach: Same as above?
