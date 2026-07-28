# User Analytics Tracker

## Plan State

- [x] Audit current analytics, product journeys, identity, privacy, auth
  milestones, and reporting constraints.
- [x] Agree that first successfully accepted user-authored message is full
  activation.
- [x] Agree on cross-repository scope, default-on account opt-out, campaign
  links first, and Looker Studio.
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
- [ ] Confirm cloud preflight facts: Firebase/GA4 BigQuery link, property ID,
  billing, dataset location, measurement start, scheduler connectivity, and
  dashboard access group.

## Immediate Operational Action

- [ ] Enable or verify Firebase daily BigQuery export now; record the exact UTC
  measurement start. Export is not retroactive.

## Implementation Series

The total is fixed at five implementation PRs. Titles must retain this slug and
step count across both repositories.

| Step | Repository | Required title | Status | Depends on |
| --- | --- | --- | --- | --- |
| 1/5 | `sesori_auth_server` | `[user-analytics] Add write-first analytics preference [step 1/5]` | Not started | Deploy before backfill; Firebase export preflight is independent |
| 2/5 | `sesori_auth_server` | `[user-analytics] Enforce analytics preference and add export [step 2/5]` | Not started | Step 1 deployed and repeated backfill validation at zero missing |
| 3/5 | apps monorepo | `[user-analytics] Add client analytics foundation and opt-out [step 3/5]` | Not started | Steps 1-2 endpoints/schema deployed |
| 4/5 | apps monorepo | `[user-analytics] Instrument activation and engagement outcomes [step 4/5]` | Not started | Step 3 released |
| 5/5 | apps monorepo + cloud | `[user-analytics] Add BigQuery metrics and Looker dashboards [step 5/5]` | Not started | Steps 2 and 4, Firebase export, private dataset/IAM |

## Release Evidence

- [ ] Write-first auth preference endpoint deployed; backfill repeatedly reports
  zero missing; required-field enforcement deployed.
- [ ] Auth export staging validation reconciled and daily schedule enabled.
- [ ] Mobile analytics release available to production users.
- [ ] First production full-activation event joined to its auth milestone row.
- [ ] Three complete event days reconcile through reporting models.
- [ ] Looker permissions, complete-period defaults, sample sizes, coverage,
  cohort maturity, and freshness verified.
- [ ] First W1 cohort matured and reviewed.
- [ ] First W4 cohort matured and reviewed, or dashboard truthfully shows no
  mature cohort yet.
