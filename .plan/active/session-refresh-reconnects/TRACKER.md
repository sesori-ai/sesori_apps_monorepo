# Session Refresh And Reconnect Assessment: Tracker

## 2026-09-04 follow-up evidence

The [periodic-cleanup investigation](../periodic-cleanup/PLAN.md) reproduces the
two transcript risks below through the intended stale-data refresh path against
`480d82f090`: an already-loaded message loses a live part, and the next streamed
delta loses its pre-refresh prefix. Diagnostic patches and exact results are
[recorded there](../periodic-cleanup/evidence/README.md). Proposed cleanup steps
2–3 own these fixes, pending scope acceptance. This is a handoff of confirmed
issues, not completion of this plan's live observation/retirement requirements.

The historical sections below describe an earlier baseline: current code no
longer uses `sessions.updated` to trigger full-detail refresh. Do not repeat
that old proposed trigger change. PR/observation states below have not been
re-audited as part of this handoff.

## Current State

- **Plan slug:** `session-refresh-reconnects`
- **Implementation base:** `main` at
  `5aaf979dd25b645a69964d0211eda5cd92126037`
- **Series state:** Step 1/3 merged; Step 2/3 logging PR open
- **Current step:** diagnostic logging PR
  [#734](https://github.com/sesori-ai/sesori_apps_monorepo/pull/734)
- **Next action:** merge logging-only Step 2, reproduce the refresh in a
  debug-enabled build, then select any behavioral or maintainability follow-up
- **Searchable diagnostic prefix:** `[session-refresh]`
- **External overlap:** PR
  [#722](https://github.com/sesori-ai/sesori_apps_monorepo/pull/722) owns bridge
  concurrent relay request completion; do not duplicate it

## Confirmed Evidence

- [x] A normal `SessionDetailCubit.sendMessage` does not directly call a refresh
  or reconnect path.
- [x] `isRefreshing=true` is emitted only by the silent snapshot refresh.
- [x] Matching project-wide `sessions.updated` currently starts a complete
  session-detail snapshot even though the event contract describes PR/session-
  list invalidation.
- [x] PR synchronization emits `sessions.updated` while viewed projects are
  refreshed.
- [x] ACP/Cursor command discovery also reuses `sessions.updated`.
- [x] Live SSE mutations can be overwritten by the older multi-request snapshot
  that completes afterward.
- [x] Refresh clears the mutable streaming buffer and can make a later delta
  publish only its suffix.
- [x] Historical bridge logs show relay reconnects, but not correlated with the
  exact reported send.
- [x] PR #722 addresses proven bridge relay head-of-line blocking but does not
  change client refresh triggers or snapshot reconciliation.

## Open Questions

- [ ] Which exact trigger caused the originally observed OpenCode detail refresh?
- [ ] Does the reported symptom correlate with the existing full-detail refresh
  after project invalidation?
- [ ] Can an intended reconnect, resume, or stale-data refresh still reproduce a
  disappearing finalized part?
- [ ] Does a post-refresh streaming delta reproduce the known buffer-clear
  suffix regression in realistic use?
- [ ] Does PR #722 eliminate any user-perceived connection stall that was
  independent of the client refresh?

## Option Decisions

| Option | Status | Planned/actual scope | Decision evidence |
|---|---|---:|---|
| Debug refresh diagnostics with `[session-refresh]` | Implemented in Step 2 | 322 client changed lines: 201 production and 121 tests | Needed to identify future refresh cause without guessing |
| Redirect `sessions.updated` to command-only refresh | Deferred | 220-400 prior estimate | Do not add coordination state before logs identify the trigger and maintainable ownership is designed |
| Transcript-only mutation epoch | Deferred | 145-270 estimated | Do not protect only the observed field before testing intended refreshes |
| Grouped snapshot reconciliation | Deferred | 440-810 estimated | Preferred client hardening only if intended refresh reproduces state rollback |
| Apply-live event journal/replay | Rejected | 370-670 estimated | Non-idempotent deltas and modal side effects are unsafe without a cursor |
| Targeted session-options wire event | Deferred | 600-1,210 estimated including generated code | Cleaner semantics do not yet justify compatibility and wire cost |
| Versioned coherent session synchronization | Deferred | 1,600-3,450 estimated including generated code | Separate plan only with replay-gap/coherency evidence |
| Concurrent relay request completion | Owned by PR #722 | 1,185 current PR changed lines | Do not duplicate bridge orchestration work |
| Generic request timeout or heartbeat tuning | Rejected | Not estimated | Does not fix invalid refresh ownership or safely cancel writes |

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [x] | 1/3 | `opencode-session-reconnects` | `🌱 [session-refresh-reconnects] docs: plan session refresh diagnosis [step 1/3]` | 550-750 | [PR #725](https://github.com/sesori-ai/sesori_apps_monorepo/pull/725) merged |
| [ ] | 2/3 | `opencode-session-reconnects` | `🌿 [session-refresh-reconnects] chore(client): trace session detail refresh causes [step 2/3]` | 120-250 | [PR #734](https://github.com/sesori-ai/sesori_apps_monorepo/pull/734) open |
| [ ] | 3/3 | Owner-provided assessment branch | `🌱 [session-refresh-reconnects] docs: assess session refresh evidence [step 3/3]` | 80-200 | Blocked on Step 2 observation evidence |

## Step 1 Checklist

- [x] Record confirmed versus hypothesized causes.
- [x] Record PR #722 overlap and non-overlap.
- [x] Lock the exact debug prefix `[session-refresh]`.
- [x] Record the selected Step 2 fix and compatibility boundary.
- [x] Record every considered option with line estimate and current status.
- [x] Define evidence fields and decision rules for recurrence.
- [x] Run `aristotle-plan-review` and apply valid findings directly.
- [x] Run `git diff --check` and plan consistency validation.
- [x] Commit, push, open the Step 1 PR, and record its URL/base/change count.

## Step 2 Checklist

- [x] Add a private closed trigger model; do not branch on log strings.
- [x] Add debug-only `observed`, `ignored`, `queued`, `coalesced`,
  `started`, and `completed` diagnostics with the exact `[session-refresh]`
  prefix.
- [x] Treat a missing causal entry as evidence only in a build configured for
  `LogLevel.debug` or `LogLevel.trace`; add no release-visible causal logging or
  production log-level toggle.
- [x] Correlate start/completion through the existing single active refresh and
  report duration from a local `Stopwatch`.
- [x] Keep prompt/transcript/code/path/command/raw-error data out of the causal
  diagnostics.
- [x] Preserve every existing refresh trigger, request, queue, and state update.
- [x] Add no mutable Cubit coordination fields.
- [x] Preserve original error and stack context in operational silent-refresh
  failure warnings while keeping bounded causal entries debug-only.
- [x] Prove matching and irrelevant project invalidations log distinct outcomes
  while retaining the current full-refresh behavior.
- [x] Prove intended reconnect/resume/stale/command refreshes log their cause and
  retain current behavior.
- [x] Run the full relevant test matrix, strict module analysis, and
  `git diff --check` after the final scope reduction.
- [x] Record actual change count, verification, and review evidence; delivery
  completes after the reduced commit is pushed and CI passes.

## Observation Log

Do not record prompts, transcript content, source paths, project names, or raw
tokens.

| Date | Build | Harness | Input kind | Visible symptom | `[session-refresh]` sequence | PR #722 present | Decision |
|---|---|---|---|---|---|---|---|
| Pending | Pending | Pending | Plain text or slash command | Pending | Pending | Pending | Pending |

## Step 3 Decision Checklist

- [ ] Record representative ordinary-send observations after Step 2.
- [ ] Record at least one deliberately exercised intended reconnect/resume/stale
  full refresh in a debug-enabled build before retirement.
- [ ] If content disappears, tie it to one bounded diagnostic trigger before
  selecting reconciliation.
- [ ] Mark every option implemented, rejected, deferred, superseded, or handed
  to a named follow-up plan.
- [ ] Correct direct Step 2 regressions only; do not expand Step 3 into a larger
  unreviewed implementation.
- [ ] Retire this plan or record the reviewed follow-up-plan handoff.

## Maintainability Follow-Up

- PR #734 deliberately adds no mutable `SessionDetailCubit` fields.
- First low-risk cleanup candidate: replace the five `late final
  StreamSubscription` fields with one final `CompositeSubscription`, matching
  `SessionListCubit`, `ProjectListCubit`, and existing module services.
- Before changing refresh behavior, model refresh scheduling and
  connection/lifecycle/view-reassertion coordination as separate sealed state
  machines rather than adding booleans, nullable futures, timers, generations,
  or flags that permit invalid combinations.
- Keep that refactor out of the logging PR. Size and review it separately after
  diagnostic evidence identifies which behavior must be retained or changed.

## Step 2 Scope Correction

- The first implementation of PR #734 combined logging with targeted command
  refresh, retries, and generation fencing. It added seven mutable Cubit fields
  and produced eight bot review findings plus a downstream mobile-test failure.
- The user rejected that direction because the independent mutable fields made
  valid state combinations impractical to reason about.
- PR #734 is now logging-only. All targeted command-refresh production code,
  result types, retries, generation fencing, compatibility logic, and behavior
  tests were removed before delivery.
- Existing `sessions.updated` full-refresh behavior remains intentionally
  unchanged so the diagnostic build can establish whether it causes the report.

## Plan Review

- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-08-04
- **Reviewed scope:** complete `.plan/active/session-refresh-reconnects/`
- **Verdict:** approved; pre-review gate passed
- **Findings applied:** none; the reviewer found no architecture, layering,
  compatibility, ownership, cohesion, naming, or proportionality violations

## Superseded PR Review Feedback

- **Retained findings:** require a debug-enabled observation build before
  interpreting missing diagnostics, preserve original error/stack context in
  operational silent-refresh failures, and deliberately exercise one intended
  full refresh before retirement.
- **Removed findings:** redirected-action, targeted-command Service ownership,
  retry, generation-fencing, and command-refresh lifecycle findings apply only
  to the discarded behavior-changing implementation.
- **Not applied:** the claim that architecture plan review is forbidden for a
  documentation-only plan conflicts with root guidance. This plan defines an
  architecture-bearing client flow and deferred wire boundaries, so
  `aristotle-plan-review` was correctly invoked and approved it.
- **Superseded Step 2 direction:** the later user decision requires diagnostics
  before any behavior change. Command-only refresh findings remain historical
  input for a future maintainability plan, not scope for PR #734.

## Verification Log

- **Step 1 documentation validation:** `git diff --check` passed; plan/tracker
  slug, exact titles, three-step denominator, line targets, selected options,
  and diagnostic prefix agree
- **Step 1 changed lines:** 665 documentation-only lines including delivery metadata
- **Step 1 PR:** [#725](https://github.com/sesori-ai/sesori_apps_monorepo/pull/725)
  merged
- **Step 2 implementation:** logging-only diagnostics with no new mutable Cubit
  fields and no refresh behavior change
- **Step 2 changed lines:** 577 total: 322 client lines (201 production and 121
  tests) plus 255 scope-correction plan/tracker lines
- **Step 2 verification:** `dart analyze --fatal-infos` and all 1,005
  `module_core` tests passed; all 43 downstream mobile session-detail tests
  passed; `git diff --check` passed
- **Step 2 review:** prior architecture findings became obsolete when the
  command-refresh implementation was removed; logging-only work is not
  architecture-bearing
- **Step 2 PR:** [#734](https://github.com/sesori-ai/sesori_apps_monorepo/pull/734) open
- **Step 3 evidence assessment:** pending
- **Final disposition:** pending
