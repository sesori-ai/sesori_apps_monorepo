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
  background observation exists and rely on `workKept` to qualify that success.
- Every policy fails through one explicit existing plugin/HTTP error path before
  root/input preparation or cancellation. No count, successful ACK, or shared
  wire field is invented for work whose current running count is unknowable.
- Background Task lifecycle cannot render completion merely because its launch
  call completed. Until Cursor exposes a terminal fact, background Tasks keep
  the honest generic Task card and remain a declared capability gap.
- Supported foreground-only confirmation reports the exact tracked count,
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
  child fanout, or keeping a root/session UI busy. The tracker exposes the
  backend-neutral aggregate `requiresProcessResidency` separately for ACP
  process work-state derivation.
- New private `_AcpTileTask({required genericPart, required phase})` lives in
  that tracker file; the enclosing nested maps own the root-session and
  tool-call keys. Closed `AcpTileTaskPhase` values are `activeInvocation` and
  `foregroundInvocationCompleted`; neither phase has a child-session field.
  Backend-neutral tracker methods record a generic `PluginMessagePartTool`,
  mark foreground completion, convert a launch into the root-level unresolved
  background observation, expose the exact active-foreground count, return the
  matching completed record for replacement, and return active generic parts
  for cancellation settlement. Their parameters are all required and named.
  Pending/in-progress parts stay generic. Only complete correlated terminal
  facts replace one generic part with a completed childless tile; prompt
  cancellation settles the standard generic card to cancelled and creates no
  subtask tile.
- `bridge/sesori_plugin_acp/lib/src/acp_event_mapper.dart` adds
  `mapPromptResult({required String sessionId, required AcpStopReason
  stopReason})`. Base behavior is empty. `CursorEventMapper` overrides it; ACP
  never imports Cursor types. `AcpPlugin._runTurn` emits this method's events
  after `AcpPromptResult.fromJson` and before `_finishTurn` completes the
  existing `activeSettlement` future.
- `bridge/sesori_plugin_acp/lib/src/acp_plugin.dart` adds neutral
  `AcpScopedStopCapability.rootSessionCancel` and one explicit branch in
  `abortSession`. Its unresolved-background guard is the first branch action,
  before root/input preparation and before descendant collection; it throws the
  one unsupported plugin operation described below. The remaining foreground-
  only branch cannot enter snapshot fanout, `cancelChild`, `stopScopedTree`, or
  child-id sets.
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
  Complete correlated foreground terminal facts produce one completed
  `PluginMessagePart.subtask` reusing the generic part's id/session/message
  identity and setting `childSessionID: null`; pending, in-progress,
  background, malformed, or incomplete facts keep the generic card.
  Cancellation maps the generic standard Task card to cancelled and never
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

No other new production classes are planned. Existing constructor calls in
Cursor tests are updated for required fields. There is no shared/client/bridge-
app/database contract, child catalog row, compatibility shim, or Cursor import
in ACP.

### One lifecycle path

1. `CursorEventMapper.map` lets `AcpEventMapper` create the standard generic
   Task card, then parses `CursorTaskInputDto`/`CursorTaskOutputDto` and records
   that exact generic part in `AcpChildSessionTracker`.
2. Pending/in-progress is a known active foreground invocation, but remains a
   generic Task card because those frames lack prompt and description.
   Foreground standard completion changes the correlation record to
   `foregroundInvocationCompleted`; the generic completed card remains visible
   while the record awaits the immediately following request.
3. Re-injected `cursor/task` parses to `CursorTaskRequestDto`. Only an exact
   `toolCallId` match in `foregroundInvocationCompleted` with complete terminal
   facts reaches `CursorTaskMapper.mapLiveCompleted`; one completed childless
   tile replaces the same part. A background launch never reaches tile
   projection.
4. `AcpPlugin._runTurn` routes every parsed prompt result through
   `eventMapper.mapPromptResult` before `_finishTurn`. On `cancelled`, the
   Cursor override takes the active foreground generic parts from the same
   tracker and maps their standard-card status to cancelled. It creates no
   cancelled subtask tile. Other prompt results do not fabricate Task or
   background completion. Native `end_turn` still idles the root honestly; it
   says nothing about background completion and produces no background tile or
   completion notification.
5. A later turn may clear only completed foreground correlation records through
   the already-called `beginTurn` path. It must not clear the unresolved
   background observation.

### Background observation and process residency

`rawOutput.isBackground: true` removes that tool id from known foreground state
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
real child work. Tracker change notification already reaches
`AcpPlugin._onChildSessionsChanged`, which reruns `_syncWorkState`; no timer,
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

`knownForegroundActiveCount` is exact: it counts only standard Task
invocations observed pending/in-progress and not yet terminal/prompt-cancelled.
The unresolved-background flag is separate and never contributes a fabricated
`runningSubAgentCount`.

### Explicit foreground-only root stop policy

