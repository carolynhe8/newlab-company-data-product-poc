-- Deployment step 00: create target dataset if needed.
--
-- Do not run until the production target dataset and location are approved.
-- This script is optional if the target dataset already exists.

DECLARE target_project STRING DEFAULT 'datahub-prod-477220';
DECLARE target_dataset STRING DEFAULT 'company_data'; -- TODO: replace with approved production dataset.
DECLARE target_location STRING DEFAULT 'US'; -- TODO: confirm BigQuery dataset location.

EXECUTE IMMEDIATE FORMAT("""
CREATE SCHEMA IF NOT EXISTS `%s.%s`
OPTIONS(location = '%s')
""", target_project, target_dataset, target_location);

