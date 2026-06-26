{{ config(
    materialized=var('company_user_mart_materialization', var('company_mart_materialization', var('company_data_materialization', 'view'))),
    schema=var('company_data_schema', 'company_data'),
    tags=['company_data_product', 'mart', 'user_facing']
) }}

-- Model: mart_newlab_companies
-- Purpose: Default user-facing company dataset for Connected Sheets, dashboards, and ad hoc analysis.
--
-- Expected grain:
--   One row per canonical_company_id.
--
-- Primary key:
--   canonical_company_id
--
-- Upstream dependencies:
--   dim_company
--   mart_membership_status
--   fct_engagement_ledger
--
-- Known caveats:
--   This model is anchored on dim_company, so unmatched source companies with null
--   canonical_company_id are intentionally excluded. Use bridge_company_source for
--   mapping audit and remediation workflows.
--
--   Company attributes are representative display fields from dim_company. They
--   should not replace bridge_company_source for source-system joins.
--
--   Current membership metrics use the current calendar month from
--   mart_membership_status. Future bookings are intentionally excluded from the
--   upstream mart_membership_status model.
--
--   Source-reported engagement amounts are directional and mix different source
--   concepts: deal amounts, membership prices, and project budgets. Use
--   type-specific amount fields when the business meaning matters.

WITH dim_company AS (
  SELECT *
  FROM {{ ref('dim_company') }}
),

current_membership AS (
  SELECT
    canonical_company_id,
    TRUE AS has_active_membership,
    ARRAY_AGG(DISTINCT CAST(location_id AS STRING) IGNORE NULLS ORDER BY CAST(location_id AS STRING)) AS current_location_ids,
    ARRAY_AGG(DISTINCT CAST(location_name AS STRING) IGNORE NULLS ORDER BY CAST(location_name AS STRING)) AS current_location_names,
    ARRAY_AGG(DISTINCT CAST(location_code AS STRING) IGNORE NULLS ORDER BY CAST(location_code AS STRING)) AS current_location_codes,
    ARRAY_AGG(DISTINCT CAST(membership_category AS STRING) IGNORE NULLS ORDER BY CAST(membership_category AS STRING)) AS current_membership_categories,
    ARRAY_AGG(DISTINCT CAST(plan_id AS STRING) IGNORE NULLS ORDER BY CAST(plan_id AS STRING) LIMIT 25) AS current_plan_ids,
    ARRAY_AGG(DISTINCT CAST(plan_name AS STRING) IGNORE NULLS ORDER BY CAST(plan_name AS STRING) LIMIT 25) AS current_plan_names,
    SUM(active_memberships) AS current_active_memberships,
    SUM(active_members) AS current_active_members,
    SUM(total_mrr) AS current_total_mrr,
    SUM(total_calculated_list_price) AS current_total_calculated_list_price,
    SUM(total_calculated_discount_amount) AS current_total_calculated_discount_amount,
    LOGICAL_OR(has_manual_review_mapping) AS has_current_membership_manual_review_mapping,
    MIN(min_match_confidence) AS current_membership_min_match_confidence
  FROM {{ ref('mart_membership_status') }}
  WHERE canonical_company_id IS NOT NULL
    AND month_start = DATE_TRUNC(CURRENT_DATE(), MONTH)
    AND month_start <= DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY canonical_company_id
),

membership_history AS (
  SELECT
    canonical_company_id,
    MIN(month_start) AS first_membership_month,
    MAX(month_start) AS most_recent_membership_month,
    COUNT(DISTINCT month_start) AS membership_month_count,
    COUNT(DISTINCT officernd_company_id) AS membership_officernd_company_count,
    COUNT(DISTINCT location_id) AS membership_location_count,
    ARRAY_AGG(DISTINCT CAST(membership_category AS STRING) IGNORE NULLS ORDER BY CAST(membership_category AS STRING)) AS all_membership_categories,
    SUM(active_memberships) AS membership_month_active_membership_sum,
    SUM(active_members) AS membership_month_active_member_sum,
    SUM(total_mrr) AS membership_month_total_mrr,
    LOGICAL_OR(has_manual_review_mapping) AS has_membership_manual_review_mapping,
    MIN(min_match_confidence) AS membership_min_match_confidence
  FROM {{ ref('mart_membership_status') }}
  WHERE canonical_company_id IS NOT NULL
    AND month_start <= DATE_TRUNC(CURRENT_DATE(), MONTH)
  GROUP BY canonical_company_id
),

