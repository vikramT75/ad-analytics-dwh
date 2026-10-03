/*
===============================================================================
Analytics Report: Funnel Metrics
===============================================================================
Script Purpose:
    Models the full ad-tech conversion funnel:
        Impressions --> Clicks --> Conversions (App Installs)

    Provides funnel analysis by campaign objective and weekly cohorts.
    Includes time-to-convert distribution and attribution window analysis
    (1-day vs 3-day vs 7-day post-click conversion rates).

Usage:
    - Identify where campaigns lose users in the funnel.
    - Compare short vs long attribution windows.
    - Analyze which campaign objectives convert fastest.

Output Grain: One row per campaign per week (for cohort view).
===============================================================================
*/

IF OBJECT_ID('analytics.report_funnel_metrics', 'V') IS NOT NULL
    DROP VIEW analytics.report_funnel_metrics;
GO

CREATE VIEW analytics.report_funnel_metrics AS
WITH weekly_impressions AS (
    SELECT
        cam.campaign_id,
        cam.campaign_name,
        cam.objective,
        cam.advertiser_industry,
        dd.year                             AS event_year,
        dd.week_of_year                     AS event_week,
        MIN(dd.full_date)                   AS week_start_date,
        COUNT(DISTINCT fi.impression_id)    AS impressions,
        SUM(fi.bid_price)                   AS spend
    FROM gold.fact_impressions fi
    LEFT JOIN gold.dim_campaigns cam  ON fi.campaign_key  = cam.campaign_key AND cam.dwh_is_current = 1
    LEFT JOIN gold.dim_date      dd   ON fi.event_date_key = dd.date_key
    WHERE dd.date_key IS NOT NULL
    GROUP BY
        cam.campaign_id,
        cam.campaign_name,
        cam.objective,
        cam.advertiser_industry,
        dd.year,
        dd.week_of_year
),
weekly_clicks AS (
    SELECT
        cam.campaign_id,
        dd.year                             AS event_year,
        dd.week_of_year                     AS event_week,
        COUNT(DISTINCT fc.click_id)         AS clicks
    FROM gold.fact_clicks fc
    LEFT JOIN gold.dim_campaigns cam  ON fc.campaign_key   = cam.campaign_key AND cam.dwh_is_current = 1
    LEFT JOIN gold.dim_date      dd   ON fc.click_date_key = dd.date_key
    WHERE dd.date_key IS NOT NULL
    GROUP BY
        cam.campaign_id,
        dd.year,
        dd.week_of_year
),
weekly_conversions AS (
    SELECT
        cam.campaign_id,
        dd.year                             AS event_year,
        dd.week_of_year                     AS event_week,
        COUNT(DISTINCT fconv.install_id)    AS conversions,
        -- Attribution window sub-buckets
        SUM(CASE WHEN fconv.hours_to_convert <= 24  THEN 1 ELSE 0 END) AS conv_within_1_day,
        SUM(CASE WHEN fconv.hours_to_convert <= 72  THEN 1 ELSE 0 END) AS conv_within_3_days,
        SUM(CASE WHEN fconv.hours_to_convert <= 168 THEN 1 ELSE 0 END) AS conv_within_7_days,
        AVG(CAST(fconv.hours_to_convert AS FLOAT))                      AS avg_hours_to_convert
    FROM gold.fact_conversions fconv
    LEFT JOIN gold.dim_campaigns cam  ON fconv.campaign_key       = cam.campaign_key AND cam.dwh_is_current = 1
    LEFT JOIN gold.dim_date      dd   ON fconv.conversion_date_key = dd.date_key
    WHERE dd.date_key IS NOT NULL
    GROUP BY
        cam.campaign_id,
        dd.year,
        dd.week_of_year
)
SELECT
    wi.campaign_id,
    wi.campaign_name,
    wi.objective,
    wi.advertiser_industry,
    wi.event_year,
    wi.event_week,
    wi.week_start_date,

    -- Funnel Volume
    wi.impressions,
    ISNULL(wc.clicks, 0)                    AS clicks,
    ISNULL(wconv.conversions, 0)            AS conversions,

    -- Funnel Drop-off Rates
    CAST(
        (wi.impressions - ISNULL(wc.clicks, 0)) * 100.0
        / NULLIF(wi.impressions, 0)
    AS DECIMAL(6,2))                         AS impression_to_click_dropoff_pct,

    CAST(
        (ISNULL(wc.clicks, 0) - ISNULL(wconv.conversions, 0)) * 100.0
        / NULLIF(wc.clicks, 0)
    AS DECIMAL(6,2))                         AS click_to_convert_dropoff_pct,

    -- Conversion Rates
    CAST(
        ISNULL(wc.clicks, 0) * 100.0
        / NULLIF(wi.impressions, 0)
    AS DECIMAL(6,3))                         AS ctr_pct,

    CAST(
        ISNULL(wconv.conversions, 0) * 100.0
        / NULLIF(wc.clicks, 0)
    AS DECIMAL(6,3))                         AS cvr_pct,

    -- Attribution Window Analysis
    ISNULL(wconv.conv_within_1_day, 0)      AS conv_within_1_day,
    ISNULL(wconv.conv_within_3_days, 0)     AS conv_within_3_days,
    ISNULL(wconv.conv_within_7_days, 0)     AS conv_within_7_days,

    CAST(
        ISNULL(wconv.conv_within_1_day, 0) * 100.0
        / NULLIF(wconv.conversions, 0)
    AS DECIMAL(6,2))                         AS pct_converting_within_1_day,

    CAST(ISNULL(wconv.avg_hours_to_convert, 0) AS DECIMAL(10,2)) AS avg_hours_to_convert,

    -- Spend
    wi.spend                                 AS weekly_spend_usd,

    -- Cumulative weekly impressions (running total per campaign)
    SUM(wi.impressions) OVER (
        PARTITION BY wi.campaign_id
        ORDER BY wi.event_year, wi.event_week
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                        AS cumulative_impressions,

    -- 4-week rolling average CTR
    AVG(
        CAST(ISNULL(wc.clicks, 0) * 100.0 / NULLIF(wi.impressions, 0) AS DECIMAL(6,3))
    ) OVER (
        PARTITION BY wi.campaign_id
        ORDER BY wi.event_year, wi.event_week
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    )                                        AS rolling_4wk_avg_ctr

FROM weekly_impressions wi
LEFT JOIN weekly_clicks      wc    ON wi.campaign_id = wc.campaign_id
                                  AND wi.event_year  = wc.event_year
                                  AND wi.event_week  = wc.event_week
LEFT JOIN weekly_conversions wconv ON wi.campaign_id = wconv.campaign_id
                                  AND wi.event_year  = wconv.event_year
                                  AND wi.event_week  = wconv.event_week;
GO
