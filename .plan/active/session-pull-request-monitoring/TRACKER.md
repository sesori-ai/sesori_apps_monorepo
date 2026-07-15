# Session Pull Request Monitoring: Tracker

## Plan State

- **Status:** Approved — plan PR #436 merged
- **Implementation base:** `main`
- **Plan slug:** `session-pull-request-monitoring`
- **Plan PR:** https://github.com/sesori-ai/sesori_apps_monorepo/pull/436
- **Execution ordering:** Complete this plan before resuming parallel-plugin Stage 2.

## Current Pointer

- **Stage:** S01 — Additive contracts
- **Wave:** W01
- **Next action:** Pin the then-current `main` baseline for S01/W01 and implement S01-W01-P01 with `sesori-plan-worker`.

## Plan Review

- **Verdict:** Approved after canonical plan-PR feedback review
- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-07-15
- **Reviewed commit:** `fdf2fd45d50f0581bdac6cb2e8e16f0188d0c871` plus the complete uncommitted plan-tree update

## Wave Baselines

| Stage | Wave | Repository | Base | Pinned SHA | Drift Decision |
|---|---|---|---|---|---|

## PR Steps

| Done | ID | Stage | Wave | PR | Branch | Notes |
|---|---|---|---|---|---|---|
| [ ] | S01-W01-P01 | S01 | W01 | — | `plan/session-pull-request-monitoring/s01-w01-p01-additive-pr-monitor-contracts` | Additive shared contracts; no behavior activation. |
| [ ] | S02-W01-P01 | S02 | W01 | — | `plan/session-pull-request-monitoring/s02-w01-p01-durable-branch-observation` | Exact directory and filesystem-driven branch history. |
| [ ] | S02-W02-P01 | S02 | W02 | — | `plan/session-pull-request-monitoring/s02-w02-p01-authored-pr-refresh` | Authored identity-scoped live cache and dispatcher. |
| [ ] | S02-W03-P01 | S02 | W03 | — | `plan/session-pull-request-monitoring/s02-w03-p01-terminal-archive-snapshots` | Irreversible PR stop and immutable archived snapshot. |
| [ ] | S02-W04-P01 | S02 | W04 | — | `plan/session-pull-request-monitoring/s02-w04-p01-view-scoped-pr-polling` | Project presence and adaptive bridge scheduling. |
| [ ] | S03-W01-P01 | S03 | W01 | — | `plan/session-pull-request-monitoring/s03-w01-p01-project-view-declarations` | Client list/detail presence lifecycle. |
| [ ] | S03-W02-P01 | S03 | W02 | — | `plan/session-pull-request-monitoring/s03-w02-p01-collapsed-pr-history-ui` | Collapsed history UI, integration, and dead-sync cleanup. |

## Manual Checkpoints

| User | Worker | ID | Check | Evidence |
|---|---|---|---|---|
| [ ] | [ ] | S03-W03-M01 | Real-repository branch/PR/presence/archive end-to-end check | — |

## Blockers and Staleness

- No implementation blocker is known.
- Parallel-plugin implementation is intentionally paused before Stage 2 while this plan executes. It requires explicit stale-plan re-review after this plan closes because both workstreams touch session schema, repositories, archive, and event flow.
- The latest audited `main` tip is `e766684e0fdc22256419b7b99691021c9f14732d` (2026-07-14T17:59:08+03:00). Workers must assess drift and pin each wave's actual current tip before branching.

## Findings and Plan Deltas

- **2026-07-15 — Feedback review approval:** `aristotle-plan-review` approved the complete canonical tree after all current account/repository, dispatcher, scheduler, and client declaration corrections; no architecture violations remained.
- **2026-07-15 — Canonical review hardening:** Made relative git `HEAD` paths checkout-relative before normalization; bound live/archived cache visibility to account, canonical repository, and verified project path; suspended live visibility once identity failure/change is detected while preserving cache-first reads; bounded disappeared-open finalization; correlated coalesced completions; prevented overdue all-state zero-delay loops; documented the pre-filter authored-row cap; and added bounded retries for lost connected project/null declarations. Retained the approved acyclic `SessionArchiveService -> WorktreeCleanupService` collaborator because it owns a standalone multi-caller policy and does not depend back on archive.
- **2026-07-14 — Optimistic plan-PR state:** Plan-branch tracker state now reflects the post-merge result immediately after PR creation; the optimistic state reaches `main` only when the plan PR merges.
- **2026-07-14 — Legacy cleanup:** Removed superseded `docs/pr-monitor/PLAN.md`; `.plan/active/session-pull-request-monitoring/` is the sole plan authority.
- **2026-07-14 — Legacy-thread assessment:** Four bot threads on superseded `docs/pr-monitor/PLAN.md` required no canonical change: owner-scoped multi-user cache metadata is explicitly speculative, direct detail has no PR presentation, intermediate-wave historical freshness is not a shipped regression and remains explicitly refreshable, and unverifiable legacy archived cache rows intentionally fail closed rather than guessing GitHub authorship. Full plan review remained approved.
- **2026-07-14 — Plan delivery:** The approved canonical plan tree was pushed to plan PR https://github.com/sesori-ai/sesori_apps_monorepo/pull/436.
- **2026-07-14 — Pre-delivery approval refresh:** `aristotle-plan-review` approved the complete tree against latest audited `main` tip `e766684e0fdc22256419b7b99691021c9f14732d`; architecture, compatibility, migrations, lifecycle ownership, verification, tracker state, and audit references were execution-ready.
- **2026-07-14 — Pre-delivery drift audit:** `main` advanced from `2f4adf2dec643f44db231f88d09672499a8a8619` to `e766684e0fdc22256419b7b99691021c9f14732d` only through iOS TestFlight workflow/Fastfile fixes. No planned path, contract, schema, architecture, or product decision changed.
- **2026-07-14 — Full-plan approval:** `aristotle-plan-review` approved the complete canonical tree after the architecture corrections below; no violations remained across bridge, shared, or client workspaces.
- **2026-07-14 — Review correction:** Made `Orchestrator.compose` the sole bridge layer composer and `BridgeRuntime` lifecycle-only; moved shared worktree-cleanup policy out of routing into `WorktreeCleanupService`; removed touched archive routing/DAO/filesystem bypasses; and introduced generic Layer-0 `RelayControlClient` so view APIs construct feature messages without calling `ConnectionService` transport methods.
- **2026-07-14 — Canonical migration:** Reframed the legacy single-file plan as a three-stage, seven-PR `.plan` tree with strict non-stacked waves, one advisory manual checkpoint, per-step commands, explicit baseline metadata, and compatibility cleanup markers.
- **2026-07-14 — Interview delta:** PR monitoring runs before parallel-plugin Stage 2; `pullRequestHistory` now uses an honest non-null empty default rather than nullable boundary state; authored all-state discovery supports 1,000 rows with a 1,001st-row truncation signal and non-destructive partial semantics.
- **2026-07-14 — Baseline audit:** Current `main` advances past the legacy plan audit only through unrelated prompt-sheet routing. Current session loading is already cache-first for normal loads and waits up to five seconds only on explicit pull-to-refresh, so S03 preserves that shipped behavior instead of planning a redundant cutover.
