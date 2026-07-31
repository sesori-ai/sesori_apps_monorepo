-- BigQuery Standard SQL. Rebuild the current eligible milestone snapshot only
-- after the auth export's 36-hour freshness and reconciliation contract passes.
DECLARE latest_auth_run STRUCT<
  published_at TIMESTAMP,
  run_cutoff TIMESTAMP,
  control_updated_at TIMESTAMP,
  users_scanned INT64,
  source_suppressed_users INT64,
  internal_users INT64,
  external_accounts INT64,
  enabled_accounts INT64,
  opted_out_accounts INT64,
  preference_after_cutoff_accounts INT64,
  late_preference_rows_removed INT64,
  milestone_rows_published INT64,
  cohort_rows_published INT64
>;
DECLARE measurement_config STRUCT<
  raw_export_start_at TIMESTAMP,
  behavioral_schema_v1_start_at TIMESTAMP
>;
DECLARE events_source_end_date DATE;
DECLARE events_completed_at TIMESTAMP;
DECLARE retained_start_date DATE;
DECLARE deletion_exclusion_count INT64;
DECLARE deletion_exclusion_max_updated_at TIMESTAMP;
DECLARE rows_inserted INT64 DEFAULT 0;

SET measurement_config = (
  SELECT AS STRUCT raw_export_start_at, behavioral_schema_v1_start_at
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.analytics_measurement_config`
  WHERE config_key = 'singleton'
);
ASSERT measurement_config IS NOT NULL AS 'The singleton analytics measurement config is required';

SET latest_auth_run = (
  SELECT AS STRUCT
    published_at,
    run_cutoff,
    control_updated_at,
    users_scanned,
    source_suppressed_users,
    internal_users,
    external_accounts,
    enabled_accounts,
    opted_out_accounts,
    preference_after_cutoff_accounts,
    late_preference_rows_removed,
    milestone_rows_published,
    cohort_rows_published
  FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.product_analytics_export_runs`
  ORDER BY published_at DESC, run_cutoff DESC
  LIMIT 1
);

ASSERT latest_auth_run IS NOT NULL AS 'A successful auth snapshot is required';
ASSERT latest_auth_run.published_at BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 36 HOUR)
  AND TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 300 SECOND)
  AS 'The latest auth snapshot is stale or future-dated';
ASSERT latest_auth_run.run_cutoff BETWEEN TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 36 HOUR)
  AND latest_auth_run.published_at
  AS 'The latest auth snapshot source cutoff is stale or later than publication';
ASSERT latest_auth_run.users_scanned =
  latest_auth_run.source_suppressed_users + latest_auth_run.internal_users + latest_auth_run.external_accounts
  AS 'Auth source/exclusion reconciliation failed';
ASSERT latest_auth_run.external_accounts =
  latest_auth_run.enabled_accounts
  + latest_auth_run.opted_out_accounts
  + latest_auth_run.preference_after_cutoff_accounts
  + latest_auth_run.late_preference_rows_removed
  AS 'Auth preference reconciliation failed';
ASSERT latest_auth_run.milestone_rows_published = latest_auth_run.enabled_accounts
  AS 'Auth milestone metadata reconciliation failed';
ASSERT (
  SELECT COUNT(*) FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_user_milestones`
) = latest_auth_run.enabled_accounts
  AS 'Current auth milestone snapshot does not match successful-run metadata';
ASSERT (
  SELECT COALESCE(SUM(total_accounts), 0)
  FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_weekly_setup_cohorts`
) = latest_auth_run.external_accounts
  AS 'Auth setup cohort total does not reconcile';
ASSERT (
  SELECT COALESCE(SUM(enabled_accounts), 0)
  FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_weekly_setup_cohorts`
) = latest_auth_run.enabled_accounts
  AS 'Auth setup cohort preference coverage does not reconcile';
ASSERT (
  SELECT COUNT(*) FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_weekly_setup_cohorts`
) = latest_auth_run.cohort_rows_published
  AS 'Auth setup cohort row count does not reconcile';
ASSERT latest_auth_run.control_updated_at = (
  SELECT control_updated_at
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state`
  WHERE state_key = 'singleton'
)
  AS 'Auth snapshot predates the current permanent internal exclusion control';

SET (events_source_end_date, events_completed_at) = (
  SELECT AS STRUCT source_end_date, completed_at
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name = 'events_flattened'
  LIMIT 1
);
ASSERT events_source_end_date IS NOT NULL AND events_completed_at IS NOT NULL
  AS 'events_flattened has no successful watermark';
SET retained_start_date = GREATEST(
  DATE(measurement_config.raw_export_start_at),
  DATE_SUB(events_source_end_date, INTERVAL 425 DAY)
);
SET (deletion_exclusion_count, deletion_exclusion_max_updated_at) = (
  SELECT AS STRUCT COUNT(*), MAX(updated_at)
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions`
);

