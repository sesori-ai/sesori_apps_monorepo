# Quota auto continuation tracker

Plan: [PLAN.md](PLAN.md). Series slug: `quota-auto-continuation`. Total: **7 PRs**.

| Step | State | PR / evidence |
|---|---|---|
| 1 — Plan and support audit | Merged | [#1601][plan-pr]; audit and reviewed plan. |
| 2 — Quota normalization | Merged | [#1641][normalization-pr]; typed terminal events and Claude/Pi reporting. |
| 3 — Durable contracts and readiness | Merged | [#1649][foundation-pr]; durable state and readiness. |
| 4 — Bridge scheduler | Merged | [#1654][scheduler-pr]; route, views, cancellation and dispatch. |
| 5 — Shared chat controls | Merged | [#1656][controls-pr]; shared hint, indicator and three-dot toggle. |
| 6 — Regression reconciliation | Merged | [#1659][regression-pr]; feature docs, provider scope and proof boundaries. |
| 7 — Verification and Pi prompt fix | Partial | [#1664][verification-pr]; [matrix](VERIFICATION.md). |

[plan-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1601
[normalization-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1641
[foundation-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1649
[scheduler-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1654
[controls-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1656
[regression-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1659
[verification-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1664

## Confirmed user decisions

- Auto continuation remains enabled for subsequent quota interruptions in the
  same session, until disabled.
- The chat session's top-right three-dot menu must expose enable/disable.
- Start with per-session opt-in; global configuration is outside this version.
- On 2026-09-24, leave the running desktop app untouched and record macOS QA
  as blocked. The plan remains active.

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
- Step 4 merged after 20/20 checks passed and the final bot review approved.
  A regression fix preserves the created session response if continuation projection fails.
- Step 5 controls: 384 focused tests pass; all four owning client modules analyze
  cleanly. Architecture review approved. Fixture-only before/after and flow media
  were inspected and published; affected screen tests pass after integration with main.
- Step 5 CI follow-up: corrected the shared mobile routing fixture; all 51 affected
  routing/split-screen tests pass and mobile analysis is clean.
- Step 5 review fixes preserve acknowledgements during reload, keep unavailable
  controls honest and reachable, and classify route/session errors separately.
  Main integration passed 237 core, 135 mobile and 9 desktop tests; the unchanged
  shared UI suite passed 13 tests before integration. All four analyzers pass.
- Step 5 merged after 20/20 checks and the final review approved the head;
  the terminal report confirmed 21/21 checks. CI's client-workspace analyzer
  also passes after its directional-inset lint correction.
- Step 6: documentation reconciles current support, cumulative L1–L4
  boundaries and natural-quota-only live verification. Local links and whitespace checks pass.
- Step 6 merged after both documentation findings were addressed; terminal CI
  confirmed 9/9 checks and the final Cubic review approved the head.
- Step 7 composed bridge checks pass: two encrypted relay clients observe the
  same setting; a headless timed send uses the real prompt service; a disk-backed
  restart sends overdue work once and a second restart does not replay it.
- Step 7 native replay found Pi rejecting its persisted `off` thinking level
  for a non-reasoning model. The focused regression failed before the fix;
  all 21 plugin tests and Pi analysis pass after accepting that native default.
  Pinned Pi 0.85.1 and 0.84.1 each pass four synthetic settlement probes.
- iOS native controls, buffered local time, persistence across bridge restart,
  ordinary automatic `Continue.`/fixture response and unknown-reset state pass
  through a real dev-account bridge and relay. This is synthetic-provider
  replay, not live-provider quota recovery.
- Android notice/menu/message-echo smoke passes after an emulator restart
  recovered DNS/WebSocket failures. Android enable reaches iOS, and iOS
  disable reaches Android; bridge reads confirm both authoritative outcomes.
- Step 7 review follow-up: implicit `off` requires a complete catalog, preserving
  rejection when thinking discovery fails. The new regression failed before the
  guard; all 22 Pi tests pass afterward. Both composed tests pass with exact
  injected acceptance timestamps; both owning packages analyze cleanly.
- Final L4 matrix: partial. See VERIFICATION.md; the plan cannot be retired yet.
