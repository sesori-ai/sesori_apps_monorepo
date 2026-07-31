# Looker Studio reporting contract

This document pins the manually built, restricted Looker Studio report for
Step 5. The report is not a safely deployable repository artifact. Operators
must build it from this contract, record the asset in the restricted deployment
record, and repeat the verification checklist after every report or data-source
change.

The warehouse remains authoritative. Looker formats and filters aggregate
reporting fields; it does not reconstruct user-level metrics, blend raw sources,
or invent alternate denominators.

## Required restricted fields

These values must remain placeholders in this repository. Fill them in the
restricted deployment record before any report is shared.

| Field | Required value |
| --- | --- |
| Report owner | **REQUIRED TO FILL:** `<DASHBOARD_OWNER>` |
| Authorized viewer group | **REQUIRED TO FILL:** `<DASHBOARD_VIEWER_GROUP>` |
| Looker data-source identity | **REQUIRED TO FILL:** `<LOOKER_SERVICE_ACCOUNT>` |
| Access-review owner | **REQUIRED TO FILL:** `<DASHBOARD_ACCESS_REVIEW_OWNER>` |
| Report URL/asset ID | **REQUIRED TO FILL in restricted record:** `<DASHBOARD_ASSET>` |
| Data-source asset IDs | **REQUIRED TO FILL in restricted record:** `<LOOKER_DATA_SOURCE_ASSETS>` |
| Refresh/cache policy | **REQUIRED TO FILL in restricted record:** `<DASHBOARD_REFRESH_POLICY>` |

**Dashboard sharing is blocked until the report owner and viewer group are
approved.** Never replace these placeholders in Git with personal email
addresses, internal group names, service-account addresses, or asset URLs.

## Report boundary

Create exactly one initial report with exactly these three pages, in this order:

1. **Executive snapshot**
2. **Activation**
3. **Retention and engagement**

Additional feature, acquisition, product-quality, or data-quality pages are
deferred. Do not silently add them to the initial investor report.

All data sources must be reusable BigQuery data sources backed only by
identifier-free objects in
`sesori-ai.sesori_analytics_reporting`. Do not connect Looker to
`analytics_529377727`, auth-private, privacy-private, controls, curated tables,
custom SQL over those datasets, or an extract containing `user_key`.

Use `<LOOKER_SERVICE_ACCOUNT>` or another explicitly approved owner-credential
configuration that has BigQuery Job User plus Data Viewer on
`sesori_analytics_reporting` only. Report viewers must not receive direct
BigQuery access through report membership.

Record `<DASHBOARD_REFRESH_POLICY>` for every reusable data source. Use live
reporting views rather than extracts; cache refresh must follow the completed
warehouse schedules and may never make the displayed freshness label newer than
the source `data_quality` timestamps.

## Reporting-only data sources

Create one reusable source per reporting view. Preserve these source names so
chart audits are unambiguous.

| Looker source name | BigQuery object | Permitted use |
| --- | --- | --- |
| `PA - Investor Snapshot` | `sesori-ai.sesori_analytics_reporting.investor_snapshot` | Independently labeled latest complete account and engagement periods plus latest mature seven-day activation cohort |
| `PA - Weekly KPIs` | `sesori-ai.sesori_analytics_reporting.weekly_kpis` | Complete-week trends and engagement depth |
| `PA - Activation Funnel` | `sesori-ai.sesori_analytics_reporting.activation_funnel` | Mature setup/activation cohorts and timing |
| `PA - Retention` | `sesori-ai.sesori_analytics_reporting.retention` | Mature W1/W4 cohorts |
| `PA - Feature Adoption` | `sesori-ai.sesori_analytics_reporting.feature_adoption` | Bounded feature/voice/control aggregates |
| `PA - Installation Login` | `sesori-ai.sesori_analytics_reporting.installation_login_funnel` | Account-less login attempt diagnostics only |
| `PA - Screen Usage` | `sesori-ai.sesori_analytics_reporting.screen_usage` | Canonical custom screen aggregates |
| `PA - Onboarding Friction` | `sesori-ai.sesori_analytics_reporting.onboarding_friction` | Empty/failure/support/install diagnostics |
| `PA - Data Quality` | `sesori-ai.sesori_analytics_reporting.data_quality` | Freshness, coverage, maturity, and pipeline state |

