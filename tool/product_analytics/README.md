# Product analytics warehouse runbook

This directory owns the Step 5 operator contract for the Sesori product
analytics warehouse. It covers controlled deployment, the warehouse data
dictionary, daily operation, privacy deletion, recovery, and release
reconciliation. Dashboard construction is pinned separately in
[`LOOKER_STUDIO.md`](LOOKER_STUDIO.md).

All reporting time is UTC. Complete weeks are Monday through Sunday. Never put
credentials, pseudonymization secrets, raw account identifiers, installation
identifiers, or live internal-user keys in this repository, command arguments,
logs, tickets, or dashboard URLs.

## Deployment block

**Cloud deployment is blocked.** Do not apply datasets, transforms, transfer
configurations, auth-export scheduling, privacy-deletion scheduling, or Looker
data sources until all of the following are approved and recorded in the
restricted deployment record:

- GA4 two-month retention, Google Signals, and advertising/privacy settings;
- restricted project and dataset IAM with broad inherited data access removed;
- separate deployment, auth-export, transform, deletion, and Looker service
  identities;
- the exact UTC `raw_export_start_at`, which cannot be inferred from a daily
  table suffix;
- the restricted Looker report owner; and
- the restricted Looker viewer group.

This block is a safety gate, not a scope boundary. Creating and verifying these
cloud resources is required Step 5 delivery work after approval; merging the
repository PR alone does not complete the analytics rollout.

As of 2026-07-31, those approvals are unverified. All mutating commands remain
blocked even though the raw export, retention expiration, billing, budget, and
query-quota facts below have been observed.

The unresolved values below are intentional placeholders. Preserve them in
source control and fill the corresponding values only in the restricted
deployment record or managed runtime configuration.

| Required approval | Restricted value |
| --- | --- |
| Analytics/security administrator group | `<ANALYTICS_SECURITY_ADMIN_GROUP>` |
| Deployment identity | `<DEPLOYMENT_SERVICE_ACCOUNT>` |
| Auth-export identity | `<AUTH_EXPORT_SERVICE_ACCOUNT>` |
| Auth suppression identity | `<AUTH_SUPPRESSION_SERVICE_ACCOUNT>` |
| Scheduled-transform identity | `<TRANSFORM_SERVICE_ACCOUNT>` |
| Privacy-deletion identity | `<PRIVACY_DELETION_SERVICE_ACCOUNT>` |
| Looker data-source identity | `<LOOKER_SERVICE_ACCOUNT>` |
| Exact controlled raw start | `<RAW_EXPORT_START_AT_UTC>` |
| Behavioral schema-v1 start | `<BEHAVIORAL_SCHEMA_V1_START_AT_UTC>` |
| Auth-export schedule | `<AUTH_EXPORT_SCHEDULE_UTC>` |
| Transform schedule owner | `<TRANSFORM_SCHEDULE_OWNER>` |
| Privacy sweep schedule | `<PRIVACY_SWEEP_SCHEDULE_UTC>` |
| Dashboard owner | `<DASHBOARD_OWNER>` |
| Dashboard viewer group | `<DASHBOARD_VIEWER_GROUP>` |
| Dashboard refresh/cache policy | `<DASHBOARD_REFRESH_POLICY>` |

## Verified cloud facts

These facts were observed during the 2026-07-31 controlled preflight. They do
not clear the deployment block above.

| Fact | Verified value |
| --- | --- |
| GCP/Firebase project | `sesori-ai` |
| GA4 property | `529377727` |
| Raw GA4 dataset | `analytics_529377727` |
| BigQuery location | `europe-west3` |
| Export mode | Daily tables; do not enable streaming/intraday export |
| Earliest daily table | `events_20260725`, representing 2026-07-25 |
| Raw default table expiration | 90 days |
| Existing raw daily-table expiration | 90 days |
| Billing | Active and linked |
| Alert budget | USD 10 per month, project scoped, all services |
| Actual-spend alert thresholds | 50%, 80%, and 100% |
| Forecast-spend alert threshold | 100% |
| BigQuery on-demand project query quota | 10 GiB per day |
| BigQuery on-demand principal query quota | 2 GiB per day |

The earliest table date is evidence that export data exists. It is not an exact
`raw_export_start_at`, does not prove the first table was controlled before it
landed, and does not prove GA4 privacy settings or IAM were correct at that
time.

## Controlled preflight

Use a named operator account with read-only project, billing, IAM, BigQuery,
Firebase, and GA4 access for preflight. Record command output in the restricted
change record. Do not use a deployment service account for discovery and do not
grant roles merely to make a check pass.

### 1. Establish the operator context

Run from the apps-monorepo root:

```bash
gcloud config get-value project
gcloud auth list --filter=status:ACTIVE
bq version
dart --version
```

The selected project must be `sesori-ai`. `bq`, including calls made by
`deploy.dart`, uses the active Cloud SDK credential shown by `gcloud auth list`;
it does not use Application Default Credentials (ADC). The auth export uses ADC;
privacy-deletion jobs use their attached metadata-server identity by default.
They never perform login or read a downloaded service-account key file. Check
local ADC separately only for explicit operator API checks or an approved manual
privacy run that opts into fallback:

```bash
gcloud auth application-default print-access-token >/dev/null
```

Stop if either credential source is ambiguous, a JSON key is being used, or the
operator cannot distinguish read-only preflight from a mutating deployment.

### 2. Verify GA4 privacy settings

GA4 property `529377727` must use two-month event/user-data retention, with the
reset-on-new-activity behavior disabled so activity cannot extend the intended
two-month user-data window. Google Signals must be disabled.

Read the current Admin API values with an operator credential that has only the
required Analytics read scope. Put the bearer header in a mode-600 curl config;
never place an access token in curl's command arguments or shell history:

```bash
umask 077
ANALYTICS_TOKEN_FILE="$(mktemp)"
ANALYTICS_CURL_CONFIG="$(mktemp)"
gcloud auth application-default print-access-token \
  --scopes=https://www.googleapis.com/auth/analytics.readonly \
  >"${ANALYTICS_TOKEN_FILE}"
{
  printf '%s\n' 'fail' 'silent' 'show-error'
  printf 'header = "Authorization: Bearer '
  tr -d '\r\n' <"${ANALYTICS_TOKEN_FILE}"
  printf '"\n'
} >"${ANALYTICS_CURL_CONFIG}"
rm -f "${ANALYTICS_TOKEN_FILE}"

curl --config "${ANALYTICS_CURL_CONFIG}" \
  "https://analyticsadmin.googleapis.com/v1alpha/properties/529377727/dataRetentionSettings"

curl --config "${ANALYTICS_CURL_CONFIG}" \
  "https://analyticsadmin.googleapis.com/v1alpha/properties/529377727/googleSignalsSettings"

rm -f "${ANALYTICS_CURL_CONFIG}"
unset ANALYTICS_TOKEN_FILE ANALYTICS_CURL_CONFIG
```

Require and record all of this evidence:

- `eventDataRetention` is `TWO_MONTHS`;
- `resetUserDataOnNewActivity` is `false`;
- Google Signals `state` is `GOOGLE_SIGNALS_DISABLED`, not unspecified or
  merely pending a change;
- ads personalization is disabled for the property and every applicable data
  stream;
- ad storage and ad user-data features are disabled;
- no Google Ads or ad-network audience activation broadens the approved use;
- Android `AD_ID`, Apple IDFV collection, and automatic ad-network registration
  remain disabled in the released Firebase configuration; and
- the property timezone is recorded, while this warehouse still reports in UTC.

Retention and Google Signals have Admin API read methods. The remaining ads and
stream settings must also be inspected in GA4/Firebase Admin because no single
API response proves the complete posture. Capture screenshots or exported
configuration in the restricted approval record, not in this repository.

If any setting is unverified or cannot be applied, stop. Do not alter the
privacy boundary in this runbook to match a looser property.

### 3. Verify the raw export

Use explicit project and location on every BigQuery operation:

```bash
bq show --project_id=sesori-ai --format=prettyjson \
  sesori-ai:analytics_529377727

bq ls --project_id=sesori-ai --format=prettyjson --max_results=1000 \
  sesori-ai:analytics_529377727

bq show --project_id=sesori-ai --format=prettyjson \
  sesori-ai:analytics_529377727.events_20260725
```

Verify that the dataset location is `europe-west3`, the default expiration is
90 days, every current `events_YYYYMMDD` table expires 90 days after creation,
and no `events_intraday_*` table exists. Recheck all tables rather than assuming
the default repaired tables created before the default changed.

