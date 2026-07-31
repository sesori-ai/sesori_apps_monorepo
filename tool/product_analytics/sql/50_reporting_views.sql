-- BigQuery Standard SQL. Every view exposes aggregate, identifier-free fields
-- only; no reporting schema contains user_key or an installation identifier.

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.weekly_kpis`
OPTIONS (description = 'Complete Monday-Sunday account, activation, engagement, and growth KPIs') AS
WITH joined AS (
  SELECT
    COALESCE(engagement.week_start, activation.cohort_week) AS week_start,
    COALESCE(engagement.week_end, activation.cohort_week_end) AS week_end,
    COALESCE(activation.total_accounts, 0) AS new_accounts,
    COALESCE(activation.enabled_accounts, 0) AS analytics_enabled_accounts,
    activation.preference_coverage,
    activation.foundation_coverage,
    IF(activation.setup_1_day_mature, activation.activation_capability_coverage, NULL) AS activation_capability_coverage,
    IF(activation.setup_7_day_mature, activation.bridge_registered_within_7_days, NULL) AS bridge_setup_within_7_days,
    IF(activation.setup_7_day_mature, activation.total_accounts, NULL) AS bridge_setup_7_day_denominator,
    IF(
      activation.setup_7_day_mature,
      SAFE_DIVIDE(activation.bridge_registered_within_7_days, activation.total_accounts),
      NULL
    ) AS bridge_setup_7_day_rate,
    IF(activation.setup_7_day_mature, activation.activated_within_7_days, NULL) AS activated_within_7_days,
    IF(
      activation.setup_7_day_mature,
      activation.activation_eligible_7_day_accounts,
      NULL
    ) AS activation_7_day_denominator,
    IF(
      activation.setup_7_day_mature,
      SAFE_DIVIDE(activation.activated_within_7_days, activation.activation_eligible_7_day_accounts),
      NULL
    ) AS activation_7_day_rate,
    IF(
      activation.setup_7_day_mature,
      activation.project_available_within_7_days,
      NULL
    ) AS project_available_within_7_days,
    IF(
      activation.setup_7_day_mature,
      SAFE_DIVIDE(activation.project_available_within_7_days, activation.activation_eligible_7_day_accounts),
      NULL
    ) AS project_available_7_day_rate,
    IF(activation.setup_7_day_mature, activation.time_to_project_p50_seconds, NULL) AS time_to_project_p50_seconds,
    IF(activation.setup_7_day_mature, activation.time_to_project_p75_seconds, NULL) AS time_to_project_p75_seconds,
    IF(activation.setup_7_day_mature, activation.time_to_activation_p50_seconds, NULL) AS time_to_activation_p50_seconds,
    IF(activation.setup_7_day_mature, activation.time_to_activation_p75_seconds, NULL) AS time_to_activation_p75_seconds,
    COALESCE(activation.setup_1_day_mature, FALSE) AS one_day_cohort_mature,
    COALESCE(activation.setup_7_day_mature, FALSE) AS seven_day_cohort_mature,
    engagement.meaningful_wau,
    engagement.controller_wau,
    engagement.active_days_p50,
    engagement.active_days_p75,
    engagement.remote_interventions,
    engagement.remote_interventions_per_controller,
    engagement.successful_messages,
    engagement.voice_assisted_messages,
    COALESCE(engagement.data_as_of_at, activation.data_as_of_at) AS data_as_of_at,
    GREATEST(
      COALESCE(engagement.refreshed_at, activation.refreshed_at),
      COALESCE(activation.refreshed_at, engagement.refreshed_at)
    ) AS refreshed_at
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.weekly_engagement` AS engagement
  FULL OUTER JOIN `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.activation_cohorts` AS activation
    ON activation.cohort_week = engagement.week_start
  WHERE COALESCE(engagement.week_end, activation.cohort_week_end) < CURRENT_DATE('UTC')
    AND COALESCE(engagement.week_end, activation.cohort_week_end) < DATE(
      COALESCE(engagement.data_as_of_at, activation.data_as_of_at)
    )
),
compared AS (
  SELECT
    joined.*,
    LAG(meaningful_wau, 4) OVER (ORDER BY week_start) AS meaningful_wau_four_weeks_prior
  FROM joined
)
SELECT
  *,
  IF(
    meaningful_wau_four_weeks_prior IS NULL OR meaningful_wau_four_weeks_prior = 0,
    NULL,
    SAFE_DIVIDE(meaningful_wau, meaningful_wau_four_weeks_prior) - 1
  ) AS four_week_wau_growth
