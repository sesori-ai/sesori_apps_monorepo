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
- Every policy returns one explicit backend-neutral not-performed result before
  root/input preparation or cancellation. The bridge serializes its required
  discriminator as a typed HTTP 409 refusal; no count or successful ACK is
  invented for work whose current running count is unknowable. Step 4 preserves
  the local prompt queue only after decoding that exact discriminator, never by
  inferring lifecycle semantics from an arbitrary or malformed 409.
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

- `AcpChildSessionTracker` remains limited to real ACP child sessions and root
  holds. Cursor Task correlation never enters its activity, root-busy, count,
  fanout, stop, deletion, or reset paths.
- Step 3 extends Cursor-owned correlation with the completed foreground phase,
  exact root/tool lookup, one-shot replacement, and next-turn stale cleanup.
  Step 4 then adds exact active count plus one root-level unresolved-background
  observation and Cursor-owned process-residency policy. Pending/in-progress
  remains mode-unknown because `isBackground` appears only on terminal output.
  No Task-only method calls `AcpChildSpawn`.
- `bridge/sesori_plugin_acp/lib/src/acp_event_mapper.dart` adds two neutral
  mapper lifecycle hooks:
  `mapPromptResult({required String sessionId, required AcpStopReason
  stopReason})` and `mapPromptLifecycleFailure({required String sessionId,
  required String failureMessage})`. Base behavior returns no events for both.
  The latter name is deliberately distinct from existing
  `AcpPlugin.mapPromptFailure`. `CursorEventMapper` overrides both; ACP never
  imports Cursor types, and every other harness remains unchanged. On parsed
  results, `AcpPlugin._runTurn` emits `mapPromptResult` events only while the
  completing turn still owns the session's current turn state, before
  `_finishTurn` completes the existing `activeSettlement` future. In the catch
  path it keeps `eventMapper.mapPromptError`, emits
  `mapPromptLifecycleFailure` with the same privacy-safe rendered failure
  message only for the still-owned turn, then calls `_finishTurn`, then invokes
  plugin-level `mapPromptFailure` exactly as today. Detached turns still settle
  pending/accounting in `_finishTurn` without touching Cursor Task state.
- `bridge/sesori_plugin_acp/lib/src/acp_plugin.dart` adds neutral
  `AcpScopedStopCapability.rootSessionCancel` and one explicit branch in
  `abortSession`. Its unresolved-background guard is the first branch action,
  before root/input preparation and before descendant collection; it returns
  `PluginAbortNotPerformed(reason:
  PluginAbortRefusalReason.residentWorkCompletionUnknown)`. The remaining safe-Task
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
  Cursor Task wire parsing. Step 2's minimal Freezed source contains only
  `CursorTaskInputDto({required CursorTaskTool toolName})` for `_toolName`.
  `CursorTaskTool` is closed with `unknown`; `unknownEnumValue` handles an
  unrecognized non-null string, while no `@Default` or converter is used. Step
  3 adds output/request/subagent presentation DTO fields only when completed
  tile correlation consumes them. Generated files come only from codegen.
- `bridge/sesori_plugin_cursor/lib/src/trackers/cursor_task_tracker.dart`
  owns process-local generic Task correlation and deletion tombstones without
  any ACP child/root activity API. `CursorEventMapper` keeps the two Step 2
  terminal projections private: both preserve exact generic-card identity and
  presentation fields, and failure text is bounded. Step 3 adds its completed
  foreground projection privately. Step 5 may extract shared pure projection
  only when live and replay become current consumers. Complete correlated
  foreground facts then produce one completed childless
  `PluginMessagePart.subtask`; pending, background, malformed, incomplete,
  cancelled, and failed cases remain generic. `agentId` is correlation data,
  never child identity.
- `bridge/sesori_plugin_cursor/lib/src/repositories/trackers/cursor_task_replay_tracker.dart`
  adds the only renamed replay class,
  `CursorTaskReplayTracker({required String sessionId, required
  AcpReplayCollector standardCollector, required CursorTaskProjection taskProjection})`.
  It implements `AcpSessionReplayCollector`, forwards each notification to the
  already-configured standard collector, and indexes typed Task input/output by
  replay-local `toolCallId`. At build it calls the collector's required
  `buildWithToolPartReplacement` seam with its own state-backed replacement,
  which delegates presentation to the injected pure projection. It owns replay-
  local maps only: no ACP client, factory, file I/O, live tracker read, event-
  buffer write, or peer construction.