The GA4 link must remain daily-only. Do not unlink it as a rollback mechanism;
export is not retroactive and unlinking creates an unrecoverable gap.

### 4. Verify billing controls and quotas

Confirm the active billing link, the project-scoped all-services USD 10 monthly
alert budget, its notification channels, and these thresholds:

| Threshold type | Threshold | Nominal monthly spend |
| --- | --- | --- |
| Actual | 50% | USD 5 |
| Actual | 80% | USD 8 |
| Actual | 100% | USD 10 |
| Forecast | 100% | USD 10 forecast |

Confirm BigQuery on-demand query quota overrides are 10 GiB per project per day
and 2 GiB per principal per day. Record quota names and effective values from
the Cloud console/API in the restricted deployment record.

Budgets are **alerts only**. They do not cap spend, reject queries, disable
services, or guarantee timely delivery. Query quotas can reject warehouse or
dashboard queries, but they do not cap non-query service costs and are not a
replacement for the budget. A failed scheduled query caused by quota exhaustion
is a freshness incident, not a zero-usage day.

### 5. Verify restricted IAM

Export the project IAM policy for restricted review and inspect dataset/table
access separately:

```bash
gcloud projects get-iam-policy sesori-ai --format=json

bq show --project_id=sesori-ai --format=prettyjson \
  sesori-ai:analytics_529377727
```

Reject broad primitive roles and project-wide BigQuery data-viewer/editor roles
that make raw or private datasets visible to ordinary project members. Confirm
that each service identity in the identity matrix below exists, is owned by the
approved team, uses keyless workload identity/ADC, and has no unexplained role.

### 6. Go/no-go record

Preflight passes only when every approval placeholder has a value in the
restricted record, every expected deny test succeeds, the exact raw start is
approved, and the dashboard owner/group are approved. A partially complete
check is a no-go. Dry-running repository SQL is permitted before approval;
mutating cloud state is not.

## Data architecture

All derived datasets must be created in `europe-west3`. Dataset names are fixed
defaults for this deployment; changing one requires an explicit migration, not
a Looker-side alias.

### Dataset dictionary

| Dataset | Classification | Retention and contents | Allowed readers/writers |
| --- | --- | --- | --- |
| `analytics_529377727` | Raw restricted | Firebase-managed `events_YYYYMMDD`; 90-day default and current-table expiration | Analytics/security admins and transform/deletion identities only |
| `sesori_analytics_auth_private` | Pseudonymous private | Current eligible auth snapshot, aggregate setup cohorts, run metadata/state, and expiring staging tables | Auth export writes; transform reads; deletion repairs; admins oversee |
| `sesori_analytics_privacy_private` | Privacy restricted | Deletion targets and status only | Suppression handoff and deletion identity; security/privacy admins |
| `sesori_analytics_controls` | Restricted controls | Permanent internal and deletion exclusions, measurement starts, freshness policy, keyed-publication guard, and authorized exclusion view | Deployment identity writes; transform reads plus table-scoped guard update; auth export sees one authorized view only |
| `sesori_analytics_curated` | Minimized pseudonymous | Allowlisted event facts, daily user activity, milestones, cohorts, and scheduled intermediates | Transform identity writes; analytics engineers read; deletion repairs |
| `sesori_analytics_reporting` | Identifier-free reporting | Aggregate authorized reporting views | Deployment creates views; Looker and approved product leadership read; deletion receives metadata-only inventory access |

Looker Studio and routine viewers may access only
`sesori_analytics_reporting`. They must not receive access to raw, auth-private,
privacy-private, controls, curated user-level tables, or `user_key`.

### Raw boundary

The vendor-managed raw GA4 schema can contain `user_pseudo_id`, GA session
identifiers, device and app metadata, derived geography, stream/bundle metadata,
traffic-source strings, Firebase automatic events, and native `screen_view`
rows. Source IP is not an exported column, but Google may derive geography
before export.

The curated pipeline must never select installation IDs, session IDs, device
brand/model, geography, user properties, advertising/vendor identifiers,
bundle sequence, stream ID, or arbitrary traffic-source values. Firebase
automatic events and native `screen_view` do not define product activity.

### Auth-private objects

| Object | Grain and contract |
| --- | --- |
| `auth_user_milestones` | One currently eligible, non-internal, non-suppressed account per `user_key`; account creation, notification registration, bridge registration, legacy metadata-request milestone, and export time |
| `auth_weekly_setup_cohorts` | One external-account creation week; identifier-free account totals, preference coverage, and 1/7/30-day setup counts after internal/source suppression |
| `product_analytics_export_runs` | One successful export publication; aggregate source/exclusion/reconciliation counts, immutable cutoff, completion, and freshness metadata only |
| `product_analytics_export_state` | Singleton distributed lease and last successfully published cutoff; an equal/older or overlapping run cannot replace newer state |
| Run staging tables | One export run; only pseudonymous or aggregate rows, hidden from reporting and expiring within 24 hours |

`notification_registered_at` proves notification registration, not complete
mobile setup. `legacy_first_metadata_request_at` is a historical setup signal,
not a successful session creation or full activation.

### Privacy-private and control objects

| Object | Contract |
| --- | --- |
| `product_analytics_deletion_targets` | External privacy request ID, HMAC `user_key`, deletion-only legacy Firebase user ID, source tombstone time, status, and non-identifying operation metadata; no raw account ID |
| `permanent_internal_user_exclusions` | Permanent HMAC `user_key`, owner, reason, and creation time; never committed to Git and never expired to reintroduce history |
| `internal_exclusion_control_state` | Singleton common `control_updated_at`; advance only when the permanent exclusion set is reviewed |
| `auth_permanent_internal_exclusions` | Read-only projection for auth export with `user_key`, `is_active`, and common `control_updated_at`, including a null-key freshness sentinel |
| `permanent_deletion_exclusions` | Permanent HMAC `user_key` tombstones used by every flattened/reported rebuild and recurring sweep |
| `keyed_publication_guard` | Singleton epoch advanced transactionally by tombstone insertion and keyed publication to prevent concurrent repopulation |
| `analytics_measurement_config` | Exactly one approved `raw_export_start_at`, one independently approved `behavioral_schema_v1_start_at`, clock-skew/freshness policy, and update audit metadata |
| `product_analytics_privacy_sweep_state` | Last successful raw-partition watermark and run status; no discovered installation identifier is persisted |

### Curated objects

| Object | Grain and contract |
| --- | --- |
| `transform_state` | One last-success watermark/quality row per transform with source range, completion/auth freshness, bounded rejection counts, and latest event times; no identifiers |
| `events_flattened` | One deduplicated, allowlisted account-linked custom event; keeps `user_key`, event name, schema, validated occurrence/emission UTC timestamps, platform/app version, and bounded event parameters only |
| `installation_login_daily` | UTC date/platform/app version/provider/failure-kind aggregate counts; never contains `user_pseudo_id` or `user_key`; always flags `includes_internal_test_traffic=true` |
| `user_activity_daily` | One eligible user/UTC date with bounded monitoring, control, message, voice, diff, screen, and feature flags/counts |
| `user_milestones` | One eligible user with auth milestones and earliest foundation, activation-capable, project, activation, monitoring, and feature milestones |
| `activation_cohorts` | Account creation cohort with 1/7/30-day setup/activation flags, latency, maturity, and separate preference/foundation/activation-capability coverage |
| `retention_cohorts` | Activation-week cohort with W1 (days 7-13) and W4 (days 28-34) eligible denominators, meaningful-activity numerators, and separate flags that become mature only after every activated user in that week has completed the window |
| `weekly_engagement` | One complete UTC Monday-Sunday week with meaningful/controller WAU, activity-depth percentiles, intervention/message/voice/feature totals, and refresh time |
| `screen_usage_weekly` | Complete week/platform/app version/pinned screen with identifier-free unique-user and view counts |
| `onboarding_friction_weekly` | Complete week and bounded diagnostic dimensions with identifier-free user/event counts |

`events_flattened` is recoverable only while the relevant raw partitions remain
inside the 90-day window. Minimized pseudonymous curated facts are retained for
426 days (approximately 14 months) initially. Identifier-free aggregate history may be retained longer
only after privacy approval.

### Reporting views

