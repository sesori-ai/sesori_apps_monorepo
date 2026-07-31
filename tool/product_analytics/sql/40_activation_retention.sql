-- BigQuery Standard SQL. All outputs are identifier-free and are replaced in a
-- single transaction only after current auth and upstream transform validation.
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
DECLARE activity_source_end_date DATE;
DECLARE activity_completed_at TIMESTAMP;
DECLARE milestone_source_end_date DATE;
DECLARE milestone_completed_at TIMESTAMP;
DECLARE data_as_of_date DATE;
DECLARE data_as_of_at TIMESTAMP;
DECLARE retained_start_date DATE;
DECLARE first_complete_behavioral_week DATE;
DECLARE deletion_exclusion_count INT64;
DECLARE deletion_exclusion_max_updated_at TIMESTAMP;

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

SET (
  events_source_end_date,
  events_completed_at,
  activity_source_end_date,
  activity_completed_at,
  milestone_source_end_date,
  milestone_completed_at
) = (
  SELECT AS STRUCT
    MAX(IF(model_name = 'events_flattened', source_end_date, NULL)),
    MAX(IF(model_name = 'events_flattened', completed_at, NULL)),
    MAX(IF(model_name = 'user_activity_daily', source_end_date, NULL)),
    MAX(IF(model_name = 'user_activity_daily', completed_at, NULL)),
    MAX(IF(model_name = 'user_milestones', source_end_date, NULL)),
    MAX(IF(model_name = 'user_milestones', completed_at, NULL))
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name IN ('events_flattened', 'user_activity_daily', 'user_milestones')
);
ASSERT events_source_end_date IS NOT NULL
  AND activity_source_end_date IS NOT NULL
  AND milestone_source_end_date IS NOT NULL
  AS 'Required upstream transforms have no successful watermark';
ASSERT activity_source_end_date = events_source_end_date
  AND milestone_source_end_date = events_source_end_date
  AND activity_completed_at >= events_completed_at
  AND milestone_completed_at >= events_completed_at
  AS 'User-level upstream transforms are stale relative to events_flattened';
ASSERT (
  SELECT COUNTIF(
    model_name IN ('user_activity_daily', 'user_milestones')
    AND auth_snapshot_published_at = latest_auth_run.published_at
  )
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
) = 2 AS 'User-level upstream transforms were not built from the current auth snapshot';

SET data_as_of_date = events_source_end_date;
SET data_as_of_at = TIMESTAMP(DATE_ADD(data_as_of_date, INTERVAL 1 DAY));
SET retained_start_date = GREATEST(
  DATE(measurement_config.raw_export_start_at),
  DATE_SUB(data_as_of_date, INTERVAL 425 DAY)
);
SET first_complete_behavioral_week = CASE
  WHEN measurement_config.behavioral_schema_v1_start_at = TIMESTAMP(
    DATE_TRUNC(DATE(measurement_config.behavioral_schema_v1_start_at), WEEK(MONDAY))
  ) THEN DATE(measurement_config.behavioral_schema_v1_start_at)
  ELSE DATE_ADD(
    DATE_TRUNC(DATE(measurement_config.behavioral_schema_v1_start_at), WEEK(MONDAY)),
    INTERVAL 7 DAY
  )
