-- dim_company_poc
--
-- Grain: one row per non-null canonical_company_id.
-- Primary key: canonical_company_id.
--
-- Representative source records are for display/convenience only:
-- - HubSpot first for name/domain/industry.
-- - OfficeRnD prefers active company_status, then latest modified_at.
-- - BigTime prefers non-deleted/current client rows, then deterministic name/id ordering.
--
-- Do not use this model as the source of truth for source mappings.
-- Use bridge_company_source_poc for mapping truth.

WITH bridge AS (
  SELECT *
  FROM `datahub-prod-477220.intermediate.int_cross_source_companies`
  WHERE canonical_company_id IS NOT NULL
),

source_rollup AS (
  SELECT
    canonical_company_id,
    ARRAY_AGG(
      IF(source_system = 'hubspot', source_company_id, NULL)
      IGNORE NULLS
      ORDER BY source_company_id
    ) AS hubspot_company_ids,
    ARRAY_AGG(
      IF(source_system = 'officernd', source_company_id, NULL)
      IGNORE NULLS
      ORDER BY source_company_id
    ) AS officernd_company_ids,
    ARRAY_AGG(
      IF(source_system = 'bigtime', source_company_id, NULL)
      IGNORE NULLS
      ORDER BY source_company_id
    ) AS bigtime_client_ids,
    COUNT(DISTINCT source_system) AS source_system_count,
    LOGICAL_OR(COALESCE(requires_manual_review, FALSE)) AS has_manual_review_mapping,
    MIN(match_confidence) AS min_match_confidence
  FROM bridge
  GROUP BY canonical_company_id
),

hubspot_representative AS (
  SELECT
    b.canonical_company_id,
    ARRAY_AGG(
      STRUCT(
        CAST(h.company_id AS STRING) AS source_company_id,
        NULLIF(h.company_name, '') AS company_name,
        NULLIF(h.company_domain, '') AS company_domain,
        NULLIF(h.industry, '') AS industry,
        NULLIF(h.property_city, '') AS city,
        NULLIF(h.property_country, '') AS country,
        h.employee_count,
        h.annual_revenue,
        h.created_at,
        h.updated_at
      )
      ORDER BY
        IF(NULLIF(h.company_name, '') IS NULL, 1, 0),
        h.updated_at DESC,
        CAST(h.company_id AS STRING)
      LIMIT 1
    )[SAFE_OFFSET(0)] AS h
  FROM bridge AS b
  JOIN `datahub-prod-477220.staging.stg_hubspot_companies` AS h
    ON b.source_system = 'hubspot'
   AND b.source_company_id = CAST(h.company_id AS STRING)
  GROUP BY b.canonical_company_id
),

officernd_representative AS (
  SELECT
    b.canonical_company_id,
    ARRAY_AGG(
      STRUCT(
        o.company_id AS source_company_id,
        NULLIF(o.company_name, '') AS company_name,
        NULLIF(o.company_email, '') AS company_email,
        NULLIF(o.company_url, '') AS company_url,
        NULLIF(o.company_status, '') AS company_status,
        NULLIF(o.company_type, '') AS company_type,
        NULLIF(o.company_tier, '') AS company_tier,
        o.location_id,
        o.start_date,
        o.modified_at
      )
      ORDER BY
        IF(o.company_status = 'active', 0, 1),
        o.modified_at DESC,
        LOWER(o.company_name),
        o.company_id
      LIMIT 1
    )[SAFE_OFFSET(0)] AS o
  FROM bridge AS b
  JOIN `datahub-prod-477220.staging.stg_officernd_companies` AS o
    ON b.source_system = 'officernd'
   AND b.source_company_id = o.company_id
  GROUP BY b.canonical_company_id
),

bigtime_representative AS (
  SELECT
    b.canonical_company_id,
    ARRAY_AGG(
      STRUCT(
        CAST(bt.client_id AS STRING) AS source_company_id,
        NULLIF(bt.client_name, '') AS client_name,
        NULLIF(bt.client_legal_name, '') AS client_legal_name,
        NULLIF(bt.client_code, '') AS client_code,
        NULLIF(bt.client_type, '') AS client_type,
        NULLIF(bt.city, '') AS city,
        NULLIF(bt.state, '') AS state,
        NULLIF(bt.country, '') AS country,
        bt.is_deleted
      )
      ORDER BY
        IF(COALESCE(bt.is_deleted, FALSE), 1, 0),
        IF(NULLIF(bt.client_name, '') IS NULL, 1, 0),
        LOWER(bt.client_name),
        CAST(bt.client_id AS STRING)
      LIMIT 1
    )[SAFE_OFFSET(0)] AS bt
  FROM bridge AS b
  JOIN `datahub-prod-477220.staging.stg_bigtime_clients` AS bt
    ON b.source_system = 'bigtime'
   AND b.source_company_id = CAST(bt.client_id AS STRING)
  GROUP BY b.canonical_company_id
)

SELECT
  r.canonical_company_id,
  COALESCE(h.h.company_name, o.o.company_name, bt.bt.client_name) AS company_name,
  CASE
    WHEN h.h.company_name IS NOT NULL THEN 'hubspot'
    WHEN o.o.company_name IS NOT NULL THEN 'officernd'
    WHEN bt.bt.client_name IS NOT NULL THEN 'bigtime'
  END AS company_name_source,
  h.h.company_domain,
  h.h.industry AS hubspot_industry,
  h.h.city AS hubspot_city,
  h.h.country AS hubspot_country,
  h.h.employee_count,
  h.h.annual_revenue,
  o.o.company_email AS officernd_company_email,
  o.o.company_url AS officernd_company_url,
  o.o.company_status AS officernd_company_status,
  o.o.company_type AS officernd_company_type,
  o.o.company_tier AS officernd_company_tier,
  o.o.location_id AS officernd_location_id,
  bt.bt.client_legal_name AS bigtime_client_legal_name,
  bt.bt.client_code AS bigtime_client_code,
  bt.bt.client_type AS bigtime_client_type,
  bt.bt.city AS bigtime_city,
  bt.bt.state AS bigtime_state,
  bt.bt.country AS bigtime_country,
  r.hubspot_company_ids,
  r.officernd_company_ids,
  r.bigtime_client_ids,
  r.source_system_count,
  r.has_manual_review_mapping,
  r.min_match_confidence
FROM source_rollup AS r
LEFT JOIN hubspot_representative AS h
  ON r.canonical_company_id = h.canonical_company_id
LEFT JOIN officernd_representative AS o
  ON r.canonical_company_id = o.canonical_company_id
LEFT JOIN bigtime_representative AS bt
  ON r.canonical_company_id = bt.canonical_company_id

