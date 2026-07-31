-- BigQuery Standard SQL. Run after DDL/transforms against a non-production or
-- production deployment; assertions inspect schemas and bounded curated values.

CREATE TEMP TABLE expected_flattened_columns AS
SELECT column_name
FROM UNNEST([
  'event_name',
  'source_export_date',
  'emitted_at',
  'occurred_at_micros',
  'occurred_at',
  'schema_version',
  'user_key',
  'platform',
  'app_version',
  'app_build',
  'activation_schema_version',
  'inventory_state',
  'activity_state',
  'submission_kind',
  'input_mode',
  'workspace_kind',
  'failure_reason',
  'decision',
  'change_state',
  'surface',
  'channel',
  'method',
  'os',
  'screen'
]) AS column_name;

ASSERT NOT EXISTS (
  SELECT column_name FROM expected_flattened_columns
  EXCEPT DISTINCT
  SELECT column_name
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'events_flattened'
) AND NOT EXISTS (
  SELECT column_name
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'events_flattened'
  EXCEPT DISTINCT
  SELECT column_name FROM expected_flattened_columns
) AS 'events_flattened columns must exactly match the approved scalar allowlist';

CREATE TEMP TABLE expected_login_columns AS
SELECT column_name
FROM UNNEST([
  'source_export_date',
  'event_date',
  'event_name',
  'schema_version',
  'platform',
  'app_version',
  'app_build',
  'provider',
  'failure_kind',
  'event_count',
  'includes_internal_test_traffic',
  'refreshed_at'
]) AS column_name;

ASSERT NOT EXISTS (
  SELECT column_name FROM expected_login_columns
  EXCEPT DISTINCT
  SELECT column_name
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'installation_login_daily'
) AND NOT EXISTS (
  SELECT column_name
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'installation_login_daily'
  EXCEPT DISTINCT
  SELECT column_name FROM expected_login_columns
) AS 'installation_login_daily must remain an identifier-free exact schema';

CREATE TEMP TABLE expected_auth_schemas (
  table_name STRING,
  ordered_columns ARRAY<STRING>,
  required_columns ARRAY<STRING>
);
INSERT INTO expected_auth_schemas VALUES
  (
    'auth_user_milestones',
    ['user_key', 'account_created_at', 'notification_registered_at', 'bridge_registered_at', 'legacy_first_metadata_request_at', 'exported_at'],
    ['user_key', 'account_created_at', 'exported_at']
  ),
  (
    'auth_weekly_setup_cohorts',
    [
      'cohort_week',
      'total_accounts',
      'enabled_accounts',
      'notification_registered_within_1_day',
      'notification_registered_within_7_days',
      'notification_registered_within_30_days',
      'bridge_registered_within_1_day',
      'bridge_registered_within_7_days',
      'bridge_registered_within_30_days',
      'legacy_first_metadata_request_within_1_day',
      'legacy_first_metadata_request_within_7_days',
      'legacy_first_metadata_request_within_30_days',
      'exported_at'
    ],
    [
      'cohort_week',
      'total_accounts',
      'enabled_accounts',
      'notification_registered_within_1_day',
      'notification_registered_within_7_days',
      'notification_registered_within_30_days',
      'bridge_registered_within_1_day',
      'bridge_registered_within_7_days',
      'bridge_registered_within_30_days',
      'legacy_first_metadata_request_within_1_day',
      'legacy_first_metadata_request_within_7_days',
      'legacy_first_metadata_request_within_30_days',
      'exported_at'
    ]
  ),
  (
    'product_analytics_export_runs',
    [
      'run_id',
      'run_cutoff',
      'preference_scan_cutoff',
      'control_updated_at',
      'users_scanned',
      'source_suppressed_users',
      'internal_users',
      'external_accounts',
      'enabled_accounts',
      'opted_out_accounts',
      'preference_after_cutoff_accounts',
      'late_preference_rows_removed',
      'milestone_rows_published',
      'cohort_rows_published',
      'published_at'
    ],
    [
      'run_id',
      'run_cutoff',
      'preference_scan_cutoff',
      'control_updated_at',
      'users_scanned',
      'source_suppressed_users',
      'internal_users',
      'external_accounts',
      'enabled_accounts',
      'opted_out_accounts',
      'preference_after_cutoff_accounts',
      'late_preference_rows_removed',
      'milestone_rows_published',
      'cohort_rows_published',
      'published_at'
    ]
  ),
  (
    'product_analytics_export_state',
    ['state_key', 'active_run_id', 'lease_expires_at', 'last_published_run_id', 'last_published_cutoff', 'updated_at'],
    ['state_key', 'updated_at']
  );

