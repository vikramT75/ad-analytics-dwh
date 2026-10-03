PRINT '================================================================';
PRINT 'BRONZE LAYER QUALITY CHECKS';
PRINT '================================================================';


-- ====================================================================
-- 1. ROW COUNT CHECKS
-- Expected: Non-zero row counts for all tables
-- ====================================================================
PRINT '>> Check 1: Row Counts';

SELECT 'bronze.dsp_impressions'    AS table_name, COUNT(*) AS row_count FROM bronze.dsp_impressions
UNION ALL
SELECT 'bronze.dsp_clicks',        COUNT(*) FROM bronze.dsp_clicks
UNION ALL
SELECT 'bronze.crm_campaigns',     COUNT(*) FROM bronze.crm_campaigns
UNION ALL
SELECT 'bronze.crm_advertisers',   COUNT(*) FROM bronze.crm_advertisers
UNION ALL
SELECT 'bronze.device_profiles',   COUNT(*) FROM bronze.device_profiles
UNION ALL
SELECT 'bronze.device_app_installs', COUNT(*) FROM bronze.device_app_installs;


-- ====================================================================
-- 2. NULL RATE IN CRITICAL FIELDS
-- Expected: Low null rates; very high null rates indicate load failure
-- ====================================================================
PRINT '>> Check 2: NULL Rate in Critical Fields';

SELECT
    'dsp_impressions.imp_id'    AS field,
    COUNT(*)                    AS total_rows,
    SUM(CASE WHEN imp_id IS NULL THEN 1 ELSE 0 END) AS null_count,
    CAST(SUM(CASE WHEN imp_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(6,2)) AS null_pct
FROM bronze.dsp_impressions
UNION ALL
SELECT
    'dsp_impressions.device_id',
    COUNT(*),
    SUM(CASE WHEN device_id IS NULL THEN 1 ELSE 0 END),
    CAST(SUM(CASE WHEN device_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(6,2))
FROM bronze.dsp_impressions
UNION ALL
SELECT
    'dsp_impressions.campaign_id',
    COUNT(*),
    SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END),
    CAST(SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(6,2))
FROM bronze.dsp_impressions
UNION ALL
SELECT
    'crm_campaigns.campaign_id',
    COUNT(*),
    SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END),
    CAST(SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(6,2))
FROM bronze.crm_campaigns;


-- ====================================================================
-- 3. DUPLICATE IMPRESSION IDs IN BRONZE
-- Expected: Duplicates present (intentionally injected) -- Silver will dedup
-- ====================================================================
PRINT '>> Check 3: Duplicate imp_id in bronze.dsp_impressions (expected: ~100 dupes)';

SELECT
    imp_id,
    COUNT(*) AS occurrence_count
FROM bronze.dsp_impressions
GROUP BY imp_id
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;


-- ====================================================================
-- 4. INVALID BID PRICES IN BRONZE
-- Expected: Some negatives, zeros, and outliers (intentionally injected)
-- ====================================================================
PRINT '>> Check 4: Invalid bid_price values in bronze.dsp_impressions';

SELECT
    CASE
        WHEN TRY_CAST(bid_price AS DECIMAL(10,4)) IS NULL THEN 'Non-numeric'
        WHEN CAST(bid_price AS DECIMAL(10,4)) <= 0          THEN 'Zero or Negative'
        WHEN CAST(bid_price AS DECIMAL(10,4)) > 100         THEN 'Outlier (>100)'
        ELSE 'Valid'
    END                         AS price_category,
    COUNT(*)                    AS row_count
FROM bronze.dsp_impressions
WHERE bid_price IS NOT NULL
GROUP BY
    CASE
        WHEN TRY_CAST(bid_price AS DECIMAL(10,4)) IS NULL THEN 'Non-numeric'
        WHEN CAST(bid_price AS DECIMAL(10,4)) <= 0          THEN 'Zero or Negative'
        WHEN CAST(bid_price AS DECIMAL(10,4)) > 100         THEN 'Outlier (>100)'
        ELSE 'Valid'
    END;


-- ====================================================================
-- 5. INVALID / UNKNOWN COUNTRY CODES
-- Expected: Some 2-letter codes, empty strings (will be normalized in Silver)
-- ====================================================================
PRINT '>> Check 5: Distinct geo_country values in bronze.dsp_impressions';

SELECT
    geo_country,
    COUNT(*) AS row_count
FROM bronze.dsp_impressions
GROUP BY geo_country
ORDER BY row_count DESC;


-- ====================================================================
-- 6. DIRTY STATUS VALUES IN CRM TABLES
-- Expected: Mix of full words (ACTIVE) and codes (A) -- normalized in Silver
-- ====================================================================
PRINT '>> Check 6: Distinct status values in bronze.crm_campaigns';

SELECT status, COUNT(*) AS row_count
FROM bronze.crm_campaigns
GROUP BY status
ORDER BY row_count DESC;

PRINT '>> Check 6b: Distinct account_status values in bronze.crm_advertisers';

SELECT account_status, COUNT(*) AS row_count
FROM bronze.crm_advertisers
GROUP BY account_status
ORDER BY row_count DESC;


-- ====================================================================
-- 7. CLICKS WITHOUT MATCHING IMPRESSIONS (referential integrity)
-- Expected: ~20 orphaned clicks (intentionally injected)
-- ====================================================================
PRINT '>> Check 7: Clicks in bronze without matching impression (expected: ~20)';

SELECT COUNT(*) AS orphaned_clicks
FROM bronze.dsp_clicks bc
WHERE NOT EXISTS (
    SELECT 1 FROM bronze.dsp_impressions bi WHERE bi.imp_id = bc.imp_id
);