FROM compared;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.investor_snapshot`
OPTIONS (description = 'Latest applicable account, complete engagement, and mature activation headline periods') AS
WITH account_periods AS (
  SELECT
    week_start,
    week_end,
    new_accounts,
    data_as_of_at,
    refreshed_at,
    LAG(week_start) OVER (ORDER BY week_start) AS prior_account_week_start,
    LAG(week_end) OVER (ORDER BY week_start) AS prior_account_week_end,
    LAG(new_accounts) OVER (ORDER BY week_start) AS prior_week_new_accounts,
    ROW_NUMBER() OVER (ORDER BY week_start DESC) AS recency_rank
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.weekly_kpis`
  WHERE week_end < DATE(data_as_of_at)
    AND week_end < CURRENT_DATE('UTC')
),
engagement_compared AS (
  SELECT
    engagement.*,
    LAG(week_start) OVER (ORDER BY week_start) AS prior_engagement_week_start,
    LAG(week_end) OVER (ORDER BY week_start) AS prior_engagement_week_end,
    LAG(meaningful_wau) OVER (ORDER BY week_start) AS prior_week_meaningful_wau,
    LAG(controller_wau) OVER (ORDER BY week_start) AS prior_week_controller_wau,
    LAG(week_start, 4) OVER (ORDER BY week_start) AS four_week_comparison_week_start,
    LAG(week_end, 4) OVER (ORDER BY week_start) AS four_week_comparison_week_end,
    LAG(meaningful_wau, 4) OVER (ORDER BY week_start) AS meaningful_wau_four_weeks_prior
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.weekly_engagement` AS engagement
  WHERE week_end < DATE(data_as_of_at)
    AND week_end < CURRENT_DATE('UTC')
),
engagement_periods AS (
  SELECT
    *,
    ROW_NUMBER() OVER (ORDER BY week_start DESC) AS recency_rank
  FROM engagement_compared
),
activation_periods AS (
  SELECT
    cohort.*,
    ROW_NUMBER() OVER (ORDER BY cohort_week DESC) AS recency_rank
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.activation_cohorts` AS cohort
  WHERE setup_7_day_mature
    AND cohort_week_end < DATE(data_as_of_at)
    AND cohort_week_end < CURRENT_DATE('UTC')
)
SELECT
  account.week_start AS account_week_start,
  account.week_end AS account_week_end,
  account.prior_account_week_start,
  account.prior_account_week_end,
  account.new_accounts,
  account.prior_week_new_accounts,
  engagement.week_start AS engagement_week_start,
  engagement.week_end AS engagement_week_end,
  engagement.prior_engagement_week_start,
  engagement.prior_engagement_week_end,
  engagement.four_week_comparison_week_start,
  engagement.four_week_comparison_week_end,
  engagement.meaningful_wau,
  engagement.prior_week_meaningful_wau,
  engagement.controller_wau,
  engagement.prior_week_controller_wau,
  IF(
    engagement.meaningful_wau_four_weeks_prior IS NULL
      OR engagement.meaningful_wau_four_weeks_prior = 0,
    NULL,
    SAFE_DIVIDE(engagement.meaningful_wau, engagement.meaningful_wau_four_weeks_prior) - 1
  ) AS four_week_wau_growth,
  activation.cohort_week AS activation_cohort_week,
  activation.cohort_week_end AS activation_cohort_week_end,
  activation.bridge_registered_within_7_days AS bridge_setup_within_7_days,
  activation.total_accounts AS bridge_setup_7_day_denominator,
  SAFE_DIVIDE(activation.bridge_registered_within_7_days, activation.total_accounts) AS bridge_setup_7_day_rate,
  activation.activated_within_7_days,
  activation.activation_eligible_7_day_accounts AS activation_7_day_denominator,
  SAFE_DIVIDE(
    activation.activated_within_7_days,
    activation.activation_eligible_7_day_accounts
  ) AS activation_7_day_rate,
  activation.project_available_within_7_days,
  SAFE_DIVIDE(
    activation.project_available_within_7_days,
    activation.activation_eligible_7_day_accounts
  ) AS project_available_7_day_rate,
  activation.time_to_project_p50_seconds,
  activation.time_to_project_p75_seconds,
  activation.time_to_activation_p50_seconds,
  activation.time_to_activation_p75_seconds,
  engagement.active_days_p50,
  engagement.active_days_p75,
  engagement.remote_interventions,
  engagement.remote_interventions_per_controller,
  activation.preference_coverage,
  activation.foundation_coverage,
  activation.activation_capability_coverage,
  activation.setup_1_day_mature AS one_day_cohort_mature,
  activation.setup_7_day_mature AS seven_day_cohort_mature,
  account.data_as_of_at AS account_data_as_of_at,
  engagement.data_as_of_at AS engagement_data_as_of_at,
  activation.data_as_of_at AS activation_data_as_of_at,
  (
    SELECT MAX(timestamp_value)
    FROM UNNEST([
      account.refreshed_at,
      engagement.refreshed_at,
      activation.refreshed_at
    ]) AS timestamp_value
  ) AS refreshed_at
