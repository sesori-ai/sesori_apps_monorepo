# User Analytics Tracker

## Plan State

- [x] Audit current analytics, product journeys, identity, privacy, auth
  milestones, and reporting constraints.
- [x] Agree that first successfully accepted user-authored message is full
  activation.
- [x] Agree on cross-repository scope, default-on optional authenticated product
  analytics with an in-app opt-out, a narrowly exempt/disclosed account-less
  login funnel, and Looker Studio. The design narrows the enforceable preference
  promise to account-linked Sesori product events, server reporting/supported-
  client synchronization, and explicitly disclosed login/legacy/Firebase-
  automatic-event limits.
- [x] First architecture pre-review rejected the draft as too vague about
  workspace/class/DI ownership, auth export composition, data flow,
  compatibility/rollback, and unavoidable GA4 raw fields.
- [x] Clarify those six areas directly in `PLAN.md`.
- [x] Run the one permitted second review. It passed the detail gate but
  rejected the architecture for upward/layer-skipping dependencies, auth/shell
  ownership leakage, backend classification, untruthful campaign persistence,
  splash networking, migration race, and unsafe rollback.
- [x] Apply those valid findings directly: explicit Client/API/Storage/
  Repository/Service/Listener layers, core preference API and lifecycle,
  dedicated server service, core hashing/route behavior, no harness event,
  SDK-acceptance result, post-splash readiness, write-first split, and forward-
  fix privacy floor. Per review rules, these corrections were not
  sent for a third approval pass; do not describe the revised plan as reviewer-
  approved.
- [x] Apply valid automated PR findings: write-ahead local disable and logout
  retry preservation, generation-safe/foreground preference reconciliation,
  cold-open buffering, strict campaign window, immutable export cutoffs,
  split auth/control IAM, dual start timestamps, outage-recoverable transforms,
  day-zero raw controls, and upstream GA4 retention/deletion.
- [x] Apply valid second-round findings: timely per-account foundation exposure,
  bounded first-message deferral, empty-to-non-empty milestones, account-scoped
  campaign completion, internal exclusion before auth aggregation, source
  deletion tombstones, honest never-keyed deletion limits, and earliest upgrade
  clearing of legacy Firebase global identity.
- [x] Apply materially valid third-round findings: auth-bound campaign retries,
  auth-restoration link classification, generic harness screen mapping, bounded
  preference deadlines, durable pending enable, repeatable daily monitoring,
  whole-process legacy-ID-clear failure disclosure, deletion anti-join/recurring
  sweeps, and tombstone-aware export completion.
- [x] Compare the alternate plan and both PR review sets. Retain this plan's
  account-level identity, privacy, layering, curated warehouse, and authoritative
  activation seams; reject the alternate raw GA4 SQL after verified WAU,
  timestamp, cohort, identity, provider, and screen-schema defects.
- [x] Apply later product decisions: keep the foundation durable beyond the
  two-month readout; add bounded voice-assisted and pre-auth login metrics;
  explicitly drive Firebase screen reporting from GoRouter with automatic
  screen collection disabled; defer campaign attribution, notification
  conversion, and dedicated dashboard pages beyond the initial three-page
  report without discarding them from future work.
- [x] Review the considerable revised plan. The reviewer rejected its missing
  pre-logout owner, underspecified deletion command, preference polling,
  undeclared runtime-capability DI, and non-mirrored layer directories. Apply
  those valid findings directly: `SettingsCubit -> prepareForLogout`, concrete
  layered deletion commands/IAM, one read per auth generation plus explicit
  Settings refresh, immutable pre-phase-1 capability injected everywhere, and
  Foundation/API/Repository/Service/Layer-4 paths. Per review rules, do not claim
  the corrected version was re-reviewed/approved.
- [x] Apply valid current PR findings: add internal JSON PUT support; add server
  revision compare-and-set/idempotency so timed-out older enable cannot overwrite
  newer disable; move monitoring activity to a route-visible listener; defer the
  obsolete notification finding with its feature; and narrow recurring upstream
  deletion to future keyed uploads without a persistent account-install map.
