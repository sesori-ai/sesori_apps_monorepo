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
- [x] Decompose Step 3.C's lifecycle implementation in supplemental PR #619,
  merged as `b65cb974` on 2026-07-30:
  keep `ProductAnalyticsService` as the delivery facade, move preference and
  account lifecycle into an injected collaborator with one disposal owner, and
  replace coordinated nullable fields with explicit snapshots/runtime states.
  Two implementation-review passes found premature local activation, hidden
  storage-read failure, split lifecycle ownership, and pass-through DI; all
  findings were applied directly. Per the two-pass cap, do not describe the
  final correction as reviewer-approved.
- [x] Apply the post-Step-3.D analytics preference UX decision: move the
  `Basic Usage Analytics` switch to the account/profile page, replace dense
  control disclosure with a short code/messages privacy hint, hide runtime
  implementation status, remove the permanent refresh row, and show one inline
  retry action only when preference loading or saving fails. Detailed limits
  remain in the privacy/legal/store disclosures.
- [ ] Confirm cloud preflight facts: Firebase/GA4 BigQuery link, property ID,
  billing, dataset location, existing raw tables/IAM/expiration, GA4 retention/
  deletion configuration, scheduler connectivity, and dashboard access group.
  Partial preflight on 2026-07-31 verified active billing and an existing daily
  raw export in the required same region. A project budget alert, 90-day raw
  default/current-table expiration, and bounded on-demand query overrides are
  configured. Exact project/property/dataset/location/table, billing, budget,
  and quota values belong only in the restricted deployment record. Restricted
  IAM, GA4 privacy settings, scheduler identities, exact start-time recording,
  and Looker ownership remain blocked or unverified; do not enable additional
  export modes or deploy transforms yet.
- [x] Implement the local Step 5 warehouse, reporting, deployment, and privacy-
  deletion assets. The final architecture pass approved neutral Google
  credential ownership, Service-owned deletion sequencing, one-shot auth
  readiness with external retry, and the layered API/Repository boundaries.
  Focused Dart formatting/analyze/privacy tests, render-only validation of seven
  SQL assets and five schedules, and `git diff --check` pass. The self-contained
  BigQuery metric fixture passed in `europe-west3` on 2026-07-31. Deployed-schema
  assertions remain deferred until an approved warehouse exists; no repository
  SQL, schedules, IAM, or dashboards have been applied to cloud resources.
- [x] Apply valid PR #641 review findings before migration: split first-run
  bootstrap from auth-dependent apply; make DDL dry-run limits explicit; bound
  schedule inventory and move schedule SQL out of argv; harden metadata/API
  timeouts and SQL boundaries; require fresh tombstone-aware request/sweep
  cleanup; serialize tombstones with keyed publication; guard transform
  watermarks; enforce ordered activation progression and schema-ready
  foundation; remove unsupported build dimensions; and extend focused
  Dart/BigQuery fixtures. A two-pass architecture
  review moved deployment policy to orchestration and freshness policy to the
  deletion Service, then approved the revised boundaries. All 34 bot review
  threads received `[Sesori reply]` assessments before the code moved. PR #650
  follow-up review found that the resulting setup-order gate also reached
  headline activation/retention; the required standalone correction is tracked
  below and blocks warehouse apply.
- [x] Move the complete Step 5 warehouse/reporting/deletion implementation and
  its scoped Git history out of the apps monorepo into private repository
  `sesori-ai/sesori_analytics_platform`. Commit `743e5330` is the current
  standalone `main`. Root documentation is now a 72-line entry point with task
  guides and deep references under `docs/`; standalone format, analyze, privacy
  tests, render validation, and Markdown-link validation pass.

## Immediate Operational Action

- [x] Before merging/deploying Step 2, generate one canonical-base64 32-byte
  pseudonymization secret and configure it on the auth web runtime. The value was
  configured as a managed DigitalOcean production secret on 2026-07-29 and its
  SOPS-encrypted counterpart was added in auth commit `183604a`.
- [ ] Reuse that exact pseudonymization secret when the disabled export and
  suppression runtimes are created. Do not record the value or rotate it without
  a coordinated re-key migration.
- [ ] Complete the existing-link contingency: establish restricted project IAM;
  verify Firebase export is **daily-only**; audit and remediate ACL/90-day
  expiration on every landed raw table; record the original preflight miss and
  remediation evidence; and derive exact UTC `raw_export_start_at` from the first
  qualified controlled daily table rather than backdating it to link creation.
  Export is not retroactive. Record `behavioral_schema_v1_start_at` separately
  only after production `analytics_activation_ready` appears; foundation-only
  and account-less login events do not qualify.

## Step 5 Cloud Setup And Go-Live

This setup is required Step 5 delivery work, not a prerequisite delegated to the
user and not a separate future project. The private
`sesori-ai/sesori_analytics_platform` repository supplies the reviewed
automation and runbook; apps-monorepo PR #641 was closed as superseded by that
repository.

After the user approves the restricted values and security/privacy decisions,
the implementing operator must execute and verify all unchecked work:

- [ ] Record the approved GA4 privacy posture, exact raw/behavioral UTC start
  timestamps, service identities, schedule owners, dashboard owner/viewer group,
  and refresh policy in the restricted deployment record.
- [ ] Apply and verify two-month GA4 event/user-data retention, disabled Google
  Signals, ad personalization, ad storage/user-data features, and disabled
  Firebase native advertising identifiers; store the evidence in the restricted
  deployment record.
