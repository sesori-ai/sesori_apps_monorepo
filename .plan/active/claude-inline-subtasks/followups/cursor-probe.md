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
- `workKept` is true when a stop races a known background launch; the native
  evidence forbids a constant false result.
- Background Task lifecycle cannot keep the root busy forever without a finish
  authority, and it cannot be rendered as completed merely because its launch
  call completed. Until Cursor exposes a terminal fact, background Tasks keep
  the honest generic Task card and remain a declared capability gap.
- Supported foreground Task confirmation reports the exact tracked count,
  `mainAgentOnlySupported: false`, and no `keep` action. There is no per-task
  cancel request.

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
  live tracker is added. It gains tile-only foreground records keyed by
  `(rootSessionId, toolCallId)` plus one session-level unresolved-background
  observation. Existing session-backed `_Child` records remain the only state
  carrying child ids, emitting child session/status events, contributing to
  child fanout, or keeping a root busy.
- New private `_AcpTileTask({required rootSessionId, required toolCallId,
  required genericPart, required phase})` lives in that tracker file. Closed
  `AcpTileTaskPhase` values are `activeForeground` and
  `foregroundInvocationCompleted`; neither phase has a child-session field.
  Backend-neutral tracker methods record a generic `PluginMessagePartTool`,
  mark foreground completion, convert a launch into the root-level unresolved
  background observation, expose the exact active-foreground count, return the
  matching completed record for replacement, and return active generic parts
  for cancellation settlement. Their parameters are all required and named.
- `bridge/sesori_plugin_acp/lib/src/acp_event_mapper.dart` adds
  `mapPromptResult({required String sessionId, required AcpStopReason
  stopReason})`. Base behavior is empty. `CursorEventMapper` overrides it; ACP
  never imports Cursor types. `AcpPlugin._runTurn` emits this method's events
  after `AcpPromptResult.fromJson` and before `_finishTurn` completes the
  existing `activeSettlement` future.
- `bridge/sesori_plugin_acp/lib/src/acp_plugin.dart` adds neutral
  `AcpScopedStopCapability.rootSessionCancel` and one explicit branch in
  `abortSession`. The branch runs before descendant collection and cannot
  enter snapshot fanout, `cancelChild`, `stopScopedTree`, or child-id sets.
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
  with `unknown`; their JSON fields use `unknownEnumValue`, never a Freezed
  `@Default`. A missing recognized key in the object-shaped subagent DTO also
  resolves to `unknown`, so an unfamiliar object shape stays typed rather than
  failing or becoming a magic string. Generated `cursor_task_dto.freezed.dart` and
  `cursor_task_dto.g.dart` come only from codegen.
- `bridge/sesori_plugin_cursor/lib/src/repositories/mappers/cursor_task_mapper.dart`
  adds pure `const CursorTaskMapper()`. It has no dependencies or mutable
  fields. `mapLiveCompleted({required PluginMessagePartTool genericPart,
  required CursorTaskRequestDto request})`, `mapReplay({required
  PluginMessagePartTool genericPart, required CursorTaskInputDto input,
  required CursorTaskOutputDto output})`, and `mapCancelled({required
  PluginMessagePartTool genericPart})` are the only presentation projections.
  Complete foreground facts produce one `PluginMessagePart.subtask` reusing
  the generic part's id/session/message identity and setting
  `childSessionID: null`; background, malformed, or incomplete facts keep the
  generic card. `agentId` remains Cursor correlation data and is never used as
  child identity.
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
  record; `mapPromptResult` settles cancelled active foreground records through
  the same tracker and mapper. One private task-observation method serves all
  three triggers. `abortSession` never creates or mutates presentation parts.
- `bridge/sesori_plugin_cursor/lib/src/cursor_approval_registry.dart`
  acknowledges `cursor/task` with the existing empty fire-and-forget response
  and re-injects one `AcpNotification`, like generated-image/todo handling.
  Parsing remains in the event mapper's typed Cursor boundary.
- `bridge/sesori_plugin_cursor/lib/src/cursor_plugin_impl.dart` remains the
  composition owner. `CursorPlugin.factory` constructs one
  `const CursorTaskMapper()` and injects that same instance into
  `CursorEventMapper` and `CursorPlugin._`; `CursorPlugin._` adds required
  `CursorTaskMapper taskMapper` and retains it only to compose replay.
  Its `createSessionReplayCollector({required String sessionId, required
  AcpReplayCollectorFactory collectorFactory})` override first calls
  `collectorFactory(toolPartSuppression: null)` for one fully configured
  standard collector, then injects that collector and the stored mapper into
  `CursorTaskReplayTracker`. The tracker receives no factory, and neither
  mapper nor tracker constructs its peer.
