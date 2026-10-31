# Desktop Product Analytics

Slug: `desktop-analytics`. The plan lives in the monorepo at `.plan/active/desktop-analytics/` once step 1 merges.

## Goal

Count messages sent from the Sesori desktop app on macOS, Linux and Windows in the product analytics warehouse, so
`user_activity_daily`, `daily_messages`, first-message and retention include them without downstream SQL changes.

## Decided route

The desktop app posts the product events it already emits to a new authenticated auth-server endpoint. The server
rechecks the account's preference, derives `user_key` from the JWT, validates each event strictly and stores it in Mongo
with a TTL. The daily auth export copies those rows to a BigQuery table. The warehouse unions that table into
`events_flattened`, through the same contract checks, internal exclusions and deletion tombstones as GA4 events.

Rejected, not reopened here: GA4 Measurement Protocol and a `dailyUsage` counter.

## Current behavior

- `client/desktop/lib/core/di/injection.dart:32-34` registers `AnalyticsRuntimeCapability.disabled(unsupportedPlatform)`,
  and `NoOpAnalyticsClient` is the sink. Desktop sends nothing on any OS.
- All shared seams already run on desktop. `session_detail_cubit.dart` and `session_launch_service.dart` call
  `ProductAnalyticsService.logEvent` in `unawaited` with `DateTime.now().toUtc()`. So `session_message_sent` and
  `session_created_with_message` need no new call site.
- `AnalyticsRepository` awaits the sink under a 10 second deadline, and `ProductAnalyticsService` drains deferred events
  one at a time. A sink that awaits HTTP could therefore stall the drain, so the new sink must return immediately.
- Asset 10 reads only `events_*`. It has strict parameter typing, closed enums, and a window `DELETE` plus `INSERT`.
- The auth export is a one-shot job with a lease, staging tables, one promotion transaction and an exact-schema check.
- The privacy sweep validates a closed keyed-table inventory. Any auth-dataset table with a `user_key` column that is
  not listed fails the sweep, and a listed table that is missing also fails it.

## Pinned contract

Installed apps can't be re-pointed, so this contract is permanent once step 7 ships. The server keeps accepting
`schemaVersion: 1` indefinitely. Changes are additive. The auth, warehouse and monorepo steps build against this section
and don't need each other's code.

### Endpoint

```
POST https://api.sesori.com/product-analytics/events
Authorization: Bearer <access JWT>
Content-Type: application/json
```

Body, at most 1 KiB (route `bodyLimit: 1024`), one event per request:

```json
{
  "schemaVersion": 1,
  "platform": "MACOS",
  "appVersion": "1.11.0",
  "name": "session_message_sent",
  "occurredAtMicros": 1793232000000000,
  "params": { "submission_kind": "text", "input_mode": "typed" }
}
```

| Field | Rule |
| --- | --- |
| `schemaVersion` | Literal `1` |
| `platform` | `MACOS`, `LINUX` or `WINDOWS`. Uppercase to match GA4's `IOS` and `ANDROID` in the same warehouse column |
| `appVersion` | `^\d{1,4}\.\d{1,4}\.\d{1,6}$`. Internal builds also report plain semver: `stage_desktop_bundle.dart` passes it as `--build-name`, and the `-internal` suffix exists only on tags and Velopack versions |
| `name` | One of the 23 names below |
| `occurredAtMicros` | Positive safe integer, from `received − 72 h` through `received + 300 s`, compared with the server clock |
| `params` | Required object. Exactly the keys listed for that event, no others. `{}` where none are listed |

Unknown fields anywhere are rejected. There is no `user_key` on the wire: the server derives it from the JWT. Free text
can't pass, because every value is a closed enum.

| `name` | `params` |
| --- | --- |
| `analytics_schema_ready` | none |
| `analytics_activation_ready` | `activation_schema_version`: `1` (string) |
| `project_inventory_loaded` | `inventory_state`: `empty`, `non_empty` |
| `session_activity_viewed` | `activity_state`: `empty`, `non_empty` |
| `session_message_sent` | `submission_kind`: `text`, `command`; `input_mode`: `typed`, `voice_assisted`. `command` requires `typed` |
| `session_created_with_message` | as `session_message_sent`, plus `workspace_kind`: `project`, `dedicated_worktree`, `no_project` |
| `session_creation_failed` | `failure_reason`: `not_authenticated`, `server_rejected`, `network_down`, `bad_response`, `unknown`; `workspace_kind` as above |
| `voice_transcription_completed` | none |
| `session_question_answered` | none |
| `session_question_rejected` | none |
| `session_permission_answered` | `decision`: `once`, `always`, `reject` |
| `session_abort_succeeded` | none |
| `session_diff_viewed` | `change_state`: `empty`, `non_empty` |
| `feedback_prompt_answered` | `answer`: `love_review_requested`, `love_no_review`, `could_be_better`, `dismissed`; `source`: `automatic`, `settings` |
| `private_feedback_sent` | `input`: `typed`, `voice_assisted`, `issues_only`, `empty`; `source` as above |
| `onboarding_need_help_opened` | `surface`: `connect_setup`, `connected_empty`, `bridge_offline` |
| `onboarding_support_link_opened` | `surface`; `channel`: `email`, `discord`, `x` |
| `onboarding_why_bridge_opened` | `surface` |
| `bridge_install_command_copied` | `surface`; `method`: `curl`, `powershell`, `npm`, `bun`; `os`: `unix`, `windows` |
| `bridge_install_command_shared` | as `bridge_install_command_copied` |
| `bridge_run_command_copied` | `surface` |
| `bridge_run_command_shared` | `surface` |
| `product_screen_viewed` | `screen`: `login`, `projects`, `settings`, `settings_default_input`, `settings_notifications`, `settings_profile`, `sessions`, `new_session`, `session_detail`, `session_diffs` |

The `os` parameter names the bridge install command's target. The app's own OS is `platform`.

| Response | Meaning | Client action |
| --- | --- | --- |
| `204`, empty body | Stored, already stored, or dropped because the preference is off. Deliberately not distinguished | Done |
| `400` | Failed validation. Only `{code, path}` of each zod issue is logged, never values or unrecognized key names | Don't retry. Log the event name and status |
| `401` | Bad token | The existing authenticated client refreshes once and retries once |
| `404` | User no longer exists | Don't retry |
| `413`, `429` | Oversized or rate limited | Don't retry |
| Network error, timeout, `5xx` | Transient | Retry per the client section |

