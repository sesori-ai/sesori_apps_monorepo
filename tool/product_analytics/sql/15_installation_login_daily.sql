-- BigQuery Standard SQL. This transform intentionally never reads or carries an
-- installation identifier; its unit is an account-less login event count.
DECLARE raw_start_date DATE DEFAULT DATE(TIMESTAMP('{{RAW_EXPORT_START_AT}}'));
DECLARE latest_available_source_date DATE DEFAULT (
  SELECT MAX(PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8)))
  FROM `{{PROJECT_ID}}.{{RAW_DATASET_ID}}.INFORMATION_SCHEMA.TABLES`
  WHERE table_type = 'BASE TABLE'
    AND REGEXP_CONTAINS(table_name, r'^events_\d{8}$')
);
DECLARE scan_end_date DATE DEFAULT LEAST(
  DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY),
  latest_available_source_date
);
DECLARE previous_source_end_date DATE DEFAULT (
  SELECT source_end_date
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name = 'installation_login_daily'
  LIMIT 1
);
DECLARE scan_start_date DATE;

SET scan_start_date = GREATEST(
  raw_start_date,
  IF(
    previous_source_end_date IS NULL,
    raw_start_date,
    LEAST(
      DATE_ADD(previous_source_end_date, INTERVAL 1 DAY),
      DATE_SUB(scan_end_date, INTERVAL 2 DAY)
    )
  )
);

ASSERT scan_start_date <= scan_end_date
  AS 'No complete GA4 daily export is available at or after raw_export_start_at';
ASSERT previous_source_end_date IS NULL OR scan_end_date >= previous_source_end_date
  AS 'The latest available GA4 daily export regressed behind the published watermark';
ASSERT scan_start_date >= DATE_SUB(scan_end_date, INTERVAL 89 DAY)
  AS 'The login watermark gap exceeds the recoverable 90-day raw window';

CREATE TEMP TABLE login_candidate_stage AS
SELECT
  PARSE_DATE('%Y%m%d', _TABLE_SUFFIX) AS source_export_date,
  DATE(TIMESTAMP_MICROS(event_timestamp)) AS event_date,
  TIMESTAMP_MICROS(event_timestamp) AS emitted_at,
  event_name,
  platform,
  app_info.version AS app_version,
  (SELECT ANY_VALUE(COALESCE(value.string_value, CAST(value.int_value AS STRING))) FROM UNNEST(event_params) WHERE key = 'app_build') AS app_build,
  (SELECT ANY_VALUE(COALESCE(value.int_value, SAFE_CAST(value.string_value AS INT64))) FROM UNNEST(event_params) WHERE key = 'schema_version') AS schema_version,
  (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'provider') AS provider,
  (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'failure_kind') AS failure_kind
FROM `{{PROJECT_ID}}.{{RAW_DATASET_ID}}.events_*`
WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', scan_start_date) AND FORMAT_DATE('%Y%m%d', scan_end_date)
  AND REGEXP_CONTAINS(_TABLE_SUFFIX, r'^\d{8}$')
  AND event_timestamp >= UNIX_MICROS(TIMESTAMP('{{RAW_EXPORT_START_AT}}'))
  AND event_name IN ('login_attempt_started', 'login_attempt_completed', 'login_attempt_failed');

CREATE TEMP TABLE login_stage AS
SELECT
  source_export_date,
  event_date,
  event_name,
  schema_version,
  platform,
  app_version,
  app_build,
  provider,
  IF(event_name = 'login_attempt_failed', failure_kind, NULL) AS failure_kind,
  COUNT(*) AS event_count,
  TRUE AS includes_internal_test_traffic,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM login_candidate_stage
WHERE schema_version = 1
  AND provider IN ('github', 'google', 'apple', 'email')
  AND (
    (event_name IN ('login_attempt_started', 'login_attempt_completed') AND failure_kind IS NULL)
    OR (event_name = 'login_attempt_failed' AND failure_kind IN ('authentication', 'launch', 'cancelled', 'timeout', 'unknown'))
  )
