-- =============================================================================
-- Sesori Analytics — BigQuery Views
-- =============================================================================
--
-- Prerequisites:
--   1. Firebase Console → Project Settings → Integrations → BigQuery → Link
--   2. Enable daily export (free tier: 10GB storage, 1TB queries/month)
--   3. Note the dataset ID (format: analytics_<project_number>)
--   4. Replace `<project>` and `<dataset>` below with your values
--
-- After creating views, register custom dimensions in GA4 console:
--   Admin → Custom Definitions → Add:
--     - provider (event-scoped)
--     - source (event-scoped)
--     - screen (event-scoped)
--     - reply (event-scoped)
--     - pluginId (event-scoped)
--     - surface (event-scoped)
--     - method (event-scoped)
--     - os (event-scoped)
--     - channel (event-scoped)
-- =============================================================================


-- =============================================================================
-- 1. Daily Active Users (DAU) + New Users
-- =============================================================================
CREATE OR REPLACE VIEW `<project>.<dataset>.v_dau` AS
SELECT
  event_date,
  COUNT(DISTINCT user_pseudo_id) AS dau,
  COUNT(DISTINCT IF(event_name = 'first_open', user_pseudo_id, NULL)) AS new_users
FROM `<project>.<dataset>.events_*`
WHERE event_name IN ('session_start', 'first_open')
  AND _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
GROUP BY event_date
ORDER BY event_date;


-- =============================================================================
-- 2. Weekly Active Users (WAU) + Stickiness (DAU/WAU ratio)
-- =============================================================================
CREATE OR REPLACE VIEW `<project>.<dataset>.v_wau_stickiness` AS
WITH daily AS (
  SELECT
    event_date,
    COUNT(DISTINCT user_pseudo_id) AS dau
  FROM `<project>.<dataset>.events_*`
  WHERE event_name = 'session_start'
  GROUP BY event_date
),
weekly AS (
  SELECT
    event_date,
    COUNT(DISTINCT user_pseudo_id) AS wau
  FROM `<project>.<dataset>.events_*`
  WHERE event_name = 'session_start'
    AND event_date >= FORMAT_DATE('%Y%m%d', DATE_SUB(PARSE_DATE('%Y%m%d', event_date), INTERVAL 6 DAY))
  GROUP BY event_date
)
SELECT
  d.event_date,
  d.dau,
  w.wau,
  SAFE_DIVIDE(d.dau, w.wau) AS stickiness_ratio
FROM daily d
JOIN weekly w ON d.event_date = w.event_date
ORDER BY d.event_date;


-- =============================================================================
-- 3. Activation Funnel
-- =============================================================================
CREATE OR REPLACE VIEW `<project>.<dataset>.v_activation_funnel` AS
WITH funnel_events AS (
  SELECT
    user_pseudo_id,
    event_name,
    event_timestamp,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'provider') AS provider
  FROM `<project>.<dataset>.events_*`
  WHERE event_name IN (
    'first_open',
    'login_started',
    'login_completed',
    'bridge_connected',
    'project_discovered',
    'session_created',
    'first_assistant_message'
  )
)
SELECT
  event_name AS funnel_step,
  COUNT(DISTINCT user_pseudo_id) AS users_reached,
  ROUND(COUNT(DISTINCT user_pseudo_id) * 100.0 /
    FIRST_VALUE(COUNT(DISTINCT user_pseudo_id)) OVER (ORDER BY COUNT(DISTINCT user_pseudo_id) DESC), 1) AS pct_of_top
FROM funnel_events
GROUP BY event_name
ORDER BY users_reached DESC;


-- =============================================================================
-- 4. Time to Activation (login → first AI reply, in hours)
-- =============================================================================
CREATE OR REPLACE VIEW `<project>.<dataset>.v_time_to_activation` AS
SELECT
  user_pseudo_id,
  MIN(IF(event_name = 'login_completed', event_timestamp, NULL)) AS login_ts,
  MIN(IF(event_name = 'first_assistant_message', event_timestamp, NULL)) AS aha_ts,
  TIMESTAMP_DIFF(
    MIN(IF(event_name = 'first_assistant_message', event_timestamp, NULL)),
    MIN(IF(event_name = 'login_completed', event_timestamp, NULL)),
    MINUTE
  ) / 60.0 AS hours_to_activation