CREATE TEMP TABLE gated_event_stage AS
WITH internal_keys AS (
  SELECT DISTINCT user_key
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions`
),
deleted_keys AS (
  SELECT DISTINCT user_key
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions`
)
SELECT
  event.*,
  auth.account_created_at,
  auth.user_key IS NOT NULL AS is_currently_eligible,
  internal_keys.user_key IS NOT NULL AS is_internal_excluded,
  deleted_keys.user_key IS NOT NULL AS is_deletion_excluded
FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened` AS event
LEFT JOIN `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_user_milestones` AS auth USING (user_key)
LEFT JOIN internal_keys USING (user_key)
LEFT JOIN deleted_keys USING (user_key)
WHERE event.source_export_date BETWEEN retained_start_date AND events_source_end_date;

CREATE TEMP TABLE eligible_event_stage AS
SELECT *
FROM gated_event_stage
WHERE is_currently_eligible
  AND NOT is_internal_excluded
  AND NOT is_deletion_excluded
  AND schema_version = 1
  AND occurred_at >= TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
  AND occurred_at <= TIMESTAMP_ADD(emitted_at, INTERVAL 300 SECOND)
  AND DATE(occurred_at) <= events_source_end_date;

CREATE TEMP TABLE event_milestone_stage AS
SELECT
  user_key,
  MIN(occurred_at) AS foundation_exposed_at,
  MIN(IF(event_name = 'analytics_schema_ready', occurred_at, NULL)) AS analytics_schema_ready_at,
  MIN(IF(
    (event_name = 'analytics_activation_ready' AND activation_schema_version = 1)
    OR event_name IN ('session_message_sent', 'session_created_with_message'),
    occurred_at,
    NULL
  )) AS activation_capable_at,
  MIN(IF(event_name = 'project_inventory_loaded' AND inventory_state = 'non_empty', occurred_at, NULL)) AS project_available_at,
  MIN(IF(event_name = 'session_activity_viewed' AND activity_state = 'non_empty', occurred_at, NULL)) AS monitor_activity_at,
  MIN(IF(event_name = 'voice_transcription_completed', occurred_at, NULL)) AS voice_transcription_at,
  MIN(IF(
    event_name IN ('session_message_sent', 'session_created_with_message') AND input_mode = 'voice_assisted',
    occurred_at,
    NULL
  )) AS voice_assisted_message_at,
  MIN(IF(event_name = 'session_created_with_message', occurred_at, NULL)) AS remote_created_session_at,
  MIN(IF(
    event_name = 'session_created_with_message' AND workspace_kind = 'dedicated_worktree',
    occurred_at,
    NULL
  )) AS dedicated_worktree_at,
  MIN(IF(event_name = 'session_diff_viewed' AND change_state = 'non_empty', occurred_at, NULL)) AS diff_viewed_at,
  MIN(IF(event_name IN ('session_question_answered', 'session_question_rejected'), occurred_at, NULL)) AS question_intervention_at,
  MIN(IF(event_name = 'session_permission_answered', occurred_at, NULL)) AS permission_intervention_at,
  MIN(IF(event_name = 'session_abort_succeeded', occurred_at, NULL)) AS abort_at,
  MIN(IF(event_name = 'product_screen_viewed', occurred_at, NULL)) AS first_screen_view_at,
  MIN(IF(event_name IN (
    'onboarding_need_help_opened',
    'onboarding_support_link_opened',
    'onboarding_why_bridge_opened',
    'bridge_install_command_copied',
    'bridge_install_command_shared',
    'bridge_run_command_copied',
    'bridge_run_command_shared'
  ), occurred_at, NULL)) AS onboarding_interaction_at
FROM eligible_event_stage
GROUP BY user_key;

CREATE TEMP TABLE first_activation_stage AS
SELECT
  user_key,
  ARRAY_AGG(
    STRUCT(occurred_at, emitted_at, event_name, input_mode)
    ORDER BY occurred_at, emitted_at, event_name
    LIMIT 1
  )[OFFSET(0)] AS activation
FROM eligible_event_stage
WHERE event_name IN ('session_message_sent', 'session_created_with_message')
GROUP BY user_key;

CREATE TEMP TABLE milestone_stage AS
SELECT
  auth.user_key,
  auth.account_created_at,
  auth.notification_registered_at,
  auth.bridge_registered_at,
  auth.legacy_first_metadata_request_at,
  event.foundation_exposed_at,
  event.analytics_schema_ready_at,
  event.activation_capable_at,
  event.project_available_at,
  first_activation.activation.occurred_at AS full_activation_at,
  CASE first_activation.activation.event_name
    WHEN 'session_message_sent' THEN 'existing_session'
    WHEN 'session_created_with_message' THEN 'remote_created_session'
  END AS full_activation_source,
  first_activation.activation.input_mode AS full_activation_input_mode,
  event.monitor_activity_at,
  event.voice_transcription_at,
  event.voice_assisted_message_at,
  event.remote_created_session_at,
  event.dedicated_worktree_at,
  event.diff_viewed_at,
  event.question_intervention_at,
  event.permission_intervention_at,
  event.abort_at,
  event.first_screen_view_at,
  event.onboarding_interaction_at,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_user_milestones` AS auth
