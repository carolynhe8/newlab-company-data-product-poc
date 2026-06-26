# Implementation Checklist

## Default User-Facing Dataset

`mart_newlab_companies` is the MVP Company Data Product output and should be the default dataset for Connected Sheets, dashboards, and ad hoc company analysis.

Grain: one row per `canonical_company_id`.

## Pre-Deployment

- Confirm production target dataset/schema name for the company data product.
- Confirm BigQuery location if a new dataset must be created.
- Confirm whether models should deploy as views or tables.
- Confirm that future membership months remain out of `mart_membership_status`.
- Confirm that downstream users should start from `mart_newlab_companies`, not the lower-level bridge, dimension, fact, or membership mart.
- Confirm that `fct_engagement_ledger` remains limited to structured business engagements for MVP and excludes HubSpot CRM activity objects.

## SQL Deployment Order

Run scripts in this order after approvals:

1. `production/sql/deploy/00_create_target_dataset_if_needed.sql`
   - Optional. Run only if the approved target dataset does not already exist.
2. `production/sql/deploy/01_create_bridge_company_source.sql`
3. `production/sql/deploy/02_create_dim_company.sql`
4. `production/sql/deploy/03_create_fct_engagement_ledger.sql`
5. `production/sql/deploy/04_create_mart_membership_status.sql`
6. `production/sql/deploy/05_create_mart_newlab_companies.sql`

Before running:

- Replace `target_dataset = 'company_data'` with the approved dataset.
- Confirm scripts point at the correct source project: `datahub-prod-477220`.
- Run first in scratch or staging if production change management requires it.

## dbt Deployment Order

1. Copy `production/dbt/models/company/*.sql` into the dbt project.
2. Copy `production/dbt/models/company/schema.yml` and `sources.yml` into the dbt project.
3. Copy `production/dbt/macros/*.sql` into the dbt project.
4. Copy `production/dbt/tests/*.sql` into the dbt project.
5. Copy `production/marts/mart_newlab_companies.sql` and `production/marts/schema.yml` into the dbt marts model folder.
6. Merge variables from `production/dbt/dbt_project.example.yml` into the real `dbt_project.yml`.
7. Run `dbt compile --select bridge_company_source dim_company fct_engagement_ledger mart_membership_status mart_newlab_companies`.
8. Run `dbt build --select bridge_company_source dim_company fct_engagement_ledger mart_membership_status mart_newlab_companies`.
9. Run the membership reconciliation singular test.

## Post-Deployment Validation

Run:

- `production/tests/test_mart_newlab_companies.sql`

Review:

- Duplicate `canonical_company_id`: expected zero rows.
- Null `canonical_company_id`: expected zero.
- Row count comparison to `dim_company`: expected equal counts.
- Null `company_name`: review count and examples if elevated.
- Manual review company count: monitor for mapping remediation.
- Active membership count: compare against current membership expectations.
- Engagement distribution by type: confirm deal, membership, and project rows are represented.

## Production Readiness Gate

- `mart_newlab_companies` builds successfully.
- `canonical_company_id` is unique and not null.
- Row count matches `dim_company`.
- Engagement taxonomy currently contains only `Business`; future Program, Technical, and Strategic categories should be added through structured sources in `fct_engagement_ledger` without changing the model grain.
- `engagement_timeline` is available in `mart_newlab_companies` for compact company-level engagement review.
- `partner_name` and `program_name` remain TODOs until structured upstream attribution fields are modeled.
- Smoke tests are reviewed.
- Data owner confirms `mart_newlab_companies` is the default downstream company dataset.
