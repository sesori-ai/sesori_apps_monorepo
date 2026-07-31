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