| View | Contract |
| --- | --- |
| `investor_snapshot` | One null-capable headline row with independently labeled latest complete account week, engagement week, and mature seven-day activation cohort, plus comparisons, coverage, and as-of timestamps |
| `weekly_kpis` | Complete-week new accounts, meaningful/controller WAU, growth, activity depth, and setup/activation conversion |
| `activation_funnel` | Account-to-bridge-to-project-to-message cohorts with mature 1/7/30-day windows, aggregate time-to-step buckets/percentiles, and notification registration kept separate |
| `retention` | Activation-anchored W1/W4 cohort-maturity flags; numerators, eligible denominators, and rates remain null until every activated user in the week completes that window |
| `feature_adoption` | Worktree, diff, question/permission, abort, remote-created-session, voice, and related bounded adoption aggregates |
| `installation_login_funnel` | Account-less attempt started/completed/failed aggregates and provider rates; diagnostic only and potentially includes internal/test release traffic |
| `screen_usage` | Account-level users/views for pinned screens from `product_screen_viewed` only |
| `onboarding_friction` | Empty states, bounded creation failures, and confirmed support/install outcomes |
| `data_quality` | Raw/auth/reporting freshness, schema/app versions, invalid timing/identity/enums, exclusion counts, coverage, maturity, and pipeline status |

The exact Looker chart, field, filter, formula, and labeling contract is in
[`LOOKER_STUDIO.md`](LOOKER_STUDIO.md). Do not reproduce warehouse metric logic
with ad hoc Looker blends or formulas.

### Event allowlist

Every account-linked event also has schema version, a validated 64-character
lowercase HMAC `user_key`, and `occurred_at_micros`. The warehouse converts raw
GA microseconds with `TIMESTAMP_MICROS`; it does not substitute SDK emission time
when occurrence time is invalid.

| Event | Allowed event-specific parameters | Reporting meaning |
| --- | --- | --- |
| `analytics_schema_ready` | None | Foundation/preference coverage only |
| `analytics_activation_ready` | `activation_schema_version=1` | Activation-capable exposure, never activity |
| `project_inventory_loaded` | `inventory_state=empty\|non_empty` | Project availability or onboarding friction |
| `session_activity_viewed` | `activity_state=empty\|non_empty` | Visible meaningful monitoring; non-empty only qualifies as activity |
| `session_message_sent` | `submission_kind=text\|command`, `input_mode=typed\|voice_assisted` | Existing-session full activation/control activity |
| `session_created_with_message` | `submission_kind`, `input_mode`, `workspace_kind=project\|dedicated_worktree` | Remote-created-session full activation |
| `session_creation_failed` | `failure_reason=not_authenticated\|server_rejected\|network_down\|bad_response\|unknown`, `workspace_kind` | Bounded creation friction only |
| `voice_transcription_completed` | None | Content-free voice adoption |
| `session_question_answered` | None | Successful intervention |
| `session_question_rejected` | None | Successful intervention |
| `session_permission_answered` | `decision=once\|always\|reject` | Successful intervention |
| `session_abort_succeeded` | None | Successful intervention |
| `session_diff_viewed` | `change_state=empty\|non_empty` | Non-empty diff adoption; empty is diagnostic |
| `onboarding_need_help_opened` | `surface=connect_setup\|connected_empty\|bridge_offline` | Confirmed onboarding interaction |
| `onboarding_support_link_opened` | `channel=email\|discord\|x`, `surface` | Confirmed external-link handoff |
| `onboarding_why_bridge_opened` | `surface` | Onboarding information use |
| `bridge_install_command_copied` | `method=curl\|powershell\|npm\|bun`, `os=unix\|windows`, `surface` | Confirmed copy outcome |
| `bridge_install_command_shared` | `method`, `os`, `surface` | Confirmed share outcome |
| `bridge_run_command_copied` | `surface` | Confirmed copy outcome |
| `bridge_run_command_shared` | `surface` | Confirmed share outcome |
| `product_screen_viewed` | `screen=login\|projects\|settings\|settings_notifications\|settings_profile\|sessions\|new_session\|session_detail\|session_diffs` | Canonical account-linked screen reporting; never meaningful activity |

The account-less allowlist is separate:

| Event | Allowed parameters | Limitation |
| --- | --- | --- |
| `login_attempt_started` | `provider=github\|google\|apple\|email` | Attempt denominator, not a person/account count |
| `login_attempt_completed` | `provider` | Attempt completion, not account creation |
| `login_attempt_failed` | `provider`, `failure_kind=authentication\|launch\|cancelled\|timeout\|unknown` | Bounded failure diagnostic |

These login rows have no `user_key` or attempt ID. They cannot be reliably
internal-filtered without creating the forbidden account-installation mapping,
so they stay out of account funnels, retention, and investor headlines.

## Least-privilege identity matrix

Use separate identities even if one person administers several roles. Project
roles grant job execution only where needed; dataset/table ACLs grant data
access. No runtime receives a downloadable service-account key.

| Identity | Minimum permitted access | Explicitly denied |
| --- | --- | --- |
| `<ANALYTICS_SECURITY_ADMIN_GROUP>` | Administer approved analytics datasets, IAM reviews, raw/privacy incident access | Routine dashboard use as a reason for raw access |
| `<DEPLOYMENT_SERVICE_ACCOUNT>` | BigQuery Job User; create/update derived schemas, approved controls, authorized views, IAM, and transfer configs; act-as only approved schedule identities | Runtime Mongo secret; GA event identifiers; routine dashboard credentials |
| `<AUTH_EXPORT_SERVICE_ACCOUNT>` | BigQuery Job User; Data Editor on `sesori_analytics_auth_private`; table-level read of the authorized internal-exclusion view; managed Mongo/HMAC secrets | Controls write/DDL; privacy-private, raw, curated, or reporting access; project-wide data roles |
| `<TRANSFORM_SERVICE_ACCOUNT>` | BigQuery Job User; Data Viewer on raw, auth-private, and controls; Data Editor on curated; table-scoped Data Editor on `keyed_publication_guard`; run only declared schedules | Privacy-private; reporting writes; Mongo; GA Admin mutation; IAM or any other control-table mutation |
| `<AUTH_SUPPRESSION_SERVICE_ACCOUNT>` | BigQuery Job User; Mongo suppression operation; table-scoped query/MERGE and status read on `product_analytics_deletion_targets` only; managed HMAC/Mongo secrets | Dataset-wide privacy access; auth export tables, controls, raw, curated, reporting, and GA Admin API |
| `<PRIVACY_DELETION_SERVICE_ACCOUNT>` | BigQuery Job User; read privacy targets/raw; write deletion exclusions/status, the sweep checkpoint, and `keyed_publication_guard`; delete affected raw/auth-private/curated keyed rows; rebuild the fixed curated aggregate chain; metadata-only inventory access on reporting; Analytics Admin `analytics.edit` only for deletion submission | Reporting data mutation; Mongo; deployment/IAM administration; any other control mutation; Looker ownership; general GA property administration |
| `<LOOKER_SERVICE_ACCOUNT>` | BigQuery Job User and Data Viewer on `sesori_analytics_reporting` only | Raw, auth-private, privacy-private, controls, curated, `user_key`, and write access |
| `<DASHBOARD_VIEWER_GROUP>` | View the restricted Looker report through approved data-source credentials | Direct BigQuery access, data-source editing/reuse, public/link sharing |
| Auth web runtime | Existing web preference service and managed HMAC secret | Every BigQuery role and every warehouse/deletion class |

Before rollout, test both positive and negative access paths. A successful
expected-deny query is a release blocker.

## Blocked IAM and API application procedure

**This entire procedure remains blocked. Do not run any command in this section
until every identity placeholder and the deployment change are approved.** The
commands are retained as an exact keyless application procedure; they are not
evidence that any grant or API is currently present.

After approval, run as the named deployment operator, confirm the active Cloud
SDK identity and project again, and enable only the required APIs if an approved
preflight proves one is disabled:

```bash
gcloud services enable \
  bigquery.googleapis.com \
  bigquerydatatransfer.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  --project=sesori-ai
```

Apply the dataset/table roles from the least-privilege matrix individually; do
not substitute project-wide BigQuery data roles. After `00_datasets.sql` and
`50_reporting_views.sql` have created the views, add each view to every source
dataset it reads. Merely granting Looker access to the reporting dataset is not
enough: without these authorized-view ACL entries, a reporting-only identity
cannot query the views, while granting it the source datasets would break the
privacy boundary.

Use the etag-protected REST procedure below. It preserves every existing ACL
entry and keeps the bearer token in a mode-600 curl config rather than a command
argument. The controls self-authorization is for the auth-export exclusion
view; the remaining entries authorize the identifier-free reporting views over
their exact auth, controls, and curated sources:

