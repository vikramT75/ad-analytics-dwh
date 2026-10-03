PRINT '================================================================';
PRINT 'SILVER LAYER QUALITY CHECKS';
PRINT '================================================================';


-- ====================================================================
-- 1. ROW COUNT COMPARISON: Bronze vs Silver
-- Expected: Silver <= Bronze (some rows dropped due to QC)
--           Silver >= Bronze * 0.95 (at most 5% dropped)
-- ====================================================================
PRINT '>> Check 1: Row Count Comparison (Bronze vs Silver)';

SELECT
    'dsp_impressions'       AS table_name,
    b.bronze_count,
    s.silver_count,
    b.bronze_count - s.silver_count             AS rows_dropped,
    CAST((b.bronze_count - s.silver_count) * 100.0 / NULLIF(b.bronze_count, 0) AS DECIMAL(6,2)) AS drop_pct
FROM
    (SELECT COUNT(*) AS bronze_count FROM bronze.dsp_impressions) b,
    (SELECT COUNT(*) AS silver_count FROM silver.dsp_impressions) s
UNION ALL
SELECT
    'dsp_clicks',
    b.bronze_count, s.silver_count,
    b.bronze_count - s.silver_count,
    CAST((b.bronze_count - s.silver_count) * 100.0 / NULLIF(b.bronze_count, 0) AS DECIMAL(6,2))
FROM
    (SELECT COUNT(*) AS bronze_count FROM bronze.dsp_clicks) b,
    (SELECT COUNT(*) AS silver_count FROM silver.dsp_clicks) s
UNION ALL
SELECT
    'crm_campaigns',
    b.bronze_count, s.silver_count,
    b.bronze_count - s.silver_count,
    CAST((b.bronze_count - s.silver_count) * 100.0 / NULLIF(b.bronze_count, 0) AS DECIMAL(6,2))
FROM
    (SELECT COUNT(*) AS bronze_count FROM bronze.crm_campaigns) b,
    (SELECT COUNT(*) AS silver_count FROM silver.crm_campaigns) s
UNION ALL
SELECT
    'crm_advertisers',
    b.bronze_count, s.silver_count,
    b.bronze_count - s.silver_count,
    CAST((b.bronze_count - s.silver_count) * 100.0 / NULLIF(b.bronze_count, 0) AS DECIMAL(6,2))
FROM
    (SELECT COUNT(*) AS bronze_count FROM bronze.crm_advertisers) b,
    (SELECT COUNT(*) AS silver_count FROM silver.crm_advertisers) s
UNION ALL
SELECT
    'device_profiles',
    b.bronze_count, s.silver_count,
    b.bronze_count - s.silver_count,
    CAST((b.bronze_count - s.silver_count) * 100.0 / NULLIF(b.bronze_count, 0) AS DECIMAL(6,2))
FROM
    (SELECT COUNT(*) AS bronze_count FROM bronze.device_profiles) b,
    (SELECT COUNT(*) AS silver_count FROM silver.device_profiles) s
UNION ALL
SELECT
    'device_app_installs',
    b.bronze_count, s.silver_count,
    b.bronze_count - s.silver_count,
    CAST((b.bronze_count - s.silver_count) * 100.0 / NULLIF(b.bronze_count, 0) AS DECIMAL(6,2))
FROM
    (SELECT COUNT(*) AS bronze_count FROM bronze.device_app_installs) b,
    (SELECT COUNT(*) AS silver_count FROM silver.device_app_installs) s;


-- ====================================================================
-- 2. DEDUPLICATION CHECK: No duplicate imp_id in silver
-- Expectation: NO ROWS returned
-- ====================================================================
PRINT '>> Check 2: Duplicate imp_id in silver.dsp_impressions (expect: 0 rows)';

SELECT
    imp_id,
    COUNT(*) AS duplicate_count
FROM silver.dsp_impressions
GROUP BY imp_id
HAVING COUNT(*) > 1;


