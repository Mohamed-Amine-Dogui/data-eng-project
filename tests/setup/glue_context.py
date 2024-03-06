# mock implementation of aws glue for pytest
import logging
from pyspark.sql import DataFrame


class MockDynamicFrame:
    def toDF(self) -> DataFrame:
        pass


class MockGlueContext:
    def get_logger(self) -> logging.Logger:
        return logging.getLogger("AWS_GLUE_TEST")