GROUP BY source_export_date, event_date, event_name, schema_version, platform, app_version, app_build, provider, failure_kind;

CREATE TEMP TABLE quality_stage AS
SELECT
  COUNT(*) AS source_rows,
  COALESCE((SELECT SUM(event_count) FROM login_stage), 0) AS published_rows,
  COUNTIF(schema_version IS NULL) AS missing_schema_rows,
  COUNTIF(schema_version IS NOT NULL AND schema_version != 1) AS unsupported_schema_rows,
  COUNTIF(
    schema_version = 1
    AND COALESCE((
      provider IN ('github', 'google', 'apple', 'email')
      AND (
        (event_name IN ('login_attempt_started', 'login_attempt_completed') AND failure_kind IS NULL)
        OR (event_name = 'login_attempt_failed' AND failure_kind IN ('authentication', 'launch', 'cancelled', 'timeout', 'unknown'))
      )
    ), FALSE) = FALSE
  ) AS invalid_parameter_rows,
  MAX(emitted_at) AS latest_emitted_at
FROM login_candidate_stage;

BEGIN TRANSACTION;

DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.installation_login_daily`
WHERE source_export_date BETWEEN scan_start_date AND scan_end_date;

INSERT INTO `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.installation_login_daily` (
  source_export_date,
  event_date,
  event_name,
  schema_version,
  platform,
  app_version,
  app_build,
  provider,
  failure_kind,
  event_count,
  includes_internal_test_traffic,
  refreshed_at
)
SELECT * FROM login_stage;

MERGE `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state` AS target
USING (
  SELECT 'installation_login_daily' AS model_name, quality.*
  FROM quality_stage AS quality
) AS source
ON target.model_name = source.model_name
WHEN MATCHED THEN UPDATE SET
  source_start_date = scan_start_date,
  source_end_date = scan_end_date,
  completed_at = CURRENT_TIMESTAMP(),
  auth_snapshot_published_at = NULL,
  source_rows = source.source_rows,
  deduplicated_rows = source.source_rows,
  published_rows = source.published_rows,
  missing_identity_rows = 0,
  malformed_identity_rows = 0,
  missing_schema_rows = source.missing_schema_rows,
  unsupported_schema_rows = source.unsupported_schema_rows,
  missing_occurrence_rows = 0,
  future_occurrence_rows = 0,
  before_account_rows = 0,
  invalid_parameter_rows = source.invalid_parameter_rows,
  unknown_enum_rows = source.invalid_parameter_rows,
  internal_excluded_rows = 0,
  deletion_excluded_rows = 0,
  ineligible_user_rows = 0,
  latest_emitted_at = source.latest_emitted_at,
  latest_occurred_at = NULL
WHEN NOT MATCHED THEN INSERT (
  model_name,
  source_start_date,
  source_end_date,
  completed_at,
  auth_snapshot_published_at,
  source_rows,
  deduplicated_rows,
  published_rows,
  missing_identity_rows,
  malformed_identity_rows,
  missing_schema_rows,
  unsupported_schema_rows,
  missing_occurrence_rows,
  future_occurrence_rows,
  before_account_rows,
  invalid_parameter_rows,
  unknown_enum_rows,
  internal_excluded_rows,
  deletion_excluded_rows,
  ineligible_user_rows,
  latest_emitted_at,
  latest_occurred_at
) VALUES (
  source.model_name,
  scan_start_date,
  scan_end_date,
  CURRENT_TIMESTAMP(),
  NULL,
  source.source_rows,
  source.source_rows,
  source.published_rows,
  0,
  0,
  source.missing_schema_rows,
  source.unsupported_schema_rows,
  0,
  0,
  0,
  source.invalid_parameter_rows,
  source.invalid_parameter_rows,
  0,
  0,
  0,
  source.latest_emitted_at,
  NULL
);

COMMIT TRANSACTION;