```bash
umask 077
BQ_TOKEN_FILE="$(mktemp)"
BQ_CURL_CONFIG="$(mktemp)"
ACL_FILE="$(mktemp)"
PATCH_FILE="$(mktemp)"
gcloud auth print-access-token >"${BQ_TOKEN_FILE}"
{
  printf '%s\n' 'fail' 'silent' 'show-error'
  printf 'header = "Authorization: Bearer '
  tr -d '\r\n' <"${BQ_TOKEN_FILE}"
  printf '"\n'
} >"${BQ_CURL_CONFIG}"
rm -f "${BQ_TOKEN_FILE}"

authorize_views() {
  SOURCE_DATASET="$1"
  VIEW_DATASET="$2"
  VIEW_NAMES_JSON="$3"

  curl --config "${BQ_CURL_CONFIG}" \
    "https://bigquery.googleapis.com/bigquery/v2/projects/sesori-ai/datasets/${SOURCE_DATASET}?datasetView=ACL" \
    >"${ACL_FILE}"

  jq --arg project "sesori-ai" \
    --arg view_dataset "${VIEW_DATASET}" \
    --argjson views "${VIEW_NAMES_JSON}" '
      (.access // []) as $access
      | {access: reduce $views[] as $view ($access;
          if any(.[]?;
            .view.projectId == $project
            and .view.datasetId == $view_dataset
            and .view.tableId == $view)
          then .
          else . + [{view: {
            projectId: $project,
            datasetId: $view_dataset,
            tableId: $view
          }}]
          end
        )}
    ' "${ACL_FILE}" >"${PATCH_FILE}"

  ETAG="$(jq -r '.etag // empty' "${ACL_FILE}")"
  test -n "${ETAG}"
  curl --config "${BQ_CURL_CONFIG}" --request PATCH \
    --header "Content-Type: application/json" \
    --header "If-Match: ${ETAG}" \
    --data-binary "@${PATCH_FILE}" \
    "https://bigquery.googleapis.com/bigquery/v2/projects/sesori-ai/datasets/${SOURCE_DATASET}?updateMode=UPDATE_ACL"
}

authorize_views \
  sesori_analytics_controls \
  sesori_analytics_controls \
  '["auth_permanent_internal_exclusions"]'
authorize_views \
  sesori_analytics_auth_private \
  sesori_analytics_reporting \
  '["data_quality"]'
authorize_views \
  sesori_analytics_controls \
  sesori_analytics_reporting \
  '["data_quality"]'
authorize_views \
  sesori_analytics_curated \
  sesori_analytics_reporting \
  '["weekly_kpis","investor_snapshot","activation_funnel","retention","feature_adoption","installation_login_funnel","screen_usage","onboarding_friction","data_quality"]'

rm -f "${BQ_CURL_CONFIG}" "${ACL_FILE}" "${PATCH_FILE}"
unset BQ_TOKEN_FILE BQ_CURL_CONFIG ACL_FILE PATCH_FILE ETAG
unset SOURCE_DATASET VIEW_DATASET VIEW_NAMES_JSON
unset -f authorize_views
```

Fetch every source dataset ACL again and verify those exact view entries exist,
no other reporting view was authorized, and no Looker principal gained direct
source-dataset access. Any later reporting view that reads a private source
requires a reviewed ACL update; reporting-dataset membership is never a blanket
authorization for future views.

Then grant the auth-export identity table-level read on only that view. Grant
the transform and privacy-deletion identities table-scoped Data Editor on only
the shared publication guard; dataset-wide controls write remains forbidden.
Finally, grant the deployment identity service-account act-as on only the
approved transform identity. `roles/iam.serviceAccountUser` supplies
`iam.serviceAccounts.actAs`; do not replace it with project-wide Service Account
User or Token Creator:

```bash
bq --project_id=sesori-ai add-iam-policy-binding \
  --member="serviceAccount:<AUTH_EXPORT_SERVICE_ACCOUNT>" \
  --role="roles/bigquery.dataViewer" \
  "sesori-ai:sesori_analytics_controls.auth_permanent_internal_exclusions"

bq --project_id=sesori-ai add-iam-policy-binding \
  --member="serviceAccount:<TRANSFORM_SERVICE_ACCOUNT>" \
  --role="roles/bigquery.dataEditor" \
  "sesori-ai:sesori_analytics_controls.keyed_publication_guard"

bq --project_id=sesori-ai add-iam-policy-binding \
  --member="serviceAccount:<PRIVACY_DELETION_SERVICE_ACCOUNT>" \
  --role="roles/bigquery.dataEditor" \
  "sesori-ai:sesori_analytics_controls.keyed_publication_guard"

gcloud iam service-accounts add-iam-policy-binding \
  "<TRANSFORM_SERVICE_ACCOUNT>" \
  --project=sesori-ai \
  --member="serviceAccount:<DEPLOYMENT_SERVICE_ACCOUNT>" \
  --role="roles/iam.serviceAccountUser"
```

Verify effective act-as without creating a transfer config. Before the binding,
the response `permissions` array must be empty; after the binding, it must
contain exactly `iam.serviceAccounts.actAs`. The verifier needs separately
approved, resource-scoped impersonation permission on the deployment identity
for this check:

```bash
umask 077
DEPLOYMENT_TOKEN_FILE="$(mktemp)"
DEPLOYMENT_CURL_CONFIG="$(mktemp)"
gcloud auth print-access-token \
  --impersonate-service-account="<DEPLOYMENT_SERVICE_ACCOUNT>" \
  >"${DEPLOYMENT_TOKEN_FILE}"
{
  printf '%s\n' 'fail' 'silent' 'show-error'
  printf 'header = "Authorization: Bearer '
  tr -d '\r\n' <"${DEPLOYMENT_TOKEN_FILE}"
  printf '"\n'
} >"${DEPLOYMENT_CURL_CONFIG}"
rm -f "${DEPLOYMENT_TOKEN_FILE}"

curl --config "${DEPLOYMENT_CURL_CONFIG}" --request POST \
  --header "Content-Type: application/json" \
  --data '{"permissions":["iam.serviceAccounts.actAs"]}' \
  "https://iam.googleapis.com/v1/projects/-/serviceAccounts/<TRANSFORM_SERVICE_ACCOUNT>:testIamPermissions"

rm -f "${DEPLOYMENT_CURL_CONFIG}"
unset DEPLOYMENT_TOKEN_FILE DEPLOYMENT_CURL_CONFIG
```

Before the grants, both auth-export probes below must be denied. After the
grants, only the view query may succeed; the underlying-table query must still
return `Access Denied`. Run these as the approved verifier with narrowly scoped,
time-bounded impersonation permission on the identity under test:

```bash
CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="<AUTH_EXPORT_SERVICE_ACCOUNT>" \
  bq query --project_id=sesori-ai --location=europe-west3 \
    --use_legacy_sql=false \
    'SELECT user_key, is_active, control_updated_at FROM `sesori-ai.sesori_analytics_controls.auth_permanent_internal_exclusions` LIMIT 0'

CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="<AUTH_EXPORT_SERVICE_ACCOUNT>" \
  bq query --project_id=sesori-ai --location=europe-west3 \
    --use_legacy_sql=false \
    'SELECT 1 FROM `sesori-ai.sesori_analytics_controls.permanent_internal_user_exclusions` LIMIT 0'
```

Confirm the transform service-account policy contains exactly the approved
deployment principal under `roles/iam.serviceAccountUser` and no unintended
Token Creator grant. After schedule application, confirm each transfer config
runs as `<TRANSFORM_SERVICE_ACCOUNT>`, then require expected-deny probes against
privacy-private data, every other controls mutation, and IAM mutation to fail
under that identity. Any
unexpected success blocks rollout; remove the excess grant rather than
broadening the matrix.

## Authorized internal-exclusion view

The auth export must receive exactly one fully qualified view:
`sesori-ai.sesori_analytics_controls.auth_permanent_internal_exclusions`.
Grant access to the view, not the controls dataset or underlying table.

The view contract is exactly:

| Column | Type | Rule |
| --- | --- | --- |
| `user_key` | nullable `STRING` | Active rows are unique lowercase 64-character HMAC hex values; the null row is the freshness sentinel |
| `is_active` | non-null `BOOL` | `true` for active permanent exclusions; `false` for the null-key sentinel |
| `control_updated_at` | non-null `TIMESTAMP` | One common control version/update time across every returned row |