- [x] Apply valid follow-up findings: retain fixed measurement-critical
  candidates until preference resolves without prematurely consuming guards;
  verify permission `ApiResponse` before success; sweep all permanent deletion
  tombstones for newly landed keyed rows; label account-less login diagnostics
  as including non-excludable internal/test traffic; move existing onboarding
  events to confirmed platform outcomes; add PR-4 activation-capable readiness;
  and begin Apple login analytics before the native authorization sheet.
- [x] Apply valid next-round findings: preserve authoritative occurrence time
  through deferred delivery; retain OAuth provider across interruption/resume;
  persist voice-assisted origin in typed in-memory drafts; disclose both two-
  month upstream and 90-day exported-raw retention; and make internal/test
  exclusions permanent so rebuilds never resurrect historical traffic.
- [x] Apply valid latest findings: clear legacy Firebase identity in foreground
  and FCM-background execution; scope readiness to each authenticated generation;
  service-own already-observed deferred session activity; isolate deletion
  targets from auth-export access; and overlap deletion sweeps across mutable
  late-arrival partitions plus watermark gaps.
- [x] Replace enumerable ObjectId SHA-256 join keys with server-derived
  HMAC-SHA-256. The authenticated preference API carries the derived key to
  clients; one shared secret serves web/export/suppression runtimes, while a
  deletion-only legacy SHA-256 value remains restricted to privacy targets for
  pre-migration Firebase `user_id` deletion.
- [ ] Confirm cloud preflight facts: Firebase/GA4 BigQuery link, property ID,
  billing, dataset location, existing raw tables/IAM/expiration, GA4 retention/
  deletion configuration, scheduler connectivity, and dashboard access group.

## Immediate Operational Action

- [x] Before merging/deploying Step 2, generate one canonical-base64 32-byte
  pseudonymization secret and configure it on the auth web runtime. The value was
  configured as a managed DigitalOcean production secret on 2026-07-29 and its
  SOPS-encrypted counterpart was added in auth commit `183604a`.
- [ ] Reuse that exact pseudonymization secret when the disabled export and
  suppression runtimes are created. Do not record the value or rotate it without
  a coordinated re-key migration.
- [ ] Establish restricted project IAM, then enable or verify Firebase **daily-
  only** BigQuery export; apply/verify raw dataset ACL and 90-day expiration
  before the first daily table and record exact UTC `raw_export_start_at`.
  Export is not retroactive. Record `behavioral_schema_v1_start_at` separately
  only after production `analytics_activation_ready` appears; foundation-only
  and account-less login events do not qualify.

## Implementation Series

The total is fixed at five implementation PRs. Titles must retain this slug and
step count across both repositories.

| Step | Repository | Required title | Status | Depends on |
| --- | --- | --- | --- | --- |
| 1/5 | `sesori_auth_server` | `[user-analytics] Add write-first analytics preference [step 1/5]` | Deployed; 2026-07-29 backfilled 656/656 and two repeated validations reported zero missing | Deploy before backfill; Firebase export preflight is independent |
| 2/5 | `sesori_auth_server` | `[user-analytics] Enforce analytics preference and add export [step 2/5]` | PR #49 merged as `043ee9f` and deployed 2026-07-29; production health is `ok`, required-field enforcement is live, and the web HMAC secret is configured; export/suppression jobs remain unprovisioned and disabled | Step 1 deployed and repeated backfill validation at zero missing |
| 3/5 | apps monorepo | `[user-analytics] Add client analytics foundation and opt-out [step 3/5]` | Local implementation and verification complete; ready for publication/manual release checks | Steps 1-2 endpoints/schema deployed |
| 4/5 | apps monorepo | `[user-analytics] Instrument activation and engagement outcomes [step 4/5]` | Not started | Step 3 released |
| 5/5 | apps monorepo + cloud | `[user-analytics] Add BigQuery metrics and Looker dashboards [step 5/5]` | Not started | Steps 2 and 4, controlled Firebase export, split auth-private/privacy-private/control IAM |

