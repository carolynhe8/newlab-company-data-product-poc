-- Deployment step 01: bridge_company_source.
--
-- Creates or replaces the canonical company source bridge.
-- Dependency order: run before dimensions, facts, and marts.

DECLARE target_project STRING DEFAULT 'datahub-prod-477220';
DECLARE target_dataset STRING DEFAULT 'company_data'; -- TODO: replace with approved production dataset.

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE VIEW `%s.%s.bridge_company_source`
OPTIONS(
  description = 'Canonical company source bridge. One row per canonical company, source system, and source company ID.'
)
AS
SELECT
  canonical_company_id,
  source_system,
  source_company_id,
  source_company_name,
  requires_manual_review,
  match_confidence,
  match_priority,
  match_method,
  match_detail,
  _resolved_at
FROM `datahub-prod-477220.intermediate.int_cross_source_companies`
""", target_project, target_dataset);

