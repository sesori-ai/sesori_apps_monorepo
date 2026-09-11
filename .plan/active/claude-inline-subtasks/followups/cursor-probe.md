# Cursor Native Task Probe

## Scope

Bounded native ACP probe on 2026-09-11 after PR #1431 merged at
`7dd323d1d762009d9a6f530630eb0683f986ab3d`.

- Current managed target: `cursor-agent 2026.08.11-e8db854`.
- Installed PATH runtime: `2026.07.23-e383d2b`; no managed Cursor runtime was
  present under the bridge plugin state directory.
- QA runtime: exact managed target archive, downloaded to a mode-0700 `/tmp`
  directory and verified against the pinned darwin-arm64 SHA-256
  `46044d6d7bcbd7b49a0cf1cd01aa4ca79aaa2ea5f2c7a32965fc0ebe29841790`.
  It was extracted only for this probe, not installed or selected in bridge
  configuration.
- Existing Cursor login, default model, and configuration were inherited
  unchanged. No login, auto-update, managed install, YOLO mode, endpoint
  override, or configuration write occurred.
- Inputs touched only newly created harmless scratch files and new probe
  sessions. `TMPDIR`, `TMP`, and `TEMP` were `/tmp`.

Raw prompts, transcripts, account data, session/tool/agent identifiers, and
permission payloads are intentionally absent here. Temporary raw captures lived
under a mode-0700 directory as mode-0600 files while facts were extracted, then
were deleted with the other owned probe resources.

## Native wire facts

### Standard Task and `cursor/task`

A completed foreground Task emitted this ordered shape:

1. standard `session/update` `tool_call`, title `Task: …`, `kind: other`,
   `status: pending`, and `rawInput` containing only `_toolName: task` live;
2. standard `tool_call_update {status: in_progress}`;
3. standard `tool_call_update {status: completed, rawOutput: {durationMs,
   isBackground: false}}`;
4. one `cursor/task` **JSON-RPC request**, not a notification, one millisecond
   later. Its params were exactly `toolCallId`, `agentId`, `description`,
   `prompt`, `subagentType`, `model`, and `durationMs`; it carried no session id
   or lifecycle discriminator;
5. the `session/prompt` response returned `stopReason: end_turn`.

The foreground Task ran for about 42 seconds. Its `cursor/task.durationMs`
matched the standard terminal update and its `toolCallId` matched all three
standard Task frames exactly. No `cursor/task` arrived at pending or
`in_progress`; it arrived once at terminal Task-tool completion.

Current production handling is incomplete: `AcpStdioClient` routes a frame with
both `id` and `method` to the server-request stream, while
`CursorApprovalRegistry` acknowledges/re-injects only generated-image and todo
requests. `CursorEventMapper.mapExtension` therefore cannot currently receive
native `cursor/task` requests.

### Foreground cancellation

A second foreground Task reached `pending`, then `in_progress`. The probe sent
standard `session/cancel` 13 ms after `in_progress`. The same outstanding
`session/prompt` returned authoritative `stopReason: cancelled` 9 ms later.
No terminal standard Task update and no `cursor/task` request followed before a
new prompt completed successfully on the same process and session.

This proves native root-turn cancellation and process survival for the observed
foreground case. It does not provide a separate child-terminal frame; Cursor
presentation must settle the in-flight Task from the authoritative prompt
result, not process death or a fabricated child response.

### Native background Task

Cursor does support native background Task launch. The standard Task call
reached `completed` with `rawOutput.isBackground: true` after 49–59 ms, followed
one millisecond later by one matching `cursor/task` request. The root prompt then
returned `end_turn` while the background task continued: a standard permission
request from that work arrived after the root turn had ended.

No second `cursor/task`, child-session event, or task-terminal update appeared
in a 90-second post-turn observation. `cursor/task` therefore describes Task
**tool invocation completion**: foreground invocation completion coincides with
sub-agent completion, while background invocation completion means only that
launch finished. It is not a universal child-finish event.

An active-turn cancellation sent immediately after a background launch got an
authoritative root `stopReason: cancelled` response 2 ms later. Background work
then emitted four permission requests between about 5 and 21 seconds after that
cancel, proving it survived root `session/cancel`. A later root prompt completed
on the same process. No background terminal lifecycle crossed ACP.

Consequences:

- Cursor cannot honestly claim full stop for a native background Task.
- The bridge-internal `SessionAborted` carries `workKept`, but
  `AbortSessionHandler` serializes only `subAgentsHandled`; the client maps every
  successful 2xx abort response to `SessionAbortOutcome.aborted`. Cursor must
  therefore never acknowledge `confirm`, `keep`, or `stop` while an unresolved
  background observation exists because `workKept` cannot qualify a success omitted
  from the client wire.
- Every policy fails through one explicit existing plugin/HTTP 409 path before
  root/input preparation or cancellation. No count, successful ACK, or shared
  wire field is invented for work whose current running count is unknowable.
  Step 3 maps an unparsed abort 409 to a typed client-local “not accepted”
  exception and preserves the local prompt queue; it does not confuse that
  refusal with an accepted abort.
- Background Task lifecycle cannot render completion merely because its launch
  call completed. Until Cursor exposes a terminal fact, background Tasks keep
  the honest generic Task card and remain a declared capability gap.
- Supported confirmation for active mode-unknown Tasks reports the exact
  observed Task count, `mainAgentOnlySupported: false`, and no `keep` action.
  There is no per-task cancel request.

### `session/load`

A fresh native process loaded the completed foreground session. Replay emitted
no `cursor/task` request. It emitted only:

- standard `tool_call {status: pending}` with replay `rawInput` containing
  exactly `_toolName`, `prompt`, `description`, and `subagentType`;
- matching standard `tool_call_update {status: completed, rawOutput:
  {durationMs, isBackground: false}}`.

`prompt` and `description` were strings. Observed `subagentType` was the typed
object shape `custom -> unspecified`, not the string assumed by the old plan.
Two consecutive loads returned the same replay-local tool-call id and facts, so
foreground replay has stable material for a typed tile. That replay id differed
from the original live id; projection must use normal replay identity rather
than assert live/replay id equality.

Loading the cancelled foreground session replayed no Task call. This is an
honest absence, not a running or cancelled tile to synthesize. No child session
or child transcript was exposed by any case.

## Coverage matrix

| Case | Result | Authority / limitation |
|---|---|---|
| Foreground Task start and finish | Passed | Standard pending/in-progress/completed plus one correlated terminal `cursor/task` request |
| Foreground root cancellation | Passed | Outstanding native prompt returned `stopReason: cancelled`; process handled a follow-up |
| Native background launch | Passed | Standard terminal `rawOutput.isBackground: true`; root ended before later background permission activity |
| Background full stop | Not supported | Background activity continued after authoritative root cancellation |
| Background terminal lifecycle | Not supported on observed ACP seam | No second task/terminal frame in 90 seconds; no child transcript |
| Cold foreground replay | Passed | Standard full Task facts and terminal update replayed; no `cursor/task` replay |
| Repeated replay identity | Passed | Replay-local tool-call id stable across two loads; not equal to original live id |
| Cancelled Task replay | Passed as absence | Native load omitted the cancelled Task entirely |
| Child session / child history | Not supported | No child session id or transcript crossed ACP |
| Phone / desktop product UI | Unexecuted | Probe was native harness-only; no client, desktop, simulator, relay, or account-state QA |

## Implementation plan against current code

### Exact files, classes, and composition

ACP changes stay backend-neutral:

- `bridge/sesori_plugin_acp/lib/src/repositories/trackers/acp_child_session_tracker.dart`
  extends the existing composition-owned `AcpChildSessionTracker`; no second
  live tracker is added. It gains tile-only Task records keyed by
  `(rootSessionId, toolCallId)` plus one session-level unresolved-background
  observation. Existing session-backed `_Child` records remain the only state
  carrying child ids, emitting child session/status events, contributing to
  child fanout, or keeping a root/session UI busy. The tracker exposes the
  backend-neutral aggregate `requiresProcessResidency` separately for ACP
  process work-state derivation. Recording the first unresolved observation,
  removing one through an authoritative terminal or `forgetSession`, and
  clearing observations through `clear()` each notify the affected root so the
  plugin recomputes process work state in both directions.