- `bridge/sesori_plugin_cursor/lib/src/cursor_event_mapper.dart` keeps the
  existing `CursorEventMapper` and adds required constructor field
  `CursorTaskTracker taskTracker` beside its existing ACP child tracker. In
  Step 2, override `map` identifies standard Task calls after generic
  projection, records/updates pending/running parts, and forgets every standard
  terminal card. The re-injected `cursor/task` is intentionally ignored.
  `mapPromptResult` takes every active mode-unknown record on a parsed cancelled
  result, maps its generic card to cancelled, and retires it;
  `mapPromptLifecycleFailure` takes every active mode-unknown record, maps its
  generic card to error with the supplied privacy-safe message, and retires it.
  Both use the Cursor-local tracker plus private terminal projections. Step 3
  extends the private observation path and `mapExtension` for completed foreground
  correlation. `abortSession` never creates or mutates presentation parts.
- `bridge/sesori_plugin_cursor/lib/src/cursor_approval_registry.dart`
  acknowledges `cursor/task` with the existing empty fire-and-forget response
  and re-injects one `AcpNotification`, like generated-image/todo handling.
  Parsing remains in the event mapper's typed Cursor boundary.
- `bridge/sesori_plugin_cursor/lib/src/cursor_plugin_impl.dart` remains the
  composition owner. Step 2 constructs one `CursorTaskTracker`, injects it into
  `CursorEventMapper`, and clears it from `onConnectionReset` after pending RPC
  failures have resumed their turn catch paths. Reset fabricates no terminal
  Task event. Step 5 may compose a shared pure projection if replay creates the
  second current consumer. Step 4 makes
  `CursorPlugin.scopedStopCapability` return
  `AcpScopedStopCapability.rootSessionCancel`, reaching the dedicated neutral
  ACP branch. Its `createSessionReplayCollector({required
  String sessionId, required
  AcpReplayCollectorFactory collectorFactory})` override first calls
  `collectorFactory(toolPartSuppression: null)` for one fully configured
  standard collector, then injects that collector and the stored projection into
  `CursorTaskReplayTracker`. The tracker receives no factory, and neither
  mapper nor tracker constructs its peer.
- `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_plugin_descriptor.dart`
  keeps constructing `CursorPlugin` through the existing factory; its public
  `CursorPluginFactory` signature does not gain repository peers. Test
  composition continues through `CursorPlugin.factory`.
- `bridge/sesori_plugin_interface/lib/src/models/plugin_abort.dart` adds closed
  `PluginAbortRefusalReason.residentWorkCompletionUnknown` and
  `PluginAbortNotPerformed({required PluginAbortRefusalReason reason})`.
  Cursor's pre-mutation guard returns this neutral result; no backend term enters
  shared or client layers.
- `shared/sesori_shared/lib/src/models/sesori/abort_session_request.dart` adds
  a `kind`-keyed `SessionAbortRefusal` union: concrete `notPerformed` requires a
  backend-neutral `SessionAbortRefusalReason`, while the unknown/future fallback
  carries no reason. Unknown non-null reasons on `notPerformed` map to the closed
  enum fallback; missing or malformed variant data never becomes trusted.
  Generated serializers are regenerated from source only.
- `bridge/app/lib/src/repositories/models/session_abort_result.dart`,
  `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart`, and
  `bridge/app/lib/src/repositories/session_repository.dart` map the plugin result
  exhaustively to `SessionAbortNotPerformed({required SessionAbortNotPerformedRefusal
  refusal})`. `SessionAbortService` treats it as failed/no completion push, and
  `AbortSessionHandler` serializes the typed refusal body with HTTP 409. No
  plugin exception or string matching carries this expected outcome.
- `client/module_core/lib/src/api/session_api.dart` decodes abort 409 bodies as
  either the existing `SessionAbortRejection` or `SessionAbortRefusal`. Only an
  exact `kind: notPerformed` throws
  `SessionAbortApiNotAcceptedException({required SessionAbortNotPerformedRefusal refusal,
  required Object innerError})`; malformed and unknown-kind 409s stay ordinary
  ambiguous errors. A post-cancel partial failure does not use 409.