Rate limit: 60 requests per minute per account, through `buildAccountRateLimitKey`, with `config.rateLimit` on the route
as in `src/routes/feedback.ts`. A human on desktop can't get near it, since the desktop reports no screens.

### Mongo collection

`AuthDbCollection.ProductAnalyticsEvents = "productAnalyticsEvents"`, in the existing auth database:

```ts
{
  _id: ObjectId,
  userKey: string,          // server-derived HMAC, treated as personal data
  eventName: string,
  occurredAtMicros: number,
  receivedAt: Date,         // server clock, UTC
  schemaVersion: 1,
  platform: string,
  appVersion: string,
  params: Record<string, string>,
}
```

| Index | Purpose |
| --- | --- |
| `{ userKey: 1, eventName: 1, occurredAtMicros: 1 }`, unique | Makes a retry idempotent. Its `userKey` prefix also serves the deletion `deleteMany` |
| `{ receivedAt: 1 }`, `expireAfterSeconds: 777600` (9 days) | Removes old rows, and serves the export's date-range scan |

### BigQuery table

`{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.desktop_product_events`. Flat, because `ProductAnalyticsExportTableField` has no
nested fields and the keyed inventory needs a top-level `user_key`:

```sql
CREATE TABLE IF NOT EXISTS `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.desktop_product_events` (
  event_name STRING NOT NULL,
  source_export_date DATE NOT NULL,      -- UTC date of received_at
  received_at TIMESTAMP NOT NULL,
  occurred_at_micros INT64 NOT NULL,
  schema_version INT64 NOT NULL,
  user_key STRING NOT NULL,
  platform STRING NOT NULL,
  app_version STRING NOT NULL,
  activation_schema_version STRING,      -- string, as asset 10 requires
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
  screen STRING,
  feedback_answer STRING,                -- wire param answer
  feedback_input STRING,                 -- wire param input
  feedback_source STRING                 -- wire param source
)
PARTITION BY source_export_date
CLUSTER BY event_name, user_key
OPTIONS (partition_expiration_days = 90);
```

Each run writes to a staging table, `desktop_product_events_staging_<runId>`, with the same columns, unpartitioned and
expiring like the existing staging tables. The auth repo's `productAnalyticsPermanentTableSchemas` holds the same column
list and modes.

## Design

### Client

Three small classes, because `client/AGENTS.md` keeps desktop logic out of `client/desktop`, and forbids it and
`module_desktop_core` from importing `module_auth` types:

- `ProductAnalyticsEventClient` in
  `client/module_core/lib/src/foundation/transport/product_analytics_event_client.dart`, a Layer 0 `Client` with the
  Freezed request model. It makes one attempt through a new
  `AuthenticatedHttpApiClient.postForUser`, a copy of `putForUser`, and returns a sealed result: delivered, permanent
  failure or transient failure.
- `AuthServerAnalyticsClient` in `client/module_desktop_core/lib/src/api/`, replacing `NoOpAnalyticsClient` as the desktop's
  `AnalyticsClient`. It owns the event allowlist and mapping, version handling, the account decision and retry. It reads the
  account from `AuthSession`, which `module_core` already exports.
- `DesktopAppInfoSource` in `client/module_desktop_core/lib/src/foundation/platform/` supplies the OS and app version.
  `FlutterDesktopAppInfoSource` in `client/desktop/lib/core/platform/` is its dumb adapter.

Behavior:

- `logProductEvent` returns at once. It maps the event, captures the current account from `AuthSession.currentState`,
  and starts sending in `unawaited`. A failure never reaches the caller. Per `AGENTS.md`, its local log keeps the event
  name, the failure category or HTTP status with the first 500 characters of any non-2xx response body, and the original
  error and stack trace where there is one. It leaves out the request body and credentials.
- `postForUser` refuses to send if the account changed, before any network call. That covers retries after a sign-out
  or account switch without any new state.
- Each attempt has a 5 second deadline. There are at most 3 attempts, 5 seconds and then 30 seconds apart, on network
  errors, timeouts, `5xx` and `NotAuthenticatedError`. The last one is how a failed token refresh surfaces, so it's the
  usual failure after waking from sleep, when the 15 minute access token has expired and the network isn't back yet.
  Before each retry, and before giving up, the client checks that the captured account is still signed in. If it isn't, it
  stops and logs at info level, because a sign-out isn't a failure.
- Retry scheduling ends after about 50 seconds even if the endpoint is dead. `.timeout()` abandons a request instead of
  cancelling it, so a socket can outlive its attempt. That's harmless, because the server ignores the duplicate.
- No queue, batch, timer or flush hook. Events in flight when the app quits are lost, and so are events during an outage
  longer than the retry budget. That loss is accepted: the numbers are product trends, and Sparkle's install on quit
  loses at most what was in flight.
- An exhaustive `switch` over the sealed `ProductAnalyticsEvent` returns the wire params or `null`, so a new client event
  fails to compile until someone decides whether it reaches the warehouse.
  - `null`, not sent, because they are outside the warehouse allowlist: `harness_install_finished`,
    `transcript_prompts_opened`, `computer_switched`, `computer_managed`, `founder_call_shown`,
    `founder_call_link_opened`, `founder_call_declined`.
  - `voice_transcription_completed` sends `{}`. The warehouse has no `finish` or `mode` column, and a server enum would
    reject the next new mode, as `on_device` was added this week.
  - Everything else sends `event.parameters` unchanged.
- `platform` comes from a `switch` on `defaultTargetPlatform` in the adapter. iOS, Android and Fuchsia are unreachable in
  this shell and send nothing. `appVersion` comes from `PackageInfo.version`, read once, with anything from a `+` onward
  removed, because no Windows app can be run to confirm its format. If that read fails, one warning has the error and stack
  trace, and each dropped event logs a warning naming it.
- `logInstallationEvent` and `activateAfterInteractiveAuthentication` stay no-ops. Asset 15's login diagnostics therefore
  remain mobile-only, and the `userKey` argument is unused because the server derives it.
- Sending turns on through the capability: `kReleaseMode ? enabled() : disabled(reason: debugOrProfile)`, the same rule as
  `client/app/lib/main.dart:286`.

### Server

`POST /product-analytics/events`, in `src/routes/product-analytics.ts`:

1. `requireAuth` and the account rate limit.
2. Strict zod validation: a discriminated union on `name` with strict `params`, built from TS enums with no raw strings.
3. `ProductAnalyticsPreferenceService.getPreference({ userId })`. Anything but enabled returns `204` without storing.
   That read already reports a suppressed account as disabled.
