import csv
import logging
import time
from pathlib import Path
from typing import List, Dict, Tuple
import pyodbc

# Config
try:
    import config
except ImportError:
    logging.error(
        "Configuration module not found. Make sure config.py is in the same directory."
    )
    raise

# Logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

CHUNK_SIZE = 5000

# Table mappings

TABLE_MAPPINGS = [
    (
        "bronze.dsp_impressions",
        "source_dsp/impressions.csv",
        [
            "imp_id",
            "device_id",
            "campaign_id",
            "event_ts",
            "bid_price",
            "geo_country",
            "geo_city",
            "placement_type",
            "ad_format",
        ],
    ),
    (
        "bronze.dsp_clicks",
        "source_dsp/clicks.csv",
        ["click_id", "imp_id", "device_id", "campaign_id", "event_ts"],
    ),
    (
        "bronze.crm_campaigns",
        "source_crm/campaigns.csv",
        [
            "campaign_id",
            "advertiser_id",
            "campaign_name",
            "objective",
            "budget_usd",
            "start_date",
            "end_date",
            "status",
            "target_geo",
        ],
    ),
    (
        "bronze.crm_advertisers",
        "source_crm/advertisers.csv",
        [
            "advertiser_id",
            "company_name",
            "industry",
            "country",
            "account_status",
            "signup_date",
        ],
    ),
    (
        "bronze.device_profiles",
        "source_device/device_profiles.csv",
        ["device_id", "os_type", "device_type", "country", "language", "age_band"],
    ),
    (
        "bronze.device_app_installs",
        "source_device/app_installs.csv",
        [
            "install_id",
            "device_id",
            "app_id",
            "app_name",
            "app_category",
            "install_date",
        ],
    ),
]


def load_data_to_table(
    cursor: pyodbc.Cursor, table_name: str, csv_file_path: Path, columns: List[str]
) -> None:
    logger.info(f"Processing table {table_name} from {csv_file_path}...")

    if not csv_file_path.exists():
        logger.error(f"CSV file not found: {csv_file_path}. Skipping.")
        return

    start_time = time.time()

    # Truncate
    logger.info(f"Truncating table {table_name}...")
    cursor.execute(f"TRUNCATE TABLE {table_name}")

    # Read & Insert
    with open(csv_file_path, mode="r", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)

        # Validation
        if len(header) != len(columns):
            logger.error(
                f"Schema mismatch for {table_name}. Expected {len(columns)} cols, got {len(header)} cols."
            )
            return

        placeholders = ",".join(["?" for _ in columns])
        columns_str = ",".join(columns)
        insert_query = (
            f"INSERT INTO {table_name} ({columns_str}) VALUES ({placeholders})"
        )

        chunk = []
        rows_inserted = 0

        for row in reader:
            chunk.append(tuple(row))
            if len(chunk) >= CHUNK_SIZE:
                cursor.executemany(insert_query, chunk)
                rows_inserted += len(chunk)
                chunk = []

        # Insert remainder
        if chunk:
            cursor.executemany(insert_query, chunk)
            rows_inserted += len(chunk)

    elapsed = time.time() - start_time
    logger.info(
        f"Successfully loaded {rows_inserted} rows into {table_name} in {elapsed:.2f} seconds."
    )


def main():
    logger.info("Starting Bronze layer ingestion...")
    total_start = time.time()

    base_dir = Path(config.DATA_DIR)

    try:
        conn = pyodbc.connect(config.CONNECTION_STRING, autocommit=True)
        cursor = conn.cursor()

        for table_name, rel_path, columns in TABLE_MAPPINGS:
            csv_path = base_dir / rel_path
            try:
                load_data_to_table(cursor, table_name, csv_path, columns)
            except Exception as e:
                logger.error(f"Failed to load table {table_name}. Error: {e}")
                # Continue with other tables
                continue

    except Exception as e:
        logger.error(f"Database connection or fatal error: {e}")
    finally:
        if "conn" in locals():
            conn.close()
            logger.info("Database connection closed.")

    total_elapsed = time.time() - total_start
    logger.info(f"Bronze layer ingestion completed in {total_elapsed:.2f} seconds.")


if __name__ == "__main__":
    main()