The view must return one null-`user_key` sentinel even when no internal account
is listed. Missing, stale, malformed, duplicate, mixed-version, or oversized
output aborts auth publication; the export must never fall back to an empty set.
The default maximum age is 48 hours, the default maximum active set is 10,000,
and the runtime hard maximums remain 30 days and 100,000 respectively.

The control owner must review the permanent set and advance the common
`control_updated_at` through the protected control procedure at least once
inside every 48-hour window, including when the set is unchanged. Do not update
the timestamp automatically without an actual review; a stale sentinel is
supposed to stop auth publication.

Internal/test exclusions are permanent. Add only a server-derived HMAC
`user_key` through a protected operator flow with an owner and reason. Never
derive the key in SQL, put the raw account ID or key in a ticket, or delete an
exclusion to make historical metrics rise. Every curated rebuild and every
current eligible-user reporting join must continue to exclude it.

## Measurement controls

Store controls in `sesori_analytics_controls` through the deployment identity.
They are immutable measurement boundaries, not dashboard parameters.

### `raw_export_start_at`

Set `<RAW_EXPORT_START_AT_UTC>` only after an operator verifies the first daily
table under the approved raw ACL, 90-day expiration, daily-only link, and GA4
privacy settings. Use the exact recorded UTC verification timestamp. Do not use
`2026-07-25T00:00:00Z`, the `events_20260725` suffix, table creation time, or
the beginning of an app release as a substitute.

### `behavioral_schema_v1_start_at`

Set `<BEHAVIORAL_SCHEMA_V1_START_AT_UTC>` only after the production outcome
release produces `analytics_activation_ready` with
`activation_schema_version=1` in controlled raw export. Foundation-only
`analytics_schema_ready` and account-less login events do not qualify.

Activation/retention eligibility also requires each account to have
activation-capable exposure no later than 24 hours after account creation. The
global timestamp alone never makes a legacy client measurable.

If either timestamp is disputed, stop publication. Do not silently rewrite it;
open an incident, preserve the prior control version/evidence, approve a
correction, rebuild affected outputs, and annotate the reporting interval.

## Deployment CLI

The deploy command renders checked-in identifier placeholders and invokes `bq`
non-interactively with explicit project/location. It does not log in, read key
files, create secrets, insert internal keys, or discover approval values.

Run all commands from the apps-monorepo root. The exact common arguments are:

```text
--project=sesori-ai
--location=europe-west3
--raw-dataset-id=analytics_529377727
--auth-dataset-id=sesori_analytics_auth_private
--privacy-dataset-id=sesori_analytics_privacy_private
--controls-dataset-id=sesori_analytics_controls
--curated-dataset-id=sesori_analytics_curated
--reporting-dataset-id=sesori_analytics_reporting
--raw-export-start-at=<RAW_EXPORT_START_AT_UTC>
--behavioral-schema-v1-start-at=<BEHAVIORAL_SCHEMA_V1_START_AT_UTC>
```

Placeholders are shown literally and are not executable values. Obtain approved
timestamps from the restricted record without committing them if policy keeps
those values private.

### Render and validate only

With no mode flag, the command validates the manifest and renders every numeric
SQL template in memory. It does not invoke `bq` or mutate anything:

The timestamps below are deliberately synthetic and safe only because this is
render-only mode. Never reuse them with `--dry-run` or `--apply`.

```bash
dart tool/product_analytics/deploy.dart \
  --project=sesori-ai \
  --location=europe-west3 \
  --raw-dataset-id=analytics_529377727 \
  --auth-dataset-id=sesori_analytics_auth_private \
  --privacy-dataset-id=sesori_analytics_privacy_private \
  --controls-dataset-id=sesori_analytics_controls \
  --curated-dataset-id=sesori_analytics_curated \
  --reporting-dataset-id=sesori_analytics_reporting \
  --raw-export-start-at="2000-01-01T00:00:00Z" \
  --behavioral-schema-v1-start-at="2000-01-02T00:00:00Z"
```

### BigQuery dry-run

This command validates arguments, renders every SQL asset, and submits BigQuery
whole-script dry runs. The tool requests JSON from `bq`, parses it, and prints
only `totalBytesProcessed` plus `totalBytesProcessedAccuracy` from that backend
response for each asset. It must not mutate datasets, tables, views, or
schedules:

```bash
dart tool/product_analytics/deploy.dart \
  --project=sesori-ai \
  --location=europe-west3 \
  --raw-dataset-id=analytics_529377727 \
  --auth-dataset-id=sesori_analytics_auth_private \
  --privacy-dataset-id=sesori_analytics_privacy_private \
  --controls-dataset-id=sesori_analytics_controls \
  --curated-dataset-id=sesori_analytics_curated \
  --reporting-dataset-id=sesori_analytics_reporting \
  --raw-export-start-at="<RAW_EXPORT_START_AT_UTC>" \
  --behavioral-schema-v1-start-at="<BEHAVIORAL_SCHEMA_V1_START_AT_UTC>" \
  --dry-run
```

BigQuery SCRIPT estimates are best-effort. Accuracy can be `PRECISE`,
`LOWER_BOUND`, `UPPER_BOUND`, or `UNKNOWN`; a `LOWER_BOUND` can be materially
below actual billed bytes and is not evidence that a query fits its allocation.
If BigQuery omits the estimate, the tool prints `totalBytesProcessed=unavailable`
and `accuracy=UNKNOWN` rather than inferring precision.
For a multi-statement DDL asset, BigQuery dry-run validation stops after the
first DDL statement. The CLI reports this limitation explicitly; dry-run is not
proof that every schema object is valid. The deployed-schema assertions below
remain mandatory after apply.
Review the estimate and accuracy against both the manifest allocation and the 2
GiB principal/10 GiB project daily quotas, then verify actual production job
bytes before enabling schedules. Dry-run success does not prove a cost ceiling,
IAM deny boundaries, source freshness, or metric correctness. If `bq` fails or
returns malformed output, the tool reports only a bounded operation error and
suppresses backend details.

### Bootstrap schemas, then publish auth

On a new warehouse, create only the datasets and reference schemas first:

```bash
dart tool/product_analytics/deploy.dart \
  --project=sesori-ai \
  --location=europe-west3 \
  --raw-dataset-id=analytics_529377727 \
  --auth-dataset-id=sesori_analytics_auth_private \
  --privacy-dataset-id=sesori_analytics_privacy_private \
  --controls-dataset-id=sesori_analytics_controls \
  --curated-dataset-id=sesori_analytics_curated \
  --reporting-dataset-id=sesori_analytics_reporting \
  --raw-export-start-at="<RAW_EXPORT_START_AT_UTC>" \
  --behavioral-schema-v1-start-at="<BEHAVIORAL_SCHEMA_V1_START_AT_UTC>" \
  --bootstrap
```

Next run and validate the initial auth export described below. Do not run
auth-dependent transforms before that snapshot exists.

### Apply schemas and transforms without schedules

Only after the deployment block is cleared, pass the explicit mutating
`--apply` mode without `--apply-schedules`. The command fails before applying
any asset when `product_analytics_export_runs` has no initial snapshot:

```bash
dart tool/product_analytics/deploy.dart \
  --project=sesori-ai \
  --location=europe-west3 \
  --raw-dataset-id=analytics_529377727 \
  --auth-dataset-id=sesori_analytics_auth_private \
  --privacy-dataset-id=sesori_analytics_privacy_private \
  --controls-dataset-id=sesori_analytics_controls \
  --curated-dataset-id=sesori_analytics_curated \
  --reporting-dataset-id=sesori_analytics_reporting \
  --raw-export-start-at="<RAW_EXPORT_START_AT_UTC>" \
  --behavioral-schema-v1-start-at="<BEHAVIORAL_SCHEMA_V1_START_AT_UTC>" \
  --apply
```

Apply order is fixed: datasets/reference schemas, flattened events, account-less
login aggregates, daily activity, milestones/cohorts, then reporting views. A
failure stops the run; do not skip ahead or point Looker at partial objects.
Every direct apply job uses that asset's manifest/deployment
`maximum_bytes_billed`; scheduled-query runs cannot use this job setting.

### Run fixture and schema assertions

The deployment CLI intentionally operates only on numeric assets under `sql/`;
it has no assertion mode. Run the self-contained metric fixture directly. The
schema assertion intentionally contains dataset placeholders, so render only
the six allowlisted identifiers into the `bq` stdin stream; do not create an
operator-edited SQL copy:

