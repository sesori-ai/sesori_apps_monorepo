# Session Refresh And Reconnect Assessment

## Status

- **Plan slug:** `session-refresh-reconnects`
- **Status:** Active - Step 1/3 plan documentation
- **Plan date:** 2026-08-04
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Current implementation base:** `main` at
  `2408b57487bb7a6048cf61221bc777b9c81ab70c`
- **Current branch:** `opencode-session-reconnects`
- **Plan PR:** [#725](https://github.com/sesori-ai/sesori_apps_monorepo/pull/725)
- **Delivery:** one plan PR, one selected implementation PR, and one
  evidence-assessment/retirement PR

This document and `TRACKER.md` are the authority for the assessment. Candidate
options are recorded so that an unselected idea is not silently converted into
committed implementation scope.

## Goal

Stop session detail from visibly refreshing after an ordinary message when no
authoritative transcript reload is required, and make every genuine silent
refresh locally diagnosable if the symptom recurs.

The work proceeds evidence-first:

1. add debug-only, consistently tagged refresh diagnostics;
2. remove the demonstrated unnecessary full-detail refresh while preserving
   released bridge compatibility for dynamic command discovery;
3. observe the resulting behavior and record whether any intended reconnect,
   resume, or stale-data refresh still loses live state; and
4. implement a larger reconciliation or transport contract only if evidence
   justifies a separate follow-up plan.

This is not a commitment to implement every option listed below.

## User Report

After sending a message from an open session detail screen, the session can
enter its visible refreshing state. During that refresh, an in-flight message
part can disappear and later return after reopening the session.

The report was observed with OpenCode. Other harnesses were not established as
affected, so all shared-client changes remain backend-neutral and no client
decision may branch on plugin identity.

## Confirmed Findings

### A normal send does not directly refresh

`SessionDetailCubit.sendMessage` submits the prompt and handles accepted/error
outcomes. It does not call `_silentRefresh`, `_doSilentRefresh`, `reload`, or
`ConnectionService.reconnect`.

`SessionDetailLoaded.isRefreshing` becomes true only in `_doSilentRefresh`.
Therefore a refresh observed near a send is caused by an SSE, connection,
lifecycle, or previously queued staleness signal arriving around the send, not
by the successful send callback itself.

### Project-wide invalidation is consumed by the wrong screen

`SesoriSessionsUpdated` is documented as a project-scoped PR/session-list
invalidation. `SessionDetailCubit` nevertheless handles a matching event by
requesting a complete silent refresh. That refresh fetches messages, children,
session metadata, commands, agents, providers, pending questions, pending
permissions, and all session statuses.

Known producers are:

- `PrSyncService.renderedChanges`, which is forwarded as
  `SesoriSseEvent.sessionsUpdated(projectID)` while a project is being viewed;
- ACP/Cursor `available_commands_update`, which currently reuses
  `BridgeSseSessionsUpdated` as a command-discovery nudge; and
- buffered project invalidations replayed after the initial detail load.

The detail screen contains no PR state. Reloading its transcript because PR
metadata changed is unnecessary. The ACP use is a compatibility-era workaround
for command discovery, not a sound reason to replace the whole detail snapshot.

### A stale snapshot can overwrite live events

While `_doSilentRefresh` awaits `SessionDetailLoadService.reload`, the Cubit
remains loaded and applies live SSE events immediately. When the aggregate REST
result completes, it unconditionally replaces transcript, own status, pending
questions and permissions, child projection, title/archive state, and catalogs.

The aggregate is not a coherent point-in-time snapshot. Its requests start and
complete at different times. A finalized `message.part.updated` that arrives
after the message read was sampled can therefore be applied live and then
replaced by the older returned message list.

This explains disappearing message parts. It does not itself cause a relay or
WebSocket reconnect.

### Streaming state is cleared during refresh

The silent refresh snapshots `StreamingTextBuffer` and then clears its mutable
buffer. A later delta can begin from an empty buffer and publish only the
post-refresh suffix. Existing tests cover a delta present at refresh completion
but not another delta arriving after the clear.

### Transport responsiveness is separate

On current `main`, the bridge relay loop awaits routed business work before
reading the next frame. This causes proven head-of-line blocking and can make
healthy clients appear offline, but an asynchronous backend wait does not by
itself stop native WebSocket ping/pong handling.

Open PR [#722](https://github.com/sesori-ai/sesori_apps_monorepo/pull/722)
implements the planned concurrent relay completion path with exact relay/client
fencing and teardown draining. Its current diff is 1,185 changed lines and all
checks pass. This plan does not duplicate or modify that bridge work.

Historical bridge logs contain relay reconnects during zero-traffic periods,
but no log set correlates the exact user-reported send with a specific refresh
trigger or socket close.

## Refresh Trigger Inventory

The diagnostic step must cover every path that can start or defer a silent
detail refresh:

| Trigger | Current behavior | Initial assessment |
|---|---|---|
| Matching `sessions.updated` | Full detail snapshot | Incorrect for detail; selected for correction |
| `command.executed` | Coalesced full detail snapshot | Retain initially; validate command-history need if observed |
| Connection disconnected -> connected | Immediate full detail snapshot and view reassertion | Intended reconciliation path |
| Lifecycle paused/hidden -> resumed | Immediate full detail snapshot when connected | Intended today; reassess only with evidence |
| `dataMayBeStale` | Immediate or deferred full detail snapshot | Intended after replay-risk window |
| Waiting-for-connection load completion | Full reload after connected | Intended |
| Queued/cooldown signal | One trailing full detail snapshot | Intended coalescing behavior |
| Public `reload()` after an operation failure | Loading-state full reload | Not the visible silent-refresh path; retain existing behavior |

## Locked Step 2 Decisions

### Searchable debug diagnostics

Every new refresh lifecycle diagnostic uses `logd` and begins with the exact
shared prefix:

```text
[session-refresh]
```

Example shape:

```text
[session-refresh] action=observed trigger=connection_reconnected
[session-refresh] action=queued trigger=data_may_be_stale
[session-refresh] action=started trigger=connection_reconnected refreshId=7
[session-refresh] action=completed trigger=connection_reconnected refreshId=7 result=applied durationMs=183
```

These causal diagnostics are available only when the observation build has
`logLevel` set to `LogLevel.debug` or `LogLevel.trace`. Product builds default
to `LogLevel.info`, so a production occurrence with no matching entry is not
evidence that the refresh path did not run. Step 3 may draw a no-entry conclusion
only from a debug-enabled observation build. Otherwise record the symptom and
reproduce it with debug logging enabled; Step 2 does not add a release-visible
log level, production toggle, or elevated causal diagnostic.

The implementation uses a private closed enum for trigger decisions. It does
not compare or branch on diagnostic strings. Diagnostic actions and results are
bounded values rather than raw event/error text.

Required trigger values are:

- `project_sessions_updated`
- `command_executed`
- `connection_reconnected`
- `lifecycle_resumed`
- `data_may_be_stale`
- `waiting_for_connection`
- `queued_event`

Required actions are `observed`, `ignored`, `redirected`, `queued`,
`coalesced`, `started`, and `completed`. Completion results are `applied`, `failed`,
`waiting_for_connection`, and `closed`.

Diagnostics must make these facts reconstructable:

1. which external trigger was observed;
2. whether it was ignored, redirected, queued, or started immediately;
3. which refresh attempt eventually ran;
4. whether the snapshot applied, failed, or waited for connection; and
5. how long the attempt took.

A small Cubit-local monotonic `refreshId` may correlate start/completion. If
coalescing retains more than one cause, use a bounded set of the private trigger
enum rather than an unbounded string list or nullable coordination fields.

The diagnostics contain no prompts, transcripts, source code, message parts,
command names, paths, request bodies, or raw errors. The new causal trace itself
remains debug-only and is not analytics.

The existing operational silent-refresh failure logs do not currently preserve
the promised diagnostic context: the typed failure case ignores its stack trace,
the catch clause does not capture one, and both interpolate the error. Step 2
must destructure/capture the original stack and pass the error plus stack to the
existing warning-level logger. The bounded `action=completed result=failed`
causal entry remains debug-only; correcting the pre-existing operational failure
log does not elevate the causal trace or duplicate its purpose.

### Redirect project invalidation to command refresh

A matching `SesoriSessionsUpdated` must no longer call
`_requestEventDrivenRefresh` or set `isRefreshing`.

Instead, while detail is loaded it requests a lightweight command-catalog
refresh through a targeted `SessionDetailLoadService` operation. The service
retains command loading and repository access; the Cubit owns only UI-trigger
single-flight/trailing coalescing and state publication. That operation:

- reads only the commands needed by the composer;
- preserves transcript, streaming text, statuses, pending interactions,
  children, title/archive state, selected agent/model, and queued messages;
- preserves a staged command only when the refreshed catalog still contains it;
- has at most one active request and one trailing request so event bursts do not
  create unbounded reads;
- preserves the current command catalog on failure; and
- does not show the full-detail refresh indicator.

During `SessionDetailLoading`, a matching event remains buffered. After the
initial snapshot loads, replay performs the same targeted command refresh. This
retains the command-discovery behavior added for Cursor without a second full
session snapshot.

Released v1.6.0 bridges can emit `sessions.updated` for command discovery, while
the same event also carries PR invalidation. The new client therefore retains
the targeted command refresh as a compatibility fallback even though some
events will cause one unnecessary command read. Add the required dated
compatibility comment naming v1.6.0 and the exact removal condition. Do not
silently remove this fallback until those bridges are unsupported or a declared
capability makes the distinction reliable.

No new wire event is added in Step 2.

### Do not bundle state reconciliation

Step 2 does not add transcript epochs, grouped snapshot revisions, event
journals, cursors, or a bridge-owned detail projection. Removing the invalid
trigger is the smallest change addressing the primary symptom. The existing
race remains documented and must be exercised specifically through intended
reconnect/resume/stale refreshes before larger machinery is approved.

## Step 2 Success Criteria

1. Every silent-refresh trigger and terminal outcome emits debug diagnostics
   beginning with `[session-refresh]`.
2. A normal accepted text prompt plus ordinary session/message/part/status SSE
   events does not invoke `SessionDetailLoadService.reload`.
3. A matching `sessions.updated` event while loaded does not set
   `isRefreshing`, fetch messages, or replace any non-command detail state.
4. A matching `sessions.updated` event during initial loading still causes the
   final command catalog to reflect the bridge's later command snapshot.
5. Irrelevant-project events cause no detail or command refresh.
6. Bursts produce at most one active and one trailing command refresh.
7. A command-refresh failure preserves the current catalog and remains locally
   observable without changing the successful detail state; silent-refresh
   failures retain the original error and stack in their operational warning.
8. Reconnect, resume, stale-data, waiting-for-connection, and command-executed
   paths retain their current full-refresh behavior and expose their reason in
   diagnostics.
9. No backend-name check, analytics event, wire contract, database field,
   persisted state, generated source, or UI copy is added.
10. PR #722 remains the sole owner of bridge relay request concurrency.

## Evidence Assessment

Step 3 is an evidence gate, not an automatic production implementation.

After Step 2 is available in a build, exercise ordinary sends and natural
reconnect/resume behavior. If the symptom recurs, search local logs for:

```text
[session-refresh]
```

Record only bounded facts in `TRACKER.md`:

- build/version and date;
- harness;
- plain text versus slash command;
- visible symptom: detail progress bar, connection banner, bridge banner, or
  disappearing content;
- diagnostic trigger/action/result sequence;
- whether PR #722 was present; and
- resulting decision.

Do not record prompt/transcript contents, source paths, project names, or raw
tokens in the tracker.

Decision rules:

| Evidence | Decision |
|---|---|
| No recurrence after representative ordinary-send use plus at least one deliberately exercised intended full refresh | Retire this plan with larger options deferred |
| `project_sessions_updated` starts a full refresh | Step 2 regression; fix within this plan |
| `command_executed` after a plain text prompt | Investigate event mapping before changing client reconciliation |
| `connection_reconnected` | Correlate client/bridge/relay logs and PR #722 before changing refresh policy |
| `lifecycle_resumed` after a brief interruption | Assess whether view reassertion can be separated from full data reload |
| `data_may_be_stale` after the replay-risk window | Keep refresh; test whether live state is overwritten during it |
| Content disappears during an intended refresh | Create a focused reconciliation follow-up from the options below |
| UI appears to refresh with no `[session-refresh]` entry in a debug-enabled observation build | Diagnose a different state/UI path; do not add snapshot machinery |
| UI appears to refresh with no entry in a default product build | Record the symptom but draw no causal conclusion; reproduce with debug logging enabled |

If evidence selects grouped reconciliation or a new wire protocol, create a
separate plan with its own slug, fixed delivery, compatibility analysis, and
architecture review. Record the handoff here before retiring this plan.

## Candidate Option Register

Changed-line estimates are additions plus deletions. Generated code is shown
separately. These are planning ranges, not commitments.

| Option | Handwritten production | Tests | Generated | Total | Current decision |
|---|---:|---:|---:|---:|---|
| Debug refresh diagnostics only | 15-30 | 30-60 | 0 | 45-90 | Selected and included in Step 2 |
| Stop unnecessary detail refresh; target command catalog | 80-140 | 140-260 | 0 | 220-400 combined with diagnostics | Selected for Step 2 |
| Transcript-only mutation epoch | 45-90 | 100-180 | 0 | 145-270 | Deferred; fixes observed content only |
| Grouped snapshot reconciliation | 140-260 | 300-550 | 0 | 440-810 | Deferred pending intended-refresh reproduction |
| Apply-live event journal and replay | 120-220 | 250-450 | 0 | 370-670 | Rejected without a server cursor |
| Targeted session-options wire event | 150-260 | 250-450 | 200-500 | 600-1,210 | Deferred; compatibility-safe follow-up only if command reads matter |
| Versioned coherent session synchronization | 500-950 | 800-1,600 | 300-900 | 1,600-3,450 | Deferred; separate plan only with replay-gap evidence |
| Concurrent bridge request completion, PR #722 | 399 current production diff | 748 current test additions | 0 | 1,185 current PR diff including tracker | External overlap; do not duplicate |

### Why event replay is rejected

`message.part.delta` is append-only and non-idempotent. Without a cursor tied to
the exact snapshot cut, the client cannot know whether a returned part already
contains a buffered delta. Applying live and replaying can duplicate text;
pausing and replaying freezes streaming and delays question/permission prompts.
Question/permission replay can also repeat modal-opening side effects.

### Transcript-only mutation epoch

Capture a transcript mutation counter when refresh starts. If a message/part
event advances it, preserve current messages and streaming state rather than
applying the returned transcript. This is the smallest downstream guard but
leaves the same overwrite class for statuses, questions, permissions, metadata,
and children. It is not selected before Step 2 evidence.

### Grouped snapshot reconciliation

Maintain private mutation epochs for transcript, own status, pending questions,
pending permissions, metadata, and child projection. At refresh completion,
apply each snapshot group only if no newer live mutation touched it. Preserve
streaming buffers, derive dependent fields after the merge, distinguish failed
subreads from authoritative empty data, fence overlapping loads, and use the
existing coalesced refresh path for eventual convergence.

This is the preferred client-only hardening if an intended refresh reproduces
the race. It prevents known local live state from regressing but cannot prove a
globally coherent backend snapshot.

### Targeted options event

Add a session-scoped options-changed event emitted only after the bridge's
options cache commits, and update only the detail catalogs. Because v1.6.0 peers
use `sessions.updated`, backward/forward compatibility requires either a
declared capability or a retained legacy fallback. That generated/wire cost is
not justified merely to remove the current full-detail refresh.

### Versioned synchronization protocol

A complete distributed solution requires a bridge epoch, monotonic event
cursor, explicit replay-gap notification, and a snapshot whose cursor honestly
describes exactly which events its fields include. Attaching one cursor to the
current multi-request aggregate would be incorrect because each field is sampled
at a different time. A bridge-owned coherent projection or honest per-domain
revisions would be a separate cross-stack architecture effort.

## Non-Goals

- Proving or changing relay-server socket timeout behavior in Step 2.
- Duplicating PR #722 or modifying bridge request concurrency.
- Removing intended reconnect/resume/stale refreshes before evidence identifies
  one as unnecessary.
- Adding generic request timeouts, retries, locks, event registries, or heartbeat
  changes.
- Adding plugin-specific client behavior.
- Adding analytics for refreshes or reconnects.
- Adding a wire event, database migration, persisted cursor, or generated source
  in the selected implementation.
- Claiming exactly-once SSE delivery or a coherent snapshot under the current
  protocol.

## Compatibility, Privacy, And Data

- Step 2 changes no transport model. Older and newer peers continue exchanging
  the same events.
- The v1.6.0 `sessions.updated` command-discovery behavior is retained as a
  targeted client fallback rather than a full-detail reload.
- No database, persisted state, migration, or backfill changes.
- Debug diagnostics are local and disabled below debug verbosity. They use the
  fixed `[session-refresh]` prefix and bounded trigger/action/result values.
- No prompt, transcript, source code, command name, file path, raw event payload,
  token, or error text is added to those diagnostics.
- This is reliability work, not a product adoption question; no analytics event
  is added.

## Delivery Rules

- The series has exactly three steps. Candidate options are not additional
  implicit steps.
- Step 1 is documentation-only and uses the current owner-provided branch and
  worktree. Do not create another branch or worktree in this session.
- Step 2 implements only the debug diagnostics and unnecessary-refresh
  correction locked above.
- Step 3 records evidence and either retires the plan or hands justified larger
  work to a separately reviewed plan. It contains no production change unless a
  direct Step 2 regression must be corrected.
- Every step updates `TRACKER.md` with base, actual changed-line count,
  verification, review, PR/merge link, and option decisions.
- Implementation tests and analysis run only for touched client packages.
- Run `aristotle-impl-review` only if Step 2 changes an architecture boundary;
  the currently selected localized Cubit/repository behavior is not expected to
  require it.
- Step 3 moves `.plan/active/session-refresh-reconnects/` to
  `.plan/completed/session-refresh-reconnects/` when no follow-up remains.

## Fixed PR Series

| Step | Branch | Exact PR title | Changed-line target | Outcome |
|---|---|---|---:|---|
| 1/3 | `opencode-session-reconnects` | `🌱 [session-refresh-reconnects] docs: plan session refresh diagnosis [step 1/3]` | 550-750 | Publish the evidence, selected first fix, diagnostics contract, option register, and assessment gates |
| 2/3 | Owner-provided implementation branch | `⚙️ [session-refresh-reconnects] fix(client): stop unnecessary session detail refreshes [step 2/3]` | 220-400 | Add searchable debug diagnostics and redirect project invalidation to targeted command refresh |
| 3/3 | Owner-provided assessment branch | `🌱 [session-refresh-reconnects] docs: assess session refresh evidence [step 3/3]` | 80-200 | Record observations, final option decisions, any follow-up-plan handoff, and retire this plan |

## Step 1/3 - Publish The Assessment Plan

### Scope

- Add this `PLAN.md` and `TRACKER.md`.
- Record confirmed and unconfirmed causes separately.
- Lock the `[session-refresh]` debug tag and selected Step 2 behavior.
- Record every considered option, estimate, status, and evidence gate.
- Run architecture plan review because deferred options include client/wire
  boundary changes, then apply valid findings directly without re-review.

### Verification

- `git diff --check`
- Markdown structure and exact title/step-total comparison between plan/tracker
- plan files only in the diff

## Step 2/3 - Diagnose And Stop Unnecessary Refreshes

### Scope

- Add the closed refresh-trigger model and `[session-refresh]` debug lifecycle
  diagnostics.
- Require a debug-enabled observation build before interpreting the absence of
  those diagnostics.
- Pass or preserve trigger causes through immediate, queued, cooldown,
  reconnect, waiting-for-connection, and failure-restoration paths.
- Replace matching `sessions.updated` full-detail refresh with a bounded targeted
  command operation on `SessionDetailLoadService`; the Cubit retains only
  trigger coalescing and loaded-state publication.
- Preserve original errors and stack traces in operational silent-refresh
  failure warnings without adding payload data to the debug causal trace.
- Preserve initial-load command discovery and released v1.6.0 compatibility.
- Add focused regressions for normal sends, event bursts, initial-load replay,
  unrelated projects, failures, and retained intended refresh reasons.

### Verification

- Targeted `SessionDetailCubit`, stale/reconnect, event-buffer, and command
  refresh tests
- `dart analyze --fatal-infos` from `client/module_core`
- affected downstream client tests only if production impact crosses module_core
- `git diff --check`

## Step 3/3 - Assess Evidence And Retire Or Hand Off

### Scope

- Record representative post-fix observations and any recurrence using only the
  bounded evidence fields above. Retirement requires at least one deliberately
  exercised intended reconnect/resume/stale refresh in a debug-enabled build.
- Mark every option implemented, rejected, deferred, superseded, or handed to a
  named follow-up plan.
- If no justified follow-up remains, move the plan directory to completed.
- If larger work is justified, create/review its separate plan before retiring
  this one; do not expand Step 3 into an unreviewed implementation.

### Verification

- Tracker and plan decisions agree.
- Every selected option has implementation/verification evidence.
- Every unselected option has an explicit final disposition.
- `git diff --check`
