# Current-Branch Pull Request Monitoring: Tracker

## Current State

- **Plan slug:** `session-pull-request-monitoring`
- **Implementation base:** `main` at
  `f969754bfa1ae8074ef24d4dbb248499abff79b1`
- **Series state:** Step 1/9 merged; Step 2/9 PR open with verification complete
- **Current step:** Step 2/9 — scoped PR persistence
- **Plan PR:** [#649](https://github.com/sesori-ai/sesori_apps_monorepo/pull/649) merged
- **Step 2 PR:** [#659](https://github.com/sesori-ai/sesori_apps_monorepo/pull/659)
- **Next action:** monitor Step 2/9 CI and review

## Existing Baseline

- Implementation PR [#457](https://github.com/sesori-ai/sesori_apps_monorepo/pull/457)
  merged additive `RelayProjectView` and `Session.pullRequestHistory` contracts.
  Those compatible contracts are the starting point for this nine-step series.
- Parallel plugins are complete through PR #497.

## Plan Review

- **Verdict:** approved with no findings
- **Reviewer:** `aristotle-plan-review`
- **Reviewed scope:** complete current `PLAN.md`, `TRACKER.md`, and
  `CONSIDERATIONS.md`, against audited `main` at
  `83518cc0e7d0a2f0be50ba7ec6a866f6cbf79c44`
- **Date:** 2026-07-31
- **Findings applied:** none; pre-review gate and bridge/client/shared
  architecture all passed
- **Post-review drift:** `main` advanced through Harness settings, output-image
  plugin work, analytics documentation, bridge `--data-dir` expansion, and plan
  archival before Step 1 merged at `f969754b`. Step 2 pinned that merge as its
  implementation base; the later `4ca1cb90` Codex output-image commit does not
  change this feature's architecture.

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [x] | 1/9 | `plan/session-pull-request-monitoring/replan-current-pr-only` | `🌿 [session-pull-request-monitoring] docs: plan current PR monitoring [step 1/9]` | 4,000–7,000 | [PR #649](https://github.com/sesori-ai/sesori_apps_monorepo/pull/649) merged as `f969754b` |
| [ ] | 2/9 | `session-pull-request-monitoring-scoped-pr-cache` | `🚧 [session-pull-request-monitoring] feat(bridge): persist scoped PR selections [step 2/9]` | 1,300–2,000 | [PR #659](https://github.com/sesori-ai/sesori_apps_monorepo/pull/659) open; verification complete; generated migration overage recorded below |
| [ ] | 3/9 | `session-pull-request-monitoring-graphql-selection` | `🚧 [session-pull-request-monitoring] feat(bridge): batch exact PR selection [step 3/9]` | 1,000–1,500 | Blocked on Step 2 merge |
| [ ] | 4/9 | `session-pull-request-monitoring-current-branch-refresh` | `🚧 [session-pull-request-monitoring] feat(bridge): refresh current session branches [step 4/9]` | 1,100–1,500 | Blocked on Step 3 merge |
| [ ] | 5/9 | `session-pull-request-monitoring-view-scheduler` | `🚧 [session-pull-request-monitoring] feat(bridge): schedule viewed-project PR refresh [step 5/9]` | 900–1,400 | Blocked on Step 4 merge |
| [ ] | 6/9 | `session-pull-request-monitoring-bridge-settings` | `⚙️ [session-pull-request-monitoring] feat(bridge): configure PR refresh cadence [step 6/9]` | 1,000–1,500 | Blocked on Step 5 merge |
| [ ] | 7/9 | `session-pull-request-monitoring-client-presence` | `🚧 [session-pull-request-monitoring] feat(client): declare viewed projects [step 7/9]` | 1,000–1,500 | Blocked on Step 6 merge |
| [ ] | 8/9 | `session-pull-request-monitoring-client-settings` | `🚧 [session-pull-request-monitoring] feat(client): configure PR refresh cadence [step 8/9]` | 1,000–1,500 | Blocked on Step 7 merge; use current settings owner and merged #647 pattern |
| [ ] | 9/9 | `session-pull-request-monitoring-retire-plan` | `🌱 [session-pull-request-monitoring] docs: retire current PR monitoring plan [step 9/9]` | 50–200 | Blocked on Step 8 merge |

## Exact PR Titles

1. `🌿 [session-pull-request-monitoring] docs: plan current PR monitoring [step 1/9]`
2. `🚧 [session-pull-request-monitoring] feat(bridge): persist scoped PR selections [step 2/9]`
3. `🚧 [session-pull-request-monitoring] feat(bridge): batch exact PR selection [step 3/9]`
4. `🚧 [session-pull-request-monitoring] feat(bridge): refresh current session branches [step 4/9]`
5. `🚧 [session-pull-request-monitoring] feat(bridge): schedule viewed-project PR refresh [step 5/9]`
6. `⚙️ [session-pull-request-monitoring] feat(bridge): configure PR refresh cadence [step 6/9]`
7. `🚧 [session-pull-request-monitoring] feat(client): declare viewed projects [step 7/9]`
8. `🚧 [session-pull-request-monitoring] feat(client): configure PR refresh cadence [step 8/9]`
9. `🌱 [session-pull-request-monitoring] docs: retire current PR monitoring plan [step 9/9]`

## Execution Rules

- Merge in numeric order. Each implementation step starts from current `main`
  after its predecessor merges and records a drift audit.
- Step 1 is the plan PR. Step 9 moves the plan from active to completed and has
  no production changes.
- Keep each fixed complexity emoji in its exact title unless implementation
  evidence requires a plan/tracker update before opening that PR.
- Every PR body includes complexity/rationale, what, why, risk/test focus, and
  expected user-visible/data/internal results.
- Target 1,500 changed lines per implementation PR. Record actual additions plus
  deletions, generated output, tests, and any unavoidable overage.
- Do not combine adjacent steps merely because one lands below estimate.
- Every schema change exports/generates from current `main`; never rewrite a
  merged Drift migration or generated file.
- Run directly relevant tests/analyzers and architecture implementation review
  for Steps 2–8. Documentation-only Steps 1/9 and 9/9 use plan/docs validation.
- Reassess causal cleanup in every implementation step; remove directly obsolete
  code/data/tests in the coherent owning PR or record why removal is deferred.
- After each merge, update this tracker in the next step and proceed in order
  unless a material decision or blocker requires the user.

## Current Drift and Open Work

- Step 2 base: `f969754bfa1ae8074ef24d4dbb248499abff79b1`.
- Latest drift-audited `origin/main`: `4ca1cb90bd1dcc066dc4d54bf444c96dac67db70`.
  Its only post-base commit is unrelated Codex output-image work (#657).
- Drift schema: v13, allocated from the exported v12 baseline without rewriting
  any merged migration.
- Parallel-plugin plan: complete through Stage 9 / PR #497.
- PR #647 is merged and consolidates Harness settings into one screen. Its
  numeric-input/mutation pattern is current evidence for Step 8; PR cadence
  remains a separate bridge setting.
- PR #641 closed without merging; its warehouse-only scope did not change this
  feature's no-new-event decision.
- PR #621 and its #655 voice follow-up merged. Step 8 will reconcile its settings
  surface against that then-current baseline.

## Interview Decisions Recorded 2026-07-31

- Root sessions only; child sessions have no independent PR.
- Dedicated and non-dedicated sessions both use the exact current branch.
- Sessions sharing a directory share current branch/PR state.
- Match any author in the same repository; fork heads are excluded.
- Newest open PR wins, otherwise newest merged/closed PR.
- A branch switch with no PR shows no PR and never falls back.
- Do not retain visited branches, multiple PRs, or PR history.
- Resolve branches only during activation/scheduled/explicit refresh; no
  filesystem watchers.
- Refresh only while project list/detail is viewed, plus explicit old-client
  request triggers.
- Multiple devices may view different projects; one connection owns one project
  and the bridge refreshes their active union.
- One fixed bridge interval defaults to 30 seconds and is customisable in
  seconds through bridge JSON plus shared client settings.
- App settings update the timer live; manual JSON edits require restart.
- Archive has no special PR behavior.
- No unseen mutation, push notification, history UI, desktop-shell-specific
  code, or new analytics event.
- Step 1 raises this plan; Step 9 moves it to `.plan/completed/`.

## Verification Log

- **Step 1/9:** `aristotle-plan-review` approved the complete production plan
  with no findings. The plan consolidation remains within its recorded
  4,000–7,000 changed-line target. No Dart/Flutter suite applies to this
  documentation/agent-definition PR.
- **PR #649 review follow-up:** Assessed five unresolved automated-review
  threads. All five identified concrete plan defects; the plan now covers
  fork-obscured candidate pagination, add-during-flight scheduling, read-time
  identity gating, named non-GitHub branch display, and the correct reviewed
  baseline SHA. Documentation validation remains `git diff --check`; no product
  suite applies.
- **PR #649 refresh-generation follow-up:** A later automated review correctly
  identified that a same-project explicit refresh could share an in-flight cycle
  after its local Git snapshot. The plan now seals per-project request
  generations before local resolution and requires post-seal requests/waiters to
  use the coalesced follow-up generation.
- **PR #649 route-visibility follow-up:** A later automated review correctly
  identified that GoRouter shell providers can remain mounted under covered
  child routes. Client claims now carry explicit visibility from `RouteSource`
  plus actual wide split-pane presence; hidden claims clear before disposal and
  are not reasserted on resume.
- **PR guidance update:** Added the requested `🌱`–`🚨` title scale,
  required PR-body summaries, and feature cleanup assessment/execution rules to
  Plan Maker and Plan Worker, with matching title/body rules in root
  `AGENTS.md`. These non-production instructions do not change the approved
  architecture. `git diff --check` passes, exact titles match between
  plan/tracker, and change scope is limited to this plan plus the three
  instruction/agent files.
- **Step 2/9 implementation:** Exported v12 before source edits, generated v13
  schema/migration fixtures, and added repository/login/current-session scope,
  typed fresh-login verification, transactional cache ownership, and fail-closed
  list/detail reads. `dart analyze --fatal-infos`, all 2,295 bridge-app tests,
  and `git diff --check` pass.
- **Step 2/9 architecture review:** `aristotle-impl-review` rejected the initial
  working-tree implementation with three in-scope findings. The implementation
  now maps the API identity into repository-owned `VerifiedGithubLogin`, preserves
  established PR scope during catalog publication, and strips PR metadata when
  the waited refresh/final mapping path fails. Per repository policy, these
  applied findings were not re-reviewed; no approval is claimed for the revised
  working tree.
- **Step 2/9 line overage:** The implementation changes 6,848
  lines, including 3,646 generated Drift/Freezed/schema-fixture lines. The schema
  migration, generated artifacts, required internal contract updates, privacy
  read gates, and their migration/DAO/repository/routing regressions must land in
  lockstep to compile and keep the migration independently valid; there is no
  smaller coherent PR inside the fixed Step 2 acceptance boundary. New v12/v13
  verifier fixtures intentionally omit generated data classes to limit overage.

## Findings and Plan Deltas

- **2026-07-31 — Current-branch scope:** Keep one selected PR for the exact
  current branch, with no visited-branch history, filesystem watcher, archive
  PR state, history presentation, or all-state discovery.
- **2026-07-31 — Coworker ownership:** Exact same-repository branch matching has
  no author filter, so coworker-authored PRs are eligible while fork heads remain
  excluded.
- **2026-07-31 — Batched active set:** One connection-scoped active-set
  scheduler batches bounded multi-repository GraphQL targets without
  per-project timers.
- **2026-07-31 — Settings:** Fixed cadence defaults to 30 seconds per bridge,
  supports live client mutation, and intentionally has no JSON file watcher.
- **2026-07-31 — Plan lifecycle:** Fixed a nine-PR series with this plan as
  Step 1/9 and active-to-completed retirement as Step 9/9.
- **2026-07-31 — PR #649 review:** Corrected the reviewed baseline SHA; required
  candidate pagination past newer fork heads, read-time GitHub identity gating,
  a coalesced add-during-flight refresh, and independent branch display for
  named non-GitHub repositories.
- **2026-07-31 — Explicit refresh generation:** Same-project requests arriving
  after cycle admission no longer share potentially stale local evidence; their
  waiter is bound to the immediate follow-up generation.
- **2026-07-31 — Visible-route ownership:** Mounted list/detail cubits are not
  sufficient evidence of viewing. Narrow covered routes clear claims, wide
  visible list panes retain them, and detail child routes hide detail claims.
- **2026-07-31 — Cleanup:** Step 2 replaces the unscoped cache shape; Step 3
  removes repository-wide PR source code and directly obsolete test support.
  Creation-branch storage and the empty compatibility wire field remain because
  they still have required cleanup/transport roles.
- **2026-07-31 — Step 2 review corrections:** Verification evidence remains a
  repository-owned typed value through handlers/services/repositories; catalog
  imports preserve PR scope they do not own; waited list responses strip cached
  PR data if refresh or final identity-gated mapping fails.
