-- Lightweight post-deployment smoke tests for mart_newlab_companies.
--
-- These are read-only validation queries. Run after deployment and inspect
-- result sets. Replace company_data if the approved production dataset differs.

-- 1. Duplicate canonical_company_id rows. Expected: zero rows.
SELECT
  canonical_company_id,
  COUNT(*) AS row_count
FROM `datahub-prod-477220.company_data.mart_newlab_companies`
GROUP BY canonical_company_id
HAVING COUNT(*) > 1
ORDER BY row_count DESC
LIMIT 100;

-- 2. Null canonical_company_id count. Expected: zero.
SELECT
  COUNT(*) AS null_canonical_company_id_count
FROM `datahub-prod-477220.company_data.mart_newlab_companies`
WHERE canonical_company_id IS NULL;

-- 3. Row count comparison to dim_company. Expected: equal row counts.
SELECT
  'mart_newlab_companies' AS model_name,
  COUNT(*) AS row_count
FROM `datahub-prod-477220.company_data.mart_newlab_companies`
UNION ALL
SELECT
  'dim_company' AS model_name,
  COUNT(*) AS row_count
FROM `datahub-prod-477220.company_data.dim_company`;

-- 4. Null company_name count. Expected: review count, not necessarily zero.
SELECT
  COUNT(*) AS null_company_name_count
FROM `datahub-prod-477220.company_data.mart_newlab_companies`
WHERE company_name IS NULL;

-- 5. Manual review company count.
SELECT
  COUNTIF(has_any_manual_review_mapping) AS manual_review_company_count,
  COUNTIF(has_identity_manual_review_mapping) AS identity_manual_review_company_count
FROM `datahub-prod-477220.company_data.mart_newlab_companies`;

-- 6. Active membership count.
SELECT
  membership_status,
  COUNT(*) AS company_count,
  SUM(current_active_memberships) AS current_active_memberships,
  SUM(current_active_members) AS current_active_members,
  ROUND(SUM(current_total_mrr), 2) AS current_total_mrr
FROM `datahub-prod-477220.company_data.mart_newlab_companies`
GROUP BY membership_status
ORDER BY company_count DESC;

-- 7. Engagement distribution by type.
SELECT
  'deal' AS engagement_type,
  COUNTIF(has_deal_engagement) AS companies_with_engagement_type,
  SUM(deal_engagement_count) AS engagement_count
FROM `datahub-prod-477220.company_data.mart_newlab_companies`
UNION ALL
SELECT
  'membership' AS engagement_type,
  COUNTIF(has_membership_engagement) AS companies_with_engagement_type,
  SUM(membership_engagement_count) AS engagement_count
FROM `datahub-prod-477220.company_data.mart_newlab_companies`
UNION ALL
SELECT
  'project' AS engagement_type,
  COUNTIF(has_project_engagement) AS companies_with_engagement_type,
  SUM(project_engagement_count) AS engagement_count
FROM `datahub-prod-477220.company_data.mart_newlab_companies`;

