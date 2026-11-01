import os
from datetime import date, datetime
from decimal import Decimal
from uuid import UUID
import logging

from dotenv import load_dotenv
from google.cloud import bigquery

load_dotenv()
logger = logging.getLogger(__name__)


def normalize_value(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()

    if isinstance(value, (Decimal, UUID)):
        return str(value)

    if isinstance(value, dict):
        return {key: normalize_value(v) for key, v in value.items()}

    if isinstance(value, (list, tuple)):
        return [normalize_value(v) for v in value]

    return value


def load_to_bigquery(client, table_name, batch, first_batch=False):
    try:
        table_id = (
            f"{os.environ['GCP_PROJECT_ID']}."
            f"{os.getenv('BQ_DATASET_ID', 'bronze')}."
            f"stg_{table_name}"
        )

        if not batch:
            logger.warning("Batch rỗng, bỏ qua %s", table_id)
            return

        data = [normalize_value(row) for row in batch]


        config = bigquery.LoadJobConfig(
            schema=client.get_table(table_id).schema,
            write_disposition=(
                bigquery.WriteDisposition.WRITE_TRUNCATE
                if first_batch
                else bigquery.WriteDisposition.WRITE_APPEND
            ),
        )

        logger.debug(
            "Bắt đầu load %s | rows=%s | mode=%s",
            table_id,
            len(data),
            config.write_disposition,
        )

        job = client.load_table_from_json(
            data,
            table_id,
            job_config=config,
            location=os.getenv("BQ_LOCATION", "US"),
        )
        job.result()

        logger.info(
            "Loaded %s dòng vào %s | job_id=%s",
            len(data),
            table_id,
            job.job_id,
        )

    except Exception as e:
        logger.error("Load bảng %s thất bại: %s", table_name, e)
        raise