END;
SET (deletion_exclusion_count, deletion_exclusion_max_updated_at) = (
  SELECT AS STRUCT COUNT(*), MAX(updated_at)
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions`
);

CREATE TEMP TABLE current_user_stage AS
SELECT milestone.*
FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.user_milestones` AS milestone
INNER JOIN `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_user_milestones` AS auth USING (user_key)
WHERE DATE(milestone.account_created_at) BETWEEN retained_start_date AND data_as_of_date
  AND NOT EXISTS (
    SELECT 1
    FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions` AS internal
    WHERE internal.user_key = milestone.user_key
  )
  AND NOT EXISTS (
    SELECT 1
    FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions` AS deleted
    WHERE deleted.user_key = milestone.user_key
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
WHERE event.source_export_date BETWEEN retained_start_date AND data_as_of_date;

CREATE TEMP TABLE eligible_event_stage AS
SELECT *
FROM gated_event_stage
WHERE is_currently_eligible
  AND NOT is_internal_excluded
  AND NOT is_deletion_excluded
  AND schema_version = 1
  AND occurred_at >= TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
  AND occurred_at <= TIMESTAMP_ADD(emitted_at, INTERVAL 300 SECOND)
  AND occurred_at < data_as_of_at;

CREATE TEMP TABLE behavioral_cohort_stage AS
SELECT
  DATE_TRUNC(DATE(account_created_at), WEEK(MONDAY)) AS cohort_week,
  COUNT(*) AS enabled_current_accounts,
  COUNTIF(foundation_exposed_at IS NOT NULL) AS foundation_exposed_accounts,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 1 DAY)
  ) AS behavioral_window_mature_accounts,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 1 DAY)
  ) AS activation_capable_accounts,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 1 DAY)
    AND project_available_at <= TIMESTAMP_ADD(account_created_at, INTERVAL 1 DAY)
  ) AS project_available_within_1_day,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 7 DAY)
    AND project_available_at <= TIMESTAMP_ADD(account_created_at, INTERVAL 7 DAY)
  ) AS project_available_within_7_days,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 30 DAY)
    AND project_available_at <= TIMESTAMP_ADD(account_created_at, INTERVAL 30 DAY)
  ) AS project_available_within_30_days,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 1 DAY)
  ) AS activation_eligible_1_day_accounts,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 1 DAY)
    AND full_activation_at <= TIMESTAMP_ADD(account_created_at, INTERVAL 1 DAY)
  ) AS activated_within_1_day,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 7 DAY)
  ) AS activation_eligible_7_day_accounts,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 7 DAY)
    AND full_activation_at <= TIMESTAMP_ADD(account_created_at, INTERVAL 7 DAY)
  ) AS activated_within_7_days,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 30 DAY)
  ) AS activation_eligible_30_day_accounts,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND account_created_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 30 DAY)
    AND full_activation_at <= TIMESTAMP_ADD(account_created_at, INTERVAL 30 DAY)
  ) AS activated_within_30_days,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND full_activation_at IS NOT NULL
    AND full_activation_source = 'existing_session'
  ) AS existing_session_activations,
  COUNTIF(
    account_created_at >= measurement_config.behavioral_schema_v1_start_at
    AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
      AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
    AND full_activation_at IS NOT NULL
    AND full_activation_source = 'remote_created_session'
  ) AS remote_created_session_activations
FROM current_user_stage
GROUP BY cohort_week;

CREATE TEMP TABLE activation_time_stage AS
SELECT
  DATE_TRUNC(DATE(account_created_at), WEEK(MONDAY)) AS cohort_week,
  APPROX_QUANTILES(
    GREATEST(TIMESTAMP_DIFF(full_activation_at, account_created_at, SECOND), 0),
    100
  )[OFFSET(50)] AS time_to_activation_p50_seconds,
  APPROX_QUANTILES(
    GREATEST(TIMESTAMP_DIFF(full_activation_at, account_created_at, SECOND), 0),
    100
  )[OFFSET(75)] AS time_to_activation_p75_seconds
FROM current_user_stage
WHERE account_created_at >= measurement_config.behavioral_schema_v1_start_at
  AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
    AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
  AND full_activation_at IS NOT NULL
GROUP BY cohort_week;

CREATE TEMP TABLE project_time_stage AS
SELECT
  DATE_TRUNC(DATE(account_created_at), WEEK(MONDAY)) AS cohort_week,
  APPROX_QUANTILES(
    GREATEST(TIMESTAMP_DIFF(project_available_at, account_created_at, SECOND), 0),
    100
  )[OFFSET(50)] AS time_to_project_p50_seconds,
  APPROX_QUANTILES(
    GREATEST(TIMESTAMP_DIFF(project_available_at, account_created_at, SECOND), 0),
    100
  )[OFFSET(75)] AS time_to_project_p75_seconds
FROM current_user_stage
WHERE account_created_at >= measurement_config.behavioral_schema_v1_start_at
  AND activation_capable_at BETWEEN TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND)
    AND TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
  AND project_available_at IS NOT NULL
