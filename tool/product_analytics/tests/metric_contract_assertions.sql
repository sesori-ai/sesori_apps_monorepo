-- BigQuery Standard SQL. Self-contained fixture assertions; no production data
-- is read or mutated.
DECLARE fixture_now TIMESTAMP DEFAULT TIMESTAMP '2026-07-27 00:00:00+00';
DECLARE account_created_at TIMESTAMP DEFAULT TIMESTAMP '2026-06-01 10:00:00+00';
DECLARE activation_at TIMESTAMP DEFAULT TIMESTAMP '2026-06-01 11:00:00+00';

CREATE TEMP TABLE expected_account_events (event_name STRING, parameter_names ARRAY<STRING>);
INSERT INTO expected_account_events VALUES
  ('analytics_schema_ready', []),
  ('analytics_activation_ready', ['activation_schema_version']),
  ('project_inventory_loaded', ['inventory_state']),
  ('session_activity_viewed', ['activity_state']),
  ('session_message_sent', ['input_mode', 'submission_kind']),
  ('session_created_with_message', ['input_mode', 'submission_kind', 'workspace_kind']),
  ('session_creation_failed', ['failure_reason', 'workspace_kind']),
  ('voice_transcription_completed', []),
  ('session_question_answered', []),
  ('session_question_rejected', []),
  ('session_permission_answered', ['decision']),
  ('session_abort_succeeded', []),
  ('session_diff_viewed', ['change_state']),
  ('onboarding_need_help_opened', ['surface']),
  ('onboarding_support_link_opened', ['channel', 'surface']),
  ('onboarding_why_bridge_opened', ['surface']),
  ('bridge_install_command_copied', ['method', 'os', 'surface']),
  ('bridge_install_command_shared', ['method', 'os', 'surface']),
  ('bridge_run_command_copied', ['surface']),
  ('bridge_run_command_shared', ['surface']),
  ('product_screen_viewed', ['screen']);

ASSERT (SELECT COUNT(*) FROM expected_account_events) = 21
  AS 'The current closed ProductAnalyticsEvent catalog must contain 21 wire events';
ASSERT (
  SELECT COUNT(*) = COUNT(DISTINCT event_name)
  FROM expected_account_events
) AS 'Account event wire names must be unique';
ASSERT (
  SELECT TO_JSON_STRING(parameter_names) = TO_JSON_STRING(['input_mode', 'submission_kind', 'workspace_kind'])
  FROM expected_account_events
  WHERE event_name = 'session_created_with_message'
) AS 'Remote session creation has an exact three-parameter contract';
ASSERT (
  SELECT TO_JSON_STRING(parameter_names) = TO_JSON_STRING(['screen'])
  FROM expected_account_events
  WHERE event_name = 'product_screen_viewed'
) AS 'Canonical screen reporting may carry only the pinned screen enum';

CREATE TEMP TABLE expected_installation_events (event_name STRING, parameter_names ARRAY<STRING>);
INSERT INTO expected_installation_events VALUES
  ('login_attempt_started', ['provider']),
  ('login_attempt_completed', ['provider']),
  ('login_attempt_failed', ['failure_kind', 'provider']);

ASSERT (SELECT COUNT(*) FROM expected_installation_events) = 3
  AS 'The account-less login catalog must remain exactly three events';

CREATE TEMP TABLE event_fixture (
  user_key STRING,
  event_name STRING,
  occurred_at TIMESTAMP,
  emitted_at TIMESTAMP,
  activation_schema_version INT64,
  activity_state STRING,
  input_mode STRING,
  screen STRING
);