4. `insertOne`. Duplicate key error `11000` returns `204`.

One clock read serves both the time-bound validation and `receivedAt`, so a stored row always satisfies asset 10's
`occurred_at <= emitted_at + 300s`. `server.ts` already sets `disableRequestLogging: true`, so there's no per-event log line carrying an IP.

### Duplicates

A retry resends the same envelope, so the natural key `(userKey, eventName, occurredAtMicros)` is enough and no client
event ID is needed. The BigQuery load can't double-count either, because each run replaces whole partitions. A same-name
event by the same account in the same microsecond would be undercounted by one, which is accepted.

### Export

Inside the existing run, under the same lease and promotion transaction, so a published `run_cutoff` implies the desktop
rows for that cutoff are complete:

- `windowEnd` is 00:00 UTC of the `runCutoff` date, and `windowStart` is `windowEnd − 7 days`.
- Stream `receivedAt ∈ [windowStart, windowEnd)` from Mongo and append to staging in batches of
  `PRODUCT_ANALYTICS_EXPORT_BATCH_LIMIT`, with the same `JSON_QUERY_ARRAY(@rows_json)` insert as `appendMilestones`.
  The job's read-only Mongo credential is restricted to the auth database, so it covers this collection.
- In `validateAndPromote`, check the staged count, then
  `DELETE ... WHERE source_export_date >= @windowStart AND source_export_date < @windowEnd` and `INSERT` from staging.
- Rows aren't filtered by preference or internal status here. Asset 10 owns those exclusions, as it does for GA4.

The 9 day TTL has to exceed the 7 day window by more than the time of day of the run, or the oldest partition would be
replaced with a partial copy. Nine days leaves almost two days of margin. A manual midday run is safe too. The TTL is
kept short because this is personal data in an operational database.

An export outage of up to 7 days recovers fully. A longer one loses those desktop days, while GA4 recovers up to 90 days.
That difference is accepted, since a job down for a week has already failed asset 20's 36 hour check. An asset 10 outage
is still recoverable for 89 days, because BigQuery keeps the partitions for 90.

The desktop export shares the run with the auth snapshot, so a desktop export failure fails the whole run. The previous
publication stays in place. That coupling is accepted in exchange for not adding a second job and lease.

### Date alignment

`source_export_date` is the UTC date of `received_at`, which matches GA4's use of the emission date rather than the
occurrence date. The desktop branch sets `event_timestamp = UNIX_MICROS(received_at)`, so
`source_export_date = DATE(emitted_at)` still holds for `tests/schema_allowlist_assertions.sql`, and activity still lands
on `DATE(occurred_at)` in asset 20.

**A day can't be partial**, for two independent reasons:

1. The export only loads days strictly before its cutoff's UTC date, and replaces each in one transaction.
2. Asset 10's window end is clamped by the latest published auth cutoff:

   ```sql
   DECLARE latest_auth_cutoff_date DATE DEFAULT (
     SELECT DATE(MAX(run_cutoff)) FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.product_analytics_export_runs`
   );
   -- add one term to the existing LEAST in scan_end_date:
   COALESCE(DATE_SUB(latest_auth_cutoff_date, INTERVAL 1 DAY), DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 1 DAY))
   ```

   The clamp delays GA4 and desktop together, so a whole day stays consistent across both sources. It doesn't fail the
   asset. Asset 10's existing `LEAST(prev_end + 1, scan_end − 2)` closes the gap on the next run. Cutoffs only move
   forward, so `scan_end_date >= previous_source_end_date` keeps holding. The exception is the first deploy: if the last
   good cutoff is three or more days old, that assert fails with a message that only mentions GA4, so step 5 deploys right
   after a fresh export. `COALESCE` covers an empty runs table, in which case the desktop table is empty too.

**A day can't be counted twice**, because:

1. Asset 10 already deletes and reinserts its scan window, and the desktop branch uses the same window.
2. Export partitions are replaced, and a closed day's rows don't change, so re-exporting yields identical rows.
3. Desktop has no Firebase SDK, so the two branches never carry the same event.

| When (UTC) | What happens for an event received on day D |
| --- | --- |
| D+1 03:00 | Export publishes D |
| D+1 08:00 | GA4's latest table is D at best, and asset 10 stops one day before the latest, so `scan_end_date` is D−1. D waits |
| D+2 03:00 | Export republishes D, identically |
| D+2 08:00 | `scan_end_date` = D. GA4 and desktop publish D in the same run |
| One export fails | D+1's cutoff still gives `scan_end_date` = D. Nothing changes |
| Two exports fail | The clamp holds `scan_end_date` back, and asset 20 fails its 36 hour check as it does today. The next good run recovers the gap |

The clamp changes one runbook statement: "Stale auth snapshot" says `events_flattened` may continue ingesting. Step 5
updates it to say ingestion continues only through the latest published cutoff.

### Warehouse union

In `sql/10_events_flattened.sql`, GA4's select becomes one branch of a union, and the `required_parameter_names`
expression moves to a CTE over both. The desktop branch rebuilds GA4-shaped `event_params`, so every existing check and
quality counter runs unchanged:

```sql
SELECT
  event_name, source_export_date, UNIX_MICROS(received_at) AS event_timestamp,
  CAST(NULL AS STRING) AS user_pseudo_id,
  CAST(NULL AS INT64) AS event_bundle_sequence_id,
  CAST(NULL AS INT64) AS batch_event_index,
  platform, app_version,
  ARRAY(
    SELECT AS STRUCT p.key, STRUCT(p.string_value, p.int_value, CAST(NULL AS FLOAT64) AS float_value, CAST(NULL AS FLOAT64) AS double_value) AS value
    FROM UNNEST([
      STRUCT('user_key' AS key, user_key AS string_value, CAST(NULL AS INT64) AS int_value),
      ('schema_version', NULL, schema_version),
      ('occurred_at_micros', NULL, occurred_at_micros),
      ('activation_schema_version', activation_schema_version, NULL),
      ('inventory_state', inventory_state, NULL),
      -- every remaining flat column; answer, input and source map from feedback_*
    ]) AS p
    WHERE p.string_value IS NOT NULL OR p.int_value IS NOT NULL
  ) AS event_params
