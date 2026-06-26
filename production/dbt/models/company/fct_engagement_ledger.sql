{{ config(
    materialized=var('company_fact_materialization', var('company_data_materialization', 'view')),
    schema=var('company_data_schema', 'company_data'),
    tags=['company_data_product', 'fact']
) }}

-- Grain: one row per deterministic engagement event.
-- Primary key: engagement_event_id.

WITH bridge AS (
  SELECT
    source_system,
    source_company_id,
    canonical_company_id,
    requires_manual_review,
    match_confidence
  FROM {{ ref('bridge_company_source') }}
),

hubspot_deals AS (
  SELECT
    {{ newlab_surrogate_key(["'hubspot_deal'", "d.deal_id", "dc.company_id"]) }} AS engagement_event_id,
    b.canonical_company_id,
    b.canonical_company_id IS NULL AS canonical_company_id_is_null,
    dc.company_id AS source_company_id,
    'hubspot' AS source_system,
    'deal' AS engagement_type,
    d.deal_id AS source_engagement_id,
    d.deal_name AS engagement_name,
    d.deal_type AS engagement_subtype,
    CASE
      WHEN d.deal_status IN ('won', 'lost', 'open') THEN d.deal_status
      ELSE 'unknown'
    END AS engagement_status,
    d.deal_status AS engagement_status_raw,
    DATE(COALESCE(d.work_start_date, d.close_date, d.created_at)) AS start_date,
    DATE(d.work_end_date) AS end_date,
    d.deal_amount AS amount,
    CAST(NULL AS STRING) AS member_id,
    CAST(NULL AS STRING) AS membership_id,
    {{ requires_manual_review('b.requires_manual_review') }} AS requires_manual_review,
    b.match_confidence
  FROM {{ source('staging', 'stg_hubspot_deals') }} AS d
  JOIN {{ source('staging', 'stg_hubspot_deal_company') }} AS dc
    ON d.deal_id = dc.deal_id
   AND dc.category = 'HUBSPOT_DEFINED'
   AND dc.type_id = 5
  LEFT JOIN bridge AS b
    ON b.source_system = 'hubspot'
   AND b.source_company_id = dc.company_id
),

officernd_memberships AS (
  SELECT
    {{ newlab_surrogate_key(["'officernd_membership'", "md.membership_id", "md.assignment_id", "md.period_start_date", "md.period_end_date"]) }} AS engagement_event_id,
    b.canonical_company_id,
    b.canonical_company_id IS NULL AS canonical_company_id_is_null,
    md.company_id AS source_company_id,
    'officernd' AS source_system,
    'membership' AS engagement_type,
    md.membership_id AS source_engagement_id,
    md.membership_name AS engagement_name,
    {{ normalize_membership_category('md.membership_category') }} AS engagement_subtype,
    CASE
      WHEN md.membership_status IN ('active', 'expired', 'not_started', 'not_approved') THEN md.membership_status
      WHEN md.period_end_date < CURRENT_DATE() THEN 'expired'
      WHEN md.period_start_date > CURRENT_DATE() THEN 'not_started'
      ELSE COALESCE(md.membership_status, 'unknown')
    END AS engagement_status,
    md.membership_status AS engagement_status_raw,
    md.period_start_date AS start_date,
    md.period_end_date AS end_date,
    COALESCE(md.calculated_list_price, md.discounted_price, md.price) AS amount,
    md.member_id,
    md.membership_id,
    {{ requires_manual_review('b.requires_manual_review') }} AS requires_manual_review,
    b.match_confidence
  FROM {{ source('intermediate', 'int_membership_detail') }} AS md
  LEFT JOIN bridge AS b
    ON b.source_system = 'officernd'
   AND b.source_company_id = md.company_id
),

bigtime_projects AS (
  SELECT
    {{ newlab_surrogate_key(["'bigtime_project'", "p.project_id", "p.client_id"]) }} AS engagement_event_id,
    b.canonical_company_id,
    b.canonical_company_id IS NULL AS canonical_company_id_is_null,
    CAST(p.client_id AS STRING) AS source_company_id,
    'bigtime' AS source_system,
    'project' AS engagement_type,
    CAST(p.project_id AS STRING) AS source_engagement_id,
    p.project_name AS engagement_name,
    NULLIF(p.production_status_name, '') AS engagement_subtype,
    IF(p.is_inactive, 'inactive', 'active') AS engagement_status,
    CAST(p.is_inactive AS STRING) AS engagement_status_raw,
    p.start_date,
    p.end_date,
    p.budget_fees AS amount,
    CAST(NULL AS STRING) AS member_id,
    CAST(NULL AS STRING) AS membership_id,
    {{ requires_manual_review('b.requires_manual_review') }} AS requires_manual_review,
    b.match_confidence
  FROM {{ source('staging', 'stg_bigtime_projects') }} AS p
  LEFT JOIN bridge AS b
    ON b.source_system = 'bigtime'
   AND b.source_company_id = CAST(p.client_id AS STRING)
)

SELECT * FROM hubspot_deals
UNION ALL
SELECT * FROM officernd_memberships
UNION ALL
SELECT * FROM bigtime_projects