GROUP BY cohort_week;

CREATE TEMP TABLE activation_cohort_stage AS
SELECT
  setup.cohort_week,
  DATE_ADD(setup.cohort_week, INTERVAL 6 DAY) AS cohort_week_end,
  data_as_of_at AS data_as_of_at,
  setup.total_accounts,
  setup.enabled_accounts,
  SAFE_DIVIDE(setup.enabled_accounts, setup.total_accounts) AS preference_coverage,
  COALESCE(behavior.foundation_exposed_accounts, 0) AS foundation_exposed_accounts,
  SAFE_DIVIDE(COALESCE(behavior.foundation_exposed_accounts, 0), setup.enabled_accounts) AS foundation_coverage,
  COALESCE(behavior.behavioral_window_mature_accounts, 0) AS behavioral_window_mature_accounts,
  COALESCE(behavior.activation_capable_accounts, 0) AS activation_capable_accounts,
  SAFE_DIVIDE(
    COALESCE(behavior.activation_capable_accounts, 0),
    behavior.behavioral_window_mature_accounts
  ) AS activation_capability_coverage,
  COALESCE(behavior.project_available_within_1_day, 0) AS project_available_within_1_day,
  COALESCE(behavior.project_available_within_7_days, 0) AS project_available_within_7_days,
  COALESCE(behavior.project_available_within_30_days, 0) AS project_available_within_30_days,
  COALESCE(behavior.activation_eligible_1_day_accounts, 0) AS activation_eligible_1_day_accounts,
  COALESCE(behavior.activated_within_1_day, 0) AS activated_within_1_day,
  COALESCE(behavior.activation_eligible_7_day_accounts, 0) AS activation_eligible_7_day_accounts,
  COALESCE(behavior.activated_within_7_days, 0) AS activated_within_7_days,
  COALESCE(behavior.activation_eligible_30_day_accounts, 0) AS activation_eligible_30_day_accounts,
  COALESCE(behavior.activated_within_30_days, 0) AS activated_within_30_days,
  COALESCE(behavior.existing_session_activations, 0) AS existing_session_activations,
  COALESCE(behavior.remote_created_session_activations, 0) AS remote_created_session_activations,
  project_times.time_to_project_p50_seconds,
  project_times.time_to_project_p75_seconds,
  times.time_to_activation_p50_seconds,
  times.time_to_activation_p75_seconds,
  setup.notification_registered_within_1_day,
  setup.notification_registered_within_7_days,
  setup.notification_registered_within_30_days,
  setup.bridge_registered_within_1_day,
  setup.bridge_registered_within_7_days,
  setup.bridge_registered_within_30_days,
  setup.legacy_first_metadata_request_within_1_day AS legacy_metadata_request_within_1_day,
  setup.legacy_first_metadata_request_within_7_days AS legacy_metadata_request_within_7_days,
  setup.legacy_first_metadata_request_within_30_days AS legacy_metadata_request_within_30_days,
  data_as_of_at >= TIMESTAMP(DATE_ADD(setup.cohort_week, INTERVAL 8 DAY)) AS setup_1_day_mature,
  data_as_of_at >= TIMESTAMP(DATE_ADD(setup.cohort_week, INTERVAL 14 DAY)) AS setup_7_day_mature,
  data_as_of_at >= TIMESTAMP(DATE_ADD(setup.cohort_week, INTERVAL 37 DAY)) AS setup_30_day_mature,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_weekly_setup_cohorts` AS setup
LEFT JOIN behavioral_cohort_stage AS behavior USING (cohort_week)
LEFT JOIN activation_time_stage AS times USING (cohort_week)
LEFT JOIN project_time_stage AS project_times USING (cohort_week)
WHERE setup.cohort_week BETWEEN DATE_SUB(data_as_of_date, INTERVAL 425 DAY) AND data_as_of_date;

CREATE TEMP TABLE meaningful_event_stage AS
SELECT user_key, occurred_at
FROM eligible_event_stage
WHERE (event_name = 'session_activity_viewed' AND activity_state = 'non_empty')
  OR event_name IN (
    'session_message_sent',
    'session_created_with_message',
    'session_question_answered',
    'session_question_rejected',
    'session_permission_answered',
    'session_abort_succeeded'
  );

CREATE TEMP TABLE retention_user_stage AS
SELECT
  user.user_key,
  user.full_activation_at,
  DATE_TRUNC(DATE(user.full_activation_at), WEEK(MONDAY)) AS activation_week,
  user.full_activation_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 14 DAY) AS w1_eligible,
  COALESCE(LOGICAL_OR(
    event.occurred_at >= TIMESTAMP_ADD(user.full_activation_at, INTERVAL 7 DAY)
    AND event.occurred_at < TIMESTAMP_ADD(user.full_activation_at, INTERVAL 14 DAY)
  ), FALSE) AS w1_retained,
  user.full_activation_at <= TIMESTAMP_SUB(data_as_of_at, INTERVAL 35 DAY) AS w4_eligible,
  COALESCE(LOGICAL_OR(
    event.occurred_at >= TIMESTAMP_ADD(user.full_activation_at, INTERVAL 28 DAY)
    AND event.occurred_at < TIMESTAMP_ADD(user.full_activation_at, INTERVAL 35 DAY)
  ), FALSE) AS w4_retained
FROM current_user_stage AS user
LEFT JOIN meaningful_event_stage AS event USING (user_key)
WHERE user.full_activation_at IS NOT NULL
  AND user.account_created_at >= measurement_config.behavioral_schema_v1_start_at
  AND user.activation_capable_at BETWEEN TIMESTAMP_SUB(user.account_created_at, INTERVAL 300 SECOND)
    AND TIMESTAMP_ADD(user.account_created_at, INTERVAL 24 HOUR)
GROUP BY user.user_key, user.full_activation_at, activation_week, w1_eligible, w4_eligible;

CREATE TEMP TABLE retention_cohort_stage AS
SELECT
  activation_week,
  DATE_ADD(activation_week, INTERVAL 6 DAY) AS activation_week_end,
  data_as_of_at AS data_as_of_at,
  COUNT(*) AS activated_users,
  COUNTIF(w1_eligible) = COUNT(*) AS w1_cohort_mature,
  COUNTIF(w1_eligible) AS w1_eligible_users,
  COUNTIF(w1_eligible AND w1_retained) AS w1_retained_users,
  SAFE_DIVIDE(COUNTIF(w1_eligible AND w1_retained), COUNTIF(w1_eligible)) AS w1_retention_rate,
  COUNTIF(w4_eligible) = COUNT(*) AS w4_cohort_mature,
  COUNTIF(w4_eligible) AS w4_eligible_users,
  COUNTIF(w4_eligible AND w4_retained) AS w4_retained_users,
  SAFE_DIVIDE(COUNTIF(w4_eligible AND w4_retained), COUNTIF(w4_eligible)) AS w4_retention_rate,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM retention_user_stage
GROUP BY activation_week;

CREATE TEMP TABLE user_week_stage AS
SELECT
  DATE_TRUNC(activity.activity_date, WEEK(MONDAY)) AS week_start,
  activity.user_key,
  COUNTIF(activity.meaningful_activity) > 0 AS meaningful_user,
  COUNTIF(activity.controller_activity) > 0 AS controller_user,
  COUNTIF(activity.meaningful_activity) AS active_days,
  SUM(activity.control_event_count) AS remote_interventions,
  SUM(activity.message_event_count) AS successful_messages,
  SUM(activity.voice_assisted_message_count) AS voice_assisted_messages,
  SUM(activity.voice_assisted_message_count) > 0 AS used_voice_assisted_message,
  SUM(activity.voice_transcription_count) > 0 AS used_voice_transcription,
  SUM(activity.remote_created_session_count) > 0 AS used_remote_created_session,
  SUM(activity.remote_created_session_count) AS remote_created_sessions,
  SUM(activity.dedicated_worktree_creation_count) > 0 AS used_dedicated_worktree,
  SUM(activity.dedicated_worktree_creation_count) AS dedicated_worktree_sessions,
  SUM(activity.non_empty_diff_view_count) > 0 AS used_diff,
  SUM(activity.question_answer_count + activity.question_rejection_count) > 0 AS used_question,
  SUM(activity.permission_answer_count) > 0 AS used_permission,
  SUM(activity.abort_count) > 0 AS used_abort,
  SUM(activity.screen_view_count) > 0 AS used_screen,
  SUM(activity.project_available_count) > 0 AS had_project_available
FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.user_activity_daily` AS activity
INNER JOIN `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.auth_user_milestones` AS auth USING (user_key)
WHERE activity.activity_date BETWEEN first_complete_behavioral_week AND data_as_of_date
  AND DATE_ADD(DATE_TRUNC(activity.activity_date, WEEK(MONDAY)), INTERVAL 6 DAY) <= data_as_of_date
  AND NOT EXISTS (
    SELECT 1 FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions` AS internal
    WHERE internal.user_key = activity.user_key
  )
  AND NOT EXISTS (
    SELECT 1 FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions` AS deleted
    WHERE deleted.user_key = activity.user_key
  )