INSERT INTO event_fixture VALUES
  (REPEAT('a', 64), 'analytics_schema_ready', TIMESTAMP_ADD(account_created_at, INTERVAL 1 MINUTE), TIMESTAMP_ADD(account_created_at, INTERVAL 1 MINUTE), NULL, NULL, NULL, NULL),
  (REPEAT('a', 64), 'analytics_activation_ready', TIMESTAMP_ADD(account_created_at, INTERVAL 2 MINUTE), TIMESTAMP_ADD(account_created_at, INTERVAL 2 MINUTE), 1, NULL, NULL, NULL),
  (REPEAT('a', 64), 'session_creation_failed', TIMESTAMP_ADD(account_created_at, INTERVAL 30 MINUTE), TIMESTAMP_ADD(account_created_at, INTERVAL 30 MINUTE), NULL, NULL, NULL, NULL),
  -- Occurrence is intentionally deferred: emission must not move activation.
  (REPEAT('a', 64), 'session_message_sent', activation_at, TIMESTAMP_ADD(activation_at, INTERVAL 8 HOUR), NULL, NULL, 'typed', NULL),
  (REPEAT('a', 64), 'session_activity_viewed', TIMESTAMP_ADD(activation_at, INTERVAL 7 DAY), TIMESTAMP_ADD(activation_at, INTERVAL 7 DAY), NULL, 'non_empty', NULL, NULL),
  (REPEAT('a', 64), 'session_activity_viewed', TIMESTAMP_ADD(activation_at, INTERVAL 14 DAY), TIMESTAMP_ADD(activation_at, INTERVAL 14 DAY), NULL, 'non_empty', NULL, NULL),
  (REPEAT('a', 64), 'session_activity_viewed', TIMESTAMP_ADD(activation_at, INTERVAL 28 DAY), TIMESTAMP_ADD(activation_at, INTERVAL 28 DAY), NULL, 'non_empty', NULL, NULL),
  (REPEAT('a', 64), 'session_activity_viewed', TIMESTAMP_ADD(activation_at, INTERVAL 35 DAY), TIMESTAMP_ADD(activation_at, INTERVAL 35 DAY), NULL, 'non_empty', NULL, NULL),
  (REPEAT('b', 64), 'analytics_schema_ready', TIMESTAMP_ADD(account_created_at, INTERVAL 1 MINUTE), TIMESTAMP_ADD(account_created_at, INTERVAL 1 MINUTE), NULL, NULL, NULL, NULL),
  (REPEAT('c', 64), 'analytics_activation_ready', TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR), TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR), 1, NULL, NULL, NULL),
  (REPEAT('d', 64), 'analytics_activation_ready', TIMESTAMP_ADD(TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR), INTERVAL 1 MICROSECOND), TIMESTAMP_ADD(TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR), INTERVAL 1 MICROSECOND), 1, NULL, NULL, NULL),
  (REPEAT('e', 64), 'product_screen_viewed', TIMESTAMP_ADD(account_created_at, INTERVAL 5 MINUTE), TIMESTAMP_ADD(account_created_at, INTERVAL 5 MINUTE), NULL, NULL, NULL, 'projects'),
  (REPEAT('e', 64), 'screen_view', TIMESTAMP_ADD(account_created_at, INTERVAL 6 MINUTE), TIMESTAMP_ADD(account_created_at, INTERVAL 6 MINUTE), NULL, NULL, NULL, 'projects');

ASSERT (
  SELECT MIN(IF(event_name IN ('session_message_sent', 'session_created_with_message'), occurred_at, NULL))
  FROM event_fixture
  WHERE user_key = REPEAT('a', 64)
) = activation_at AS 'Full activation must use the first successful message occurrence';

ASSERT (
  SELECT MIN(IF(event_name IN ('session_message_sent', 'session_created_with_message'), emitted_at, NULL))
  FROM event_fixture
  WHERE user_key = REPEAT('a', 64)
) != activation_at AS 'Deferred emission time must remain distinct from occurrence time';

ASSERT (
  SELECT COUNTIF(event_name = 'session_creation_failed')
  FROM event_fixture
  WHERE user_key = REPEAT('a', 64)
) = 1 AND (
  SELECT COUNTIF(event_name IN ('session_message_sent', 'session_created_with_message'))
  FROM event_fixture
  WHERE user_key = REPEAT('a', 64)
) = 1 AS 'Failed creation is friction, never activation';

ASSERT NOT EXISTS (
  SELECT 1
  FROM event_fixture
  WHERE user_key = REPEAT('b', 64)
    AND (
      (event_name = 'analytics_activation_ready' AND activation_schema_version = 1)
      OR event_name IN ('session_message_sent', 'session_created_with_message')
    )
) AS 'Foundation-only exposure must not create activation eligibility';

ASSERT (
  SELECT COUNTIF(
    event_name = 'analytics_activation_ready'
    AND activation_schema_version = 1
    AND occurred_at <= TIMESTAMP_ADD(account_created_at, INTERVAL 24 HOUR)
  )
  FROM event_fixture
  WHERE user_key IN (REPEAT('c', 64), REPEAT('d', 64))
) = 1 AS 'Activation-capable exposure includes 24h exactly and excludes 24h plus one microsecond';

CREATE TEMP TABLE timing_fixture (
  case_name STRING,
  account_created_at TIMESTAMP,
  occurred_at TIMESTAMP,
  emitted_at TIMESTAMP
);
INSERT INTO timing_fixture VALUES
  ('future_at_allowance', account_created_at, TIMESTAMP_ADD(account_created_at, INTERVAL 300 SECOND), account_created_at),
  ('future_over_allowance', account_created_at, TIMESTAMP_ADD(TIMESTAMP_ADD(account_created_at, INTERVAL 300 SECOND), INTERVAL 1 MICROSECOND), account_created_at),
  ('account_at_allowance', account_created_at, TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND), account_created_at),
  ('account_over_allowance', account_created_at, TIMESTAMP_SUB(TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND), INTERVAL 1 MICROSECOND), account_created_at);

