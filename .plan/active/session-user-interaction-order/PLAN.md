# Running Session Interaction Order

## Status

- **Plan slug:** `session-user-interaction-order`
- **Status:** Reviewed plan - architecture findings applied and current main revalidated
- **Plan date:** 2026-08-13
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main` at `88059e200`
- **Implementation branch:** `session-order-ux-review`
- **Delivery:** one plan PR, four implementation PRs, one regression-documentation
  PR, and one verification/retirement PR

This document and `TRACKER.md` are the implementation authority for the series.
The fixed split keeps the backend-specific provenance, durable bridge state,
released wire compatibility, and client behavior independently reviewable.

## Goal

Keep running root sessions promoted at the top of the project session list, but
order that running prefix by the most recent genuine user interaction rather
than alphabetically.

Interactions that advance recency are:

- an accepted user prompt, including a prompt created directly in an observable
  backend surface;
- an accepted slash command;
- a manual question answer, question rejection, or permission decision; and
- manual context compaction.

Automatic compaction, generated continuation/replay prompts, automatic
permission approval, cancellation cleanup, assistant activity, tool activity,
and title/catalog updates must not advance the marker.

The visible policy remains otherwise unchanged:

- running means `mainAgentRunning || isRetrying || backgroundTaskCount > 0`;
- awaiting-input alone does not promote a session into the running prefix;
- non-running sessions remain ordered by `Session.time.updated` descending;
- archived filtering remains unchanged; and
- project ordering and the background-task child list do not change.

## Success Criteria

1. Running root sessions with known interaction markers appear in descending
   user-interaction recency, regardless of title.
2. A prompt, command, manual answer/rejection/permission decision, or manual
   compaction advances the displayed root session promptly without a list
   refetch.
3. Automatic OpenCode compaction, including its synthetic continuation and
   overflow replay messages, does not advance recency.
4. Sesori permission auto-approval and plugin cancellation/teardown replies do
   not advance recency.
5. Observable backend/laptop-originated user interactions advance recency when
   the owning plugin can prove human provenance; unsupported external-process
   cases remain unknown rather than guessed.
6. Existing databases add a nullable `last_user_interaction_at` column without
   backfilling polluted `last_user_message_at` or backend `updated_at` values.
7. The marker is monotonic across duplicate events, reconnects, bridge restart,
   and clock rollback, using existing ordered pipelines rather than a new lock
   or registry. An accepted bridge-owned OpenCode write still records one fact
   if its raw SSE envelope/part pair is lost during reconnect.
8. REST session payloads and the existing `session.unseen_changed` live patch
   carry the nullable marker additively. Old app/new bridge and new app/old
   bridge combinations retain their current behavior.
9. A stale REST or `session.updated` payload cannot replace a fresher live
   marker, including when the patch arrives during the initial REST load.
10. Sessions whose marker is absent use `time.updated` as the compatibility
    fallback. Equal keys have a deterministic ID tie-breaker.
11. No backend identifier, interaction kind, prompt text, command name,
    transcript content, path, or entity identifier is added to analytics or a
    new public event.

## Current Behavior And Evidence

### Client ordering ownership

- `SessionListService.visibleSessions` partitions running sessions using
  `SessionActivityCalculator.isRunning`, alphabetizes the running prefix, then
  appends the remaining sessions sorted by `time.updated` descending
  (`client/module_core/lib/src/services/session_list_service.dart`).
- `SessionActivityCalculator` deliberately excludes `awaitingInput` alone from
  running (`client/module_core/lib/src/services/session_activity_calculator.dart`).
- `SessionListCubit` owns the complete unbounded project list, applies REST and
  live session updates, and re-runs `visibleSessions` whenever activity changes
  (`client/module_core/lib/src/cubits/session_list/session_list_cubit.dart`).
- The in-repository client sends `start: null, limit: null` to `POST /sessions`
  (`client/module_core/lib/src/api/project_api.dart`). Server pagination remains
  an API capability but does not define this screen's visible order.
- The background-task child list is separately sorted by `time.updated`
  (`SessionDetailCubit._sortChildrenByUpdatedDesc`) and is not part of this
  root-list change.

### Existing bridge timestamps are not an interaction source

- `sessions_table.last_user_message_at` feeds released unseen-state behavior
  (`SessionUnseenCalculator`) and is currently advanced by generic
  user-shaped messages and question/permission reply events.
- OpenCode represents both manual and automatic compaction as a user message.
  `MessagePartMapper` intentionally renders both forms as `/compact`, so the
  shared message shape no longer contains provenance.
- OpenCode publishes `message.updated` before `message.part.updated`; only the
  raw `CompactionPart.auto` on the later part distinguishes manual from
  automatic compaction.
- The generated OpenCode API models remain sourced from v1.17.7, while the
  managed runtime is now pinned to v1.18.11. Revalidation against v1.18.11
  confirms the same envelope-before-part order, `auto` provenance, synthetic
  continuation, and overflow replay behavior used by this classifier.
- OpenCode also creates synthetic user messages for compaction continuation,
  plan-mode transitions, task-result injection, and shell bookkeeping. Overflow
  compaction can replay an earlier user message with copied non-synthetic parts.
- Existing released rows can therefore contain values unsuitable for ordering.
  No valid historical backfill exists.

### Existing seams can carry the new fact

- `BridgePluginApi.events` is the backend-neutral plugin boundary for live
  backend facts (`bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart`).
- `SessionEventDispatcher` and `OrchestratorSession._processPluginEventInOrder`
  already preserve per-plugin event order and generation fencing.
- `SessionEventMapper` translates backend session IDs to stable bridge IDs and
  already supports a distinct display/root session for child questions and
  permissions.
- `SessionUnseenService` already serializes low-volume session-list timestamp
  writes, owns a monotonic clock, persists `last_user_message_at`, and emits the
  existing cross-cutting `session.unseen_changed` list-state patch after a
  commit.
- Shared JSON generation omits nullable values and accepts missing nullable
  keys, which provides additive old/new peer compatibility.

### History decisions

- PR #474 introduced a broad bridge-authored project/session activity summary.
- PR #480 reverted that pipeline.
- PR #482 established the current client-owned running prefix and alphabetical
  running order.
- This plan transmits one timestamp fact and keeps ordering in the client. It
  does not restore `ActiveWorkSummaryService` or bridge-authored list snapshots.

## Architecture

### 1. Backend-neutral interaction fact

Add one internal plugin event in
`bridge/sesori_plugin_interface/lib/src/bridge_sse_event.dart`:

```text
BridgeSseSessionUserInteraction
  sessionID: String
  displaySessionId: String?
  occurredAt: int?
