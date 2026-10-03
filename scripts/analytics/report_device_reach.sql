IF OBJECT_ID('analytics.report_device_reach', 'V') IS NOT NULL
    DROP VIEW analytics.report_device_reach;
GO

CREATE VIEW analytics.report_device_reach AS
WITH device_frequency AS (
    -- Calculate impressions per device per campaign
    SELECT
        fi.campaign_key,
        fi.device_key,
        fi.geo_country,
        dev.device_type,
        dev.device_category,
        dev.os_type,
        dev.age_band,
        COUNT(fi.impression_id)             AS impression_count,
        MIN(fi.event_ts)                    AS first_seen_ts,
        MAX(fi.event_ts)                    AS last_seen_ts,
        DATEDIFF(DAY, MIN(fi.event_ts), MAX(fi.event_ts)) AS exposure_span_days,
        MAX(CAST(fi.is_clicked AS INT))     AS ever_clicked
    FROM gold.fact_impressions fi
    LEFT JOIN gold.dim_devices dev ON fi.device_key = dev.device_key
    WHERE fi.device_key IS NOT NULL
    GROUP BY
        fi.campaign_key,
        fi.device_key,
        fi.geo_country,
        dev.device_type,
        dev.device_category,
        dev.os_type,
        dev.age_band
),
campaign_reach_summary AS (
    SELECT
        df.campaign_key,
        df.geo_country,
        df.device_type,
        df.device_category,
        df.os_type,
        df.age_band,

        -- Reach: unique device count
        COUNT(DISTINCT df.device_key)                       AS unique_device_reach,

        -- Gross impressions
        SUM(df.impression_count)                            AS gross_impressions,

        -- Average frequency
        CAST(
            SUM(df.impression_count) * 1.0
            / NULLIF(COUNT(DISTINCT df.device_key), 0)
        AS DECIMAL(8,2))                                    AS avg_frequency,

        -- Frequency buckets (for distribution analysis)
        COUNT(CASE WHEN df.impression_count = 1            THEN 1 END) AS freq_1x,
        COUNT(CASE WHEN df.impression_count BETWEEN 2 AND 3 THEN 1 END) AS freq_2_3x,
        COUNT(CASE WHEN df.impression_count BETWEEN 4 AND 5 THEN 1 END) AS freq_4_5x,
        COUNT(CASE WHEN df.impression_count >= 6            THEN 1 END) AS freq_6plus_x,

        -- Engaged devices (ever clicked)
        SUM(df.ever_clicked)                                AS devices_that_clicked,

        -- Average exposure span
        CAST(AVG(CAST(df.exposure_span_days AS FLOAT)) AS DECIMAL(8,2)) AS avg_exposure_span_days

    FROM device_frequency df
    GROUP BY
        df.campaign_key,
        df.geo_country,
        df.device_type,
        df.device_category,
        df.os_type,
        df.age_band
)
SELECT
    cam.campaign_id,
    cam.campaign_name,
    cam.objective,
    cam.advertiser_name,
    crs.geo_country,
    crs.device_type,
    crs.device_category,
    crs.os_type,
    crs.age_band,

    -- Reach
    crs.unique_device_reach,
    crs.gross_impressions,
    crs.avg_frequency,

    -- Frequency Distribution
    crs.freq_1x,
    crs.freq_2_3x,
    crs.freq_4_5x,
    crs.freq_6plus_x,

    -- Engagement
    crs.devices_that_clicked,
    CAST(
        crs.devices_that_clicked * 100.0
        / NULLIF(crs.unique_device_reach, 0)
    AS DECIMAL(6,3))                         AS device_engagement_rate_pct,

    crs.avg_exposure_span_days,

    -- Saturation flag: > 5 avg frequency = potentially over-served
    CASE WHEN crs.avg_frequency > 5 THEN 1 ELSE 0 END AS is_over_served,

    -- Reach rank by geo (which geos have widest reach per campaign)
    RANK() OVER (
        PARTITION BY crs.campaign_key
        ORDER BY crs.unique_device_reach DESC
    )                                        AS reach_rank_by_geo

FROM campaign_reach_summary crs
LEFT JOIN gold.dim_campaigns cam ON crs.campaign_key = cam.campaign_key AND cam.dwh_is_current = 1;
GO
