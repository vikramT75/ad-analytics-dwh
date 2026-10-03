IF OBJECT_ID('analytics.report_campaign_performance', 'V') IS NOT NULL
    DROP VIEW analytics.report_campaign_performance;
GO

CREATE VIEW analytics.report_campaign_performance AS
WITH campaign_impressions AS (
    SELECT
        fi.campaign_key,
        COUNT(DISTINCT fi.impression_id)    AS total_impressions,
        SUM(fi.bid_price)                   AS total_spend,
        SUM(CAST(fi.is_clicked AS INT))     AS clicked_impressions
    FROM gold.fact_impressions fi
    GROUP BY fi.campaign_key
),
campaign_clicks AS (
    SELECT
        fc.campaign_key,
        COUNT(DISTINCT fc.click_id)         AS total_clicks
    FROM gold.fact_clicks fc
    GROUP BY fc.campaign_key
),
campaign_conversions AS (
    SELECT
        fconv.campaign_key,
        COUNT(DISTINCT fconv.install_id)    AS total_conversions,
        AVG(CAST(fconv.hours_to_convert AS FLOAT)) AS avg_hours_to_convert
    FROM gold.fact_conversions fconv
    GROUP BY fconv.campaign_key
)
SELECT
    cam.campaign_key,
    cam.campaign_id,
    cam.campaign_name,
    cam.objective,
    cam.status,
    cam.start_date,
    cam.end_date,
    cam.campaign_duration_days,
    cam.budget_usd,
    cam.advertiser_name,
    cam.advertiser_industry,
    cam.advertiser_country,
    cam.target_geo,

    -- Volume
    ISNULL(ci.total_impressions, 0)         AS total_impressions,
    ISNULL(ck.total_clicks, 0)              AS total_clicks,
    ISNULL(cv.total_conversions, 0)         AS total_conversions,

    -- Efficiency
    CAST(
        ISNULL(ck.total_clicks, 0) * 100.0
        / NULLIF(ci.total_impressions, 0)
    AS DECIMAL(6,3))                         AS ctr_pct,

    CAST(
        ISNULL(cv.total_conversions, 0) * 100.0
        / NULLIF(ck.total_clicks, 0)
    AS DECIMAL(6,3))                         AS cvr_pct,

    CAST(
        ISNULL(cv.total_conversions, 0) * 100.0
        / NULLIF(ci.total_impressions, 0)
    AS DECIMAL(6,4))                         AS view_to_convert_pct,

    -- Spend
    ISNULL(ci.total_spend, 0)               AS total_spend_usd,

    CAST(
        ISNULL(ci.total_spend, 0) * 100.0
        / NULLIF(cam.budget_usd, 0)
    AS DECIMAL(6,2))                         AS budget_utilization_pct,

    -- Cost
    CAST(
        ISNULL(ci.total_spend, 0) * 1000.0
        / NULLIF(ci.total_impressions, 0)
    AS DECIMAL(10,4))                        AS effective_cpm,

    CAST(
        ISNULL(ci.total_spend, 0)
        / NULLIF(ck.total_clicks, 0)
    AS DECIMAL(10,4))                        AS cost_per_click,

    CAST(
        ISNULL(ci.total_spend, 0)
        / NULLIF(cv.total_conversions, 0)
    AS DECIMAL(10,4))                        AS cost_per_conversion,

    -- Attribution
    CAST(ISNULL(cv.avg_hours_to_convert, 0) AS DECIMAL(10,2)) AS avg_hours_to_convert,

    -- Rank
    RANK() OVER (ORDER BY ISNULL(ck.total_clicks, 0) DESC)             AS click_rank,
    RANK() OVER (ORDER BY ISNULL(cv.total_conversions, 0) DESC)        AS conversion_rank,
    RANK() OVER (
        ORDER BY
            CAST(
                ISNULL(ck.total_clicks, 0) * 100.0
                / NULLIF(ci.total_impressions, 0)
            AS DECIMAL(6,3)) DESC
    )                                                                   AS ctr_rank

FROM gold.dim_campaigns cam
LEFT JOIN campaign_impressions ci  ON cam.campaign_key = ci.campaign_key
LEFT JOIN campaign_clicks      ck  ON cam.campaign_key = ck.campaign_key
LEFT JOIN campaign_conversions cv  ON cam.campaign_key = cv.campaign_key
WHERE cam.dwh_is_current = 1;
GO