## Step 3 Local Implementation Evidence (2026-07-29)

- [x] Added the layered client analytics foundation, synchronized Settings
  preference, release-only runtime capability, server-HMAC key propagation,
  GoRouter-owned screen reporting, Firebase mobile adapter/legacy-ID clear, and
  desktop no-op adapter. Migrated the existing onboarding catalog to confirmed
  platform outcomes and removed the legacy shell-owned analytics stack.
- [x] Bound preference GET/PUT token acquisition and 401 retry to the initiating
  account. Analytics auth subscription now exists before startup storage work,
  and startup/readiness wait for the latest generation's local initialization
  before reconciliation. Regression tests cover account switches during token
  refresh and while both old/new account storage reads are pending.
- [x] Ran `dart pub get` from `client/`; regenerated Injectable outputs in
  `module_core`, `app`, and `desktop`; regenerated app localizations.
- [x] `dart analyze` reports no issues in `client/module_auth`,
  `client/module_core`, `client/app`, `client/desktop`, and
  `client/module_desktop_core`.
- [x] Full suites pass: `module_auth` 86 tests, `module_core` 748 tests, mobile
  app 769 tests, desktop shell 15 tests, and `module_desktop_core` 52 tests.
  `git diff --check` also passes.
- [x] Ran the two permitted architecture implementation-review passes. Pass 1
  found startup subscription and cross-account 401-retry races; both were fixed.
  Pass 2 confirmed the account-bound transport fix and found that stale startup
  completion could release readiness before the latest local load; that finding
  was fixed with a latest-generation initialization gate and regression test.
  Per the two-pass cap, the final fix was not sent for a third verdict; do not
  describe the implementation as reviewer-approved.
- [ ] Complete the plan's release-build Firebase/GoRouter/upgrade smoke checks
  with synthetic content. Public privacy notice, private store metadata, and
  counsel approval remain release prerequisites.

## Release Evidence

- [x] Write-first auth preference endpoint deployed; backfill repeatedly reports
  zero missing; required-field enforcement deployed.
- [ ] Auth export staging validation reconciled and daily schedule enabled.
- [ ] Mobile analytics release available to production users.
- [ ] Local disable survives restart/logout, delayed stale auth work cannot
  reactivate another account, and clients observe remote preference changes on
  next auth generation/process start or explicit online Settings refresh without
  polling.
- [ ] Upgrade clears legacy Firebase global identity before custom sources, and
  forced clear failure suppresses custom events without blocking the product or
  pretending the process's automatic events lost legacy identity.
- [ ] First production full-activation event joins its auth milestone row and a
  timely per-account `analytics_activation_ready` exposure from the outcome
  release; foundation-only binaries remain unmeasurable and preference-unknown
  first message is deferred rather than lost.
- [ ] Typed/voice-assisted successful messages and content-free transcription
  completions appear without transcript/audio-derived data; account-less login
  aggregates contain only pinned provider/failure dimensions and no user key.
- [ ] Every GoRouter route maps to the pinned screen enum and produces one
  canonical custom screen event plus one matching Firebase-native mirror, with
  automatic screen reporting disabled and no concrete route identifiers.
- [ ] Three complete event days reconcile through reporting models.
- [ ] Stale auth snapshot abort/recovery and GA4 upstream deletion drills pass,
  including in-flight export ordering, delayed offline upload/recurring sweep,
  flattened non-repopulation, aggregate rebuild, and explicit transient/future-
  automatic-only/never-keyed coverage limits; recurring enforcement is claimed
  only for future keyed uploads, and responses distinguish two-month upstream
  retention from 90-day restricted exported-raw expiration.
- [ ] Three-page Looker permissions, complete-period defaults, sample sizes,
  coverage, cohort maturity, and freshness verified.
- [ ] First W1 cohort matured and reviewed.
- [ ] First W4 cohort matured and reviewed, or dashboard truthfully shows no
  mature cohort yet.
