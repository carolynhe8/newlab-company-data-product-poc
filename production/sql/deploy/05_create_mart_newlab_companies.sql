-- Deployment step 05: mart_newlab_companies.
--
-- Creates or replaces the default user-facing Company Data Product mart.
-- Dependency order: run after bridge_company_source, dim_company,
-- fct_engagement_ledger, and mart_membership_status.

DECLARE target_project STRING DEFAULT 'datahub-prod-477220';
DECLARE target_dataset STRING DEFAULT 'company_data'; -- TODO: replace with approved production dataset.

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.mart_newlab_companies`
OPTIONS(
  description = 'Default user-facing company mart. One row per canonical company ID.'
)
AS
WITH dim_company AS (
  SELECT *
  FROM `%s.%s.dim_company`
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
  FROM `%s.%s.mart_membership_status`
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
  FROM `%s.%s.mart_membership_status`
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
    SUM(COALESCE(amount, 0)) AS total_source_reported_engagement_amount,
    SUM(IF(engagement_type = 'deal', COALESCE(amount, 0), 0)) AS deal_amount,
    SUM(IF(engagement_type = 'membership', COALESCE(amount, 0), 0)) AS membership_amount,
    SUM(IF(engagement_type = 'project', COALESCE(amount, 0), 0)) AS project_amount,
    LOGICAL_OR(requires_manual_review) AS has_engagement_manual_review_mapping,
    MIN(match_confidence) AS engagement_min_match_confidence
  FROM `%s.%s.fct_engagement_ledger`
  WHERE canonical_company_id IS NOT NULL
  GROUP BY canonical_company_id
)

SELECT
  d.canonical_company_id,
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
  d.hubspot_company_ids,
  d.officernd_company_ids,
  d.bigtime_client_ids,
  d.source_system_count,
  d.source_system_count > 1 AS is_multi_source_company,
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
  mh.first_membership_month,
  mh.most_recent_membership_month,
  COALESCE(mh.membership_month_count, 0) AS membership_month_count,
  COALESCE(mh.membership_officernd_company_count, 0) AS membership_officernd_company_count,
  COALESCE(mh.membership_location_count, 0) AS membership_location_count,
  COALESCE(mh.all_membership_categories, ARRAY<STRING>[]) AS all_membership_categories,
  COALESCE(mh.membership_month_active_membership_sum, 0) AS membership_month_active_membership_sum,
  COALESCE(mh.membership_month_active_member_sum, 0) AS membership_month_active_member_sum,
  COALESCE(mh.membership_month_total_mrr, 0) AS membership_month_total_mrr,
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
""", target_project, target_dataset, target_project, target_dataset, target_project, target_dataset, target_project, target_dataset, target_project, target_dataset);
