/*
===============================================================================
Script: proc_load_gold.sql
Description: Stored procedure to load Gold layer tables.
===============================================================================
*/

USE DataWarehouse;
GO

IF OBJECT_ID('gold.load_gold', 'P') IS NOT NULL
    DROP PROCEDURE gold.load_gold;
GO

CREATE PROCEDURE gold.load_gold
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @end_time DATETIME2;
    DECLARE @batch_start_time DATETIME2 = GETDATE();
    
    BEGIN TRY
        PRINT '====================================================';
        PRINT 'Starting Gold Layer Load Process';
        PRINT 'Batch Start Time: ' + CONVERT(NVARCHAR, @batch_start_time, 120);
        PRINT '====================================================';

        -- Section A: Populate gold.dim_date for years 2023 to 2026
        SET @start_time = GETDATE();
        PRINT 'Loading gold.dim_date...';
        
        DECLARE @current_date DATE = '2023-01-01';
        DECLARE @end_date DATE = '2026-12-31';

        WHILE @current_date <= @end_date
        BEGIN
            DECLARE @date_key INT = YEAR(@current_date) * 10000 + MONTH(@current_date) * 100 + DAY(@current_date);
            
            IF NOT EXISTS (SELECT 1 FROM gold.dim_date WHERE date_key = @date_key)
            BEGIN
                INSERT INTO gold.dim_date (
                    date_key, full_date, year, quarter, month, month_name, 
                    week_of_year, day_of_week, day_name, is_weekend
                )
                VALUES (
                    @date_key,
                    @current_date,
                    YEAR(@current_date),
                    DATEPART(QUARTER, @current_date),
                    MONTH(@current_date),
                    DATENAME(MONTH, @current_date),
                    DATEPART(WEEK, @current_date),
                    DATEPART(WEEKDAY, @current_date),
                    DATENAME(WEEKDAY, @current_date),
                    CASE WHEN DATEPART(WEEKDAY, @current_date) IN (1, 7) THEN 1 ELSE 0 END
                );
            END
            SET @current_date = DATEADD(DAY, 1, @current_date);
        END

        SET @end_time = GETDATE();
        PRINT 'gold.dim_date load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- Section B: SCD Type-2 MERGE for gold.dim_campaigns
        SET @start_time = GETDATE();
        PRINT 'Loading gold.dim_campaigns (SCD Type-2)...';
        
        -- Temporary table for source data
        IF OBJECT_ID('tempdb..#SourceCampaigns') IS NOT NULL DROP TABLE #SourceCampaigns;
        
        SELECT 
            c.campaign_id,
            c.campaign_name,
            c.objective,
            c.budget_usd,
            c.start_date,
            c.end_date,
            c.status,
            c.target_geo,
            c.advertiser_id,
            a.company_name AS advertiser_name,
            a.industry AS advertiser_industry,
            a.country AS advertiser_country
        INTO #SourceCampaigns
        FROM silver.crm_campaigns c
        LEFT JOIN silver.crm_advertisers a ON c.advertiser_id = a.advertiser_id;

        -- UPDATE existing records that have changed (Expire them)
        UPDATE target
        SET 
            dwh_expiry_date = CAST(GETDATE() AS DATE), 
            dwh_is_current = 0
        FROM gold.dim_campaigns target
        INNER JOIN #SourceCampaigns source ON source.campaign_id = target.campaign_id
        WHERE target.dwh_is_current = 1
        AND (
            ISNULL(source.campaign_name, '') <> ISNULL(target.campaign_name, '') OR
            ISNULL(source.objective, '') <> ISNULL(target.objective, '') OR
            ISNULL(source.budget_usd, 0) <> ISNULL(target.budget_usd, 0) OR
            ISNULL(source.status, '') <> ISNULL(target.status, '') OR
            ISNULL(source.target_geo, '') <> ISNULL(target.target_geo, '') OR
            ISNULL(source.advertiser_name, '') <> ISNULL(target.advertiser_name, '')
        );

        -- INSERT new records for changed rows (the new active version)
        INSERT INTO gold.dim_campaigns (
            campaign_id, campaign_name, objective, budget_usd, start_date, end_date, 
            status, target_geo, advertiser_id, advertiser_name, advertiser_industry, 
            advertiser_country, dwh_effective_date, dwh_expiry_date, dwh_is_current
        )
        SELECT 
            s.campaign_id, s.campaign_name, s.objective, s.budget_usd, s.start_date, s.end_date, 
            s.status, s.target_geo, s.advertiser_id, s.advertiser_name, s.advertiser_industry, 
            s.advertiser_country, CAST(GETDATE() AS DATE), '9999-12-31', 1
        FROM #SourceCampaigns s
        WHERE EXISTS (
            SELECT 1 FROM gold.dim_campaigns t 
            WHERE t.campaign_id = s.campaign_id AND t.dwh_is_current = 0
        )
        AND NOT EXISTS (
            SELECT 1 FROM gold.dim_campaigns t 
            WHERE t.campaign_id = s.campaign_id AND t.dwh_is_current = 1
        );

        -- INSERT entirely new campaigns
        INSERT INTO gold.dim_campaigns (
            campaign_id, campaign_name, objective, budget_usd, start_date, end_date, 
            status, target_geo, advertiser_id, advertiser_name, advertiser_industry, 
            advertiser_country, dwh_effective_date, dwh_expiry_date, dwh_is_current
        )
        SELECT 
            s.campaign_id, s.campaign_name, s.objective, s.budget_usd, s.start_date, s.end_date, 
            s.status, s.target_geo, s.advertiser_id, s.advertiser_name, s.advertiser_industry, 
            s.advertiser_country, CAST(GETDATE() AS DATE), '9999-12-31', 1
        FROM #SourceCampaigns s
        WHERE NOT EXISTS (
            SELECT 1 FROM gold.dim_campaigns t 
            WHERE t.campaign_id = s.campaign_id
        );

        SET @end_time = GETDATE();
        PRINT 'gold.dim_campaigns load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        PRINT '====================================================';
        PRINT 'Gold Layer Load Process Completed';
        PRINT 'Total Batch Time: ' + CAST(DATEDIFF(ms, @batch_start_time, GETDATE()) AS NVARCHAR) + ' ms.';
        PRINT '====================================================';

    END TRY
    BEGIN CATCH
        PRINT '====================================================';
        PRINT 'ERROR IN GOLD LOAD PROCESS';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR);
        PRINT '====================================================';
        THROW;
    END CATCH
END
GO