ASSERT (
  SELECT COUNTIF(occurred_at <= TIMESTAMP_ADD(emitted_at, INTERVAL 300 SECOND))
  FROM timing_fixture
  WHERE STARTS_WITH(case_name, 'future_')
) = 1 AS 'Future occurrence accepts exactly five minutes and rejects one microsecond more';
ASSERT (
  SELECT COUNTIF(occurred_at >= TIMESTAMP_SUB(account_created_at, INTERVAL 300 SECOND))
  FROM timing_fixture
  WHERE STARTS_WITH(case_name, 'account_')
) = 1 AS 'Pre-account occurrence accepts exactly five minutes and rejects one microsecond more';

ASSERT account_created_at <= TIMESTAMP_SUB(TIMESTAMP_ADD(account_created_at, INTERVAL 7 DAY), INTERVAL 7 DAY)
  AS 'A seven-day activation cohort matures at exactly 7x24 hours';
ASSERT NOT (account_created_at <= TIMESTAMP_SUB(
  TIMESTAMP_SUB(TIMESTAMP_ADD(account_created_at, INTERVAL 7 DAY), INTERVAL 1 MICROSECOND),
  INTERVAL 7 DAY
)) AS 'A seven-day activation cohort is immature one microsecond before its boundary';

CREATE TEMP TABLE ordered_funnel_fixture (
  case_name STRING,
  account_at TIMESTAMP,
  bridge_at TIMESTAMP,
  project_at TIMESTAMP,
  message_at TIMESTAMP
);
INSERT INTO ordered_funnel_fixture VALUES
  ('ordered', account_created_at, TIMESTAMP_ADD(account_created_at, INTERVAL 1 HOUR), TIMESTAMP_ADD(account_created_at, INTERVAL 2 HOUR), TIMESTAMP_ADD(account_created_at, INTERVAL 3 HOUR)),
  ('project_before_bridge', account_created_at, TIMESTAMP_ADD(account_created_at, INTERVAL 2 HOUR), TIMESTAMP_ADD(account_created_at, INTERVAL 1 HOUR), TIMESTAMP_ADD(account_created_at, INTERVAL 3 HOUR)),
  ('message_before_project', account_created_at, TIMESTAMP_ADD(account_created_at, INTERVAL 1 HOUR), TIMESTAMP_ADD(account_created_at, INTERVAL 3 HOUR), TIMESTAMP_ADD(account_created_at, INTERVAL 2 HOUR));

ASSERT (
  SELECT COUNTIF(
    bridge_at >= TIMESTAMP_SUB(account_at, INTERVAL 300 SECOND)
    AND project_at >= TIMESTAMP_SUB(bridge_at, INTERVAL 300 SECOND)
    AND message_at >= TIMESTAMP_SUB(project_at, INTERVAL 300 SECOND)
  )
  FROM ordered_funnel_fixture
) = 1 AS 'Activation progression must remain account to bridge to project to message';

CREATE TEMP TABLE retention_maturity_fixture (
  activation_week DATE,
  w1_eligible BOOL,
  w1_retained BOOL,
  w4_eligible BOOL,
  w4_retained BOOL
);
INSERT INTO retention_maturity_fixture VALUES
  (DATE '2026-07-06', TRUE, TRUE, TRUE, FALSE),
  (DATE '2026-07-06', TRUE, FALSE, TRUE, TRUE),
  (DATE '2026-07-13', TRUE, TRUE, FALSE, FALSE),
  (DATE '2026-07-13', FALSE, FALSE, FALSE, FALSE);

CREATE TEMP TABLE retention_maturity_result AS
SELECT
  activation_week,
  COUNTIF(w1_eligible) = COUNT(*) AS w1_cohort_mature,
  COUNTIF(w1_eligible) AS w1_eligible_users,
  COUNTIF(w1_eligible AND w1_retained) AS w1_retained_users,
  COUNTIF(w4_eligible) = COUNT(*) AS w4_cohort_mature,
  COUNTIF(w4_eligible) AS w4_eligible_users,
  COUNTIF(w4_eligible AND w4_retained) AS w4_retained_users
FROM retention_maturity_fixture
GROUP BY activation_week;