engagement_summary AS (
  SELECT
    canonical_company_id,
    MIN(start_date) AS first_engagement_date,
    MAX(COALESCE(end_date, start_date)) AS most_recent_engagement_date,
    COUNT(*) AS total_engagement_count,
    COUNTIF(engagement_type = 'deal') AS deal_engagement_count,
    COUNTIF(engagement_type = 'membership') AS membership_engagement_count,
    COUNTIF(engagement_type = 'project') AS project_engagement_count,
    COUNTIF(source_system = 'hubspot') AS hubspot_engagement_count,
    COUNTIF(source_system = 'officernd') AS officernd_engagement_count,
    COUNTIF(source_system = 'bigtime') AS bigtime_engagement_count,
    COUNT(DISTINCT source_system) AS engagement_source_system_count,
    ARRAY_AGG(DISTINCT source_system IGNORE NULLS ORDER BY source_system) AS engagement_source_systems,
    ARRAY_AGG(DISTINCT engagement_type IGNORE NULLS ORDER BY engagement_type) AS engagement_types,
    ARRAY_AGG(DISTINCT engagement_category IGNORE NULLS ORDER BY engagement_category) AS engagement_categories,
    -- TODO: Add structured Program, Technical, and Strategic categories when
    -- source data for showcases, demo days, accelerators, office hours, grants,
    -- pilots, technical assistance, investments, and partnerships is modeled in
    -- fct_engagement_ledger.
    ARRAY_AGG(
      STRUCT(
        CAST(engagement_category AS STRING) AS engagement_category,
        CAST(engagement_type AS STRING) AS engagement_type,
        CAST(engagement_name AS STRING) AS engagement_name,
        CAST(engagement_status AS STRING) AS engagement_status,
        start_date,
        end_date,
        CAST(source_system AS STRING) AS source_system
      )
      ORDER BY start_date DESC
      LIMIT 20
    ) AS engagement_timeline,
    -- TODO: Add partner_name/program_name to these structs once structured
    -- partner, program, or HubSpot project/deal association fields are modeled
    -- in fct_engagement_ledger.
    ARRAY_AGG(
      STRUCT(
        CAST(engagement_type AS STRING) AS engagement_type,
        CAST(engagement_name AS STRING) AS engagement_name,
        CAST(engagement_status AS STRING) AS engagement_status,
        start_date,
        end_date,
        CAST(source_system AS STRING) AS source_system
      )
      ORDER BY start_date DESC
      LIMIT 10
    ) AS recent_engagements,
    ARRAY_AGG(
      IF(
        engagement_type = 'project',
        STRUCT(
          CAST(engagement_name AS STRING) AS engagement_name,
          CAST(engagement_status AS STRING) AS engagement_status,
          start_date,
          end_date,
          CAST(source_system AS STRING) AS source_system
        ),
        NULL
      )
      IGNORE NULLS
      ORDER BY IF(engagement_type = 'project', start_date, NULL) DESC
      LIMIT 10
    ) AS project_engagements,
    ARRAY_AGG(
      IF(
        engagement_type = 'deal',
        STRUCT(
          CAST(engagement_name AS STRING) AS engagement_name,
          CAST(engagement_status AS STRING) AS engagement_status,
          start_date,
          end_date,
          CAST(source_system AS STRING) AS source_system
        ),
        NULL
      )
      IGNORE NULLS
      ORDER BY IF(engagement_type = 'deal', start_date, NULL) DESC
      LIMIT 10
    ) AS deal_engagements,
    ARRAY_AGG(
      IF(
        engagement_type = 'membership',
        STRUCT(
          CAST(engagement_name AS STRING) AS engagement_name,
          CAST(engagement_status AS STRING) AS engagement_status,
          start_date,
          end_date,
          CAST(source_system AS STRING) AS source_system
        ),
        NULL
      )
      IGNORE NULLS
      ORDER BY IF(engagement_type = 'membership', start_date, NULL) DESC
      LIMIT 10
    ) AS membership_engagements,
    -- TODO: Add high/medium/low impact engagement rollups once an engagement
    -- taxonomy or importance tier is modeled in fct_engagement_ledger.
    SUM(COALESCE(amount, 0)) AS total_source_reported_engagement_amount,
    SUM(IF(engagement_type = 'deal', COALESCE(amount, 0), 0)) AS deal_amount,
    SUM(IF(engagement_type = 'membership', COALESCE(amount, 0), 0)) AS membership_amount,
    SUM(IF(engagement_type = 'project', COALESCE(amount, 0), 0)) AS project_amount,
    LOGICAL_OR(requires_manual_review) AS has_engagement_manual_review_mapping,
    MIN(match_confidence) AS engagement_min_match_confidence
  FROM {{ ref('fct_engagement_ledger') }}
  WHERE canonical_company_id IS NOT NULL
  GROUP BY canonical_company_id
)

