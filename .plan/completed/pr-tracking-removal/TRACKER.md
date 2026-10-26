# PR tracking removal tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Status: complete. All 13 steps are merged, and the plan was retired on 2026-10-26.
- User decisions:
  - remove all PR tracking (round 1, Q1 A, 2026-10-25);
  - D7, remove project-view presence (the user's follow-up the same day).
- D2–D6 are detailed under Decisions in `PLAN.md`. D2 and D5 are the compatibility ones.

## Delivery

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/13 | Publish the plan | Done | #2068 |
| 2/13 | Row PR mark removed | Done | #2089 |
| 3/13 | PR refresh setting removed | Done | #2092 (3.i), #2096 (3.ii) |
| 4/13 | Client stops declaring the open project | Done | #2091 |
| 5/13 | Session reads carry no PR data | Done | #2085 (5.i), #2086 (5.ii) |
| 6/13 | Polling stopped | Done | #2090 |
| 7/13 | Bridge stops tracking the open project | Done | #2093 |
| 8/13 | PR sync service removed | Done | #2095 |
| 9/13 | PR source lookup removed | Done | #2097 |
| 10/13 | Pull request repository removed | Done | #2098 |
| 11/13 | gh client removed | Done | #2099 |
| 12/13 | Schema v21 drops stored PR data | Done | #2100 |
| 13/13 | PR wire models removed; plan retired | Done | #2102; retirement matrix below |

## Decision log

- 2026-10-25: the user chose to remove all PR tracking (Q1 A, no notes).
- 2026-10-25: detached worktrees were decided in round 2 (Q2 B, Q3 A). They ship as the separate
  `detached-worktrees` series, and step 12 waits for its rename removal.
- 2026-10-25: the user asked to remove the "active project" tracking too (D7). Steps 4 and 7 were added; the
  series grew from 11 to 13 steps. The voice glossary keeps its current-project trigger.
- 2026-10-26: the user accepted the unexecuted voice cells A4 and C6 as a reduction, and retired the plan
  (retirement round, Q1 A).

## Retirement matrix

Run 2026-10-25 on slot 1 with headless iOS simulators, a fixture HOME under `/tmp` and OpenCode 2.1.4. The run
covered: the step 13 head (`4e1be7ce22`, which contains #2094) against v1.9.1 (`8bfeda9416`), apps and bridges
mixed both ways; a `gh` shim that logs and fails every call; and a v20 data copy seeded with one fixture PR row
before it was migrated.

| Area | Cells | Result |
|---|---|---|
| A. New app on a v1.9.1 bridge | A1 lists, A2 settings card, A3 composer publishes the glossary | Pass |
| | A4 voice uses the glossary | Not executed (no microphone on a headless simulator); reduction accepted 2026-10-26 |
| B. v20 data migrates | B1 copy kept, B2 v21 drops PR data with clean FKs, B3 sessions open, B4 worktrees, B5 archives, B6 dedicated branch | Pass |
| C. New app on the new bridge | C1 no PR mark, C2 no PR row, C3 prompt pull, C4 no `gh` call in 15 minutes, C5 composers publish the glossary | Pass |
| | C6 voice uses the glossary | Not executed (same reason as A4); reduction accepted 2026-10-26 |
| D. v1.9.1 app on the new bridge | D1 card loads, D2 PR row save accepted and inert, D3 pull, D4 dedicated branch, D5 no relay parse warning | Pass |

Findings, neither caused by this plan:

- F1: the v1.9.1 bridge rejects a dedicated-worktree create with a model (409 `staleSessionOptions`). #2094
  fixes it on main.
- F2: on macOS, `/tmp` resolves to `/private/tmp`, and a rescan moves sessions to duplicate resolved-path
  projects. This happens on v1.9.1 too. Fixed by #2103.

The new app logs and ignores `sessions.updated` from v1.9.1 bridges, and nothing is lost.

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