GROUP BY week_start, activity.user_key;

CREATE TEMP TABLE active_day_quantile_stage AS
SELECT
  week_start,
  APPROX_QUANTILES(active_days, 100)[OFFSET(50)] AS active_days_p50,
  APPROX_QUANTILES(active_days, 100)[OFFSET(75)] AS active_days_p75
FROM user_week_stage
WHERE meaningful_user
GROUP BY week_start;

CREATE TEMP TABLE weekly_aggregate_stage AS
SELECT
  weekly.week_start,
  DATE_ADD(weekly.week_start, INTERVAL 6 DAY) AS week_end,
  data_as_of_at AS data_as_of_at,
  COUNTIF(weekly.meaningful_user) AS meaningful_wau,
  COUNTIF(weekly.controller_user) AS controller_wau,
  quantiles.active_days_p50,
  quantiles.active_days_p75,
  SUM(weekly.remote_interventions) AS remote_interventions,
  SAFE_DIVIDE(SUM(weekly.remote_interventions), COUNTIF(weekly.controller_user)) AS remote_interventions_per_controller,
  SUM(weekly.successful_messages) AS successful_messages,
  SUM(weekly.voice_assisted_messages) AS voice_assisted_messages,
  COUNTIF(weekly.used_voice_assisted_message) AS voice_assisted_message_users,
  COUNTIF(weekly.used_voice_transcription) AS voice_transcription_users,
  COUNTIF(weekly.used_remote_created_session) AS remote_created_session_users,
  SUM(weekly.remote_created_sessions) AS remote_created_sessions,
  COUNTIF(weekly.used_dedicated_worktree) AS dedicated_worktree_users,
  SUM(weekly.dedicated_worktree_sessions) AS dedicated_worktree_sessions,
  COUNTIF(weekly.used_diff) AS diff_users,
  COUNTIF(weekly.used_question) AS question_users,
  COUNTIF(weekly.used_permission) AS permission_users,
  COUNTIF(weekly.used_abort) AS abort_users,
  COUNTIF(weekly.used_screen) AS screen_users,
  COUNTIF(weekly.had_project_available) AS project_available_users,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM user_week_stage AS weekly
