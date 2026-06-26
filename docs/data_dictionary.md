# Data Dictionary

This dictionary documents the output fields in the four proposed POC models. Data types are expressed as intended BigQuery output types based on the model SQL and validated query results.

## `bridge_company_source_poc`

Model grain: one row per `canonical_company_id / source_system / source_company_id`.

Primary key: `canonical_company_id`, `source_system`, `source_company_id`.

| Field | Data type | Grain | Source | Description | Business meaning |
|---|---|---|---|---|---|
| `canonical_company_id` | STRING | Bridge row | `intermediate.int_cross_source_companies.canonical_company_id` | Canonical company identifier assigned by the existing cross-source mapping model. | Shared company key used to connect source systems when a match exists. May be null for unmatched source records. |
| `source_system` | STRING | Bridge row | `intermediate.int_cross_source_companies.source_system` | Source system for the mapped company record. | Indicates whether the source ID came from HubSpot, OfficeRnD, BigTime, or another supported source. |
| `source_company_id` | STRING | Bridge row | `intermediate.int_cross_source_companies.source_company_id` | Company/client identifier from the source system. | Audit and drill-through key back to the operational source. |
| `source_company_name` | STRING | Bridge row | `intermediate.int_cross_source_companies.source_company_name` | Source-system company name used in the match. | Human-readable source label for reviewing mappings. |
| `requires_manual_review` | BOOL | Bridge row | `intermediate.int_cross_source_companies.requires_manual_review` | Flag indicating whether the mapping should be reviewed manually. | Downstream consumers can filter, segment, or monitor lower-confidence mappings. |
| `match_confidence` | FLOAT64 | Bridge row | `intermediate.int_cross_source_companies.match_confidence` | Numeric confidence assigned by the upstream matching logic. | Provides a comparable quality signal for canonical mapping. |
| `match_priority` | INT64 | Bridge row | `intermediate.int_cross_source_companies.match_priority` | Priority assigned by the upstream matching logic. | Helps explain why a match was selected when multiple signals exist. |
| `match_method` | STRING | Bridge row | `intermediate.int_cross_source_companies.match_method` | Matching method used by the upstream model. | Describes whether the match came from canonical logic, direct ID logic, name/domain matching, or other configured rules. |
| `match_detail` | STRING | Bridge row | `intermediate.int_cross_source_companies.match_detail` | Additional upstream detail about the match. | Supports review, debugging, and remediation workflows. |
| `_resolved_at` | DATETIME | Bridge row | `intermediate.int_cross_source_companies._resolved_at` | Timestamp/datetime when the mapping was resolved upstream. | Indicates freshness of the company mapping decision. |

## `dim_company_poc`

Model grain: one row per non-null `canonical_company_id`.

Primary key: `canonical_company_id`.

Important note: representative display attributes are for convenience only. Source mapping truth remains in `bridge_company_source_poc`.

