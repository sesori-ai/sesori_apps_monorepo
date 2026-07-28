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
- [x] Apply valid second-round findings: timely per-account schema exposure,
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
- [ ] Confirm cloud preflight facts: Firebase/GA4 BigQuery link, property ID,
  billing, dataset location, existing raw tables/IAM/expiration, GA4 retention/
  deletion configuration, scheduler connectivity, and dashboard access group.

## Immediate Operational Action

- [ ] Establish restricted project IAM, then enable or verify Firebase **daily-
  only** BigQuery export; apply/verify raw dataset ACL and 90-day expiration
  before the first daily table and record exact UTC `raw_export_start_at`.
  Export is not retroactive. Record `behavioral_schema_v1_start_at` separately
  only after the production account-linked product schema appears; account-less
  login events do not qualify.

## Implementation Series

The total is fixed at five implementation PRs. Titles must retain this slug and
step count across both repositories.

| Step | Repository | Required title | Status | Depends on |
| --- | --- | --- | --- | --- |
| 1/5 | `sesori_auth_server` | `[user-analytics] Add write-first analytics preference [step 1/5]` | Not started | Deploy before backfill; Firebase export preflight is independent |
| 2/5 | `sesori_auth_server` | `[user-analytics] Enforce analytics preference and add export [step 2/5]` | Not started | Step 1 deployed and repeated backfill validation at zero missing |
| 3/5 | apps monorepo | `[user-analytics] Add client analytics foundation and opt-out [step 3/5]` | Not started | Steps 1-2 endpoints/schema deployed |
| 4/5 | apps monorepo | `[user-analytics] Instrument activation and engagement outcomes [step 4/5]` | Not started | Step 3 released |
| 5/5 | apps monorepo + cloud | `[user-analytics] Add BigQuery metrics and Looker dashboards [step 5/5]` | Not started | Steps 2 and 4, controlled Firebase export, split auth-private/control IAM |

## Release Evidence

- [ ] Write-first auth preference endpoint deployed; backfill repeatedly reports
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
  timely per-account schema-v1 exposure; preference-unknown first message is
  deferred rather than lost.
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
  only for future keyed uploads.
- [ ] Three-page Looker permissions, complete-period defaults, sample sizes,
  coverage, cohort maturity, and freshness verified.
- [ ] First W1 cohort matured and reviewed.
- [ ] First W4 cohort matured and reviewed, or dashboard truthfully shows no
  mature cohort yet.