- New
  `client/module_core/lib/src/repositories/models/session_abort_not_accepted_exception.dart`
  adds `SessionAbortNotAcceptedException({required SessionAbortNotPerformedRefusal refusal,
  required Object innerError})`. `SessionRepository.abortSession` translates the
  API exception at the existing API → repository boundary and retains it as
  `innerError`.
- `client/module_core/lib/src/cubits/session_detail/session_abort_outcome.dart`
  adds closed `SessionAbortNotAccepted({required SessionAbortNotPerformedRefusal refusal})`.
  This is distinct from generic `failed` and from the existing sub-agent-count
  rejection; each variant carries only its valid data.
- `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`
  adds one request-lifetime `_abortRequestInFlight` gate. Queue draining returns
  while it is true. `abort` sets the gate before dispatch and no longer clears
  local prompts before `keep`/`stop`; accepted 2xx and ambiguous failures keep
  the existing clear behavior, while typed confirmation rejection and exact
  typed not-performed refusal return without clearing the queue or stale-options
  bookkeeping. The `finally` path releases the gate and retries normal drain.
  The not-accepted path returns the new typed outcome without redundant logging;
  the remote failure retains its original cause in the repository exception.
- `client/module_app_ui/lib/src/features/session_detail/widgets/session_abort_scope_dialog.dart`
  handles `SessionAbortNotAccepted` with a shared localized explanation: the
  harness has background work whose completion cannot be verified, Sesori did
  not stop the session, and restarting the harness is the available recovery.
  Add source localization keys and regenerate localization output; unknown
  refusal reasons receive a generic not-performed explanation. This explicit
  limitation needs no analytics event because it is neither an authoritative
  success nor an adoption decision.

No other new production classes are planned. Existing constructor calls in
Cursor tests are updated for required fields. There is no database change,
child catalog row, compatibility shim, or Cursor import in ACP. The additive
error body is forward/backward safe: released clients treat it as an ordinary
failed abort rather than false success; newer clients still parse released
bridges' existing `SessionAbortRejection` and treat every unknown/malformed 409
conservatively.

### One lifecycle path

1. `CursorEventMapper.map` lets `AcpEventMapper` create the standard generic
   Task card, then parses `CursorTaskInputDto`/`CursorTaskOutputDto` and records
   that exact generic part in Cursor-owned `CursorTaskTracker`.
2. Pending/in-progress is an active mode-unknown Task and remains a generic card
   because those frames lack prompt, description, and `isBackground`.
   A terminal standard update with `isBackground: false` changes the correlation
   record to `foregroundCompleted`; the generic completed card remains visible
   while the record awaits the immediately following request. A terminal update
   with `isBackground: true` retires the Task record into the session-level
   unresolved-background observation and never reaches tile projection.
3. Re-injected `cursor/task` parses to `CursorTaskRequestDto`. Only an exact
   `toolCallId` match in `foregroundCompleted` with complete terminal facts
   reaches the event mapper's completed foreground projection; one completed childless tile
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

Step 4 adds `CursorTaskTracker.requiresProcessResidency` while any such
observation exists and a narrow Cursor-owned work-state hook into `AcpPlugin`;
it must not store this fact or emit changes through `AcpChildSessionTracker`.
The hook contributes only to `PluginWorkState.busy`, beside pending turns,
pending input, and real child work. Cursor-owned observation changes trigger
work-state resynchronization; deletion/reset clears them. No timer, poller, or
lifecycle synthesis is added. This prevents configured safe idle suspension
from silently killing work known to have escaped its root turn.