The `rootSessionCancel` branch targets only the method's named `sessionId`.
Its first operation checks the unresolved-background observation. When present,
all three policies throw the same side-effect-free
`PluginOperationException` for operation `abortSession`, HTTP status 409, and
backend-neutral message `Cannot stop while resident background work has unknown completion`.
This uses the existing plugin-operation → router HTTP failure path, introduces no
new shared response, and runs before queued/writing work, pending interaction,
root cancellation, settlement capture, descendant collection, or fanout.
`SessionApi.abortSession` cannot parse this plain 409 as the existing typed
confirmation rejection, so it returns the ordinary `ErrorResponse`;
`SessionDetailCubit.abort` returns failed rather than aborted.

Without an unresolved-background observation, the branch captures the existing
`activeSettlement` future when a prompt is in flight, prepares only that root's
queued/writing work and pending interaction, sends exactly one standard
`session/cancel` for that root when the live client exists (and zero only when
no process exists to notify), and waits for that captured settlement. Because
`_runTurn` maps the prompt result before completing settlement, a foreground
accepted stop cannot return before the authoritative `cancelled` result has
settled the generic Task card. No child id, Task id, known client child id,
ancestor, sibling, or descendant enters preparation or native dispatch.

| Named-root state | Policy | Effect | Result |
|---|---|---|---|
| Any unresolved-background observation | `confirm` / `keep` / `stop` | None | Same explicit unsupported HTTP failure |
| Known foreground `N > 0`, no unresolved background | `confirm` | None | Exact typed rejection `N`; main running; main-only false |
| Known foreground `N > 0`, no unresolved background | `keep` | None | Same exact typed rejection |
| Known foreground `N > 0`, no unresolved background | `stop` | Root prepare/cancel; await prompt | ACK kept=false, handled=false |
| No foreground/background fact | `confirm` / `stop` / `keep` | Existing root cancel | ACK kept=false, handled=false |

`subAgentsHandled` is always false because Cursor exposes no child targets or
complete background authority. No accepted Cursor path depends on bridge-
internal `workKept`; every accepted foreground/no-observation path reports
`workKept: false`. Background full stop remains unsupported.

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
land first, then completed live tiles, foreground-only scoped stop, replay, and
final actual-plugin evidence. Feature implementation has not landed; successors
must be regenerated from this revised plan. Line sizes include source, generated
serializers, tests, each behavior slice's regression docs, and tracker
bookkeeping.

Existing code refs `c5c0def` (former live slice) and `ab03528` (former scoped-
stop slice) remain preserved as historical implementation evidence. Neither is a
publication candidate after the transport/client, process-residency, and
completion-only corrections here; do not mutate or delete them. Regenerate both
successors from this revised plan.

1. `🌱 [claude-inline-subtasks] docs: record Cursor native probe and corrected plan [step 1/5]`:
   this privacy-safe native evidence, corrected ownership/policy design, and
   exact delivery sequence only. No feature implementation. This step remains
   unchecked until its PR merges.
2. `🚧 [claude-inline-subtasks] cursor: completed foreground Task tiles [step 2/5]`
   (expected approximately 1,550–1,700 changed lines): neutral tile-only
   correlation, prompt-result mapper hook, Cursor DTOs/codegen, one injected
   `CursorTaskMapper`, request forwarding, completed foreground replacement,
   generic cancelled settlement, focused ACP/Cursor tests, and corresponding
   `docs/regression/tools-and-file-changes.md` plus
   `docs/regression/session-turns.md` behavior updates. Pending/in-progress and
   background calls stay generic; cancellation creates no tile. No scoped-stop
   authority, unresolved-background residency state, or replay wrapper.
3. `⚙️ [claude-inline-subtasks] cursor: foreground-only scoped Task stop [step 3/5]`
   (expected approximately 500–700 changed lines): exact foreground count,
   durable unresolved-background observation and
   `requiresProcessResidency`, first-action unsupported guard for all policies,
   foreground-only `rootSessionCancel`, root settlement, focused tests, and
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
  the only child-id/fanout/root-busy state and tile-only foreground correlation
  does not alter those snapshots; prompt results map before root turn
  settlement.
- `bridge/sesori_plugin_cursor`: DTO valid/unknown/malformed fixtures,
  object-shaped `subagentType`, `cursor/task` ack/re-injection, standard →
  request correlation, pending/in-progress generic cards, completed foreground
  tile replacement only after complete correlated terminal facts, prompt-cancel
  generic-card settlement with no tile, background generic retention, no child
  id, and constructor/composition tests. Run package analyzers/tests and
  `git diff --check`.

Step 3 automated scope:

- Exact foreground count and unresolved background remain independent; the
  observation survives turns, clears on session/process teardown, leaves root
  status/active summaries/deferred idle/counts unchanged, and alone keeps ACP
  `PluginWorkState` busy through `requiresProcessResidency`.
- Every unresolved-background `confirm`/`keep`/`stop` takes the same explicit
  failure before root/input preparation or cancellation; tests assert no
  outbound cancel, queue/input mutation, successful ACK, or fabricated count.
  Known foreground-only `confirm`/`keep`, root-only `stop`, prompt settlement
  ordering, forced process cleanup, explicit session deletion, and unchanged
  DeepSeek/Grok branches remain covered.

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
terminal correlation; pending/in-progress generic presentation; exact side-
effect-free foreground confirmation; rejected foreground keep; authoritative
root-only foreground stop with a generic cancelled card; process/session reuse;
repeated cold load; background generic card; honest root idle after native
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
