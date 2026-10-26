# PR tracking removal tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 6/13 in review.
- User decisions:
  - remove all PR tracking (round 1, Q1 A, 2026-10-25);
  - D7, remove project-view presence (the user's follow-up the same day).
- D2–D6 are detailed under Decisions in `PLAN.md`. D2 and D5 are the compatibility ones.

## Delivery

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/13 | Publish the plan | Done | #2068 |
| 2/13 | Row PR mark removed | Done | #2089 |
| 3/13 | PR refresh setting removed | In review (3.i); 3.ii not started | #2092 |
| 4/13 | Client stops declaring the open project | Not started | — |
| 5/13 | Session reads carry no PR data | Done | #2085 (5.i), #2086 (5.ii) |
| 6/13 | Polling stopped | In review | #2090 |
| 7/13 | Bridge stops tracking the open project | Not started | — |
| 8/13 | PR sync service removed | Not started | — |
| 9/13 | PR source lookup removed | Not started | — |
| 10/13 | Pull request repository removed | Not started | — |
| 11/13 | gh client removed | Not started | — |
| 12/13 | Schema v21 drops stored PR data | Not started | — |
| 13/13 | PR wire models removed; plan retired | Not started | — |

## Decision log

- 2026-10-25: the user chose to remove all PR tracking (Q1 A, no notes).
- 2026-10-25: detached worktrees were decided in round 2 (Q2 B, Q3 A). They ship as the separate
  `detached-worktrees` series, and step 12 waits for its rename removal.
- 2026-10-25: the user asked to remove the "active project" tracking too (D7). Steps 4 and 7 were added; the
  series grew from 11 to 13 steps. The voice glossary keeps its current-project trigger.
- No reduction of the retirement matrix has been requested or accepted.

## Review record

- Architecture plan review, 2026-10-25: rejected with 11 findings, all applied directly.
  - Order: the lookup, repository and gh-client steps (now 9–11) follow the imports, with dependencies
    corrected.
  - Compatibility: the D2 retiring condition can now be met, and `pullRequestRefresh` becomes nullable with a
    test. `waitForPrData` needs no marker; the last step tests that it still parses.
  - Missed sources: the benchmarks, the migration tests, `_projectPlaceholder`, `SseEventTracker`, and the shared
    test fixtures, named per step.
  - Cleanup: obsolete code is deleted in the step that makes it obsolete.
  - Docs: `bridge/AGENTS.md` and the two architecture-review skills drop their `GhCliApi` examples.
  - Settings: the service method, the validation bounds and the l10n regeneration.
  - Migration: the v21 test includes a parent and child session and checks foreign keys.
- D7 and its steps 4 and 7 were added after that review and have not been reviewed. They delete code and keep one
  inert wire variant. One runtime change is accepted: a recording made right after opening a project's composer
  may miss the new glossary.
