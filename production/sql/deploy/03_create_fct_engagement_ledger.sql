-- Deployment step 03: fct_engagement_ledger.
--
-- Creates or replaces the consolidated company engagement ledger.
-- Dependency order: run after bridge_company_source.

DECLARE target_project STRING DEFAULT 'datahub-prod-477220';
DECLARE target_dataset STRING DEFAULT 'company_data'; -- TODO: replace with approved production dataset.

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.fct_engagement_ledger`
OPTIONS(
  description = 'Company engagement ledger across HubSpot deals, HubSpot Startup Projects, OfficeRnD memberships, and BigTime projects.'
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
    CAST(NULL AS STRING) AS program_name,
    ARRAY<STRING>[] AS partner_company_ids,
    ARRAY<STRING>[] AS partner_names,
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

hubspot_project_partners AS (
  SELECT
    pc.from_id AS project_id,
    ARRAY_AGG(DISTINCT CAST(pc.to_id AS STRING) IGNORE NULLS ORDER BY CAST(pc.to_id AS STRING)) AS partner_company_ids,
    ARRAY_AGG(DISTINCT CAST(c.property_name AS STRING) IGNORE NULLS ORDER BY CAST(c.property_name AS STRING)) AS partner_names
  FROM `datahub-prod-477220.hubspot.projects_to_company` AS pc
  LEFT JOIN `datahub-prod-477220.hubspot.company` AS c
    ON c.id = pc.to_id
  WHERE pc.type_id = 107 -- project_partner
  GROUP BY pc.from_id
),

hubspot_startup_projects AS (
  SELECT
    TO_HEX(SHA256(CONCAT('hubspot_startup_project|', CAST(p.id AS STRING), '|', CAST(startup.to_id AS STRING)))) AS engagement_event_id,
    b.canonical_company_id,
    b.canonical_company_id IS NULL AS canonical_company_id_is_null,
    CAST(startup.to_id AS STRING) AS source_company_id,
    'hubspot' AS source_system,
    'Business' AS engagement_category,
    'project' AS engagement_type,
    CAST(p.id AS STRING) AS source_engagement_id,
    p.property_project_name AS engagement_name,
    p.property_project_category AS engagement_subtype,
    COALESCE(p.property_project_status, 'unknown') AS engagement_status,
    p.property_project_status AS engagement_status_raw,
    DATE(p.property_project_start_date) AS start_date,
    DATE(p.property_project_end_date) AS end_date,
    CAST(NULL AS FLOAT64) AS amount,
    CAST(NULL AS STRING) AS member_id,
    CAST(NULL AS STRING) AS membership_id,
    p.property_offering AS program_name,
    COALESCE(partners.partner_company_ids, ARRAY<STRING>[]) AS partner_company_ids,
    COALESCE(partners.partner_names, ARRAY<STRING>[]) AS partner_names,
    COALESCE(b.requires_manual_review, TRUE) AS requires_manual_review,
    b.match_confidence
  FROM `datahub-prod-477220.hubspot.projects` AS p
  JOIN `datahub-prod-477220.hubspot.projects_to_company` AS startup
    ON startup.from_id = p.id
   AND startup.type_id = 105 -- project_startup
  LEFT JOIN hubspot_project_partners AS partners
    ON partners.project_id = p.id
  LEFT JOIN bridge AS b
    ON b.source_system = 'hubspot'
   AND b.source_company_id = CAST(startup.to_id AS STRING)
  WHERE NOT COALESCE(p._fivetran_deleted, FALSE)
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
    CAST(NULL AS STRING) AS program_name,
    ARRAY<STRING>[] AS partner_company_ids,
    ARRAY<STRING>[] AS partner_names,
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
    CAST(NULL AS STRING) AS program_name,
    ARRAY<STRING>[] AS partner_company_ids,
    ARRAY<STRING>[] AS partner_names,
    COALESCE(b.requires_manual_review, TRUE) AS requires_manual_review,
    b.match_confidence
  FROM `datahub-prod-477220.staging.stg_bigtime_projects` AS p
  LEFT JOIN bridge AS b
    ON b.source_system = 'bigtime'
   AND b.source_company_id = CAST(p.client_id AS STRING)
)

SELECT * FROM hubspot_deals
UNION ALL
SELECT * FROM hubspot_startup_projects
UNION ALL
SELECT * FROM officernd_memberships
UNION ALL
SELECT * FROM bigtime_projects
""", target_project, target_dataset);
