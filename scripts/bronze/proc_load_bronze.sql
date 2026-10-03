/*
===============================================================================
Script: proc_load_bronze.sql
Description: Stored procedure to load all Bronze layer tables.
===============================================================================
*/

USE DataWarehouse;
GO

IF OBJECT_ID('bronze.load_bronze', 'P') IS NOT NULL
    DROP PROCEDURE bronze.load_bronze;
GO

CREATE PROCEDURE bronze.load_bronze
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @end_time DATETIME2;
    DECLARE @batch_start_time DATETIME2 = GETDATE();
    
    DECLARE @data_path NVARCHAR(255) = 'E:\awat\sql-proj\datasets\';
    DECLARE @sql NVARCHAR(MAX);
    
    BEGIN TRY
        PRINT '====================================================';
        PRINT 'Starting Bronze Layer Load Process';
        PRINT 'Batch Start Time: ' + CONVERT(NVARCHAR, @batch_start_time, 120);
        PRINT '====================================================';

        -- bronze.dsp_impressions
        SET @start_time = GETDATE();
        PRINT 'Truncating bronze.dsp_impressions...';
        TRUNCATE TABLE bronze.dsp_impressions;
        PRINT 'Loading bronze.dsp_impressions...';
        SET @sql = 'BULK INSERT bronze.dsp_impressions FROM ''' + @data_path + 'dsp_impressions.csv'' WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''\n'', FIRSTROW=2, CODEPAGE=''65001'');';
        EXEC sp_executesql @sql;
        SET @end_time = GETDATE();
        PRINT 'bronze.dsp_impressions load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- bronze.dsp_clicks
        SET @start_time = GETDATE();
        PRINT 'Truncating bronze.dsp_clicks...';
        TRUNCATE TABLE bronze.dsp_clicks;
        PRINT 'Loading bronze.dsp_clicks...';
        SET @sql = 'BULK INSERT bronze.dsp_clicks FROM ''' + @data_path + 'dsp_clicks.csv'' WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''\n'', FIRSTROW=2, CODEPAGE=''65001'');';
        EXEC sp_executesql @sql;
        SET @end_time = GETDATE();
        PRINT 'bronze.dsp_clicks load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- bronze.crm_campaigns
        SET @start_time = GETDATE();
        PRINT 'Truncating bronze.crm_campaigns...';
        TRUNCATE TABLE bronze.crm_campaigns;
        PRINT 'Loading bronze.crm_campaigns...';
        SET @sql = 'BULK INSERT bronze.crm_campaigns FROM ''' + @data_path + 'crm_campaigns.csv'' WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''\n'', FIRSTROW=2, CODEPAGE=''65001'');';
        EXEC sp_executesql @sql;
        SET @end_time = GETDATE();
        PRINT 'bronze.crm_campaigns load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- bronze.crm_advertisers
        SET @start_time = GETDATE();
        PRINT 'Truncating bronze.crm_advertisers...';
        TRUNCATE TABLE bronze.crm_advertisers;
        PRINT 'Loading bronze.crm_advertisers...';
        SET @sql = 'BULK INSERT bronze.crm_advertisers FROM ''' + @data_path + 'crm_advertisers.csv'' WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''\n'', FIRSTROW=2, CODEPAGE=''65001'');';
        EXEC sp_executesql @sql;
        SET @end_time = GETDATE();
        PRINT 'bronze.crm_advertisers load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- bronze.device_profiles
        SET @start_time = GETDATE();
        PRINT 'Truncating bronze.device_profiles...';
        TRUNCATE TABLE bronze.device_profiles;
        PRINT 'Loading bronze.device_profiles...';
        SET @sql = 'BULK INSERT bronze.device_profiles FROM ''' + @data_path + 'device_profiles.csv'' WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''\n'', FIRSTROW=2, CODEPAGE=''65001'');';
        EXEC sp_executesql @sql;
        SET @end_time = GETDATE();
        PRINT 'bronze.device_profiles load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        -- bronze.device_app_installs
        SET @start_time = GETDATE();
        PRINT 'Truncating bronze.device_app_installs...';
        TRUNCATE TABLE bronze.device_app_installs;
        PRINT 'Loading bronze.device_app_installs...';
        SET @sql = 'BULK INSERT bronze.device_app_installs FROM ''' + @data_path + 'device_app_installs.csv'' WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''\n'', FIRSTROW=2, CODEPAGE=''65001'');';
        EXEC sp_executesql @sql;
        SET @end_time = GETDATE();
        PRINT 'bronze.device_app_installs load completed in ' + CAST(DATEDIFF(ms, @start_time, @end_time) AS NVARCHAR) + ' ms.';

        PRINT '====================================================';
        PRINT 'Bronze Layer Load Process Completed';
        PRINT 'Total Batch Time: ' + CAST(DATEDIFF(ms, @batch_start_time, GETDATE()) AS NVARCHAR) + ' ms.';
        PRINT '====================================================';

    END TRY
    BEGIN CATCH
        PRINT '====================================================';
        PRINT 'ERROR IN BRONZE LOAD PROCESS';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR);
        PRINT '====================================================';
        THROW;
    END CATCH
END
GO
