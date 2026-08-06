# Session History Store: Tracker

## Current State

- **Plan slug:** `session-history-store`
- **Implementation base:** `origin/main` at `232974e1`
- **Series state:** Step 1/9 plan PR open
- **Current step:** 1/9
- **Plan PR:** [#764](https://github.com/sesori-ai/sesori_apps_monorepo/pull/764)
- **Next action:** merge PR #764, then start step 2/9

## Plan Review

- **Verdict:** first draft rejected with seven actionable findings; all
  applied directly; corrected plan not re-reviewed merely for approval
- **Reviewer:** `architecture-plan-review`
- **Date:** 2026-08-06
- **Applied corrections:** Layer 3 purge coordination via
  `SessionDeletionService`, named classes with constructor dependencies,
  Layer 1 `AttachmentSpillStorage`/`SessionArchiveStorage`, DAO-owned vacuum,
  single `ArchivedSessionGate`, deleted speculative sync-state `origin`
  column, concrete client pagination step

## Delivery Steps

| Done | Step | Exact PR title | Estimate | State |
|---|---|---|---:|---|
| [ ] | 1/9 | `🌱 [session-history-store] docs: plan the session history store [step 1/9]` | 500-700 | [PR #764](https://github.com/sesori-ai/sesori_apps_monorepo/pull/764) open; 627 changed lines |
| [ ] | 2/9 | `🚧 [session-history-store] feat(bridge): introduce the history database [step 2/9]` | 1,500-2,600 | pending |
| [ ] | 3/9 | `🚧 [session-history-store] feat(bridge): capture live message events [step 3/9]` | 800-1,300 | pending |
| [ ] | 4/9 | `⚙️ [session-history-store] feat(bridge): serve messages from the store [step 4/9]` | 700-1,100 | pending |
| [ ] | 5/9 | `⚙️ [session-history-store] feat: paginate session messages [step 5/9]` | 600-1,000 | pending |
| [ ] | 6/9 | `🌿 [session-history-store] feat(client): load history pages on demand [step 6/9]` | 500-900 | pending |
| [ ] | 7/9 | `🚧 [session-history-store] feat(bridge): make archiving read-only [step 7/9]` | 1,000-1,500 | pending |
| [ ] | 8/9 | `🌿 [session-history-store] feat(client): permanent archive experience [step 8/9]` | 400-700 | pending |
| [ ] | 9/9 | `🌱 [session-history-store] docs: retire the session history store plan [step 9/9]` | 50-150 | pending |

## Execution Rules

- Merge in numeric order; each PR must remain independently valid at its own
  base. A successor may target its open predecessor.
- After a PR merges, continue automatically with the next numbered step; stop
  only for a material decision or blocker.
- Count additions plus deletions (including generated code and tests) against
  the 1,500-line soft cap; the step 2 overage from new-database codegen is
  pre-recorded in `PLAN.md`.
- Generated Drift/Freezed files change only through code generation; preserve
  every schema version already merged to `main`.
- Run focused tests, the owning package's full tests,
  `dart analyze --fatal-infos`, and `git diff --check` for each implementation
  step; run `architecture-implementation-review` for steps 2, 3, 4, 5, and 7.
- Wire changes stay additive-optional; older-peer behavior is asserted by
  tests in steps 5 and 7.

## Verification Log

- (empty)

## Findings And Plan Deltas

- **2026-08-06 — Attachment spill decision:** inline base64 payloads are
  written to spill files and referenced from stored JSON rather than dropped,
  so images keep rendering from store and archive while no database ever
  holds base64. Recorded as Decision 3 in `PLAN.md`.
- **2026-08-06 — Unarchive removal:** archiving becomes permanent read-only
  by user direction; `archived: false` from published apps receives an
  explicit error. Recorded as Decision 4.