| Field | Data type | Grain | Source | Description | Business meaning |
|---|---|---|---|---|---|
| `canonical_company_id` | STRING | Canonical company | `intermediate.int_cross_source_companies.canonical_company_id` | Canonical company identifier. | Primary reporting key for a real-world company across systems. |
| `company_name` | STRING | Canonical company | Coalesced representative HubSpot, OfficeRnD, then BigTime name | Preferred display company name. | Human-readable company label for dashboards and reporting. |
| `company_name_source` | STRING | Canonical company | Derived in model | Source system used for `company_name`. | Shows whether the displayed name came from HubSpot, OfficeRnD, or BigTime. |
| `company_domain` | STRING | Canonical company | `staging.stg_hubspot_companies.company_domain` | HubSpot representative company domain. | Useful for company identification, enrichment, and deduplication review. |
| `hubspot_industry` | STRING | Canonical company | `staging.stg_hubspot_companies.industry` | HubSpot industry from the representative company record. | CRM industry classification for segmentation. |
| `hubspot_city` | STRING | Canonical company | `staging.stg_hubspot_companies.property_city` | HubSpot city from the representative company record. | Location context from CRM. |
| `hubspot_country` | STRING | Canonical company | `staging.stg_hubspot_companies.property_country` | HubSpot country from the representative company record. | Country context from CRM. |
| `employee_count` | FLOAT64 | Canonical company | `staging.stg_hubspot_companies.employee_count` | Employee count from HubSpot representative record. | Company size signal for segmentation. |
| `annual_revenue` | FLOAT64 | Canonical company | `staging.stg_hubspot_companies.annual_revenue` | Annual revenue from HubSpot representative record. | Company scale signal when available. |
| `officernd_company_email` | STRING | Canonical company | `staging.stg_officernd_companies.company_email` | Email from deterministic OfficeRnD representative record. | Membership-system contact or billing context. |
| `officernd_company_url` | STRING | Canonical company | `staging.stg_officernd_companies.company_url` | URL from deterministic OfficeRnD representative record. | OfficeRnD company web presence when available. |
| `officernd_company_status` | STRING | Canonical company | `staging.stg_officernd_companies.company_status` | Status from deterministic OfficeRnD representative record. | Indicates active/inactive membership-system company status. |
| `officernd_company_type` | STRING | Canonical company | `staging.stg_officernd_companies.company_type` | Type from deterministic OfficeRnD representative record. | OfficeRnD company classification. |
| `officernd_company_tier` | STRING | Canonical company | `staging.stg_officernd_companies.company_tier` | Tier from deterministic OfficeRnD representative record. | OfficeRnD tiering signal for membership/customer segmentation. |
| `officernd_location_id` | STRING | Canonical company | `staging.stg_officernd_companies.location_id` | Location ID from deterministic OfficeRnD representative record. | Default or representative OfficeRnD location context. |
| `bigtime_client_legal_name` | STRING | Canonical company | `staging.stg_bigtime_clients.client_legal_name` | Legal name from deterministic BigTime representative client. | Finance/project-system legal entity label. |
| `bigtime_client_code` | STRING | Canonical company | `staging.stg_bigtime_clients.client_code` | Client code from deterministic BigTime representative client. | Project-system client code for audit and drill-through. |
| `bigtime_client_type` | STRING | Canonical company | `staging.stg_bigtime_clients.client_type` | Client type from deterministic BigTime representative client. | BigTime client classification. |
| `bigtime_city` | STRING | Canonical company | `staging.stg_bigtime_clients.city` | City from deterministic BigTime representative client. | Project-system location context. |
| `bigtime_state` | STRING | Canonical company | `staging.stg_bigtime_clients.state` | State from deterministic BigTime representative client. | Project-system state context. |
| `bigtime_country` | STRING | Canonical company | `staging.stg_bigtime_clients.country` | Country from deterministic BigTime representative client. | Project-system country context. |
| `hubspot_company_ids` | ARRAY<STRING> | Canonical company | `intermediate.int_cross_source_companies.source_company_id` where `source_system = 'hubspot'` | All HubSpot company IDs mapped to the canonical company. | Preserves CRM source IDs for audit and source joins. |
| `officernd_company_ids` | ARRAY<STRING> | Canonical company | `intermediate.int_cross_source_companies.source_company_id` where `source_system = 'officernd'` | All OfficeRnD company IDs mapped to the canonical company. | Preserves membership source IDs for audit and source joins. |
| `bigtime_client_ids` | ARRAY<STRING> | Canonical company | `intermediate.int_cross_source_companies.source_company_id` where `source_system = 'bigtime'` | All BigTime client IDs mapped to the canonical company. | Preserves project-system source IDs for audit and source joins. |
| `source_system_count` | INT64 | Canonical company | Derived from bridge | Count of distinct source systems mapped to the canonical company. | Indicates cross-system coverage. |
| `has_manual_review_mapping` | BOOL | Canonical company | Derived from bridge `requires_manual_review` | True if any source mapping for the canonical company requires manual review. | Company-level mapping quality flag. |
| `min_match_confidence` | FLOAT64 | Canonical company | Derived from bridge `match_confidence` | Lowest match confidence across mapped source records. | Conservative company-level mapping confidence signal. |

## `fct_engagement_ledger_poc`

Model grain: one row per deterministic engagement event.

Primary key: `engagement_event_id`.

| Field | Data type | Grain | Source | Description | Business meaning |
|---|---|---|---|---|---|
| `engagement_event_id` | STRING | Engagement event | SHA256-derived deterministic ID | Stable event key generated from source type and source IDs. | Primary key for the consolidated engagement ledger. |
| `canonical_company_id` | STRING | Engagement event | Bridge lookup from `intermediate.int_cross_source_companies` | Canonical company ID when source company is matched. | Enables company-level aggregation across engagement systems. |
| `canonical_company_id_is_null` | BOOL | Engagement event | Derived from bridge lookup | True when no canonical company ID was found. | QA flag for unmatched engagement rows. |
| `source_company_id` | STRING | Engagement event | HubSpot deal company, OfficeRnD company, or BigTime client | Source-system company/client ID attached to the engagement. | Drill-through key to source system and bridge mapping. |
| `source_system` | STRING | Engagement event | Derived literal | Source system for the engagement row. | Identifies whether the event came from HubSpot, OfficeRnD, or BigTime. |
| `engagement_type` | STRING | Engagement event | Derived literal | Normalized high-level event type: deal, membership, or project. | Allows source-comparable engagement grouping. |
| `source_engagement_id` | STRING | Engagement event | Source event ID | Source-system engagement identifier. | Audit and drill-through key for the event. |
| `engagement_name` | STRING | Engagement event | Source event name | Human-readable engagement name. | Label for analysis and source review. |
| `engagement_subtype` | STRING | Engagement event | Deal type, membership category, or production status | Source-specific subtype normalized into one column. | Provides secondary event classification. |
| `engagement_status` | STRING | Engagement event | Derived from source status fields | Normalized status where possible. | Supports cross-source active/open/expired/won/lost style analysis. |
| `engagement_status_raw` | STRING | Engagement event | Source status field | Raw source status value. | Preserves source semantics for audit and debugging. |
| `start_date` | DATE | Engagement event | Source dates | Engagement start date or best available equivalent. | Timeline anchor for engagement reporting. |
| `end_date` | DATE | Engagement event | Source dates | Engagement end date when available. | Supports lifecycle and duration analysis. |
| `amount` | NUMERIC/FLOAT64 | Engagement event | Deal amount, membership price, or project budget fees | Monetary value associated with the engagement. | Financial or value proxy for engagement. Source semantics vary by event type. |
| `member_id` | STRING | Engagement event | OfficeRnD membership detail | OfficeRnD member ID for membership rows; null for other sources. | Enables member-level drill-through for OfficeRnD engagements. |
| `membership_id` | STRING | Engagement event | OfficeRnD membership detail | OfficeRnD membership ID for membership rows; null for other sources. | Enables membership-level drill-through and reconciliation. |
| `requires_manual_review` | BOOL | Engagement event | Bridge lookup | Mapping review flag for the source company. Defaults true when bridge match is absent. | Prevents questionable mappings from being hidden in engagement analysis. |
| `match_confidence` | FLOAT64 | Engagement event | Bridge lookup | Match confidence for the source company mapping. | Allows filtering or weighting by mapping confidence. |

