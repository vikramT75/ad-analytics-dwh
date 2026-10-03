# Naming Conventions

This document defines naming rules for all objects in the data warehouse — schemas, tables, views, columns, stored procedures, and files. Consistency enables readability, tooling support, and easier onboarding.

---

## General Principles

| Principle | Rule |
|---|---|
| Case style | `snake_case` — all lowercase with underscores |
| Language | English only |
| Reserved words | Never use SQL reserved words as identifiers |
| Abbreviations | Use widely-understood abbreviations only (e.g., `id`, `ts`, `dt`) |
| Avoid | Spaces, hyphens, special characters, leading underscores in business names |

---

## Schema Naming

| Schema | Purpose |
|---|---|
| `bronze` | Raw ingestion — exact mirror of source systems |
| `silver` | Cleansed, typed, normalized data |
| `gold` | Business-ready star schema (dimensions + facts) |
| `analytics` | Pre-aggregated report views for dashboards and BI tools |

---

## Table & View Naming

### Bronze (`bronze.*`)

Tables mirror their source system and entity exactly:

**Pattern:** `<source_system>_<entity_name>`

| Example | Meaning |
|---|---|
| `bronze.dsp_impressions` | Impression events from the DSP system |
| `bronze.crm_campaigns` | Campaign records from the CRM system |
| `bronze.device_profiles` | Device attributes from the Device Graph |

### Silver (`silver.*`)

Tables maintain the same name as Bronze — they are the cleansed version:

**Pattern:** `<source_system>_<entity_name>` (same as Bronze)

### Gold (`gold.*`)

Tables and views use business-aligned names with category prefixes:

**Pattern:** `<category>_<entity>`

| Category | Meaning | Example |
|---|---|---|
| `dim_` | Dimension table | `gold.dim_campaigns`, `gold.dim_devices` |
| `fact_` | Fact table | `gold.fact_impressions`, `gold.fact_clicks` |

### Analytics (`analytics.*`)

Report views always begin with `report_`:

**Pattern:** `report_<subject>`

| Example | Meaning |
|---|---|
| `analytics.report_campaign_performance` | Campaign-level KPI aggregation |
| `analytics.report_audience_segments` | Reach and CTR by device/OS/geo segment |

---

## Column Naming

### Surrogate Keys

All dimension table primary keys use the suffix `_key`:

| Example | Table | Role |
|---|---|---|
| `campaign_key` | `gold.dim_campaigns` | Surrogate PK |
| `device_key` | `gold.dim_devices` | Surrogate PK |
| `date_key` | `gold.dim_date` | Surrogate PK (YYYYMMDD integer) |

Fact table foreign key references use the same suffix: `campaign_key`, `device_key`, `event_date_key`.

### Natural Keys

Source system identifiers use the suffix `_id`:

| Example | Meaning |
|---|---|
| `campaign_id` | Natural key from the CRM source |
| `device_id` | Natural key from the Device Graph |
| `imp_id` | Impression ID from the DSP |

### Timestamps

| Suffix | Meaning | Example |
|---|---|---|
| `_ts` | Full datetime (DATETIME2) | `event_ts`, `click_ts` |
| `_date` | Date only (DATE) | `start_date`, `signup_date` |
| `_date_key` | FK to dim_date | `event_date_key`, `click_date_key` |

### DWH Technical Columns

All warehouse-generated metadata columns use the `dwh_` prefix:

| Column | Meaning |
|---|---|
| `dwh_load_date` | When the record was loaded into Bronze |
| `dwh_create_date` | When the record was inserted into Silver |
| `dwh_effective_date` | SCD Type-2: when this version became active |
| `dwh_expiry_date` | SCD Type-2: when this version expired (`9999-12-31` = current) |
| `dwh_is_current` | SCD Type-2: `1` = current, `0` = historical |

### Derived / Calculated Columns

Calculated columns use descriptive names with units where needed:

| Example | Meaning |
|---|---|
| `campaign_duration_days` | Difference in days between start and end |
| `hours_to_convert` | Hours between click and conversion |
| `budget_utilization_pct` | Spend / budget × 100 |
| `is_clicked` | BIT flag — 1 if impression was clicked |
| `is_weekend` | BIT flag — 1 if date falls on Sat/Sun |

---

## Stored Procedure Naming

**Pattern:** `<schema>.load_<layer>`

| Procedure | Purpose |
|---|---|
| `bronze.load_bronze` | Loads raw CSV data into Bronze tables |
| `silver.load_silver` | Transforms Bronze → Silver (ETL) |
| `gold.load_gold` | Populates `dim_date` and runs SCD Type-2 MERGE for `dim_campaigns` |

---

## File Naming

| Type | Pattern | Example |
|---|---|---|
| DDL scripts | `ddl_<layer>.sql` | `ddl_bronze.sql` |
| Procedure scripts | `proc_load_<layer>.sql` | `proc_load_silver.sql` |
| Test scripts | `quality_checks_<layer>.sql` | `quality_checks_gold.sql` |
| Analytics views | `report_<subject>.sql` | `report_campaign_performance.sql` |
| Python scripts | `<verb>_<noun>.py` | `generate_datasets.py`, `load_bronze.py` |
| Dataset files | `<entity>.csv` | `impressions.csv`, `campaigns.csv` |
