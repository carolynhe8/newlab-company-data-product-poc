-- Deployment step 03: fct_engagement_ledger.
--
-- Creates or replaces the consolidated company engagement ledger.
-- Dependency order: run after bridge_company_source.

DECLARE target_project STRING DEFAULT 'datahub-prod-477220';
DECLARE target_dataset STRING DEFAULT 'company_data'; -- TODO: replace with approved production dataset.

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.fct_engagement_ledger`
OPTIONS(
  description = 'Company engagement ledger across HubSpot deals, OfficeRnD memberships, and BigTime projects.'
)
AS
WITH bridge AS (
  SELECT
    source_system,
    source_company_id,
    canonical_company_id,
    requires_manual_review,
    match_confidence
  FROM `datahub-prod-477220.intermediate.int_cross_source_companies`
),

hubspot_deals AS (
  SELECT
    TO_HEX(SHA256(CONCAT('hubspot_deal|', d.deal_id, '|', dc.company_id))) AS engagement_event_id,
    b.canonical_company_id,
    b.canonical_company_id IS NULL AS canonical_company_id_is_null,
    dc.company_id AS source_company_id,
    'hubspot' AS source_system,
    'Business' AS engagement_category,
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
    COALESCE(b.requires_manual_review, TRUE) AS requires_manual_review,
    b.match_confidence
  FROM `datahub-prod-477220.staging.stg_hubspot_deals` AS d
  JOIN `datahub-prod-477220.staging.stg_hubspot_deal_company` AS dc
    ON d.deal_id = dc.deal_id
   AND dc.category = 'HUBSPOT_DEFINED'
   AND dc.type_id = 5
  LEFT JOIN bridge AS b
    ON b.source_system = 'hubspot'
   AND b.source_company_id = dc.company_id
),

officernd_memberships AS (
  SELECT
    TO_HEX(
      SHA256(
        CONCAT(
          'officernd_membership|',
          md.membership_id,
          '|',
          COALESCE(md.assignment_id, ''),
          '|',
          CAST(md.period_start_date AS STRING),
          '|',
          COALESCE(CAST(md.period_end_date AS STRING), '')
        )
      )
    ) AS engagement_event_id,
    b.canonical_company_id,
    b.canonical_company_id IS NULL AS canonical_company_id_is_null,
    md.company_id AS source_company_id,
    'officernd' AS source_system,
    'Business' AS engagement_category,
    'membership' AS engagement_type,
    md.membership_id AS source_engagement_id,
    md.membership_name AS engagement_name,
    COALESCE(md.membership_category, 'Uncategorized') AS engagement_subtype,
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
    COALESCE(b.requires_manual_review, TRUE) AS requires_manual_review,
    b.match_confidence
  FROM `datahub-prod-477220.intermediate.int_membership_detail` AS md
  LEFT JOIN bridge AS b
    ON b.source_system = 'officernd'
   AND b.source_company_id = md.company_id
),

bigtime_projects AS (
  SELECT
    TO_HEX(SHA256(CONCAT('bigtime_project|', CAST(p.project_id AS STRING), '|', CAST(p.client_id AS STRING)))) AS engagement_event_id,
    b.canonical_company_id,
    b.canonical_company_id IS NULL AS canonical_company_id_is_null,
    CAST(p.client_id AS STRING) AS source_company_id,
    'bigtime' AS source_system,
    'Business' AS engagement_category,
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
    COALESCE(b.requires_manual_review, TRUE) AS requires_manual_review,
    b.match_confidence
  FROM `datahub-prod-477220.staging.stg_bigtime_projects` AS p
  LEFT JOIN bridge AS b
    ON b.source_system = 'bigtime'
   AND b.source_company_id = CAST(p.client_id AS STRING)
)

SELECT * FROM hubspot_deals
UNION ALL
SELECT * FROM officernd_memberships
UNION ALL
SELECT * FROM bigtime_projects
""", target_project, target_dataset);
