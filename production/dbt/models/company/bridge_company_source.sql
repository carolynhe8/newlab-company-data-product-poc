{{ config(
    materialized=var('company_data_materialization', 'view'),
    schema=var('company_data_schema', 'company_data'),
    tags=['company_data_product', 'company_identity']
) }}

-- Grain: one row per canonical_company_id / source_system / source_company_id.
-- Primary key: canonical_company_id, source_system, source_company_id.
-- Note: canonical_company_id may be null for unmatched source records.

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
FROM {{ source('intermediate', 'int_cross_source_companies') }}