FROM (SELECT 1 AS singleton) AS base
LEFT JOIN account_periods AS account ON account.recency_rank = base.singleton
LEFT JOIN engagement_periods AS engagement ON engagement.recency_rank = base.singleton
LEFT JOIN activation_periods AS activation ON activation.recency_rank = base.singleton;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.activation_funnel`
OPTIONS (description = 'Weekly account-to-bridge-to-project-to-message funnel with explicit maturity and coverage') AS
SELECT
  cohort_week,
  cohort_week_end,
  total_accounts,
  enabled_accounts,
  preference_coverage,
  foundation_exposed_accounts,
  foundation_coverage,
  behavioral_window_mature_accounts,
  activation_capable_accounts,
  IF(setup_1_day_mature, activation_capability_coverage, NULL) AS activation_capability_coverage,
  IF(setup_1_day_mature, project_available_within_1_day, NULL) AS project_available_within_1_day,
  IF(setup_7_day_mature, project_available_within_7_days, NULL) AS project_available_within_7_days,
  IF(setup_30_day_mature, project_available_within_30_days, NULL) AS project_available_within_30_days,
  IF(setup_1_day_mature, SAFE_DIVIDE(project_available_within_1_day, activation_eligible_1_day_accounts), NULL) AS project_available_1_day_rate,
  IF(setup_7_day_mature, SAFE_DIVIDE(project_available_within_7_days, activation_eligible_7_day_accounts), NULL) AS project_available_7_day_rate,
  IF(setup_30_day_mature, SAFE_DIVIDE(project_available_within_30_days, activation_eligible_30_day_accounts), NULL) AS project_available_30_day_rate,
  IF(setup_1_day_mature, activation_eligible_1_day_accounts, NULL) AS activation_eligible_1_day_accounts,
  IF(setup_1_day_mature, activated_within_1_day, NULL) AS activated_within_1_day,
  IF(setup_1_day_mature, SAFE_DIVIDE(activated_within_1_day, activation_eligible_1_day_accounts), NULL) AS activation_1_day_rate,
  IF(setup_7_day_mature, activation_eligible_7_day_accounts, NULL) AS activation_eligible_7_day_accounts,
  IF(setup_7_day_mature, activated_within_7_days, NULL) AS activated_within_7_days,
  IF(setup_7_day_mature, SAFE_DIVIDE(activated_within_7_days, activation_eligible_7_day_accounts), NULL) AS activation_7_day_rate,
  IF(setup_30_day_mature, activation_eligible_30_day_accounts, NULL) AS activation_eligible_30_day_accounts,
  IF(setup_30_day_mature, activated_within_30_days, NULL) AS activated_within_30_days,
  IF(setup_30_day_mature, SAFE_DIVIDE(activated_within_30_days, activation_eligible_30_day_accounts), NULL) AS activation_30_day_rate,
  existing_session_activations,
  remote_created_session_activations,
  time_to_project_p50_seconds,
  time_to_project_p75_seconds,
  time_to_activation_p50_seconds,
  time_to_activation_p75_seconds,
  IF(setup_1_day_mature, notification_registered_within_1_day, NULL) AS notification_registered_within_1_day,
  IF(setup_7_day_mature, notification_registered_within_7_days, NULL) AS notification_registered_within_7_days,
  IF(setup_30_day_mature, notification_registered_within_30_days, NULL) AS notification_registered_within_30_days,
  IF(setup_1_day_mature, bridge_registered_within_1_day, NULL) AS bridge_registered_within_1_day,
  IF(setup_7_day_mature, bridge_registered_within_7_days, NULL) AS bridge_registered_within_7_days,
  IF(setup_30_day_mature, bridge_registered_within_30_days, NULL) AS bridge_registered_within_30_days,
  IF(setup_1_day_mature, legacy_metadata_request_within_1_day, NULL) AS legacy_metadata_request_within_1_day,
  IF(setup_7_day_mature, legacy_metadata_request_within_7_days, NULL) AS legacy_metadata_request_within_7_days,
  IF(setup_30_day_mature, legacy_metadata_request_within_30_days, NULL) AS legacy_metadata_request_within_30_days,
  IF(setup_1_day_mature, SAFE_DIVIDE(bridge_registered_within_1_day, total_accounts), NULL) AS bridge_1_day_rate,
  IF(setup_7_day_mature, SAFE_DIVIDE(bridge_registered_within_7_days, total_accounts), NULL) AS bridge_7_day_rate,
  IF(setup_30_day_mature, SAFE_DIVIDE(bridge_registered_within_30_days, total_accounts), NULL) AS bridge_30_day_rate,
  setup_1_day_mature,
  setup_7_day_mature,
  setup_30_day_mature,
  data_as_of_at,
  refreshed_at
FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.activation_cohorts`
WHERE cohort_week_end < CURRENT_DATE('UTC')
  AND cohort_week_end < DATE(data_as_of_at);

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.retention`
OPTIONS (description = 'Activation-anchored W1 [7d,14d) and W4 [28d,35d) retention with eligible denominators') AS
SELECT
  activation_week,
  activation_week_end,
  activated_users,
  w1_cohort_mature,
  IF(w1_cohort_mature, w1_eligible_users, NULL) AS w1_eligible_users,
  IF(w1_cohort_mature, w1_retained_users, NULL) AS w1_retained_users,
  IF(w1_cohort_mature, w1_retention_rate, NULL) AS w1_retention_rate,
  w4_cohort_mature,
  IF(w4_cohort_mature, w4_eligible_users, NULL) AS w4_eligible_users,
  IF(w4_cohort_mature, w4_retained_users, NULL) AS w4_retained_users,
  IF(w4_cohort_mature, w4_retention_rate, NULL) AS w4_retention_rate,
  data_as_of_at,
  refreshed_at
FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.retention_cohorts`;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.feature_adoption`
OPTIONS (description = 'Complete-week bounded feature and voice adoption among current eligible accounts') AS
SELECT
  week_start,
  week_end,
  meaningful_wau,
  controller_wau,
  successful_messages,
  voice_assisted_messages,
  voice_assisted_message_users,
  SAFE_DIVIDE(voice_assisted_message_users, meaningful_wau) AS voice_assisted_user_share,
  SAFE_DIVIDE(voice_assisted_messages, successful_messages) AS voice_assisted_message_share,
  voice_transcription_users,
  remote_created_session_users,
  remote_created_sessions,
  dedicated_worktree_users,
  dedicated_worktree_sessions,
  SAFE_DIVIDE(dedicated_worktree_sessions, remote_created_sessions) AS dedicated_worktree_session_share,
  diff_users,
  question_users,
  permission_users,
  abort_users,
  screen_users,
  project_available_users,
  data_as_of_at,
  refreshed_at
FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.weekly_engagement`;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.installation_login_funnel`
OPTIONS (description = 'Account-less login event counts; diagnostic only and may include internal/test traffic') AS
SELECT
  event_date,
  schema_version,
  platform,
  app_version,
  provider,
  SUM(IF(event_name = 'login_attempt_started', event_count, 0)) AS started_events,
  SUM(IF(event_name = 'login_attempt_completed', event_count, 0)) AS completed_events,
  SUM(IF(event_name = 'login_attempt_failed', event_count, 0)) AS failed_events,
  SUM(IF(event_name = 'login_attempt_failed' AND failure_kind = 'authentication', event_count, 0)) AS authentication_failures,
  SUM(IF(event_name = 'login_attempt_failed' AND failure_kind = 'launch', event_count, 0)) AS launch_failures,
  SUM(IF(event_name = 'login_attempt_failed' AND failure_kind = 'cancelled', event_count, 0)) AS cancelled_failures,
  SUM(IF(event_name = 'login_attempt_failed' AND failure_kind = 'timeout', event_count, 0)) AS timeout_failures,
  SUM(IF(event_name = 'login_attempt_failed' AND failure_kind = 'unknown', event_count, 0)) AS unknown_failures,
  SAFE_DIVIDE(
    SUM(IF(event_name = 'login_attempt_completed', event_count, 0)),
    SUM(IF(event_name = 'login_attempt_started', event_count, 0))
  ) AS event_completion_rate,
  'account_less_login_events' AS measurement_unit,
  LOGICAL_OR(includes_internal_test_traffic) AS includes_internal_test_traffic,
  MAX(refreshed_at) AS refreshed_at
FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.installation_login_daily`
GROUP BY event_date, schema_version, platform, app_version, provider;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.screen_usage`
OPTIONS (description = 'Canonical custom product_screen_viewed usage; Firebase-native screen_view is excluded') AS
SELECT
  week_start,
  week_end,
  platform,
  app_version,
  screen,
  unique_users,
  view_count,
  refreshed_at
FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.screen_usage_weekly`;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.onboarding_friction`
OPTIONS (description = 'Complete-week empty states, bounded creation failures, and onboarding support/install outcomes') AS
SELECT
  week_start,
  week_end,
  metric_name,
  platform,
  app_version,
  surface,
  channel,
  install_method,
  install_os,
  failure_reason,
  workspace_kind,
  unique_users,
  event_count,
  refreshed_at
FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.onboarding_friction_weekly`;