ASSERT (
  SELECT w1_cohort_mature AND w4_cohort_mature
  FROM retention_maturity_result
  WHERE activation_week = DATE '2026-07-06'
) AS 'Retention cohort maturity requires every activated user window to elapse';
ASSERT (
  SELECT
    NOT w1_cohort_mature
    AND NOT w4_cohort_mature
    AND IF(w1_cohort_mature, w1_eligible_users, NULL) IS NULL
    AND IF(w1_cohort_mature, w1_retained_users, NULL) IS NULL
    AND IF(w4_cohort_mature, w4_eligible_users, NULL) IS NULL
    AND IF(w4_cohort_mature, w4_retained_users, NULL) IS NULL
  FROM retention_maturity_result
  WHERE activation_week = DATE '2026-07-13'
) AS 'A partially mature activation week exposes null retention counts';

ASSERT (
  SELECT COUNTIF(
    event_name = 'session_activity_viewed'
    AND activity_state = 'non_empty'
    AND occurred_at >= TIMESTAMP_ADD(activation_at, INTERVAL 7 DAY)
    AND occurred_at < TIMESTAMP_ADD(activation_at, INTERVAL 14 DAY)
  )
  FROM event_fixture
  WHERE user_key = REPEAT('a', 64)
) = 1 AS 'W1 is the half-open [7d,14d) activation window';

ASSERT (
  SELECT COUNTIF(
    event_name = 'session_activity_viewed'
    AND activity_state = 'non_empty'
    AND occurred_at >= TIMESTAMP_ADD(activation_at, INTERVAL 28 DAY)
    AND occurred_at < TIMESTAMP_ADD(activation_at, INTERVAL 35 DAY)
  )
  FROM event_fixture
  WHERE user_key = REPEAT('a', 64)
) = 1 AS 'W4 is the half-open [28d,35d) activation window';

CREATE TEMP TABLE activity_classification_fixture (event_name STRING, state STRING, meaningful BOOL, controller BOOL);
INSERT INTO activity_classification_fixture VALUES
  ('session_activity_viewed', 'empty', FALSE, FALSE),
  ('session_activity_viewed', 'non_empty', TRUE, FALSE),
  ('session_message_sent', NULL, TRUE, TRUE),
  ('session_created_with_message', NULL, TRUE, TRUE),
  ('session_question_answered', NULL, TRUE, TRUE),
  ('session_question_rejected', NULL, TRUE, TRUE),
  ('session_permission_answered', NULL, TRUE, TRUE),
  ('session_abort_succeeded', NULL, TRUE, TRUE),
  ('voice_transcription_completed', NULL, FALSE, FALSE),
  ('session_diff_viewed', 'non_empty', FALSE, FALSE),
  ('product_screen_viewed', NULL, FALSE, FALSE);

ASSERT (
  SELECT COUNTIF(meaningful) FROM activity_classification_fixture
) = 7 AS 'Meaningful activity is non-empty monitoring or a confirmed control outcome';
ASSERT (
  SELECT COUNTIF(controller) FROM activity_classification_fixture
) = 6 AS 'Controller activity is exactly the six successful control event names';
ASSERT NOT EXISTS (
  SELECT 1 FROM activity_classification_fixture
  WHERE event_name IN ('product_screen_viewed', 'voice_transcription_completed', 'session_diff_viewed')
    AND meaningful
) AS 'Screens, transcription, and diffs never inflate meaningful WAU';

CREATE TEMP TABLE voice_fixture (submission_kind STRING, input_mode STRING, accepted BOOL);
INSERT INTO voice_fixture VALUES
  ('text', 'typed', TRUE),
  ('text', 'voice_assisted', TRUE),
  ('command', 'typed', TRUE),
  ('command', 'voice_assisted', FALSE);
ASSERT (SELECT COUNTIF(accepted AND input_mode = 'voice_assisted') FROM voice_fixture) = 1
  AS 'Only accepted text submissions can be voice-assisted';

CREATE TEMP TABLE privacy_gate_fixture (
  user_key STRING,
  current_auth_eligible BOOL,
  internal_excluded BOOL,
  deletion_excluded BOOL,
  event_count INT64
);
INSERT INTO privacy_gate_fixture VALUES
  (REPEAT('1', 64), TRUE, FALSE, FALSE, 2),
  (REPEAT('2', 64), FALSE, FALSE, FALSE, 3),
  (REPEAT('3', 64), TRUE, TRUE, FALSE, 5),
  (REPEAT('4', 64), TRUE, FALSE, TRUE, 7);

ASSERT (
  SELECT SUM(event_count)
  FROM privacy_gate_fixture
  WHERE current_auth_eligible AND NOT internal_excluded AND NOT deletion_excluded
) = 2 AS 'Current eligibility and both permanent exclusions apply before aggregation';

