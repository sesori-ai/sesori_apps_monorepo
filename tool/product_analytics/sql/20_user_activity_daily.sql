-- BigQuery Standard SQL. A stale or unreconciled auth snapshot aborts before
-- any mutation, leaving the previous published activity table intact.
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
DECLARE events_source_end_date DATE;
DECLARE retained_start_date DATE;
DECLARE rows_inserted INT64 DEFAULT 0;

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

SET events_source_end_date = (
  SELECT source_end_date
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name = 'events_flattened'
  LIMIT 1
);
ASSERT events_source_end_date IS NOT NULL AS 'events_flattened has no successful watermark';
SET retained_start_date = GREATEST(
  DATE(TIMESTAMP('{{RAW_EXPORT_START_AT}}')),
  DATE_SUB(events_source_end_date, INTERVAL 425 DAY)
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

CREATE TEMP TABLE activity_stage AS
WITH counts AS (
  SELECT
    DATE(occurred_at) AS activity_date,
    user_key,
    COUNTIF(event_name = 'session_activity_viewed' AND activity_state = 'non_empty') AS monitor_event_count,
    COUNTIF(event_name IN (
      'session_message_sent',
      'session_created_with_message',
      'session_question_answered',
      'session_question_rejected',
      'session_permission_answered',
      'session_abort_succeeded'
    )) AS control_event_count,
    COUNTIF(event_name IN ('session_message_sent', 'session_created_with_message')) AS message_event_count,
    COUNTIF(
      event_name IN ('session_message_sent', 'session_created_with_message')
      AND input_mode = 'voice_assisted'
    ) AS voice_assisted_message_count,
    COUNTIF(event_name = 'voice_transcription_completed') AS voice_transcription_count,
    COUNTIF(event_name = 'project_inventory_loaded' AND inventory_state = 'non_empty') AS project_available_count,
    COUNTIF(event_name = 'session_created_with_message') AS remote_created_session_count,
    COUNTIF(
      event_name = 'session_created_with_message' AND workspace_kind = 'dedicated_worktree'
    ) AS dedicated_worktree_creation_count,
    COUNTIF(event_name = 'session_creation_failed') AS session_creation_failure_count,
    COUNTIF(event_name = 'session_question_answered') AS question_answer_count,
    COUNTIF(event_name = 'session_question_rejected') AS question_rejection_count,
    COUNTIF(event_name = 'session_permission_answered') AS permission_answer_count,
    COUNTIF(event_name = 'session_abort_succeeded') AS abort_count,
    COUNTIF(event_name = 'session_diff_viewed' AND change_state = 'non_empty') AS non_empty_diff_view_count,
    COUNTIF(event_name = 'product_screen_viewed') AS screen_view_count,
    COUNTIF(event_name IN (
      'onboarding_need_help_opened',
      'onboarding_support_link_opened',
      'onboarding_why_bridge_opened',
      'bridge_install_command_copied',
      'bridge_install_command_shared',
      'bridge_run_command_copied',
      'bridge_run_command_shared'
    )) AS onboarding_interaction_count,
    MIN(IF(
      (event_name = 'session_activity_viewed' AND activity_state = 'non_empty')
      OR event_name IN (
        'session_message_sent',
        'session_created_with_message',
        'session_question_answered',
        'session_question_rejected',
        'session_permission_answered',
        'session_abort_succeeded'
      ),
      occurred_at,
      NULL
    )) AS first_meaningful_at,
    MAX(IF(
      (event_name = 'session_activity_viewed' AND activity_state = 'non_empty')
      OR event_name IN (
        'session_message_sent',
        'session_created_with_message',
        'session_question_answered',
        'session_question_rejected',
        'session_permission_answered',
        'session_abort_succeeded'
      ),
      occurred_at,
      NULL
    )) AS last_meaningful_at
  FROM eligible_event_stage
  GROUP BY activity_date, user_key
)
SELECT
  activity_date,
  user_key,
  monitor_event_count + control_event_count > 0 AS meaningful_activity,
  control_event_count > 0 AS controller_activity,
  monitor_event_count,
  control_event_count,
  message_event_count,
  voice_assisted_message_count,
  voice_transcription_count,
  project_available_count,
  remote_created_session_count,
  dedicated_worktree_creation_count,
  session_creation_failure_count,
  question_answer_count,
  question_rejection_count,
  permission_answer_count,
  abort_count,
  non_empty_diff_view_count,
  screen_view_count,
  onboarding_interaction_count,
  first_meaningful_at,
  last_meaningful_at,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM counts;

CREATE TEMP TABLE quality_stage AS
SELECT
  (SELECT COUNT(*) FROM gated_event_stage) AS source_rows,
  (SELECT COUNT(*) FROM activity_stage) AS published_rows,
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
) AS 'Auth snapshot changed while user activity was staged';
ASSERT latest_auth_run.control_updated_at = (
  SELECT control_updated_at
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state`
  WHERE state_key = 'singleton'
) AS 'Internal exclusion control changed while user activity was staged';

BEGIN TRANSACTION;

DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.user_activity_daily`
WHERE activity_date >= DATE '0001-01-01';

INSERT INTO `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.user_activity_daily` (
  activity_date,
  user_key,
  meaningful_activity,
  controller_activity,
  monitor_event_count,
  control_event_count,
  message_event_count,
  voice_assisted_message_count,
  voice_transcription_count,
  project_available_count,
  remote_created_session_count,
  dedicated_worktree_creation_count,
  session_creation_failure_count,
  question_answer_count,
  question_rejection_count,
  permission_answer_count,
  abort_count,
  non_empty_diff_view_count,
  screen_view_count,
  onboarding_interaction_count,
  first_meaningful_at,
  last_meaningful_at,
  refreshed_at
)
SELECT stage.*
FROM activity_stage AS stage
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
USING (SELECT 'user_activity_daily' AS model_name, quality.* FROM quality_stage AS quality) AS source
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