FROM `{{PROJECT_ID}}.{{AUTH_DATASET_ID}}.desktop_product_events`
WHERE source_export_date BETWEEN scan_start_date AND scan_end_date
```

The `NULL` values in `user_pseudo_id`, `event_bundle_sequence_id` and `batch_event_index` are safe for asset 10's
deduplication. Its partition also includes `event_timestamp`, `user_key`, `event_name` and `occurred_at_micros`, and the
Mongo unique key makes those distinct. `platform` carries the OS closed value with no schema change: no asset or
assertion restricts that column's values, and `app_distribution` already groups by it.

### Deletion

- **Mongo:** `ProductAnalyticsDeletionService.suppressAndHandoff` calls `deleteMany({ userKey })` after the source
  tombstone and before the handoff. It's idempotent, and a failure leaves suppression observable and the command safe to
  retry. The owner's 2026-08-08 decision (`.plan/active/user-analytics/TRACKER.md`) makes this an operator command run
  from the auth repo root under the app's production environment, whose Mongo credential writes the auth database. So the
  delete is permitted. The auth README and runbook still describe a separate suppression identity. Step 3 notes the delete
  there, and the drill before step 7 proves it. Operators must use a checkout containing step 3. An older one skips the
  delete, leaving rows to re-export for up to 9 days, though the tombstone and sweep still contain them.
- **BigQuery:** `desktop_product_events` joins `authKeyedTables` in `privacy_deletion_config.dart`, and
  `validateKeyedTableInventory`'s staging pattern extends to
  `^(auth_user_milestones|desktop_product_events)_staging_[a-z0-9_]{8,80}$`. `deleteKeyedContributions` and
  `verifyNoRepopulation` then cover the table with no other change.
- **Raw expiration, IAM and authorized views:** unchanged. The table sits in the restricted auth dataset, whose readers
  and writers don't change. `data_quality`'s authorized view reads only the tables named in its query. So the runbook's
  owner sign-off for "who can read data" isn't triggered. The privacy job's delete access reads as dataset-wide in the
  runbook, and a sweep with no tombstones returns before running any `DELETE`, so only the drill before step 7 proves it.
- **In-flight export:** a run that observes a suppression change after its cutoff aborts, as today. A suppression after
  that check can still promote a row, but the tombstone keeps it out of curated tables, and the sweep's auth cleanup waits
  for a run whose cutoff covers the tombstone, then deletes it.
- **Insert racing `deleteMany`:** an event in flight in the same milliseconds could store one row after the delete.
  The tombstone blocks it from curated tables, the sweep removes it from BigQuery, and the TTL ends it. Accepted.

### Abuse

An authenticated account can post at most 60 events per minute, or 777,600 stored rows over the TTL, each only under its
own `user_key` with closed values. It can inflate its own counts, and so can anyone with a modified mobile app, because
Firebase client keys are public. This route is at least authenticated. The 72 hour lower bound stops backdating first
messages. No further limit is added.

### Byte caps

Caps don't need to move. The allocations total exactly 2 GiB, and no query may exceed 768 MiB, so any raise would need a
matching cut or owner approval.

- Asset 10 (256 MiB) adds one statement for the cutoff read and scans three small desktop partitions, at around 200 bytes
  a row.
- Assets 20, 30 and 40 scan `events_flattened`, so they grow with desktop's share of rows. Asset 40 has the tightest
  margin: about 650-660 MiB billed against 768 MiB, on about 100 MiB processed, because 57 statements each bill the
  10 MiB minimum. Most of its statements stay under that minimum as rows grow.
- Runtime enforcement is the project and principal quota. `maxBytesBilled` applies to direct apply only.

Step 5 reviews the dry-run estimates, and step 10 reads actual billed bytes for 7 days after stable adoption. If any
asset is over 90% of its allocation, the fix goes to a reallocation PR, or to the owner if the 2 GiB total has to rise.

### Deployment order

These constraints come from the code, and each mistake has a real cost:

1. **Warehouse table before the export image.** The new export image's exact-schema check aborts if the table doesn't
   exist, and asset 20 goes stale at 36 hours. The old image ignores extra tables.
2. **Table and privacy image together, between two 06:00 UTC sweeps.** The inventory check fails in either mismatched
   order. The sweep and request-cleanup paths share one image and both validate the inventory. Apply the table, roll both
   to the new digest, and run one manual sweep to prove it, all right after a 06:00 run.
3. **Privacy image before the export image.** The old image doesn't recognize the new staging table name.
4. **Export image roll** updates `AUTH_EXPORT_IMAGE_REF` in the SOPS record. Run one manual export right after, before the
   03:00 UTC schedule.
5. **Everything above before step 7.** Asset 10's union itself can deploy any time after the table exists, right after a
   good export, because the table is empty until then.

The auth web deploy has no warehouse dependency. `ensureIndexes` creates the collection and indexes at startup, and the
route sits idle until step 7.

## Complexity budget

| New part | Kind | Why it exists |
| --- | --- | --- |
| `productAnalyticsEvents` Mongo collection with 2 indexes | Persistent | Holds accepted events until exported. Provides idempotency and short retention |
| `desktop_product_events` BigQuery table | Persistent | The warehouse's read source, and the keyed deletion target |
| `desktop_product_events_staging_<runId>` | Persistent, per run, expiring | Makes publication atomic, same as the existing staging tables |
| Pending retry futures in the desktop client | In-memory, retries end after about 50 s per event | Survives a transient failure. No field, list or timer object holds them |

No other server state is added. The rate limiter gains one route in its existing store.

Deliberately left out:

- Disk queue, because a small loss on crash or long outage is acceptable.
- Client event IDs, because the natural key holds.
- Batching, its timer and a flush-on-quit hook, because single requests need none of them.
- An in-flight cap, because the retry budget already bounds lifetime and events arrive at human pace.
- A separate export job, lease or watermark table, because the existing run provides all three.
- A preference filter at export time, because the server gate plus the tombstones cover it.
- A desktop-row counter in the run metadata, because a query answers it.
- A dashboard OS split, and desktop login events.
- A kill switch. Removing the route returns `404`, and the client doesn't retry on `4xx`.

### Safeguards and evidence

| Safeguard | Evidence level | Flow, and what happens without it |
| --- | --- | --- |
| Server recheck of the preference | Requirement, ordinary flow | Opt-out on another device. The event would be stored against the owner's choice |
| Strict closed schema | Requirement, privacy boundary | A modified client could store free text |
| Natural-key unique index | Ordinary flow | A timeout after the server committed. A retry would double-count |
| `sink returns immediately` | Ordinary flow | A dead endpoint would stall the deferred drain for 10 seconds per event |
| Retry on transient failure, including a failed token refresh | Ordinary flow | Waking from sleep, or a short network drop. Those events would be lost. The loss would be small, because the event fires after a successful send |
| Cutoff clamp in asset 10 | Ordinary flow | A failed export run. Desktop would be partially missing for a day that GA4 publishes |
| `postForUser` account check | Ordinary flow, reused | Sign-out during the retry window. An event would be sent under the wrong account |
| `deleteMany` on suppression | Requirement | Mongo rows would stay until the TTL and could reach BigQuery again |

Accepted without a safeguard, all theoretical: same-microsecond collision, an insert racing `deleteMany`, a
`PackageInfo` failure dropping events, and a device clock over 72 hours behind or over 5 minutes ahead (the latter is
already rejected by the warehouse for mobile).

## What counting changes in the numbers

- **Messages:** rise from the start date, partly from more being counted. Desktop is new and has few users, so the owner
  expects that part to be very small and wants no dedicated marker. The release is already a numbered marker on the
  `/internal/` Messages chart.
- **First message:** an existing desktop-only account gets `full_activation_at` at its first counted desktop message, not
  its true first. No SQL changes for this. It stays out of retention and weekly activation, because those require
  `activation_capable_at` within 24 hours of account creation, and an old account fails that. It's visible only in the
  restricted `user_milestones`.
- **Retention:**
  - Numerators rise for phone-activated users who also use desktop, which is a real correction. The retention charts
    already carry the numbered release markers.
  - New accounts that start on an updated desktop build now enter activation and retention denominators, because they
    send `analytics_activation_ready`. That is also a real correction, and it can move rates in either direction.
  - Accounts created on an old desktop build and updated more than 24 hours later stay out of cohorts permanently. That's
    a small understatement during the adoption ramp, and it's accepted.
  - Reporting views used outside the website carry no marker. Their readers should use the publish date of the first
    stable release carrying step 7.b.
- **Public headline:** `/traction/` keeps "Messages are up N% over the last 30 days" throughout, with no hiding and no
  note. This is the owner's decision of 2026-10-31.

## Steps

Merge gate, for every implementer:

> Right before merge: re-fetch inline comments and confirm each one whose `original_commit_id` matches the head has a
> reply or a fix; confirm Codex's completion comment names that exact head; wait at least 3 minutes after Codex's last
> comment. If Codex is still Running after about 30 minutes, or was triggered on an older head, with green CI and every
> thread replied, use `mark_ready`.

Testing rule, for every implementer: on-screen and device checks run only on a headless iOS simulator (`xcrun simctl boot`
without opening Simulator.app, on the device the project's local testing setup assigns), except that this feature is
desktop-specific, so desktop platform cells are in scope for it.

Project rules: Dart uses named `required` params, sealed Freezed classes, no null assertions and no
`@Default(EnumClass.unknown)`. TS uses object args and no `as any`. Dates are always UTC. Warehouse deploys follow the
runbook's "Deploying changes" routine.

```
1 ─┬─ 2 ─┬─ 5 ───────┐
   │     └─ (table)  │
   ├─ 3 ── 4 ────────┼─ 7 ── stable release ── 8
   └─ 6 ─────────────┘
                                 9 ── 10