The property is deliberately excluded from child activity, root/session status,
deferred root idle, active-session summaries, sub-agent counts, fanout, and
stop targeting. Concretely, `AcpPlugin._finishTurn`, child-change handling,
`getSessionStatuses`, `getActiveSessionsSummary`, and `interruptActiveWork` keep
their existing root/child predicates and do not query Cursor Task residency.
Native `end_turn` therefore still emits honest root idle
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
all three policies return the same side-effect-free
`PluginAbortNotPerformed(reason:
PluginAbortRefusalReason.residentWorkCompletionUnknown)`. The bridge maps it to
`SessionAbortRefusal.notPerformed(reason:
SessionAbortRefusalReason.residentWorkCompletionUnknown)` and an HTTP 409 before
queued/writing work, pending interaction, root cancellation, settlement
capture, descendant collection, or fanout. `SessionApi.abortSession` recognizes
only that required typed discriminator, then the API/repository exceptions carry
the refusal and original transport error. `SessionDetailCubit.abort` returns
the typed not-accepted outcome rather than aborted while retaining its queued
prompts. The shared UI renders the explicit limitation. A request-lifetime drain
gate prevents those prompts from dispatching until the refusal is known, then
normal drain resumes. A recognized `notPerformed` kind remains non-mutating
when its reason is unknown; missing/malformed bodies and unknown kinds remain
ambiguous and keep existing queue cleanup.

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
exists (and zero only when no process exists to notify), and waits at most 20
seconds for that captured settlement. It then **must re-check** unresolved
background and `activeTaskCount` before any accepted response. Timeout, surviving
mode-unknown work, or a Task terminal that changed to background while cancellation
settled makes the branch throw a separate backend-neutral
`PluginOperationException` with HTTP 502: root cancellation has already happened,
so this partial failure deliberately follows the existing ambiguous-failure
queue cleanup rather than the non-mutating 409 path. The client never receives
false aborted success. Only when settlement leaves no unresolved background or
active mode-unknown work may the branch return
`PluginAbortAccepted(workKept: false, subAgentsHandled: false)`. No child id,
Task id, known client child id, ancestor, sibling, or descendant enters
preparation or native dispatch.

| Named-root state | Policy | Effect | Result |
|---|---|---|---|
| Any prior unresolved-background observation | `confirm` / `keep` / `stop` | None | Typed not-performed HTTP 409 refusal |
| Active mode-unknown Tasks `N > 0`, no prior unresolved background | `confirm` | None | Exact typed rejection `N`; main running; main-only false |
| Active mode-unknown Tasks `N > 0`, no prior unresolved background | `keep` | None | Same exact typed rejection |
| Active mode-unknown Tasks `N > 0`, no prior unresolved background | `stop` | Named-root prepare/cancel; bounded settlement wait; re-check background and active count | ACK kept=false/handled=false only if both clear; otherwise HTTP 502 partial failure after cancellation |
| No active Task/background fact | `confirm` / `stop` / `keep` | Existing named-root cancellation; bounded re-check after any captured settlement | ACK kept=false, handled=false only while no unresolved background or active Task |

`subAgentsHandled` is always false because Cursor exposes no child targets or
complete background authority. Every accepted Cursor path reports
`workKept: false` only after proving no unresolved background or active Task
remains at the post-settlement re-check. Background full stop remains unsupported.

### Replay and unsupported behavior

Replay uses only typed standard Task facts. Complete foreground input plus
`isBackground: false` replaces the exact materialized generic part. `isBackground: true`,
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

Six slices replace the oversized reviewed combined Step 2 checkpoint: generic
lifecycle first, completed live tiles second, then safe stop, replay, and final
actual-plugin evidence. Full checkpoint `5cc54ad013` changed 2,038 lines and is
preserved by branches `claude-inline-subtasks-cursor-tiles-step2-of5` and
`checkpoint/cursor-step2-combined-reviewed-5cc54`; never mutate/delete them.
Refs `c5c0def` and `ab03528` remain stale, unpublishable historical evidence.
Regenerate each successor from its merged predecessor. Line sizes include
source, generated serializers, tests, behavior docs, and tracker bookkeeping.

1. `🌱 [claude-inline-subtasks] docs: record Cursor native probe and corrected plan [step 1/6]`:
   PR #1435 merged at `b83b64901c`; supervisor owns GitHub title update. Docs
   only, no feature implementation.
2. `🚧 [claude-inline-subtasks] cursor: settle generic Task lifecycle [step 2/6]`
   merged as PR #1438 at `116392cb71`: active generic-part tracking,
   pending/running observation, every standard terminal forget, generic
   cancelled/error settlement, `cursor/task` request ack, NDJSON exit ordering,
   focused ACP/Cursor/runtime tests, behavior docs, and late typed-refusal plan
   correction only. No tile, completed correlation, residency, stop, or replay.
