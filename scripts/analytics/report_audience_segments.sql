/*
===============================================================================
Analytics Report: Audience Segments
===============================================================================
Script Purpose:
    Breaks down impression, click, and conversion performance by audience
    segment dimensions: device type, OS, age band, and geography.

    This mirrors the kind of audience intelligence Mobilewalla specializes in
    -- understanding WHICH audiences drive performance for advertisers.

Usage:
    Query this view to answer:
    - "Which device type has the highest CTR?"
    - "Which age band converts best for Performance campaigns?"
    - "How does mobile vs CTV performance compare?"

Output Grain: One row per unique segment combination.
===============================================================================
*/

IF OBJECT_ID('analytics.report_audience_segments', 'V') IS NOT NULL
    DROP VIEW analytics.report_audience_segments;
GO

CREATE VIEW analytics.report_audience_segments AS
WITH base AS (
    SELECT
        dev.device_type,
        dev.device_category,
        dev.os_type,
        dev.age_band,
        dev.country             AS device_country,
        fi.geo_country          AS impression_country,
        fi.placement_type,
        fi.impression_id,
        fi.bid_price,
        fi.is_clicked,
        fi.campaign_key
    FROM gold.fact_impressions fi
    LEFT JOIN gold.dim_devices dev ON fi.device_key = dev.device_key
),
clicks_by_segment AS (
    SELECT
        dev.device_type,
        dev.device_category,
        dev.os_type,
        dev.age_band,
        dev.country             AS device_country,
        COUNT(DISTINCT fc.click_id) AS clicks
    FROM gold.fact_clicks fc
    LEFT JOIN gold.dim_devices dev ON fc.device_key = dev.device_key
    GROUP BY
        dev.device_type,
        dev.device_category,
        dev.os_type,
        dev.age_band,
        dev.country
),
conversions_by_segment AS (
    SELECT
        dev.device_type,
        dev.device_category,
        dev.os_type,
        dev.age_band,
        dev.country             AS device_country,
        COUNT(DISTINCT fconv.install_id) AS conversions
    FROM gold.fact_conversions fconv
    LEFT JOIN gold.dim_devices dev ON fconv.device_key = dev.device_key
    GROUP BY
        dev.device_type,
        dev.device_category,
        dev.os_type,
        dev.age_band,
        dev.country
),
impression_agg AS (
    SELECT
        device_type,
        device_category,
        os_type,
        age_band,
        device_country,
        COUNT(DISTINCT impression_id)       AS total_impressions,
        COUNT(DISTINCT CASE WHEN is_clicked = 1 THEN impression_id END) AS clicked_impressions,
        SUM(bid_price)                      AS total_spend,
        COUNT(DISTINCT campaign_key)        AS campaigns_reached
    FROM base
    GROUP BY
        device_type,
        device_category,
        os_type,
        age_band,
        device_country
)
SELECT
    ia.device_type,
    ia.device_category,
    ia.os_type,
    ia.age_band,
    ia.device_country,

    -- Reach & Volume
    ia.total_impressions,
    ia.campaigns_reached,

    -- Performance
    ISNULL(cs.clicks, 0)                    AS total_clicks,
    ISNULL(conv.conversions, 0)             AS total_conversions,

    CAST(
        ISNULL(cs.clicks, 0) * 100.0
        / NULLIF(ia.total_impressions, 0)
    AS DECIMAL(6,3))                         AS ctr_pct,

    CAST(
        ISNULL(conv.conversions, 0) * 100.0
        / NULLIF(cs.clicks, 0)
    AS DECIMAL(6,3))                         AS cvr_pct,

    ia.total_spend                           AS total_spend_usd,

    CAST(
        ia.total_spend * 1000.0
        / NULLIF(ia.total_impressions, 0)
    AS DECIMAL(10,4))                        AS effective_cpm,

    -- Segment ranking (for finding best-performing audiences)
    RANK() OVER (
        PARTITION BY ia.device_type
        ORDER BY ISNULL(cs.clicks, 0) * 100.0 / NULLIF(ia.total_impressions, 0) DESC
    )                                        AS ctr_rank_within_device_type,

    RANK() OVER (
        ORDER BY ISNULL(conv.conversions, 0) DESC
    )                                        AS conversion_rank_overall

FROM impression_agg ia
LEFT JOIN clicks_by_segment cs
    ON  ia.device_type     = cs.device_type
    AND ia.device_category = cs.device_category
    AND ia.os_type         = cs.os_type
    AND ia.age_band        = cs.age_band
    AND ia.device_country  = cs.device_country
LEFT JOIN conversions_by_segment conv
    ON  ia.device_type     = conv.device_type
    AND ia.device_category = conv.device_category
    AND ia.os_type         = conv.os_type
    AND ia.age_band        = conv.age_band
    AND ia.device_country  = conv.device_country;
GO
