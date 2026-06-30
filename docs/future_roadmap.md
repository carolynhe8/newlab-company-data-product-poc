# Future Roadmap

## Roadmap Summary

The MVP establishes the canonical company foundation and a small set of company-centered reporting models. Future work should expand coverage, improve data quality workflows, and move from POC models to governed warehouse and BI assets.

## Near-Term Enhancements

### 1. Promote POC SQL To Scratch Views

Goal:

- Make the four POC models available for stakeholder review without changing production tables.

Work:

- Create scratch views after approval.
- Run QA checks against scratch views.
- Capture review feedback from warehouse owner and analytics engineering.

Success criteria:

- SQL runs without syntax issues.
- QA results match documented expectations.
- Stakeholders can inspect the data without copy/pasting SQL.

### 2. Convert Approved Models To dbt

Goal:

- Move from standalone SQL to maintainable models with tests and documentation.

Work:

- Add dbt model files.
- Add schema YAML docs and tests.
- Add lineage metadata and exposures.
- Add run instructions and owner metadata.

Success criteria:

- dbt build passes.
- Tests cover uniqueness, accepted values, and reconciliation.
- dbt docs clearly describe grain, keys, caveats, and owners.

### 3. Add Mapping Quality Monitors

Goal:

- Make canonical mapping risk visible and actionable.

Work:

- Track null canonical rates by source.
- Track manual-review rows by source.
- Track low-confidence mappings.
- Sample companies with multiple source IDs.

Success criteria:

- Data owners can identify mappings needing review.
- Changes in mapping quality are visible over time.

## Medium-Term Enhancements

## Phase 2 — Qualification & Operational Intelligence

The current MVP provides the necessary foundation for operational intelligence: canonical company IDs, primary company owner ID, the engagement ledger, HubSpot Startup Projects, partner attribution, program attribution, the engagement timeline, and the one-row-per-company `mart_newlab_companies` mart.

### Qualification Support

- Tier A status.
- Fund qualification.
- Qualification-meeting workflow.
- Qualification triggers.
- Resurfacing companies after major milestones.

### Readiness & Risk

- Technical readiness.
- Commercialization readiness.
- Team readiness.
- Deep Tech Readiness Framework.
- Red flags and disqualification reasons.

### Qualitative Knowledge

- Investment memos.
- Commercialization reviews.
- State intake forms.
- Linked documents.
- Internal notes.
- Document metadata.

### External Enrichment

- PitchBook.
- Harmonic.
- LinkedIn/headcount.
- Hiring signals.
- Founder/team activity.

### Owner Enrichment

The MVP uses `hubspot.company.property_hubspot_owner_id` as the authoritative company-level primary internal Newlab relationship owner and resolves owner name/email from `hubspot.owner`. Deal and Startup Project owners should remain engagement-level context unless a separate operational workflow requires them.

### 4. Expand Engagement Coverage

Goal:

- Extend the engagement ledger beyond deals, memberships, and projects.

Candidate sources:

- HubSpot emails.
- HubSpot meetings.
- HubSpot calls.
- HubSpot notes.
- HubSpot tasks.
- Program participation data if available.
- Event attendance or service utilization data if available.

Design considerations:

- Activity volume may require a separate activity fact rather than adding everything to the engagement ledger.
- Activity semantics differ from commercial/member/project engagements.
- The team should decide whether the ledger represents all activity or only meaningful company-level engagement milestones.

### 5. Add Future Bookings Mart

Goal:

- Separate future contracted membership months from current/past membership status.

Work:

- Create a future-bookings version of the membership mart by changing the month predicate to future months.
- Validate against OfficeRnD expectations.
- Decide whether future bookings should share metrics with current/past membership status or use different naming.

Success criteria:

- Current/past membership reporting remains stable.
- Future bookings are visible without confusing existing membership status metrics.

### 6. Create Company Profile Mart

Goal:

- Provide a dashboard-ready company profile model that combines dimension attributes, membership status, engagement summaries, and source coverage.

Potential fields:

- Canonical company ID.
- Display company name.
- Source-system coverage.
- Current membership status.
- Current location/category/plan summary.
- Latest HubSpot deal.
- Latest BigTime project.
- Last engagement date.
- Mapping quality flags.

Success criteria:

- Business users can start from a single company profile view.
- Drill-through to bridge and facts remains available.

## Longer-Term Enhancements

### 7. Source-System Remediation Workflow

Goal:

- Turn mapping quality findings into an operational process.

Work:

- Define mapping review ownership.
- Create a queue for null canonical IDs, manual-review mappings, and low-confidence matches.
- Track resolution status and resolved-at timestamps.
- Decide whether corrected mappings live in source systems, override tables, or upstream matching configuration.

Success criteria:

- Mapping issues have an owner and resolution path.
- Mapping quality improves over time.

### 8. Company Identity Governance

Goal:

- Establish canonical company identity as a governed warehouse domain.

Work:

- Define canonical ID creation rules.
- Define source precedence rules.
- Document change management for matching logic.
- Add regression tests for identity matching.
- Review sensitive or high-impact merges before promotion.

Success criteria:

- Identity changes are explainable and auditable.
- Stakeholders trust canonical company reporting.

### 9. Production Dashboards

Goal:

- Build governed dashboards on the approved company data product.

Candidate dashboards:

- Company 360 profile.
- Membership status and MRR.
- Engagement by source system.
- Source-system coverage and data quality.
- Mapping review operations.

Success criteria:

- Dashboard metrics reconcile to warehouse models.
- QA flags are visible to users.
- Dashboard owners and refresh expectations are documented.

## Future Data Quality Enhancements

- Add freshness checks for source tables and intermediate models.
- Add anomaly detection for row counts and MRR shifts.
- Add accepted-value tests for source systems, engagement types, and statuses.
- Add not-null tests where business rules allow.
- Add referential checks between facts, marts, bridge, and dimension.
- Add automated reporting for null canonical rows and manual-review mappings.

## Future Modeling Questions

- Should canonical company IDs ever be reassigned, or should merges be versioned?
- Should source mappings support effective dates?
- Should company display attributes become slowly changing dimensions?
- Should engagement amount be split into source-specific measures instead of one generic `amount` field?
- Should membership status and future bookings share one model with a period type, or remain separate marts?
- Should HubSpot activity events be modeled as company engagement or as a separate activity fact?
