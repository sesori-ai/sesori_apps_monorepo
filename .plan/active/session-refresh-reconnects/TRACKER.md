# Session Refresh And Reconnect Assessment: Tracker

## Current State

- **Plan slug:** `session-refresh-reconnects`
- **Implementation base:** `main` at
  `7b2fa65ad1b210dd6a52714e14ce9b5951d0aa68`
- **Series state:** Step 1/3 merged; Step 2/3 PR open
- **Current step:** Step 2 implementation PR
  [#734](https://github.com/sesori-ai/sesori_apps_monorepo/pull/734)
- **Next action:** review and merge Step 2, then collect Step 3 observation evidence
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
| Debug refresh diagnostics with `[session-refresh]` | Implemented in Step 2 | Included in 846 code/test changed lines before delivery metadata | Every bounded trigger/action/result is searchable without payload data |
| Redirect `sessions.updated` to command-only refresh | Implemented in Step 2 | Included in 846 code/test changed lines before delivery metadata | Preserves v1.6.0 command discovery without replacing detail state |
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
| [ ] | 2/3 | `opencode-session-reconnects` | `⚙️ [session-refresh-reconnects] fix(client): stop unnecessary session detail refreshes [step 2/3]` | 220-400 | [PR #734](https://github.com/sesori-ai/sesori_apps_monorepo/pull/734) open |
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
- [x] Add debug-only `observed`, `ignored`, `redirected`, `queued`, `coalesced`,
  `started`, and `completed` diagnostics with the exact `[session-refresh]`
  prefix.
- [x] Treat a missing causal entry as evidence only in a build configured for
  `LogLevel.debug` or `LogLevel.trace`; add no release-visible causal logging or
  production log-level toggle.
- [x] Correlate start/completion with a Cubit-local refresh ID and duration.
- [x] Keep prompt/transcript/code/path/command/raw-error data out of the causal
  diagnostics.
- [x] Stop matching `sessions.updated` from invoking full snapshot reload.
- [x] Expose targeted command loading through `SessionDetailLoadService`; the
  Cubit owns at most one active and one trailing trigger.
- [x] Preserve staged command only when still available.
- [x] Preserve existing commands after refresh failure.
- [x] Preserve original error and stack context in operational silent-refresh
  failure warnings while keeping bounded causal entries debug-only.
- [x] Retain initial-load event buffering and v1.6.0 bridge compatibility with a
  dated cleanup comment.
- [x] Prove normal accepted text sends plus ordinary SSE do not reload.
- [x] Prove matching project events never fetch or replace transcript state.
- [x] Prove initial-load command discovery still converges.
- [x] Prove irrelevant projects, bursts, and failures behave as specified.
- [x] Prove intended reconnect/resume/stale/command refreshes log their cause and
  retain current behavior.
- [x] Run targeted tests, strict module analysis, and `git diff --check`.
- [x] Record actual change count, verification, review, and delivery evidence.

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

## Step 2 Architecture Review

- **Reviewer:** `aristotle-impl-review`
- **Date:** 2026-08-04
- **Reviewed scope:** Step 2 production changes in `SessionDetailCubit` and
  `SessionDetailLoadService`
- **Pass 1 findings applied:** require non-null plugin identity at the Service
  boundary and retain failed/connection-blocked command invalidations.
- **Pass 2 finding applied with user approval:** generation-fence targeted
  command publication against a subsequently applied full command-bearing
  snapshot.
- **Final status:** both allowed review passes rejected before their findings
  were fixed. The user selected the recommended generation fence; all findings
  are implemented and verified, with no third review under the two-pass cap.

## Verification Log

- **Step 1 documentation validation:** `git diff --check` passed; plan/tracker
  slug, exact titles, three-step denominator, line targets, selected options,
  and diagnostic prefix agree
- **Step 1 changed lines:** 665 documentation-only lines including delivery metadata
- **Step 1 PR:** [#725](https://github.com/sesori-ai/sesori_apps_monorepo/pull/725)
  merged
- **Step 2 implementation:** debug refresh traces, targeted command-catalog
  invalidation, bounded retry/coalescing, and full-snapshot generation fencing
- **Step 2 scope variance:** 932 total changed lines including tracker metadata
  (846 code/test) versus 220-400 planned; architecture findings added non-null
  identity, retained invalidations, bounded retries, and generation fencing
- **Step 2 verification:** `dart test` passed all 1,008 `module_core` tests;
  `dart analyze --fatal-infos` and `git diff --check` passed
- **Step 2 review:** two architecture passes completed; all findings fixed under
  the user-approved generation-fence decision and two-pass review cap
- **Step 2 PR:** [#734](https://github.com/sesori-ai/sesori_apps_monorepo/pull/734) open
- **Step 3 evidence assessment:** pending
- **Final disposition:** pending