ASSERT NOT EXISTS (
  SELECT 1
  FROM expected_auth_schemas AS expected
  WHERE TO_JSON_STRING(expected.ordered_columns) != TO_JSON_STRING((
    SELECT ARRAY_AGG(column_name ORDER BY ordinal_position)
    FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = expected.table_name
  ))
) AS 'Permanent auth export columns must exactly match the auth repository contract';

ASSERT NOT EXISTS (
  SELECT 1
  FROM expected_auth_schemas AS expected
  WHERE EXISTS (
    SELECT required_column FROM UNNEST(expected.required_columns) AS required_column
    EXCEPT DISTINCT
    SELECT column_name
    FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = expected.table_name AND is_nullable = 'NO'
  ) OR EXISTS (
    SELECT column_name
    FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
    WHERE table_name = expected.table_name AND is_nullable = 'NO'
    EXCEPT DISTINCT
    SELECT required_column FROM UNNEST(expected.required_columns) AS required_column
  )
) AS 'Permanent auth export required/nullability modes must exactly match the auth repository contract';

ASSERT TO_JSON_STRING((
  SELECT ARRAY_AGG(column_name ORDER BY ordinal_position)
  FROM `{{PROJECT_ID}}.{{PRIVACY_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'product_analytics_deletion_targets'
)) = TO_JSON_STRING(['request_id', 'user_key', 'legacy_firebase_user_id', 'suppressed_at', 'status', 'last_error_code', 'completed_at', 'created_at', 'updated_at'])
  AS 'Privacy deletion target schema must match the isolated auth handoff';

ASSERT TO_JSON_STRING((
  SELECT ARRAY_AGG(column_name ORDER BY ordinal_position)
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'permanent_deletion_exclusions'
)) = TO_JSON_STRING(['user_key', 'suppressed_at', 'created_at', 'updated_at'])
  AS 'Permanent deletion exclusion schema must match the privacy processor contract';

ASSERT TO_JSON_STRING((
  SELECT ARRAY_AGG(column_name ORDER BY ordinal_position)
  FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'product_analytics_privacy_sweep_state'
)) = TO_JSON_STRING(['sweep_name', 'last_success_through_date', 'updated_at'])
  AS 'Privacy sweep checkpoint must remain identifier-free and monotonic';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE LOWER(column_name) IN (
    'user_pseudo_id',
    'user_id',
    'event_params',
    'user_properties',
    'geo',
    'device',
    'device_model',
    'device_brand',
    'advertising_id',
    'vendor_id',
    'stream_id',
    'traffic_source',
    'prompt',
    'response',
    'transcript_text',
    'code',
    'path',
    'project_id',
    'session_id',
    'bridge_id',
    'notification_id',
    'raw_error'
  )
) AS 'Curated schemas must not persist raw identifiers, arbitrary records, device/geo data, or sensitive content';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE LOWER(column_name) IN (
    'user_key',
    'user_pseudo_id',
    'user_id',
    'request_id',
    'privacy_request_id',
    'legacy_firebase_user_id',
    'project_id',
    'session_id',
    'bridge_id',
    'device_id',
    'notification_id'
  )
) AS 'Reporting views must expose no account, installation, entity, or deletion-request identifier';

CREATE TEMP TABLE expected_reporting_views AS
SELECT table_name
FROM UNNEST([
  'investor_snapshot',
  'weekly_kpis',
  'activation_funnel',
  'retention',
  'feature_adoption',
  'installation_login_funnel',
  'screen_usage',
  'onboarding_friction',
  'data_quality'
]) AS table_name;

ASSERT NOT EXISTS (
  SELECT table_name FROM expected_reporting_views
  EXCEPT DISTINCT
  SELECT table_name
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.INFORMATION_SCHEMA.TABLES`
  WHERE table_type = 'VIEW'
) AS 'Every required identifier-free reporting view must exist';

ASSERT NOT EXISTS (
  SELECT required_column
  FROM UNNEST([
    'account_week_start',
    'account_week_end',
    'engagement_week_start',
    'engagement_week_end',
    'activation_cohort_week',
    'activation_cohort_week_end',
    'account_data_as_of_at',
    'engagement_data_as_of_at',
    'activation_data_as_of_at'
  ]) AS required_column
  EXCEPT DISTINCT
  SELECT column_name
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'investor_snapshot'
) AND NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'investor_snapshot'
    AND column_name IN ('week_start', 'week_end', 'data_as_of_at')
) AS 'Investor snapshot must expose explicit account, engagement, and mature activation periods';