CREATE OR REPLACE VIEW `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.data_quality`
OPTIONS (description = 'Identifier-free pipeline freshness, bounded schema/app distribution, exclusions, coverage, and maturity') AS
WITH ranked_auth AS (
  SELECT
    published_at,
    run_cutoff,
    control_updated_at,
    external_accounts,
    enabled_accounts,
    users_scanned,
    source_suppressed_users,
    internal_users,
    opted_out_accounts,
    preference_after_cutoff_accounts,
    late_preference_rows_removed,
    milestone_rows_published,
    ROW_NUMBER() OVER (ORDER BY published_at DESC, run_cutoff DESC) AS recency_rank
  FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.product_analytics_export_runs`
),
latest_auth_values AS (
  SELECT
    MAX(IF(recency_rank = 1, published_at, NULL)) AS published_at,
    MAX(IF(recency_rank = 1, run_cutoff, NULL)) AS run_cutoff,
    MAX(IF(recency_rank = 1, control_updated_at, NULL)) AS control_updated_at,
    MAX(IF(recency_rank = 1, external_accounts, NULL)) AS external_accounts,
    MAX(IF(recency_rank = 1, enabled_accounts, NULL)) AS enabled_accounts,
    MAX(IF(recency_rank = 1, users_scanned, NULL)) AS users_scanned,
    MAX(IF(recency_rank = 1, source_suppressed_users, NULL)) AS source_suppressed_users,
    MAX(IF(recency_rank = 1, internal_users, NULL)) AS internal_users,
    MAX(IF(recency_rank = 1, opted_out_accounts, NULL)) AS opted_out_accounts,
    MAX(IF(recency_rank = 1, preference_after_cutoff_accounts, NULL)) AS preference_after_cutoff_accounts,
    MAX(IF(recency_rank = 1, late_preference_rows_removed, NULL)) AS late_preference_rows_removed,
    MAX(IF(recency_rank = 1, milestone_rows_published, NULL)) AS milestone_rows_published
  FROM ranked_auth
),
latest_auth AS (
  SELECT
    *,
    users_scanned = source_suppressed_users + internal_users + external_accounts
      AND external_accounts = enabled_accounts + opted_out_accounts
        + preference_after_cutoff_accounts + late_preference_rows_removed
      AND milestone_rows_published = enabled_accounts AS reconciled
  FROM latest_auth_values
),
current_internal_control AS (
  SELECT MAX(IF(state_key = 'singleton', control_updated_at, NULL)) AS control_updated_at
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state`
),
latest_complete_activation AS (
  SELECT *
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.activation_cohorts`
  WHERE cohort_week_end < CURRENT_DATE('UTC')
    AND cohort_week_end < DATE(data_as_of_at)
  ORDER BY cohort_week DESC
  LIMIT 1
),
latest_retention_status AS (
  SELECT
    MAX(data_as_of_at) AS data_as_of_at,
    MAX(refreshed_at) AS refreshed_at
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.retention_cohorts`
),
latest_w1_retention AS (
  SELECT *
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.retention_cohorts`
  WHERE w1_cohort_mature
  ORDER BY activation_week DESC
  LIMIT 1
),
latest_w4_retention AS (
  SELECT *
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.retention_cohorts`
  WHERE w4_cohort_mature
  ORDER BY activation_week DESC
  LIMIT 1
),
expected_models AS (
  SELECT model_name
  FROM UNNEST([
    'events_flattened',
    'installation_login_daily',
    'user_activity_daily',
    'user_milestones',
    'activation_retention'
  ]) AS model_name
),
pipeline AS (
  SELECT
    CURRENT_TIMESTAMP() AS observed_at,
    'pipeline' AS category,
    expected.model_name AS metric_name,
    CONCAT(CAST(source_start_date AS STRING), '..', CAST(source_end_date AS STRING)) AS dimension_value,
    published_rows AS metric_count,
    CAST(NULL AS FLOAT64) AS metric_rate,
    CASE
      WHEN state.model_name IS NULL THEN 'missing'
      WHEN completed_at < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 36 HOUR) THEN 'stale'
      WHEN source_end_date < DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 2 DAY) THEN 'source_lagging'
      ELSE 'ok'
    END AS status,
    source_end_date AS data_as_of_date,
    latest_emitted_at AS latest_event_at,
    completed_at AS latest_transform_at
  FROM expected_models AS expected
  LEFT JOIN `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state` AS state USING (model_name)
),
quality_counters AS (
  SELECT
    CURRENT_TIMESTAMP() AS observed_at,
    'quality_counter' AS category,
    CONCAT(state.model_name, '.', counter.metric_name) AS metric_name,
    CAST(NULL AS STRING) AS dimension_value,
    counter.metric_count,
    CAST(NULL AS FLOAT64) AS metric_rate,
    IF(counter.metric_count = 0, 'ok', 'review') AS status,
    state.source_end_date AS data_as_of_date,
    state.latest_emitted_at AS latest_event_at,
    state.completed_at AS latest_transform_at
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state` AS state
  CROSS JOIN UNNEST([
    STRUCT('missing_identity_rows' AS metric_name, state.missing_identity_rows AS metric_count),
    STRUCT('malformed_identity_rows' AS metric_name, state.malformed_identity_rows AS metric_count),
    STRUCT('missing_schema_rows' AS metric_name, state.missing_schema_rows AS metric_count),
    STRUCT('unsupported_schema_rows' AS metric_name, state.unsupported_schema_rows AS metric_count),
    STRUCT('missing_occurrence_rows' AS metric_name, state.missing_occurrence_rows AS metric_count),
    STRUCT('future_occurrence_rows' AS metric_name, state.future_occurrence_rows AS metric_count),
    STRUCT('before_account_rows' AS metric_name, state.before_account_rows AS metric_count),
    STRUCT('invalid_parameter_rows' AS metric_name, state.invalid_parameter_rows AS metric_count),
    STRUCT('unknown_enum_rows' AS metric_name, state.unknown_enum_rows AS metric_count),
    STRUCT('internal_excluded_rows' AS metric_name, state.internal_excluded_rows AS metric_count),
    STRUCT('deletion_excluded_rows' AS metric_name, state.deletion_excluded_rows AS metric_count),
    STRUCT('ineligible_user_rows' AS metric_name, state.ineligible_user_rows AS metric_count)
  ]) AS counter
),
auth_freshness AS (
  SELECT
    CURRENT_TIMESTAMP() AS observed_at,
    'auth_snapshot' AS category,
    'current_eligible_accounts' AS metric_name,
    CAST(NULL AS STRING) AS dimension_value,
    COALESCE(enabled_accounts, 0) AS metric_count,
    SAFE_DIVIDE(enabled_accounts, external_accounts) AS metric_rate,
    CASE
      WHEN published_at IS NULL THEN 'missing'
      WHEN NOT reconciled THEN 'reconciliation_failed'
      WHEN latest_auth.control_updated_at IS DISTINCT FROM current_control.control_updated_at
        THEN 'internal_control_mismatch'
      WHEN published_at > TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 300 SECOND)
        OR run_cutoff > published_at THEN 'future_dated'
      WHEN published_at < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 36 HOUR)
        OR run_cutoff < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 36 HOUR) THEN 'stale'
      ELSE 'ok'
    END AS status,
    DATE(run_cutoff) AS data_as_of_date,
    CAST(NULL AS TIMESTAMP) AS latest_event_at,
    published_at AS latest_transform_at
  FROM latest_auth
  CROSS JOIN current_internal_control AS current_control
),
coverage AS (
  SELECT
    CURRENT_TIMESTAMP() AS observed_at,
    'coverage' AS category,
    metric.metric_name,
    CAST(cohort.cohort_week AS STRING) AS dimension_value,
    metric.metric_count,
    metric.metric_rate,
    IF(metric.metric_rate IS NULL, 'not_mature', 'measured') AS status,
    DATE(cohort.data_as_of_at) AS data_as_of_date,
    CAST(NULL AS TIMESTAMP) AS latest_event_at,
    cohort.refreshed_at AS latest_transform_at
  FROM latest_complete_activation AS cohort
  CROSS JOIN UNNEST([
    STRUCT('preference' AS metric_name, cohort.enabled_accounts AS metric_count, cohort.preference_coverage AS metric_rate),
    STRUCT('foundation' AS metric_name, cohort.foundation_exposed_accounts AS metric_count, cohort.foundation_coverage AS metric_rate),
    STRUCT('activation_capability' AS metric_name, cohort.activation_capable_accounts AS metric_count, IF(cohort.setup_1_day_mature, cohort.activation_capability_coverage, NULL) AS metric_rate),
    STRUCT('activation_7_day_maturity' AS metric_name, IF(cohort.setup_7_day_mature, cohort.activation_eligible_7_day_accounts, NULL) AS metric_count, IF(cohort.setup_7_day_mature, SAFE_DIVIDE(cohort.activated_within_7_days, cohort.activation_eligible_7_day_accounts), NULL) AS metric_rate)
  ]) AS metric
),
maturity AS (
  SELECT
    CURRENT_TIMESTAMP() AS observed_at,
    'cohort_maturity' AS category,
    'w1_eligible_users' AS metric_name,
    CAST(cohort.activation_week AS STRING) AS dimension_value,
    cohort.w1_eligible_users AS metric_count,
    SAFE_DIVIDE(cohort.w1_eligible_users, cohort.activated_users) AS metric_rate,
    IF(cohort.activation_week IS NULL, 'not_mature', 'measured') AS status,
    DATE(COALESCE(cohort.data_as_of_at, latest.data_as_of_at)) AS data_as_of_date,
    CAST(NULL AS TIMESTAMP) AS latest_event_at,
    COALESCE(cohort.refreshed_at, latest.refreshed_at) AS latest_transform_at
  FROM latest_retention_status AS latest
  LEFT JOIN latest_w1_retention AS cohort ON TRUE
  UNION ALL
  SELECT
    CURRENT_TIMESTAMP() AS observed_at,
    'cohort_maturity' AS category,
    'w4_eligible_users' AS metric_name,
    CAST(cohort.activation_week AS STRING) AS dimension_value,
    cohort.w4_eligible_users AS metric_count,
    SAFE_DIVIDE(cohort.w4_eligible_users, cohort.activated_users) AS metric_rate,
    IF(cohort.activation_week IS NULL, 'not_mature', 'measured') AS status,
    DATE(COALESCE(cohort.data_as_of_at, latest.data_as_of_at)) AS data_as_of_date,
    CAST(NULL AS TIMESTAMP) AS latest_event_at,
    COALESCE(cohort.refreshed_at, latest.refreshed_at) AS latest_transform_at
  FROM latest_retention_status AS latest
  LEFT JOIN latest_w4_retention AS cohort ON TRUE
),
schema_distribution AS (
  SELECT
    CURRENT_TIMESTAMP() AS observed_at,
    'schema' AS category,
    'account_event_schema_version' AS metric_name,
    CAST(schema_version AS STRING) AS dimension_value,
    COUNT(*) AS metric_count,
    CAST(NULL AS FLOAT64) AS metric_rate,
    IF(schema_version = 1, 'supported', 'unsupported') AS status,
    MAX(DATE(occurred_at)) AS data_as_of_date,
    MAX(emitted_at) AS latest_event_at,
    CAST(NULL AS TIMESTAMP) AS latest_transform_at
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened`
  WHERE source_export_date BETWEEN DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 425 DAY)
    AND DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY)
  GROUP BY schema_version
),
app_distribution AS (
  SELECT
    CURRENT_TIMESTAMP() AS observed_at,
    'app_release' AS category,
    'account_event_rows' AS metric_name,
    CONCAT(
      COALESCE(platform, 'unknown'), '/',
      COALESCE(app_version, 'unknown')
    ) AS dimension_value,
    COUNT(*) AS metric_count,
    CAST(NULL AS FLOAT64) AS metric_rate,
    IF(app_version IS NULL, 'missing_version', 'observed') AS status,
    MAX(DATE(occurred_at)) AS data_as_of_date,
    MAX(emitted_at) AS latest_event_at,
    CAST(NULL AS TIMESTAMP) AS latest_transform_at
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened`
  WHERE source_export_date BETWEEN DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 425 DAY)
    AND DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY)
  GROUP BY platform, app_version
)
SELECT * FROM pipeline
UNION ALL SELECT * FROM quality_counters
UNION ALL SELECT * FROM auth_freshness
UNION ALL SELECT * FROM coverage
UNION ALL SELECT * FROM maturity
UNION ALL SELECT * FROM schema_distribution
UNION ALL SELECT * FROM app_distribution;
