# QA Results

All QA below came from read-only BigQuery queries against `datahub-prod-477220`.

## Key QA Findings

### Company Mapping

- Duplicate `source_system / source_company_id` mappings: `0` duplicate groups.
- Duplicate `dim_company_poc.canonical_company_id`: `0` duplicate groups.
- Multiple source company IDs per canonical/source: `61` groups affecting `189` source IDs.
- `dim_company_poc` row count before excluding null canonical IDs: `34,658`.
- Null canonical rows in that draft dimension: `1`.
- Blank company-name rows in that draft dimension: `8`.
- Manual-review rows in that draft dimension: `212`.
- Multi-source company rows: `885`.

Implication:

- `dim_company_poc` should preserve source ID arrays and should not collapse mapping truth to `MAX(source_company_id)`.
- `bridge_company_source_poc` is required.

### Engagement Ledger

Read-only POC ledger counts:

| source_system | engagement_type | row_count | null_canonical_rows | null_canonical_rate | manual_review_rows |
|---|---:|---:|---:|---:|---:|
| officernd | membership | 8,696 | 184 | 2.12% | 1,543 |
| hubspot | deal | 4,500 | 11 | 0.24% | 0 |
| bigtime | project | 67 | 0 | 0.00% | 15 |

Duplicate deterministic event IDs: `0`.

Implication:

- Facts should retain `canonical_company_id_is_null`, `requires_manual_review`, and `match_confidence`.
- OfficeRnD unmatched mappings are the largest company-resolution issue.

### Membership Status Reconciliation

Initial mismatch was caused by `membership_category IS NULL` in the POC while `marts.mart_membership_detail` uses `Uncategorized`.

After applying `COALESCE(membership_category, 'Uncategorized')`, past/current reconciliation to `marts.mart_membership_detail` was exact:

- Reconciled key rows: `25,478`
- Missing from POC: `0`
- Missing from mart: `0`
- Active memberships: `58,044` vs `58,044`
- Active members: `27,224` vs `27,224`
- Total MRR: `17,474,937.73` vs `17,474,937.73`
- Absolute total MRR diff: `0.0`

Current month reconciliation was also exact:

- Current-month key rows: `1,003`
- Missing from POC: `0`
- Missing from mart: `0`
- Active memberships: `2,298` vs `2,298`
- Active members: `1,566` vs `1,566`
- Total MRR: `513,463.23` vs `513,463.23`
- Absolute total MRR diff: `0.0`

### Future Months

`int_membership_months` includes future contracted months through `2027-10-01`.

Past/current POC rows:

- `25,478` rows
- Null canonical rows: `741`
- Null canonical rate: `2.91%`

Future POC rows:

- `12,830` rows
- Null canonical rows: `226`
- Null canonical rate: `1.76%`

Implication:

- MVP membership status should default to past/current months.
- Future bookings should be split into a separate model if needed.

## Top Data Quality Risks

1. Null canonical mappings, mostly OfficeRnD.
2. Manual-review mappings are material in OfficeRnD and BigTime facts.
3. Multiple source IDs per canonical/source are real and must be preserved in the bridge.
4. HubSpot deal-company associations are many-to-many unless filtered to primary association type.
5. `membership_category` normalization is required for reconciliation.
6. Representative dimension attributes are convenient but can hide multiple source-system records.