LEFT JOIN active_day_quantile_stage AS quantiles USING (week_start)
GROUP BY weekly.week_start, quantiles.active_days_p50, quantiles.active_days_p75;

CREATE TEMP TABLE weekly_engagement_stage AS
WITH first_week_candidates AS (
  SELECT
    CASE
      WHEN retained_start_date = DATE_TRUNC(retained_start_date, WEEK(MONDAY)) THEN retained_start_date
      ELSE DATE_ADD(DATE_TRUNC(retained_start_date, WEEK(MONDAY)), INTERVAL 7 DAY)
    END AS first_retained_complete_week,
    first_complete_behavioral_week AS first_behavioral_complete_week
),
boundaries AS (
  SELECT
    GREATEST(first_retained_complete_week, first_behavioral_complete_week) AS first_complete_week,
    DATE_TRUNC(DATE_SUB(data_as_of_date, INTERVAL 6 DAY), WEEK(MONDAY)) AS last_complete_week
  FROM first_week_candidates
),
week_spine AS (
  SELECT week_start
  FROM boundaries,
  UNNEST(GENERATE_DATE_ARRAY(first_complete_week, last_complete_week, INTERVAL 7 DAY)) AS week_start
)
SELECT
  spine.week_start,
  DATE_ADD(spine.week_start, INTERVAL 6 DAY) AS week_end,
  data_as_of_at AS data_as_of_at,
  COALESCE(aggregate.meaningful_wau, 0) AS meaningful_wau,
  COALESCE(aggregate.controller_wau, 0) AS controller_wau,
  aggregate.active_days_p50,
  aggregate.active_days_p75,
  COALESCE(aggregate.remote_interventions, 0) AS remote_interventions,
  aggregate.remote_interventions_per_controller,
  COALESCE(aggregate.successful_messages, 0) AS successful_messages,
  COALESCE(aggregate.voice_assisted_messages, 0) AS voice_assisted_messages,
  COALESCE(aggregate.voice_assisted_message_users, 0) AS voice_assisted_message_users,
  COALESCE(aggregate.voice_transcription_users, 0) AS voice_transcription_users,
  COALESCE(aggregate.remote_created_session_users, 0) AS remote_created_session_users,
  COALESCE(aggregate.remote_created_sessions, 0) AS remote_created_sessions,
  COALESCE(aggregate.dedicated_worktree_users, 0) AS dedicated_worktree_users,
  COALESCE(aggregate.dedicated_worktree_sessions, 0) AS dedicated_worktree_sessions,
  COALESCE(aggregate.diff_users, 0) AS diff_users,
  COALESCE(aggregate.question_users, 0) AS question_users,
  COALESCE(aggregate.permission_users, 0) AS permission_users,
  COALESCE(aggregate.abort_users, 0) AS abort_users,
  COALESCE(aggregate.screen_users, 0) AS screen_users,
  COALESCE(aggregate.project_available_users, 0) AS project_available_users,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM week_spine AS spine