3. `🚧 [claude-inline-subtasks] cursor: completed foreground Task tiles [step 3/6]`
   merged as PR #1441 at `bb85f48148`: completed correlation/review fixes,
   childless replacement, tests, and live-tile capability/docs. Step 4 is based
   on that merged commit; pre-squash `d3297ad4b9` has the same tree.
4. `🚧 [claude-inline-subtasks] cursor: safe Task stop policy [step 4/6]`
   merged as PR #1442 at `a7d3014e1a`: exact active count, unresolved-background
   residency, typed refusal, safe `rootSessionCancel`, and concurrent descendant
   fallback with mandatory settlement re-check; no replay/native QA.
5. `⚙️ [claude-inline-subtasks] cursor: replay completed foreground Task tiles [step 5/6]`
   is open as PR #1443 with one configured standard ACP collector and shared typed
   `CursorTaskProjection`, fallbacks, tests, history docs, and no native QA.
6. `🌱 [claude-inline-subtasks] docs: record Cursor sub-agent coverage [step 6/6]`
   (expected 60–140 changed lines): bounded actual-plugin evidence and final
   reconciliation only; unsupported/unexecuted boundaries remain explicit.

### Bounded verification plan

Step 2 automated scope:

- `bridge/sesori_plugin_acp`: tracker tests prove generic Task records remain
  outside child id/fanout/root-busy snapshots; prompt result/failure mapping runs
  before root settlement.
- `bridge/sesori_plugin_cursor`: minimal DTO valid/unknown/missing fixtures,
  request ack/reinjection, pending/running tracking, all standard terminal
  retirement, cancellation/error mapping and retirement, process-exit ordering,
  no tile/child activity, and composition tests.
- `bridge/sesori_plugin_runtime`: current-generation pending response failure
  precedes public exit settlement; stale-generation isolation remains covered.
  Run owning package tests/analyzers, source codegen, and `git diff --check`.

Step 3 automated scope proves completed foreground correlation/replacement,
minimal added DTO fields, incomplete/background fallbacks, one-shot consumption,
and no child id or activity. Run ACP/Cursor focused tests and analyzers.

Step 4 automated scope:

- Exact `activeTaskCount` for mode-unknown Tasks and unresolved background remain
  independent; the count maps through the existing
  `PluginAbortRejectedSubAgentsRunning`/`SessionAbortRejection` path with no wire
  change. The observation survives turns, leaves root status/active summaries/
  deferred idle/counts unchanged, and alone keeps ACP `PluginWorkState` busy
  through `requiresProcessResidency`. Tests cover work-state resync when the
  first observation is recorded and when authoritative clear, root-only
  `forgetSession`, or process-wide `clear()` removes it.
- Every prior unresolved-background `confirm`/`keep`/`stop` returns the same
  typed plugin not-performed result before root/input preparation or
  cancellation. Shared serializer and bridge repository/service/route tests
  assert the required kind/reason, HTTP 409 body, no successful ACK, and no
  fabricated count. Client tests assert exact kind decoding, API/repository
  translation, the sealed cubit outcome, no local queue or stale-options
  cleanup, no drain during the request, resumed normal drain afterward, and the
  localized shared limitation dialog. Malformed/unknown-kind 409s, accepted
  responses, and ambiguous failures still clear the queue. A
  background transition discovered only after root cancellation uses HTTP 502
  and the ambiguous-failure cleanup path.
  Active mode-unknown `confirm`/`keep`, named-root `stop`, prompt settlement
  ordering, post-settlement background-transition failure (with root cancel
  already allowed), accepted `workKept: false` only after the re-check, forced
  process cleanup, explicit session deletion, and unchanged DeepSeek/Grok
  branches remain covered.

Step 5 automated scope:

- Complete foreground replay replaces the exact generic part; repeated loads
  keep replay-local identity; live/replay fields converge without requiring
  live-id equality; background/missing/malformed facts retain generic; cancelled
  absence stays absent.
- Composition test proves `CursorTaskReplayTracker` receives one configured
  `AcpReplayCollector` and the shared pure projection extracted when replay lands; tracker
  has no live state, transport, or I/O. Run Cursor/ACP replay-focused tests and
  analyzers plus `git diff --check`.

Step 6 actual-plugin scope uses `CursorPlugin` production composition and the
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