If a required chart field is absent from the reporting view, change the
versioned warehouse model and assertions. Do not work around it by connecting a
private source, adding a per-user extract, or blending sources in Looker.

## Global semantic contract

### Time and complete periods

- Set report timezone to UTC.
- Weeks begin Monday and end Sunday.
- Default weekly controls to the latest 12 complete Monday-Sunday weeks.
- Default cohort charts to mature cohorts only.
- Default daily diagnostics to dates whose warehouse completion flag is true.
- Never include the current partial week in scorecards, comparisons, exported
  PDFs, or investor screenshots.
- An operator-only `Period mode` control may expose `Complete periods` and
  `Live partial period`; default it to `Complete periods` on every page.
- When live mode is selected, display a persistent "LIVE PARTIAL PERIOD - NOT
  FOR INVESTOR EXPORT" banner and suppress prior-period percentage claims that
  are not like-for-like.

Use source completion/maturity fields. Do not derive completeness from the
viewer browser clock or GA property timezone.

### Rates and formulas

Warehouse-provided metric values are authoritative for latest-row scorecards,
four-week growth, percentiles, and cohort retention. Do not average percentages
or recompute distinct users in Looker.

Where a chart groups reporting rows and therefore must calculate a displayed
rate, the only allowed formula is a ratio of summed source components:

```text
CASE
  WHEN SUM(denominator) = 0 THEN NULL
  ELSE SUM(numerator) / SUM(denominator)
END
```

Give each chart-specific numerator and denominator explicit aliases before
using this formula. Never use `AVG(rate)`, `COUNT_DISTINCT(user_key)`, a blended
denominator, or zero for an absent/immature denominator.

Pin these definitions:

| Metric | Numerator | Denominator/formula |
| --- | --- | --- |
| Weekly new accounts | External, non-deletion-suppressed accounts created in the complete week | Count; ordinary product-analytics opt-out does not reduce this aggregate auth metric |
| 7-day bridge setup conversion | Accounts with first bridge registration within 7 x 24 hours of creation | External accounts in the cohort whose full seven-day window elapsed |
| 7-day full activation conversion | Analytics-eligible accounts with first successful message outcome within 7 x 24 hours of account creation | Accounts at least seven days old, created on/after the behavioral start, and activation-capable within 24 hours; untimely/legacy accounts are unmeasurable, not failures |
| Meaningful WAU | Distinct eligible users with non-empty visible session activity or a confirmed control outcome in the complete week | Count; screens/app opens/empty/failure/queued-only rows do not qualify |
| Controller WAU | Distinct eligible users with a successful message, question/permission action, abort, or session creation with message | Count |
| W1 retention | Activated eligible users with meaningful activity on days 7-13 after activation | Activated users whose complete W1 window elapsed |
| W4 retention | Activated eligible users with meaningful activity on days 28-34 after activation | Activated users whose complete W4 window elapsed |
| Active days per WAU | Source-provided P50/P75 of distinct UTC meaningful-activity dates | Meaningful users in that complete week; do not aggregate percentiles in Looker |
| Remote interventions per controller | Successful control outcomes | Controller WAU |
| Voice-assisted message share | Successful messages with `input_mode=voice_assisted` | All successful messages in the same complete/filter scope |
| Four-week WAU growth | Source-provided latest complete-week meaningful WAU divided by meaningful WAU four complete weeks earlier, minus one | Null when either sample is absent |
| Login attempt completion | Account-less completed attempts | Account-less started attempts under the same provider/app-version/date filters |

Full activation is the earliest successful `session_message_sent` or
`session_created_with_message`. A tap, queue insertion, failed creation, empty
session, permission/question answer, or legacy metadata request is not full
activation.

### Required labels

Every rate chart and scorecard must expose all of these adjacent to the value,
either as visible subtitle fields or companion scorecards:

- `Numerator: <count>`;
- `Denominator: <count and population>`;
- `Coverage: <preference, foundation, and activation-capability numerator / denominator as applicable>`;
- `Maturity: <window and latest mature cohort/date>`; and
- `Freshness: raw <as-of>, auth <as-of>, reporting <as-of/status>`.

