# Newlab Company Data Product POC

This package contains a review-ready design proposal for a centralized Newlab company data product in BigQuery project `datahub-prod-477220`.

The goal is to align on architecture, grain, keys, data quality strategy, and implementation sequencing before creating scratch views or PR-ready dbt models. The SQL in this package remains read-only POC SQL.

## Review Entry Points

- `DESIGN.md` - executive-level design narrative and review decisions
- `docs/architecture.md` - detailed architecture, lineage, relationships, and model specs
- `docs/data_dictionary.md` - field-level documentation for all four POC models
- `docs/implementation_plan.md` - phased implementation plan from bridge to dashboards
- `docs/future_roadmap.md` - future enhancements and governance roadmap
- `docs/qa_results.md` - QA findings from read-only validation

## SQL Models

- `sql/bridge_company_source_poc.sql`
- `sql/dim_company_poc.sql`
- `sql/fct_engagement_ledger_poc.sql`
- `sql/mart_membership_status_poc.sql`
- `sql/qa_checks.sql`

## Proposed Model Set

| Model | Purpose | Grain | Primary key |
|---|---|---|---|
| `bridge_company_source_poc` | Source-to-canonical company bridge and mapping audit layer. | One row per canonical company / source system / source company ID. | `canonical_company_id`, `source_system`, `source_company_id` |
| `dim_company_poc` | Convenience/display dimension for canonical companies. | One row per non-null canonical company ID. | `canonical_company_id` |
| `fct_engagement_ledger_poc` | Consolidated engagement ledger for HubSpot deals, OfficeRnD memberships, and BigTime projects. | One row per deterministic engagement event. | `engagement_event_id` |
| `mart_membership_status_poc` | Current/past monthly membership status mart. | One row per month / OfficeRnD company / location / membership category / plan. | `month_start`, `officernd_company_id`, `location_id`, `membership_category`, `plan_id` |

## Important Design Principle

`bridge_company_source_poc` is the source of truth for company mappings. `dim_company_poc` uses deterministic representative records for display attributes only and should not replace the bridge for audit, source joins, or identity resolution.

## Engagement MVP Scope

`fct_engagement_ledger` represents structured business engagements only: HubSpot deals, OfficeRnD memberships, and BigTime projects. HubSpot CRM activity objects such as emails, calls, notes, meetings, and tasks are intentionally excluded from the MVP.

The current taxonomy uses `engagement_category = 'Business'`. Future structured Program, Technical, and Strategic sources can extend the same ledger grain without redesigning the model. `mart_newlab_companies` includes `engagement_timeline`, a compact 20-event company-level timeline built from the ledger.

Partner/program attribution is not currently modeled in the ledger. Add `partner_name` and `program_name` only after structured partner, program, or HubSpot project/deal association fields are available upstream.

## Validation Notes

The four model SQL files were validated with local `bq query` and `LIMIT 1`. No BigQuery objects were created, modified, or deleted during validation.

Before promotion, rerun `sql/qa_checks.sql` and capture results for the target scratch or dbt environment.
