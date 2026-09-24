# Quota auto continuation tracker

Plan: [PLAN.md](PLAN.md). Series slug: `quota-auto-continuation`. Total: **7 PRs**.

| Step | State | PR / evidence |
|---|---|---|
| 1 — Plan and support audit | Merged | [#1601][plan-pr]; audit and reviewed plan. |
| 2 — Quota normalization | Merged | [#1641][normalization-pr]; typed terminal events and Claude/Pi reporting. |
| 3 — Durable contracts and readiness | Merged | [#1649][foundation-pr]; durable state and readiness. |
| 4 — Bridge scheduler | In review | [#1654][scheduler-pr]; route, views, cancellation and dispatch. |
| 5 — Shared chat controls | In progress locally | Shared hint, acknowledged indicator and three-dot toggle on phone and desktop. |
| 6 — Regression reconciliation | Not started | Complete affected feature docs and capability matrix. |
| 7 — L4 verification and retirement | Not started | All recorded boundary/platform/provider coverage must pass. |

[plan-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1601
[normalization-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1641
[foundation-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1649
[scheduler-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1654

## Confirmed user decisions

- Auto continuation remains enabled for subsequent quota interruptions in the
  same session, until disabled.
- The chat session's top-right three-dot menu must expose enable/disable.
- Start with per-session opt-in; global configuration is outside this version.

## Proposed implementation defaults

- Two-minute buffer after the reported reset; ordinary prompt text `Continue.`.
- Paused sessions recheck after five minutes, checking readiness before history.
- Durable bridge-owned preference and pending observation; no client timer.
- One attempt per observed reset, with an explicitly accepted possible missed
  attempt if the bridge crashes between consumption and backend acceptance.
- No guessed reset for an unrecognized error/provider or imported old history.
- Readiness is checked before and after history; native work beginning after
  the final check can still race with normal prompt acceptance. No atomic native
  admission protocol is included in v1.

## Validation record

- Read-only local session evidence: complete, scope and limits in EVIDENCE.md.
- Architecture plan review: specificity rejection clarified; second pass
  produced concrete findings, applied directly. Corrected version not re-reviewed.
- PR feedback: clarified reset-based due selection, persisted pause recheck delay,
  readiness-before-history, and wrapped the long documentation tables.
- Follow-up feedback: explicit per-plugin ownership, repository-owned selection,
  service-owned scheduled transitions, and durable cancellation before Stop/archive.
- Further review: corrected Codex evidence status, single-owner plugin decisions,
  and awaited quota handling in the existing event/handoff order.
- Plan links / diff checks: passed on the final documentation revision.
- Step 2: focused Claude/Pi lifecycle and parser tests and core routing tests
  passed; owning packages analyze cleanly. Published Pi 0.85.1 and 0.84.1
  synthetic-provider RPC probes verified terminal settlement and retry ordering.
- Step 2 architecture implementation review: approved; plugin normalization and
  existing session services retain their ownership boundaries.
- Step 2 review: preserve quota observations through trailing Claude stream
  frames; cover both trailing frames and a superseding message. Commit portable
  Pi RPC probes and separate release-critical from extended regression coverage.
- Step 3/4 split: measured bridge work exceeded the authored review budget, so storage/wire/readiness
  are published separately from scheduling. Architecture and product scope remain unchanged.
- Step 3 architecture implementation review: approved twice, including the focused
  mandatory-readiness and off-isolate lookup follow-up; no outstanding findings.
- Step 3 local validation: 400 focused tests pass at the pinned readiness checkpoint;
  the five-test repository suite also passes after the JSON-boundary follow-up.
  Bridge/shared/client analysis and documentation links pass. Measured commits,
  trees, working folders and exact commands are in EVIDENCE.md.
- Step 3 Pi follow-up: a primed directory no longer proves persisted readiness;
  the reproduced regression and all 83 Pi service/catalog tests pass after the fix.
- Step 3 merged after 33/33 checks passed. The scheduler branch incorporates the
  landed commit without changing its verified production/test tree.
- Step 4 local implementation: timer, route, projections, ordered observations,
  normal dispatch and durable cancellation are implemented. Focused service,
  routing, cancellation, event and composed handoff checks pass; app analysis is
  clean. Architecture implementation review approved the complete step 4 diff;
  controls and live provider recovery are not implemented/verified yet.
- Step 5 local controls are implemented; focused validation and rendered review are in progress.
- Live scheduled continuation: not run; scheduler is in review and controls remain local.
- Final L4 matrix: not run. Do not retire this plan on the plan PR's checks.