The compact freshness/coverage/maturity strip from `PA - Data Quality` appears
at the top of every page and is never hidden by business filters. Use explicit
status text in addition to color so stale and inaccessible states remain
understandable in screenshots and to color-impaired viewers.

Allowed freshness labels are:

| Label | Meaning |
| --- | --- |
| `Fresh` | Raw, auth, and reporting layers satisfy their declared freshness policy |
| `Stale - last good data shown` | A layer is late/failed and reporting intentionally retains prior publication |
| `Blocked - auth snapshot invalid` | User-level publication aborted because the snapshot was stale, partial, or unreconciled |
| `No mature cohort` | The full metric window has not elapsed; value must be null, not zero |
| `Live partial period` | Operator selected an incomplete period; never investor-exportable |

### Coverage labels

Do not combine these into one vague "analytics coverage" percentage:

| Coverage | Required interpretation |
| --- | --- |
| Preference coverage | External accounts represented by current enabled reporting preference versus all eligible external accounts in scope |
| Foundation coverage | Accounts with timely `analytics_schema_ready` foundation exposure; diagnostic only |
| Activation-capability coverage | Accounts with `analytics_activation_ready` schema v1 or a qualifying activation outcome within 24 hours of creation |
| Measurable activation population | Mature accounts satisfying behavioral start, current eligibility, and timely activation-capability rules |

Opted-out and unsupported/legacy accounts are not silently counted as
non-activations. Display both coverage counts and percentages wherever an
account behavior rate is shown.

### Maturity labels

Pin the visible maturity text to the metric window:

| Metric | Mature when |
| --- | --- |
| 7-day setup/activation | Seven full 24-hour days have elapsed after account creation |
| W1 retention | Day 13 after activation has fully elapsed for every activated user in the displayed activation week |
| W4 retention | Day 34 after activation has fully elapsed for every activated user in the displayed activation week; operationally available after 35 days |
| Complete week | The UTC Monday-Sunday week ended before the current week |

Never let a dashboard date control override maturity filtering without also
switching to the clearly marked live/operator mode.

## Filter contract

Filters must preserve numerator/denominator populations. A filter may appear
only when the reporting view supplies both components under that dimension.

| Filter | Pages | Default | Rules |
| --- | --- | --- | --- |
| `Period mode` | All | `Complete periods` | Live mode adds warning banner and cannot be saved as default |
| Complete week range | Executive; Retention and engagement | Latest 12 complete weeks | UTC Monday-Sunday only |
| Account cohort week | Activation | Latest mature cohorts available | Applies only to cohort-compatible activation/setup charts |
| Platform | Activation diagnostics; Retention and engagement feature/screen panels | All | Do not apply to auth-only new-account totals unless source supplies matched denominator |
| App version | Login/onboarding/screen diagnostics only | All | Never use to redefine account activation/retention denominator |
| Login provider | Separated login diagnostic panel only | All | Closed values `github`, `google`, `apple`, `email` |
| Input mode/workspace kind/feature | Relevant adoption charts only | All | Do not cross-filter headline scorecards |
| Screen | Screen usage chart only | All | Pinned canonical custom screen names only |

Do not expose free-text filters, `user_key`, event-level drill-through, raw app
instance/session identifiers, report URL parameters carrying dimensions, or a
cross-page filter that changes only a numerator.

## Page 1: Executive snapshot

Purpose: investor/product-leadership readout of complete-period growth,
activation, retention, and data trust.

`PA - Investor Snapshot` intentionally selects three applicable periods
independently. Account cards use `account_week_start/end`, engagement cards use
`engagement_week_start/end`, and setup/activation cards use
`activation_cohort_week/end`. Show the applicable period beside every card;
never imply these dates are one shared week. Before a seven-day activation
cohort matures, keep activation values null and show `No mature cohort` while
the account and engagement cards continue to render.

### Pinned charts

