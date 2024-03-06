import logging
import bootstrap
from lambda_modules.crawler_runner import CrawlerRunner


def handler(event: dict, context: bootstrap.LambdaContext) -> None:
    """
    Lambda function for synchronously running a glue crawler job.

    :param event: dictionary with required key "crawler_name" that specifies the name of the crawler to rum
    :param context: Lambda context, unused
    :return: None
    """
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    logging.info("Lambda handler started")

    assert (
        type(event) == dict and "crawler_name" in event
    ), "Key `crawler_name` must be supplied to the lambda function"

    crawler_name = event["crawler_name"]

    logging.info(f"Crawler: {crawler_name}")

    cr = CrawlerRunner(crawler_name, logger)
    cr.run()

    logging.debug("Lambda handler end")