SELECT
  d.canonical_company_id,

  -- Canonical company identity and display attributes.
  d.company_name,
  d.company_name_source,
  d.company_domain,
  d.hubspot_industry,
  d.hubspot_city,
  d.hubspot_country,
  d.employee_count,
  d.annual_revenue,
  d.officernd_company_email,
  d.officernd_company_url,
  d.officernd_company_status,
  d.officernd_company_type,
  d.officernd_company_tier,
  d.officernd_location_id,
  d.bigtime_client_legal_name,
  d.bigtime_client_code,
  d.bigtime_client_type,
  d.bigtime_city,
  d.bigtime_state,
  d.bigtime_country,

  -- Source-system coverage.
  d.hubspot_company_ids,
  d.officernd_company_ids,
  d.bigtime_client_ids,
  d.source_system_count,
  d.source_system_count > 1 AS is_multi_source_company,

  -- Mapping quality.
  d.has_manual_review_mapping AS has_identity_manual_review_mapping,
  d.min_match_confidence AS identity_min_match_confidence,
  (
    SELECT MIN(confidence)
    FROM UNNEST([
      d.min_match_confidence,
      mh.membership_min_match_confidence,
      e.engagement_min_match_confidence
    ]) AS confidence
    WHERE confidence IS NOT NULL
  ) AS min_match_confidence,
  COALESCE(d.has_manual_review_mapping, FALSE)
    OR COALESCE(cm.has_current_membership_manual_review_mapping, FALSE)
    OR COALESCE(mh.has_membership_manual_review_mapping, FALSE)
    OR COALESCE(e.has_engagement_manual_review_mapping, FALSE) AS has_any_manual_review_mapping,

  -- Current membership status.
  CASE
    WHEN COALESCE(cm.current_active_memberships, 0) > 0 THEN 'active_member'
    WHEN mh.canonical_company_id IS NOT NULL THEN 'former_member'
    ELSE 'no_membership_record'
  END AS membership_status,
  COALESCE(cm.has_active_membership, FALSE) AS has_active_membership,
  COALESCE(cm.current_location_ids, ARRAY<STRING>[]) AS current_location_ids,
  COALESCE(cm.current_location_names, ARRAY<STRING>[]) AS current_location_names,
  COALESCE(cm.current_location_codes, ARRAY<STRING>[]) AS current_location_codes,
  COALESCE(cm.current_membership_categories, ARRAY<STRING>[]) AS current_membership_categories,
  COALESCE(cm.current_plan_ids, ARRAY<STRING>[]) AS current_plan_ids,
  COALESCE(cm.current_plan_names, ARRAY<STRING>[]) AS current_plan_names,
  COALESCE(cm.current_active_memberships, 0) AS current_active_memberships,
  COALESCE(cm.current_active_members, 0) AS current_active_members,
  COALESCE(cm.current_total_mrr, 0) AS current_total_mrr,
  COALESCE(cm.current_total_calculated_list_price, 0) AS current_total_calculated_list_price,
  COALESCE(cm.current_total_calculated_discount_amount, 0) AS current_total_calculated_discount_amount,

  -- Historical membership summary.
  mh.first_membership_month,
  mh.most_recent_membership_month,
  COALESCE(mh.membership_month_count, 0) AS membership_month_count,
  COALESCE(mh.membership_officernd_company_count, 0) AS membership_officernd_company_count,
  COALESCE(mh.membership_location_count, 0) AS membership_location_count,
  COALESCE(mh.all_membership_categories, ARRAY<STRING>[]) AS all_membership_categories,
  COALESCE(mh.membership_month_active_membership_sum, 0) AS membership_month_active_membership_sum,
  COALESCE(mh.membership_month_active_member_sum, 0) AS membership_month_active_member_sum,
  COALESCE(mh.membership_month_total_mrr, 0) AS membership_month_total_mrr,

  -- Engagement summary.
  e.first_engagement_date,
  e.most_recent_engagement_date,
  COALESCE(e.total_engagement_count, 0) AS total_engagement_count,
  COALESCE(e.deal_engagement_count, 0) AS deal_engagement_count,
  COALESCE(e.membership_engagement_count, 0) AS membership_engagement_count,
  COALESCE(e.project_engagement_count, 0) AS project_engagement_count,
  COALESCE(e.hubspot_engagement_count, 0) AS hubspot_engagement_count,
  COALESCE(e.officernd_engagement_count, 0) AS officernd_engagement_count,
  COALESCE(e.bigtime_engagement_count, 0) AS bigtime_engagement_count,
  COALESCE(e.engagement_source_system_count, 0) AS engagement_source_system_count,
  COALESCE(e.engagement_source_systems, ARRAY<STRING>[]) AS engagement_source_systems,
  COALESCE(e.engagement_types, ARRAY<STRING>[]) AS engagement_types,
  COALESCE(e.engagement_categories, ARRAY<STRING>[]) AS engagement_categories,
  COALESCE(
    e.engagement_timeline,
    ARRAY<STRUCT<
      engagement_category STRING,
      engagement_type STRING,
      engagement_name STRING,
      engagement_status STRING,
      start_date DATE,
      end_date DATE,
      source_system STRING
    >>[]
  ) AS engagement_timeline,
  COALESCE(
    e.recent_engagements,
    ARRAY<STRUCT<
      engagement_type STRING,
      engagement_name STRING,
      engagement_status STRING,
      start_date DATE,
      end_date DATE,
      source_system STRING
    >>[]
  ) AS recent_engagements,
  COALESCE(
    e.project_engagements,
    ARRAY<STRUCT<
      engagement_name STRING,
      engagement_status STRING,
      start_date DATE,
      end_date DATE,
      source_system STRING
    >>[]
  ) AS project_engagements,
  COALESCE(
    e.deal_engagements,
    ARRAY<STRUCT<
      engagement_name STRING,
      engagement_status STRING,
      start_date DATE,
      end_date DATE,
      source_system STRING
    >>[]
  ) AS deal_engagements,
  COALESCE(
    e.membership_engagements,
    ARRAY<STRUCT<
      engagement_name STRING,
      engagement_status STRING,
      start_date DATE,
      end_date DATE,
      source_system STRING
    >>[]
  ) AS membership_engagements,
  COALESCE(e.total_engagement_count, 0) > 0 AS has_engagement,
  COALESCE(e.deal_engagement_count, 0) > 0 AS has_deal_engagement,
  COALESCE(e.membership_engagement_count, 0) > 0 AS has_membership_engagement,
  COALESCE(e.project_engagement_count, 0) > 0 AS has_project_engagement,
  COALESCE(e.total_source_reported_engagement_amount, 0) AS total_source_reported_engagement_amount,
  COALESCE(e.deal_amount, 0) AS deal_amount,
  COALESCE(e.membership_amount, 0) AS membership_amount,
  COALESCE(e.project_amount, 0) AS project_amount
FROM dim_company AS d
LEFT JOIN current_membership AS cm
  ON d.canonical_company_id = cm.canonical_company_id
LEFT JOIN membership_history AS mh
  ON d.canonical_company_id = mh.canonical_company_id
LEFT JOIN engagement_summary AS e
  ON d.canonical_company_id = e.canonical_company_id