CREATE TEMP TABLE login_fixture (
  event_date DATE,
  platform STRING,
  app_version STRING,
  provider STRING,
  failure_kind STRING,
  event_name STRING
);
INSERT INTO login_fixture VALUES
  (DATE '2026-07-20', 'IOS', '1.0.0', 'github', NULL, 'login_attempt_started'),
  (DATE '2026-07-20', 'IOS', '1.0.0', 'github', NULL, 'login_attempt_completed'),
  (DATE '2026-07-20', 'IOS', '1.0.0', 'github', 'timeout', 'login_attempt_failed');
ASSERT (
  SELECT SAFE_DIVIDE(COUNTIF(event_name = 'login_attempt_completed'), COUNTIF(event_name = 'login_attempt_started'))
  FROM login_fixture
) = 1 AS 'Account-less login completion is a direct event-count rate';
ASSERT NOT REGEXP_CONTAINS(TO_JSON_STRING(ARRAY(SELECT AS STRUCT * FROM login_fixture)), r'(?i)user_pseudo|user_key|user_id|installation')
  AS 'Login aggregation fixtures contain no account or installation identifier';

ASSERT (
  SELECT COUNTIF(event_name = 'product_screen_viewed')
  FROM event_fixture
  WHERE user_key = REPEAT('e', 64)
) = 1 AND (
  SELECT COUNTIF(event_name = 'screen_view')
  FROM event_fixture
  WHERE user_key = REPEAT('e', 64)
) = 1 AS 'Canonical custom screens remain distinct from the native screen_view mirror';

ASSERT TIMESTAMP_SUB(fixture_now, INTERVAL 36 HOUR) >= TIMESTAMP_SUB(fixture_now, INTERVAL 36 HOUR)
  AS 'An auth snapshot exactly 36 hours old is fresh';
ASSERT NOT (
  TIMESTAMP_SUB(TIMESTAMP_SUB(fixture_now, INTERVAL 36 HOUR), INTERVAL 1 MICROSECOND)
    >= TIMESTAMP_SUB(fixture_now, INTERVAL 36 HOUR)
) AS 'An auth snapshot older than 36 hours by one microsecond is stale';

CREATE TEMP TABLE week_fixture (activity_date DATE);
INSERT INTO week_fixture VALUES
  (DATE '2026-07-20'),
  (DATE '2026-07-26'),
  (DATE '2026-07-27');
ASSERT (
  SELECT COUNTIF(
    DATE_TRUNC(activity_date, WEEK(MONDAY)) = DATE '2026-07-20'
    AND DATE_ADD(DATE_TRUNC(activity_date, WEEK(MONDAY)), INTERVAL 6 DAY) = DATE '2026-07-26'
  )
  FROM week_fixture
) = 2 AS 'Weeks are complete Monday-Sunday UTC periods';

CREATE TEMP TABLE replacement_fixture (source_date DATE, event_name STRING, event_count INT64);
INSERT INTO replacement_fixture VALUES (DATE '2026-07-24', 'session_message_sent', 1);
DELETE FROM replacement_fixture WHERE source_date BETWEEN DATE '2026-07-22' AND DATE '2026-07-24';
INSERT INTO replacement_fixture VALUES (DATE '2026-07-24', 'session_message_sent', 2);
ASSERT (
  SELECT COUNT(*) = 1 AND SUM(event_count) = 2 FROM replacement_fixture
) AS 'Late-arrival recomputation replaces rather than appends mutable source dates';

ASSERT LEAST(
  DATE_SUB(DATE(fixture_now), INTERVAL 1 DAY),
  DATE_SUB(DATE '2026-07-26', INTERVAL 1 DAY)
) = DATE '2026-07-25'
  AS 'Complete UTC coverage ends no later than one day before the latest property-local suffix';

CREATE TEMP TABLE timezone_scan_fixture (
  case_name STRING,
  suffix_date DATE,
  emitted_at TIMESTAMP
);
INSERT INTO timezone_scan_fixture VALUES
  ('previous_suffix', DATE '2026-07-19', TIMESTAMP '2026-07-20 00:15:00+00'),
  ('matching_suffix', DATE '2026-07-20', TIMESTAMP '2026-07-20 12:00:00+00'),
  ('next_suffix', DATE '2026-07-21', TIMESTAMP '2026-07-20 23:45:00+00'),
  ('suffix_too_early', DATE '2026-07-18', TIMESTAMP '2026-07-20 00:30:00+00'),
  ('utc_date_outside_range', DATE '2026-07-20', TIMESTAMP '2026-07-19 23:45:00+00');

CREATE TEMP TABLE timezone_scan_result AS
SELECT
  case_name,
  DATE(emitted_at) AS source_export_date