- `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_plugin_descriptor.dart`
  keeps constructing `CursorPlugin` through the existing factory; its public
  `CursorPluginFactory` signature does not gain repository peers. Test
  composition continues through `CursorPlugin.factory`.

No other new production classes are planned. Existing constructor calls in
Cursor tests are updated for required fields. There is no shared/client/bridge-
app/database contract, child catalog row, compatibility shim, or Cursor import
in ACP.

### One lifecycle path

1. `CursorEventMapper.map` lets `AcpEventMapper` create the generic Task card,
   then parses `CursorTaskInputDto`/`CursorTaskOutputDto` and records that exact
   generic part in `AcpChildSessionTracker`.
2. Pending/in-progress is a known active foreground invocation. Foreground
   standard completion changes it to `foregroundInvocationCompleted`; it no
   longer contributes to the active count but stays available for the
   immediately following request.
3. Re-injected `cursor/task` parses to `CursorTaskRequestDto`. Only an exact
   `toolCallId` match in `foregroundInvocationCompleted` reaches
   `CursorTaskMapper.mapLiveCompleted`; the resulting tile replaces the same
   part. A background launch never reaches tile projection.
4. `AcpPlugin._runTurn` routes every parsed prompt result through
   `eventMapper.mapPromptResult` before `_finishTurn`. On `cancelled`, the
   Cursor override takes the active foreground generic parts from the same
   tracker and maps their status to cancelled. Other prompt results do not
   fabricate Task completion. Thus standard updates, `cursor/task`, and
   authoritative cancellation all converge in `CursorEventMapper` plus
   `AcpChildSessionTracker`; abort policy has no presentation mutation.
5. A later turn may clear only completed foreground correlation records through
   the already-called `beginTurn` path. It must not clear the unresolved
   background observation.

### Background observation and work state

`rawOutput.isBackground: true` removes that tool id from known foreground state
and records only `rootSessionId` in a set such as
`_rootsWithUnresolvedTileBackgroundWork`. It is deliberately a boolean fact per
session, not a tool-id set or running-task count: native ACP proves at least one
launch escaped the root turn, but does not reveal how many remain running or
when they finish.

The observation survives `end_turn`, later turns, and later permission/question
requests. It clears only from an authoritative native terminal fact if Cursor
adds one, `forgetSession(sessionId:)` on session deletion, or `clear()` on ACP
process teardown/reset/disposal. Current Cursor supplies no terminal fact, so
normal cleanup is session/process teardown. This state is not included in
`hasBusyChildren`, `hasActiveWorkForRoot`, `activeRootSessionIds`, session
status, deferred idle, or `_syncWorkState`; it therefore cannot pin the root
busy or block process policy forever. A later pending interaction remains busy
through the existing approval registry only for that interaction's lifetime.

`knownForegroundActiveCount` is exact: it counts only standard Task
invocations observed pending/in-progress and not yet terminal/prompt-cancelled.
The unresolved-background flag is separate and never contributes a fabricated
`runningSubAgentCount`.

### Explicit root-only stop policy

The `rootSessionCancel` branch targets only the method's named `sessionId`.
It captures the existing `activeSettlement` future when a prompt is in flight,
prepares only that root's queued/writing work and pending interaction, sends
exactly one standard `session/cancel` for that root when the live client exists
(and zero only when no process exists to notify), and waits for that captured
settlement. Because `_runTurn` maps the
prompt result before completing settlement, a foreground accepted stop cannot
return before the authoritative `cancelled` result has settled tracker and
presentation state. No child id, Task id, known client child id, ancestor,
sibling, or descendant enters preparation or native dispatch.

| Named-root state | Policy | Effect | Result |
|---|---|---|---|
| Known foreground `N > 0` | `confirm` | None | Reject `N`; main running; main-only false |
| Known foreground `N > 0` | `keep` | None | Same typed rejection |
| Known foreground `N > 0` | `stop` | Root prepare/cancel; await prompt | ACK from rules below |
| Unresolved background; root active | `keep` | None | Explicit `UnsupportedError` |
| Unresolved background; root idle | `keep` | None | ACK kept=true, handled=false |
| Unresolved background; count zero | `confirm` / `stop` | Root prepare/cancel | ACK kept=true, handled=false |
| Above plus later pending input | `confirm` / `stop` | Also cancel named-root input | ACK kept=true, handled=false |
| No foreground/background fact | `confirm` / `stop` / `keep` | Existing root cancel | ACK kept=false, handled=false |

