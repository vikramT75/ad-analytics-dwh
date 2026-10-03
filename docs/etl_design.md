# ETL Design Document

## Overview

This document describes the Extract, Transform, Load (ETL) pipeline that moves data from raw source files through three layers — Bronze, Silver, and Gold — to produce a business-ready analytical model.

---

## Architecture: Medallion Pattern

```
Source CSVs → [Bronze] → [Silver] → [Gold + Analytics]
                Raw       Cleansed    Star Schema
```

Each layer has a single stored procedure that is the authoritative entry point for loading that layer. Layers should always be loaded in order.

**Load sequence:**
```sql
EXEC bronze.load_bronze;   -- Step 1
EXEC silver.load_silver;   -- Step 2
EXEC gold.load_gold;       -- Step 3
-- Then create/refresh analytics views (DDL, no procedure needed)
```

---

## Layer 1: Bronze — Raw Ingestion

**Source:** CSV files in `datasets/source_dsp/`, `datasets/source_crm/`, `datasets/source_device/`  
**Target:** `bronze.*` tables  
**Script:** `scripts/bronze/proc_load_bronze.sql`

### Design Decisions

| Decision | Rationale |
|---|---|
| All columns stored as NVARCHAR | Preserve exactly what the source sent; typing happens in Silver |
| TRUNCATE + reload (full refresh) | Simplest idempotent pattern for batch ETL |
| BULK INSERT for performance | Orders of magnitude faster than row-by-row INSERT |
| No transformation | Bronze is a forensic record — untouched source data |

### Transformation Rules

None. Bronze is a pure copy of the source.

---

## Layer 2: Silver — Cleansing & Normalization

**Source:** `bronze.*` tables  
**Target:** `silver.*` tables  
**Script:** `scripts/silver/proc_load_silver.sql`

### Design Decisions

| Decision | Rationale |
|---|---|
| TRUNCATE + full reload | Consistent with Bronze; campaigns run daily |
| TRY_CAST for type conversion | Graceful handling of malformed values (NULL instead of error) |
| ROW_NUMBER() for deduplication | Standard window function approach; keeps latest record |
| INNER JOIN for referential integrity | Clicks without a valid impression are discarded (not propagated) |

### Transformation Rules by Table

#### `silver.dsp_impressions`

| Source Field | Transformation | Target Field |
|---|---|---|
| `event_ts` | `TRY_CAST(event_ts AS DATETIME2)` — NULL if unparseable | `event_ts` DATETIME2 |
| `bid_price` | `TRY_CAST` to DECIMAL; set NULL if ≤ 0 or > 100 | `bid_price` DECIMAL(10,4) |
| `geo_country` | Map 2-letter codes to full names; empty/NULL → 'Unknown' | `geo_country` NVARCHAR(100) |
| `imp_id` | `ROW_NUMBER() OVER (PARTITION BY imp_id ORDER BY event_ts DESC) = 1` | Deduplication |
| `device_id` | Pass-through; NULL rows retained | `device_id` |

**Geo normalization mapping:**

| Input | Output |
|---|---|
| `US`, `USA` | `United States` |
| `IN`, `IND` | `India` |
| `GB`, `GBR` | `United Kingdom` |
| `CA`, `CAN` | `Canada` |
| `AU`, `AUS` | `Australia` |
| `DE`, `DEU` | `Germany` |
| `''`, NULL | `Unknown` |
| anything else | `TRIM(geo_country)` |

#### `silver.dsp_clicks`

| Transformation | Detail |
|---|---|
| Type casting | `event_ts` → DATETIME2 via TRY_CAST |
| Referential integrity | Only load clicks where `imp_id` exists in `silver.dsp_impressions` |
| Effect | ~20 orphaned clicks (intentionally injected in dataset) are dropped |

#### `silver.crm_campaigns`

| Source Field | Transformation | Target Field |
|---|---|---|
| `budget_usd` | TRY_CAST to DECIMAL(12,2); NULL if ≤ 0 | `budget_usd` |
| `start_date` / `end_date` | TRY_CAST to DATE | DATE columns |
| `campaign_duration_days` | `DATEDIFF(DAY, start_date, end_date)` | Derived column |
| `objective` | AWA/AWARENESS → 'Awareness'; PERF/PERFORMANCE → 'Performance'; RET/RETARGETING → 'Retargeting'; else 'Other' | `objective` |
| `status` | A/ACTIVE → 'Active'; P/PAUSED → 'Paused'; C/COMPLETED → 'Completed'; D/DRAFT → 'Draft'; else 'Unknown' | `status` |

