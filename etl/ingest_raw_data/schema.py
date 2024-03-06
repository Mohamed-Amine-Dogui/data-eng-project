from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    TimestampType,
)

OUT_SCHEMA = StructType(
    [
        StructField("uuid", StringType()),
        StructField("signal_name", StringType()),
        StructField("signal_value", TimestampType()),
        StructField("timestamp", TimestampType(), False),
    ]
)