| Chart | Source | Contract and filters |
| --- | --- | --- |
| `E0 - Data trust strip` | `PA - Data Quality` | Raw/auth/reporting as-of, pipeline status, preference/foundation/activation-capability coverage, latest mature W1/W4 cohorts; unaffected by business filters |
| `E1 - Weekly new accounts` | `PA - Investor Snapshot` | Latest complete week count, prior complete-week value and delta; label external account population |
| `E2 - 7-day bridge setup` | `PA - Investor Snapshot` | Rate plus visible numerator/eligible mature denominator; latest complete eligible cohort |
| `E3 - 7-day full activation` | `PA - Investor Snapshot` | Rate plus numerator, mature measurable denominator, and all three coverage labels |
| `E4 - Meaningful WAU` | `PA - Investor Snapshot` | Latest complete week count and prior comparison |
| `E5 - Controller WAU` | `PA - Investor Snapshot` | Latest complete week count and prior comparison |
| `E6 - W1 retention` | `PA - Retention` | Latest mature cohort rate, numerator/denominator, maturity; null when no mature cohort |
| `E7 - W4 retention` | `PA - Retention` | Latest mature cohort rate, numerator/denominator, maturity; directional label when sample is small; null when unavailable |
| `E8 - Four-week WAU growth` | `PA - Investor Snapshot` | Source-provided value only; null if current or four-weeks-prior sample is unavailable |
| `E9 - KPI trends` | `PA - Weekly KPIs` | Complete-week series for new accounts, meaningful WAU, controller WAU; latest 12 complete weeks |
| `E10 - Activation funnel` | `PA - Activation Funnel` | Account -> bridge -> project -> successful message; mature counts/rates; notification registration shown beside, not as a required step |

Do not place login conversion on this page. Do not show a headline metric without
its sample size and trust strip in the same screenshot/export viewport.

## Page 2: Activation

Purpose: explain setup-to-value conversion, time to activation, and bounded
onboarding/login friction without redefining the headline population.

### Pinned charts

| Chart | Source | Contract and filters |
| --- | --- | --- |
| `A0 - Data trust strip` | `PA - Data Quality` | Same fixed strip as Page 1 |
| `A1 - Mature cohort funnel` | `PA - Activation Funnel` | Account -> bridge -> project -> message by account cohort; show step numerator, original cohort denominator, conversion, maturity, and coverage |
| `A2 - 1/7/30-day setup table` | `PA - Activation Funnel` | Bridge/project/message windows only where each cohort is mature for that window; null for immature cells |
| `A3 - Time-to-step distribution` | `PA - Activation Funnel` | Aggregate pre-bucketed account counts for bridge, project, and full-activation elapsed time plus source-provided full-activation P50/P75; no per-user rows or Looker percentile calculation |
| `A4 - Activation path split` | `PA - Activation Funnel` | Existing-session message versus remotely created session with message; mutually exclusive first-activation counts |
| `A5 - Notification registration` | `PA - Activation Funnel` | Side-adoption panel visually separated from required funnel; label it notification registration, never "mobile setup" |
| `A6 - Onboarding friction` | `PA - Onboarding Friction` | Empty inventory/activity/diff, bounded session-creation failures, and confirmed support/install outcomes; complete dates only |
| `A7 - Login attempt completion` | `PA - Installation Login` | Separate diagnostic panel with started/completed/failed counts and summed-ratio completion by provider; include mandatory limitation label below |
| `A8 - Login failure mix` | `PA - Installation Login` | Fixed bounded authentication/launch/cancelled/timeout/unknown failure series by provider/app version/date; counts of attempts, never unique people |

### Mandatory login limitation

Display this text verbatim beside every login chart and in exports that contain
one:

> Installation-level sign-in attempt diagnostics. They contain no account key
> or attempt identifier, may include internal/test release traffic, and cannot
> be interpreted as unique people, account creation, or account activation.

The login source must have `includes_internal_test_traffic=true`. Treat a false
or missing value as a data-quality failure and hide the panel until corrected.
Never blend login attempts with auth account cohorts.

## Page 3: Retention and engagement

Purpose: show mature return behavior and adoption of remote-control and
differentiating features.

### Pinned charts

