import boto3
import time
import logging

WAIT_TIME_S = (
    10  # time in seconds to wait between checks whether crawler is still running
)


class CrawlerRunner:
    """
    Allows to synchronously run a glue crawler

    """

    def __init__(self, crawler_name: str, logger: logging.Logger = None):
        """
        Constructor

        :param crawler_name: Name of the crawler
        :param logger: Logger instance
        """
        self.client = boto3.client("glue")
        self.crawler_name = crawler_name
        self.logger = logger

    def _get_crawler(self) -> dict:
        """
        Query crawler information from AWS

        :return: dictionary with crawler information
        :except: EntityNotFoundException if crawler does not exist
        """
        crawler = self.client.get_crawler(Name=self.crawler_name)

        return crawler["Crawler"]

    def _get_state(self) -> str:
        """
        Get current crawler status
        :return: 'READY'|'RUNNING'|'STOPPING'
        """
        return self._get_crawler()["State"]

    def _get_last_crawl_state(self):
        """
        Get status of the last completed crawler run

        :return: 'SUCCEEDED' | 'CANCELLED' | 'FAILED' or None if crawler was never run
        """
        crawler = self._get_crawler()
        if "LastCrawl" not in crawler:
            return None

        return crawler["LastCrawl"]["Status"]

    def _start_crawler(self):
        """
        Asynchronously start a glue crawler

        :except: CrawlerRunningException if Crawler is already running
        :return: None
        """
        res = self.client.start_crawler(Name=self.crawler_name)

        assert (
            res["ResponseMetadata"]["HTTPStatusCode"] == 200
        ), "Crawler start not successful"

    def _crawler_running(self):
        """
        Check if crawler is running

        :return: True if crawler is in RUNNING or STOPPING state, False otherwise
        """
        return self._get_state() != "READY"

    def _crawler_ready(self):
        """
        Check if crawler is ready

        :return: True if crawler is in READY state
        """
        return self._get_state() == "READY"

    def run(self):
        """
        Start the crawler and wait for it to complete

        :return: None
        """
        self.logger.info(f'Starting crawler "{self.crawler_name}"')

        self._start_crawler()

        self.logger.info(f"Crawler started")

        sec_waited = 0

        while self._crawler_running():
            time.sleep(WAIT_TIME_S)
            sec_waited += WAIT_TIME_S
            self.logger.debug(f"Waiting for crawler finish ({sec_waited} s)")

        self.logger.info(
            f"Crawler finished with state ({self._get_last_crawl_state()})"
        )

        assert (
            self._get_last_crawl_state() == "SUCCEEDED"
        ), "Crawler did not finish successfully"
