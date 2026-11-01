import os
import logging
import psycopg
from dotenv import load_dotenv
from psycopg import sql
from psycopg.rows import dict_row

load_dotenv()
logger = logging.getLogger(__name__)


def extract_table(table_name, batch_size=None):
    try:
        batch_size = (
            int(os.getenv("BATCH_SIZE", "5000"))
            if batch_size is None
            else batch_size
        )

        if batch_size <= 0:
            raise ValueError("batch_size phải lớn hơn 0")

        with psycopg.connect(
            host=os.environ["PG_HOST"],
            port=os.getenv("PG_PORT", "5432"),
            dbname=os.environ["PG_DATABASE"],
            user=os.environ["PG_USER"],
            password=os.environ["PG_PASSWORD"],
            connect_timeout=15,
            row_factory=dict_row,
        ) as conn:
            query = sql.SQL("SELECT * FROM {}.{}").format(
                sql.Identifier(os.getenv("PG_SCHEMA", "public")),
                sql.Identifier(table_name),
            )

            with conn.cursor(name="extract_cursor") as cursor:
                cursor.execute(query)

                while batch := cursor.fetchmany(batch_size):
                    yield batch

    except KeyError as e:
        logger.error("Thiếu biến môi trường: %s", e)
        raise

    except ValueError as e:
        logger.error("Cấu hình không hợp lệ: %s", e)
        raise

    except psycopg.OperationalError as e:
        logger.error("Lỗi kết nối PostgreSQL: %s", e)
        raise

    except psycopg.Error as e:
        logger.error("Lỗi PostgreSQL khi đọc bảng %s: %s", table_name, e)
        raise

TABLE_NAMES = [
    "accounts",
    "branches",
    "cards",
    "channels",
    "currencies",
    "customers",
    "merchants",
    "products",
    "transaction_status_history",
    "transaction_types",
    "transactions", 
]


def extract_all_tables(table_names=None, batch_size=None):
    if table_names is None:
        table_names = TABLE_NAMES

    for table_name in table_names:
        logger.info("Bắt đầu extract bảng %s", table_name)
        total = 0

        for batch in extract_table(table_name, batch_size=batch_size):
            total += len(batch)
            logger.debug(
                "%s | batch=%s | tổng đã extract=%s",
                table_name,
                len(batch),
                total,
            )
            yield table_name, batch

        logger.info(
            "Hoàn thành extract bảng %s | tổng=%s dòng",
            table_name,
            total,
        )