```bash
bq --headless=true --quiet=true \
  --project_id=sesori-ai \
  --location=europe-west3 \
  query --use_legacy_sql=false --maximum_bytes_billed=1073741824 \
  < tool/product_analytics/tests/metric_contract_assertions.sql

perl -pe '
  s/\{\{PROJECT_ID\}\}/sesori-ai/g;
  s/\{\{AUTH_DATASET_ID\}\}/sesori_analytics_auth_private/g;
  s/\{\{PRIVACY_DATASET_ID\}\}/sesori_analytics_privacy_private/g;
  s/\{\{CONTROLS_DATASET_ID\}\}/sesori_analytics_controls/g;
  s/\{\{CURATED_DATASET_ID\}\}/sesori_analytics_curated/g;
  s/\{\{REPORTING_DATASET_ID\}\}/sesori_analytics_reporting/g;
' tool/product_analytics/tests/schema_allowlist_assertions.sql \
  | bq --headless=true --quiet=true \
      --project_id=sesori-ai \
      --location=europe-west3 \
      query --use_legacy_sql=false --maximum_bytes_billed=1073741824
```

Require both `metric_contract_assertions.sql` and
`schema_allowlist_assertions.sql` to pass. Assertions cover activation success
versus queued/failed attempts, ordered account-to-bridge-to-project-to-message
progression, timely activation capability, cohort maturity, W1/W4 boundaries,
occurrence time, internal/disabled/deleted exclusion, the keyed publication
guard, monitoring deduplication, voice classification, account-less login
isolation, custom-screen-only reporting, stale auth snapshots, and late-event
replacement.

### Apply schedules

Schedules are a separate deliberate phase. First complete one manual auth
export and one manual transform chain. Then create/update only the transfer
configs declared in `sql/schedules.json`:

```bash
dart tool/product_analytics/deploy.dart \
  --project=sesori-ai \
  --location=europe-west3 \
  --raw-dataset-id=analytics_529377727 \
  --auth-dataset-id=sesori_analytics_auth_private \
  --privacy-dataset-id=sesori_analytics_privacy_private \
  --controls-dataset-id=sesori_analytics_controls \
  --curated-dataset-id=sesori_analytics_curated \
  --reporting-dataset-id=sesori_analytics_reporting \
  --raw-export-start-at="<RAW_EXPORT_START_AT_UTC>" \
  --behavioral-schema-v1-start-at="<BEHAVIORAL_SCHEMA_V1_START_AT_UTC>" \
  --transform-service-account="<TRANSFORM_SERVICE_ACCOUNT>" \
  --apply \
  --apply-schedules
```

`--apply-schedules` is invalid unless both `--apply` and
`--transform-service-account` are supplied. The current manifest is:

| Display name | UTC cadence | Query | Recent dates | Daily allocation/direct-apply maximum |
| --- | --- | --- | --- | --- |
| `Sesori Product Analytics - 10 Events Flattened` | Daily 04:00 | `10_events_flattened.sql` | 3 | 512 MiB |
| `Sesori Product Analytics - 15 Installation Login Daily` | Daily 04:15 | `15_installation_login_daily.sql` | 3 | 256 MiB |
| `Sesori Product Analytics - 20 User Activity Daily` | Daily 04:30 | `20_user_activity_daily.sql` | 3 | 256 MiB |
| `Sesori Product Analytics - 30 User Milestones` | Daily 04:45 | `30_user_milestones.sql` | 3 | 256 MiB |
| `Sesori Product Analytics - 40 Activation Retention` | Daily 05:00 | `40_activation_retention.sql` | 3 | 512 MiB |

The manifest is the source of truth for query file, cadence, recent-date
recomputation, display name, and byte allocation. Validation rejects any one
schedule above 512 MiB or a cumulative allocation above 1.75 GiB
(1,879,048,192 bytes). The listed allocations total exactly 1.75 GiB, leaving
256 MiB of headroom below the transform principal's 2 GiB daily quota.
Scheduled-query transfer configs do not support a runtime
`maximum_bytes_billed`; project/principal query quotas remain the runtime
enforcement. Do not apply schedules unless measured production bytes fit both
quotas. Do not create console-only schedules or use a human owner. Record
transfer-config IDs in the restricted deployment record.

Transfer configs are independent schedules, not one orchestrated chain. The
15-minute spacing is normal sequencing only; delayed, retried, or manually
started runs can overlap. The SQL scripts therefore enforce same-run auth and
upstream watermark guards before publication, and each write is transactional
or idempotent. Do not weaken those guards or assume schedule timing provides
mutual exclusion.

Keyed transforms and permanent deletion tombstones also advance the shared
`keyed_publication_guard` singleton inside their transactions. Every transform
captures the epoch before staging and fails if it changes, while an overlapping
tombstone/publication causes a transaction conflict. This prevents a staged
aggregate from republishing a user whose tombstone arrived concurrently.

Before creating or updating any transfer config, `--apply-schedules` lists
scheduled-query configs in the location. If any display name beginning with
`Sesori Product Analytics - ` is absent from `sql/schedules.json`, the tool
fails before the first schedule write. It never auto-deletes an obsolete
config; review, disable, and remove it only through a separately approved
operation, then rerun deployment.

## Auth export

The auth export is a one-shot command in `sesori_auth_server`; it is not an HTTP
handler and the auth web process must never construct BigQuery clients.
Run source-tree commands in the `sesori_auth_server` repository root, not the
apps-monorepo root.

### Runtime environment

Configure these non-secret values on the isolated job:

```text
PRODUCT_ANALYTICS_GCP_PROJECT_ID=sesori-ai
PRODUCT_ANALYTICS_AUTH_DATASET_ID=sesori_analytics_auth_private
PRODUCT_ANALYTICS_INTERNAL_EXCLUSION_VIEW=sesori-ai.sesori_analytics_controls.auth_permanent_internal_exclusions
PRODUCT_ANALYTICS_BIGQUERY_LOCATION=europe-west3
PRODUCT_ANALYTICS_EXPORT_BATCH_LIMIT=500
PRODUCT_ANALYTICS_INTERNAL_EXCLUSION_MAX_KEYS=10000
PRODUCT_ANALYTICS_INTERNAL_EXCLUSION_MAX_AGE_MS=172800000
```

Inject `MONGODB_URI` and `PRODUCT_ANALYTICS_PSEUDONYMIZATION_KEY` from managed
secrets. Never print, export into a checked-in env file, or manually retype the
key. The web, export, and suppression runtimes use the same long-lived canonical
base64 HMAC key. Rotation requires a coordinated re-key migration and is not an
incident-response shortcut.

The exact production image command is:

```bash
node dist/scripts/export-product-analytics.js
```

The source-tree equivalent for an approved non-production/manual run is:

```bash
npm run export-product-analytics
```

Both use ADC. Do not set `GOOGLE_APPLICATION_CREDENTIALS` to a downloaded key.

### Scheduling

Create a daily Cloud Run Job or equivalently isolated scheduler at
`<AUTH_EXPORT_SCHEDULE_UTC>`. It must securely reach MongoDB, run as
`<AUTH_EXPORT_SERVICE_ACCOUNT>`, use the same built image with the command
override above, disallow overlapping executions, and remain independent of auth
HTTP availability. If GCP cannot securely reach MongoDB, use an isolated job on
the existing host rather than adding export work to the web process.

Choose `<AUTH_EXPORT_SCHEDULE_UTC>` so a healthy export completes before the
04:30 UTC user-level transform. The raw-only 04:00/04:15 transforms may run
independently, but user-level publication must still assert a reconciled auth
snapshot no older than 36 hours.

Before enabling the schedule:

- provision permanent auth-private schemas with the deployment identity;
- grant only the IAM in the matrix;
- authorize only the internal-exclusion view;
- run one manual export with a fixed cutoff;
- verify source, exclusion, enabled, staging, and published counts reconcile;
- verify an equal/older or overlapping cutoff cannot publish; and
- verify a failed run leaves the prior snapshot and cohorts intact.

The run stages pseudonymous/aggregate rows, reloads the internal controls before
promotion, reconciles current preference changes, and atomically publishes both
auth products plus metadata. It never exports OAuth/provider identity, email,
username, raw account ID, bridge/device identifiers, or reminder timestamps.

## Freshness and recovery

### Expected freshness

