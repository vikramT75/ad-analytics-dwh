# Ad Intelligence Data Warehouse

A production-grade data warehousing project built around an **ad-tech audience intelligence** platform. This warehouse consolidates data from three source systems — a Demand-Side Platform (DSP), an Advertiser CRM, and a Device Graph — to power campaign analytics, audience segmentation, and conversion attribution at scale.

Built as a portfolio project to demonstrate end-to-end data engineering and analytical SQL skills.

---

## Architecture

The warehouse follows **Medallion Architecture** — a proven pattern for building reliable, scalable data lakes and warehouses:

```
┌─────────────────────────────────────────────────────────────────┐
│  SOURCE SYSTEMS                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │  DSP Events  │  │ Advertiser   │  │   Device Graph     │    │
│  │  (Impressions│  │    CRM       │  │  (Profiles +       │    │
│  │   & Clicks)  │  │ (Campaigns + │  │   App Installs)    │    │
│  │              │  │  Advertisers)│  │                    │    │
│  └──────┬───────┘  └──────┬───────┘  └─────────┬──────────┘    │
└─────────┼─────────────────┼────────────────────┼───────────────┘
          │                 │                    │
          ▼                 ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│  🥉 BRONZE LAYER  (Raw Ingestion)                                 │
│  dsp_impressions | dsp_clicks | crm_campaigns |                  │
│  crm_advertisers | device_profiles | device_app_installs         │
└─────────────────────────────┬───────────────────────────────────┘
                              │  TRUNCATE + BULK INSERT
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  🥈 SILVER LAYER  (Cleansed & Typed)                              │
│  • Deduplication (ROW_NUMBER window functions)                   │
│  • Type casting (TRY_CAST — graceful null on bad data)           │
│  • Value normalization (geo codes, status codes)                 │
│  • Referential integrity (orphaned clicks discarded)             │
│  • Derived columns (campaign_duration_days)                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │  MERGE (SCD-2) + Views
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  🥇 GOLD LAYER  (Star Schema)                                     │
│                                                                   │
│  DIMENSIONS              FACTS                                    │
│  dim_date (table)        fact_impressions (view)                  │
│  dim_campaigns (SCD-2)   fact_clicks (view)                      │
│  dim_advertisers (view)  fact_conversions (7-day attribution)    │
│  dim_devices (view)                                               │
│  dim_apps (view)                                                  │
└─────────────────────────────┬───────────────────────────────────┘
                              │  Analytical Views
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  📊 ANALYTICS LAYER  (Report Views)                               │
│  report_campaign_performance | report_audience_segments          │
│  report_funnel_metrics | report_device_reach                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Technical Highlights

### Slowly Changing Dimensions (SCD Type-2)
`gold.dim_campaigns` tracks full history of campaign changes. When a campaign's budget, status, or targeting changes, the old record is expired and a new current row is inserted — preserving auditability without losing history. Implemented via a T-SQL `MERGE` statement in `proc_load_gold.sql`.

### 7-Day Post-Click Attribution
`gold.fact_conversions` attributes app install conversions to ad clicks using a 7-day lookback window. A `ROW_NUMBER()` partition ensures each conversion is attributed to exactly **one** click (first-touch model), preventing fan-out in aggregations.

### Window Function Analytics
The analytics layer uses advanced SQL window functions throughout:
- `RANK()` for campaign leaderboards
- `SUM() OVER (... ROWS UNBOUNDED PRECEDING)` for cumulative impressions
- `AVG() OVER (... ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)` for 4-week rolling CTR
- `ROW_NUMBER() OVER (PARTITION BY ...)` for funnel cohort tracking

### Python Ingestion Pipeline
`ingest/load_bronze.py` provides a chunked, idempotent Python loader using `pyodbc`. Supports 5,000-row batches, per-table error isolation, schema validation, and timing logs — demonstrating scalable ingestion design beyond simple BULK INSERT.

### Synthetic Dataset with Injected Data Quality Issues
`ingest/generate_datasets.py` generates ~90,000 rows of realistic ad-tech data with **intentionally injected anomalies** that the Silver ETL must handle:
- ~100 duplicate impression IDs
- ~20 clicks referencing non-existent impressions
- 2-letter country codes that need geo normalization
- Abbreviated status codes (`A`, `P`, `C`) mixed with full words
- Negative and outlier bid prices
- Future-dated app installs

---

## Project Structure

```
sql-proj/
│
├── datasets/                          # Source CSV files
│   ├── source_dsp/
│   │   ├── impressions.csv            # ~50,000 ad impressions
│   │   └── clicks.csv                 # ~1,000 clicks (~2% CTR)
│   ├── source_crm/
│   │   ├── campaigns.csv              # 200 ad campaigns
│   │   └── advertisers.csv            # 50 advertiser accounts
│   └── source_device/
│       ├── device_profiles.csv        # 10,000 device records
│       └── app_installs.csv           # 30,000 app install events
│
├── docs/
│   ├── data_catalog.md                # Column-level catalog for Gold layer
│   ├── naming_conventions.md          # Naming rules for all objects
│   └── etl_design.md                  # ETL transformation rules documentation
│
├── scripts/
│   ├── init_database.sql              # DB + schema setup (run first)
│   ├── bronze/
│   │   ├── ddl_bronze.sql             # Bronze table definitions
│   │   └── proc_load_bronze.sql       # Load procedure (BULK INSERT)
│   ├── silver/
│   │   ├── ddl_silver.sql             # Silver table definitions
│   │   └── proc_load_silver.sql       # ETL: cleanse + normalize
│   ├── gold/
│   │   ├── ddl_gold.sql               # Gold views + table DDL
│   │   └── proc_load_gold.sql         # dim_date population + SCD-2 MERGE
│   └── analytics/
│       ├── report_campaign_performance.sql
│       ├── report_audience_segments.sql
│       ├── report_funnel_metrics.sql
│       └── report_device_reach.sql
│
├── ingest/
│   ├── generate_datasets.py           # Synthetic data generator
│   ├── load_bronze.py                 # Python Bronze loader (pyodbc)
│   ├── config.py                      # DB connection config
│   └── requirements.txt
│
├── tests/
│   ├── quality_checks_bronze.sql      # Post-ingest validation
│   ├── quality_checks_silver.sql      # Post-ETL validation
│   └── quality_checks_gold.sql        # Star schema integrity checks
│
└── README.md
```

---

## Quick Start

### Prerequisites
- SQL Server Express (or any SQL Server edition)
- SQL Server Management Studio (SSMS)
- Python 3.9+ with pip
- ODBC Driver 17 for SQL Server

### Step 1 — Generate Datasets

```bash
cd ingest
pip install -r requirements.txt
python generate_datasets.py
```

This creates all CSV files in `datasets/`.

### Step 2 — Set Up the Database

Run in SSMS:
```sql
-- Creates DataWarehouse database + 4 schemas
-- WARNING: drops DataWarehouse if it already exists
scripts/init_database.sql
```

### Step 3 — Create Tables and Load Bronze

```sql
scripts/bronze/ddl_bronze.sql
scripts/bronze/proc_load_bronze.sql
EXEC bronze.load_bronze;
```

Or use Python ingestion instead:
```bash
# Update ingest/config.py with your SQL Server instance name first
python ingest/load_bronze.py
```

### Step 4 — Create and Load Silver

```sql
scripts/silver/ddl_silver.sql
scripts/silver/proc_load_silver.sql
EXEC silver.load_silver;
```

### Step 5 — Create Gold Layer

```sql
scripts/gold/ddl_gold.sql
scripts/gold/proc_load_gold.sql
EXEC gold.load_gold;
```

### Step 6 — Create Analytics Views

```sql
scripts/analytics/report_campaign_performance.sql
scripts/analytics/report_audience_segments.sql
scripts/analytics/report_funnel_metrics.sql
scripts/analytics/report_device_reach.sql
```

### Step 7 — Run Quality Checks

```sql
tests/quality_checks_bronze.sql
tests/quality_checks_silver.sql
tests/quality_checks_gold.sql
```

### Step 8 — Query the Warehouse

```sql
-- Campaign KPIs
SELECT TOP 10 campaign_name, total_impressions, ctr_pct, total_conversions, budget_utilization_pct
FROM analytics.report_campaign_performance
ORDER BY total_impressions DESC;

