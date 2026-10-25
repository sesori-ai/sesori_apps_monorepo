# PR tracking removal tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 1/11.
- User decision: remove all PR tracking (round 1, Q1 A, 2026-10-25). D2–D6 follow from compatibility rules.

## Delivery

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/11 | Publish the plan | In review | — |
| 2/11 | Row PR mark removed | Not started | — |
| 3/11 | PR refresh setting removed | Not started | — |
| 4/11 | Session reads carry no PR data | Not started | — |
| 5/11 | Polling stopped | Not started | — |
| 6/11 | PR sync service removed | Not started | — |
| 7/11 | PR source lookup removed | Not started | — |
| 8/11 | Pull request repository removed | Not started | — |
| 9/11 | gh client removed | Not started | — |
| 10/11 | Schema v21 drops stored PR data | Not started | — |
| 11/11 | PR wire models removed; plan retired | Not started | — |

## Decision log

- 2026-10-25: the user chose to remove all PR tracking (Q1 A, no notes).
- 2026-10-25: detached worktrees were decided in round 2 (Q2 B, Q3 A). They ship as the separate
  `detached-worktrees` series, and step 10 waits for its rename removal.
- No reduction of the retirement matrix has been requested or accepted.

## Review record

- Architecture plan review, 2026-10-25: rejected with 11 findings, all applied directly.
  - Order: steps 7–9 reordered to follow the imports, with dependencies corrected.
  - Compatibility: the D2 retiring condition can now be met, and `pullRequestRefresh` becomes nullable with a
    test. `waitForPrData` needs no marker; step 11 tests that it still parses.
  - Missed sources: the benchmarks, the migration tests, `_projectPlaceholder`, `SseEventTracker`, and the shared
    test fixtures, named per step.
  - Cleanup: obsolete code is deleted in the step that makes it obsolete.
  - Docs: `bridge/AGENTS.md` and the two architecture-review skills drop their `GhCliApi` examples.
  - Settings: the service method, the validation bounds and the l10n regeneration.
  - Migration: the v21 test includes a parent and child session and checks foreign keys.