```

After step 1, steps 2, 3 and 6 run in parallel. Step 4 builds on 3, and its image rolls only after 2 is applied. Step 5
builds on 2 and runs alongside 3, 4 and 6. Step 7 waits for 2-6 live, the pipeline and deletion drill, and the owner's
privacy decision. Step 8 follows the first stable release carrying step 7. Steps 1, 9 and 10 follow the docs-only PR rule.

### Step 1: raise the plan

`🌱 [desktop-analytics] Raise the desktop analytics plan [step 1/10]`. Repo: monorepo.

- **Complexity:** trivial. Documents only.
- **What:** adds `.plan/active/desktop-analytics/PLAN.md` and `TRACKER.md`.
- **Why:** the three repos need one pinned contract before they can proceed in parallel.
- **Risk and test focus:** none. Check the diff is docs-only.
- **Expected result:** no user-visible or database change.

### Step 2: warehouse table and deletion coverage

`🚧 [desktop-analytics] Add the desktop events table and its deletion coverage [step 2/10]`. Repo: warehouse. About 250
lines.

- **Complexity:** complex. It's small, but it changes the privacy deletion inventory and has a strict rollout order.
- **What:**
  - `sql/00_datasets.sql`: the pinned table, and the auth schema description and "four schemas" comment.
  - `privacy_deletion_config.dart`, `privacy_deletion_api.dart`: inventory and staging pattern.
  - `privacy_deletion_test.dart`: lines 91-94, 146, 481-485, 1059-1060, plus a new case for the staging name.
  - `tests/schema_allowlist_assertions.sql`: exact column list, partitioning and 90 day expiration.
  - `docs/reference/full-runbook.md`: table lists, retention, the staging-table text around line 1772, the suppression
    operation at line 420 (it now also deletes from `productAnalyticsEvents`), and the deployment order above.
    `docs/privacy-deletion.md`.
- **Why:** the table has to exist before the export can write to it, and it must be deletable from its first row.
- **Risk and test focus:** high if rolled in the wrong order, since the daily sweep fails. Test
  `dart privacy_deletion/privacy_deletion_test.dart`, the render-only dry run, the assertions, and one manual sweep after
  rollout.
- **Expected result:** a new empty table. The sweep passes with it in the inventory. No user-visible change.

Rollback: if the manual sweep fails, repoint the job to the previous digest and drop the empty table.

### Step 3: auth endpoint

`🚧 [desktop-analytics] Accept desktop product events on the auth server [step 3/10]`. Repo: auth. About 700 lines,
half of it tests.

- **Complexity:** complex. Privacy boundary, persistence and deletion.
- **What:**
  - `src/types/mongo.ts`, `src/db/mongo-db-accessor.ts`: collection and indexes.
  - `src/types/product-analytics.ts`: enums and the strict schema, next to the existing preference types.
  - `src/repositories/product-analytics-event-repo.ts`: insert and `deleteForUserKey`.
  - `src/services/product-analytics-event-service.ts`: the gate and insert.
  - `src/routes/product-analytics.ts`, `src/server.ts`: route, with `tokenService` and `resolveClientIp` added to its
    options.
  - `src/services/product-analytics-deletion-service.ts`, `src/scripts/suppress-product-analytics-export.ts`: delete step.
  - `README.md`: route, retention, the deletion note, and that suppression now deletes from `productAnalyticsEvents`.
- **Why:** this is the privacy boundary and the only place a desktop event can enter.
- **Risk and test focus:** medium. Nothing calls the route until step 7. Tests in `tests/auth/product-analytics.test.ts`:
  - Every event name accepted with its params.
  - Rejected: unknown name, unknown param, unknown top-level field, a `user_key` field, free text, `command` with
    `voice_assisted`, out-of-range time.
  - Preference off stores nothing and returns `204`. A suppressed account likewise.
  - A repeated body stores one row.
  - The 61st request in a minute returns `429`, keyed by account.
  - An oversized body returns `413`.
  - `ensureIndexes` creates the TTL index and recognizes it on a second run. It's the first use of `expireAfterSeconds`
    in this repo.
  - A rejected body logs no input value, including an unrecognized key name.
  - Suppression removes that account's rows only.
- **Expected result:** a new collection with 2 indexes. No user-visible change.

### Step 4: auth export

`🚧 [desktop-analytics] Export desktop product events to BigQuery [step 4/10]`. Repo: auth. About 500 lines. Builds on 3.

- **Complexity:** complex. It extends a leased, transactional job that all warehouse freshness depends on.
- **What:**
  - `product-analytics-export-repo.ts`: schema map, staging table, append, and the replace in `validateAndPromote`.
  - `product-analytics-event-repo.ts`: export cursor.
  - `product-analytics-export-service.ts`: the desktop phase, after the user scan and before cohorts.
  - `src/scripts/export-product-analytics.ts`: wiring.
  - `README.md`.
  - The schema map uses BigQuery API type names (`INTEGER`, not `INT64`) and compares fields in order. It must match the
    DDL's column order exactly. Fake-API tests can't catch a mismatch, but the manual export after the roll will.
- **Why:** this is the only writer of the warehouse table, and sharing the run makes `run_cutoff` imply completeness.
- **Risk and test focus:** high if rolled before step 2 is applied. Tests:
  - Window boundaries around 00:00 UTC, including a midday manual run.
  - Mapping of `answer`, `input` and `source` to `feedback_*`.
  - `source_export_date` is UTC.
  - Row count mismatch aborts promotion.
  - Re-running replaces rather than appends.
  - A suppression observed after the cutoff aborts, with staging cleaned up.
  - The exact-schema check fails on a missing table.
- **Expected result:** the job publishes the snapshot plus an empty desktop table. No user-visible change.

Rollback: repoint to the previous image digest. Before step 7 that's all it takes. After step 7, the old image still
publishes cutoffs, so asset 10 keeps publishing days with no desktop rows. Re-rolling backfills the last 7 days into the
table, but asset 10 only rescans 3, and the reconciliation assertion only sees its current window. So recovery also lowers
asset 10's `transform_state.source_end_date` to the day before the first affected day, which makes the next run rescan
from there. Step 5 adds this to the runbook, which has no rescan procedure today.

### Step 5: warehouse union

`🚧 [desktop-analytics] Union desktop events into events_flattened [step 5/10]`. Repo: warehouse. About 350 lines. Builds
on 2.

- **Complexity:** complex. It changes the root asset of every metric, in a non-trivially scheduled script.
- **What:**
  - `sql/10_events_flattened.sql`: union and clamp, as specified above.
  - Also there, `settings_default_input` joins the `screen` enum. The client already emits it, and asset 10 drops it as
    an unknown enum, for phones today. `tests/schema_allowlist_assertions.sql:675` changes with it.
  - `tests/metric_contract_assertions.sql`: a fixture proving the desktop projection passes parameter shape, enum and
    semantic checks for all 23 events, that two distinct rows both survive deduplication, and that a tombstoned or
    internal key is dropped.
  - `tests/schema_allowlist_assertions.sql`: a deployed reconciliation. Every desktop row in the scanned window that
    isn't internal or tombstoned must exist in `events_flattened`, so a wrong projection can't silently drop rows.
  - `docs/reference/full-runbook.md`: "Stale auth snapshot", the screen enum at line 392, the data flow, smoke steps, and
    the bounded rescan procedure. `docs/overview.md`: its "custom Firebase events" flow gets the second source.
- **Why:** this makes desktop rows real metric input with no downstream change.
- **Risk and test focus:** high, because this asset feeds everything. Deploy right after a good export. Check the
  render-only dry run and its byte estimates, the assertions, watermark advance, and that GA4 row counts are unchanged
  except `settings_default_input` for the rescanned dates, using aggregate counts only. The dry run is also the first real
  check of the `UNNEST` tuple's `NULL` coercion. If BigQuery rejects it, spell out `CAST(NULL AS ...)` in each tuple.
- **Expected result:** `events_flattened` content unchanged except the new screen value. No user-visible change. Can merge
  and deploy with the table empty.

Rollback: redeploy the previous asset. The window rewrite removes desktop rows from the rescanned dates. Older desktop rows
stay, and they are valid. If they ever need removing, use the rescan procedure.

### Step 6: desktop client, switched off

`⚙️ [desktop-analytics] Add the desktop analytics client, switched off [step 6/10]`. Repo: monorepo. About 400 lines.

- **Complexity:** moderate. A new sink, a new auth client method, and retry behavior.
- **What:**
  - `module_auth/.../authenticated_http_api_client.dart`: `postForUser`.
  - `client/module_core/lib/src/foundation/transport/product_analytics_event_client.dart`, its sealed Freezed request
    model with `toJson`, and its sealed result.
  - `client/module_desktop_core/lib/src/api/auth_server_analytics_client.dart`, importing no `module_auth` types.
  - `client/module_desktop_core/lib/src/foundation/platform/desktop_app_info_source.dart`, and its adapter
    `client/desktop/lib/core/platform/flutter_desktop_app_info_source.dart`.
  - Deletes `no_op_analytics_client.dart`.
  - `injection_test.dart`: expects the new client, capability still disabled.
- **Why:** it can be reviewed and merged with no release risk, ahead of the privacy decision.
- **Risk and test focus:** low, since the capability stays off and nothing calls it. Tests with a fake HTTP client:
  - The exact body against the pinned contract, for a sample of events.
  - `logProductEvent` completes before a never-completing POST does.
  - Retry happens on network error, timeout, `500` and `NotAuthenticatedError`, and not on `400`, `404`, `413` or `429`.
  - A retry after an account change sends nothing.
  - The 7 outside events send nothing, and voice sends `{}`.
  - Platform mapping for all three OSes, with `debugDefaultTargetPlatformOverride`.
  - A `1.11.0+1066` version is sent as `1.11.0`.
  - A `PackageInfo` failure sends nothing and doesn't throw.
  - Tests and analyze across `client/desktop`, `client/app`, `module_auth`, `module_core` and `module_desktop_core`.
- **Expected result:** no user-visible or database change.

### Step 7: turn it on

`🌿 [desktop-analytics] Turn on desktop analytics in release builds [step 7.b/10]`. Repo: monorepo. About 60 lines plus
disclosure.

**Gate. Do not merge until all three hold:**

1. Steps 2-5 are deployed, including the privacy and export images, and step 6 is merged, with evidence in the tracker.
2. The pipeline and deletion drill in the verification section has passed. No release has sent real rows yet, so a problem
   here costs nothing.
3. The owner approved the privacy wording themselves on 2026-10-31, with no outside review. That wording is in place both
   in the disclosure below and in the live notice at `https://sesori.com/privacy/`. The disclosure says it isn't itself a
   published notice. The
   notice's source is `assets/legal/privacy.md` in the auth repo, which `https://api.sesori.com/privacy` serves, so it
   ships as its own auth PR, `🌱 [desktop-analytics] Name the desktop app in the privacy notice [step 7.a/10]`, before this
   switch, which is step 7.b. This condition applies to this step only and blocks nothing earlier.