FROM `<project>.<dataset>.events_*`
WHERE event_name IN ('login_completed', 'first_assistant_message')
GROUP BY user_pseudo_id
HAVING aha_ts IS NOT NULL
ORDER BY hours_to_activation;


-- =============================================================================
-- 5. Weekly Cohort Retention
-- =============================================================================
CREATE OR REPLACE VIEW `<project>.<dataset>.v_weekly_retention` AS
WITH first_seen AS (
  SELECT
    user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date)) AS cohort_date
  FROM `<project>.<dataset>.events_*`
  WHERE event_name = 'first_open'
  GROUP BY user_pseudo_id
),
activity AS (
  SELECT DISTINCT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS active_date
  FROM `<project>.<dataset>.events_*`
  WHERE event_name = 'session_start'
)
SELECT
  DATE_TRUNC(f.cohort_date, WEEK) AS cohort_week,
  COUNT(DISTINCT f.user_pseudo_id) AS cohort_size,
  COUNT(DISTINCT IF(DATE_DIFF(a.active_date, f.cohort_date, DAY) BETWEEN 0 AND 6, f.user_pseudo_id, NULL)) AS week_0,
  COUNT(DISTINCT IF(DATE_DIFF(a.active_date, f.cohort_date, DAY) BETWEEN 7 AND 13, f.user_pseudo_id, NULL)) AS week_1,
  COUNT(DISTINCT IF(DATE_DIFF(a.active_date, f.cohort_date, DAY) BETWEEN 14 AND 27, f.user_pseudo_id, NULL)) AS week_2,
  COUNT(DISTINCT IF(DATE_DIFF(a.active_date, f.cohort_date, DAY) BETWEEN 28 AND 55, f.user_pseudo_id, NULL)) AS week_4
FROM first_seen f
LEFT JOIN activity a ON f.user_pseudo_id = a.user_pseudo_id
GROUP BY cohort_week
ORDER BY cohort_week;


-- =============================================================================
-- 6. Voice Adoption (weekly voice vs typed message volume)
-- =============================================================================
CREATE OR REPLACE VIEW `<project>.<dataset>.v_voice_adoption` AS
SELECT
  DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK) AS week,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS source,
  COUNT(*) AS message_count,
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM `<project>.<dataset>.events_*`
WHERE event_name = 'message_sent'
GROUP BY week, source
ORDER BY week, source;


-- =============================================================================
-- 7. Screen Popularity (top screens by views)
-- =============================================================================
CREATE OR REPLACE VIEW `<project>.<dataset>.v_screen_popularity` AS
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'screen') AS screen_name,
  COUNT(*) AS view_count,
  COUNT(DISTINCT user_pseudo_id) AS unique_viewers
FROM `<project>.<dataset>.events_*`
WHERE event_name = 'screen_view'
GROUP BY screen_name
ORDER BY view_count DESC;


-- =============================================================================
-- 8. Permission Reply Distribution (always vs once vs reject)
-- =============================================================================
CREATE OR REPLACE VIEW `<project>.<dataset>.v_permission_replies` AS
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'reply') AS reply_type,
  COUNT(*) AS count,
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM `<project>.<dataset>.events_*`
WHERE event_name = 'permission_replied'
GROUP BY reply_type
ORDER BY count DESC;


-- =============================================================================
-- 9. Login Provider Breakdown
-- =============================================================================
CREATE OR REPLACE VIEW `<project>.<dataset>.v_login_providers` AS
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'provider') AS provider,
  COUNT(IF(event_name = 'login_started', 1, NULL)) AS started,
  COUNT(IF(event_name = 'login_completed', 1, NULL)) AS completed,
  COUNT(IF(event_name = 'login_failed', 1, NULL)) AS failed,
  ROUND(SAFE_DIVIDE(
    COUNT(IF(event_name = 'login_completed', 1, NULL)),
    COUNT(IF(event_name = 'login_started', 1, NULL))
  ) * 100, 1) AS success_rate_pct
FROM `<project>.<dataset>.events_*`
WHERE event_name IN ('login_started', 'login_completed', 'login_failed')
GROUP BY provider
ORDER BY started DESC;
