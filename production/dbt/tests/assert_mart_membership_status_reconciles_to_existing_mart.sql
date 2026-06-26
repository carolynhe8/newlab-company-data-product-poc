-- Singular dbt test:
-- Returns rows when mart_membership_status does not reconcile to the existing
-- marts.mart_membership_detail at the current/past month aggregate level.

WITH production_mart AS (
  SELECT
    month_start,
    officernd_company_id AS company_id,
    location_id,
    membership_category,
    plan_id,
    active_memberships,
    active_members,
    total_mrr,
    total_calculated_list_price,
    total_calculated_discount_amount
  FROM {{ ref('mart_membership_status') }}
),

existing_mart AS (
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
  FROM {{ source('marts', 'mart_membership_detail') }}
  WHERE month_start <= DATE_TRUNC(CURRENT_DATE(), MONTH)
),

reconciliation AS (
  SELECT
    COALESCE(p.month_start, m.month_start) AS month_start,
    COALESCE(p.company_id, m.company_id) AS company_id,
    COALESCE(p.location_id, m.location_id) AS location_id,
    COALESCE(p.membership_category, m.membership_category) AS membership_category,
    COALESCE(p.plan_id, m.plan_id) AS plan_id,
    p.active_memberships AS production_active_memberships,
    m.active_memberships AS existing_active_memberships,
    p.active_members AS production_active_members,
    m.active_members AS existing_active_members,
    p.total_mrr AS production_total_mrr,
    m.total_mrr AS existing_total_mrr,
    p.total_calculated_list_price AS production_total_calculated_list_price,
    m.total_calculated_list_price AS existing_total_calculated_list_price,
    p.total_calculated_discount_amount AS production_total_calculated_discount_amount,
    m.total_calculated_discount_amount AS existing_total_calculated_discount_amount
  FROM production_mart AS p
  FULL OUTER JOIN existing_mart AS m
    ON p.month_start = m.month_start
   AND p.company_id = m.company_id
   AND p.location_id = m.location_id
   AND p.membership_category = m.membership_category
   AND p.plan_id = m.plan_id
)

SELECT *
FROM reconciliation
WHERE production_active_memberships IS NULL
   OR existing_active_memberships IS NULL
   OR COALESCE(production_active_memberships, 0) != COALESCE(existing_active_memberships, 0)
   OR COALESCE(production_active_members, 0) != COALESCE(existing_active_members, 0)
   OR ROUND(COALESCE(production_total_mrr, 0), 2) != ROUND(COALESCE(existing_total_mrr, 0), 2)
   OR ROUND(COALESCE(production_total_calculated_list_price, 0), 2) != ROUND(COALESCE(existing_total_calculated_list_price, 0), 2)
   OR ROUND(COALESCE(production_total_calculated_discount_amount, 0), 2) != ROUND(COALESCE(existing_total_calculated_discount_amount, 0), 2)