- New private `_AcpTileTask({required var PluginMessagePartTool genericPart,
  required var AcpTileTaskPhase phase})` lives in that tracker file; the
  enclosing nested maps own the root-session and
  tool-call keys. Closed `AcpTileTaskPhase` values are `activeModeUnknown` and
  `foregroundCompleted`; neither phase has a child-session field. A pending or
  in-progress standard Task is mode-unknown because `isBackground` appears only
  on its terminal frame. Backend-neutral tracker methods record that generic
  `PluginMessagePartTool`, mark terminal foreground completion, convert a
  terminal background launch into the root-level unresolved observation, expose
  the exact `activeTaskCount({required String rootSessionId})`, return the
  matching completed record through `takeCompletedForegroundTile({required
  String rootSessionId, required String toolCallId})`, and take-and-retire active
  generic parts through `takeActiveTaskInvocations({required String
  rootSessionId})` for cancellation or prompt-failure settlement. Existing
  method names `recordTileInvocation`, `updateTileInvocation`,
  `hasTileInvocation`, `completeForegroundTileInvocation`,
  `recordUnresolvedBackground`, `forgetTileInvocation`, and `beginTileTurn`
  remain, with required named parameters. No method calls `AcpChildSpawn` for
  tile-only state.
  Pending/in-progress parts stay generic. Only complete correlated terminal
  `isBackground: false` facts replace one generic part with a completed
  childless tile; prompt cancellation or failure settles the standard generic
  card and creates no subtask tile.
- `bridge/sesori_plugin_acp/lib/src/acp_event_mapper.dart` adds two neutral
  mapper lifecycle hooks:
  `mapPromptResult({required String sessionId, required AcpStopReason
  stopReason})` and `mapPromptLifecycleFailure({required String sessionId,
  required String failureMessage})`. Base behavior returns no events for both.
  The latter name is deliberately distinct from existing
  `AcpPlugin.mapPromptFailure`. `CursorEventMapper` overrides both; ACP never
  imports Cursor types, and every other harness remains unchanged. On parsed
  results, `AcpPlugin._runTurn` emits
  `mapPromptResult` events before `_finishTurn` completes the existing
  `activeSettlement` future. In the current catch path it keeps
  `eventMapper.mapPromptError`, then emits `mapPromptLifecycleFailure` with the
  same privacy-safe rendered failure message, then calls `_finishTurn`, then
  invokes plugin-level `mapPromptFailure` exactly as today.
- `bridge/sesori_plugin_acp/lib/src/acp_plugin.dart` adds neutral
  `AcpScopedStopCapability.rootSessionCancel` and one explicit branch in
  `abortSession`. Its unresolved-background guard is the first branch action,
  before root/input preparation and before descendant collection; it throws the
  one unsupported plugin operation described below. The remaining safe-Task
  branch cannot enter snapshot fanout, `cancelChild`, `stopScopedTree`, or
  child-id sets. After an explicit root stop awaits authoritative prompt
  settlement, it re-checks unresolved background before returning accepted.
  Existing `unsupported`, `perChildSnapshot` (Grok), and
  `completeNativeAtomic` (DeepSeek) branches keep their behavior.
- `bridge/sesori_plugin_acp/lib/src/models/acp_scoped_stop.dart` is inspected
  but gains no target type: Cursor has only the named root and must not turn a
  Task tool id into an `AcpScopedStopTarget`.
- `bridge/sesori_plugin_acp/lib/src/acp_session_loader.dart` keeps
  `AcpSessionReplayCollector` and every existing constructor/caller unchanged.
  Concrete `AcpReplayCollector` adds
  `buildWithToolPartReplacement({required String? modelId, required String?
  providerId, required String? variant, required
  AcpReplayToolPartReplacement toolPartReplacement})`; it materializes through
  the existing ordered `_build` path with that required replay-local
  replacement. Existing `buildWithAssistantSelection` still uses the
  constructor-injected replacement, so DeepSeek and Grok behavior does not
  change.

Cursor boundary and repository changes:

- `bridge/sesori_plugin_cursor/lib/src/api/models/cursor_task_dto.dart` owns all
  Cursor Task wire parsing. Source declarations and required named fields are:
  `CursorTaskInputDto({required CursorTaskTool toolName, required String?
  prompt, required String? description, required CursorSubagentTypeDto?
  subagentType})`; `CursorTaskOutputDto({required int? durationMs, required
  bool isBackground})`; `CursorSubagentTypeDto({required CursorSubagentType?
  custom})`; and `CursorTaskRequestDto({required String toolCallId, required
  String agentId, required String description, required String prompt,
  required CursorSubagentTypeDto subagentType, required String model, required
  int durationMs})`. `CursorTaskTool` and `CursorSubagentType` are closed enums
  with `unknown`; their JSON fields use `unknownEnumValue` for unrecognized
  non-null enum strings, never a Freezed `@Default`. A missing `custom` key in
  the object-shaped subagent DTO honestly decodes to null through the nullable
  field, so the input stays incomplete and preserves the generic card. No
  converter or JSON `defaultValue` is added. Generated
  `cursor_task_dto.freezed.dart` and `cursor_task_dto.g.dart` come only from
  codegen.
