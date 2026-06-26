-- bridge_company_source_poc
--
-- Grain: one row per canonical_company_id / source_system / source_company_id.
-- Primary key: canonical_company_id, source_system, source_company_id.
-- Note: canonical_company_id may be NULL for unmatched source companies.

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