#### `silver.crm_advertisers`

| Transformation | Detail |
|---|---|
| `signup_date` | TRY_CAST to DATE |
| `account_status` | A/ACTIVE → 'Active'; S/SUSPENDED → 'Suspended'; P/PAUSED → 'Paused'; else 'Unknown' |

#### `silver.device_profiles`

| Field | Normalization |
|---|---|
| `os_type` | Case-insensitive: ios → 'iOS'; android → 'Android'; windows → 'Windows'; macos/mac os → 'macOS' |
| `device_type` | mob/mobile → 'Mobile'; tab/tablet → 'Tablet'; desk/desktop → 'Desktop'; ctv → 'CTV' |
| All fields | `TRIM()` applied |

#### `silver.device_app_installs`

| Transformation | Detail |
|---|---|
| `install_date` | TRY_CAST to DATETIME2; future dates are NOT dropped here (dropped at Gold via attribution window) |
| `app_name`, `app_category` | `TRIM()` applied |

---

## Layer 3: Gold — Star Schema

**Source:** `silver.*` tables  
**Target:** `gold.*` views + `gold.dim_date` and `gold.dim_campaigns` tables  
**Scripts:** `scripts/gold/ddl_gold.sql` and `scripts/gold/proc_load_gold.sql`

### Dimension Strategy

| Dimension | Type | Why |
|---|---|---|
| `dim_date` | Physical table | Generated once; used by all facts |
| `dim_campaigns` | Physical table (SCD Type-2) | Needs history tracking for budget/status changes |
| `dim_advertisers` | View | Stable; no history needed |
| `dim_devices` | View | Large; view avoids duplication |
| `dim_apps` | View | Derived aggregate; simplest as a view |

### SCD Type-2 Design for `dim_campaigns`

Slowly Changing Dimension Type-2 preserves full history of changes. When a campaign attribute changes (status, budget, name, target_geo), the old record is marked expired and a new current record is inserted.

**Tracked change columns:** `campaign_name`, `objective`, `budget_usd`, `status`, `target_geo`, `advertiser_name`

**MERGE logic (in `proc_load_gold.sql`):**

```
WHEN MATCHED AND any tracked column changed:
    → UPDATE: set dwh_expiry_date = today, dwh_is_current = 0

WHEN NOT MATCHED (new campaign):
    → INSERT with dwh_effective_date = today, dwh_expiry_date = '9999-12-31', dwh_is_current = 1
```

Then a second pass:
```
INSERT new row for changed campaigns (expired above but missing new current row)
```

**Important query pattern — always filter current:**
```sql
FROM gold.dim_campaigns WHERE dwh_is_current = 1
```

### Fact Table — Attribution Logic (`fact_conversions`)

The 7-day post-click attribution window is implemented using an INNER JOIN with a date range:

```sql
inst.install_date BETWEEN cl.event_ts AND DATEADD(DAY, 7, cl.event_ts)
```

To prevent fan-out (one install matching multiple clicks), a `ROW_NUMBER()` window function picks only the **earliest** qualifying click per install:

```sql
ROW_NUMBER() OVER (PARTITION BY inst.install_id ORDER BY cl.event_ts ASC) = 1
```

This ensures each conversion is attributed to exactly one click, following the **first-touch within the 7-day window** attribution model.

---

## Python Ingestion Alternative (`ingest/load_bronze.py`)

As an alternative to BULK INSERT, the Python script provides:
- Chunked loading (5,000 rows per batch) for memory efficiency
- Schema validation before insert
- Graceful per-table error handling (one table failure doesn't stop others)
- Detailed logging with timing

**Use cases for Python ingestion:**
- When BULK INSERT file path permissions are restricted
- When source data comes from an API (not a file)
- When pre-processing is needed before Bronze insertion

---

## Error Handling

All stored procedures use TRY/CATCH with PRINT statements:

```sql
BEGIN TRY
    -- load logic
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
    PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
END CATCH
```

All procedures also PRINT timing per table so slow loads can be identified.