-- Best-performing audience segments
SELECT device_category, os_type, age_band, total_impressions, ctr_pct
FROM analytics.report_audience_segments
ORDER BY ctr_pct DESC;

-- Weekly funnel for a specific campaign
SELECT event_week, impressions, clicks, conversions, ctr_pct, cvr_pct
FROM analytics.report_funnel_metrics
WHERE campaign_id = 'CMP-00001'
ORDER BY event_year, event_week;
```

---

## Data Model

### Star Schema Overview

```
                        ┌───────────────┐
                        │  dim_date     │
                        │  (date_key)   │
                        └───────┬───────┘
                                │
    ┌───────────────┐    ┌──────┴──────────┐    ┌───────────────┐
    │ dim_campaigns │    │ fact_impressions │    │  dim_devices  │
    │ (SCD Type-2)  │◄───│                 │───►│               │
    └───────────────┘    │  impression_id  │    └───────────────┘
                         │  campaign_key   │
                         │  device_key     │
                         │  event_date_key │
    ┌───────────────┐    │  bid_price      │
    │ dim_campaigns │    │  is_clicked     │
    │               │◄───┤                 │
    └───────────────┘    └────────┬────────┘
                                  │ (1:1 via imp_id)
                         ┌────────┴────────┐
                         │  fact_clicks    │
                         └────────┬────────┘
                                  │ (7-day window)
    ┌───────────────┐    ┌────────┴────────┐    ┌───────────────┐
    │ dim_apps      │◄───│ fact_conversions│───►│  dim_devices  │
    └───────────────┘    └─────────────────┘    └───────────────┘
```

---

## Skills Demonstrated

| Skill | Where |
|---|---|
| **Medallion Architecture** | 3-layer Bronze/Silver/Gold pipeline |
| **Star Schema Design** | 5 dimensions + 3 fact tables |
| **SCD Type-2** | `dim_campaigns` with full version history |
| **Advanced T-SQL** | Window functions, CTEs, MERGE, TRY_CAST |
| **ETL Design** | Deduplication, type casting, normalization, ref. integrity |
| **Attribution Logic** | 7-day post-click conversion window with first-touch model |
| **Data Quality** | 10+ assertions across all 3 layers |
| **Python / Cross-language** | Data generation + chunked pyodbc ingestion |
| **Analytical SQL** | Rolling averages, cohort analysis, funnel metrics |
| **Documentation** | Data catalog, ETL design doc, naming conventions |

---

## Tools & Technologies

| Category | Tools |
|---|---|
| Database | SQL Server Express |
| Query Interface | SQL Server Management Studio (SSMS) |
| Scripting | T-SQL (stored procedures, views, MERGE) |
| Python | Python 3.9+, pyodbc, faker |
| Version Control | Git |