LEFT JOIN weekly_aggregate_stage AS aggregate USING (week_start);

CREATE TEMP TABLE screen_usage_stage AS
SELECT
  DATE_TRUNC(DATE(occurred_at), WEEK(MONDAY)) AS week_start,
  DATE_ADD(DATE_TRUNC(DATE(occurred_at), WEEK(MONDAY)), INTERVAL 6 DAY) AS week_end,
  platform,
  app_version,
  app_build,
  screen,
  COUNT(DISTINCT user_key) AS unique_users,
  COUNT(*) AS view_count,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM eligible_event_stage
WHERE event_name = 'product_screen_viewed'
  AND occurred_at >= TIMESTAMP(first_complete_behavioral_week)
  AND DATE_ADD(DATE_TRUNC(DATE(occurred_at), WEEK(MONDAY)), INTERVAL 6 DAY) <= data_as_of_date
GROUP BY week_start, week_end, platform, app_version, app_build, screen;

CREATE TEMP TABLE onboarding_friction_stage AS
WITH classified AS (
  SELECT
    DATE_TRUNC(DATE(occurred_at), WEEK(MONDAY)) AS week_start,
    CASE
      WHEN event_name = 'project_inventory_loaded' AND inventory_state = 'empty' THEN 'empty_project_inventory'
      WHEN event_name = 'session_activity_viewed' AND activity_state = 'empty' THEN 'empty_session_activity'
      WHEN event_name = 'session_diff_viewed' AND change_state = 'empty' THEN 'empty_session_diff'
      WHEN event_name = 'session_creation_failed' THEN 'session_creation_failed'
      WHEN event_name IN (
        'onboarding_need_help_opened',
        'onboarding_support_link_opened',
        'onboarding_why_bridge_opened',
        'bridge_install_command_copied',
        'bridge_install_command_shared',
        'bridge_run_command_copied',
        'bridge_run_command_shared'
      ) THEN event_name
    END AS metric_name,
    platform,
    app_version,
    app_build,
    surface,
    channel,
    method AS install_method,
    os AS install_os,
    failure_reason,
    workspace_kind,
    user_key
  FROM eligible_event_stage
)
SELECT
  week_start,
  DATE_ADD(week_start, INTERVAL 6 DAY) AS week_end,
  metric_name,
  platform,
  app_version,
  app_build,
  surface,
  channel,
  install_method,
  install_os,
  failure_reason,
  workspace_kind,
  COUNT(DISTINCT user_key) AS unique_users,
  COUNT(*) AS event_count,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM classified