Internal builds are hourly, so merging means sending from the next internal build, and from the next stable cut for
everyone else. Sparkle checks every 6 hours and installs on quit or restart, AppImage uses Velopack, and DEB/RPM use
signed repositories, so adoption ramps over days after a stable release. Stable last shipped Sep 24, Oct 14 and Oct 27.
Windows has no public build, so it counts from its first release with no extra analytics work.

People with the desktop app already installed get the same Basic Usage Analytics switch and no new prompt. The notes of the
first stable release carrying this step say so in one line, added by hand because the generator only lists PR titles:
"Sesori Desktop now sends the same basic usage analytics as the phone app. You can turn this off in Settings."

- **Complexity:** straightforward. A single switch, but its effect is broad.
- **What:**
  - `client/desktop/lib/core/di/injection.dart`: the `kReleaseMode` capability.
  - Removes `AnalyticsRuntimeDisabledReason.unsupportedPlatform`, and its entry in
    `client/app/test/core/platform/firebase_analytics_startup_test.dart:57`, since the value is then unused.
  - `client/app/docs/PRODUCT_ANALYTICS_DISCLOSURE.md`: desktop section with the approved wording. Facts to reflect:
    - Events go to Sesori's auth server, not Firebase or Singular.
    - The same closed event set, plus OS and app version.
    - The same Basic Usage Analytics switch governs them, and it's now rechecked on the server.
    - Retention: 9 days in the operational database, 90 days in the restricted BigQuery table, then the existing 14 months
      for curated facts.
    - The IP address is seen in transport and for rate limiting but not stored with events.
