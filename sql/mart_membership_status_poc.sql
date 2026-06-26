-- mart_membership_status_poc
--
-- Grain: one row per month / OfficeRnD company / location / membership category / plan.
-- Primary key: month_start, officernd_company_id, location_id, membership_category, plan_id.
--
-- Defaults to current/past months only.
-- To create a future-bookings view later, change the month predicate to:
--   mm.month_start > DATE_TRUNC(CURRENT_DATE(), MONTH)

WITH bridge AS (
  SELECT
    source_company_id,
    canonical_company_id,
    requires_manual_review,
    match_confidence
  FROM `datahub-prod-477220.intermediate.int_cross_source_companies`
  WHERE source_system = 'officernd'
),

membership_months AS (
  SELECT
    mm.month_start,
    b.canonical_company_id,
    b.canonical_company_id IS NULL AS canonical_company_id_is_null,
    mm.company_id AS officernd_company_id,
    mm.location_id,
    mm.location_name,
    mm.location_code,
    COALESCE(mm.membership_category, 'Uncategorized') AS membership_category,
    mm.plan_id,
    mm.plan_name,
    mm.membership_status,
    mm.member_id,
    mm.membership_id,
    mm.calculated_list_price,
    mm.discounted_price,
    mm.price,
    mm.calculated_discount_amount,
    COALESCE(b.requires_manual_review, TRUE) AS requires_manual_review,
    b.match_confidence
  FROM `datahub-prod-477220.intermediate.int_membership_months` AS mm
  LEFT JOIN bridge AS b
    ON b.source_company_id = mm.company_id
  WHERE mm.is_contracted_in_month
    AND mm.month_start <= DATE_TRUNC(CURRENT_DATE(), MONTH)
)

SELECT
  month_start,
  canonical_company_id,
  canonical_company_id_is_null,
  officernd_company_id,
  location_id,
  location_name,
  location_code,
  membership_category,
  plan_id,
  plan_name,
  COUNT(DISTINCT membership_id) AS active_memberships,
  COUNT(DISTINCT member_id) AS active_members,
  SUM(COALESCE(discounted_price, price, 0)) AS total_mrr,
  SUM(COALESCE(calculated_list_price, discounted_price, price, 0)) AS total_calculated_list_price,
  SUM(COALESCE(calculated_discount_amount, 0)) AS total_calculated_discount_amount,
  LOGICAL_OR(requires_manual_review) AS has_manual_review_mapping,
  MIN(match_confidence) AS min_match_confidence,
  ARRAY_AGG(DISTINCT membership_status IGNORE NULLS ORDER BY membership_status LIMIT 10) AS observed_membership_statuses
FROM membership_months
GROUP BY
  month_start,
  canonical_company_id,
  canonical_company_id_is_null,
  officernd_company_id,
  location_id,
  location_name,
  location_code,
  membership_category,
  plan_id,
  plan_name