| Chart | Source | Contract and filters |
| --- | --- | --- |
| `R0 - Data trust strip` | `PA - Data Quality` | Same fixed strip as Pages 1-2 |
| `R1 - W1/W4 cohort heatmap` | `PA - Retention` | Activation cohort week, W1/W4 numerator, eligible denominator, rate, and maturity; immature cells are null/hatched, not zero |
| `R2 - Meaningful and controller WAU` | `PA - Weekly KPIs` | Complete-week two-series trend; source definitions only |
| `R3 - Active days per WAU` | `PA - Weekly KPIs` | Source-provided P50/P75 for complete weeks; no percentile reaggregation |
| `R4 - Remote interventions per controller` | `PA - Weekly KPIs` | Successful intervention numerator divided by Controller WAU; show successful messages separately from other controls |
| `R5 - Message depth` | `PA - Weekly KPIs` | Successful accepted messages per meaningful/controller user as explicitly supplied; no queued/failed events |
| `R6 - Voice adoption` | `PA - Feature Adoption` | Weekly transcription users and voice-assisted successful-message users/share; visible numerator and message/user denominator |
| `R7 - Session creation/worktree adoption` | `PA - Feature Adoption` | Successful remote-created sessions and dedicated-worktree share; failures shown separately, never in success numerator |
| `R8 - Remote feature adoption` | `PA - Feature Adoption` | Diff users, question answers/rejections, permission answers, and aborts; confirmed outcomes only |
| `R9 - Screen usage` | `PA - Screen Usage` | Canonical `product_screen_viewed` users/views by pinned screen; standard Firebase `screen_view` excluded; never classify as activity |

The W1/W4 heatmap must show activated-cohort size even when the retained numerator
is zero. When no cohort is mature, show "No mature cohort" and null rather than
a fabricated 0%.

## Field and style contract

Use human-readable labels only as presentation aliases. Preserve source field
types and aggregation:

| Field class | Looker aggregation/display |
| --- | --- |
| Counts/numerators/denominators | `SUM` only at the view's declared compatible grain; whole numbers |
| Distinct-user metrics already aggregated by SQL | Use source value; never `COUNT_DISTINCT` in Looker |
| Rates | Percent with one decimal; ratio-of-sums only when grouping compatible rows |
| Four-week growth | Source value; signed percent with one decimal; null remains blank/not available |
| P50/P75 | Source value; duration unit labeled; never averaged or recalculated |
| UTC date/week/cohort | ISO date; week label includes Monday start date |
| Freshness timestamps | UTC date/time with `UTC` in label |
| Booleans/status | Human-readable bounded label; no silent filter of failures |

Do not use chart sampling, approximate Looker calculations, auto date ranges,
cross-source blends, community visualizations that copy data, or report-level
extracts. Disable viewer data-source reuse and report copying. Restrict download,
print, and copy features to the explicitly approved policy; investor screenshots
must retain trust/maturity labels.

## Manual build sequence

1. Clear the cloud deployment block in the runbook.
2. Verify all reporting views and schema assertions in BigQuery, then confirm
   each view is authorized on only the exact auth/controls/curated source
   datasets it reads as listed in the warehouse runbook.
3. Create reusable data sources under `<DASHBOARD_OWNER>` using
   `<LOOKER_SERVICE_ACCOUNT>` credentials and reporting-only access.
4. Confirm each data source exposes no `user_key`, raw identifier, free-text
   event parameter, or private dataset field.
5. Build exactly the three pages and chart IDs above.
6. Apply the complete-period, numerator/denominator, coverage, maturity, and
   freshness contracts.
7. Reconcile every chart against a direct query of its reporting view for the
   same filters.
8. Share only with `<DASHBOARD_VIEWER_GROUP>` after all access tests pass.
9. Record report/data-source asset IDs and verification timestamp in the
   restricted deployment record.

## Manual access verification

Repeat this checklist before first sharing, after any IAM/credential/share
change, and at least quarterly. Record pass/fail evidence without identities or
asset URLs in this repository.

### BigQuery identity tests