ASSERT NOT EXISTS (
  SELECT cohort_week
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.activation_cohorts`
  WHERE cohort_week_end < CURRENT_DATE('UTC')
    AND cohort_week_end < DATE(data_as_of_at)
  EXCEPT DISTINCT
  SELECT week_start
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.weekly_kpis`
) AS 'weekly_kpis must preserve complete account weeks even without engagement rows';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.activation_funnel`
  WHERE (
      NOT setup_1_day_mature
      AND COALESCE(
        project_available_within_1_day,
        activation_eligible_1_day_accounts,
        activated_within_1_day,
        notification_registered_within_1_day,
        bridge_registered_within_1_day,
        legacy_metadata_request_within_1_day
      ) IS NOT NULL
    ) OR (
      NOT setup_7_day_mature
      AND COALESCE(
        project_available_within_7_days,
        activation_eligible_7_day_accounts,
        activated_within_7_days,
        notification_registered_within_7_days,
        bridge_registered_within_7_days,
        legacy_metadata_request_within_7_days
      ) IS NOT NULL
    ) OR (
      NOT setup_30_day_mature
      AND COALESCE(
        project_available_within_30_days,
        activation_eligible_30_day_accounts,
        activated_within_30_days,
        notification_registered_within_30_days,
        bridge_registered_within_30_days,
        legacy_metadata_request_within_30_days
      ) IS NOT NULL
    )
) AS 'Immature activation-funnel windows must expose null counts rather than partial values';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.activation_funnel`
  WHERE cohort_week_end >= DATE(data_as_of_at)
) AS 'Activation funnel must not expose a week incomplete at its published data watermark';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.retention`
  WHERE (
      NOT w1_cohort_mature
      AND COALESCE(w1_eligible_users, w1_retained_users) IS NOT NULL
    ) OR (
      NOT w4_cohort_mature
      AND COALESCE(w4_eligible_users, w4_retained_users) IS NOT NULL
    ) OR (NOT w1_cohort_mature AND w1_retention_rate IS NOT NULL)
      OR (NOT w4_cohort_mature AND w4_retention_rate IS NOT NULL)
) AS 'Partially mature activation weeks must not expose W1 or W4 retention results';

ASSERT NOT EXISTS (
  WITH expected AS (
    SELECT week_start, week_end, new_accounts
    FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.weekly_kpis`
    WHERE week_end < DATE(data_as_of_at)
      AND week_end < CURRENT_DATE('UTC')
    ORDER BY week_start DESC
    LIMIT 1
  ),
  actual AS (
    SELECT account_week_start, account_week_end, new_accounts
    FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.investor_snapshot`
  )
  SELECT 1
  FROM expected
  FULL OUTER JOIN actual ON TRUE
  WHERE expected.week_start IS DISTINCT FROM actual.account_week_start
    OR expected.week_end IS DISTINCT FROM actual.account_week_end
    OR expected.new_accounts IS DISTINCT FROM actual.new_accounts
) AS 'Investor account headline must use the latest complete weekly spine even when signups are zero';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.weekly_kpis` AS weekly
  CROSS JOIN `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.analytics_measurement_config` AS config
  WHERE config.config_key = 'singleton'
    AND TIMESTAMP(weekly.week_start) < config.behavioral_schema_v1_start_at
    AND weekly.meaningful_wau IS NOT NULL
) AS 'Pre-behavior account weeks must retain null engagement rather than a synthetic zero';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{REPORTING_DATASET_ID}}.data_quality`
  WHERE category = 'auth_snapshot'
    AND status = 'ok'
    AND (
      SELECT control_updated_at
      FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.product_analytics_export_runs`
      ORDER BY published_at DESC, run_cutoff DESC
      LIMIT 1
    ) IS DISTINCT FROM (
      SELECT control_updated_at
      FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.internal_exclusion_control_state`
      WHERE state_key = 'singleton'
    )
) AS 'An internal exclusion control mismatch must never be reported as healthy';

ASSERT (
  SELECT COUNTIF(is_partitioning_column = 'YES')
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'events_flattened' AND column_name = 'source_export_date'
) = 1 AS 'events_flattened must remain partitioned by its UTC emission date';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened`
  WHERE source_export_date BETWEEN DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 425 DAY)
    AND DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY)
    AND source_export_date != DATE(emitted_at)
) AS 'events_flattened source_export_date must be the UTC emission date';

