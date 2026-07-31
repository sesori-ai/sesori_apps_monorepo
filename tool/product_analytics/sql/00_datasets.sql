-- BigQuery Standard SQL. The query job location must match the Firebase export.
ASSERT TIMESTAMP('{{RAW_EXPORT_START_AT}}') <= TIMESTAMP('{{BEHAVIORAL_SCHEMA_V1_START_AT}}')
  AS 'behavioral_schema_v1_start_at must not precede raw_export_start_at';
ASSERT TIMESTAMP('{{RAW_EXPORT_START_AT}}') <= CURRENT_TIMESTAMP()
  AS 'raw_export_start_at must not be in the future';
ASSERT TIMESTAMP('{{BEHAVIORAL_SCHEMA_V1_START_AT}}') <= CURRENT_TIMESTAMP()
  AS 'behavioral_schema_v1_start_at must not be in the future';

CREATE SCHEMA IF NOT EXISTS `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}`;
CREATE SCHEMA IF NOT EXISTS `{{PROJECT_ID}}.{{PRIVACY_DATASET_ID}}`;
CREATE SCHEMA IF NOT EXISTS `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}`;
CREATE SCHEMA IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}`;
CREATE SCHEMA IF NOT EXISTS `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}`;

ALTER SCHEMA `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}`
SET OPTIONS (description = 'Restricted current auth eligibility and identifier-free setup cohorts');
ALTER SCHEMA `{{PROJECT_ID}}.{{PRIVACY_DATASET_ID}}`
SET OPTIONS (description = 'Restricted product analytics privacy-deletion handoff');
ALTER SCHEMA `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}`
SET OPTIONS (description = 'Restricted permanent exclusions and analytics measurement controls');
ALTER SCHEMA `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}`
SET OPTIONS (description = 'Minimized pseudonymous product analytics facts and aggregates');
ALTER SCHEMA `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}`
SET OPTIONS (description = 'Identifier-free authorized product analytics views');

-- These four schemas intentionally match the auth export repository exactly.
CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_user_milestones` (
  user_key STRING NOT NULL,
  account_created_at TIMESTAMP NOT NULL,
  notification_registered_at TIMESTAMP,
  bridge_registered_at TIMESTAMP,
  legacy_first_metadata_request_at TIMESTAMP,
  exported_at TIMESTAMP NOT NULL
)
CLUSTER BY user_key
OPTIONS (description = 'Current analytics-eligible auth snapshot; replaced atomically by the auth export');

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_weekly_setup_cohorts` (
  cohort_week DATE NOT NULL,
  total_accounts INT64 NOT NULL,
  enabled_accounts INT64 NOT NULL,
  notification_registered_within_1_day INT64 NOT NULL,
  notification_registered_within_7_days INT64 NOT NULL,
  notification_registered_within_30_days INT64 NOT NULL,
  bridge_registered_within_1_day INT64 NOT NULL,
  bridge_registered_within_7_days INT64 NOT NULL,
  bridge_registered_within_30_days INT64 NOT NULL,
  legacy_first_metadata_request_within_1_day INT64 NOT NULL,
  legacy_first_metadata_request_within_7_days INT64 NOT NULL,
  legacy_first_metadata_request_within_30_days INT64 NOT NULL,
  exported_at TIMESTAMP NOT NULL
)
OPTIONS (description = 'Identifier-free external-account setup cohorts from the auth export');

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.product_analytics_export_runs` (
  run_id STRING NOT NULL,
  run_cutoff TIMESTAMP NOT NULL,
  preference_scan_cutoff TIMESTAMP NOT NULL,
  control_updated_at TIMESTAMP NOT NULL,
  users_scanned INT64 NOT NULL,
  source_suppressed_users INT64 NOT NULL,
  internal_users INT64 NOT NULL,
  external_accounts INT64 NOT NULL,
  enabled_accounts INT64 NOT NULL,
  opted_out_accounts INT64 NOT NULL,
  preference_after_cutoff_accounts INT64 NOT NULL,
  late_preference_rows_removed INT64 NOT NULL,
  milestone_rows_published INT64 NOT NULL,
  cohort_rows_published INT64 NOT NULL,
  published_at TIMESTAMP NOT NULL
)
PARTITION BY DATE(published_at)
OPTIONS (description = 'Successful auth export metadata without source account identifiers');

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.product_analytics_export_state` (
  state_key STRING NOT NULL,
  active_run_id STRING,
  lease_expires_at TIMESTAMP,
  last_published_run_id STRING,
  last_published_cutoff TIMESTAMP,
  updated_at TIMESTAMP NOT NULL
)
OPTIONS (description = 'Singleton lease and monotonic auth export publication state');

MERGE `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.product_analytics_export_state` AS target
USING (SELECT 'singleton' AS state_key) AS source
ON target.state_key = source.state_key
WHEN NOT MATCHED THEN
  INSERT (state_key, active_run_id, lease_expires_at, last_published_run_id, last_published_cutoff, updated_at)
  VALUES ('singleton', NULL, NULL, NULL, NULL, CURRENT_TIMESTAMP());

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{PRIVACY_DATASET_ID}}.product_analytics_deletion_targets` (
  request_id STRING NOT NULL,
  user_key STRING NOT NULL,
  legacy_firebase_user_id STRING NOT NULL,
  suppressed_at TIMESTAMP NOT NULL,
  status STRING NOT NULL,
  last_error_code STRING,
  completed_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
)
CLUSTER BY request_id
OPTIONS (description = 'Restricted auth-to-deletion-job handoff; never exposed to reporting');

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.analytics_measurement_config` (
  config_key STRING NOT NULL,
  raw_export_start_at TIMESTAMP NOT NULL,
  behavioral_schema_v1_start_at TIMESTAMP NOT NULL,
  clock_skew_allowance_seconds INT64 NOT NULL,
  auth_snapshot_max_age_hours INT64 NOT NULL,
  raw_late_arrival_days INT64 NOT NULL,
  updated_at TIMESTAMP NOT NULL
)
OPTIONS (description = 'Singleton pinned analytics measurement boundaries and freshness policy');

ASSERT (
  SELECT COUNT(*) = 0 OR (COUNT(*) = 1 AND COUNTIF(config_key = 'singleton') = 1)
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.analytics_measurement_config`
) AS 'analytics measurement config must contain only the singleton row';
ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.analytics_measurement_config`
  WHERE config_key = 'singleton'
    AND (
      raw_export_start_at != TIMESTAMP('{{RAW_EXPORT_START_AT}}')
      OR behavioral_schema_v1_start_at != TIMESTAMP('{{BEHAVIORAL_SCHEMA_V1_START_AT}}')
      OR clock_skew_allowance_seconds != 300
      OR auth_snapshot_max_age_hours != 36
      OR raw_late_arrival_days != 3
    )
) AS 'analytics measurement boundaries and policies are immutable after first deployment';

MERGE `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.analytics_measurement_config` AS target
USING (
  SELECT
    'singleton' AS config_key,
    TIMESTAMP('{{RAW_EXPORT_START_AT}}') AS raw_export_start_at,
    TIMESTAMP('{{BEHAVIORAL_SCHEMA_V1_START_AT}}') AS behavioral_schema_v1_start_at,
    300 AS clock_skew_allowance_seconds,
    36 AS auth_snapshot_max_age_hours,
    3 AS raw_late_arrival_days
) AS source
ON target.config_key = source.config_key
WHEN MATCHED THEN UPDATE SET
  raw_export_start_at = source.raw_export_start_at,
  behavioral_schema_v1_start_at = source.behavioral_schema_v1_start_at,
  clock_skew_allowance_seconds = source.clock_skew_allowance_seconds,
  auth_snapshot_max_age_hours = source.auth_snapshot_max_age_hours,
  raw_late_arrival_days = source.raw_late_arrival_days,
  updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
  INSERT (
    config_key,
    raw_export_start_at,
    behavioral_schema_v1_start_at,
    clock_skew_allowance_seconds,
    auth_snapshot_max_age_hours,
    raw_late_arrival_days,
    updated_at
  )
  VALUES (
    source.config_key,
    source.raw_export_start_at,
    source.behavioral_schema_v1_start_at,
    source.clock_skew_allowance_seconds,
    source.auth_snapshot_max_age_hours,
    source.raw_late_arrival_days,
    CURRENT_TIMESTAMP()
  );

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions` (
  user_key STRING NOT NULL,
  owner STRING NOT NULL,
  reason STRING NOT NULL,
  created_at TIMESTAMP NOT NULL
)
CLUSTER BY user_key
OPTIONS (description = 'Permanent internal/test account exclusions; entries must never be deactivated or expired');

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state` (
  state_key STRING NOT NULL,
  control_updated_at TIMESTAMP NOT NULL
)
OPTIONS (description = 'Explicit freshness sentinel advanced whenever the permanent exclusion set is reviewed');

MERGE `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state` AS target
USING (SELECT 'singleton' AS state_key) AS source
ON target.state_key = source.state_key
WHEN NOT MATCHED THEN
  INSERT (state_key, control_updated_at) VALUES ('singleton', CURRENT_TIMESTAMP());

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.auth_permanent_internal_exclusions`
OPTIONS (description = 'Authorized auth-export view with one null-key freshness sentinel') AS
SELECT
  exclusion.user_key,
  TRUE AS is_active,
  state.control_updated_at
FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions` AS exclusion
CROSS JOIN `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state` AS state
WHERE state.state_key = 'singleton'
UNION ALL
SELECT
  CAST(NULL AS STRING) AS user_key,
  FALSE AS is_active,
  state.control_updated_at
FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state` AS state
WHERE state.state_key = 'singleton';

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions` (
  user_key STRING NOT NULL,
  suppressed_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
)
CLUSTER BY user_key
OPTIONS (description = 'Permanent deletion tombstones applied to every keyed warehouse recomputation');

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.product_analytics_privacy_sweep_state` (
  sweep_name STRING NOT NULL,
  last_success_through_date DATE NOT NULL,
  updated_at TIMESTAMP NOT NULL
)
OPTIONS (description = 'Identifier-free monotonic checkpoint for overlapping keyed-upload deletion sweeps');

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state` (
  model_name STRING NOT NULL,
  source_start_date DATE NOT NULL,
  source_end_date DATE NOT NULL,
  completed_at TIMESTAMP NOT NULL,
  auth_snapshot_published_at TIMESTAMP,
  source_rows INT64 NOT NULL,
  deduplicated_rows INT64 NOT NULL,
  published_rows INT64 NOT NULL,
  missing_identity_rows INT64 NOT NULL,
  malformed_identity_rows INT64 NOT NULL,
  missing_schema_rows INT64 NOT NULL,
  unsupported_schema_rows INT64 NOT NULL,
  missing_occurrence_rows INT64 NOT NULL,
  future_occurrence_rows INT64 NOT NULL,
  before_account_rows INT64 NOT NULL,
  invalid_parameter_rows INT64 NOT NULL,
  unknown_enum_rows INT64 NOT NULL,
  internal_excluded_rows INT64 NOT NULL,
  deletion_excluded_rows INT64 NOT NULL,
  ineligible_user_rows INT64 NOT NULL,
  latest_emitted_at TIMESTAMP,
  latest_occurred_at TIMESTAMP
)
OPTIONS (description = 'Identifier-free last-success watermark, freshness, and bounded quality counters per transform');

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened` (
  event_name STRING NOT NULL,
  source_export_date DATE NOT NULL,
  emitted_at TIMESTAMP NOT NULL,
  occurred_at_micros INT64 NOT NULL,
  occurred_at TIMESTAMP NOT NULL,
  schema_version INT64 NOT NULL,
  user_key STRING NOT NULL,
  platform STRING,
  app_version STRING,
  app_build STRING,
  activation_schema_version INT64,
  inventory_state STRING,
  activity_state STRING,
  submission_kind STRING,
  input_mode STRING,
  workspace_kind STRING,
  failure_reason STRING,
  decision STRING,
  change_state STRING,
  surface STRING,
  channel STRING,
  method STRING,
  os STRING,
  screen STRING
)
PARTITION BY source_export_date
CLUSTER BY event_name, user_key
OPTIONS (
  description = 'Allowlisted account-linked product events; no installation, user_id, content, arbitrary parameter, geo, or device fields',
  partition_expiration_days = 426
);

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.installation_login_daily` (
  source_export_date DATE NOT NULL,
  event_date DATE NOT NULL,
  event_name STRING NOT NULL,
  schema_version INT64 NOT NULL,
  platform STRING,
  app_version STRING,
  app_build STRING,
  provider STRING NOT NULL,
  failure_kind STRING,
  event_count INT64 NOT NULL,
  includes_internal_test_traffic BOOL NOT NULL,
  refreshed_at TIMESTAMP NOT NULL
)
PARTITION BY source_export_date
CLUSTER BY event_name, provider
OPTIONS (
  description = 'Identifier-free direct event counts for the account-less login funnel',
  partition_expiration_days = 426
);

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.user_activity_daily` (
  activity_date DATE NOT NULL,
  user_key STRING NOT NULL,
  meaningful_activity BOOL NOT NULL,
  controller_activity BOOL NOT NULL,
  monitor_event_count INT64 NOT NULL,
  control_event_count INT64 NOT NULL,
  message_event_count INT64 NOT NULL,
  voice_assisted_message_count INT64 NOT NULL,
  voice_transcription_count INT64 NOT NULL,
  project_available_count INT64 NOT NULL,
  remote_created_session_count INT64 NOT NULL,
  dedicated_worktree_creation_count INT64 NOT NULL,
  session_creation_failure_count INT64 NOT NULL,
  question_answer_count INT64 NOT NULL,
  question_rejection_count INT64 NOT NULL,
  permission_answer_count INT64 NOT NULL,
  abort_count INT64 NOT NULL,
  non_empty_diff_view_count INT64 NOT NULL,
  screen_view_count INT64 NOT NULL,
  onboarding_interaction_count INT64 NOT NULL,
  first_meaningful_at TIMESTAMP,
  last_meaningful_at TIMESTAMP,
  refreshed_at TIMESTAMP NOT NULL
)
PARTITION BY activity_date
CLUSTER BY user_key
OPTIONS (
  description = 'One current-eligible user/date row with bounded product activity flags and counts',
  partition_expiration_days = 426
);

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.user_milestones` (
  user_key STRING NOT NULL,
  account_created_at TIMESTAMP NOT NULL,
  notification_registered_at TIMESTAMP,
  bridge_registered_at TIMESTAMP,
  legacy_first_metadata_request_at TIMESTAMP,
  foundation_exposed_at TIMESTAMP,
  analytics_schema_ready_at TIMESTAMP,
  activation_capable_at TIMESTAMP,
  project_available_at TIMESTAMP,
  full_activation_at TIMESTAMP,
  full_activation_source STRING,
  full_activation_input_mode STRING,
  monitor_activity_at TIMESTAMP,
  voice_transcription_at TIMESTAMP,
  voice_assisted_message_at TIMESTAMP,
  remote_created_session_at TIMESTAMP,
  dedicated_worktree_at TIMESTAMP,
  diff_viewed_at TIMESTAMP,
  question_intervention_at TIMESTAMP,
  permission_intervention_at TIMESTAMP,
  abort_at TIMESTAMP,
  first_screen_view_at TIMESTAMP,
  onboarding_interaction_at TIMESTAMP,
  refreshed_at TIMESTAMP NOT NULL
)
PARTITION BY DATE(account_created_at)
CLUSTER BY user_key
OPTIONS (
  description = 'Current-eligible auth and product milestones anchored to validated occurrence time',
  partition_expiration_days = 426
);

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.activation_cohorts` (
  cohort_week DATE NOT NULL,
  cohort_week_end DATE NOT NULL,
  data_as_of_at TIMESTAMP NOT NULL,
  total_accounts INT64 NOT NULL,
  enabled_accounts INT64 NOT NULL,
  preference_coverage FLOAT64,
  foundation_exposed_accounts INT64 NOT NULL,
  foundation_coverage FLOAT64,
  behavioral_window_mature_accounts INT64 NOT NULL,
  activation_capable_accounts INT64 NOT NULL,
  activation_capability_coverage FLOAT64,
  project_available_within_1_day INT64 NOT NULL,
  project_available_within_7_days INT64 NOT NULL,
  project_available_within_30_days INT64 NOT NULL,
  activation_eligible_1_day_accounts INT64 NOT NULL,
  activated_within_1_day INT64 NOT NULL,
  activation_eligible_7_day_accounts INT64 NOT NULL,
  activated_within_7_days INT64 NOT NULL,
  activation_eligible_30_day_accounts INT64 NOT NULL,
  activated_within_30_days INT64 NOT NULL,
  existing_session_activations INT64 NOT NULL,
  remote_created_session_activations INT64 NOT NULL,
  time_to_project_p50_seconds INT64,
  time_to_project_p75_seconds INT64,
  time_to_activation_p50_seconds INT64,
  time_to_activation_p75_seconds INT64,
  notification_registered_within_1_day INT64 NOT NULL,
  notification_registered_within_7_days INT64 NOT NULL,
  notification_registered_within_30_days INT64 NOT NULL,
  bridge_registered_within_1_day INT64 NOT NULL,
  bridge_registered_within_7_days INT64 NOT NULL,
  bridge_registered_within_30_days INT64 NOT NULL,
  legacy_metadata_request_within_1_day INT64 NOT NULL,
  legacy_metadata_request_within_7_days INT64 NOT NULL,
  legacy_metadata_request_within_30_days INT64 NOT NULL,
  setup_1_day_mature BOOL NOT NULL,
  setup_7_day_mature BOOL NOT NULL,
  setup_30_day_mature BOOL NOT NULL,
  refreshed_at TIMESTAMP NOT NULL
)
PARTITION BY cohort_week
OPTIONS (description = 'Identifier-free weekly setup, coverage, maturity, and activation cohorts', partition_expiration_days = 426);

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.retention_cohorts` (
  activation_week DATE NOT NULL,
  activation_week_end DATE NOT NULL,
  data_as_of_at TIMESTAMP NOT NULL,
  activated_users INT64 NOT NULL,
  w1_eligible_users INT64 NOT NULL,
  w1_retained_users INT64 NOT NULL,
  w1_retention_rate FLOAT64,
  w4_eligible_users INT64 NOT NULL,
  w4_retained_users INT64 NOT NULL,
  w4_retention_rate FLOAT64,
  refreshed_at TIMESTAMP NOT NULL
)
PARTITION BY activation_week
OPTIONS (description = 'Identifier-free activation-anchored half-open W1 and W4 retention cohorts', partition_expiration_days = 426);

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.weekly_engagement` (
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,
  data_as_of_at TIMESTAMP NOT NULL,
  meaningful_wau INT64 NOT NULL,
  controller_wau INT64 NOT NULL,
  active_days_p50 INT64,
  active_days_p75 INT64,
  remote_interventions INT64 NOT NULL,
  remote_interventions_per_controller FLOAT64,
  successful_messages INT64 NOT NULL,
  voice_assisted_messages INT64 NOT NULL,
  voice_assisted_message_users INT64 NOT NULL,
  voice_transcription_users INT64 NOT NULL,
  remote_created_session_users INT64 NOT NULL,
  remote_created_sessions INT64 NOT NULL,
  dedicated_worktree_users INT64 NOT NULL,
  dedicated_worktree_sessions INT64 NOT NULL,
  diff_users INT64 NOT NULL,
  question_users INT64 NOT NULL,
  permission_users INT64 NOT NULL,
  abort_users INT64 NOT NULL,
  screen_users INT64 NOT NULL,
  project_available_users INT64 NOT NULL,
  refreshed_at TIMESTAMP NOT NULL
)
PARTITION BY week_start
OPTIONS (description = 'Identifier-free complete Monday-Sunday engagement and feature aggregates', partition_expiration_days = 426);

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.screen_usage_weekly` (
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,
  platform STRING,
  app_version STRING,
  app_build STRING,
  screen STRING NOT NULL,
  unique_users INT64 NOT NULL,
  view_count INT64 NOT NULL,
  refreshed_at TIMESTAMP NOT NULL
)
PARTITION BY week_start
CLUSTER BY screen
OPTIONS (description = 'Identifier-free complete-week canonical product screen usage', partition_expiration_days = 426);

CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.onboarding_friction_weekly` (
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,
  metric_name STRING NOT NULL,
  platform STRING,
  app_version STRING,
  app_build STRING,
  surface STRING,
  channel STRING,
  install_method STRING,
  install_os STRING,
  failure_reason STRING,
  workspace_kind STRING,
  unique_users INT64 NOT NULL,
  event_count INT64 NOT NULL,
  refreshed_at TIMESTAMP NOT NULL
)
PARTITION BY week_start
CLUSTER BY metric_name
OPTIONS (description = 'Identifier-free complete-week bounded onboarding and creation-friction aggregates', partition_expiration_days = 426);
