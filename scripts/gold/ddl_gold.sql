/*
===============================================================================
Script: ddl_gold.sql
Description: DDL for Gold layer tables and views.
===============================================================================
*/

USE DataWarehouse;
GO

-- 1. Create dim_date
IF OBJECT_ID('gold.dim_date', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_date (
        date_key INT PRIMARY KEY,
        full_date DATE,
        year INT,
        quarter INT,
        month INT,
        month_name NVARCHAR(20),
        week_of_year INT,
        day_of_week INT,
        day_name NVARCHAR(20),
        is_weekend BIT
    );
END
GO

-- 2. Create dim_campaigns (SCD2)
IF OBJECT_ID('gold.dim_campaigns', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_campaigns (
        campaign_key INT IDENTITY(1,1) PRIMARY KEY,
        campaign_id NVARCHAR(50),
        campaign_name NVARCHAR(200),
        objective NVARCHAR(50),
        budget_usd DECIMAL(12,2),
        start_date DATE,
        end_date DATE,
        status NVARCHAR(20),
        target_geo NVARCHAR(200),
        advertiser_id NVARCHAR(50),
        advertiser_name NVARCHAR(200),
        advertiser_industry NVARCHAR(100),
        advertiser_country NVARCHAR(50),
        dwh_effective_date DATE,
        dwh_expiry_date DATE,
        dwh_is_current BIT DEFAULT 1
    );
END
GO

-- 3. Create dim_advertisers View
IF OBJECT_ID('gold.dim_advertisers', 'V') IS NOT NULL
    DROP VIEW gold.dim_advertisers;
GO
CREATE VIEW gold.dim_advertisers AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY advertiser_id) AS advertiser_key, 
    advertiser_id, 
    company_name, 
    industry, 
    country, 
    account_status, 
    signup_date
FROM silver.crm_advertisers;
GO

-- 4. Create dim_devices View
IF OBJECT_ID('gold.dim_devices', 'V') IS NOT NULL
    DROP VIEW gold.dim_devices;
GO
CREATE VIEW gold.dim_devices AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY device_id) AS device_key, 
    device_id, 
    os_type, 
    device_type, 
    country, 
    language, 
    age_band,
    CASE 
        WHEN UPPER(device_type) = 'CTV' THEN 'Connected TV' 
        WHEN UPPER(device_type) = 'MOBILE' THEN 'Mobile' 
        WHEN UPPER(device_type) = 'TABLET' THEN 'Tablet' 
        ELSE 'Desktop' 
    END AS device_category
FROM silver.device_profiles;
GO

-- 5. Create dim_apps View
IF OBJECT_ID('gold.dim_apps', 'V') IS NOT NULL
    DROP VIEW gold.dim_apps;
GO
CREATE VIEW gold.dim_apps AS
SELECT 
    DENSE_RANK() OVER (ORDER BY app_id) AS app_key, 
    app_id, 
    MAX(app_name) AS app_name, 
    MAX(app_category) AS app_category, 
    COUNT(DISTINCT device_id) AS install_count
FROM silver.device_app_installs 
GROUP BY app_id;
GO

-- 6. Create fact_impressions View
IF OBJECT_ID('gold.fact_impressions', 'V') IS NOT NULL
    DROP VIEW gold.fact_impressions;
GO
CREATE VIEW gold.fact_impressions AS
SELECT 
    i.imp_id AS impression_id, 
    cam.campaign_key, 
    dev.device_key, 
    dd.date_key    AS event_date_key,
    i.event_ts, 
    i.bid_price, 
    i.placement_type, 
    i.ad_format, 
    i.geo_country, 
    i.geo_city,
    CASE WHEN cl.click_id IS NOT NULL THEN 1 ELSE 0 END AS is_clicked
FROM silver.dsp_impressions i
LEFT JOIN gold.dim_campaigns cam ON i.campaign_id = cam.campaign_id AND cam.dwh_is_current = 1
LEFT JOIN gold.dim_devices dev ON i.device_id = dev.device_id
LEFT JOIN gold.dim_date dd ON CAST(i.event_ts AS DATE) = dd.full_date
LEFT JOIN silver.dsp_clicks cl ON i.imp_id = cl.imp_id;
GO

-- 7. Create fact_clicks View
IF OBJECT_ID('gold.fact_clicks', 'V') IS NOT NULL
    DROP VIEW gold.fact_clicks;
GO
CREATE VIEW gold.fact_clicks AS
SELECT 
    c.click_id, 
    c.imp_id AS impression_id, 
    cam.campaign_key, 
    dev.device_key, 
    dd.date_key AS click_date_key, 
    c.event_ts AS click_ts
FROM silver.dsp_clicks c
LEFT JOIN gold.dim_campaigns cam ON c.campaign_id = cam.campaign_id AND cam.dwh_is_current = 1
LEFT JOIN gold.dim_devices dev ON c.device_id = dev.device_id
LEFT JOIN gold.dim_date dd ON CAST(c.event_ts AS DATE) = dd.full_date;
GO

-- 8. Create fact_conversions View
IF OBJECT_ID('gold.fact_conversions', 'V') IS NOT NULL
    DROP VIEW gold.fact_conversions;
GO
CREATE VIEW gold.fact_conversions AS
WITH EarliestClick AS (
    SELECT 
        inst.install_id,
        cl.click_id,
        cl.campaign_id,
        cl.device_id,
        cl.event_ts AS click_ts,
        inst.app_id,
        inst.install_date,
        ROW_NUMBER() OVER (PARTITION BY inst.install_id ORDER BY cl.event_ts ASC) AS rn
    FROM silver.device_app_installs inst
    INNER JOIN silver.dsp_clicks cl ON inst.device_id = cl.device_id 
        AND inst.install_date BETWEEN cl.event_ts AND DATEADD(DAY, 7, cl.event_ts)
)
SELECT 
    ec.install_id, 
    ec.click_id, 
    cam.campaign_key, 
    dev.device_key, 
    app.app_key, 
    dd.date_key AS conversion_date_key, 
    DATEDIFF(HOUR, ec.click_ts, ec.install_date) AS hours_to_convert
FROM EarliestClick ec
LEFT JOIN gold.dim_campaigns cam ON ec.campaign_id = cam.campaign_id AND cam.dwh_is_current = 1
LEFT JOIN gold.dim_devices dev ON ec.device_id = dev.device_id
LEFT JOIN gold.dim_apps app ON ec.app_id = app.app_id
LEFT JOIN gold.dim_date dd ON CAST(ec.install_date AS DATE) = dd.full_date
WHERE ec.rn = 1;
GO