-- ====================================================================
-- 3. REFERENTIAL INTEGRITY: Clicks reference valid impressions
-- Expectation: NO ROWS returned (orphaned clicks excluded in Silver ETL)
-- ====================================================================
PRINT '>> Check 3: Clicks without matching impression in Silver (expect: 0 rows)';

SELECT
    sc.click_id,
    sc.imp_id
FROM silver.dsp_clicks sc
WHERE NOT EXISTS (
    SELECT 1 FROM silver.dsp_impressions si WHERE si.imp_id = sc.imp_id
);


-- ====================================================================
-- 4. DATE RANGE VALIDATION
-- Expectation: All event timestamps in reasonable range (2020-2025)
-- ====================================================================
PRINT '>> Check 4: Out-of-range event timestamps in silver.dsp_impressions (expect: 0 rows)';

SELECT
    imp_id,
    event_ts
FROM silver.dsp_impressions
WHERE event_ts < '2020-01-01'
   OR event_ts > GETDATE();

PRINT '>> Check 4b: Future install dates in silver.device_app_installs (expect: 0 rows)';

SELECT
    install_id,
    install_date
FROM silver.device_app_installs
WHERE install_date > GETDATE();


-- ====================================================================
-- 5. BID PRICE VALIDATION
-- Expectation: No negative or zero bid prices in Silver
-- ====================================================================
PRINT '>> Check 5: Invalid bid_price in silver.dsp_impressions (expect: 0 rows)';

SELECT
    imp_id,
    bid_price
FROM silver.dsp_impressions
WHERE bid_price IS NOT NULL
  AND (bid_price <= 0 OR bid_price > 100);


-- ====================================================================
-- 6. NORMALIZED VALUE CHECKS
-- Expectation: Only standardized values for categorical fields
-- ====================================================================
PRINT '>> Check 6: Non-standard status values in silver.crm_campaigns (expect: 0 rows)';

SELECT DISTINCT status
FROM silver.crm_campaigns
WHERE status NOT IN ('Active', 'Paused', 'Completed', 'Draft', 'Unknown');

PRINT '>> Check 6b: Non-standard account_status in silver.crm_advertisers (expect: 0 rows)';

SELECT DISTINCT account_status
FROM silver.crm_advertisers
WHERE account_status NOT IN ('Active', 'Paused', 'Suspended', 'Unknown');

PRINT '>> Check 6c: Non-standard os_type in silver.device_profiles (expect: 0 rows)';

SELECT DISTINCT os_type
FROM silver.device_profiles
WHERE os_type NOT IN ('iOS', 'Android', 'Windows', 'macOS', 'Unknown');

PRINT '>> Check 6d: Non-standard device_type in silver.device_profiles (expect: 0 rows)';

SELECT DISTINCT device_type
FROM silver.device_profiles
WHERE device_type NOT IN ('Mobile', 'Tablet', 'Desktop', 'CTV', 'Unknown');


-- ====================================================================
-- 7. CAMPAIGN DURATION SANITY CHECK
-- Expectation: No campaigns with negative duration (end before start)
-- ====================================================================
PRINT '>> Check 7: Campaigns with invalid duration in silver.crm_campaigns (expect: 0 rows)';

SELECT
    campaign_id,
    start_date,
    end_date,
    campaign_duration_days
FROM silver.crm_campaigns
WHERE campaign_duration_days < 0
   OR start_date > end_date;


-- ====================================================================
-- 8. CAMPAIGN REFERENTIAL INTEGRITY: impressions reference valid campaigns
-- Expectation: Low/zero unmatched campaigns (some may be expected)
-- ====================================================================
PRINT '>> Check 8: Impressions with no matching campaign in silver.crm_campaigns';

SELECT COUNT(*) AS impression_with_no_campaign
FROM silver.dsp_impressions si
WHERE NOT EXISTS (
    SELECT 1 FROM silver.crm_campaigns sc WHERE sc.campaign_id = si.campaign_id
);