LEFT JOIN event_milestone_stage AS event USING (user_key)
LEFT JOIN first_activation_stage AS first_activation USING (user_key)
WHERE DATE(auth.account_created_at) >= DATE_SUB(events_source_end_date, INTERVAL 425 DAY)
  AND NOT EXISTS (
    SELECT 1
    FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions` AS internal
    WHERE internal.user_key = auth.user_key
  )
  AND NOT EXISTS (
    SELECT 1
    FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions` AS deleted
    WHERE deleted.user_key = auth.user_key
  );

CREATE TEMP TABLE quality_stage AS
SELECT
  (SELECT COUNT(*) FROM gated_event_stage) AS source_rows,
  (SELECT COUNT(*) FROM milestone_stage) AS published_rows,
  (SELECT COUNTIF(occurred_at < TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND))
   FROM gated_event_stage WHERE is_currently_eligible) AS before_account_rows,
  (SELECT COUNTIF(NOT is_currently_eligible) FROM gated_event_stage) AS ineligible_user_rows,
  (SELECT COUNTIF(is_internal_excluded) FROM gated_event_stage) AS internal_excluded_rows,
  (SELECT COUNTIF(is_deletion_excluded) FROM gated_event_stage) AS deletion_excluded_rows,
  (SELECT MAX(emitted_at) FROM eligible_event_stage) AS latest_emitted_at,
  (SELECT MAX(occurred_at) FROM eligible_event_stage) AS latest_occurred_at;

ASSERT latest_auth_run.published_at = (
  SELECT MAX(published_at)
  FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.product_analytics_export_runs`
) AS 'Auth snapshot changed while user milestones were staged';
ASSERT latest_auth_run.control_updated_at = (
  SELECT control_updated_at
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state`
  WHERE state_key = 'singleton'
) AS 'Internal exclusion control changed while user milestones were staged';
ASSERT (
  SELECT COUNTIF(
    source_end_date = events_source_end_date
    AND completed_at = events_completed_at
  )
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name = 'events_flattened'
) = 1 AS 'events_flattened changed while user milestones were staged';
ASSERT deletion_exclusion_count = (
  SELECT COUNT(*)
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions`
) AND deletion_exclusion_max_updated_at IS NOT DISTINCT FROM (
  SELECT MAX(updated_at)
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions`
) AS 'Permanent deletion exclusions changed while user milestones were staged';

BEGIN TRANSACTION;

DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.user_milestones`
WHERE DATE(account_created_at) >= DATE '0001-01-01';

INSERT INTO `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.user_milestones` (
  user_key,
  account_created_at,
  notification_registered_at,
  bridge_registered_at,
  legacy_first_metadata_request_at,
  foundation_exposed_at,
  analytics_schema_ready_at,
  activation_capable_at,
  project_available_at,
  full_activation_at,
  full_activation_source,
  full_activation_input_mode,
  monitor_activity_at,
  voice_transcription_at,
  voice_assisted_message_at,
  remote_created_session_at,
  dedicated_worktree_at,
  diff_viewed_at,
  question_intervention_at,
  permission_intervention_at,
  abort_at,
  first_screen_view_at,
  onboarding_interaction_at,
  refreshed_at
)
SELECT stage.*
FROM milestone_stage AS stage
WHERE EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_user_milestones` AS auth
  WHERE auth.user_key = stage.user_key
)
AND NOT EXISTS (
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
USING (SELECT 'user_milestones' AS model_name, quality.* FROM quality_stage AS quality) AS source
ON target.model_name = source.model_name
WHEN MATCHED THEN UPDATE SET
  source_start_date = retained_start_date,
  source_end_date = events_source_end_date,
  completed_at = CURRENT_TIMESTAMP(),
  auth_snapshot_published_at = latest_auth_run.published_at,
  source_rows = source.source_rows,
  deduplicated_rows = source.source_rows,
  published_rows = rows_inserted,
  missing_identity_rows = 0,
  malformed_identity_rows = 0,
  missing_schema_rows = 0,
  unsupported_schema_rows = 0,
  missing_occurrence_rows = 0,
  future_occurrence_rows = 0,
  before_account_rows = source.before_account_rows,
  invalid_parameter_rows = 0,
  unknown_enum_rows = 0,
  internal_excluded_rows = source.internal_excluded_rows,
  deletion_excluded_rows = source.deletion_excluded_rows,
  ineligible_user_rows = source.ineligible_user_rows,
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
  retained_start_date,
  events_source_end_date,
  CURRENT_TIMESTAMP(),
  latest_auth_run.published_at,
  source.source_rows,
  source.source_rows,
  rows_inserted,
  0,
  0,
  0,
  0,
  0,
  0,
  source.before_account_rows,
  0,
  0,
  source.internal_excluded_rows,
  source.deletion_excluded_rows,
  source.ineligible_user_rows,
  source.latest_emitted_at,
  source.latest_occurred_at
);

COMMIT TRANSACTION;
