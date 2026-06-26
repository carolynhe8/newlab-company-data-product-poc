-- Model: bridge_company_source
-- Type: bridge
-- Dependency order: 1 of 4
--
-- Grain:
--   One row per canonical_company_id / source_system / source_company_id.
--
-- Primary key:
--   canonical_company_id, source_system, source_company_id
--
-- Source dependencies:
--   datahub-prod-477220.intermediate.int_cross_source_companies
--
-- Notes:
--   canonical_company_id may be null for unmatched source records.
--   This model is the source of truth for company-source mappings.

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