FROM timezone_scan_fixture
WHERE suffix_date BETWEEN DATE_SUB(DATE '2026-07-20', INTERVAL 1 DAY)
    AND DATE_ADD(DATE '2026-07-20', INTERVAL 1 DAY)
  AND DATE(emitted_at) BETWEEN DATE '2026-07-20' AND DATE '2026-07-20';

ASSERT TO_JSON_STRING(ARRAY(
  SELECT case_name FROM timezone_scan_result ORDER BY case_name
)) = TO_JSON_STRING(['matching_suffix', 'next_suffix', 'previous_suffix'])
  AS 'One-day suffix bounds retain both timezone edges and the UTC date filter removes adjacent UTC dates';
ASSERT NOT EXISTS (
  SELECT 1 FROM timezone_scan_result WHERE source_export_date != DATE '2026-07-20'
) AS 'source_export_date is always derived from the UTC emission timestamp';

CREATE TEMP TABLE raw_duplicate_fixture (
  event_scope STRING,
  user_pseudo_id STRING,
  user_key STRING,
  event_name STRING,
  event_timestamp INT64,
  event_bundle_sequence_id INT64,
  batch_event_index INT64,
  bounded_payload STRING
);
INSERT INTO raw_duplicate_fixture VALUES
  ('account', 'account-installation-a', REPEAT('a', 64), 'session_message_sent', 100, 7, 0, 'typed'),
  ('account', 'account-installation-a', REPEAT('a', 64), 'session_message_sent', 100, 7, 0, 'typed'),
  ('account', 'account-installation-a', REPEAT('b', 64), 'session_message_sent', 100, 7, 0, 'typed'),
  ('account', 'account-installation-b', REPEAT('a', 64), 'session_message_sent', 100, 7, 0, 'typed'),
  ('login', 'login-installation-a', NULL, 'login_attempt_started', 200, 8, 0, 'github'),
  ('login', 'login-installation-a', NULL, 'login_attempt_started', 200, 8, 0, 'github');

CREATE TEMP TABLE deduplicated_fixture AS
SELECT * EXCEPT (user_pseudo_id, user_key, duplicate_rank)
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY
        user_pseudo_id,
        user_key,
        event_name,
        event_timestamp,
        event_bundle_sequence_id,
        batch_event_index,
        bounded_payload
      ORDER BY event_timestamp
    ) AS duplicate_rank
  FROM raw_duplicate_fixture
)
WHERE duplicate_rank = 1;

ASSERT (SELECT COUNT(*) FROM raw_duplicate_fixture WHERE event_scope = 'account') = 4
  AND (SELECT COUNT(*) FROM deduplicated_fixture WHERE event_scope = 'account') = 3
  AS 'Account duplicate identity includes transient installation identity, user key, bounded payload, bundle, batch, and timestamp';
ASSERT (SELECT COUNT(*) FROM raw_duplicate_fixture WHERE event_scope = 'login') = 2
  AND (SELECT COUNT(*) FROM deduplicated_fixture WHERE event_scope = 'login') = 1
  AS 'Login counts remove equivalent transient Firebase export duplicates';
ASSERT NOT REGEXP_CONTAINS(
  TO_JSON_STRING(ARRAY(SELECT AS STRUCT * FROM deduplicated_fixture)),
  r'(?i)user_pseudo_id|installation-a|installation-b'
) AS 'Transient duplicate identity never survives into deduplicated output';

CREATE TEMP TABLE parameter_contract_fixture (
  case_name STRING,
  required_parameter_names ARRAY<STRING>
);
INSERT INTO parameter_contract_fixture VALUES
  ('valid', ['user_key', 'schema_version', 'occurred_at_micros', 'submission_kind', 'input_mode']),
  ('duplicate_required', ['user_key', 'schema_version', 'occurred_at_micros', 'submission_kind', 'input_mode']),
  ('wrong_typed_slot', ['user_key', 'schema_version', 'occurred_at_micros', 'submission_kind', 'input_mode']),
  ('unknown_enum', ['user_key', 'schema_version', 'occurred_at_micros', 'submission_kind', 'input_mode']);

