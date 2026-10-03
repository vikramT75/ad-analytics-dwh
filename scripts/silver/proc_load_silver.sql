/*
===============================================================================
Script: proc_load_silver.sql
Description: Stored procedure to load all Silver layer tables.
===============================================================================
*/

USE DataWarehouse;
GO

IF OBJECT_ID('silver.load_silver', 'P') IS NOT NULL
    DROP PROCEDURE silver.load_silver;
GO

CREATE PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @end_time DATETIME2;
    DECLARE @batch_start_time DATETIME2 = GETDATE();
    
    BEGIN TRY
        PRINT '====================================================';
        PRINT 'Starting Silver Layer Load Process';
        PRINT 'Batch Start Time: ' + CONVERT(NVARCHAR, @batch_start_time, 120);
        PRINT '====================================================';

        -- silver.dsp_impressions
        SET @start_time = GETDATE();
        PRINT 'Truncating silver.dsp_impressions...';
        TRUNCATE TABLE silver.dsp_impressions;
        PRINT 'Loading silver.dsp_impressions...';
        
        WITH DeduplicatedImpressions AS (
            SELECT 
                imp_id, device_id, campaign_id, event_ts, bid_price, geo_country, geo_city, placement_type, ad_format,
                ROW_NUMBER() OVER (PARTITION BY imp_id ORDER BY TRY_CAST(event_ts AS DATETIME2) DESC) AS rn
            FROM bronze.dsp_impressions
        )
        INSERT INTO silver.dsp_impressions (
            imp_id, device_id, campaign_id, event_ts, bid_price, 
            geo_country, geo_city, placement_type, ad_format
        )
        SELECT 
            imp_id,
            device_id,
            campaign_id,
            TRY_CAST(event_ts AS DATETIME2) AS event_ts,
            CASE 
                WHEN TRY_CAST(bid_price AS DECIMAL(10,4)) <= 0 OR TRY_CAST(bid_price AS DECIMAL(10,4)) > 100 THEN NULL 
                ELSE TRY_CAST(bid_price AS DECIMAL(10,4)) 
            END AS bid_price,
            CASE 
                WHEN UPPER(geo_country) IN ('US', 'USA') THEN 'United States'
                WHEN UPPER(geo_country) IN ('IN', 'IND') THEN 'India'
                WHEN UPPER(geo_country) IN ('GB', 'GBR') THEN 'United Kingdom'
                WHEN UPPER(geo_country) IN ('CA', 'CAN') THEN 'Canada'
                WHEN UPPER(geo_country) IN ('AU', 'AUS') THEN 'Australia'
                WHEN UPPER(geo_country) IN ('DE', 'DEU') THEN 'Germany'
                WHEN geo_country IS NULL OR TRIM(geo_country) = '' THEN 'Unknown'
                ELSE TRIM(geo_country)
            END AS geo_country,
            geo_city,
            placement_type,
            ad_format
        FROM DeduplicatedImpressions
        WHERE rn = 1;

        SET @end_time = GETDATE();
        PRINT 'silver.dsp_impressions load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- silver.dsp_clicks
        SET @start_time = GETDATE();
        PRINT 'Truncating silver.dsp_clicks...';
        TRUNCATE TABLE silver.dsp_clicks;
        PRINT 'Loading silver.dsp_clicks...';
        
        INSERT INTO silver.dsp_clicks (click_id, imp_id, device_id, campaign_id, event_ts)
        SELECT 
            c.click_id,
            c.imp_id,
            c.device_id,
            c.campaign_id,
            TRY_CAST(c.event_ts AS DATETIME2) AS event_ts
        FROM bronze.dsp_clicks c
        WHERE EXISTS (
            SELECT 1 FROM silver.dsp_impressions i WHERE i.imp_id = c.imp_id
        );

        SET @end_time = GETDATE();
        PRINT 'silver.dsp_clicks load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- silver.crm_campaigns
        SET @start_time = GETDATE();
        PRINT 'Truncating silver.crm_campaigns...';
        TRUNCATE TABLE silver.crm_campaigns;
        PRINT 'Loading silver.crm_campaigns...';
        
        INSERT INTO silver.crm_campaigns (
            campaign_id, advertiser_id, campaign_name, objective, budget_usd, 
            start_date, end_date, campaign_duration_days, status, target_geo
        )
        SELECT 
            campaign_id,
            advertiser_id,
            campaign_name,
            CASE 
                WHEN UPPER(objective) IN ('AWA', 'AWARENESS') THEN 'Awareness'
                WHEN UPPER(objective) IN ('PERF', 'PERFORMANCE') THEN 'Performance'
                WHEN UPPER(objective) IN ('RET', 'RETARGETING') THEN 'Retargeting'
                ELSE 'Other'
            END AS objective,
            CASE 
                WHEN TRY_CAST(budget_usd AS DECIMAL(12,2)) <= 0 THEN NULL
                ELSE TRY_CAST(budget_usd AS DECIMAL(12,2))
            END AS budget_usd,
            TRY_CAST(start_date AS DATE) AS start_date,
            TRY_CAST(end_date AS DATE) AS end_date,
            DATEDIFF(DAY, TRY_CAST(start_date AS DATE), TRY_CAST(end_date AS DATE)) AS campaign_duration_days,
            CASE 
                WHEN UPPER(status) IN ('A', 'ACTIVE') THEN 'Active'
                WHEN UPPER(status) IN ('P', 'PAUSED') THEN 'Paused'
                WHEN UPPER(status) IN ('C', 'COMPLETED') THEN 'Completed'
                WHEN UPPER(status) IN ('D', 'DRAFT') THEN 'Draft'
                ELSE 'Unknown'
            END AS status,
            target_geo
        FROM bronze.crm_campaigns;

        SET @end_time = GETDATE();
        PRINT 'silver.crm_campaigns load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- silver.crm_advertisers
        SET @start_time = GETDATE();
        PRINT 'Truncating silver.crm_advertisers...';
        TRUNCATE TABLE silver.crm_advertisers;
        PRINT 'Loading silver.crm_advertisers...';
        
        INSERT INTO silver.crm_advertisers (
            advertiser_id, company_name, industry, country, account_status, signup_date
        )
        SELECT 
            advertiser_id,
            company_name,
            industry,
            country,
            CASE 
                WHEN UPPER(account_status) IN ('A', 'ACTIVE') THEN 'Active'
                WHEN UPPER(account_status) IN ('S', 'SUSPENDED') THEN 'Suspended'
                WHEN UPPER(account_status) IN ('P', 'PAUSED') THEN 'Paused'
                ELSE 'Unknown'
            END AS account_status,
            TRY_CAST(signup_date AS DATE) AS signup_date
        FROM bronze.crm_advertisers;

        SET @end_time = GETDATE();
        PRINT 'silver.crm_advertisers load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- silver.device_profiles
        SET @start_time = GETDATE();
        PRINT 'Truncating silver.device_profiles...';
        TRUNCATE TABLE silver.device_profiles;
        PRINT 'Loading silver.device_profiles...';
        
        INSERT INTO silver.device_profiles (
            device_id, os_type, device_type, country, language, age_band
        )
        SELECT 
            TRIM(device_id) AS device_id,
            CASE 
                WHEN LOWER(TRIM(os_type)) = 'ios' THEN 'iOS'
                WHEN LOWER(TRIM(os_type)) = 'android' THEN 'Android'
                WHEN LOWER(TRIM(os_type)) = 'windows' THEN 'Windows'
                WHEN LOWER(TRIM(os_type)) IN ('macos', 'mac os') THEN 'macOS'
                ELSE TRIM(os_type)
            END AS os_type,
            CASE 
                WHEN LOWER(TRIM(device_type)) IN ('mob', 'mobile') THEN 'Mobile'
                WHEN LOWER(TRIM(device_type)) IN ('tab', 'tablet') THEN 'Tablet'
                WHEN LOWER(TRIM(device_type)) IN ('desk', 'desktop') THEN 'Desktop'
                WHEN LOWER(TRIM(device_type)) = 'ctv' THEN 'CTV'
                ELSE TRIM(device_type)
            END AS device_type,
            TRIM(country) AS country,
            TRIM(language) AS language,
            TRIM(age_band) AS age_band
        FROM bronze.device_profiles;

        SET @end_time = GETDATE();
        PRINT 'silver.device_profiles load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- silver.device_app_installs
        SET @start_time = GETDATE();
        PRINT 'Truncating silver.device_app_installs...';
        TRUNCATE TABLE silver.device_app_installs;
        PRINT 'Loading silver.device_app_installs...';
        
        INSERT INTO silver.device_app_installs (
            install_id, device_id, app_id, app_name, app_category, install_date
        )
        SELECT 
            install_id,
            device_id,
            app_id,
            TRIM(app_name) AS app_name,
            TRIM(app_category) AS app_category,
            TRY_CAST(install_date AS DATETIME2) AS install_date
        FROM bronze.device_app_installs;

        SET @end_time = GETDATE();
        PRINT 'silver.device_app_installs load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        PRINT '====================================================';
        PRINT 'Silver Layer Load Process Completed';
        PRINT 'Total Batch Time: ' + CAST(DATEDIFF(ms, @batch_start_time, GETDATE()) AS NVARCHAR) + ' ms.';
        PRINT '====================================================';

    END TRY
    BEGIN CATCH
        PRINT '====================================================';
        PRINT 'ERROR IN SILVER LOAD PROCESS';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR);
        PRINT '====================================================';
        THROW;
    END CATCH
END
GO
