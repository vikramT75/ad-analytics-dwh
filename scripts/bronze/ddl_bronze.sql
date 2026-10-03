USE DataWarehouse;
GO

IF OBJECT_ID('bronze.dsp_impressions', 'U') IS NOT NULL
    DROP TABLE bronze.dsp_impressions;
CREATE TABLE bronze.dsp_impressions (
    imp_id NVARCHAR(50),
    device_id NVARCHAR(50),
    campaign_id NVARCHAR(50),
    event_ts NVARCHAR(30),
    bid_price NVARCHAR(20),
    geo_country NVARCHAR(10),
    geo_city NVARCHAR(100),
    placement_type NVARCHAR(50),
    ad_format NVARCHAR(50),
    dwh_load_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('bronze.dsp_clicks', 'U') IS NOT NULL
    DROP TABLE bronze.dsp_clicks;
CREATE TABLE bronze.dsp_clicks (
    click_id NVARCHAR(50),
    imp_id NVARCHAR(50),
    device_id NVARCHAR(50),
    campaign_id NVARCHAR(50),
    event_ts NVARCHAR(30),
    dwh_load_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('bronze.crm_campaigns', 'U') IS NOT NULL
    DROP TABLE bronze.crm_campaigns;
CREATE TABLE bronze.crm_campaigns (
    campaign_id NVARCHAR(50),
    advertiser_id NVARCHAR(50),
    campaign_name NVARCHAR(200),
    objective NVARCHAR(50),
    budget_usd NVARCHAR(20),
    start_date NVARCHAR(20),
    end_date NVARCHAR(20),
    status NVARCHAR(20),
    target_geo NVARCHAR(200),
    dwh_load_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('bronze.crm_advertisers', 'U') IS NOT NULL
    DROP TABLE bronze.crm_advertisers;
CREATE TABLE bronze.crm_advertisers (
    advertiser_id NVARCHAR(50),
    company_name NVARCHAR(200),
    industry NVARCHAR(100),
    country NVARCHAR(50),
    account_status NVARCHAR(20),
    signup_date NVARCHAR(20),
    dwh_load_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('bronze.device_profiles', 'U') IS NOT NULL
    DROP TABLE bronze.device_profiles;
CREATE TABLE bronze.device_profiles (
    device_id NVARCHAR(50),
    os_type NVARCHAR(50),
    device_type NVARCHAR(50),
    country NVARCHAR(50),
    language NVARCHAR(20),
    age_band NVARCHAR(20),
    dwh_load_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('bronze.device_app_installs', 'U') IS NOT NULL
    DROP TABLE bronze.device_app_installs;
CREATE TABLE bronze.device_app_installs (
    install_id NVARCHAR(50),
    device_id NVARCHAR(50),
    app_id NVARCHAR(50),
    app_name NVARCHAR(200),
    app_category NVARCHAR(100),
    install_date NVARCHAR(30),
    dwh_load_date DATETIME2 DEFAULT GETDATE()
);
GO