- **Why:** this is the single point where counting starts.
- **Risk and test focus:** low for the app, because the sink can't block it. Check that the Settings switch becomes live
  on desktop, and that a debug or profile build sends nothing. The dispatch-only release-mode probes
  (`desktop-qualification.yml`, `desktop-linux-authenticated-upgrade.yml`) sign in to production with QA credentials, so
  they will now send events such as `analytics_schema_ready`. Confirm by aggregate count that those QA accounts are in the
  permanent internal exclusion, and add them if they aren't.
- **Expected result:** user-visible: the Basic Usage Analytics switch is live on desktop release builds. Database: rows
  start arriving.

Rollback: revert for new builds. For installed apps, removing the route stops storage, and the client doesn't retry.

### Step 8: correct the traction copy

`🌱 [desktop-analytics] Say the traction page counts the desktop app [step 8/10]`. Repo: website. About 2 lines.

Open it when the first stable release carrying step 7.b is published, and merge within two days. Warehouse lag means the
numbers can't rise on the charts before that.

- **Complexity:** trivial. One copy change.
- **What:** `src/pages/traction.astro`: the copy at lines 87-88 becomes "Counts the phone and desktop apps." Also change any
  other copy that still says the desktop app isn't counted. No chart marker, date constant, or headline change: the owner
  decided on 2026-10-31 that none is needed, and `/internal/` already marks the release.
- **Why:** the current sentence becomes false once desktop counts.
- **Risk and test focus:** low. `npm test`, `npm run lint`, `npm run verify:site`.
- **Expected result:** user-visible: the new `/traction/` sentence. No database change.

### Step 9: reconcile docs

`🌱 [desktop-analytics] Reconcile the analytics docs with desktop counting [step 9/10]`. Repo: monorepo.

- **Complexity:** trivial. Documents only.
- **What:**
  - `docs/regression/analytics.md`: the capability paragraph no longer says "no-op sink". Required behavior gains the
    route, server recheck, no local queue, and accepted loss. "The desktop reports no screens" stays true. L2-L5 entries
    gain the desktop cells.
  - `client/AGENTS.md:131`: "disabled desktop analytics" is replaced with the actual rule, release-only.
- **Why:** the docs state a behavior that has changed.
- **Risk and test focus:** none. Verify docs-only.
- **Expected result:** no user-visible or database change.

### Step 10: verify and retire

`🌱 [desktop-analytics] Record desktop analytics verification and retire the plan [step 10/10]`. Repo: monorepo.

- **Complexity:** trivial as a PR, though the checks behind it take days of elapsed time.
- **What:** runs the matrix below, records results in `TRACKER.md`, and moves the plan to `.plan/completed/desktop-analytics/`.
- **Why:** it proves the whole path through its real boundary.
- **Risk and test focus:** the post-release cells use real release builds. Any disposable account used for them has to be
  removed through the real deletion path, like the drill's.
- **Expected result:** no user-visible or database change beyond that account's removal.

## Verification

Affected documents: `docs/regression/analytics.md`, `client/app/docs/PRODUCT_ANALYTICS_DISCLOSURE.md`. Highest level: L5
for the desktop analytics behavior, because it depends on a packaged release build and external services. It isn't L5
for all of analytics.

All cells use a release build, because debug and profile builds don't send. `authBaseUrl` is a constant, so cells run
against production with a disposable, non-excluded account created for this check. Queries report aggregate counts only.
An excluded account wouldn't reach `events_flattened`.

**Pipeline and deletion drill, before step 7.** This runs with no release involved, against the deployed steps 2-5:

