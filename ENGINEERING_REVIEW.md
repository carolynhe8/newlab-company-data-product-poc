# Engineering Review

## Current Status

The MVP Company Data Product implementation package is complete locally under `~/Documents/Newlab/newlab_company_data_product_poc`. The package is implementation-ready, pending engineering review, dev deployment, smoke validation, and Cristóvão approval for production handoff.

No BigQuery objects have been created by this package yet.

## Models Included

Deployment models:

1. `bridge_company_source`
2. `dim_company`
3. `fct_engagement_ledger`
4. `mart_membership_status`
5. `mart_newlab_companies`

Final user-facing mart:

- `mart_newlab_companies`
- Grain: one row per `canonical_company_id`
- Intended default dataset for Connected Sheets, dashboards, and ad hoc company analysis
- Includes compact engagement rollups and `engagement_timeline` from structured ledger events.

## Deployment Order

1. `production/sql/deploy/00_create_target_dataset_if_needed.sql`
2. `production/sql/deploy/01_create_bridge_company_source.sql`
3. `production/sql/deploy/02_create_dim_company.sql`
4. `production/sql/deploy/03_create_fct_engagement_ledger.sql`
5. `production/sql/deploy/04_create_mart_membership_status.sql`
6. `production/sql/deploy/05_create_mart_newlab_companies.sql`

## Known Assumptions

- `intermediate.int_cross_source_companies` remains the canonical identity source.
- `dim_company` is for display/convenience attributes; the bridge remains mapping truth.
- HubSpot deal-company association uses `category = 'HUBSPOT_DEFINED'` and `type_id = 5`.
- `fct_engagement_ledger` represents structured business engagements only: HubSpot deals, OfficeRnD memberships, and BigTime projects.
- HubSpot CRM activity objects such as emails, calls, notes, meetings, and tasks are intentionally excluded from the MVP.
- `mart_membership_status` covers current/past months only.
- `company_data` is a placeholder target dataset and must be confirmed before deployment.

## Risks / Caveats

- Null canonical mappings remain excluded from the final company mart.
- Manual-review mappings are surfaced, not resolved.
- Engagement `amount` has source-specific meaning across deals, memberships, and projects.
- Current engagement taxonomy is limited to `Business`. Program, Technical, and Strategic categories are reserved for future structured sources such as showcases, demo days, accelerators, office hours, grants, pilots, technical assistance, investments, and partnerships.
- Partner/program attribution is not currently modeled; add `partner_name` and `program_name` only once structured upstream association fields exist.
- Future membership bookings are deferred.
- Source-system arrays should be preserved for audit and drill-through.

## Pre-Production Validation

- Compile dbt models or dry-run SQL scripts in dev.
- Run dbt tests in `production/marts/schema.yml` and `production/dbt/models/company/schema.yml`.
- Run `production/tests/test_mart_newlab_companies.sql`.
- Confirm `mart_newlab_companies` row count matches `dim_company`.
- Confirm `canonical_company_id` is unique and not null.
- Check null `company_name`, manual-review counts, active membership counts, and engagement distribution.

## Decisions Needed From Cristóvão

- Approved dev/prod dataset name.
- View vs table materialization.
- Approval that `mart_newlab_companies` is the default downstream company dataset.
- Acceptance of known caveats for MVP.
- Timing and owner for production deployment.

## Recommended Next Step

Deploy to a dev dataset, run the lightweight smoke tests, review results with Cristóvão, then promote the same model set to production.