- [ ] Create the separate deployment, auth-export, auth-suppression, transform,
  privacy-deletion, and Looker identities; remove broad inherited data access;
  apply the dataset/table IAM matrix and exact authorized-view ACLs; pass every
  positive and expected-deny access probe.
- [ ] Before warehouse apply, correct and verify the standalone activation-
  cohort SQL/fixtures so headline activation, time-to-activation, and retention
  use authoritative `full_activation_at` independently of bridge/project order;
  reserve ordered bridge/project timestamps for setup diagnostics.
- [ ] Run the checked-in bootstrap-only deployment to create the same-location
  datasets and reference schemas; do not apply auth-dependent transforms yet.
- [ ] Provision and smoke-test the isolated auth export and suppression jobs,
  publish the initial auth snapshot, and verify its freshness and reconciliation.
- [ ] Run the auth-dependent warehouse apply only after that snapshot exists;
  apply schemas/views, run deployed-schema assertions, and reconcile the first
  complete raw/auth/curated/reporting data.
- [ ] Provision and smoke-test transform schedules, the request deletion command,
  and recurring privacy sweep; complete the non-production in-flight export and
  delayed-upload deletion drill.
- [ ] Build the restricted three-page Looker report, verify its data sources,
  maturity/coverage/freshness labels and sharing controls, then record asset IDs
  and go-live evidence.
- [ ] Keep Step 5 open until all setup, verification, deletion, access, and
  dashboard acceptance items pass; creating the analytics repository alone does
  not complete it.
- [ ] **Final plan action:** after every completion criterion and tracker item is
  complete, record final evidence and move the entire
  `.plan/active/user-analytics/` directory to
  `.plan/completed/user-analytics/`; commit the move and leave no active copy.

## Implementation Series

The total remains fixed at five rollout steps. Titles retain this slug and step
count across both repositories; Steps 3 and 4 are delivered as stacked PR
substeps. The former combined apps PR #610 was frozen and closed as superseded by
PRs #611-#614. Oversized outcome PR #629 was likewise closed and preserved as a
reference before rebuilding Step 4 as 4.A-4.D. Each replacement targets a
coherent review below roughly 1,200 added lines rather than accumulating review
patches in one umbrella diff.

| Step | Repository | Required title | Status | Depends on |
| --- | --- | --- | --- | --- |
| 1/5 | `sesori_auth_server` | `[user-analytics] Add write-first analytics preference [step 1/5]` | Deployed; 2026-07-29 backfilled 656/656 and two repeated validations reported zero missing | Deploy before backfill; Firebase export preflight is independent |
| 2/5 | `sesori_auth_server` | `[user-analytics] Enforce analytics preference and add export [step 2/5]` | PR #49 merged as `043ee9f` and deployed 2026-07-29; production health is `ok`, required-field enforcement is live, and the web HMAC secret is configured; export/suppression jobs remain unprovisioned and disabled | Step 1 deployed and repeated backfill validation at zero missing |
| 3.A/5 | apps monorepo | `[user-analytics] Add client analytics contracts and delivery [step 3.A/5]` | PR #611 merged as `3a181ee3` on 2026-07-30; frozen PR #610 remains superseded | Step 2 deployed |
| 3.B/5 | apps monorepo | `[user-analytics] Add durable analytics preference sync [step 3.B/5]` | PR #612 merged as `a792481b` on 2026-07-30 | Step 3.A |
| 3.C/5 | apps monorepo | `[user-analytics] Add account-linked analytics lifecycle [step 3.C/5]` | PR #613 merged as `53e9453f` on 2026-07-30, including supplemental lifecycle decomposition PR #619 | Step 3.B |
| 3.D/5 | apps monorepo | `[user-analytics] Integrate analytics settings and routing [step 3.D/5]` | PR #614 merged as `fb8cd0e8`; focused account-page UX follow-up PR #628 merged as `5e42bedc` on 2026-07-30 | Step 3.C |
| 4.A/5 | apps monorepo | `[user-analytics] Add bounded outcome analytics contracts [step 4.A/5]` | PR #632 merged as `e3e6b6e7` on 2026-07-31; oversized PR #629 remains closed as superseded | Step 3.D released |
| 4.B/5 | apps monorepo | `[user-analytics] Instrument account-less login outcomes [step 4.B/5]` | PR #634 merged as `5223c27d` on 2026-07-31 | Step 4.A |
| 4.C/5 | apps monorepo | `[user-analytics] Instrument activation and voice outcomes [step 4.C/5]` | PR #633 merged as `c662a639` on 2026-07-31 | Step 4.B |
| 4.D/5 | apps monorepo | `[user-analytics] Instrument visible engagement outcomes [step 4.D/5]` | PR #631 merged as `671c67ed` on 2026-07-31 | Step 4.C |
| 5/5 | private `sesori_analytics_platform` + cloud | `[user-analytics] Add BigQuery metrics and Looker dashboards [step 5/5]` | Repository implementation and scoped history migrated to private `sesori-ai/sesori_analytics_platform` `main` at `743e5330`; apps-monorepo PR #641 was closed as superseded. Focused standalone checks and metric fixtures pass, and the review-fix architecture is approved. Required Step 5 cloud setup remains tracked above and blocked pending approved restricted values. Billing/budget and 90-day raw expiration are configured, while restricted IAM, GA4 privacy settings, identities, exact timestamps, deployed-schema assertions, jobs/schedules, deletion drill, and dashboard setup remain unresolved | Steps 2 and 4.D, controlled Firebase export, split auth-private/privacy-private/control IAM |

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