## `mart_membership_status_poc`

Model grain: one row per month / OfficeRnD company / location / membership category / plan.

Primary key: `month_start`, `officernd_company_id`, `location_id`, `membership_category`, `plan_id`.

| Field | Data type | Grain | Source | Description | Business meaning |
|---|---|---|---|---|---|
| `month_start` | DATE | Membership month group | `intermediate.int_membership_months.month_start` | First day of the membership reporting month. | Monthly reporting period. |
| `canonical_company_id` | STRING | Membership month group | Bridge lookup from OfficeRnD company ID | Canonical company ID when mapped. | Enables membership reporting by canonical company. |
| `canonical_company_id_is_null` | BOOL | Membership month group | Derived from bridge lookup | True when OfficeRnD company has no canonical company mapping. | QA flag for unmatched membership rows. |
| `officernd_company_id` | STRING | Membership month group | `intermediate.int_membership_months.company_id` | OfficeRnD company ID. | Source-system company key for membership reporting and reconciliation. |
| `location_id` | STRING | Membership month group | `intermediate.int_membership_months.location_id` | OfficeRnD location ID. | Location-level reporting key. |
| `location_name` | STRING | Membership month group | `intermediate.int_membership_months.location_name` | OfficeRnD location name. | Human-readable location label. |
| `location_code` | STRING | Membership month group | `intermediate.int_membership_months.location_code` | OfficeRnD location code. | Compact location label for reporting. |
| `membership_category` | STRING | Membership month group | `COALESCE(int_membership_months.membership_category, 'Uncategorized')` | Normalized membership category. | Reconciles null categories to the existing mart convention. |
| `plan_id` | STRING | Membership month group | `intermediate.int_membership_months.plan_id` | OfficeRnD plan ID. | Plan-level membership reporting key. |
| `plan_name` | STRING | Membership month group | `intermediate.int_membership_months.plan_name` | OfficeRnD plan name. | Human-readable plan label. |
| `active_memberships` | INT64 | Membership month group | Count distinct `membership_id` | Number of distinct contracted memberships in the group. | Membership volume metric. |
| `active_members` | INT64 | Membership month group | Count distinct `member_id` | Number of distinct members in the group. | Member volume metric. |
| `total_mrr` | NUMERIC/FLOAT64 | Membership month group | Sum of `discounted_price` or `price` | Monthly recurring revenue for the group. | Primary membership revenue metric. |
| `total_calculated_list_price` | NUMERIC/FLOAT64 | Membership month group | Sum of `calculated_list_price`, `discounted_price`, or `price` | List-price value for the group. | Gross price baseline for discount analysis. |
| `total_calculated_discount_amount` | NUMERIC/FLOAT64 | Membership month group | Sum of `calculated_discount_amount` | Discount amount for the group. | Discount measurement for membership pricing. |
| `has_manual_review_mapping` | BOOL | Membership month group | Logical OR of bridge `requires_manual_review` | True when any mapped OfficeRnD company row in the group requires manual review. | Mapping quality flag for membership reporting. |
| `min_match_confidence` | FLOAT64 | Membership month group | Minimum bridge `match_confidence` | Lowest match confidence in the grouped membership rows. | Conservative mapping quality signal. |
| `observed_membership_statuses` | ARRAY<STRING> | Membership month group | Distinct `membership_status` values | Up to 10 observed statuses in the group. | Helps explain group composition and troubleshoot status logic. |

