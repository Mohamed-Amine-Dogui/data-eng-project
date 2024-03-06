import tempfile
import os
from base64 import b64encode
import ssl
import http.client
import json
import re


def send_to_endpoint(
    ms_host, ms_url, certificate, pem_file, secret, json_records, user, password
):

    # create temporary files for certificate and key
    cert_tmp, cert_path = tempfile.mkstemp()
    with os.fdopen(cert_tmp, "w") as tmp:
        tmp.write(certificate)

    key_tmp, key_path = tempfile.mkstemp()
    with os.fdopen(key_tmp, "w") as tmp:
        tmp.write(pem_file)

    # Defining certificate related things and host of endpoint
    certificate_file = cert_path
    key_file = key_path
    certificate_secret = secret
    host = ms_host

    # Defining parts of the HTTP request
    request_url = ms_url
    user_and_pass_decoded = b64encode(bytes(user + ":" + password, "utf-8")).decode(
        "ascii"
    )
    request_headers = {
        "Content-Type": "application/json",
        "Authorization": "Basic %s" % user_and_pass_decoded,
        "Accept": "*/*",
    }

    # Define the client certificate settings for https connection
    context = ssl.SSLContext(ssl.PROTOCOL_SSLv23)
    context.load_cert_chain(
        certificate_file, keyfile=key_file, password=certificate_secret
    )

    # Create a connection to submit HTTP requests
    connection = http.client.HTTPSConnection(host, port=443, context=context)
    connection.set_debuglevel(3)
    # Use connection to submit a HTTP POST request
    connection.request(
        method="POST",
        url=request_url,
        headers=request_headers,
        body=json.dumps(json_records),
    )

    # Print the HTTP response from the Mulesoft service endpoint
    response = connection.getresponse()
    # data = json.loads(response.read().decode("utf-8"))

    return response


def error_logging(response, logger, records) -> None:
    res = json.loads(response.read().decode("utf-8"))
    errors_str = (
        res["error"]["errorDescription"].replace("Description:", "").split("\n")
    )
    error_details = {}
    logger.info(errors_str)
    for error in errors_str:

        record_num = re.search("/(.+)/", error).group(1)
        error = error.replace(record_num, "")
        error_details[int(record_num)] = error
    logger.error(f"{response.status} : {error_details}")

    rejected_records = []
    for key, value in error_details.items():
        rejected_records.append(records[key])
    logger.error(f"Records with error: {rejected_records}")


def json_to_db_values(json_records) -> str:
    """Converts a json object into a string which can be used in SQL insert statement
    Eg: {"id": 1, name:"xyz", price:10} -> (1, "xyz", 10)
    """
    reprocess_records = ""
    for rec in json_records:

        reprocess_records += str(tuple(rec.values()))
        reprocess_records += ","
    reprocess_records = reprocess_records[:-1]
    return reprocess_records