- `bridge/sesori_plugin_cursor/lib/src/repositories/mappers/cursor_task_mapper.dart`
  adds pure `const CursorTaskMapper()`. It has no dependencies or mutable
  fields. `mapLiveCompleted({required PluginMessagePartTool genericPart,
  required CursorTaskRequestDto request})`, `mapReplay({required
  PluginMessagePartTool genericPart, required CursorTaskInputDto input,
  required CursorTaskOutputDto output})`, `mapCancelled({required
  PluginMessagePartTool genericPart})`, and `mapFailed({required
  PluginMessagePartTool genericPart, required String failureMessage})` are the
  only presentation projections. Complete correlated foreground terminal facts
  produce one completed `PluginMessagePart.subtask` reusing the generic part's
  id/session/message identity and setting `childSessionID: null`; pending,
  in-progress, background, malformed, or incomplete facts keep the generic
  card. Cancellation maps the generic standard Task card to cancelled and
  prompt failure maps it to error with the privacy-safe failure message; neither
  creates a subtask tile. `agentId` remains Cursor correlation data and is never
  used as child identity.
- `bridge/sesori_plugin_cursor/lib/src/repositories/trackers/cursor_task_replay_tracker.dart`
  adds the only renamed replay class,
  `CursorTaskReplayTracker({required String sessionId, required
  AcpReplayCollector standardCollector, required CursorTaskMapper taskMapper})`.
  It implements `AcpSessionReplayCollector`, forwards each notification to the
  already-configured standard collector, and indexes typed Task input/output by
  replay-local `toolCallId`. At build it calls the collector's required
  `buildWithToolPartReplacement` seam with its own state-backed replacement,
  which delegates presentation to the injected pure mapper. It owns replay-
  local maps only: no ACP client, factory, file I/O, live tracker read, event-
  buffer write, or peer construction.
- `bridge/sesori_plugin_cursor/lib/src/cursor_event_mapper.dart` keeps the
  existing `CursorEventMapper` and adds required constructor field
  `CursorTaskMapper taskMapper`. Its existing required
  `AcpChildSessionTracker childSessions` remains the one live state owner.
  Override `map` parses standard Task DTOs and feeds the tracker after standard
  generic projection; `mapExtension` parses the re-injected `cursor/task` and
  asks the injected mapper to replace only a correlated completed foreground
  record; `mapPromptResult` takes every active mode-unknown record on a parsed
  cancelled result, maps its generic card to cancelled, and retires it;
  `mapPromptLifecycleFailure` takes every active mode-unknown record, maps its
  generic card to error with the supplied privacy-safe message, and retires it.
  Both use the same tracker plus injected `CursorTaskMapper`. One private task-
  observation method serves the standard/extension triggers. `abortSession`
  never creates or mutates presentation parts.
- `bridge/sesori_plugin_cursor/lib/src/cursor_approval_registry.dart`
  acknowledges `cursor/task` with the existing empty fire-and-forget response
  and re-injects one `AcpNotification`, like generated-image/todo handling.
  Parsing remains in the event mapper's typed Cursor boundary.
- `bridge/sesori_plugin_cursor/lib/src/cursor_plugin_impl.dart` remains the
  composition owner. `CursorPlugin.factory` constructs one
  `const CursorTaskMapper()` and injects that same instance into
  `CursorEventMapper` and `CursorPlugin._`; `CursorPlugin._` adds required
  `CursorTaskMapper taskMapper` and retains it only to compose replay.
  `CursorPlugin.scopedStopCapability` explicitly returns
  `AcpScopedStopCapability.rootSessionCancel`, making the dedicated neutral ACP
  branch reachable in Step 3. Its `createSessionReplayCollector({required
  String sessionId, required
  AcpReplayCollectorFactory collectorFactory})` override first calls
  `collectorFactory(toolPartSuppression: null)` for one fully configured
  standard collector, then injects that collector and the stored mapper into
  `CursorTaskReplayTracker`. The tracker receives no factory, and neither
  mapper nor tracker constructs its peer.
