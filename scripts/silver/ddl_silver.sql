USE DataWarehouse;
GO

IF OBJECT_ID('silver.dsp_impressions', 'U') IS NOT NULL
    DROP TABLE silver.dsp_impressions;
CREATE TABLE silver.dsp_impressions (
    imp_id NVARCHAR(50),
    device_id NVARCHAR(50),
    campaign_id NVARCHAR(50),
    event_ts DATETIME2,
    bid_price DECIMAL(10,4),
    geo_country NVARCHAR(100),
    geo_city NVARCHAR(100),
    placement_type NVARCHAR(50),
    ad_format NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.dsp_clicks', 'U') IS NOT NULL
    DROP TABLE silver.dsp_clicks;
CREATE TABLE silver.dsp_clicks (
    click_id NVARCHAR(50),
    imp_id NVARCHAR(50),
    device_id NVARCHAR(50),
    campaign_id NVARCHAR(50),
    event_ts DATETIME2,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.crm_campaigns', 'U') IS NOT NULL
    DROP TABLE silver.crm_campaigns;
CREATE TABLE silver.crm_campaigns (
    campaign_id NVARCHAR(50),
    advertiser_id NVARCHAR(50),
    campaign_name NVARCHAR(200),
    objective NVARCHAR(50),
    budget_usd DECIMAL(12,2),
    start_date DATE,
    end_date DATE,
    campaign_duration_days INT,
    status NVARCHAR(20),
    target_geo NVARCHAR(200),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.crm_advertisers', 'U') IS NOT NULL
    DROP TABLE silver.crm_advertisers;
CREATE TABLE silver.crm_advertisers (
    advertiser_id NVARCHAR(50),
    company_name NVARCHAR(200),
    industry NVARCHAR(100),
    country NVARCHAR(50),
    account_status NVARCHAR(20),
    signup_date DATE,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.device_profiles', 'U') IS NOT NULL
    DROP TABLE silver.device_profiles;
CREATE TABLE silver.device_profiles (
    device_id NVARCHAR(50),
    os_type NVARCHAR(50),
    device_type NVARCHAR(50),
    country NVARCHAR(50),
    language NVARCHAR(20),
    age_band NVARCHAR(20),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.device_app_installs', 'U') IS NOT NULL
    DROP TABLE silver.device_app_installs;
CREATE TABLE silver.device_app_installs (
    install_id NVARCHAR(50),
    device_id NVARCHAR(50),
    app_id NVARCHAR(50),
    app_name NVARCHAR(200),
    app_category NVARCHAR(100),
    install_date DATETIME2,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO
