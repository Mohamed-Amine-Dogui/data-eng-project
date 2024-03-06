"""
Convenience Test class inheriting from unittest.TestCase to help
assert cases that require a Spark Session to be created (and torn
down when finished.
"""

import logging
import os
import unittest
from pyspark.sql import SparkSession


class PySparkTest(unittest.TestCase):
    """
    Test cases can inheric from PySparkTest instead of unittest.TestCase and take
    advantage of the spark session created by this class by referencing `self.ss`.
    """

    ss: SparkSession = None

    @classmethod
    def setUpClass(cls) -> None:
        """
        Setup Spark testing object.
        """
        cls.suppress_py4j_logging()
        cls.ss = cls.create_testing_pyspark_session()
        cls.logger = logging.getLogger("spark")

    """
        Clean up the Class
        """

    @classmethod
    def tearDownClass(cls) -> None:
        cls.ss.stop()

    @classmethod
    def suppress_py4j_logging(cls) -> None:
        """
        Suppress spark logging
        """
        logger = logging.getLogger("py4j")
        logger.setLevel(logging.WARN)

    @classmethod
    def create_testing_pyspark_session(cls) -> SparkSession:
        """
        Returns SparkSession connecting to local context the extrajava
        session is to generate the metastore_db and derby.log into .tmp/ directory
        """
        tmp_dir = os.path.abspath(".tmp/")
        return (
            SparkSession.builder.master("local[1]")
            .appName("local-spark-tests_unit")
            .config("spark.driver.extraJavaOptions", "-Dderby.system.home=" + tmp_dir)
            .config("spark.sql.warehouse.dir", tmp_dir)
            .getOrCreate()
        )