- `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_plugin_descriptor.dart`
  keeps constructing `CursorPlugin` through the existing factory; its public
  `CursorPluginFactory` signature does not gain repository peers. Test
  composition continues through `CursorPlugin.factory`.
- `client/module_core/lib/src/api/session_api.dart` adds local
  `SessionAbortApiNotAcceptedException({required Object innerError})`. An abort
  HTTP 409 that does not parse as the existing `SessionAbortRejection` throws
  this exception with the original `NonSuccessCodeError`; parsed confirmation
  rejections remain unchanged. A post-cancel partial failure does not use 409.
- New
  `client/module_core/lib/src/repositories/models/session_abort_not_accepted_exception.dart`
  adds `SessionAbortNotAcceptedException({required Object innerError})`.
  `SessionRepository.abortSession` translates the API exception at the existing
  API → repository boundary and retains it as `innerError`.
- `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`
  adds one request-lifetime `_abortRequestInFlight` gate. Queue draining returns
  while it is true. `abort` sets the gate before dispatch and no longer clears
  local prompts before `keep`/`stop`; accepted 2xx and ambiguous failures keep
  the existing clear behavior, while typed confirmation rejection and typed
  not-accepted failure return without clearing the queue or stale-options
  bookkeeping. The `finally` path releases the gate and retries normal drain.
  The not-accepted path logs once and returns the existing
  `SessionAbortOutcome.failed`, so no new UI state is required.

No other new production classes are planned. Existing constructor calls in
Cursor tests are updated for required fields. There is no shared wire,
bridge-app/database contract, child catalog row, compatibility shim, or Cursor
import in ACP.

### One lifecycle path

1. `CursorEventMapper.map` lets `AcpEventMapper` create the standard generic
   Task card, then parses `CursorTaskInputDto`/`CursorTaskOutputDto` and records
   that exact generic part in `AcpChildSessionTracker`.
2. Pending/in-progress is an active mode-unknown Task and remains a generic card
   because those frames lack prompt, description, and `isBackground`.
   A terminal standard update with `isBackground: false` changes the correlation
   record to `foregroundCompleted`; the generic completed card remains visible
   while the record awaits the immediately following request. A terminal update
   with `isBackground: true` retires the Task record into the session-level
   unresolved-background observation and never reaches tile projection.
3. Re-injected `cursor/task` parses to `CursorTaskRequestDto`. Only an exact
   `toolCallId` match in `foregroundCompleted` with complete terminal facts
   reaches `CursorTaskMapper.mapLiveCompleted`; one completed childless tile
   replaces the same part.
4. `AcpPlugin._runTurn` routes every parsed prompt result through
   `eventMapper.mapPromptResult` before `_finishTurn`. On `cancelled`, the
   Cursor override takes and retires all active mode-unknown generic parts and
   maps their standard-card status to cancelled. On dispatch timeout, RPC error,
   or malformed prompt response, the catch path emits the existing prompt error,
   invokes `mapPromptLifecycleFailure` before `_finishTurn`, and the Cursor
   override takes and retires those same records after mapping their generic
   cards to error. Neither path creates a subtask tile. Other parsed prompt
   results do not fabricate Task or background completion; specifically, no
   speculative missing-terminal handling is added for `end_turn`.
5. Ordering assumption, stated narrowly: standard Task terminal frames that
   precede the prompt result are mapped before active prompt settlement
   completes. The explicit-stop path can therefore await that settlement and
   re-check whether a mode-unknown Task became unresolved background. No quiet
   timer or poller is added.
6. A later turn may clear only completed foreground correlation records through
   the already-called `beginTurn` path. It must not clear the unresolved
   background observation.

### Background observation and process residency

`rawOutput.isBackground: true` removes that tool id from active Task state
and records only `rootSessionId` in a set such as
`_rootsWithUnresolvedTileBackgroundWork`. It is deliberately a boolean fact per
session, not a tool-id set or running-task count: native ACP proves at least one
launch escaped the root turn, but does not reveal how many remain running or
when they finish.

The observation survives `end_turn`, later turns, and later permission/question
requests. It clears only from an authoritative native terminal fact if Cursor
adds one, `forgetSession(sessionId:)` on explicit session deletion, or `clear()`
on ACP process teardown/reset/disposal. Current Cursor supplies no terminal
fact, so normal cleanup is session/process teardown.