CREATE TEMP TABLE parameter_value_fixture (
  case_name STRING,
  parameter_name STRING,
  string_value STRING,
  int_value INT64,
  float_value FLOAT64,
  double_value FLOAT64
);
INSERT INTO parameter_value_fixture VALUES
  ('valid', 'user_key', REPEAT('a', 64), NULL, NULL, NULL),
  ('valid', 'schema_version', NULL, 1, NULL, NULL),
  ('valid', 'occurred_at_micros', NULL, 100, NULL, NULL),
  ('valid', 'submission_kind', 'text', NULL, NULL, NULL),
  ('valid', 'input_mode', 'typed', NULL, NULL, NULL),
  ('duplicate_required', 'user_key', REPEAT('a', 64), NULL, NULL, NULL),
  ('duplicate_required', 'schema_version', NULL, 1, NULL, NULL),
  ('duplicate_required', 'occurred_at_micros', NULL, 100, NULL, NULL),
  ('duplicate_required', 'submission_kind', 'text', NULL, NULL, NULL),
  ('duplicate_required', 'input_mode', 'typed', NULL, NULL, NULL),
  ('duplicate_required', 'input_mode', 'typed', NULL, NULL, NULL),
  ('wrong_typed_slot', 'user_key', REPEAT('a', 64), NULL, NULL, NULL),
  ('wrong_typed_slot', 'schema_version', '1', NULL, NULL, NULL),
  ('wrong_typed_slot', 'occurred_at_micros', NULL, 100, NULL, NULL),
  ('wrong_typed_slot', 'submission_kind', 'text', NULL, NULL, NULL),
  ('wrong_typed_slot', 'input_mode', 'typed', NULL, NULL, NULL),
  ('unknown_enum', 'user_key', REPEAT('a', 64), NULL, NULL, NULL),
  ('unknown_enum', 'schema_version', NULL, 1, NULL, NULL),
  ('unknown_enum', 'occurred_at_micros', NULL, 100, NULL, NULL),
  ('unknown_enum', 'submission_kind', 'text', NULL, NULL, NULL),
  ('unknown_enum', 'input_mode', 'unbounded', NULL, NULL, NULL);

CREATE TEMP TABLE parameter_validation_fixture AS
SELECT
  contract.case_name,
  (
    SELECT
      COUNT(*) = ARRAY_LENGTH(contract.required_parameter_names)
      AND COUNT(DISTINCT parameter.parameter_name) = ARRAY_LENGTH(contract.required_parameter_names)
      AND COUNTIF(
        (
          parameter.parameter_name IN ('schema_version', 'occurred_at_micros')
          AND parameter.int_value IS NOT NULL
          AND parameter.string_value IS NULL
          AND parameter.float_value IS NULL
          AND parameter.double_value IS NULL
        )
        OR (
          parameter.parameter_name NOT IN ('schema_version', 'occurred_at_micros')
          AND parameter.string_value IS NOT NULL
          AND parameter.int_value IS NULL
          AND parameter.float_value IS NULL
          AND parameter.double_value IS NULL
        )
      ) = ARRAY_LENGTH(contract.required_parameter_names)
    FROM parameter_value_fixture AS parameter
    WHERE parameter.case_name = contract.case_name
      AND parameter.parameter_name IN UNNEST(contract.required_parameter_names)
  ) AS parameter_shape_valid,
  (
    SELECT MAX(IF(parameter_name = 'input_mode', string_value, NULL)) IN ('typed', 'voice_assisted')
    FROM parameter_value_fixture AS parameter
    WHERE parameter.case_name = contract.case_name
  ) AS bounded_enum_valid
FROM parameter_contract_fixture AS contract;

ASSERT (SELECT parameter_shape_valid FROM parameter_validation_fixture WHERE case_name = 'valid')
  AS 'Exactly one correctly typed value for every required parameter is accepted';
ASSERT NOT (SELECT parameter_shape_valid FROM parameter_validation_fixture WHERE case_name = 'duplicate_required')
  AS 'A duplicate required parameter is rejected even when both values agree';
ASSERT NOT (SELECT parameter_shape_valid FROM parameter_validation_fixture WHERE case_name = 'wrong_typed_slot')
  AS 'Integer shared parameters are rejected when supplied through a string slot';
ASSERT (
  SELECT parameter_shape_valid AND NOT bounded_enum_valid
  FROM parameter_validation_fixture
  WHERE case_name = 'unknown_enum'
) AS 'Unknown bounded values remain distinct from invalid parameter shape rows';

CREATE TEMP TABLE login_nullability_fixture (
  case_name STRING,
  event_name STRING,
  failure_kind STRING,
  expected_valid BOOL
);
INSERT INTO login_nullability_fixture VALUES
  ('failed_with_kind', 'login_attempt_failed', 'timeout', TRUE),
  ('failed_without_kind', 'login_attempt_failed', NULL, FALSE),
  ('started_without_kind', 'login_attempt_started', NULL, TRUE),
  ('started_with_kind', 'login_attempt_started', 'timeout', FALSE);