For known foreground `stop`, `workKept` is false only when no unresolved-
background observation exists; `subAgentsHandled` is false. Unresolved
background never inflates `N`. Root-active `keep` throws
`UnsupportedError("Cursor cannot keep background work while the named root turn is active")`;
it never accepts a no-op as a main-only stop and never invents a count.

`subAgentsHandled` is always false for this capability because Cursor exposes no
child targets or complete background authority. `workKept: true` is a
conservative retained-work statement until the unresolved observation clears;
it is not a claim that background work is currently running. Background full
stop remains unsupported.

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
land first, then live lifecycle, scoped stop, replay, and final coverage. Feature
implementation has not landed; the live slice awaits publication after this
first docs-only candidate. Line sizes include source, generated serializers,
tests, behavior docs, and tracker bookkeeping. The measured approximately
1,642-line live slice is accepted as one coherent unit rather than dropping
generated code, tests, or evidence.

1. `🌱 [claude-inline-subtasks] docs: record Cursor native probe and corrected plan [step 1/5]`:
   this privacy-safe native evidence, corrected ownership/policy design, and
   exact delivery sequence only. No feature implementation.
2. `🚧 [claude-inline-subtasks] cursor: live foreground Task tiles [step 2/5]`
   (approximately 1,642 changed lines): neutral tile-only tracker state,
   prompt-result mapper hook, Cursor DTOs/codegen, one injected
   `CursorTaskMapper`, request forwarding, live foreground replacement and
   cancellation, plus focused ACP/Cursor tests. Background stays generic; no
   scoped-stop authority, unresolved-background state, or replay wrapper.
3. `⚙️ [claude-inline-subtasks] cursor: scoped Task stop policy [step 3/5]`:
   exact foreground count, durable unresolved-background observation,
   `rootSessionCancel`, root-only settlement, policy table, and focused tests.
4. `⚙️ [claude-inline-subtasks] cursor: replay foreground Task tiles [step 4/5]`
   (approximately 650–950 changed lines):
   `repositories/trackers/cursor_task_replay_tracker.dart`, plugin replay
   composition with one already-configured ACP collector and the same injected
   mapper, complete/malformed/background/cancelled/repeated-load projection
   tests, and live/replay shape convergence without live-id equality.
5. `🌱 [claude-inline-subtasks] docs: record Cursor sub-agent coverage [step 5/5]`
   (approximately 100–220 changed lines): reconcile
   `docs/HARNESS_CAPABILITIES.md`,
   `docs/regression/tools-and-file-changes.md`,
   `docs/regression/session-turns.md`,
   `docs/regression/session-history-and-recovery.md`, and
   `docs/regression/plugin-setup-and-lifecycle.md`; record executed native-
   plugin results, generic background fallback, conservative retained-work ACK,
   and every unsupported/unexecuted boundary. Overall plan remains active while
   the separate Grok phone gate is blocked.

### Bounded verification plan

Step 2 automated scope:

- `bridge/sesori_plugin_acp`: tracker tests prove session-backed children remain
  the only child-id/fanout/busy state and tile-only foreground correlation does
  not alter those snapshots; prompt results map before root turn settlement.
- `bridge/sesori_plugin_cursor`: DTO valid/unknown/malformed fixtures,
  object-shaped `subagentType`, `cursor/task` ack/re-injection, standard →
  request correlation, generic foreground start, completed tile replacement,
  prompt-cancel generic settlement, background generic retention, no child id,
  and constructor/composition tests. Run package analyzers/tests and
  `git diff --check`.

Step 3 automated scope:

- Exact foreground count and unresolved background remain independent; the
  observation survives turns, clears on session/process teardown, and never
  changes root/plugin work state.
- Known foreground `confirm`/`keep`, foreground `stop`, unresolved-background
  `confirm`/`stop`, root-idle/root-active `keep`, later pending input, one root
  cancel, prompt settlement ordering, and unchanged DeepSeek/Grok branches.

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
managed `2026.08.11-e8db854` target: foreground natural completion; exact,
side-effect-free confirmation; rejected foreground keep; authoritative root
stop and process/session reuse; repeated cold load; background generic card;
post-turn background permission followed by root-idle keep and by
confirm/stop; conservative `workKept: true` and `subAgentsHandled: false`.
Phone/desktop presentation, child navigation/history, background completion,
and full background stop remain unexecuted/unsupported rather than inferred.

Do not recreate the cleaned native captures merely for confidence. Future
actual-plugin QA must retain raw prompts, transcripts, ids, permission payloads,
logs, and timing captures as private evidence after every owned process/session
and scratch resource is cleaned and cleanup is verified. Never commit that
private evidence or replace it with a public raw capture.