`AcpChildSessionTracker.requiresProcessResidency` is true while any such
observation exists. `AcpPlugin._syncWorkState` includes that property in its
`PluginWorkState.busy` computation, beside pending turns, pending input, and
real child work. A false-to-true record emits the existing
`AcpChildSessionTrackerChange` for its root. `forgetSession` includes removal of
an unresolved observation in its active-work notification even when that root
has no children or holds. `clear()` includes every unresolved root in its
`affectedRoots`, clears the set, and notifies each root; a future authoritative
terminal clear does the same. The existing `AcpPlugin._onChildSessionsChanged`
listener reruns `_syncWorkState` after each transition, so work state cannot
remain falsely idle after recording or falsely busy after cleanup. No timer,
poller, or lifecycle synthesis is added. This prevents configured safe idle
suspension from silently killing work known to have escaped its root turn.

The property is deliberately excluded from `hasBusyChildren`,
`hasActiveWorkForRoot`, `activeRootSessionIds`, `hasActiveWork`, session status,
deferred root idle, active-session summaries, and sub-agent counts. Concretely,
`AcpPlugin._finishTurn`, `_onChildSessionsChanged`, `getSessionStatuses`,
`getActiveSessionsSummary`, and `interruptActiveWork` keep their existing root/
child predicates and do not query `requiresProcessResidency`; only
`_syncWorkState` does. Native `end_turn` therefore still emits honest root idle
and does not pin root/session UI busy, fabricate completion, or create a
background completion notification or tile. A later pending interaction remains
busy through the existing approval registry only for that interaction's
lifetime.

Safety tradeoff: because Cursor emits no background terminal fact, a silently
completed launch can keep `PluginWorkState` busy and block safe idle suspension
until explicit session deletion or process reset. This indefinite process-
residency false positive is accepted. Forced plugin stop/process teardown and
explicit session cleanup remain possible and clear the observation; they may
terminate native background work. Cursor background lifecycle and full-stop
guarantees remain unsupported.

`activeTaskCount` is exact: it counts standard Task invocations observed
pending/in-progress and not yet terminal or prompt-settled. Their mode remains
unknown until terminal `isBackground` arrives. The unresolved-background flag
is separate and never contributes a fabricated `runningSubAgentCount`.

### Safe Task root stop policy

The `rootSessionCancel` branch targets only the method's named `sessionId`.
Its first operation checks the unresolved-background observation. When present,
all three policies throw the same side-effect-free
`PluginOperationException` for operation `abortSession`, HTTP status 409, and
backend-neutral message
`Cannot stop while resident background work has unknown completion`. This uses
existing plugin-operation → router HTTP failure path, introduces no
new shared response, and runs before queued/writing work, pending interaction,
root cancellation, settlement capture, descendant collection, or fanout.
`SessionApi.abortSession` cannot parse this plain 409 as the existing typed
confirmation rejection, so it throws the client-local
`SessionAbortApiNotAcceptedException` with the original error. The repository
translates that to `SessionAbortNotAcceptedException`; `SessionDetailCubit.abort`
returns failed rather than aborted while retaining its queued prompts. A
request-lifetime drain gate prevents those prompts from dispatching until the
refusal is known, then normal drain resumes. This changes no shared wire shape.

Without an unresolved-background observation, `confirm` and `keep` with
`activeTaskCount > 0` return the existing
`PluginAbortRejectedSubAgentsRunning`, mapping that exact count through
`runningSubAgentCount`, the existing root-turn fact through
`mainAgentRunning`, and `mainAgentOnlySupported: false`. The current repository
and router then serialize the existing `SessionAbortRejection`; no new result
or wire field is introduced. Explicit `stop` captures the existing
`activeSettlement` future when a prompt is in
flight, prepares only that root's queued/writing work and pending interaction,
sends exactly one standard `session/cancel` for that root when the live client
exists (and zero only when no process exists to notify), and waits for that
captured settlement. It then **must re-check** unresolved background before any
accepted response. If a mode-unknown Task terminal changed to background while
cancellation settled, the branch throws a separate backend-neutral
`PluginOperationException` with HTTP 502: root cancellation has already happened,
so this partial failure deliberately follows the existing ambiguous-failure
queue cleanup rather than the non-mutating 409 path. The client never receives
false aborted success. Only when settlement leaves no unresolved background may
the branch return
`PluginAbortAccepted(workKept: false, subAgentsHandled: false)`. No child id,
Task id, known client child id, ancestor, sibling, or descendant enters
preparation or native dispatch.