WHERE metric_name IS NOT NULL
  AND week_start >= first_complete_behavioral_week
  AND DATE_ADD(week_start, INTERVAL 6 DAY) <= data_as_of_date
GROUP BY
  week_start,
  week_end,
  metric_name,
  platform,
  app_version,
  app_build,
  surface,
  channel,
  install_method,
  install_os,
  failure_reason,
  workspace_kind;

CREATE TEMP TABLE quality_stage AS
SELECT
  (SELECT COUNT(*) FROM gated_event_stage) AS source_rows,
  (
    (SELECT COUNT(*) FROM activation_cohort_stage)
    + (SELECT COUNT(*) FROM retention_cohort_stage)
    + (SELECT COUNT(*) FROM weekly_engagement_stage)
    + (SELECT COUNT(*) FROM screen_usage_stage)
    + (SELECT COUNT(*) FROM onboarding_friction_stage)
  ) AS published_rows,
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
) AS 'Auth snapshot changed while activation and retention aggregates were staged';
ASSERT latest_auth_run.control_updated_at = (
  SELECT control_updated_at
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state`
  WHERE state_key = 'singleton'
) AS 'Internal exclusion control changed while activation and retention aggregates were staged';
ASSERT (
  SELECT
    COUNTIF(
      model_name = 'events_flattened'
      AND source_end_date = events_source_end_date
      AND completed_at = events_completed_at
    ) = 1
    AND COUNTIF(
      model_name = 'user_activity_daily'
      AND source_end_date = events_source_end_date
      AND completed_at = activity_completed_at
    ) = 1
    AND COUNTIF(
      model_name = 'user_milestones'
      AND source_end_date = events_source_end_date
      AND completed_at = milestone_completed_at
    ) = 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name IN ('events_flattened', 'user_activity_daily', 'user_milestones')
) AS 'Upstream transform state changed while activation and retention aggregates were staged';
ASSERT deletion_exclusion_count = (
  SELECT COUNT(*)
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions`
) AND deletion_exclusion_max_updated_at IS NOT DISTINCT FROM (
  SELECT MAX(updated_at)
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions`
) AS 'Permanent deletion exclusions changed while activation and retention aggregates were staged';

BEGIN TRANSACTION;

DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.activation_cohorts` WHERE cohort_week >= DATE '0001-01-01';
INSERT INTO `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.activation_cohorts` SELECT * FROM activation_cohort_stage;

DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.retention_cohorts` WHERE activation_week >= DATE '0001-01-01';
INSERT INTO `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.retention_cohorts` SELECT * FROM retention_cohort_stage;

DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.weekly_engagement` WHERE week_start >= DATE '0001-01-01';
INSERT INTO `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.weekly_engagement` SELECT * FROM weekly_engagement_stage;

DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.screen_usage_weekly` WHERE week_start >= DATE '0001-01-01';
INSERT INTO `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.screen_usage_weekly` SELECT * FROM screen_usage_stage;

DELETE FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.onboarding_friction_weekly` WHERE week_start >= DATE '0001-01-01';
INSERT INTO `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.onboarding_friction_weekly` SELECT * FROM onboarding_friction_stage;

MERGE `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state` AS target
USING (SELECT 'activation_retention' AS model_name, quality.* FROM quality_stage AS quality) AS source
ON target.model_name = source.model_name
WHEN MATCHED THEN UPDATE SET
  source_start_date = retained_start_date,
  source_end_date = data_as_of_date,
  completed_at = CURRENT_TIMESTAMP(),
  auth_snapshot_published_at = latest_auth_run.published_at,
  source_rows = source.source_rows,
  deduplicated_rows = source.source_rows,
  published_rows = source.published_rows,
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
  data_as_of_date,
  CURRENT_TIMESTAMP(),
  latest_auth_run.published_at,
  source.source_rows,
  source.source_rows,
  source.published_rows,
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
