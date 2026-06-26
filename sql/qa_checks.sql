-- Read-only QA checks for the Newlab company data product POC.
--
-- This file is intentionally a set of standalone SELECT statements.
-- Run one section at a time before creating scratch views or dbt models.

-- 1. Duplicate source mappings.
SELECT
  source_system,
  source_company_id,
  COUNT(*) AS row_count
FROM `datahub-prod-477220.intermediate.int_cross_source_companies`
GROUP BY source_system, source_company_id
HAVING COUNT(*) > 1
ORDER BY row_count DESC, source_system, source_company_id
LIMIT 100;

-- 2. Canonical/source groups with multiple source IDs.
SELECT
  canonical_company_id,
  source_system,
  COUNT(DISTINCT source_company_id) AS source_company_id_count,
  ARRAY_AGG(DISTINCT source_company_id ORDER BY source_company_id LIMIT 20) AS sample_source_company_ids,
  COUNTIF(requires_manual_review) AS manual_review_rows,
  MIN(match_confidence) AS min_match_confidence
FROM `datahub-prod-477220.intermediate.int_cross_source_companies`
GROUP BY canonical_company_id, source_system
HAVING COUNT(DISTINCT source_company_id) > 1
ORDER BY source_company_id_count DESC, canonical_company_id
LIMIT 100;

-- 3. Engagement ledger row counts and null canonical rates.
WITH bridge AS (
  SELECT source_system, source_company_id, canonical_company_id, requires_manual_review
  FROM `datahub-prod-477220.intermediate.int_cross_source_companies`
),
ledger_source_companies AS (
  SELECT
    'hubspot' AS source_system,
    dc.company_id AS source_company_id,
    COUNT(*) AS row_count
  FROM `datahub-prod-477220.staging.stg_hubspot_deals` AS d
  JOIN `datahub-prod-477220.staging.stg_hubspot_deal_company` AS dc
    ON d.deal_id = dc.deal_id
   AND dc.category = 'HUBSPOT_DEFINED'
   AND dc.type_id = 5
  GROUP BY 1, 2

  UNION ALL

  SELECT
    'officernd' AS source_system,
    md.company_id AS source_company_id,
    COUNT(*) AS row_count
  FROM `datahub-prod-477220.intermediate.int_membership_detail` AS md
  GROUP BY 1, 2

  UNION ALL

  SELECT
    'bigtime' AS source_system,
    CAST(p.client_id AS STRING) AS source_company_id,
    COUNT(*) AS row_count
  FROM `datahub-prod-477220.staging.stg_bigtime_projects` AS p
  GROUP BY 1, 2
)
SELECT
  l.source_system,
  SUM(l.row_count) AS row_count,
  SUM(IF(b.canonical_company_id IS NULL, l.row_count, 0)) AS null_canonical_rows,
  SAFE_DIVIDE(SUM(IF(b.canonical_company_id IS NULL, l.row_count, 0)), SUM(l.row_count)) AS null_canonical_rate,
  SUM(IF(COALESCE(b.requires_manual_review, TRUE), l.row_count, 0)) AS manual_review_rows
FROM ledger_source_companies AS l
LEFT JOIN bridge AS b
  ON b.source_system = l.source_system
 AND b.source_company_id = l.source_company_id
GROUP BY l.source_system
ORDER BY row_count DESC;

-- 4. Membership status reconciliation to marts.mart_membership_detail.
WITH membership_months AS (
  SELECT
    mm.month_start,
    mm.company_id,
    mm.location_id,
    COALESCE(mm.membership_category, 'Uncategorized') AS membership_category,
    mm.plan_id,
    mm.member_id,
    mm.membership_id,
    mm.calculated_list_price,
    mm.discounted_price,
    mm.price,
    mm.calculated_discount_amount
  FROM `datahub-prod-477220.intermediate.int_membership_months` AS mm
  WHERE mm.is_contracted_in_month
    AND mm.month_start <= DATE_TRUNC(CURRENT_DATE(), MONTH)
),
poc AS (
  SELECT
    month_start,
    company_id,
    location_id,
    membership_category,
    plan_id,
    COUNT(DISTINCT membership_id) AS active_memberships,
    COUNT(DISTINCT member_id) AS active_members,
    SUM(COALESCE(discounted_price, price, 0)) AS total_mrr,
    SUM(COALESCE(calculated_list_price, discounted_price, price, 0)) AS total_calculated_list_price,
    SUM(COALESCE(calculated_discount_amount, 0)) AS total_calculated_discount_amount
  FROM membership_months
  GROUP BY month_start, company_id, location_id, membership_category, plan_id
),
mart AS (
  SELECT
    month_start,
    company_id,
    location_id,
    membership_category,
    plan_id,
    active_memberships,
    active_members,
    total_mrr,
    total_calculated_list_price,
    total_calculated_discount_amount
  FROM `datahub-prod-477220.marts.mart_membership_detail`
  WHERE month_start <= DATE_TRUNC(CURRENT_DATE(), MONTH)
),
recon AS (
  SELECT
    COALESCE(p.month_start, m.month_start) AS month_start,
    p.active_memberships AS poc_active_memberships,
    m.active_memberships AS mart_active_memberships,
    p.active_members AS poc_active_members,
    m.active_members AS mart_active_members,
    p.total_mrr AS poc_total_mrr,
    m.total_mrr AS mart_total_mrr,
    p.total_calculated_list_price AS poc_total_calculated_list_price,
    m.total_calculated_list_price AS mart_total_calculated_list_price
  FROM poc AS p
  FULL OUTER JOIN mart AS m
    ON p.month_start = m.month_start
   AND p.company_id = m.company_id
   AND p.location_id = m.location_id
   AND p.plan_id = m.plan_id
   AND p.membership_category = m.membership_category
)
SELECT
  COUNT(*) AS reconciled_key_rows,
  COUNTIF(poc_active_memberships IS NULL) AS missing_from_poc,
  COUNTIF(mart_active_memberships IS NULL) AS missing_from_mart,
  SUM(COALESCE(poc_active_memberships, 0)) AS poc_active_memberships,
  SUM(COALESCE(mart_active_memberships, 0)) AS mart_active_memberships,
  SUM(COALESCE(poc_active_members, 0)) AS poc_active_members,
  SUM(COALESCE(mart_active_members, 0)) AS mart_active_members,
  ROUND(SUM(COALESCE(poc_total_mrr, 0)), 2) AS poc_total_mrr,
  ROUND(SUM(COALESCE(mart_total_mrr, 0)), 2) AS mart_total_mrr,
  ROUND(SUM(ABS(COALESCE(poc_total_mrr, 0) - COALESCE(mart_total_mrr, 0))), 2) AS abs_total_mrr_diff
FROM recon;