ASSERT (
  SELECT COUNTIF(clustering_ordinal_position IS NOT NULL)
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.INFORMATION_SCHEMA.COLUMNS`
  WHERE table_name = 'events_flattened' AND column_name IN ('event_name', 'user_key')
) = 2 AS 'events_flattened must remain clustered by event_name and user_key';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened`
  WHERE source_export_date BETWEEN DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 425 DAY)
    AND DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY)
    AND event_name NOT IN (
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
) AS 'events_flattened may contain only the current closed ProductAnalyticsEvent catalog';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened`
  WHERE source_export_date BETWEEN DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 425 DAY)
    AND DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY)
    AND (
      schema_version != 1
      OR NOT REGEXP_CONTAINS(user_key, r'^[a-f0-9]{64}$')
      OR occurred_at_micros != UNIX_MICROS(occurred_at)
      OR occurred_at > TIMESTAMP_ADD(emitted_at, INTERVAL 300 SECOND)
    )
) AS 'Flattened shared schema, key, occurrence, and clock-skew contracts must hold';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened` AS event
  WHERE event.source_export_date BETWEEN DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 425 DAY)
    AND DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY)
    AND (
      EXISTS (
        SELECT 1 FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_internal_user_exclusions` AS internal
        WHERE internal.user_key = event.user_key
      )
      OR EXISTS (
        SELECT 1 FROM `{{PROJECT_ID}}.{{CONTROLS_DATASET_ID}}.permanent_deletion_exclusions` AS deleted
        WHERE deleted.user_key = event.user_key
      )
    )
) AS 'Permanent internal and deletion exclusions must never survive flattened recomputation';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened`
  WHERE source_export_date BETWEEN DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 425 DAY)
    AND DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY)
    AND (
      (activation_schema_version IS NOT NULL AND event_name != 'analytics_activation_ready')
      OR (inventory_state IS NOT NULL AND event_name != 'project_inventory_loaded')
      OR (activity_state IS NOT NULL AND event_name != 'session_activity_viewed')
      OR (submission_kind IS NOT NULL AND event_name NOT IN ('session_message_sent', 'session_created_with_message'))
      OR (input_mode IS NOT NULL AND event_name NOT IN ('session_message_sent', 'session_created_with_message'))
      OR (workspace_kind IS NOT NULL AND event_name NOT IN ('session_created_with_message', 'session_creation_failed'))
      OR (failure_reason IS NOT NULL AND event_name != 'session_creation_failed')
      OR (decision IS NOT NULL AND event_name != 'session_permission_answered')
      OR (change_state IS NOT NULL AND event_name != 'session_diff_viewed')
      OR (surface IS NOT NULL AND event_name NOT IN (
        'onboarding_need_help_opened',
        'onboarding_support_link_opened',
        'onboarding_why_bridge_opened',
        'bridge_install_command_copied',
        'bridge_install_command_shared',
        'bridge_run_command_copied',
        'bridge_run_command_shared'
      ))
      OR (channel IS NOT NULL AND event_name != 'onboarding_support_link_opened')
      OR (method IS NOT NULL AND event_name NOT IN ('bridge_install_command_copied', 'bridge_install_command_shared'))
      OR (os IS NOT NULL AND event_name NOT IN ('bridge_install_command_copied', 'bridge_install_command_shared'))
      OR (screen IS NOT NULL AND event_name != 'product_screen_viewed')
    )
) AS 'Event-specific flattened parameter columns must be null outside their exact wire events';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened`
  WHERE source_export_date BETWEEN DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 425 DAY)
    AND DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY)
    AND (
      (event_name = 'analytics_activation_ready' AND activation_schema_version IS NULL)
      OR (event_name = 'project_inventory_loaded' AND inventory_state IS NULL)
      OR (event_name = 'session_activity_viewed' AND activity_state IS NULL)
      OR (event_name = 'session_message_sent' AND (submission_kind IS NULL OR input_mode IS NULL))
      OR (event_name = 'session_created_with_message' AND (
        submission_kind IS NULL OR input_mode IS NULL OR workspace_kind IS NULL
      ))
      OR (event_name = 'session_creation_failed' AND (failure_reason IS NULL OR workspace_kind IS NULL))
      OR (event_name = 'session_permission_answered' AND decision IS NULL)
      OR (event_name = 'session_diff_viewed' AND change_state IS NULL)
      OR (event_name IN (
        'onboarding_need_help_opened',
        'onboarding_support_link_opened',
        'onboarding_why_bridge_opened',
        'bridge_install_command_copied',
        'bridge_install_command_shared',
        'bridge_run_command_copied',
        'bridge_run_command_shared'
      ) AND surface IS NULL)
      OR (event_name = 'onboarding_support_link_opened' AND channel IS NULL)
      OR (event_name IN ('bridge_install_command_copied', 'bridge_install_command_shared') AND (
        method IS NULL OR os IS NULL
      ))
      OR (event_name = 'product_screen_viewed' AND screen IS NULL)
    )
) AS 'Every event-specific parameter required by the wire event must be present';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.events_flattened`
  WHERE source_export_date BETWEEN DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 425 DAY)
    AND DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY)
    AND (
      (activation_schema_version IS NOT NULL AND activation_schema_version != 1)
      OR (inventory_state IS NOT NULL AND inventory_state NOT IN ('empty', 'non_empty'))
      OR (activity_state IS NOT NULL AND activity_state NOT IN ('empty', 'non_empty'))
      OR (submission_kind IS NOT NULL AND submission_kind NOT IN ('text', 'command'))
      OR (input_mode IS NOT NULL AND input_mode NOT IN ('typed', 'voice_assisted'))
      OR (submission_kind = 'command' AND input_mode != 'typed')
      OR (workspace_kind IS NOT NULL AND workspace_kind NOT IN ('project', 'dedicated_worktree'))
      OR (failure_reason IS NOT NULL AND failure_reason NOT IN ('not_authenticated', 'server_rejected', 'network_down', 'bad_response', 'unknown'))
      OR (decision IS NOT NULL AND decision NOT IN ('once', 'always', 'reject'))
      OR (change_state IS NOT NULL AND change_state NOT IN ('empty', 'non_empty'))
      OR (surface IS NOT NULL AND surface NOT IN ('connect_setup', 'connected_empty', 'bridge_offline'))
      OR (channel IS NOT NULL AND channel NOT IN ('email', 'discord', 'x'))
      OR (method IS NOT NULL AND method NOT IN ('curl', 'powershell', 'npm', 'bun'))
      OR (os IS NOT NULL AND os NOT IN ('unix', 'windows'))
      OR (screen IS NOT NULL AND screen NOT IN (
        'login',
        'projects',
        'settings',
        'settings_notifications',
        'settings_profile',
        'sessions',
        'new_session',
        'session_detail',
        'session_diffs'
      ))
    )
) AS 'Flattened event parameters must remain inside the closed bounded value allowlists';

ASSERT NOT EXISTS (
  SELECT 1
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.installation_login_daily`
  WHERE source_export_date != event_date
    OR event_name NOT IN ('login_attempt_started', 'login_attempt_completed', 'login_attempt_failed')
    OR schema_version != 1
    OR provider NOT IN ('github', 'google', 'apple', 'email')
    OR (event_name = 'login_attempt_failed' AND (
      failure_kind IS NULL
      OR failure_kind NOT IN ('authentication', 'launch', 'cancelled', 'timeout', 'unknown')
    ))
    OR (event_name != 'login_attempt_failed' AND failure_kind IS NOT NULL)
    OR event_count <= 0
    OR NOT includes_internal_test_traffic
) AS 'Installation login aggregates must retain only the exact bounded diagnostic contract';

ASSERT NOT EXISTS (
  SELECT model_name
  FROM `{{PROJECT_ID}}.{{CURATED_DATASET_ID}}.transform_state`
  WHERE model_name NOT IN (
    'events_flattened',
    'installation_login_daily',
    'user_activity_daily',
    'user_milestones',
    'activation_retention'
  )
) AS 'Transform freshness state must remain a closed model set';
