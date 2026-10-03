PRINT '================================================================';
PRINT 'GOLD LAYER QUALITY CHECKS';
PRINT '================================================================';


-- ====================================================================
-- 1. SURROGATE KEY UNIQUENESS IN DIMENSION TABLES
-- Expectation: NO ROWS returned (all keys must be unique)
-- ====================================================================
PRINT '>> Check 1a: Duplicate device_key in gold.dim_devices (expect: 0 rows)';

SELECT
    device_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_devices
GROUP BY device_key
HAVING COUNT(*) > 1;

PRINT '>> Check 1b: Duplicate advertiser_key in gold.dim_advertisers (expect: 0 rows)';

SELECT
    advertiser_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_advertisers
GROUP BY advertiser_key
HAVING COUNT(*) > 1;

PRINT '>> Check 1c: Duplicate app_key in gold.dim_apps (expect: 0 rows)';

SELECT
    app_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_apps
GROUP BY app_key
HAVING COUNT(*) > 1;

PRINT '>> Check 1d: Duplicate date_key in gold.dim_date (expect: 0 rows)';

SELECT
    date_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_date
GROUP BY date_key
HAVING COUNT(*) > 1;


-- ====================================================================
-- 2. SCD TYPE-2 INTEGRITY FOR dim_campaigns
-- Expectation: Each campaign_id has exactly ONE current row (dwh_is_current=1)
-- ====================================================================
PRINT '>> Check 2: Multiple current rows per campaign in gold.dim_campaigns (expect: 0 rows)';

SELECT
    campaign_id,
    COUNT(*) AS current_row_count
FROM gold.dim_campaigns
WHERE dwh_is_current = 1
GROUP BY campaign_id
HAVING COUNT(*) > 1;

PRINT '>> Check 2b: Historical rows have valid expiry dates (expect: 0 rows)';

SELECT
    campaign_key,
    campaign_id,
    dwh_effective_date,
    dwh_expiry_date,
    dwh_is_current
FROM gold.dim_campaigns
WHERE dwh_is_current = 0
  AND (dwh_expiry_date IS NULL OR dwh_expiry_date = '9999-12-31');

PRINT '>> Check 2c: Current rows should have expiry = 9999-12-31 (expect: 0 rows)';

SELECT
    campaign_key,
    campaign_id,
    dwh_expiry_date
FROM gold.dim_campaigns
WHERE dwh_is_current = 1
  AND dwh_expiry_date != '9999-12-31';


-- ====================================================================
-- 3. REFERENTIAL INTEGRITY: FACT TABLES LINKED TO DIMENSIONS
-- Expectation: NO ROWS returned (no orphaned fact records)
-- ====================================================================
PRINT '>> Check 3a: Orphaned impressions (no matching campaign) (expect: 0 rows)';

SELECT COUNT(*) AS orphaned_impression_count
FROM gold.fact_impressions fi
WHERE fi.campaign_key IS NULL;

PRINT '>> Check 3b: Orphaned impressions (no matching device) (expect: 0 rows)';

SELECT COUNT(*) AS orphaned_impression_count
FROM gold.fact_impressions fi
WHERE fi.device_key IS NULL;

PRINT '>> Check 3c: Impressions with no matching dim_date row (expect: 0 rows)';

SELECT
    fi.impression_id,
    fi.event_date_key
FROM gold.fact_impressions fi
WHERE fi.event_date_key IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM gold.dim_date dd WHERE dd.date_key = fi.event_date_key
);

PRINT '>> Check 3d: Orphaned conversions (no matching campaign) (expect: 0 rows)';

SELECT COUNT(*) AS orphaned_conversion_count
FROM gold.fact_conversions fconv
WHERE fconv.campaign_key IS NULL;


-- ====================================================================
-- 4. BUSINESS METRIC REASONABLENESS
-- Expectation: CTR between 0% and 100%, CVR between 0% and 100%
-- ====================================================================
PRINT '>> Check 4: Campaign CTR out of valid range (expect: 0 rows)';

SELECT
    campaign_id,
    campaign_name,
    total_impressions,
    total_clicks,
    ctr_pct
FROM analytics.report_campaign_performance
WHERE ctr_pct < 0
   OR ctr_pct > 100;

PRINT '>> Check 4b: Campaign CVR out of valid range (expect: 0 rows)';

SELECT
    campaign_id,
    campaign_name,
    total_clicks,
    total_conversions,
    cvr_pct
FROM analytics.report_campaign_performance
WHERE cvr_pct < 0
   OR cvr_pct > 100;

PRINT '>> Check 4c: Campaigns where conversions exceed clicks (expect: 0 rows)';

SELECT
    campaign_id,
    campaign_name,
    total_clicks,
    total_conversions
FROM analytics.report_campaign_performance
WHERE total_conversions > total_clicks;


-- ====================================================================
-- 5. CONVERSION ATTRIBUTION SANITY CHECK
-- Expectation: All conversions have hours_to_convert between 0 and 168 (7 days)
-- ====================================================================
PRINT '>> Check 5: Conversions outside 7-day attribution window (expect: 0 rows)';

SELECT
    install_id,
    click_id,
    hours_to_convert
FROM gold.fact_conversions
WHERE hours_to_convert < 0
   OR hours_to_convert > 168;


-- ====================================================================
-- 6. DIM_DATE COMPLETENESS
-- Expectation: All dates referenced in facts exist in dim_date
-- ====================================================================
PRINT '>> Check 6: dim_date coverage vs fact dates (informational)';

SELECT
    MIN(dd.full_date) AS dim_date_min,
    MAX(dd.full_date) AS dim_date_max,
    COUNT(*)          AS total_date_rows
FROM gold.dim_date dd;

SELECT
    MIN(CAST(fi.event_ts AS DATE)) AS fact_min_date,
    MAX(CAST(fi.event_ts AS DATE)) AS fact_max_date,
    COUNT(DISTINCT CAST(fi.event_ts AS DATE)) AS distinct_event_dates
FROM silver.dsp_impressions fi;


-- ====================================================================
-- 7. GOLD LAYER SUMMARY (informational)
-- Provides an overview of record counts across the star schema
-- ====================================================================
PRINT '>> Check 7: Gold Layer Record Counts (informational)';

SELECT 'gold.dim_campaigns (current)'     AS object_name, COUNT(*) AS row_count FROM gold.dim_campaigns WHERE dwh_is_current = 1
UNION ALL
SELECT 'gold.dim_campaigns (historical)', COUNT(*) FROM gold.dim_campaigns WHERE dwh_is_current = 0
UNION ALL
SELECT 'gold.dim_advertisers',            COUNT(*) FROM gold.dim_advertisers
UNION ALL
SELECT 'gold.dim_devices',                COUNT(*) FROM gold.dim_devices
UNION ALL
SELECT 'gold.dim_apps',                   COUNT(*) FROM gold.dim_apps
UNION ALL
SELECT 'gold.dim_date',                   COUNT(*) FROM gold.dim_date
UNION ALL
SELECT 'gold.fact_impressions',           COUNT(*) FROM gold.fact_impressions
UNION ALL
SELECT 'gold.fact_clicks',                COUNT(*) FROM gold.fact_clicks
UNION ALL
SELECT 'gold.fact_conversions',           COUNT(*) FROM gold.fact_conversions;
