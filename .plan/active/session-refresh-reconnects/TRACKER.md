# Session Refresh And Reconnect Assessment: Tracker

## Current state — 2026-09-04

- **Plan slug:** `session-refresh-reconnects`; original diagnostic baseline:
  `5aaf979dd25b645a69964d0211eda5cd92126037`.
- **Series state:** Steps 1–2 merged; Step 3 live observation/assessment pending.
  Logging PR [#734](https://github.com/sesori-ai/sesori_apps_monorepo/pull/734)
  merged 2026-08-04 as `6e24da2558b2b11eed2f0dbcddeaeebb49377d08`.
- **Next action:** record representative ordinary sends and an intended
  reconnect/resume/stale refresh in a debug-enabled build, then complete the
  evidence assessment. Do not wait for or recreate the merged logging PR.
- **External overlap:** relay request completion PR
  [#722](https://github.com/sesori-ai/sesori_apps_monorepo/pull/722) merged
  2026-08-04 as `2fd3423ebb426a4889ca6d87a008e45240f7e42d`.
- **Current client behavior:** at `480d82f090`, `SessionDetailCubit` ignores
  `SesoriSessionsUpdated`; dedicated `SesoriSessionOptionsUpdated` events invoke
  `_onSessionOptionsUpdated`. The old project-invalidation full-refresh trigger
  and proposed command-only replacement are superseded, not outstanding work.
- **Searchable diagnostic prefix:** `[session-refresh]`; missing entries are
  evidence only in a build configured for debug/trace logging.

## Confirmed follow-up and remaining uncertainty

The [periodic-cleanup investigation](../periodic-cleanup/PLAN.md) reproduces two
transcript failures through the intended stale-data refresh path against
`480d82f090`: an already-loaded message loses a live part, and the next streamed
delta loses its pre-refresh prefix. Diagnostic patches and results are
[recorded there](../periodic-cleanup/evidence/README.md). Proposed cleanup steps
2–3 own those fixes, pending implementation scope acceptance. They preserve
active streaming text, reconcile completed snapshot catch-up and merge
before/live/fetched transcript values without an event journal.

Normal `sendMessage` does not directly refresh or reconnect; `isRefreshing=true`
comes from silent snapshot refresh. Historical reconnect logs did not identify
the trigger of the originally reported send. Its exact live cause, realistic
frequency and any independent connection-stall improvement from #722 remain
unverified. Unit reproductions establish the two follow-up bugs, not completion
of this plan's live observation/retirement requirements. The original PLAN.md
records the August diagnostic design; this tracker owns current execution state.

## Option dispositions

| Option | Current disposition | Evidence / reopening condition |
| --- | --- | --- |
| Debug refresh diagnostics | Delivered by merged #734 | Logging-only; historical validation below. |
| Redirect `sessions.updated` to command-only refresh | Superseded by subsequent implementation | Current detail ignores this event; do not implement the old proposal. |
| Targeted session-options wire event | Implemented subsequently | Current dedicated options event and handler replace the old deferred proposal. |
| Transcript reconciliation | Handed to periodic-cleanup steps 2–3 | Two diagnostics fail through intended refresh; other snapshot groups remain deferred. |
| Transcript-only mutation epoch | Deferred | No additional epoch needed for the proposed before/live/fetched merge. |
| Apply-live event journal/replay | Rejected | Deltas and modal effects are not safely replayable without a cursor. |
| Versioned coherent session synchronization | Deferred | Requires separate evidence of material replay gaps/coherency needs. |
| Concurrent relay request completion | Delivered externally by #722 | Do not duplicate merged bridge orchestration work; live effect remains unverified. |
| Generic request timeout or heartbeat tuning | Rejected | Does not establish refresh ownership or cancel writes safely. |

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [x] | 1/3 | `opencode-session-reconnects` | `🌱 [session-refresh-reconnects] docs: plan session refresh diagnosis [step 1/3]` | 550-750 | [PR #725](https://github.com/sesori-ai/sesori_apps_monorepo/pull/725) merged |
| [x] | 2/3 | `opencode-session-reconnects` | `🌿 [session-refresh-reconnects] chore(client): trace session detail refresh causes [step 2/3]` | 120-250 | [PR #734](https://github.com/sesori-ai/sesori_apps_monorepo/pull/734) merged 2026-08-04 |
| [ ] | 3/3 | Owner-provided assessment branch | `🌱 [session-refresh-reconnects] docs: assess session refresh evidence [step 3/3]` | 80-200 | Pending live observation and assessment |

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
- [x] Tie the reproduced transcript failures to the intended stale-data trigger
  and hand their fixes to periodic-cleanup steps 2–3. Live observations remain
  required; unit diagnostics do not satisfy that boundary.
- [ ] Mark every option implemented, rejected, deferred, superseded, or handed
  to a named follow-up plan.
- [ ] Correct direct Step 2 regressions only; do not expand Step 3 into a larger
  unreviewed implementation.
- [ ] Retire this plan or record the reviewed follow-up-plan handoff.

## Historical scope and review

PR #734's initial targeted-command refresh implementation was withdrawn after
review and the user's rejection of seven extra mutable Cubit fields. The merged
PR contained logging only and retained the refresh behavior at its August
baseline. Later removal of the `sessions.updated` trigger is separate work; it
must not be undone to match that historical checklist.

The August plan review (`aristotle-plan-review`, 2026-08-04) approved the original
diagnostic scope. It is not approval of subsequent cleanup implementation.
Keep any future coordination refactor proportional to evidence and separately
scoped; the previously suggested subscription consolidation or new state
machines are not prerequisites for the handed-off fixes.

## Historical delivery verification (2026-08-04)

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
- **Step 2 PR:** [#734](https://github.com/sesori-ai/sesori_apps_monorepo/pull/734) merged 2026-08-04
- **Step 3 evidence assessment:** pending
- **Final disposition:** pending
