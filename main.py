import argparse
import logging
import os
from pathlib import Path

from google.cloud import bigquery

from etl.extract import TABLE_NAMES, extract_all_tables
from etl.load import load_to_bigquery
from etl.logger import setup_logging

logger = logging.getLogger(__name__)


def positive_int(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("Phải lớn hơn 0")
    return number

def run_sql_file(client, filename, tables=None):
    path = Path(__file__).resolve().parent / "sql" / filename
    query = path.read_text(encoding="utf-8")

    replacements = {
        "{project_id}": os.environ["GCP_PROJECT_ID"],
        "{dataset_id}": os.getenv("BQ_DATASET_ID", "bronze_core_banking"),
        "{location}": os.getenv("BQ_LOCATION", "US"),
    }

    for placeholder, value in replacements.items():
        query = query.replace(placeholder, value)

    config = bigquery.QueryJobConfig()

    if tables is not None:
        config.query_parameters = [
            bigquery.ArrayQueryParameter("tables", "STRING", tables)
        ]

    logger.info("Đang chạy SQL: %s", filename)

    client.query(
        query,
        job_config=config,
        location=os.getenv("BQ_LOCATION", "US"),
    ).result()

    logger.info("Hoàn thành SQL: %s", filename)


def parse_args():
    parser = argparse.ArgumentParser(description="Load PostgreSQL data into BigQuery staging tables")
    parser.add_argument("--tables",nargs="+",choices=TABLE_NAMES,default=TABLE_NAMES,help="Các bảng cần extract; mặc định lấy tất cả",)
    parser.add_argument("--batch-size",type=positive_int,default=os.getenv("BATCH_SIZE", "5000"),)
    parser.add_argument("--log-level",type=str.upper,choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],default=os.getenv("LOG_LEVEL", "INFO").upper(),)
    
    return parser.parse_args()


def main():
    args = parse_args()
    setup_logging(args.log_level)

    try:
        with bigquery.Client(
            project=os.environ["GCP_PROJECT_ID"]
        ) as client:
            # 1. Chuẩn bị dataset và schema.
            run_sql_file(client, "00_create_dataset.sql")
            run_sql_file(client, "01_create_tables.sql")

            # 2. Xóa staging của các bảng được chọn.
            # Làm trước để bảng nguồn rỗng cũng không để lại staging cũ.
            for table_name in args.tables:
                table_id = (
                    f"{os.environ['GCP_PROJECT_ID']}."
                    f"{os.getenv('BQ_DATASET_ID', 'bronze_core_banking')}."
                    f"stg_{table_name}"
                )

                client.query(
                    f"TRUNCATE TABLE `{table_id}`",
                    location=os.getenv("BQ_LOCATION", "US"),
                ).result()

            # 3. Extract và append từng batch vào staging.
            totals = {name: 0 for name in args.tables}

            for table_name, batch in extract_all_tables(
                args.tables,
                batch_size=args.batch_size,
            ):
                load_to_bigquery(
                    client,
                    table_name,
                    batch,
                    first_batch=False,
                )

                totals[table_name] += len(batch)
                logger.info(
                    "%s | tổng đã load=%s",
                    table_name,
                    totals[table_name],
                )

            # 4. Chỉ merge sau khi mọi batch đã load thành công.
            run_sql_file(
                client,
                "02_merge_tables.sql",
                tables=args.tables,
            )

            logger.info("Pipeline hoàn thành | totals=%s", totals)

    except Exception:
        logger.exception("Pipeline thất bại")
        raise SystemExit(1)

if __name__ == "__main__":
    main()