| Named-root state | Policy | Effect | Result |
|---|---|---|---|
| Any prior unresolved-background observation | `confirm` / `keep` / `stop` | None | Same explicit unsupported HTTP failure |
| Active mode-unknown Tasks `N > 0`, no prior unresolved background | `confirm` | None | Exact typed rejection `N`; main running; main-only false |
| Active mode-unknown Tasks `N > 0`, no prior unresolved background | `keep` | None | Same exact typed rejection |
| Active mode-unknown Tasks `N > 0`, no prior unresolved background | `stop` | Named-root prepare/cancel; await authoritative prompt settlement; re-check background | ACK kept=false/handled=false only if no unresolved background; otherwise HTTP 502 partial failure after cancellation |
| No active Task/background fact | `confirm` / `stop` / `keep` | Existing named-root cancellation; re-check after any captured settlement | ACK kept=false, handled=false only while no unresolved background |

`subAgentsHandled` is always false because Cursor exposes no child targets or
complete background authority. Every accepted Cursor path reports
`workKept: false` only after proving no unresolved background remains at the
post-settlement re-check. Background full stop remains unsupported.

### Replay and unsupported behavior

Replay uses only typed standard Task facts. Complete foreground input plus
`isBackground: false` may replace the generic part. `isBackground: true`,
missing/malformed input/output, or incomplete presentation facts preserve the
generic card. Native cancelled replay absence remains absence. Repeated loads
reuse native replay-local identity without asserting equality to the original
live id.

Still unsupported: background terminal lifecycle, accurate background running
count, full background stop, background history tile, child session/transcript,
child navigation, per-child stop, and live/replay child-history parity. The
client sees the existing generic Task card for those unobservable cases; no
false child id, tile completion, or history row is produced.

### Delivery slices

Five slices preserve the actual review diff: native probe/corrected-plan docs
land first, then completed live tiles, safe Task stop policy, replay, and final
actual-plugin evidence. Feature implementation has not landed; successors must
be regenerated from this revised plan. Line sizes include source, generated
serializers, tests, each behavior slice's regression docs, and tracker
bookkeeping.

Existing code refs `c5c0def` (former live slice) and `ab03528` (former scoped-
stop slice) remain preserved as stale, unpublishable historical implementation
evidence after the transport/client, process-residency, and completion-only
corrections here; do not mutate or delete them. Regenerate both successors from
this revised plan.

1. `🌱 [claude-inline-subtasks] docs: record Cursor native probe and corrected plan [step 1/5]`:
   this privacy-safe native evidence, corrected ownership/policy design, and
   exact delivery sequence only. No feature implementation. This step remains
   unchecked until its PR merges.
2. `🚧 [claude-inline-subtasks] cursor: completed foreground Task tiles [step 2/5]`
   (expected approximately 1,550–1,750 changed lines): neutral tile-only
   correlation, parsed-result and prompt-failure mapper lifecycle hooks, Cursor
   DTOs/codegen, one injected `CursorTaskMapper`, request forwarding, completed
   foreground replacement, generic cancelled/error settlement with record
   retirement, focused ACP/Cursor tests, and corresponding
   `docs/regression/tools-and-file-changes.md` plus
   `docs/regression/session-turns.md` behavior updates. Pending/in-progress and
   background calls stay generic; cancellation creates no tile. No scoped-stop
   authority, unresolved-background residency state, or replay wrapper.
3. `⚙️ [claude-inline-subtasks] cursor: safe Task stop policy [step 3/5]`
   (expected approximately 750–1,050 changed lines): exact active mode-unknown
   Task count, durable unresolved-background observation and
   `requiresProcessResidency`, first-action unsupported guard for all policies,
   safe `rootSessionCancel` with mandatory post-settlement background re-check,
   typed client-local non-acceptance plus a request-lifetime queue-drain gate,
   focused tests, and
   corresponding scoped-stop/lifecycle/capability updates in
   `docs/regression/session-turns.md`,
   `docs/regression/plugin-setup-and-lifecycle.md`, and
   `docs/HARNESS_CAPABILITIES.md`.
4. `⚙️ [claude-inline-subtasks] cursor: replay completed foreground Task tiles [step 4/5]`
   (expected approximately 650–1,000 changed lines):
   `repositories/trackers/cursor_task_replay_tracker.dart`, plugin replay
   composition with one already-configured ACP collector and the same injected
   mapper, complete/malformed/background/cancelled/repeated-load projection
   tests, live/replay shape convergence without live-id equality, and the
   corresponding `docs/regression/session-history-and-recovery.md` update.
