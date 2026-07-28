# User Analytics Tracker

## Plan State

- [x] Audit current analytics, product journeys, identity, privacy, auth
  milestones, and reporting constraints.
- [x] Agree that first successfully accepted user-authored message is full
  activation.
- [x] Agree on cross-repository scope, default-on optional analytics with an
  in-app opt-out, campaign links first, and Looker Studio. The reviewed design
  narrows the enforceable promise to installation-local Sesori custom events,
  server reporting/supported-client synchronization, and explicitly disclosed
  legacy/Firebase-automatic-event limits.
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
  dedicated server service, core hashing/route/campaign behavior, no harness or
  voice events, SDK-acceptance result, post-splash readiness, write-first split,
  and forward-fix privacy floor. Per review rules, these corrections were not
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
- [ ] Confirm cloud preflight facts: Firebase/GA4 BigQuery link, property ID,
  billing, dataset location, existing raw tables/IAM/expiration, GA4 retention/
  deletion configuration, scheduler connectivity, and dashboard access group.

## Immediate Operational Action

- [ ] Establish restricted project IAM, then enable or verify Firebase **daily-
  only** BigQuery export; apply/verify raw dataset ACL and 90-day expiration
  before the first daily table and record exact UTC `raw_export_start_at`.
  Export is not retroactive. Record `behavioral_schema_v1_start_at` separately
  only after the production custom schema appears.

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
  reactivate another account, and supported online foreground clients observe a
  remote preference change within the declared 15-minute bound.
- [ ] Upgrade clears legacy Firebase global identity before custom sources, and
  forced clear failure suppresses custom events without blocking the product.
- [ ] First production full-activation event joins its auth milestone row and a
  timely per-account schema-v1 exposure; preference-unknown first message is
  deferred rather than lost.
- [ ] Three complete event days reconcile through reporting models.
- [ ] Stale auth snapshot abort/recovery and GA4 upstream deletion drills pass,
  including auth-source non-repopulation, aggregate rebuild, and explicit
  automatic-only never-keyed coverage limits.
- [ ] Looker permissions, complete-period defaults, sample sizes, coverage,
  cohort maturity, and freshness verified.
- [ ] First W1 cohort matured and reviewed.
- [ ] First W4 cohort matured and reviewed, or dashboard truthfully shows no
  mature cohort yet.