ASSERT NOT EXISTS (
  SELECT 1
  FROM login_nullability_fixture
  WHERE expected_valid != COALESCE(
    (event_name = 'login_attempt_failed' AND failure_kind IN ('authentication', 'launch', 'cancelled', 'timeout', 'unknown'))
      OR (event_name IN ('login_attempt_started', 'login_attempt_completed') AND failure_kind IS NULL),
    FALSE
  )
) AS 'Login failures require one bounded failure kind and non-failures require none';

CREATE TEMP TABLE snapshot_period_fixture (
  week_start DATE,
  account_period_available BOOL,
  complete_engagement_available BOOL,
  mature_7_day_activation_available BOOL
);
INSERT INTO snapshot_period_fixture VALUES
  (DATE '2026-07-06', TRUE, TRUE, TRUE),
  (DATE '2026-07-13', TRUE, TRUE, FALSE),
  (DATE '2026-07-20', TRUE, FALSE, FALSE);

ASSERT (SELECT MAX(IF(account_period_available, week_start, NULL)) FROM snapshot_period_fixture) = DATE '2026-07-20'
  AND (SELECT MAX(IF(complete_engagement_available, week_start, NULL)) FROM snapshot_period_fixture) = DATE '2026-07-13'
  AND (SELECT MAX(IF(mature_7_day_activation_available, week_start, NULL)) FROM snapshot_period_fixture) = DATE '2026-07-06'
  AS 'Investor snapshot periods are selected independently by account, engagement, and 7-day maturity';

ASSERT (
  SELECT COUNT(*)
  FROM (SELECT 1 AS singleton) AS base
  LEFT JOIN (
    SELECT 1 AS recency_rank
    FROM snapshot_period_fixture
    WHERE mature_7_day_activation_available AND FALSE
  ) AS no_mature_activation
    ON no_mature_activation.recency_rank = base.singleton
) = 1 AS 'Investor snapshot keeps one null-capable row before any activation cohort matures';

CREATE TEMP TABLE zero_account_week_fixture (
  week_start DATE,
  week_end DATE,
  new_accounts INT64
);
INSERT INTO zero_account_week_fixture VALUES
  (DATE '2026-07-06', DATE '2026-07-12', 4),
  (DATE '2026-07-13', DATE '2026-07-19', 0);

CREATE TEMP TABLE zero_account_week_compared AS
SELECT
  *,
  LAG(new_accounts) OVER (ORDER BY week_start) AS prior_week_new_accounts,
  ROW_NUMBER() OVER (ORDER BY week_start DESC) AS recency_rank
FROM zero_account_week_fixture;

ASSERT (
  SELECT
    week_start = DATE '2026-07-13'
    AND new_accounts = 0
    AND prior_week_new_accounts = 4
  FROM zero_account_week_compared
  WHERE recency_rank = 1
) AS 'Investor account periods retain and compare a complete zero-signup week';

CREATE TEMP TABLE publication_gate_fixture (
  case_name STRING,
  auth_published_at TIMESTAMP,
  staged_control_updated_at TIMESTAMP,
  current_control_updated_at TIMESTAMP,
  staged_value INT64
);
INSERT INTO publication_gate_fixture VALUES
  (
    'stale_auth',
    TIMESTAMP_SUB(TIMESTAMP_SUB(fixture_now, INTERVAL 36 HOUR), INTERVAL 1 MICROSECOND),
    TIMESTAMP '2026-07-26 00:00:00+00',
    TIMESTAMP '2026-07-26 00:00:00+00',
    9
  ),
  (
    'control_mismatch',
    fixture_now,
    TIMESTAMP '2026-07-25 00:00:00+00',
    TIMESTAMP '2026-07-26 00:00:00+00',
    9
  ),
  (
    'current',
    fixture_now,
    TIMESTAMP '2026-07-26 00:00:00+00',
    TIMESTAMP '2026-07-26 00:00:00+00',
    9
  );

CREATE TEMP TABLE publication_target_fixture (case_name STRING, published_value INT64);
INSERT INTO publication_target_fixture VALUES
  ('stale_auth', 7),
  ('control_mismatch', 7),
  ('current', 7);

UPDATE publication_target_fixture AS target
SET published_value = gate.staged_value
FROM publication_gate_fixture AS gate
WHERE target.case_name = gate.case_name
  AND gate.auth_published_at BETWEEN TIMESTAMP_SUB(fixture_now, INTERVAL 36 HOUR)
    AND TIMESTAMP_ADD(fixture_now, INTERVAL 300 SECOND)
  AND gate.staged_control_updated_at = gate.current_control_updated_at;

ASSERT (
  SELECT COUNTIF(published_value = 7) = 2 AND COUNTIF(case_name = 'current' AND published_value = 9) = 1
  FROM publication_target_fixture
) AS 'Stale auth or a changed control sentinel leaves the previously published target unmodified';