5. `🌱 [claude-inline-subtasks] docs: record Cursor sub-agent coverage [step 5/5]`
   (expected approximately 60–140 changed lines): run and record bounded
   actual-plugin evidence, reconcile final claims against already-landed
   behavior docs/capability entries, and record every unsupported/unexecuted
   boundary. This is not the first behavior-document update for Steps 2–4.
   Overall plan remains active while the separate Grok phone gate is blocked.

### Bounded verification plan

Step 2 automated scope:

- `bridge/sesori_plugin_acp`: tracker tests prove session-backed children remain
  the only child-id/fanout/root-busy state and tile-only Task correlation does
  not alter those snapshots; parsed prompt results and prompt lifecycle failures
  map before root turn settlement.
- `bridge/sesori_plugin_cursor`: DTO valid/unknown/malformed fixtures,
  object-shaped `subagentType` (including missing `custom` → null/incomplete),
  `cursor/task` ack/re-injection, standard → request correlation, pending/in-
  progress mode-unknown generic cards, completed foreground tile replacement
  only after complete correlated terminal facts, prompt-cancel generic-card
  cancellation and prompt-failure generic-card error with record retirement,
  background generic retention, no child id, and constructor/composition tests.
  Run package analyzers/tests and `git diff --check`.

Step 3 automated scope:

- Exact `activeTaskCount` for mode-unknown Tasks and unresolved background remain
  independent; the count maps through the existing
  `PluginAbortRejectedSubAgentsRunning`/`SessionAbortRejection` path with no wire
  change. The observation survives turns, leaves root status/active summaries/
  deferred idle/counts unchanged, and alone keeps ACP `PluginWorkState` busy
  through `requiresProcessResidency`. Tests cover work-state resync when the
  first observation is recorded and when authoritative clear, root-only
  `forgetSession`, or process-wide `clear()` removes it.
- Every prior unresolved-background `confirm`/`keep`/`stop` takes the same
  explicit HTTP 409 before root/input preparation or cancellation; client tests
  assert its typed API/repository translation, no local queue or stale-options
  cleanup, no drain during the request, resumed normal drain afterward, and no
  successful ACK or fabricated count. Accepted responses and ambiguous failures
  still clear the queue. A background transition discovered only after root
  cancellation uses HTTP 502 and the ambiguous-failure cleanup path.
  Active mode-unknown `confirm`/`keep`, named-root `stop`, prompt settlement
  ordering, post-settlement background-transition failure (with root cancel
  already allowed), accepted `workKept: false` only after the re-check, forced
  process cleanup, explicit session deletion, and unchanged DeepSeek/Grok
  branches remain covered.

Step 4 automated scope:

- Complete foreground replay replaces the exact generic part; repeated loads
  keep replay-local identity; live/replay fields converge without requiring
  live-id equality; background/missing/malformed facts retain generic; cancelled
  absence stays absent.
- Composition test proves `CursorTaskReplayTracker` receives one configured
  `AcpReplayCollector` and the factory-built shared `CursorTaskMapper`; tracker
  has no live state, transport, or I/O. Run Cursor/ACP replay-focused tests and
  analyzers plus `git diff --check`.

Step 5 actual-plugin scope uses `CursorPlugin` production composition and the
managed `2026.08.11-e8db854` target: completed foreground replacement after
terminal correlation; pending/in-progress mode-unknown generic presentation;
exact side-effect-free active-Task confirmation; rejected active-Task keep;
authoritative named-root stop with a generic cancelled card; race coverage where
a Task resolves background before prompt settlement and yields failure rather
than aborted success; process/session reuse; repeated cold load; background
generic card; honest root idle after native
`end_turn`; process residency after later background permission; and identical
side-effect-free unsupported failure for post-background `confirm`, `keep`, and
`stop`. Verify no successful ACK, root/input cancellation, background
completion notification, or tile claim for those cases. Phone/desktop
presentation, child navigation/history, background completion, and full
background stop remain unexecuted/unsupported rather than inferred.

Do not recreate the cleaned native captures merely for confidence. Future
actual-plugin QA must retain raw prompts, transcripts, ids, permission payloads,
logs, and timing captures as private evidence after every owned process/session
and scratch resource is cleaned and cleanup is verified. Never commit that
private evidence or replace it with a public raw capture.
