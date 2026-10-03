# Data Catalog — Gold Layer

## Overview

The Gold Layer is the business-ready analytical model. It implements a **Star Schema** with conformed dimensions and three fact tables targeting the ad-tech audience intelligence domain. All views and tables in the Gold layer are optimized for analytical queries and reporting dashboards.

---

## Dimension Tables

### 1. `gold.dim_date`

**Type:** Physical table (populated once via `EXEC gold.load_gold`)  
**Purpose:** Standard calendar dimension used to slice all fact tables by time period.

| Column | Data Type | Description |
|---|---|---|
| `date_key` | INT | Surrogate key in YYYYMMDD integer format (e.g., `20240115`) |
| `full_date` | DATE | The actual calendar date |
| `year` | INT | Calendar year (e.g., 2024) |
| `quarter` | INT | Quarter of the year (1–4) |
| `month` | INT | Month number (1–12) |
| `month_name` | NVARCHAR(20) | Full month name (e.g., 'January') |
| `week_of_year` | INT | ISO week number (1–53) |
| `day_of_week` | INT | Day of week (1=Sunday, 7=Saturday) |
| `day_name` | NVARCHAR(20) | Full day name (e.g., 'Monday') |
| `is_weekend` | BIT | 1 if Saturday or Sunday, else 0 |

---

### 2. `gold.dim_campaigns`

**Type:** Physical table with **SCD Type-2** (Slowly Changing Dimensions)  
**Purpose:** Tracks current and historical states of advertising campaigns. When a campaign's budget, status, or targeting changes, the old record is expired and a new current record is inserted — preserving full auditability.

| Column | Data Type | Description |
|---|---|---|
| `campaign_key` | INT (IDENTITY) | Surrogate key — auto-incremented, unique per version |
| `campaign_id` | NVARCHAR(50) | Natural key from the source CRM system |
| `campaign_name` | NVARCHAR(200) | Human-readable campaign name |
| `objective` | NVARCHAR(50) | Campaign goal: `Awareness`, `Performance`, `Retargeting`, `Other` |
| `budget_usd` | DECIMAL(12,2) | Total campaign budget in USD |
| `start_date` | DATE | Scheduled campaign start date |
| `end_date` | DATE | Scheduled campaign end date |
| `status` | NVARCHAR(20) | Current campaign status: `Active`, `Paused`, `Completed`, `Draft` |
| `target_geo` | NVARCHAR(200) | Comma-separated list of target countries |
| `advertiser_id` | NVARCHAR(50) | FK to the owning advertiser (denormalized for query convenience) |
| `advertiser_name` | NVARCHAR(200) | Denormalized advertiser company name |
| `advertiser_industry` | NVARCHAR(100) | Advertiser industry vertical |
| `advertiser_country` | NVARCHAR(50) | Advertiser home country |
| `dwh_effective_date` | DATE | Date this version became active in the warehouse |
| `dwh_expiry_date` | DATE | Date this version was superseded (`9999-12-31` = current) |
| `dwh_is_current` | BIT | `1` = current version, `0` = historical version |

> **SCD Type-2 Note:** Always filter `WHERE dwh_is_current = 1` to get the latest state of each campaign. Joining without this filter will cause fan-out in fact queries.

---

### 3. `gold.dim_advertisers`

**Type:** View (sourced from `silver.crm_advertisers`)  
**Purpose:** Provides advertiser account details.

| Column | Data Type | Description |
|---|---|---|
| `advertiser_key` | INT | Surrogate key (generated via `ROW_NUMBER`) |
| `advertiser_id` | NVARCHAR(50) | Natural key from the CRM system |
| `company_name` | NVARCHAR(200) | Legal company name of the advertiser |
| `industry` | NVARCHAR(100) | Industry vertical (e.g., `Technology`, `Retail`, `Finance`) |
| `country` | NVARCHAR(50) | Advertiser headquarters country |
| `account_status` | NVARCHAR(20) | Account state: `Active`, `Paused`, `Suspended` |
| `signup_date` | DATE | Date the advertiser signed up on the platform |

---

### 4. `gold.dim_devices`

**Type:** View (sourced from `silver.device_profiles`)  
**Purpose:** Device-level attributes from the Device Graph, enabling audience segmentation.

| Column | Data Type | Description |
|---|---|---|
| `device_key` | INT | Surrogate key (generated via `ROW_NUMBER`) |
| `device_id` | NVARCHAR(50) | Natural key — unique device identifier |
| `os_type` | NVARCHAR(50) | Operating system: `iOS`, `Android`, `Windows`, `macOS`, `Unknown` |
| `device_type` | NVARCHAR(50) | Form factor: `Mobile`, `Tablet`, `Desktop`, `CTV` |
| `device_category` | NVARCHAR(50) | Human-friendly label derived from `device_type` (e.g., `Connected TV`) |
| `country` | NVARCHAR(50) | Device's home country (standardized to full name) |
| `language` | NVARCHAR(20) | Primary device language (ISO 639-1 code, e.g., `en`, `hi`) |
| `age_band` | NVARCHAR(20) | Inferred age range of the device user: `18-24`, `25-34`, `35-44`, `45-54`, `55+` |