1. Sign the disposable account in normally. Keep its token in memory only and never log it.
2. `POST` a `session_message_sent` with `platform = WINDOWS`, the same body again, one body per rejection class, and
   another valid event with the preference off.
3. Confirm one stored row in Mongo. After the exports, confirm it in `desktop_product_events` the next day, and in
   `events_flattened` and `daily_messages` at D+2.
4. Run the runbook's suppression and handoff, then request cleanup and one sweep.
5. Confirm zero rows in Mongo immediately, then zero in `desktop_product_events`, curated and reporting tables.
   `verifyNoRepopulation` is clean, and the tombstone remains. Delete the Mongo user with a guarded filter.

This proves the export, union and deletion path, the Mongo delete credential, and the privacy job's access to the new
table. It takes about three days of elapsed time, and its one synthetic message leaves the numbers with the sweep. It's
also the honest extent of pipeline verification for Windows.

**After step 7:**

| Cell | Build | Check | Result expected |
| --- | --- | --- | --- |
| macOS arm64, send | Internal-channel release | Send in an existing session, and create a session with a message | Two Mongo rows, `platform = MACOS`, then in `desktop_product_events` the next day, then in `events_flattened` at D+2, then in `daily_messages` |
| macOS arm64, opt-out | Same | Turn the switch off and send. Then turn the server preference off while the app's local state is stale, using a second session | No new rows in either case |
| macOS arm64, dead endpoint | Same | Sinkhole the auth host in `/etc/hosts` during a signed-in session and send | Composer stays responsive and sending isn't slowed. Restore with `cp` |
| Linux x64 | Internal-channel release, AppImage | One message | `platform = LINUX` through to `events_flattened` |
| Windows | No public build | Unit test of platform mapping, the `windows-distribution` CI job, and the drill's `platform = WINDOWS` row | **No Windows app run is possible**, so the app's own version format and sending are unverified. Its first real events arrive with its first release, and should be checked then |
| Phone regression | Headless iOS simulator only if an on-screen check is needed | `flutter test` for `client/app`, `module_core`, `module_auth`. No phone behavior changes | Mobile GA4 flow unchanged |
| Date alignment | Production | Three complete days after adoption, reconciliation assertion from step 5 | Every eligible desktop row present, once |
| QA exclusion | Production | Aggregate count of curated rows from the QA accounts after a probe run | Zero |
| Bytes | Production | `INFORMATION_SCHEMA.JOBS` for 7 days after stable adoption | Each asset under 90% of its allocation, or a follow-up |
| Website | Production | `/traction/` | New copy, percentage still showing, no note |

Cells needing an interactive sign-in that an agent can't drive are run on the published internal build after merge, by
the owner, per the project's testing rule. The Linux cell depends on sign-in working on that package. If it doesn't, that
is reported as a Linux desktop bug. Reducing this matrix needs the owner's explicit acceptance, recorded here.

## Cleanup assessment

Included in the feature PRs:

- Delete `NoOpAnalyticsClient` (step 6).
- Delete `AnalyticsRuntimeDisabledReason.unsupportedPlatform` (step 7).
- Update `injection_test.dart`, the auth schema description, `docs/overview.md`, the runbook's stale-auth text, and the
  `/traction/` copy.

No larger cleanup is caused by this change. `NoOpAttributionClient` and the other desktop no-ops stay, because desktop
still has no attribution SDK.

## Risks

| Risk | Handling |
| --- | --- |
| A rollout order mistake stalls the sweep or the export | Deployment order above, with a manual run after each roll |
| A desktop export bug makes all warehouse freshness stale | Tests, and the previous publication stays in place. Rollback is a digest repoint, plus a bounded rescan if step 7 has shipped |
| The Mongo delete or the privacy job's delete fails in production | The drill before step 7, while no real rows exist |
| Release-mode QA probes send events under real accounts | Confirm they're in the permanent internal exclusion |
| A wrong projection silently drops desktop rows | Fixture for all 23 events, plus the deployed reconciliation assertion |
| Existing desktop users' preference defaults to enabled, and they start sending on update with no prompt | Owner accepted on 2026-10-31: same switch, the updated notice, and one line in the release notes |
| The contract can't be changed once shipped | Additive only, and `schemaVersion` is on the wire |
| Readers misread the rise | Owner accepted on 2026-10-31: desktop has too few users to move it, and `/internal/` already marks the release |

## Open decisions

None. On 2026-10-31 the owner approved the privacy wording themselves, chose the same switch with one line in the release
notes, and kept the `/traction/` percentage with no note. Accepted risks are recorded above.

## Review record

One adversarial review of the draft against all four repos' origin refs, by a read-only Opus sub-agent, on 2026-10-31. It
ran no BigQuery or Mongo queries and didn't read the restricted deployment record. It found that the route works and that
no redesign is needed. This revised version was not re-reviewed, because the fixes add no new scope. Outcome:

| Finding | Outcome |
| --- | --- |
| Rated blocking: the Mongo delete may be denied for a separate suppression identity | Downgraded. The owner's 2026-08-08 decision runs suppression under the app's production environment. Kept the doc updates and proof by drill |
| The client imported `module_auth` types into `client/desktop`, against a project rule | Fixed. The request moved to `module_core`, as `ProductAnalyticsEventClient` after step 6's architecture review |
| Rolling back the export after step 7 can leave a permanent gap | Fixed. Added a bounded rescan procedure |
| The QA check in step 7 was wrong, because release probes do sign in to production | Fixed. Replaced with an exclusion check |
| The privacy gate didn't name the live public notice | Fixed. Added to the gate |
| Deletion would first be proven after real rows exist | Fixed. Added the drill to step 7's gate, which made a separate ACL check unnecessary |
| Deployment order named only the sweep job | Fixed. It now names both paths |
| Retry missed a failed token refresh | Fixed. The reviewer proposed comparing account ids, but no comparison is needed: `postForUser` already refuses a changed account before any network call |
| Minor: schema type names, first clamp deploy, denominators, single clock read, timeout wording, docs lists, date table wording, `+build` suffix, Messages-only prop in the shared chart loop | Fixed |
| Removals: the `-internal` version group and the `platform` assertion | Applied. The version group was confirmed dead in `stage_desktop_bundle.dart` |

Not verified by anyone yet, and left to the steps named: `NULL` coercion in the `UNNEST` tuple (step 5's dry run), the
GCP and Mongo roles (the drill), and Windows' real `PackageInfo` value (its first release).
