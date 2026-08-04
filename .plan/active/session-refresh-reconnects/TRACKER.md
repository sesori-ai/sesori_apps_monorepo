# Session Refresh And Reconnect Assessment: Tracker

## Current State

- **Plan slug:** `session-refresh-reconnects`
- **Implementation base:** `main` at
  `2408b57487bb7a6048cf61221bc777b9c81ab70c`
- **Series state:** Step 1/3 PR open
- **Current step:** plan PR
  [#725](https://github.com/sesori-ai/sesori_apps_monorepo/pull/725)
- **Next action:** review and merge Step 1, then implement debug diagnostics and
  the unnecessary-detail-refresh correction in Step 2
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
- [ ] Does the symptom recur after project invalidation stops reloading the full
  detail snapshot?
- [ ] Can an intended reconnect, resume, or stale-data refresh still reproduce a
  disappearing finalized part?
- [ ] Does a post-refresh streaming delta reproduce the known buffer-clear
  suffix regression in realistic use?
- [ ] Does PR #722 eliminate any user-perceived connection stall that was
  independent of the client refresh?

## Option Decisions

| Option | Status | Planned/actual scope | Decision evidence |
|---|---|---:|---|
| Debug refresh diagnostics with `[session-refresh]` | Selected for Step 2 | 45-90 estimated changed lines alone | Needed to identify future refresh cause without guessing |
| Redirect `sessions.updated` to command-only refresh | Selected for Step 2 | 220-400 estimated changed lines combined with diagnostics | Removes wrong full-detail reload while retaining v1.6.0 command compatibility |
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
| [ ] | 1/3 | `opencode-session-reconnects` | `🌱 [session-refresh-reconnects] docs: plan session refresh diagnosis [step 1/3]` | 550-750 | [PR #725](https://github.com/sesori-ai/sesori_apps_monorepo/pull/725) open |
| [ ] | 2/3 | Owner-provided implementation branch | `⚙️ [session-refresh-reconnects] fix(client): stop unnecessary session detail refreshes [step 2/3]` | 220-400 | Blocked on Step 1 merge |
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

- [ ] Add a private closed trigger model; do not branch on log strings.
- [ ] Add debug-only `observed`, `ignored`, `redirected`, `queued`, `coalesced`,
  `started`, and `completed` diagnostics with the exact `[session-refresh]`
  prefix.
- [ ] Treat a missing causal entry as evidence only in a build configured for
  `LogLevel.debug` or `LogLevel.trace`; add no release-visible causal logging or
  production log-level toggle.
- [ ] Correlate start/completion with a Cubit-local refresh ID and duration.
- [ ] Keep prompt/transcript/code/path/command/raw-error data out of the causal
  diagnostics.
- [ ] Stop matching `sessions.updated` from invoking full snapshot reload.
- [ ] Expose targeted command loading through `SessionDetailLoadService`; the
  Cubit owns at most one active and one trailing trigger.
- [ ] Preserve staged command only when still available.
- [ ] Preserve existing commands after refresh failure.
- [ ] Preserve original error and stack context in operational silent-refresh
  failure warnings while keeping bounded causal entries debug-only.
- [ ] Retain initial-load event buffering and v1.6.0 bridge compatibility with a
  dated cleanup comment.
- [ ] Prove normal accepted text sends plus ordinary SSE do not reload.
- [ ] Prove matching project events never fetch or replace transcript state.
- [ ] Prove initial-load command discovery still converges.
- [ ] Prove irrelevant projects, bursts, and failures behave as specified.
- [ ] Prove intended reconnect/resume/stale/command refreshes log their cause and
  retain current behavior.
- [ ] Run targeted tests, strict module analysis, and `git diff --check`.
- [ ] Record actual change count, verification, review, and delivery evidence.

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

## Plan Review

- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-08-04
- **Reviewed scope:** complete `.plan/active/session-refresh-reconnects/`
- **Verdict:** approved; pre-review gate passed
- **Findings applied:** none; the reviewer found no architecture, layering,
  compatibility, ownership, cohesion, naming, or proportionality violations

## PR Review Feedback

- **Valid findings applied:** require a debug-enabled observation build before
  interpreting missing diagnostics; add the bounded `redirected` action;
  preserve original error/stack context in operational silent-refresh failures;
  route targeted command loading through `SessionDetailLoadService`; and require
  one deliberately exercised intended full refresh before retirement.
- **Duplicate threads:** the redirected-action and Service-boundary findings were
  each reported independently by two bot reviewers and share one correction.
- **Not applied:** the claim that architecture plan review is forbidden for a
  documentation-only plan conflicts with root guidance. This plan defines an
  architecture-bearing client flow and deferred wire boundaries, so
  `aristotle-plan-review` was correctly invoked and approved it.

## Verification Log

- **Step 1 documentation validation:** `git diff --check` passed; plan/tracker
  slug, exact titles, three-step denominator, line targets, selected options,
  and diagnostic prefix agree
- **Step 1 changed lines:** 665 documentation-only lines including delivery metadata
- **Step 1 PR:** [#725](https://github.com/sesori-ai/sesori_apps_monorepo/pull/725)
  open from `6a6e8cf9`
- **Step 2 implementation:** pending
- **Step 2 verification:** pending
- **Step 2 review:** pending
- **Step 2 PR:** pending
- **Step 3 evidence assessment:** pending
- **Final disposition:** pending
