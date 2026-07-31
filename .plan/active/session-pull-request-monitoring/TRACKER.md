# Current-Branch Pull Request Monitoring: Tracker

## Current State

- **Plan slug:** `session-pull-request-monitoring`
- **Implementation base:** `main` at
  `0da8ec7cae9e23ac17569ab7a1069e815e16f8cf`
- **Series state:** Step 1/9 plan PR preparing; architecture approved
- **Current step:** Step 1/9 — revised durable plan
- **Plan PR:** pending
- **Next action:** commit/push and open Step 1/9

## Historical Delivery

- Plan PR [#436](https://github.com/sesori-ai/sesori_apps_monorepo/pull/436)
  merged the superseded all-branch/history/archive design.
- Implementation PR [#457](https://github.com/sesori-ai/sesori_apps_monorepo/pull/457)
  merged additive `RelayProjectView` and `Session.pullRequestHistory` contracts.
  Those compatible contracts remain prerequisites but are outside this revised
  nine-step series.
- Parallel plugins completed through PR #497 before this replan.

## Plan Review

- **Verdict:** approved with no findings
- **Reviewer:** `aristotle-plan-review`
- **Reviewed scope:** complete current `PLAN.md`, `TRACKER.md`, and
  `CONSIDERATIONS.md` plus removal of superseded stage files, against audited
  `main` at `83518cc087b76928bdd3a8c654f41dcfbefde6b4`
- **Date:** 2026-07-31
- **Findings applied:** none; pre-review gate and bridge/client/shared
  architecture all passed
- **Post-review drift:** `main` then advanced through unrelated Codex Step 4 and
  merged Harness-settings PR #647. The plan baseline/settings evidence was
  corrected to `0da8ec7c`; no architecture decision changed, so the approved
  plan was not re-reviewed merely for metadata/path refresh.

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [ ] | 1/9 | `plan/session-pull-request-monitoring/replan-current-pr-only` | `[session-pull-request-monitoring] docs: replan current PR monitoring [step 1/9]` | 4,000–7,000 | Architecture/docs validation passed; preparing commit/PR; pre-evidence diff was 4,888 lines |
| [ ] | 2/9 | `session-pull-request-monitoring-scoped-pr-cache` | `[session-pull-request-monitoring] feat(bridge): persist scoped PR selections [step 2/9]` | 1,300–2,000 | Blocked on Step 1 merge; generated migration overage may be unavoidable |
| [ ] | 3/9 | `session-pull-request-monitoring-graphql-selection` | `[session-pull-request-monitoring] feat(bridge): batch exact PR selection [step 3/9]` | 1,000–1,500 | Blocked on Step 2 merge |
| [ ] | 4/9 | `session-pull-request-monitoring-current-branch-refresh` | `[session-pull-request-monitoring] feat(bridge): refresh current session branches [step 4/9]` | 1,100–1,500 | Blocked on Step 3 merge |
| [ ] | 5/9 | `session-pull-request-monitoring-view-scheduler` | `[session-pull-request-monitoring] feat(bridge): schedule viewed-project PR refresh [step 5/9]` | 900–1,400 | Blocked on Step 4 merge |
| [ ] | 6/9 | `session-pull-request-monitoring-bridge-settings` | `[session-pull-request-monitoring] feat(bridge): configure PR refresh cadence [step 6/9]` | 1,000–1,500 | Blocked on Step 5 merge |
| [ ] | 7/9 | `session-pull-request-monitoring-client-presence` | `[session-pull-request-monitoring] feat(client): declare viewed projects [step 7/9]` | 1,000–1,500 | Blocked on Step 6 merge |
| [ ] | 8/9 | `session-pull-request-monitoring-client-settings` | `[session-pull-request-monitoring] feat(client): configure PR refresh cadence [step 8/9]` | 1,000–1,500 | Blocked on Step 7 merge; use current settings owner and merged #647 pattern |
| [ ] | 9/9 | `session-pull-request-monitoring-retire-plan` | `[session-pull-request-monitoring] docs: retire current PR monitoring plan [step 9/9]` | 50–200 | Blocked on Step 8 merge |

## Exact PR Titles

1. `[session-pull-request-monitoring] docs: replan current PR monitoring [step 1/9]`
2. `[session-pull-request-monitoring] feat(bridge): persist scoped PR selections [step 2/9]`
3. `[session-pull-request-monitoring] feat(bridge): batch exact PR selection [step 3/9]`
4. `[session-pull-request-monitoring] feat(bridge): refresh current session branches [step 4/9]`
5. `[session-pull-request-monitoring] feat(bridge): schedule viewed-project PR refresh [step 5/9]`
6. `[session-pull-request-monitoring] feat(bridge): configure PR refresh cadence [step 6/9]`
7. `[session-pull-request-monitoring] feat(client): declare viewed projects [step 7/9]`
8. `[session-pull-request-monitoring] feat(client): configure PR refresh cadence [step 8/9]`
9. `[session-pull-request-monitoring] docs: retire current PR monitoring plan [step 9/9]`

## Execution Rules

- Merge in numeric order. Each implementation step starts from current `main`
  after its predecessor merges and records a drift audit.
- Step 1 is the plan PR. Step 9 moves the plan from active to completed and has
  no production changes.
- Target 1,500 changed lines per implementation PR. Record actual additions plus
  deletions, generated output, tests, and any unavoidable overage.
- Do not combine adjacent steps merely because one lands below estimate.
- Every schema change exports/generates from current `main`; never rewrite a
  merged Drift migration or generated file.
- Run directly relevant tests/analyzers and architecture implementation review
  for Steps 2–8. Documentation-only Steps 1/9 and 9/9 use plan/docs validation.
- After each merge, update this tracker in the next step and proceed in order
  unless a material decision or blocker requires the user.

## Current Drift and Open Work

- Latest audited `main`: `0da8ec7cae9e23ac17569ab7a1069e815e16f8cf`.
- Drift schema: v12. Step 2 allocates the next version present on its actual
  baseline, not a hard-coded v13.
- Parallel-plugin plan: complete through Stage 9 / PR #497.
- PR #647 is merged and consolidates Harness settings into one screen. Its
  numeric-input/mutation pattern is current evidence for Step 8; PR cadence
  remains a separate bridge setting.
- Open PR #641 is analytics warehouse-only and does not change this feature's
  no-new-event decision.
- Open PR #621 touches the settings landing screen and may require Step 8 drift
  reconciliation if it merges.

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

- **Step 1/9:** `aristotle-plan-review` approved the complete revised plan with
  no findings. `git diff --check` passes; all 14 changed files are under the one
  plan directory. The pre-evidence 954-addition/3,934-deletion (4,888-line)
  docs-only diff is
  within its recorded 4,000–7,000 target; the intentional overage atomically
  removes obsolete executable stage authority. No Dart/Flutter suite was run.
  Commit/push/PR delivery is pending.

## Findings and Plan Deltas

- **2026-07-31 — Current-branch simplification:** Replaced durable visited
  branch/PR history with one selected PR for the exact current branch. Removed
  filesystem watchers, archive terminal state/snapshots, history presentation,
  and all-state authored discovery.
- **2026-07-31 — Coworker ownership:** Removed `--author @me`; exact
  same-repository branch matching includes coworker-authored PRs while fork heads
  remain excluded.
- **2026-07-31 — Batched active set:** Kept project presence but replaced
  per-project timers with one connection-scoped active-set scheduler and bounded
  multi-repository GraphQL target batches.
- **2026-07-31 — Settings:** Fixed cadence defaults to 30 seconds per bridge,
  supports live client mutation, and intentionally has no JSON file watcher.
- **2026-07-31 — Plan lifecycle:** Fixed a nine-PR series with this plan as
  Step 1/9 and active-to-completed retirement as Step 9/9.
