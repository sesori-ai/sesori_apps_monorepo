-- BigQuery Standard SQL. Rebuild mutable GA4 daily exports plus any watermark gap.
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
  WHERE model_name = 'events_flattened'
  LIMIT 1
);
DECLARE scan_start_date DATE;
DECLARE rows_inserted INT64 DEFAULT 0;

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
  AS 'The flattened-event watermark gap exceeds the recoverable 90-day raw window';

-- Only approved scalar metadata is materialized. Bundle fields are transiently
-- used for duplicate removal and never enter a curated table.
CREATE TEMP TABLE candidate_stage AS
WITH extracted AS (
  SELECT
    event_name,
    PARSE_DATE('%Y%m%d', _TABLE_SUFFIX) AS source_export_date,
    event_timestamp,
    event_bundle_sequence_id,
    batch_event_index,
    platform,
    app_info.version AS app_version,
    (SELECT ANY_VALUE(COALESCE(value.string_value, CAST(value.int_value AS STRING))) FROM UNNEST(event_params) WHERE key = 'app_build') AS app_build,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'user_key') AS user_key,
    (SELECT ANY_VALUE(COALESCE(value.int_value, SAFE_CAST(value.string_value AS INT64))) FROM UNNEST(event_params) WHERE key = 'schema_version') AS schema_version,
    (SELECT ANY_VALUE(COALESCE(value.int_value, SAFE_CAST(value.string_value AS INT64))) FROM UNNEST(event_params) WHERE key = 'occurred_at_micros') AS occurred_at_micros,
    (SELECT ANY_VALUE(COALESCE(value.int_value, SAFE_CAST(value.string_value AS INT64))) FROM UNNEST(event_params) WHERE key = 'activation_schema_version') AS activation_schema_version,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'inventory_state') AS inventory_state,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'activity_state') AS activity_state,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'submission_kind') AS submission_kind,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'input_mode') AS input_mode,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'workspace_kind') AS workspace_kind,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'failure_reason') AS failure_reason,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'decision') AS decision,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'change_state') AS change_state,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'surface') AS surface,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'channel') AS channel,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'method') AS method,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'os') AS os,
    (SELECT ANY_VALUE(value.string_value) FROM UNNEST(event_params) WHERE key = 'screen') AS screen
  FROM `{{PROJECT_ID}}.{{RAW_DATASET_ID}}.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', scan_start_date) AND FORMAT_DATE('%Y%m%d', scan_end_date)
    AND REGEXP_CONTAINS(_TABLE_SUFFIX, r'^\d{8}$')
    AND event_timestamp >= UNIX_MICROS(TIMESTAMP('{{RAW_EXPORT_START_AT}}'))
    AND event_name IN (
      'analytics_schema_ready',
      'analytics_activation_ready',
      'project_inventory_loaded',
      'session_activity_viewed',
      'session_message_sent',
      'session_created_with_message',
      'session_creation_failed',
      'voice_transcription_completed',
      'session_question_answered',
      'session_question_rejected',
      'session_permission_answered',
      'session_abort_succeeded',
      'session_diff_viewed',
      'onboarding_need_help_opened',
      'onboarding_support_link_opened',
      'onboarding_why_bridge_opened',
      'bridge_install_command_copied',
      'bridge_install_command_shared',
      'bridge_run_command_copied',
      'bridge_run_command_shared',
      'product_screen_viewed'
    )
),
timestamped AS (
  SELECT
    *,
    TIMESTAMP_MICROS(event_timestamp) AS emitted_at,
    CASE
      WHEN occurred_at_micros BETWEEN
        UNIX_MICROS(TIMESTAMP '0001-01-01 00:00:00+00') AND
        UNIX_MICROS(TIMESTAMP '9999-12-31 23:59:59.999999+00')
      THEN TIMESTAMP_MICROS(occurred_at_micros)
    END AS occurred_at
  FROM extracted
),
contract_checked AS (
  SELECT
    *,
    CASE event_name
      WHEN 'analytics_schema_ready' THEN TRUE
      WHEN 'analytics_activation_ready' THEN activation_schema_version = 1
      WHEN 'project_inventory_loaded' THEN inventory_state IN ('empty', 'non_empty')
      WHEN 'session_activity_viewed' THEN activity_state IN ('empty', 'non_empty')
      WHEN 'session_message_sent' THEN
        submission_kind IN ('text', 'command')
        AND input_mode IN ('typed', 'voice_assisted')
        AND (submission_kind != 'command' OR input_mode = 'typed')
      WHEN 'session_created_with_message' THEN
        submission_kind IN ('text', 'command')
        AND input_mode IN ('typed', 'voice_assisted')
        AND (submission_kind != 'command' OR input_mode = 'typed')
        AND workspace_kind IN ('project', 'dedicated_worktree')
      WHEN 'session_creation_failed' THEN
        failure_reason IN ('not_authenticated', 'server_rejected', 'network_down', 'bad_response', 'unknown')
        AND workspace_kind IN ('project', 'dedicated_worktree')
      WHEN 'voice_transcription_completed' THEN TRUE
      WHEN 'session_question_answered' THEN TRUE
      WHEN 'session_question_rejected' THEN TRUE
      WHEN 'session_permission_answered' THEN decision IN ('once', 'always', 'reject')
      WHEN 'session_abort_succeeded' THEN TRUE
      WHEN 'session_diff_viewed' THEN change_state IN ('empty', 'non_empty')
      WHEN 'onboarding_need_help_opened' THEN surface IN ('connect_setup', 'connected_empty', 'bridge_offline')
      WHEN 'onboarding_support_link_opened' THEN
        surface IN ('connect_setup', 'connected_empty', 'bridge_offline')
        AND channel IN ('email', 'discord', 'x')
      WHEN 'onboarding_why_bridge_opened' THEN surface IN ('connect_setup', 'connected_empty', 'bridge_offline')
      WHEN 'bridge_install_command_copied' THEN
        surface IN ('connect_setup', 'connected_empty', 'bridge_offline')
        AND method IN ('curl', 'powershell', 'npm', 'bun')
        AND os IN ('unix', 'windows')
      WHEN 'bridge_install_command_shared' THEN
        surface IN ('connect_setup', 'connected_empty', 'bridge_offline')
        AND method IN ('curl', 'powershell', 'npm', 'bun')
        AND os IN ('unix', 'windows')
      WHEN 'bridge_run_command_copied' THEN surface IN ('connect_setup', 'connected_empty', 'bridge_offline')
      WHEN 'bridge_run_command_shared' THEN surface IN ('connect_setup', 'connected_empty', 'bridge_offline')
      WHEN 'product_screen_viewed' THEN screen IN (
        'login',
        'projects',
        'settings',
        'settings_notifications',
        'settings_profile',
        'sessions',
        'new_session',
        'session_detail',
        'session_diffs'
      )
      ELSE FALSE
    END AS contract_valid
  FROM timestamped
),
deduplicated AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY
        event_name,
        source_export_date,
        event_timestamp,
        event_bundle_sequence_id,
        batch_event_index,
        user_key,
        schema_version,
        occurred_at_micros,
        platform,
        app_version,
        app_build,
        activation_schema_version,
        inventory_state,
        activity_state,
        submission_kind,
        input_mode,
        workspace_kind,
        failure_reason,
        decision,
        change_state,
        surface,
        channel,
        method,
        os,
        screen
      ORDER BY event_timestamp
    ) AS duplicate_rank
  FROM contract_checked
),
internal_keys AS (
  SELECT DISTINCT user_key
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions`
),
deleted_keys AS (
  SELECT DISTINCT user_key
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions`
)
SELECT
  source.*,
  internal_keys.user_key IS NOT NULL AS is_internal_excluded,
  deleted_keys.user_key IS NOT NULL AS is_deletion_excluded
FROM deduplicated AS source
LEFT JOIN internal_keys USING (user_key)
LEFT JOIN deleted_keys USING (user_key);

CREATE TEMP TABLE flattened_stage AS
SELECT
  event_name,
  source_export_date,
  emitted_at,
  occurred_at_micros,
  occurred_at,
  schema_version,
  user_key,
  platform,
  app_version,
  app_build,
  IF(event_name = 'analytics_activation_ready', activation_schema_version, NULL) AS activation_schema_version,
  IF(event_name = 'project_inventory_loaded', inventory_state, NULL) AS inventory_state,
  IF(event_name = 'session_activity_viewed', activity_state, NULL) AS activity_state,
  IF(event_name IN ('session_message_sent', 'session_created_with_message'), submission_kind, NULL) AS submission_kind,
  IF(event_name IN ('session_message_sent', 'session_created_with_message'), input_mode, NULL) AS input_mode,
  IF(event_name IN ('session_created_with_message', 'session_creation_failed'), workspace_kind, NULL) AS workspace_kind,
  IF(event_name = 'session_creation_failed', failure_reason, NULL) AS failure_reason,
  IF(event_name = 'session_permission_answered', decision, NULL) AS decision,
  IF(event_name = 'session_diff_viewed', change_state, NULL) AS change_state,
  IF(
    event_name IN (
      'onboarding_need_help_opened',
      'onboarding_support_link_opened',
      'onboarding_why_bridge_opened',
      'bridge_install_command_copied',
      'bridge_install_command_shared',
      'bridge_run_command_copied',
      'bridge_run_command_shared'
    ),
    surface,
    NULL
  ) AS surface,
  IF(event_name = 'onboarding_support_link_opened', channel, NULL) AS channel,
  IF(event_name IN ('bridge_install_command_copied', 'bridge_install_command_shared'), method, NULL) AS method,
  IF(event_name IN ('bridge_install_command_copied', 'bridge_install_command_shared'), os, NULL) AS os,
  IF(event_name = 'product_screen_viewed', screen, NULL) AS screen
FROM candidate_stage
WHERE duplicate_rank = 1
  AND schema_version = 1
  AND REGEXP_CONTAINS(user_key, r'^[a-f0-9]{64}$')
  AND occurred_at IS NOT NULL
  -- Five minutes is the pinned client-clock allowance. Later occurrence is
  -- rejected rather than silently replaced with Firebase emission time.
  AND occurred_at <= TIMESTAMP_ADD(emitted_at, INTERVAL 300 SECOND)
  AND contract_valid
  AND NOT is_internal_excluded
  AND NOT is_deletion_excluded;

CREATE TEMP TABLE quality_stage AS
SELECT
  COUNT(*) AS source_rows,
  COUNTIF(duplicate_rank = 1) AS deduplicated_rows,
  (SELECT COUNT(*) FROM flattened_stage) AS published_rows,
  COUNTIF(duplicate_rank = 1 AND user_key IS NULL) AS missing_identity_rows,
  COUNTIF(duplicate_rank = 1 AND user_key IS NOT NULL AND NOT REGEXP_CONTAINS(user_key, r'^[a-f0-9]{64}$')) AS malformed_identity_rows,
  COUNTIF(duplicate_rank = 1 AND schema_version IS NULL) AS missing_schema_rows,
  COUNTIF(duplicate_rank = 1 AND schema_version IS NOT NULL AND schema_version != 1) AS unsupported_schema_rows,
  COUNTIF(duplicate_rank = 1 AND occurred_at IS NULL) AS missing_occurrence_rows,
  COUNTIF(duplicate_rank = 1 AND occurred_at > TIMESTAMP_ADD(emitted_at, INTERVAL 300 SECOND)) AS future_occurrence_rows,
  COUNTIF(
    duplicate_rank = 1
    AND schema_version = 1
    AND REGEXP_CONTAINS(user_key, r'^[a-f0-9]{64}$')
    AND occurred_at IS NOT NULL
    AND occurred_at <= TIMESTAMP_ADD(emitted_at, INTERVAL 300 SECOND)
    AND contract_valid IS NOT TRUE
  ) AS invalid_parameter_rows,
  COUNTIF(
    duplicate_rank = 1
    AND schema_version = 1
    AND REGEXP_CONTAINS(user_key, r'^[a-f0-9]{64}$')
    AND occurred_at IS NOT NULL
    AND occurred_at <= TIMESTAMP_ADD(emitted_at, INTERVAL 300 SECOND)
    AND contract_valid IS NOT TRUE
  ) AS unknown_enum_rows,
  COUNTIF(duplicate_rank = 1 AND is_internal_excluded) AS internal_excluded_rows,
  COUNTIF(duplicate_rank = 1 AND is_deletion_excluded) AS deletion_excluded_rows,
  MAX(emitted_at) AS latest_emitted_at,
  MAX(IF(occurred_at <= TIMESTAMP_ADD(emitted_at, INTERVAL 300 SECOND), occurred_at, NULL)) AS latest_occurred_at
FROM candidate_stage;

BEGIN TRANSACTION;

-- The broad partition predicate lets a newly added permanent tombstone remove
-- every retained keyed fact, not just the three mutable source dates.
DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened`
WHERE source_export_date >= raw_start_date
  AND (
    source_export_date BETWEEN scan_start_date AND scan_end_date
    OR user_key IN (
      SELECT user_key FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions`
    )
    OR user_key IN (
      SELECT user_key FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions`
    )
  );

INSERT INTO `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened` (
  event_name,
  source_export_date,
  emitted_at,
  occurred_at_micros,
  occurred_at,
  schema_version,
  user_key,
  platform,
  app_version,
  app_build,
  activation_schema_version,
  inventory_state,
  activity_state,
  submission_kind,
  input_mode,
  workspace_kind,
  failure_reason,
  decision,
  change_state,
  surface,
  channel,
  method,
  os,
  screen
)
SELECT stage.*
FROM flattened_stage AS stage
WHERE NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions` AS internal
  WHERE internal.user_key = stage.user_key
)
AND NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions` AS deleted
  WHERE deleted.user_key = stage.user_key
);
SET rows_inserted = @@row_count;