```

Contract:

- The event means the plugin has authoritative evidence that a human
  interaction was accepted or observed.
- `sessionID` is the backend session that owns the interaction.
- `displaySessionId` is the backend root session whose row should move when a
  child request is surfaced under that root. Flat plugins use the same session
  ID; null means the plugin cannot resolve a distinct display root.
- `occurredAt` is milliseconds since epoch when the backend supplies a reliable
  interaction timestamp; null asks bridge core to stamp acceptance/observation
  time.
- The event deliberately carries no interaction kind or content. Every accepted
  kind has identical ordering semantics, and exposing more detail would add no
  client decision value.
- `BridgeEventMapper` maps it to no direct public SSE event. It is consumed by
  bridge core after backend-to-stable ID translation.

Add a closed `PluginInteractionOrigin.manual/automatic` enum to the internal
plugin interface and require it on `BridgePluginApi.replyToPermission`. The
manual reply handler passes `manual`; `PermissionAutoApprovalService` passes
`automatic`. Internal plugin contracts and all in-repository implementors update
in lockstep; no compatibility shim or optional parameter is added.

Question reply/rejection methods need no origin parameter because the only
bridge-app callers are explicit user routes. Plugin cancellation and teardown
paths remain separate and do not emit the interaction fact.

`SessionEventMapper` translates both session identities. If either explicitly
named backend ID has no durable binding, the existing pending-binding behavior
holds or drops the event exactly like other session events. Persistence targets
`displaySessionId ?? sessionID`; it does not walk ancestors, stamp both rows, or
infer a family beyond the plugin's display attribution.

### 2. Plugin provenance rules

Every registered production plugin emits the same neutral event, but each owns
its backend-specific evidence.

#### OpenCode

Add `OpenCodeUserInteractionTracker` beside the existing OpenCode trackers. It
owns the bounded message-envelope/part classifier, automatic-overflow
suppression, and all classifier lifecycle state. It receives the existing
`ActiveSessionTracker` as a required dependency for root/display attribution;
it does not duplicate the session-parent graph.

`OpenCodePlugin._handleRawSseEvent` remains a composition pipeline: after
parsing and updating the existing service/tracker state, it delegates the raw
`SseEventData` to `OpenCodeUserInteractionTracker`, forwards any returned
neutral interaction fact, then continues existing presentation mapping.
Classification still occurs before `SseEventMapper` erases raw part provenance.

The same tracker also coordinates bridge-owned prompt/command acceptance. The
plugin starts one bounded pending write before dispatch, raw classification may
satisfy that write first, and successful API completion emits a null-timestamp
fallback only when no matching raw fact was observed. Failed acceptance emits no
fallback. This produces one fact in the ordinary path while covering the real
disconnect window where OpenCode accepted the write but its envelope or part was
lost before the fresh non-replaying SSE connection. Initial create-session turns
use the same coordination after the backend session ID is known.

- Keep at most one pending user envelope per session: message ID plus the
  message creation timestamp. This state is bounded by the number of known
  sessions, not transcript length.
- A later part classifies only the matching pending envelope.
- A root-session non-synthetic text/file/subtask prompt records one interaction.
  A child user prompt is not counted because OpenCode creates those for agent
  task sessions and Sesori exposes child detail as read-only.
- `CompactionPart(auto: false)` records one manual interaction.
- `CompactionPart(auto: true)` records none.
- Synthetic text parts record none. This excludes auto-compaction continuation,
  plan-mode transitions, background-result injection, and shell bookkeeping.
- For automatic overflow compaction, suppress the next replay/continuation user
  envelope. Clear suppression when consumed or when compaction/status terminal
  evidence proves no replay remains, so a failed compaction cannot suppress a
  later genuine prompt.
- Remove pending/suppression state when the tracker observes session deletion;
  call its `reset` from the existing OpenCode reconnect/reset path and its
  `dispose` during plugin disposal. Do not add a transcript-sized dedupe set;
  one envelope is consumed once, and bridge-write coordination emits at most one
  fact for its accepted action.
- Raw `question.replied` and `question.rejected` events are authoritative and
  cover both Sesori and laptop replies.
- Raw `permission.replied` is not authoritative: OpenCode emits the same event
  for `always` cascades. Emit one fact only from a successful manual
  `replyToPermission` call. Direct laptop permission decisions remain unknown.

This design relies on OpenCode's observed and generated API ordering:
`message.updated` precedes its parts. It does not add a timer, delayed flush,
history read, or content comparison for a theoretical reversed sequence.
OpenCode facts use null `occurredAt`: interaction order is acceptance/observation
order, and bridge stamping remains monotonic even when the backend clock rolls
back. Other plugins may provide a known timestamp only where replay identity and
clock semantics make it authoritative.

#### Codex

- Add `CodexUserInteractionTracker` as the plugin-local owner of app-server user
  item provenance. `CodexPlugin` delegates notifications and terminal lifecycle
  signals to it and forwards returned neutral facts; `CodexEventMapper` remains
  a presentation mapper.
- The tracker emits once from the first app-server `userMessage` item lifecycle
  observation; that typed item is the authoritative prompt/command boundary and
  also covers another observable Codex surface. It keeps only in-flight
  `(threadId, itemId)` keys: `item/started` emits and records, `item/completed`
  removes and emits only if no start was observed. Turn terminal, thread delete,
  reconnect/reset, and disposal clear remaining keys. Do not emit again from
  `sendPrompt` or an ordinary `sendCommand` response.
- Extract the existing private generated repository/context test into one pure
  `CodexGeneratedContextValidator`. Inject that required dependency into both
  `CodexUserInteractionTracker` and `CodexMessageRepository`; do not duplicate
  wrapper strings or expose them outside the Codex plugin.
- A successful `thread/compact/start` call emits one manual-compaction fact.
  Generic `contextCompaction` notifications carry no manual/automatic origin and
  emit no fact.
- Successful registry question/permission methods emit facts only for explicit
  manual calls. `cancelForSession` remains a no-fact cleanup path.
- App-server user items have no reliable message timestamp, so these events use
  null `occurredAt` and bridge observation time.

#### Cursor / ACP

- Emit after the existing prompt/command acceptance gate and for a non-empty
  initial create-session turn.
- Cursor's public `compact` command is counted once after acceptance even though
  the adapter rewrites it to the backend `summarize` command.
- Emit after successful manual registry answers/decisions; abort/dispose
  cancellation emits no fact.
- ACP drops backend `user_message_chunk` echoes and the bridge owns a separate
  process, so interactions made in another laptop process are not observable and
  remain unknown.

#### Claude

- Emit after `_enqueue` accepts a prompt/command and for a non-empty initial
  create-session turn. A manually sent `/compact` is therefore counted as a
  command.
- Emit after successful manual registry answers/decisions; cancellation and
  disposal emit no fact.
- Do not infer interaction from generic Claude user frames, which can represent
  internal tool-result/context traffic.
- Separate laptop Claude CLI transcripts are not live-tailed by this plugin, so
  those interactions remain unknown.

OMP inherits the ACP implementation but is not registered in the production
bridge at the plan date. Pi has protocol primitives but no `BridgePluginApi`
implementation and is also excluded until registration. If registration changes
before execution, re-evaluate the production matrix rather than hard-coding this
historical list.

### 3. Durable marker and monotonic write

Add nullable `lastUserInteractionAt` to `SessionTable`/`SessionDto` and bump the
Drift schema from v13 to v14.

- The v13-to-v14 migration only adds the nullable column.
- Existing rows remain null. Neither `last_user_message_at` nor `updated_at` is
  an honest baseline.
- Preserve the v13 snapshot and generate a new v14 schema snapshot, migration
  steps, generated database source, and migration helper. Never hand-edit
  generated files.
- Catalog import/upsert preserves an existing marker and leaves new imported
  rows null until an authoritative live fact arrives.
- Existing session projection updates and placeholder/create UPSERTs omit the
  column so they cannot erase it.

Extend `SessionUnseenRepository`/`SessionUnseenService` rather than adding a
parallel timestamp repository, service, stream, or lock. They already own the
persisted user marker, monotonic timestamp source, ordered write tail, and
session-list state patch.

`recordUserInteraction` behavior:

1. read the named stable session row;
2. no-op if it does not exist;
3. for a known `occurredAt`, no-op when it is not newer than the stored marker;
4. for a null timestamp, stamp `max(local monotonic now, stored + 1)` so a new
   accepted action still advances after clock rollback/restart;
5. update only `last_user_interaction_at` with a conditional/monotonic DAO
   write; and
6. emit the committed session-list patch.

This does not alter `last_activity_at`, `last_seen_at`, `last_user_message_at`,
or the unseen formula. Generic message/reply unseen routing stays in place for
released behavior, even where historical user-shaped backend events are broader
than the new marker. Update the `lastUserMessageAt` comment to state that it is
an unseen-specific legacy marker and must not be reused as authoritative
interaction recency.

The ordinary reachable duplicate/replay flow justifies monotonic persistence.
No new cross-plugin queue, per-session mutex, event journal, or reconciliation
job is needed because existing per-plugin processing and the global low-volume
timestamp write tail already serialize the relevant operations.

### 4. Additive REST and live transport

Add `required int? lastUserInteractionAt` to the shared `Session` model and map
the persisted field through every bridge catalog/detail/child/live session
projection:

- `SessionCatalogMapper` for database-only roots and children;
- `PluginSessionMapper.enrichSharedSession` for plugin-enriched payloads; and
- all direct `Session` construction call sites required by generated analysis.

Add the same required nullable property to the existing
`SesoriSseEvent.sessionUnseenChanged` variant. Update its documentation and the
bridge `UnseenChange` typedef to describe a session-list state patch carrying
unseen state plus interaction recency.

- Every post-row patch carries the committed marker.
- Delete patches carry null.
- Old apps ignore the extra REST/SSE key.
- New apps decode omission from old bridges as null.
- Null values remain omitted by shared JSON generation.
- Use dated compatibility comments with the actual release target at
  implementation time.

Do not create a dedicated public interaction event. Reusing the existing
post-commit list-state patch avoids a second ordering relationship and unknown
event behavior in older clients while keeping the internal provenance fact out
of the released protocol.

Do not change `Session.time.updated`, DAO root ordering, or session-list indexes.
The client owns the activity-aware visible order and fetches the complete list.
Changing server pagination would not be sufficient because the server query
does not own live running state, and no current in-repository list consumer uses
paged roots.

### 5. Client merge and comparator

`SessionListService` remains the sole visible-order policy owner.

For running sessions, compare:

1. effective interaction recency descending, where
   `lastUserInteractionAt ?? time.updated ?? 0`;
2. a known interaction marker before an unknown marker when effective keys are
   equal;
3. `time.updated` descending; and
4. session ID ascending as a deterministic final tie-breaker.

The `time.updated` fallback preserves useful behavior with old bridges and
pre-migration sessions. Once a verified marker exists, later automatic backend
updates cannot move that session because the comparator uses the marker instead.

For non-running sessions, keep `time.updated` descending and add only the same
deterministic ID tie-breaker. Do not change `SessionActivityCalculator`, project
ordering, or child-task ordering.

`SessionListService` owns every marker transformation:

- `applyInteractionPatch` locates an already-held session and max-merges the
  nullable live marker without manufacturing a missing session;
- `applySessionUpdatedEvent` keeps the greater existing/new interaction marker
  alongside its current PR metadata merge; and
- `mergeRestSnapshot` treats fetched membership and ordinary fields as
  authoritative while max-merging markers from matching sessions already held
  and from the existing `SessionUnseenTracker`, so an in-flight or initial fetch
  cannot roll back a live patch.

`SessionListCubit` only validates the SSE project/state, delegates
`SesoriSessionUnseenChanged` to `applyInteractionPatch`, delegates successful
REST replacement to `mergeRestSnapshot`, and re-runs `visibleSessions`.
`SessionUnseenTracker` remains the live list-state cache: extend its existing
per-project tick and session map to retain the nullable marker from
`SesoriSessionUnseenChanged` alongside unseen state. It performs no ordering or
merge decision; `SessionListService` consumes its cached marker map. This reuses
the tracker that already receives patches before a list Cubit is loaded rather
than adding another long-lived owner.

No new long-lived tracker, Cubit generation, tick map, or optimistic interaction
state is required. Bridge markers are monotonic, so a per-session max at the two
existing merge seams is sufficient.

## Compatibility

### Wire

- **New bridge, old app:** extra nullable properties on known REST/SSE shapes are
  ignored; current updated-time/alphabetical behavior remains in that app.
- **Old bridge, new app:** missing properties decode to null and running order
  falls back to `time.updated`.
- **New plugin fact, old app:** the internal fact never reaches the wire.
- No request field, route, capability negotiation, or new public SSE variant is
  added.

### Database

- Stable released databases migrate v13 to v14 by adding a nullable column.
- No historical interaction is manufactured.
- Existing unseen columns and values remain intact.
- If another schema version lands on `main` before implementation, preserve it
  and move this migration/snapshot to the next available version rather than
  rewriting merged history.

### Internal APIs

- `BridgePluginApi` and plugin packages have no out-of-repository consumers and
  update together. The new required permission origin has no fallback or shim.

## Scope And Non-Goals

- Do not restore `ActiveWorkSummaryService`, bridge-authored session ordering,
  or project ordering by session activity.
- Do not infer genuine interaction from `Session.time.updated`, generic shared
  `MessageUser`, command completion, assistant output, tool output, session
  status, or title changes when an authoritative marker is available.
- Do not backfill the new column from existing timestamps or transcript history.
- Do not redesign unseen state or clean polluted historical
  `last_user_message_at` values.
- Do not add live tailing to Claude/ACP processes or make unobservable laptop
  interactions appear supported.
- Do not add locks, timers, ancestry walks, content hashes, event journals,
  background repair, server-side active sorting, or pagination/index changes.
- Do not change child-session presentation or make child detail writable.
- Do not add analytics. There is no product decision, reporting model, or
  privacy-safe aggregate that requires tracking this ordering behavior; the
  authoritative event would also risk turning session activity into telemetry.

## Evidence And Accepted Risk

| Concern | Evidence class | Planned safeguard / accepted behavior |
|---|---|---|
| Automatic compaction looks user-authored | Observed backend behavior | Classify raw OpenCode parts before mapping; test auto, continuation, and overflow replay |
| Auto-approved/cancelled replies look manual | Ordinary reachable flow | Required permission origin plus manual-only plugin fact emission; cancellation methods emit no fact |
| Duplicate backend events | Ordinary live-event flow | Plugin-local one-shot classification plus persisted monotonic conditional update and existing ordered write tail |
| Accepted OpenCode write loses SSE pair | Ordinary disconnect window | Coordinate bridge write with raw observation and emit one successful null-time fallback only when raw did not satisfy it |
| Backend clock rollback | Ordinary clock-adjustment flow | OpenCode uses null occurred-at and bridge monotonic stamping; known times remain only for authoritative plugin sources |
| REST/SSE replacement race | Ordinary initial/in-flight refresh flow | Existing unseen tracker retains the patch; service maxes it at client replacement seams |
| Reversed OpenCode message/part order | Theoretical against current upstream order | Accepted; no timer or history lookup. Missing one reorder self-heals on the next genuine interaction |
| Direct laptop interaction in a separate ACP/Claude process | Unobservable by current architecture | Accepted limitation; keep marker unchanged rather than guess |
| Direct OpenCode permission decision | Event cannot distinguish one choice from `always` cascade | Accepted limitation; only Sesori manual decisions count until upstream adds provenance |
| Existing null markers after migration | Required honest migration state | Fall back to `time.updated` until the first authoritative interaction |
| Paged third-party root requests | No current in-repository consumer and server lacks running state | Keep existing server order; visible app fetch remains complete and client-owned |

## Cleanup Assessment

Directly caused cleanup:

- remove `_compareSessionsByTitleAndId` and the alphabetical-running-order tests
  replaced by the recency comparator;
- correct the `lastUserMessageAt` documentation so future work does not treat it
  as authoritative interaction provenance; and
- update `session.unseen_changed` naming documentation from unseen-only to the
  cross-cutting session-list patch it becomes.

Retained intentionally:

- `last_user_message_at`, generic user-message unseen routing, and current
  unseen tests remain required by released persisted unseen behavior;
- `time.updated` remains the inactive order and compatibility fallback;
- existing activity-summary and child-task calculations remain required; and
- no larger obsolete service, cache, setting, job, or transport field is created
  by this change.

## Delivery Plan

All steps use the existing `session-order-ux-review` branch/worktree. Before each
implementation PR, synchronize with current `main` and preserve any schema
versions already merged. Do not create another branch or worktree for this
series.

### Step 1/7 - Plan

**Exact PR title:**
`🌱 [session-user-interaction-order] docs: plan running session interaction order [step 1/7]`

- Add this plan and tracker.
- Record architecture review findings and direct corrections.
- Validate exact titles, fixed denominator, scope, and `git diff --check`.
- No production, generated, database, wire, or user-visible change.

**Changed-line target:** 550-1,050 documentation lines.

### Step 2/7 - Authoritative plugin facts

**Exact PR title:**
`🚧 [session-user-interaction-order] feat(plugins): report genuine user interactions [step 2/7]`

- Add the internal interaction event and required permission origin enum.
- Update every registered plugin and all app/plugin call sites in lockstep.
- Add `OpenCodeUserInteractionTracker` and implement pending-envelope
  classification, bridge-write fallback coordination, lifecycle cleanup, and
  automatic-compaction exclusions.
- Add `CodexGeneratedContextValidator` plus
  `CodexUserInteractionTracker`, then implement Codex, ACP/Cursor, and Claude
  authoritative emission rules.
- Add bridge event ID translation and explicit no-public-wire mapping.
- Test prompt, command, initial turn, manual compaction, manual answer/decision,
  auto approval, cancellation, synthetic continuation, overflow replay, and
  duplicate handling, backend clock rollback, and disconnect-between-acceptance-
  and-SSE behavior at the owning boundaries.
- No database, released wire, client, or user-visible behavior yet.

**Changed-line target:** 1,050-1,500 lines. If complete production-plugin tests
would exceed the soft cap, split test-only follow-up is not acceptable because
the contract must land verified; update the target with measured generated-free
scope before opening the PR.

### Step 3/7 - Persist interaction recency

**Exact PR title:**
`🚧 [session-user-interaction-order] feat(bridge): persist session interaction recency [step 3/7]`

- Add the nullable Drift column and next schema migration with no backfill.
- Generate schema snapshot, steps, database source, and migration helpers.
- Preserve markers through catalog import and all session projection UPSERTs.
- Extend the existing unseen repository/service with the monotonic
  post-translation write and consume internal facts in the orchestrator.
- Keep existing unseen timestamps/formula unchanged.
- Test migration structure/null baseline, preservation, root/display
  attribution, missing rows, known-time duplicate/no-regression, null-time clock
  rollback, and auto-generated no-fact paths.
- No released wire or client behavior yet.

**Changed-line target:** 4,500-6,500 lines, explicitly above the 1,500-line soft
cap because the required new Drift v14 JSON snapshot and generated Dart schema
helper are additive files of several thousand lines. Hand-editing, omitting, or
separating those generated migration artifacts would leave the persisted change
unreviewable or invalid; non-generated production/test scope should remain
localized.

### Step 4/7 - Transport the marker

**Exact PR title:**
`⚙️ [session-user-interaction-order] feat(protocol): publish session interaction recency [step 4/7]`

- Add the nullable shared `Session` and `session.unseen_changed` properties with
  dated compatibility comments.
- Regenerate shared Freezed/JSON source.
- Map REST/detail/child/live session projections and post-commit list patches.
- Verify null omission, missing-field decode, old/new peer behavior, delete null,
  and committed-value delivery.
- No ordering change in the client yet; old clients remain unaffected.

**Changed-line target:** 700-1,300 lines including generated source and tests.

### Step 5/7 - Apply client ordering

**Exact PR title:**
`⚙️ [session-user-interaction-order] feat(client): order running sessions by interaction [step 5/7]`

- Replace alphabetical running order with the effective-recency comparator.
- Add `SessionListService.applyInteractionPatch` and `mergeRestSnapshot`; preserve
  max values across live patches, session updates, and in-flight REST
  replacement. Extend `SessionUnseenTracker`'s existing list-state cache so an
  initial-load patch is retained while keeping the Cubit orchestration-only.
- Keep awaiting-only, inactive, archived, project, and child ordering behavior
  unchanged.
- Add service/Cubit tests for marker order, null fallback, deterministic ties,
  auto-update stability, live reordering, initial/in-flight stale REST, old
  bridge payloads, and project mismatch.
- Verify both mobile and desktop downstream analysis because both consume
  `module_core`, while noting the desktop shell has no catalog UI.

**Changed-line target:** 350-750 lines.

### Step 6/7 - Regression contract

**Exact PR title:**
`🌱 [session-user-interaction-order] docs: define session interaction order coverage [step 6/7]`

- Reconcile `docs/regression/projects-and-sessions.md` with the root running
  order, live marker, null fallback, and compatibility behavior.
- Reconcile `docs/regression/session-turns.md` with genuine interaction
  provenance, manual compaction, and automatic/cancellation exclusions.
- Record the final registered-plugin and platform matrix discovered from the
  implemented code.
- No production, database, wire, generated, or user-visible change.

**Changed-line target:** 50-180 lines.

### Step 7/7 - Verify and retire

**Exact PR title:**
`🌱 [session-user-interaction-order] docs: verify and retire interaction ordering [step 7/7]`

- Run the recorded L3 cumulative regression level through the matrix below.
- Record automated and live/client evidence, limitations, versions, and cleanup
  in the tracker without prompts, transcripts, paths, raw IDs, or logs.
- Run final relevant analysis/tests only where the evidence changed since each
  implementation PR; do not rerun an unchanged passing matrix for confidence.
- Move the plan directory from `.plan/active/` to `.plan/completed/` only when
  every required boundary passes. Partial, blocked, failed, or reduced coverage
  keeps the plan active unless the user explicitly accepts and records a matrix
  reduction.
- No production, database, wire, generated, or new user-visible change.

**Changed-line target:** 60-220 documentation lines.

## Verification Plan

### Focused automated verification

Step 2:

- `sesori_plugin_interface`: strict analysis and exhaustive event switches.
- `OpenCodeUserInteractionTracker` tests: ordinary root prompt/file prompt,
  child-generated prompt exclusion, slash/subtask command, manual compaction,
  auto compaction, synthetic continuation, overflow replay, question
  reply/reject, manual versus automatic permission, bridge-write/raw one-fact
  coordination, lost-SSE fallback, clock rollback, and bounded pending-state cleanup.
- `CodexGeneratedContextValidator` and `CodexUserInteractionTracker` tests: one
  first-lifecycle user-item fact, generated-context exclusion, bounded terminal
  cleanup, ordinary command, explicit manual compact, generic context compaction
  exclusion, manual registry replies, and cancellation exclusion.
- ACP/Cursor and Claude tests: accepted/failed prompt and command, initial turn,
  compact mapping, manual reply, cancellation/disposal exclusion.
- Bridge app mapper tests: backend/stable IDs and display-root translation; no
  public mapping.

Step 3:

- Drift v13-to-v14 migration tests and schema validation.
- DAO/repository/service tests for null baseline, preservation, monotonic writes,
  missing rows, display-root targeting, and post-commit patch emission.
- Orchestrator event processing test proving the internal fact persists but is
  not directly enqueued as a wire event.

Step 4:

- Shared model round-trip and omitted-field compatibility tests.
- Bridge catalog/detail/child/session-update mapper and route tests.
- Existing unseen-change tests extended to assert the committed nullable marker.

Step 5:

- `client/module_core/test/services/session_list_service_test.dart`.
- `client/module_core/test/cubits/session_list/session_list_cubit_test.dart`.
- Focused connection/SSE parsing tests for the additive known-event property.
- `dart analyze` in shared, changed bridge packages, `module_core`, mobile app,
  and desktop shell as applicable.

### Regression level and proof boundaries

**Highest required level:** L3 Release, cumulative through L1 and L2.

The behavior has independent proof boundaries:

- **Automated:** plugin provenance classification, migration/persistence,
  additive JSON compatibility, monotonic merge, and deterministic comparator.
- **Live plugin:** real backend prompt/command/manual-compaction behavior and
  automatic-compaction exclusion where supported.
- **Client end to end:** a phone observes multiple running root sessions reorder
  after genuine interactions while inactive/awaiting-only rows retain policy.

### Required matrix

- **Plugins:** every supporting registered production plugin at execution time.
  At plan time: OpenCode, Codex, Cursor, and Claude.
- **Interaction capabilities:** prompt and command for each plugin; manual
  compaction and question/permission response where supported; automatic
  compaction/auto-approval/cancellation exclusions where the plugin exposes
  those flows.
- **Backend-originated coverage:** OpenCode and Codex where the attached backend
  stream can authoritatively observe another surface; ACP/Cursor and Claude are
  explicitly limited to the bridge-owned process.
- **Client platform:** one release-target phone platform for L3. The desktop
  shell has no catalog surface, but downstream compile/analyze remains required.
- **Bridge host:** one release-target host; no host-specific ordering claim.
- **Peer compatibility:** current app with a pre-marker bridge fixture and
  current bridge payload with a pre-marker app decoder/fixture where available.

Any reduction to this matrix requires explicit user acceptance recorded here
before retirement.

## Expected PR Review Summaries

Every implementation PR body must include the repository-required sections.
Use these review focuses rather than duplicating the whole plan:

- **Step 2 complexity:** complex - backend-specific provenance across the shared
  plugin boundary, especially OpenCode compaction ordering.
- **Step 2 risk/test focus:** false recency from generated messages, duplicate
  facts, permission auto paths, and plugin lifecycle cleanup. No database or
  released-wire impact; no user-visible change yet.
- **Step 3 complexity:** complex - persisted nullable state, migration/codegen,
  ordered event consumption, and monotonicity.
- **Step 3 risk/test focus:** schema preservation, no dishonest backfill,
  display-root attribution, and not changing unseen behavior. Database impact:
  one nullable column; no user-visible change yet.
- **Step 4 complexity:** moderate - additive shared REST/SSE contract and bridge
  projections.
- **Step 4 risk/test focus:** mixed-version decode/encode, null omission, and
  committed-value delivery. No visible ordering change until Step 5.
- **Step 5 complexity:** moderate - client ordering plus live/REST race-safe
  merge.
- **Step 5 risk/test focus:** running-prefix policy, fallback behavior, no churn,
  and no project/child/inactive regression. User-visible impact: running sessions
  reorder by genuine interaction.

## Architecture Review

- **Reviewer:** `architecture-plan-review`
- **Reviewed scope:** complete `.plan/active/session-user-interaction-order/`
  against current plugin, bridge, shared, database, and client architecture
- **Initial verdict:** rejected with three actionable ownership findings
- **Findings applied:** moved OpenCode classifier state from the top-level plugin
  into `OpenCodeUserInteractionTracker`; named `CodexUserInteractionTracker` and
  one shared `CodexGeneratedContextValidator` with bounded lifecycle; moved live
  patch and REST max-merge policy from `SessionListCubit` into
  `SessionListService`
- **Re-review:** not run; repository policy applies valid concrete findings
  directly without a second review merely to approve the corrections
