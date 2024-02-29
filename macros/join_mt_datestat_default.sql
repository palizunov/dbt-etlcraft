{%- macro join_mt_datestat_default(
    sourcetype_name,
    pipeline_name,
    template_name,
    stream_name,
    relations_dict,
    date_from,
    date_to,
    params
    ) -%}

WITH banners_statistics AS (
SELECT * FROM {{ ref('incremental_mt_datestat_default_banners_statistics') }}
{%- if date_from and date_to %} 
WHERE toDate(__date) BETWEEN '{{date_from}}' AND '{{date_to}}'
{%- endif -%}
),

banners AS (
SELECT * FROM {{ ref('incremental_mt_datestat_default_banners') }}
),

campaigns AS (
SELECT * FROM {{ ref('incremental_mt_datestat_default_campaigns') }}
)

SELECT 
    toDate(banners_statistics.__date) AS __date,
    toLowCardinality('*') AS reportType,  
    toLowCardinality(splitByChar('_', banners_statistics.__table_name)[6]) AS accountName,
    toLowCardinality(banners_statistics.__table_name) AS __table_name,
    'MyTarget' AS adSourceDirty,
    '' AS productName,
    campaigns.name AS adCampaignName,
    '' AS adGroupName,
    banners.id AS adId,
    '' AS adPhraseId,
    extract(JSON_VALUE(replaceAll(banners.urls, '''', '"'), '$.primary.url'), 'utm_source=([^&]*)') AS utmSource,
    extract(JSON_VALUE(replaceAll(banners.urls, '''', '"'), '$.primary.url'), 'utm_medium=([^&]*)') AS utmMedium,
    extract(JSON_VALUE(replaceAll(banners.urls, '''', '"'), '$.primary.url'), 'utm_campaign=([^&]*)') AS utmCampaign,
    extract(JSON_VALUE(replaceAll(banners.urls, '''', '"'), '$.primary.url'), 'utm_term=([^&]*)') AS utmTerm,
    extract(JSON_VALUE(replaceAll(banners.urls, '''', '"'), '$.primary.url'), 'utm_content=([^&]*)') AS utmContent,
    {{ etlcraft.get_utmhash('__') }} AS utmHash,
    JSON_VALUE(replaceAll(banners.textblocks, '''', '"'), '$.title_25.text') AS adTitle1,
    '' AS adTitle2,
    assumeNotNull(coalesce(nullif(JSON_VALUE(replaceAll(banners.textblocks, '''', '"'), '$.text_90.text'), ''),
    JSON_VALUE(replaceAll(banners.textblocks, '''', '"'), '$.text_220.text'), '')) AS adText,
    '' AS adPhraseName,
    toFloat64(JSONExtractString(banners_statistics.base, 'spent'))* 1.2 AS adCost,
    toInt32(JSONExtractString(banners_statistics.base, 'shows')) AS impressions,
    toInt32(JSONExtractString(banners_statistics.base, 'clicks')) AS clicks,
    banners_statistics.__emitted_at AS __emitted_at
FROM banners_statistics
JOIN banners ON banners_statistics.banner_id = banners.id 
JOIN campaigns ON banners.campaign_id = campaigns.id



{% endmacro %}