MERGE `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state` AS target
USING (
  SELECT
    'events_flattened' AS model_name,
    quality.*
  FROM quality_stage AS quality
) AS source
ON target.model_name = source.model_name
WHEN MATCHED THEN UPDATE SET
  source_start_date = scan_start_date,
  source_end_date = scan_end_date,
  completed_at = CURRENT_TIMESTAMP(),
  auth_snapshot_published_at = NULL,
  source_rows = source.source_rows,
  deduplicated_rows = source.deduplicated_rows,
  published_rows = rows_inserted,
  missing_identity_rows = source.missing_identity_rows,
  malformed_identity_rows = source.malformed_identity_rows,
  missing_schema_rows = source.missing_schema_rows,
  unsupported_schema_rows = source.unsupported_schema_rows,
  missing_occurrence_rows = source.missing_occurrence_rows,
  future_occurrence_rows = source.future_occurrence_rows,
  before_account_rows = 0,
  invalid_parameter_rows = source.invalid_parameter_rows,
  unknown_enum_rows = source.unknown_enum_rows,
  internal_excluded_rows = source.internal_excluded_rows,
  deletion_excluded_rows = source.deletion_excluded_rows,
  ineligible_user_rows = 0,
  latest_emitted_at = source.latest_emitted_at,
  latest_occurred_at = source.latest_occurred_at
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
  rows_inserted,
  source.missing_identity_rows,
  source.malformed_identity_rows,
  source.missing_schema_rows,
  source.unsupported_schema_rows,
  source.missing_occurrence_rows,
  source.future_occurrence_rows,
  0,
  source.invalid_parameter_rows,
  source.unknown_enum_rows,
  source.internal_excluded_rows,
  source.deletion_excluded_rows,
  0,
  source.latest_emitted_at,
  source.latest_occurred_at
);

COMMIT TRANSACTION;