---

### 5. `gold.dim_apps`

**Type:** View (derived from `silver.device_app_installs`)  
**Purpose:** App catalog dimension showing each unique app across the device graph.

| Column | Data Type | Description |
|---|---|---|
| `app_key` | INT | Surrogate key (generated via `DENSE_RANK` on `app_id`) |
| `app_id` | NVARCHAR(50) | Natural key — unique app identifier |
| `app_name` | NVARCHAR(200) | App display name |
| `app_category` | NVARCHAR(100) | App store category: `Gaming`, `Social`, `Shopping`, `Finance`, `Health`, `News` |
| `install_count` | INT | Total number of device installs recorded in the data |

---

## Fact Tables

### 6. `gold.fact_impressions`

**Type:** View (sourced from `silver.dsp_impressions` + dimensions)  
**Grain:** One row per ad impression event  
**Purpose:** Core transaction fact table. Each row represents a single ad impression served to a device for a campaign.

| Column | Data Type | Description |
|---|---|---|
| `impression_id` | NVARCHAR(50) | Natural key from the DSP system (unique per impression) |
| `campaign_key` | INT | FK to `gold.dim_campaigns` (current version) |
| `device_key` | INT | FK to `gold.dim_devices` |
| `event_date_key` | INT | FK to `gold.dim_date` (YYYYMMDD format) |
| `event_ts` | DATETIME2 | Full timestamp of the impression event |
| `bid_price` | DECIMAL(10,4) | Winning bid price paid for this impression (in USD CPM) |
| `placement_type` | NVARCHAR(50) | Ad placement: `BANNER`, `VIDEO`, `NATIVE`, `INTERSTITIAL` |
| `ad_format` | NVARCHAR(50) | Creative format: `300x250`, `728x90`, `320x50`, `16:9`, `1x1` |
| `geo_country` | NVARCHAR(100) | Country where the impression was served (standardized name) |
| `geo_city` | NVARCHAR(100) | City where the impression was served |
| `is_clicked` | BIT | `1` if this impression was followed by a click, else `0` |

---

### 7. `gold.fact_clicks`

**Type:** View (sourced from `silver.dsp_clicks` + dimensions)  
**Grain:** One row per click event  
**Purpose:** Click event fact table. Links clicks back to the originating impression and campaign.

| Column | Data Type | Description |
|---|---|---|
| `click_id` | NVARCHAR(50) | Natural key — unique click identifier |
| `impression_id` | NVARCHAR(50) | FK to `gold.fact_impressions` (natural key linkage) |
| `campaign_key` | INT | FK to `gold.dim_campaigns` (current version) |
| `device_key` | INT | FK to `gold.dim_devices` |
| `click_date_key` | INT | FK to `gold.dim_date` (YYYYMMDD format) |
| `click_ts` | DATETIME2 | Full timestamp of the click event |

---

### 8. `gold.fact_conversions`

**Type:** View (sourced from `silver.device_app_installs` + `silver.dsp_clicks` + dimensions)  
**Grain:** One row per attributed app install (conversion event)  
**Purpose:** Conversion fact table using **7-day post-click attribution**. An app install is attributed to the earliest click on the same device within the 7-day window preceding the install.

| Column | Data Type | Description |
|---|---|---|
| `install_id` | NVARCHAR(50) | Natural key — unique app install event ID |
| `click_id` | NVARCHAR(50) | The attributed click ID (earliest click within 7-day window) |
| `campaign_key` | INT | FK to `gold.dim_campaigns` (via attributed click's campaign) |
| `device_key` | INT | FK to `gold.dim_devices` |
| `app_key` | INT | FK to `gold.dim_apps` |
| `conversion_date_key` | INT | FK to `gold.dim_date` (date of the install event) |
| `hours_to_convert` | INT | Hours elapsed between the attributed click and the install |

> **Attribution Note:** Only the earliest matching click within the 7-day window is used (to avoid double-counting). Installs with no matching click within 7 days are not included in this fact table (unattributed installs).

---

## Analytics Layer

### `analytics.report_campaign_performance`
Aggregated campaign KPIs: impressions, clicks, conversions, CTR, CVR, spend, budget utilization, effective CPM, CPC, CPA, and campaign rankings.

### `analytics.report_audience_segments`
Impression and conversion performance broken down by device type, OS, age band, and geography. Includes segment-level CTR ranking.

### `analytics.report_funnel_metrics`
Weekly cohort analysis of the impression → click → conversion funnel per campaign. Includes 4-week rolling CTR, attribution window breakdowns (1-day vs 3-day vs 7-day), and cumulative impression totals.

### `analytics.report_device_reach`
Unique device reach, average impression frequency, frequency distribution buckets, and engagement rate per campaign and geo segment.
