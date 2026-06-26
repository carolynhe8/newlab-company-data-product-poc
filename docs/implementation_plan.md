# Implementation Plan

## Objective

Move the POC from reviewed read-only SQL into maintainable warehouse assets with tests, documentation, and dashboard-ready outputs. The implementation should remain incremental so the team can validate company identity, membership reconciliation, and engagement definitions before productionizing.

## Phase Roadmap

| Phase | Scope | Dependencies | Estimated complexity | Main risks | Validation steps |
|---|---|---|---|---|---|
| Phase 1: Bridge | Create `bridge_company_source_poc` as the identity mapping foundation. | Approval to use `intermediate.int_cross_source_companies`; scratch schema or dbt target. | Low | Null canonical mappings; manual-review mappings; source mapping drift. | Check duplicate `source_system / source_company_id`; count null canonical rows; count manual-review rows; sample low-confidence mappings. |
| Phase 2: Dimensions | Create `dim_company_poc` for display/convenience attributes. | Phase 1 bridge; confirmed representative-record rules. | Medium | Display attributes may be mistaken for mapping truth; multiple source IDs can be hidden if arrays are ignored. | Check one row per non-null canonical ID; validate source ID arrays; count blank company names; inspect companies with multiple source IDs. |
| Phase 3: Facts | Create `fct_engagement_ledger_poc` for HubSpot deals, OfficeRnD memberships, and BigTime projects. | Phase 1 bridge; confirmed HubSpot association rule; confirmed MVP engagement scope. | Medium | HubSpot associations may be many-to-many; OfficeRnD membership grain may be misunderstood; source amount fields have different meanings. | Check event ID uniqueness; row counts by source; null canonical rates by source; manual-review rows; sample each source type. |
| Phase 4: Marts | Create `mart_membership_status_poc` for current/past membership reporting. | Phase 1 bridge; confirmed membership category normalization; confirmed future-month handling. | Medium | Category normalization missed; future bookings confused with current/past reporting; reconciliation divergence from existing mart. | Reconcile to `marts.mart_membership_detail`; validate current month totals; check null canonical rates; compare MRR, active memberships, active members. |
| Phase 5: Dashboards | Build dashboard-ready semantic views and initial reporting surfaces. | Phases 1-4; stakeholder metric definitions; BI access pattern. | Medium to high | Users may overinterpret POC caveats; dashboard filters may hide QA flags; metric definitions may diverge from existing reporting. | Dashboard QA against marts; stakeholder UAT; row-level drill-through; documented metric definitions. |

## Phase 1: Bridge

Deliverable:

- A scratch view or dbt model equivalent to `bridge_company_source_poc`.

Purpose:

- Make canonical company mappings auditable and consumable.
- Preserve every source company ID.
- Expose mapping quality fields.

Dependencies:

- `intermediate.int_cross_source_companies` remains the authoritative source for canonical mapping.
- A scratch schema or dbt branch is approved.

Validation:

- No duplicate `source_system / source_company_id` mappings.
- Known null canonical rows remain visible.
- Manual-review and match-confidence fields are populated as expected.
- Multiple source IDs per canonical/source remain visible.

Exit criteria:

- Warehouse owner approves bridge grain and mapping semantics.
- QA results are documented and repeatable.

## Phase 2: Dimensions

Deliverable:

- A scratch view or dbt model equivalent to `dim_company_poc`.

Purpose:

- Provide one display/convenience row per canonical company.
- Preserve source IDs in arrays.
- Expose company-level mapping quality rollups.

Dependencies:

- Phase 1 bridge is accepted.
- Representative-record rules are accepted:
  - HubSpot first for company name, domain, and industry.
  - OfficeRnD prefers active company status, then latest modified date.
  - BigTime prefers non-deleted/current client rows when available, using the current `is_deleted` signal.

Validation:

- One row per non-null canonical company ID.
- Source ID arrays contain all mapped IDs.
- Manual-review rollup matches bridge-level expectations.
- Companies with multiple source IDs are sampled and reviewed.
- Blank or null company names are counted and sampled.

Exit criteria:

- Reviewers agree that dimension attributes are for display only.
- The bridge remains documented as the source of truth for mappings.

## Phase 3: Facts

Deliverable:

- A scratch view or dbt model equivalent to `fct_engagement_ledger_poc`.

Purpose:

- Consolidate selected company-facing engagement events.
- Provide event-level canonical company linkage.
- Make mapping quality observable on every fact row.

Dependencies:

- Phase 1 bridge exists.
- HubSpot deal-company association rule is confirmed.
- MVP source scope is confirmed.

Validation:

- Event IDs are unique.
- Row counts by source match expected POC counts.
- Null canonical rates by source are monitored.
- Manual-review row counts are documented.
- Each source type is sampled with `LIMIT`.

Exit criteria:

- Stakeholders agree on MVP engagement sources.
- Amount/status semantics are documented for each source.

## Phase 4: Marts

Deliverable:

- A scratch view or dbt model equivalent to `mart_membership_status_poc`.

Purpose:

- Provide current/past monthly membership metrics aligned to the canonical company strategy.
- Preserve reconciliation with the existing membership mart.

Dependencies:

- Phase 1 bridge exists.
- Existing membership spine remains stable.
- Decision confirmed that future bookings are separate from current/past status.

Validation:

- Past/current rows reconcile exactly to `marts.mart_membership_detail`.
- Current month reconciles exactly for active memberships, active members, and MRR.
- `membership_category` is normalized to `Uncategorized`.
- Null canonical rows are counted and monitored.

Exit criteria:

- Membership mart reconciliation is accepted by warehouse owner.
- Future-bookings scope is explicitly deferred or approved as a separate model.

## Phase 5: Dashboards

Deliverable:

- Initial dashboards or semantic views for company profile, engagement, and membership status.

Potential dashboard sections:

- Company profile and source-system coverage.
- Membership status by month, location, category, and plan.
- Engagement ledger by source system and status.
- Data-quality monitor for null canonical IDs and manual-review mappings.

Dependencies:

- Phases 1-4 promoted to stable scratch or dbt assets.
- Metric definitions confirmed by the data and business owners.
- BI access permissions and naming conventions approved.

Validation:

- Dashboard totals reconcile to warehouse models.
- Filters do not suppress QA risks by default.
- Drill-through paths to source IDs are available.
- Stakeholders complete UAT on representative companies.

Exit criteria:

- Head of Data or analytics engineering lead approves productionization path.
- Ownership, refresh expectations, and monitoring are documented.

## Recommended Promotion Sequence

1. Review this design package with warehouse owner and analytics engineering lead.
2. Approve scratch dataset and naming convention.
3. Create scratch views for the four POC models.
4. Run `sql/qa_checks.sql` and record results.
5. Convert approved scratch views into dbt models.
6. Add dbt tests:
   - Unique bridge source mapping.
   - Unique dimension canonical company ID.
   - Unique engagement event ID.
   - Membership reconciliation checks.
   - Accepted values for `source_system` and `engagement_type`.
7. Add dbt docs and exposures for dashboards.
8. Build dashboard prototypes.
9. Complete stakeholder UAT and promote.

## Open Implementation Decisions

- Scratch schema name and object naming convention.
- Whether unmatched source companies remain excluded from the dimension.
- Whether HubSpot primary company association `type_id = 5` is final.
- Whether HubSpot activities should be included in the MVP or deferred.
- Whether future membership months should become a separate future-bookings mart.
- Ownership of mapping remediation workflows.

