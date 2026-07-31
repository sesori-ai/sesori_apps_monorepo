-- BigQuery Standard SQL. user_pseudo_id is used only as transient duplicate
-- identity; no installation identifier is persisted or grouped.
DECLARE raw_start_date DATE DEFAULT DATE(TIMESTAMP('{{RAW_EXPORT_START_AT}}'));
DECLARE latest_available_suffix_date DATE DEFAULT (
  SELECT MAX(PARSE_DATE('%Y%m%d', SUBSTR(table_name, 8)))
  FROM `{{PROJECT_ID}}.{{RAW_DATASET_ID}}.INFORMATION_SCHEMA.TABLES`
  WHERE table_type = 'BASE TABLE'
    AND REGEXP_CONTAINS(table_name, r'^events_\d{8}$')
);
DECLARE scan_end_date DATE DEFAULT LEAST(
  DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY),
  DATE_SUB(latest_available_suffix_date, INTERVAL 1 DAY)
);
DECLARE previous_source_end_date DATE DEFAULT (
  SELECT source_end_date
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name = 'installation_login_daily'
  LIMIT 1
);
DECLARE previous_completed_at TIMESTAMP DEFAULT (
  SELECT completed_at
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
WITH raw_events AS (
  SELECT
    DATE(TIMESTAMP_MICROS(event_timestamp)) AS source_export_date,
    DATE(TIMESTAMP_MICROS(event_timestamp)) AS event_date,
    TIMESTAMP_MICROS(event_timestamp) AS emitted_at,
    event_timestamp,
    user_pseudo_id,
    event_bundle_sequence_id,
    batch_event_index,
    event_name,
    platform,
    app_info.version AS app_version,
    event_params,
    CASE
      WHEN event_name = 'login_attempt_failed' THEN ['schema_version', 'provider', 'failure_kind']
      ELSE ['schema_version', 'provider']
    END AS required_parameter_names
  FROM `{{PROJECT_ID}}.{{RAW_DATASET_ID}}.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(scan_start_date, INTERVAL 1 DAY))
    AND FORMAT_DATE('%Y%m%d', DATE_ADD(scan_end_date, INTERVAL 1 DAY))
    AND REGEXP_CONTAINS(_TABLE_SUFFIX, r'^\d{8}$')
    AND event_timestamp >= UNIX_MICROS(TIMESTAMP('{{RAW_EXPORT_START_AT}}'))
    AND DATE(TIMESTAMP_MICROS(event_timestamp)) BETWEEN scan_start_date AND scan_end_date
    AND event_name IN ('login_attempt_started', 'login_attempt_completed', 'login_attempt_failed')
),
parameterized AS (
  SELECT
    raw.* EXCEPT (event_params),
    (
      SELECT AS STRUCT
        MAX(IF(parameter.key = 'schema_version', parameter.value.int_value, NULL)) AS schema_version,
        MAX(IF(parameter.key = 'provider', parameter.value.string_value, NULL)) AS provider,
        MAX(IF(parameter.key = 'failure_kind', parameter.value.string_value, NULL)) AS failure_kind,
        COUNTIF(parameter.key = 'failure_kind') AS failure_kind_parameter_count,
        COUNTIF(parameter.key IN UNNEST(raw.required_parameter_names)) AS required_parameter_count,
        COUNT(DISTINCT IF(parameter.key IN UNNEST(raw.required_parameter_names), parameter.key, NULL)) AS distinct_required_parameter_count,
        COUNTIF(
          parameter.key IN UNNEST(raw.required_parameter_names)
          AND (
            (
              parameter.key = 'schema_version'
              AND parameter.value.int_value IS NOT NULL
              AND parameter.value.string_value IS NULL
              AND parameter.value.float_value IS NULL
              AND parameter.value.double_value IS NULL
            )
            OR (
              parameter.key != 'schema_version'
              AND parameter.value.string_value IS NOT NULL
              AND parameter.value.int_value IS NULL
              AND parameter.value.float_value IS NULL
              AND parameter.value.double_value IS NULL
            )
          )
        ) AS correctly_typed_required_parameter_count
      FROM UNNEST(raw.event_params) AS parameter
    ) AS parameters
  FROM raw_events AS raw
),
contract_checked AS (
  SELECT
    parameterized.* EXCEPT (parameters),
    parameters.*,
    parameters.required_parameter_count = ARRAY_LENGTH(required_parameter_names)
      AND parameters.distinct_required_parameter_count = ARRAY_LENGTH(required_parameter_names)
      AND parameters.correctly_typed_required_parameter_count = ARRAY_LENGTH(required_parameter_names)
      AS parameter_shape_valid,
    event_name = 'login_attempt_failed' OR parameters.failure_kind_parameter_count = 0
      AS parameter_semantics_valid,
    parameters.provider IN ('github', 'google', 'apple', 'email')
      AND (
        event_name != 'login_attempt_failed'
        OR parameters.failure_kind IN ('authentication', 'launch', 'cancelled', 'timeout', 'unknown')
      ) AS bounded_enum_valid
  FROM parameterized
),
deduplicated AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY
        user_pseudo_id,
        event_name,
        event_timestamp,
        event_bundle_sequence_id,
        batch_event_index,
        schema_version,
        platform,
        app_version,
        provider,
        failure_kind,
        parameter_shape_valid,
        parameter_semantics_valid,
        bounded_enum_valid
      ORDER BY event_timestamp
    ) AS duplicate_rank
  FROM contract_checked
)
SELECT * FROM deduplicated;

CREATE TEMP TABLE login_stage AS
SELECT
  source_export_date,
  event_date,
  event_name,
  schema_version,
  platform,
  app_version,
  provider,
  IF(event_name = 'login_attempt_failed', failure_kind, NULL) AS failure_kind,
  COUNT(*) AS event_count,
  TRUE AS includes_internal_test_traffic,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM login_candidate_stage
WHERE duplicate_rank = 1
  AND schema_version = 1
  AND parameter_shape_valid
  AND parameter_semantics_valid
  AND bounded_enum_valid
GROUP BY source_export_date, event_date, event_name, schema_version, platform, app_version, provider, failure_kind;

CREATE TEMP TABLE quality_stage AS
SELECT
  COUNT(*) AS source_rows,
  COUNTIF(duplicate_rank = 1) AS deduplicated_rows,
  COALESCE((SELECT SUM(event_count) FROM login_stage), 0) AS published_rows,
  COUNTIF(duplicate_rank = 1 AND schema_version IS NULL) AS missing_schema_rows,
  COUNTIF(duplicate_rank = 1 AND schema_version IS NOT NULL AND schema_version != 1) AS unsupported_schema_rows,
  COUNTIF(
    duplicate_rank = 1
    AND (
      parameter_shape_valid IS NOT TRUE
      OR parameter_semantics_valid IS NOT TRUE
    )
  ) AS invalid_parameter_rows,
  COUNTIF(
    duplicate_rank = 1
    AND parameter_shape_valid
    AND parameter_semantics_valid
    AND bounded_enum_valid IS NOT TRUE
  ) AS unknown_enum_rows,
  MAX(emitted_at) AS latest_emitted_at
FROM login_candidate_stage;

ASSERT previous_source_end_date IS NOT DISTINCT FROM (
  SELECT source_end_date
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name = 'installation_login_daily'
  LIMIT 1
) AND previous_completed_at IS NOT DISTINCT FROM (
  SELECT completed_at
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name = 'installation_login_daily'
  LIMIT 1
) AS 'installation_login_daily state changed while the transform was staged';

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
WHEN MATCHED
  AND target.source_end_date IS NOT DISTINCT FROM previous_source_end_date
  AND target.completed_at IS NOT DISTINCT FROM previous_completed_at
THEN UPDATE SET
  source_start_date = scan_start_date,
  source_end_date = scan_end_date,
  completed_at = CURRENT_TIMESTAMP(),
  auth_snapshot_published_at = NULL,
  source_rows = source.source_rows,
  deduplicated_rows = source.deduplicated_rows,
  published_rows = source.published_rows,
  missing_identity_rows = 0,
  malformed_identity_rows = 0,
  missing_schema_rows = source.missing_schema_rows,
  unsupported_schema_rows = source.unsupported_schema_rows,
  missing_occurrence_rows = 0,
  future_occurrence_rows = 0,
  before_account_rows = 0,
  invalid_parameter_rows = source.invalid_parameter_rows,
  unknown_enum_rows = source.unknown_enum_rows,
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
  source.deduplicated_rows,
  source.published_rows,
  0,
  0,
  source.missing_schema_rows,
  source.unsupported_schema_rows,
  0,
  0,
  0,
  source.invalid_parameter_rows,
  source.unknown_enum_rows,
  0,
  0,
  0,
  source.latest_emitted_at,
  NULL
);
ASSERT @@row_count = 1
  AS 'installation_login_daily state changed before watermark publication';

COMMIT TRANSACTION;