Using approved service-account impersonation, verify the Looker identity can
query one reporting view. `bq` uses the active Cloud SDK credential and honors
`CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT`; it does not accept a bq
`--impersonate_service_account` flag. The human verifier needs a narrowly
approved, resource-scoped Service Account Token Creator grant (or an equivalent
custom impersonation role containing only the required token-minting
`iam.serviceAccounts.getAccessToken` permission) on
`<LOOKER_SERVICE_ACCOUNT>`. Do not grant Token Creator at project scope, and
remove a temporary verifier grant after recording the result:

```bash
CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="<LOOKER_SERVICE_ACCOUNT>" \
  bq query \
    --project_id=sesori-ai \
    --location=europe-west3 \
    --use_legacy_sql=false \
    'SELECT * FROM `sesori-ai.sesori_analytics_reporting.investor_snapshot` LIMIT 1'
```

Then verify each of these expected-deny probes fails with `Access Denied`:

```bash
CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="<LOOKER_SERVICE_ACCOUNT>" \
  bq query \
    --project_id=sesori-ai \
    --location=europe-west3 \
    --use_legacy_sql=false \
    'SELECT 1 FROM `sesori-ai.analytics_529377727.events_20260725` LIMIT 0'

CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="<LOOKER_SERVICE_ACCOUNT>" \
  bq query \
    --project_id=sesori-ai \
    --location=europe-west3 \
    --use_legacy_sql=false \
    'SELECT 1 FROM `sesori-ai.sesori_analytics_auth_private.auth_user_milestones` LIMIT 0'

CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="<LOOKER_SERVICE_ACCOUNT>" \
  bq query \
    --project_id=sesori-ai \
    --location=europe-west3 \
    --use_legacy_sql=false \
    'SELECT 1 FROM `sesori-ai.sesori_analytics_privacy_private.product_analytics_deletion_targets` LIMIT 0'

CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="<LOOKER_SERVICE_ACCOUNT>" \
  bq query \
    --project_id=sesori-ai \
    --location=europe-west3 \
    --use_legacy_sql=false \
    'SELECT 1 FROM `sesori-ai.sesori_analytics_curated.events_flattened` LIMIT 0'
```

Also verify the reporting schema contains no `user_key`. Do not grant access to
make a deny probe pass; a successful deny probe blocks sharing and requires IAM
remediation.

### Report sharing tests

- Sign in as `<DASHBOARD_OWNER>` and verify edit access plus all data-source
  credentials/owners are the approved restricted values.
- Sign in as one ordinary member of `<DASHBOARD_VIEWER_GROUP>` and verify view
  access, all charts, labels, and filters work without direct BigQuery roles.
- Sign in as an authenticated account outside the group and verify access is
  denied even with the report URL.
- Open the URL in a private/anonymous browser and verify access is denied.
- Verify link sharing, public embedding, organization-wide sharing, report copy,
  and data-source reuse are disabled.
- Verify a viewer cannot edit credentials, inspect SQL, add a private data
  source, or navigate to a BigQuery object.
- Verify permitted download/print output retains complete-period, sample-size,
  coverage, maturity, freshness, and login limitation labels.
- Search report fields, calculated fields, filters, chart drill-downs, URL
  parameters, and permitted exports for `user_key` and prohibited identifiers;
  require zero findings.

### Value reconciliation

For at least three complete UTC event dates and the latest complete week,
compare every scorecard/chart with its reporting-view row under identical
filters. Rates must equal summed numerator divided by summed denominator;
percentiles and four-week growth must equal source-provided values. Record
aggregate values, query job IDs, source/reporting as-of timestamps, and outcome
only. Never record user keys or raw rows.

## Change and incident handling

Treat any of these as a report incident: a missing trust strip, partial period
shown as complete, zero replacing null maturity, hidden denominator, mismatched
coverage, stale data without a stale label, login diagnostics represented as
people/accounts, a private data source, unexpected sharing, or a chart that does
not reconcile.

Immediately hide or pause the affected chart/report, revoke unintended sharing,
and preserve privacy/deletion operations. Restore the last known-good reporting
source/report version or fix the warehouse contract, then repeat schema, value,
and access verification. Do not repair a report incident by broadening IAM,
connecting raw data, adding an unreviewed blend, or removing labels.

Record the report version/change date, owner, affected chart IDs, complete
periods, last good warehouse/report freshness, access impact, correction, and
verification result in the restricted operations record.