| Layer | Healthy condition |
| --- | --- |
| Raw GA4 | A daily table arrives; latest three UTC event dates remain mutable for late events |
| Auth export | Latest successful reconciled snapshot completed no more than 36 hours ago |
| Flattened/login | Latest three UTC event dates recomputed successfully within the declared schedule |
| User-level models | Built only from a fresh reconciled auth snapshot and current exclusions |
| Reporting | Watermark reaches the last complete eligible period and `data_quality` reports fresh |
| Looker | Every page displays raw/auth/reporting as-of values and stale state explicitly |

An absent event can mean zero usage, delayed GA export, stale auth, failed
transform, exclusion, unsupported client coverage, or an immature cohort. Never
interpret it as product decline until `data_quality` distinguishes those cases.

### Stale auth snapshot

If the latest auth snapshot is missing, partial, unreconciled, or older than 36
hours, user-level transforms must fail before mutation. Keep the last known-good
reporting tables visible with stale status. `events_flattened` and
`installation_login_daily` may continue ingesting recoverable raw facts; do not
publish an empty user day.

Recover in this order:

1. Pause dependent user-level schedules, not privacy sweeps.
2. Correct Mongo connectivity, authorized-view freshness, IAM, quota, or job
   failure without broadening access.
3. Run the auth export and require a newer reconciled `run_cutoff`.
4. Recompute user-level data from the first UTC date after the last successfully
   published reporting watermark through the latest three mutable event dates.
5. Keep the range within the 90-day raw recovery window and dry-run byte cost.
6. Run assertions and three-day reconciliation before advancing freshness.
7. Resume schedules and annotate the incident interval.

If the missing range has expired from raw storage, do not fabricate or copy
forward behavioral facts. Publish an explicit measurement gap.

### Late arrivals

Every daily event transform recomputes at least the latest three UTC event dates
and replaces idempotently. Recovery additionally covers any watermark gap. A
late keyed event for a permanently deleted account is anti-joined on rebuild and
is also covered by the overlapping privacy sweep.

## Cost controls

Every scheduled query declares a conservative byte allocation in
`sql/schedules.json`: no query may exceed 512 MiB and the daily sum may not
exceed 1.75 GiB. Direct apply uses each value as `maximum_bytes_billed`.
Scheduled runs have no per-job maximum setting, so the 2 GiB transform-principal
quota is the runtime backstop. Review dry-run estimate values and accuracy
before apply and actual job bytes after material changes. A SCRIPT
`LOWER_BOUND` estimate is not a ceiling. Partition filters must be mandatory;
materialize repeated daily/intermediate work instead of letting Looker scan raw
events.

Operational limits are:

- 10 GiB of on-demand query bytes per project per day;
- 2 GiB of on-demand query bytes per principal per day;
- USD 10 monthly all-services project alert budget;
- actual-spend alerts at 50%, 80%, and 100%; and
- forecast-spend alert at 100%.

The budget is not an enforcement cap. Alert delivery can lag, all GCP services
contribute to it, and BigQuery storage/streaming/non-query costs are not stopped
by query quotas. Conversely, a quota failure can make reports stale before the
budget alerts. At 50%, inspect billing by service/SKU and query job bytes. At
80%, pause nonessential ad hoc/dashboard refreshes and investigate. At 100% or
forecast 100%, pause non-privacy schedules if needed; never pause source
suppression, deletion exclusion, or required deletion sweeps merely to save
cost. Raising budget/quota values requires explicit approval.

Perform a monthly cost review even when no alert fires. Record actual spend,
forecast, bytes by scheduled identity, Looker bytes, failed quota jobs, and any
approved change in the restricted operations record.

## Privacy deletion

Privacy deletion is an isolated, idempotent source-to-warehouse flow. It is not
an ad hoc console query and not a public route.

The required repository preflight for any privacy-job change is:

```bash
dart tool/product_analytics/privacy_deletion/privacy_deletion_test.dart
```

### 1. Source suppression and handoff

After independently verifying the requester and external request ID, run the
auth-server suppression command under its dedicated identity. Start the command
without putting request content in argv or shell history, then provide the
bounded JSON through protected stdin. Run the source command from the
`sesori_auth_server` repository root:

```bash
npm run suppress-product-analytics-export
```

The production image command is:

```bash
node dist/scripts/suppress-product-analytics-export.js
```

Protected stdin has this shape; values shown are placeholders and must not be
copied into this repository:

```json
{"userId":"<VERIFIED_MONGO_ACCOUNT_ID>","requestId":"<EXTERNAL_PRIVACY_REQUEST_ID>"}
```

The command atomically disables analytics and writes the permanent source
tombstone before handing only the HMAC key, deletion-only legacy Firebase user
ID, tombstone time, external request ID, and status to privacy-private. Output
contains request ID/status only. A handoff failure leaves source suppression in
place and is safely retryable.

### 2. Warehouse deletion

Run the layered warehouse command by external request ID under
`<PRIVACY_DELETION_SERVICE_ACCOUNT>`:

These Dart privacy jobs call the BigQuery and Analytics Admin REST APIs with
the attached runtime identity from the GCP metadata server. They do not use the
active Cloud SDK credential that `bq` uses. Production and scheduled jobs are
metadata-only and fail if that identity is unavailable. An approved local
operator run may explicitly add `--allow-gcloud-adc-fallback` to use
`gcloud auth application-default`; fallback is disabled by default and the
aggregate result reports when it was used. Never put that flag on a production
or scheduled job. Leave `GOOGLE_APPLICATION_CREDENTIALS` unset because
downloaded key files and arbitrary credential files are intentionally rejected.

```bash
dart tool/product_analytics/privacy_deletion/run_privacy_deletion.dart \
  --project=sesori-ai \
  --location=europe-west3 \
  --analytics-property-id=529377727 \
  --raw-dataset=analytics_529377727 \
  --auth-dataset=sesori_analytics_auth_private \
  --privacy-dataset=sesori_analytics_privacy_private \
  --controls-dataset=sesori_analytics_controls \
  --curated-dataset=sesori_analytics_curated \
  --reporting-dataset=sesori_analytics_reporting \
  --exclusions-table=permanent_deletion_exclusions \
  --sweep-state-table=product_analytics_privacy_sweep_state \
  --request-id="<EXTERNAL_PRIVACY_REQUEST_ID>"
```

Run the same command with `--dry-run` first. Dry-run performs reads and BigQuery
planning but no mutation, status change, aggregate rebuild execution, or upstream
Analytics Admin API call. The command accepts no operator-selected aggregate
query or executable. For a mutating run it automatically rebuilds the fixed,
checked-in `20_user_activity_daily.sql` -> `30_user_milestones.sql` ->
`40_activation_retention.sql` transform chain in that order.

The command adds and verifies the permanent deletion exclusion first, then
performs one immediate privacy-preserving raw/curated cleanup and rebuild. It
reads auth-export readiness exactly once; it never polls or sleeps inside the
process. If no successful export has `run_cutoff >= suppressed_at`, or its
source cutoff/publication is stale or future-dated under the warehouse
freshness policy, the command records a bounded retryable outcome and exits. The
approved external job or operator must run the auth export and invoke the same
idempotent deletion command again. The preliminary pass deliberately does not
mutate auth-private publication while an older export may still own that
snapshot. Once a later invocation observes the qualifying export, the final
pass deletes the key from
auth-private and curated keyed tables, repeats the fixed rebuild, verifies
keyed/raw absence and post-request transform state, and only then marks the
request complete. Do not declare warehouse completion before both the
tombstone-aware export and final cleanup succeed.

Before either request cleanup or a recurring sweep, the job compares the
deployed auth/curated/reporting `user_key` column inventory with its checked-in
closed table inventory. It also rejects intraday raw export, unsupported
`events_*` names, or a gap in the controlled retained daily-table sequence.
Those checks are fail-closed: update the reviewed code and IAM contract when the
warehouse schema intentionally changes; never bypass coverage with command-line
table lists or a shorter retention window. Preliminary cleanup may observe an
active, validated auth milestone staging table, but final cleanup, completion,
and recurring sweep checkpoints fail closed until every such staging table has
expired or the owning export has removed it; no auth-private keyed staging row
is silently left outside deletion verification.

### 3. Current GA deletion submission

Use the current Google Analytics Admin API v1alpha
`properties.submitUserDeletion` method. The legacy Google Analytics User
Deletion API v3 `userDeletionRequests:upsert` endpoint is sunset and must not be
called.

The current endpoint is:

```text
POST https://analyticsadmin.googleapis.com/v1alpha/properties/529377727:submitUserDeletion
```

The deletion identity requires the narrow
`https://www.googleapis.com/auth/analytics.edit` OAuth scope. For each currently
linkable installation discovered inside the restricted 90-day raw window, send
exactly one union field:

```json
{"appInstanceId":"<DISCOVERED_APP_INSTANCE_ID>"}
```

For data created by legacy releases that set Firebase global `user_id`, submit
the deletion-only prior SHA-256 value as:

```json
{"userId":"<DELETION_ONLY_LEGACY_FIREBASE_USER_ID>"}
```

Never submit the new HMAC `user_key` as `userId`; it was not the historical GA
global user ID. Never send both union fields in one request. Do not persist or
log discovered app-instance IDs. Record only the external privacy request ID,
aggregate submission status, and returned `deletionRequestTime` in restricted
status.

### 4. Recurring keyed-upload sweep

Run the checkpointed command daily at `<PRIVACY_SWEEP_SCHEDULE_UTC>`:

```bash
dart tool/product_analytics/privacy_deletion/sweep_privacy_deletions.dart \
  --project=sesori-ai \
  --location=europe-west3 \
  --analytics-property-id=529377727 \
  --raw-dataset=analytics_529377727 \
  --auth-dataset=sesori_analytics_auth_private \
  --privacy-dataset=sesori_analytics_privacy_private \
  --controls-dataset=sesori_analytics_controls \
  --curated-dataset=sesori_analytics_curated \
  --reporting-dataset=sesori_analytics_reporting \
  --exclusions-table=permanent_deletion_exclusions \
  --sweep-state-table=product_analytics_privacy_sweep_state
```

Each sweep starts from the earlier of the watermark continuation and the latest
three UTC event dates, scans every permanent tombstone regardless of request
age/status, deletes newly landed keyed rows, and resubmits newly discovered app
instances through `submitUserDeletion`. It persists no account-install mapping
and automatically uses the same fixed checked-in 20 -> 30 -> 40 rebuild chain;
there is no operator-supplied rebuild path or command.
Before any auth-private cleanup or checkpoint advancement, the sweep requires a
fresh successful auth export whose cutoff covers the newest tombstone. A stale
or pre-tombstone export produces a bounded retryable result without cleanup or
checkpoint advancement.

The enforceable promise is source/warehouse suppression plus recurring removal
of future **keyed uploads**. An automatic-only installation that never emitted a
keyed event cannot be linked to an account by design. Its upstream data follows
the verified two-month GA retention, while an already-exported restricted raw
row may remain until the separate 90-day expiration. State both limits in the
request response; never promise indefinite automatic-event deletion.

Before production rollout, complete a non-production drill covering an
in-flight pre-tombstone auth export, final tombstone-aware export, flattened
non-repopulation, aggregate rebuild, a delayed keyed upload into a previously
swept mutable partition, watermark-gap recovery, current Admin API submission,
and expected IAM denials.

## Incidents and rollback

Privacy controls have a forward-fix floor. Permanent internal/deletion
exclusions, source tombstones, and recurring deletion sweeps continue during a
reporting rollback.

| Incident | Immediate response | Recovery/rollback boundary |
| --- | --- | --- |
| Broad raw/private access | Revoke unintended access, pause Looker and non-privacy transforms, preserve evidence | Reapply reviewed ACLs and deny tests before resuming; do not copy data elsewhere |
| Missing raw expiration or intraday table | Stop rollout, restrict access, apply 90-day expiration to every affected table, disable streaming/intraday | Verify all current/default expirations; do not unlink daily export |
| GA privacy setting drift | Stop dashboard/data acceptance and non-privacy schedules | Restore approved settings, record affected interval, assess deletion/disclosure impact |
| Sensitive/unallowlisted field | Pause affected transform/report source, restrict output, open privacy incident | Forward-fix allowlist and delete/rebuild affected outputs; never expose the field for debugging |
| Stale/failed auth export | Keep last-good reports visibly stale; pause dependent user-level transforms | Publish a newer reconciled snapshot and backfill watermark gap within 90 days |
| Incorrect metric/SQL | Pause affected schedules and dashboard charts | Redeploy last known-good SQL/views or corrected version, rebuild, rerun assertions/reconciliation |
| Query quota exhaustion | Pause nonessential/ad hoc work and dashboard refreshes; keep stale label | Resume after quota window/reduced bytes; quota increase requires approval |
| Budget alert | Inspect all-service billing and query jobs; at high severity pause non-privacy schedules | Resume after cause/cost approval; budget itself never shut off spend |
| Deletion failure | Keep source tombstone/exclusion active and mark request retryable | Retry idempotently; never roll back suppression to make export succeed |
| Dashboard oversharing | Revoke report/data-source sharing immediately and audit access | Restore only approved owner/group and repeat manual access tests |
| Wrong measurement timestamp | Stop affected publication and preserve old control/evidence | Approve a versioned correction, rebuild affected range, and annotate the gap/change |

A Step 5 reporting rollback may pause or restore auth export, transforms,
reporting views, and Looker sources to the last known-good version. Raw daily
export and prior good auth tables remain; app behavior is unaffected. Never use
rollback to re-enable a deleted account, remove a permanent exclusion, broaden
IAM, or revert the client privacy gate.

Record incident start/end UTC, affected layers/periods, last good commit and
watermarks, privacy assessment, actions, owner, and reconciliation evidence.
Do not include event payloads, keys, identifiers, paths, or raw error text.

## Release smoke and reconciliation

Use a release build and synthetic content. Do not enable debug-build custom
event sharing for convenience and do not inspect prompts, messages,
transcripts, paths, names, or raw payload text.

### End-to-end smoke

1. Use an approved synthetic smoke account and record its restricted HMAC key
   outside Git/logs.
2. Complete account creation, notification registration if applicable, bridge
   registration, a successful non-empty project inventory, and one successfully
   accepted user-authored message.
3. Confirm `analytics_activation_ready` schema v1, the expected project event,
   and exactly one of `session_message_sent` or
   `session_created_with_message`; queued/failed attempts must not activate.
4. Navigate a pinned route and verify one canonical `product_screen_viewed` plus
   one matching native `screen_view`, with no automatic duplicate. Curated
   account reporting uses only the canonical event.
5. If testing voice, verify only `input_mode=voice_assisted` and the content-free
   transcription completion appear, with no transcript/audio-derived value.
6. Wait for the complete daily raw table; verify allowed names/types/parameters
   and the absence of prohibited fields without viewing content values.
7. Run auth export, transform chain, and reporting views. Verify the account
   joins, full activation uses occurrence time, and the complete-day aggregate
   advances.
8. Add the smoke account to the permanent internal exclusion through the
   protected control flow, rerun auth export/rebuild, and verify it disappears
   from historical/future account reporting. Never remove that exclusion.

The account-less login smoke must separately prove only provider/failure enums,
no `user_key` or attempt ID, and the diagnostic
`includes_internal_test_traffic=true` label. Do not join it to the smoke account.

### Three-complete-day reconciliation

Before sharing Looker, reconcile at least three complete UTC event dates through
this chain:

```text
GA4 allowlisted custom-event aggregate
-> events_flattened / installation_login_daily
-> user_activity_daily and user_milestones
-> cohort/reporting views
-> Looker chart values
```

For each date record aggregate counts only. Require:

- raw-to-flattened differences are explained by duplicate, schema, timing,
  internal, deletion, or allowlist data-quality counts;
- flattened-to-daily event contributions reconcile by bounded event class;
- auth eligible counts reconcile to source totals after internal/suppressed and
  preference filtering;
- full activation is only the earliest successful accepted message outcome;
- meaningful/controller WAU excludes opens, screens, empty states, failures,
  and queued-only actions;
- activation and retention denominators include only mature, timely
  activation-capable cohorts;
- W1 is days 7-13 and W4 is days 28-34 after activation;
- login counts remain installation-attempt diagnostics and out of headlines;
- every page shows numerator, denominator, coverage, maturity, and raw/auth/
  reporting freshness; and
- the Looker values equal reporting-view values under the same complete-period
  filters.

Finally test IAM manually: auth export cannot write controls/curated/reporting;
transforms cannot read privacy-private; Looker cannot query raw/private/curated
or expose `user_key`; ordinary viewers cannot bypass report sharing. Complete
the access checklist in [`LOOKER_STUDIO.md`](LOOKER_STUDIO.md).

Do not claim release completion until the first W1 cohort is mature and
reviewed. W4 requires 35 days after activation; show null and "no mature cohort"
rather than zero when none has completed the full window.
