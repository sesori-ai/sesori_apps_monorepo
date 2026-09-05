# Claude Inline Sub-Agent Subtasks

## Status

- **Plan slug:** `claude-inline-subtasks`
- **Status:** Series completed 2026-09-02 (Step 8/8; L4 matrix recorded in
  `TRACKER.md`); reactivated 2026-09-02 for the harness follow-ups in
  `HARNESS_FOLLOWUPS.md`, retired again when their coverage PRs merge
- **Plan date:** 2026-08-22
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main` at `ba725ec84`
- **Plan branch:** `inline-subtask-plan`
- **Plan PR:** [#1027](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1027)
- **Delivery:** eight PRs: plan, contract + client tile, Claude lifecycle,
  Claude child sessions, Claude live sub-agent streaming, scoped stop,
  regression docs, retirement
- **DeepSeek consumer split (2026-09-04):** supersede oversized PR #1293 with
  five sequential, approximately 1,500-line slices. Exact scopes, titles,
  budgets, and the verbatim-fixture exception are in `HARNESS_FOLLOWUPS.md`;
  progress is in `TRACKER.md`. Preserve the approved design and all review
  fixes. Release preparation waits for every consumer slice to merge. Existing
  regression reconciliation and final coverage/retirement gates remain intact.

## Goal

Claude Code sub-agents (`Agent` tool calls, historically `Task`) are invisible
in Sesori today: the call renders as a generic tool card named `Agent` whose
output is the final report truncated to 500 characters, and everything the
sub-agent did is dropped. After this plan:

- every sub-agent launch renders **inline, in transcript order**, as a subtask
  tile that shows its own lifecycle — pending, running, completed, failed,
  cancelled — live and after a history reload;
- tapping the tile opens the sub-agent's own transcript read-only (prompt,
  tool calls, results, final text), including while it is still running;
- stopping a session while sub-agents run asks whether to stop only the
  main agent or the main agent plus all sub-agents, instead of silently
  killing everything;
- no new "tasks" surface is built. The existing `BackgroundTasksBar` keeps
  working for child sessions as today; its removal in favour of inline-only
  rendering for every plugin is a separate effort (see Non-Goals).

## Current Behavior (verified 2026-08-22)

### Contract and client

- `shared/sesori_shared/lib/src/models/sesori/message_part.dart:89-140`:
  `MessagePartType.subtask` exists; `MessagePart` is one flat record with
  `prompt`, `description`, `agent` (subtask), `tool`, `state: ToolState?`
  (tool), `agentName`, `attempt`, `retryError`, `attachment`. `ToolStatus`
  (`:211-223`) is `pending | running | completed | error | unknown` with
  `unknownEnumValue: ToolStatus.unknown` on `ToolState.status` — no cancelled.
- `bridge/sesori_plugin_interface/lib/src/models/plugin_message.dart:21-85,
  114-137` mirrors both (`PluginMessagePartType.subtask`, `PluginMessagePart`,
  `PluginToolStatus`).
- `bridge/app/lib/src/bridge/plugin_to_shared_mapping.dart` maps both enums
  exhaustively; `bridge/app/lib/src/bridge/repositories/mappers/session_event_mapper.dart:35,177`
  rewrites `part.sessionID` from the backend id to the bridge session id on
  live events; the history read path does the same through
  `toSharedMessageWithParts(sessionId:)`
  (`bridge/app/lib/src/bridge/repositories/session_repository.dart:423-433`).
- `client/app/lib/features/session_detail/widgets/subtask_part_widget.dart`
  already renders `subtask` parts inline: description/prompt, agent, a status
  icon derived from the **child session's** `SessionStatus`, and a tap that
  pushes `AppRoute.sessionDetail(readOnly: true)` for a child found by
  heuristic title matching (`_findChildSession`, L114-146: only child, exact,
  case-insensitive, substring). Dispatched from
  `assistant_message_card.dart:79-119`. It ignores `part.state`.
- `client/app/lib/features/session_detail/widgets/tool_part_widget.dart:94-121`
  switches exhaustively on `ToolStatus` for icon and label.
- Only OpenCode produces child sessions and subtask parts
  (`bridge/sesori_plugin_opencode/lib/src/message_part_mapper.dart:83-91`);
  OpenCode subtask parts carry `state: null`.
- Bridge chat history persists parts as whole JSON blobs
  (`history_parts.partJson`), so new nullable fields need no migration. The
  store's stale-tool sweep
  (`bridge/app/lib/src/bridge/services/chat_history_service.dart:500-543`,
  `chat_history_repository.dart:295-332`) finalizes open **tool** parts to
  `error` when the session is not busy; it ignores other part types.
- Client: no local database; `SessionDetailCubit._onPartUpdated`
  (`client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart:1309`)
  already replaces parts by id, so lifecycle updates need no cubit change.

### Claude plugin

- `bridge/sesori_plugin_claude/lib/src/claude_event_dispatcher.dart:65-70`
  returns `[]` for every `assistant`/`user`/`stream_event` frame carrying
  `parent_tool_use_id`; `:79-89` discards the already-parsed
  `ClaudeTaskProgressMessage`/`ClaudeToolProgressMessage`.
- `api/models/claude_stream_message.dart:42-110` parses `system/task_progress`
  but absorbs `task_started`, `task_notification`, `task_updated`, and
  `background_tasks_changed` as `ClaudeUnknownMessage`.
- `repositories/trackers/claude_tool_tracker.dart:218-228` classifies tools as
  `edit | todoWrite | other`; state is reset per turn (`beginTurn`).
- `repositories/mappers/claude_content_mapper.dart:275-301,318-342` maps every
  `tool_use` to a `tool` part with the subtask slots hard-coded null.
- `claude_history_mapper.dart:142-143` drops all sidechain records; user records
  are rendered unless `isMeta`/`isVisibleInTranscriptOnly` or the internal
  command markers match (`claude_content_mapper.dart:59-77`). A
  `<task-notification>` user record matches none of these, so a replayed
  background-agent completion renders as a user bubble containing raw XML.
- `repositories/claude_transcript_catalog_repository.dart:198-206` admits only
  UUID-stem transcripts; `claude_plugin_impl.dart:195` returns `const []` for
  `getChildSessions`; the transcript DTO
  (`api/models/claude_transcript_record_dto.dart`) has no `agentId` or
  `toolUseResult`.
- `api/claude_launch_spec.dart:102-133` does not pass
  `--forward-subagent-text`.
- `services/claude_session_service.dart` owns work/idle lifecycle and knows
  nothing about sub-agents: `_finish` (`:554-565`) and `_endSelfStartedTurn`
  (`:701-707`) emit `BridgeSseSessionIdle` and arm `_scheduleIdleReap`
  (`:567-605`) as soon as `pending == 0 && selfStartedTurn == null`; the reap
  tears the resident CLI process down after the configured idle timeout,
  deferring only for a pending `ScheduleWakeup` (`wakeupAt`, tracked by
  inspecting assistant frames in `_trackWakeupSchedule`, `:651-673`).
  `_syncWorkState` (`:607-611`) derives the plugin-level `PluginWorkState`
  from the same predicate, which gates safe plugin stops and suspension
  (`bridge/app/lib/src/bridge/runtime/plugin_runtime.dart:758,1103`), and
  `interruptActiveWork` (`:500-515`) aborts only sessions matching it.
  `abort` (`:465-498`) interrupts **and tears the process down**. A
  background sub-agent lives only inside that process, so without a lifecycle
  change the reap (and any safe stop) would kill running sub-agents silently.

### Claude Code CLI 2.1.237 facts (live probe + local transcript survey)

Live stream-json with the plugin's exact flags:

- `system/task_started {task_id, tool_use_id, description, subagent_type,
  task_type: "local_agent"}` fires for both foreground
  (`run_in_background: false`) and background launches, before the sub-agent's
  first forwarded frame.
- `system/task_progress {task_id, tool_use_id, description, subagent_type,
  usage{total_tokens, tool_uses, duration_ms}, last_tool_name}` fires
  periodically.
- `system/task_notification {task_id, tool_use_id, status, output_file,
  summary, usage}` fires on completion for both foreground and background
  launches; `status` observed as `completed`, `failed`, `stopped`.
- `system/task_updated {task_id, patch{status, end_time}}` and
  `system/background_tasks_changed {tasks}` also appear; not needed.
- `task_id` **is** the sub-agent `agentId`: the probe showed
  `task_started.task_id`, `task_notification.task_id`, and the same call's
  `tool_use_result.agentId` carrying one identical value, and the transcript
  survey showed `<task-id>` in notification records equal to `toolUseResult.
  agentId` and to the `agent-<agentId>` file stem and meta. Live and persisted
  child ids are therefore the same canonical `agent-<agentId>`.
- The parent's `user` tool-result frame carries a top-level `tool_use_result`:
  background launch `{isAsync: true, status: "async_launched", agentId,
  description, resolvedModel, prompt, outputFile, canReadOutputFile}` with the
  tool-result text "Async agent launched successfully…"; foreground completion
  `{status: "completed", agentId, agentType, content, prompt, resolvedModel,
  totalDurationMs, totalTokens, totalToolUseCount, usage, toolStats}`.
- Sub-agent **complete** `assistant` and `user` frames (its initial prompt,
  tool_use blocks, tool_result blocks, final text) are forwarded with
  `parent_tool_use_id`, `subagent_type`, and `task_description` set, without
  `--forward-subagent-text`; sub-agent `stream_event` deltas are not.
- The main turn's `result` arrives while a background agent is still running;
  its completion is later delivered to the model as a user message whose text
  starts with `<task-notification>` and carries `<task-id>`, `<tool-use-id>`,
  `<status>`, `<summary>`, optional `<result>`/`<usage>`.

Persisted transcript (`~/.claude/projects/<munged-cwd>/`):

- Sub-agent transcripts live at `<session-id>/subagents/agent-<agentId>.jsonl`
  beside `agent-<agentId>.meta.json` = `{agentType, description, toolUseId,
  spawnDepth}`. Their records carry `agentId`, `isSidechain: true`, and the
  **parent's** `sessionId`. The older flat layout `agent-<slug>-<hex>.jsonl`
  next to the session file has no meta file.
- The parent's tool-result record carries top-level `toolUseResult` with the
  shapes above (`status: "async_launched"` plus `agentId`; foreground results
  carry the content). Background completion is a `user` record with
  `origin: {kind: "task-notification"}` and the `<task-notification>` text.
  No `system` record persists the task lifecycle.

## Locked Design

### Part shape

The Claude plugin emits `PluginMessagePartType.subtask` for every `Agent` or
`Task` tool_use, keyed by the tool_use id so live updates upsert the same part:

| Field | Value |
|---|---|
| `id` | tool_use id |
| `description` | `input.description` (null until the streamed input completes) |
| `prompt` | `input.prompt` |
| `agent` | `input.subagent_type` |
| `state` | lifecycle below; `output` = bounded `summary`/result on completion, `error` = bounded summary on failure |
| `childSessionID` | new nullable field: the sub-agent transcript id (`agent-<agentId>`) once known |
| `tool` | null (matches OpenCode subtask parts) |

Part identity, ordering, and replacement reuse the existing tool tracker and
`message.part.updated` path; no new SSE event.

### Contract additions (Step 2)

1. `ToolStatus.cancelled` and `PluginToolStatus.cancelled`, wire value
   `"cancelled"`, mapped in `plugin_to_shared_mapping.dart`. An older client
   decodes it as `ToolStatus.unknown` (existing `unknownEnumValue`), which is
   the documented forward-compatible fallback. `ToolPartWidget` and the subtask
   tile render it explicitly.
2. `MessagePart.childSessionID` / `PluginMessagePart.childSessionID`, nullable,
   omitted when null. The bridge translates it from the backend id to the
   bridge session id at the two existing id-translation seams, **as an
   optional reference**: `SessionEventService._translate`
   (`session_event_service.dart:374-400`) requires a binding for every id in
   `SessionEventMapper.backendSessionIds` and parks or drops the whole event
   otherwise, so `childSessionID` is deliberately **not** added to that set;
   the rewrite resolves it through a separate best-effort lookup of the same
   bindings table and maps an unbound id to null. The history read path in
   `SessionRepository.getSessionMessages` resolves the distinct child ids on
   the page the same best-effort way. A null keeps the part deliverable and
   degrades the tile to the existing title fallback until a later update
   resolves it — this is also what makes Step 3 (parts carrying a child id
   before Step 4 creates child sessions) safe. Older bridges omit the field;
   older clients ignore it.

`MessagePart.state` on a subtask part becomes a documented meaning: when
present it is the subtask's own lifecycle and is authoritative for inline
status. OpenCode keeps sending null and keeps its child-status fallback.

### Lifecycle mapping (Step 3)

Live, in `ClaudeToolTracker` + `ClaudeEventDispatcher`:

- Tool kind `task` (`Agent`, `Task`) is added to the tracker's closed kind
  enum. Task records survive turns: they live in a per-session task map cleared
  only by `forgetSession`/process exit, because background agents outlive the
  turn that launched them.
- tool_use start → `pending`, then `running` once input streams or completes
  (same as tools); the part is emitted as `subtask` from the first frame.
- `task_started` whose `tool_use_id` is a known task → `running`,
  `childSessionID = agent-<task_id>`; also records `task_id ↔ tool_use_id`
  and, for `owned_by_subagent` starts, the nested tool_use id so Step 5 can
  route nested frames.
- Task status vocabulary has one closed enum, `ClaudeTaskStatus`
  (`lib/src/models/claude_task_status.dart`: `completed | failed | stopped |
  unknown`), parsed at both boundaries — `claude_stream_message.dart` for
  `system/task_notification.status` and `ClaudeContentMapper` for the
  notification text — and one mapping `toPluginToolStatus()` in
  `repositories/mappers/` used by the tracker (live) and the history mapper
  (replay): `completed` → `completed` with `output` = bounded `summary`;
  `failed` → `error` with `error` = bounded `summary`; `stopped` →
  `cancelled`; `unknown` → `unknown`.
- The tool-use result is parsed at the boundary, never branched on as a raw
  string: `claude_stream_message.dart` (frame `tool_use_result`) and the
  transcript DTO (record `toolUseResult`) both yield one sealed
  `ClaudeToolUseResult` (`lib/src/models/`): `asyncLaunched({required
  agentId})`, `completed({required agentId?})`, `absent`/`unknown`. The
  tracker and the history mapper switch on the variant, so an async launch
  cannot exist without its child identity.
- Terminal precedence is fixed, not first-wins: the task notification (system
  frame or parsed text) is the **authoritative** terminal source. A `user`
  tool-result frame whose result is `ClaudeToolUseResultAsyncLaunched` never
  finalizes the part and binds `childSessionID = agent-<agentId>` if
  `task_started` has not already done so. Any other tool result (foreground
  completion, error, or an older CLI that omits the result) is a
  **fallback** that finalizes per `is_error` exactly like a tool — binding
  `output`/`error` from the bounded tool-result content — only while no
  notification has been seen; a later notification for the same tool_use id
  replaces a fallback status/output/error, and a notification-set terminal is
  never replaced by a later tool result. The task record keeps which source
  finalized it (one closed two-value field). For a foreground agent both
  sources carry the same final report, so live and replay render the same
  bounded text whichever arrives first. No tool-result text is matched.
- The `<task-notification>` text has one parser: `ClaudeContentMapper` yields
  a typed `ClaudeMappedTaskNotificationContentBlock({taskId, toolUseId,
  status: ClaudeTaskStatus, summary})` for a text block that starts with that marker
  (the same marker-prefix rule as `containsInternalCommandOutput`) **and**
  parses as a complete envelope (`<task-id>`, `<tool-use-id>`, `<status>`
  all present); the transcript DTO additionally reads `origin.kind`, and
  `task-notification` there is authoritative provenance. The live dispatcher
  and the history mapper consume the typed block as a second terminal source
  **only when its `toolUseId` matches a task-kind tool use known in that
  session**, and hide it only then; an envelope that fails validation or
  matches no known task stays ordinary user text, so a prompt that happens to
  discuss the protocol can neither vanish nor finalize a subtask. The status
  mapping is the shared `toPluginToolStatus()` above.
- Session process exit has one owner: `ClaudePlugin._handleProcessEvent`
  handles `ClaudeSessionProcessExited` by calling
  `ClaudeEventDispatcher.cancelTasks(sessionId:)` (which delegates to the
  tracker's `cancelAll`) and adds the returned part updates and child idle
  events to `_eventBuffer`; `deleteSession` and dispose call the same method
  before `forgetSession`. `ClaudeSessionService` never touches the dispatcher
  or tracker.
- **Running tasks keep the session alive (lifecycle owner:
  `ClaudeSessionService`).** `_SessionTurnState` gains `runningTaskIds`
  (`{taskId → ClaudeTaskType}`), maintained exactly like
  `wakeupAt`/`selfStartedTurn` from typed frames in `_handleProcessEvent`:
  `ClaudeTaskStartedMessage` adds `task_id` with its boundary-parsed
  `ClaudeTaskType` (`local_agent` → `subAgent`, anything else → `other`),
  `ClaudeTaskNotificationMessage` removes it, `ClaudeSessionProcessExited`
  and `abort` clear it. It covers **every** `task_type` (sub-agents,
  background shells, workflows, nested `owned_by_subagent` tasks), because
  any of them lives only inside the resident process; the type is read only
  by the scoped-stop rejection (Step 6). The set extends the
  existing "work in flight" predicate wherever it is evaluated:
  `sessionStatuses` (the root reports **busy** while a task runs, even after
  its turn's `result`), `_syncWorkState` (plugin `PluginWorkState.busy`, so
  safe stop/suspension refuse and a forced stop interrupts observably),
  `interruptActiveWork`'s active set, the `abort` eligibility guard
  (`claude_session_service.dart:458-467`, so a background-only session can
  still be stopped instead of returning early and leaving a forced shutdown
  waiting on a busy work state), and the idle gate in
  `_finish`/`_endSelfStartedTurn`/`_scheduleIdleReap`. A notification that
  empties the set never emits idle by itself: the CLI follows every task
  notification with a wake-up turn (the notification reaches the model as a
  user message), so a `ClaudeTaskNotificationMessage` — or, on the floor, a
  user frame carrying the notification block — that arrives while no turn is
  active **opens a self-started turn**, exactly as a stream/assistant frame
  does today; that turn's `result` (or process exit/abort) ends it, and idle,
  work-state sync, and the reap follow then if the running set is empty. One
  continuous busy span therefore covers launch → background work → wake-up
  turn, so the 500 ms completion debounce (`bridge/app/lib/src/push/
  completion_notifier.dart:14`) never sees a transient idle and the completion
  push fires once. Residual: a notification with no wake-up turn would hold
  that self-started turn until abort/delete/exit — the same class of residual
  as a missing notification, cleared by the same paths. On a CLI floor without
  task frames the
  service uses the same typed substitutes as the dispatcher: an
  `asyncLaunched` `ClaudeToolUseResult` adds the task (as `subAgent`, keyed by
  its `agentId`) and a completed tool result or a user frame carrying
  `ClaudeMappedTaskNotificationContentBlock` removes it, keyed by the result's
  `agentId` or the block's validated `taskId` — so the service never needs
  the dispatcher's tool-use correlation. `ClaudeSessionService` takes
  `ClaudeContentMapper` as a required constructor dependency for that parse
  (Layer 2 into Layer 3; the const instance already built in
  `runtime/claude_plugin_descriptor.dart:216`). `_trackSelfStartedTurn`
  additionally ignores `ClaudeAssistantMessage`/`ClaudeStreamEventMessage`
  frames whose `parentToolUseId` is set: forwarded child frames are task
  activity, already represented by the running set, not a root turn (today
  such a frame after the root's `result` accidentally opens a root
  self-started turn that only the next root `result` closes); control
  requests keep counting because a sub-agent's permission ask is root-level
  input. The set never changes dispatch mode or turn-boundary waits —
  prompts still steer or wait on turns exactly as today. Consequences: no
  idle reap and no safe stop can kill a running
  sub-agent; the completion push fires once, after the last sub-agent and its
  wake-up turn settle; the client's `hasActiveWork` is true from the root
  itself. Two structures exist by design with disjoint responsibilities —
  the service's running-task set (lifecycle policy) and the dispatcher's task
  map (part presentation, child statuses, frame routing) — fed by the same
  typed frames and never consulting each other.
- Abort through Step 5 keeps today's mechanics — interrupt **then teardown**
  — so running sub-agents die with the process and surface as `cancelled`
  through the process-exit rule. One behavior change lands with Step 3's
  guard extension: today a background-only session (`pending == 0`,
  `selfStartedTurn == null`) makes `abort` return early and leaves the process
  and its sub-agents alive; with `runningTaskIds` in the guard the same stop
  tears the process down and cancels them. Step 6 ("Scoped stop" below) then
  makes that the `stop` policy and adds `keep`. Residual: if the CLI ever emits no
  `task_notification` for a task, the session stays busy and the process
  pinned until abort/delete/exit; Step 3's live capture checks whether
  `system/background_tasks_changed {tasks}` is a usable reconciliation
  snapshot for the set, and adopts it only if its shape lists live task ids.

History replay, in `ClaudeHistoryMapper`:

- `Agent`/`Task` tool_use → subtask part; a tool-result record whose parsed
  `ClaudeToolUseResult` is `asyncLaunched(agentId)` → `running` with
  `childSessionID = agent-<agentId>`; any other tool result finalizes per
  `is_error` (fallback); a `ClaudeMappedTaskNotificationContentBlock` in a
  user record finalizes authoritatively with its status/summary, under the
  same precedence as live. The transcript DTO gains `agentId` and the parsed
  `toolUseResult` variant.
- `ClaudeHistoryMapper.map({sessionId, records, residentTaskToolUseIds})`
  owns the downgrade: a replayed subtask that is still `running` stays
  `running` only if its tool_use id is in `residentTaskToolUseIds` — the tasks
  the session's **current resident process** started, obtained by
  `ClaudePlugin.getSessionMessages` through
  `ClaudeEventDispatcher.residentTaskToolUseIds(sessionId:)` and passed in as
  data; otherwise it becomes `cancelled`, because sub-agents die with their
  process. The composition root makes no status decision itself. Accepted
  residue: a session run in a terminal outside Sesori shows a still running
  sub-agent as cancelled until its notification record lands, then
  self-corrects on reload.

### Sub-agent transcripts as child sessions (Step 4)

- Child id: `agent-<agentId>` (the transcript stem). Layer split:
  - `ClaudeTranscriptApi` (Layer 1) stays dumb: the existing recursive
    `listTranscriptPaths` walk already yields `subagents/agent-*.jsonl`; it
    gains `readSubagentMeta(transcriptPath:) → ClaudeSubagentMetaDto?`
    (Freezed DTO in `api/models/claude_subagent_meta_dto.dart`: `agentType`,
    `description`, `toolUseId`, `spawnDepth`), `deleteDirectory(...)`,
    and reuses `lastModified`. No classification logic.
  - `ClaudeTranscriptCatalogRepository` (Layer 2) owns child detection from
    the walk (an `agent-*.jsonl` under `subagents/` whose grandparent directory
    is a root session id present in the same scan), the `agent-` id rule,
    grandparent-root resolution, legacy-layout exclusion, and mapping into
    `ClaudeSessionRecord` extended with a nullable `parentId` (null for roots)
    → `PluginSession(parentID: root, title: meta.description,
    directory/projectID: root's cwd, time: meta/jsonl mtimes)`.
    `listAllSessions` returns roots and children; `getSessions` (paginated per
    project) returns roots only. Children cost a meta read plus stat — no JSONL
    header scan.
- Nested agents (`spawnDepth > 1`) are flattened as children of the root; the
  `toolUseId` link still binds them to the nested subtask part.
- `findTranscriptPath`/`readTranscriptRecords`/`getSessionMessages` accept
  `agent-` ids; the history mapper gets a child mode keyed by `agentId` (those
  records are sidechain by construction). `getChildSessions(root)` lists the
  same children. `_findSession` resolves children for delete.
- Live child sessions — one lifecycle owner. `ClaudeEventDispatcher` (over
  the tracker task map) owns the whole child lifecycle: on the **first signal
  that carries the sub-agent id** — `task_started`, or, on a CLI floor without
  task frames, an `asyncLaunched`/`completed` `ClaudeToolUseResult` (a
  foreground agent then appears at completion, which is when its transcript
  is complete) — it builds the child `PluginSession` (id `agent-<agentId>`,
  `parentID` = root,
  title = description, directory/projectID = the root directory that
  `ClaudePlugin` passes as data through `beginTurn({sessionId, directory})`
  when it dispatches the session's first turn, retained until
  `forgetSession`) and returns, in this order inside `map()`,
  `BridgeSseSessionCreated(child)`, `BridgeSseSessionStatus(child, busy)`,
  then the subtask part update carrying `childSessionID`; on terminal or
  `cancelTasks` it returns the part update and `BridgeSseSessionStatus(child,
  idle)` (precedent: `_mapRetry` already emits session status). `ClaudePlugin`
  only forwards that output to `_eventBuffer`, as it does for every frame. The
  dispatcher exposes `childSessionStatuses({sessionId})` as the sole source of
  child status: `ClaudePlugin.getSessionStatuses()` returns the disjoint union
  of `ClaudeSessionService.sessionStatuses` (roots) and that accessor
  (children) with no decision of its own, and
  `ClaudePlugin.getActiveSessionsSummary()` fills
  `PluginActiveSession.childSessionIds` with only the children whose status
  is busy/retry (the contract's meaning: a finished child drops out while a
  sibling keeps running; today `const []` at `claude_plugin_impl.dart:396`);
  `mainAgentRunning` is **not** read from the conflated busy status:
  `ClaudeSessionService` exposes `isTurnRunning(sessionId)` (`pending > 0 ||
  selfStartedTurn != null`) for it, `childSessionIds` come from the
  dispatcher's busy children, and the root is included when either is true
  (today `:381-397` derives both from the status, which with background-only
  activity would report `mainAgentRunning: true`). This reaches the bar,
  `hasActiveWork`,
  activity roll-ups, and push grouping through the plugin's existing contract
  surfaces (`session.created`/`session.status` events, `getSessionStatuses`,
  `childSessionIds`); no bridge/app change is needed for that.
- Delete: root deletion also removes `<root>/` (its `subagents/`) through the
  API's `deleteDirectory`; child deletion removes the `.jsonl` and
  `.meta.json`. Rename/archive on a child are no-ops, as today for OpenCode
  children.
- Legacy flat `agent-<slug>-<hex>.jsonl` transcripts stay excluded (no title,
  no tool link) — honest limitation.
- Bridge sweep extension (bridge/app, same PR): because the root session is
  busy for as long as any of its tasks runs (Step 3 lifecycle rule), the
  existing `_sweepUnlessTurnRunning` guard (`chat_history_service.dart:521-
  523`, root status busy/retry → no sweep) already protects live sub-agents
  on both triggers — the idle transition and a history read. The extension
  is therefore small and needs no child-status lookup: `_containsOpenToolPart`
  (`:500-509`) also counts subtask parts whose `state` is `pending`/`running`,
  and `ChatHistoryRepository.finalizeOpenToolParts` (`chat_history_repository.
  dart:295-332`) finalizes an open subtask part to `cancelled` with no error
  text, while tool parts keep today's `error` finalization. No new repository
  dependency, no new `SessionRepository` method. This repairs a stuck spinner
  after an abrupt bridge death (root idle after restart), uniformly with tool
  parts, without ever sweeping a live background agent.

### Live sub-agent streaming (Step 5)

- Frames whose `parent_tool_use_id` maps (via the task map) to a child session
  id are routed through the existing `_mapAssistant`/`_mapUser` with
  `sessionId = childId`; the dispatcher's per-session maps isolate them. No
  `--forward-subagent-text`: complete messages are enough, parts appear whole
  (tool parts get their own pending→completed updates from the forwarded
  tool_use/tool_result frames).
- The child's first `user` frame renders as its prompt; tool results update the
  child's tool parts; nested `Agent` calls inside a child render as subtask
  parts with their own `childSessionID`. Because a nested task's
  `task_started`/notification frames arrive from the root process without a
  `parent_tool_use_id` while its tool_use was tracked under the child's
  rendered session, the tracker's task map is indexed by tool_use id
  globally (tool ids are unique per process) with the owning rendered
  session id stored on each record: lifecycle frames resolve by tool_use id
  regardless of which session's frame carried the tool_use, bind the nested
  child, and route its forwarded frames; the part update still targets the
  owning rendered session.
- History and live use the same ids (transcript `uuid`/`message.id`/tool ids),
  so an open child screen converges after a reload without duplicates, exactly
  as the root session does today.

### Scoped stop (Step 6)

Stop today is interrupt + teardown, which kills every running sub-agent;
day to day that is often not what the user wants. Stop becomes scoped,
mirroring the delete/archive `force` flow (`SessionCleanupRejection` 409 →
`client/app/lib/features/session_list/session_force_dialog.dart` → retry):

- Wire: a dedicated `AbortSessionRequest { sessionId, subAgents:
  SessionAbortSubAgentPolicy }` — `confirm | keep | stop`, `@Default(stop)`
  with a dated `COMPATIBILITY` comment — replaces the generic
  `SessionIdRequest` body on `/session/abort` only (precedent:
  `DeleteSessionRequest` is "a superset of `SessionIdRequest`",
  `shared/sesori_shared/lib/src/models/sesori/session.dart:134`;
  `SessionIdRequest` itself is untouched because seven other routes share
  it). An older client's `{sessionId}` body decodes with the default and keeps
  today's stop-everything behavior; an older bridge ignores the field and
  stops everything without confirmation (the documented degradation). New 409
  body `SessionAbortRejection { runningSubAgentCount, mainAgentRunning }` —
  no discriminator and no session id (one cause, one target; precedent
  `SessionCleanupRejection` carries only `issues`) — returned only to a
  client that asked for `confirm`.
- Count semantics: `runningSubAgentCount` counts **sub-agents only**.
  `ClaudeTaskStartedMessage` parses `task_type` at the boundary into a closed
  `ClaudeTaskType` (`local_agent` → `subAgent`, anything else → `other`);
  the service's running set keeps every type for process/reap safety
  (`{taskId → ClaudeTaskType}`), and the rejection counts only `subAgent`
  entries. `keep` keeps the whole resident process, so non-sub-agent tasks
  survive too; `confirm` with only non-sub-agent tasks running is not refused
  and proceeds as `stop` — the confirmation is about sub-agents, as asked.
- Bridge (Layer 2 → 3 → 4): `SessionRepository.abortSession({sessionId,
  subAgents}) → SessionAbortResult` (`aborted | rejected(
  SessionAbortRejection)`) stays the only caller of `plugin.abortSession`
  (`session_repository.dart:999-1011`) and maps `SessionAbortSubAgentPolicy
  ↔ PluginAbortSubAgentPolicy` and `PluginAbortResult →
  SessionAbortRejection` in `plugin_to_shared_mapping.dart` (the file Step 2
  already extends). `SessionAbortService.abortSession` wraps that into its
  sealed result and owns the push-suppression streams per outcome:
  `abortStartedSessions` still fires at call time (→
  `markSessionAbortPending`); `aborted` under `stop` fires `abortedSessions`
  (today's suppression); `rejected` and `aborted` under `keep` fire
  `abortFailedSessions` (→ `clearPendingAbort`, `orchestrator.dart:863`), so
  neither a dismissed dialog nor a kept sub-agent loses its eventual
  completion push — `keep` deliberately does not suppress the completion that
  follows the kept work, consistent with the Step 3 "fires once" rule.
  `AbortSessionHandler` only maps `rejected` → 409 like
  `delete_session_handler.dart`. Plugin stop/suspend paths
  (`interruptActiveWork`) use `stop`.
- Plugin interface: `BridgePluginApi.abortSession({sessionId, subAgents:
  PluginAbortSubAgentPolicy})` returning `PluginAbortResult` (`aborted` |
  `rejectedSubAgentsRunning(count, mainAgentRunning)`); every in-repo plugin
  is updated in lockstep — only Claude can reject; the others ignore the
  policy and keep their stop semantics.
- Claude (decision owner `ClaudeSessionService.abort`, which already owns the
  running set and the teardown; `ClaudePlugin.abortSession` forwards):
  `confirm` with at least one `subAgent` task → `rejectedSubAgentsRunning(
  subAgentCount, isTurnRunning)` with no side effect; `confirm` otherwise,
  or `stop` → interrupt + teardown (every resident task cancelled via process
  exit); `keep` → interrupt (`cancel_queued`, queue cleared as today)
  **without** teardown while tasks run — the process stays resident, tasks
  continue, their notifications wake the main agent as usual; `keep` with no
  tasks ≡ `stop`. The post-interrupt window stays owned where it lives today,
  `ClaudeSessionProcessRepository` (`_ResidentProcess.interrupted`, set by
  `interrupt()` and cleared by `sendTurn()`,
  `claude_session_process_repository.dart:205,250`): under `keep` the
  repository closes the window at the first of the next `sendTurn` or the
  first `ClaudeTaskNotificationMessage` for that session after the
  interrupt's own result, so the recovery/meta frames that teardown used to
  discard stay dropped by the existing `ClaudeTurnInterrupted`
  classification while the notification-triggered wake-up turn renders. The
  dispatcher gains no interrupt state; the Step 6 live capture only confirms
  which frame shapes appear inside that window.
- Client (Layer 1 → 2 → 3 → 4, no optional parameters):
  `SessionApi.abortSession({sessionId, subAgents})` sends
  `AbortSessionRequest` and parses the 409 into
  `SessionAbortRejectedException`; `SessionRepository.abortSession({sessionId,
  subAgents})` forwards and propagates it; `capabilities/session/
  SessionService.abortSession` is updated in lockstep;
  `SessionDetailCubit.abort({subAgents})` returns a sealed outcome
  (`aborted | rejected(rejection)`) and holds no new state. The `confirm`
  probe is side-effect free: the cubit clears its local prompt queue and
  recovery bookkeeping (`session_detail_cubit.dart:2243-2248`) only after a
  root `aborted` outcome or when retrying with `keep`/`stop`, and it sends
  exactly one root request per attempt — the existing child fan-out
  (`:2250-2259`, which today aborts every busy/retrying child alongside the
  root) runs only after a root `aborted` outcome under `stop`, never for
  `keep` and never before the dialog, so plugins whose children are real
  sessions keep today's stop-everything behavior while the root policy owns
  descendant scope. The stop action sends `confirm` first and, on rejection,
  shows a dialog modeled on `session_force_dialog.dart` — "Stop main agent
  only" (shown only when `mainAgentRunning`) and "Stop main agent and N
  sub-agents" — then retries with `keep` or `stop`; dismissing the dialog
  leaves everything running. l10n for the dialog.
- Not added: stopping one sub-agent (`stop_task`), a remembered default
  policy, analytics for the choice (candidate event if a default-policy
  decision ever comes up).

### Client (Step 2)

- `SubtaskPartWidget`: status icon + label come from `part.state?.status` when
  present (`pending|running` spinner "Running", `completed` check
  "Completed", `error` "Failed", `cancelled` cancel icon "Cancelled",
  `unknown` fallback); otherwise the current child-status logic. Tap: when
  `childSessionID` is present, push `AppRoute.sessionDetail(sessionId:
  childSessionID, readOnly: true, sessionTitle: description)` directly;
  otherwise the existing heuristic.
- `ToolPartWidget`: `cancelled` icon + label. New l10n key(s) for "Cancelled".
- No new widget, route, sheet, or design-catalog entry (the catalog currently
  hard-codes a single component; extending it is out of scope).
- Desktop renders no transcript; the phone split layout reuses the same widget.

## Complexity Budget

New mutable parts:

- Claude plugin: one per-session task map in `ClaudeToolTracker`
  (`tool_use_id → {messageId, description, prompt, agent, taskId, status,
  output, finalizedBy}`) owned through `ClaudeEventDispatcher`, plus the
  derived `parent_tool_use_id → childSessionId` routing view over it, and one
  per-session root directory recorded at `beginTurn` for child construction.
  Cleared on `forgetSession`/`cancelTasks` only. Child statuses, resident task
  ids, and `childSessionIds` are accessors over that one map.
- Claude plugin, lifecycle: one per-session `runningTaskIds` set in
  `ClaudeSessionService._SessionTurnState`, beside `wakeupAt` and
  `selfStartedTurn`, cleared on notification/exit/abort. Justified by the
  idle reaper and safe-stop policy that would otherwise kill running
  sub-agents; it is lifecycle state, not a second copy of presentation state.
- Bridge/app: none persistent. The sweep reads the root's existing status.
- Client: none.
- Scoped stop (Step 6): one dedicated request model and one 409 body on the
  wire, a sealed abort result in the plugin contract, no new bridge state
  (the existing abort-pending/aborted push marks are driven per outcome
  through the existing streams), the `ClaudeTaskType` on each running-set
  entry, and a client rejection that lives only for the dialog's lifetime (no
  new cubit field).

Deliberately not added: `stop_task` (abort already tears the process down),
a service→dispatcher query for task state, `task_progress` rendering,
per-subtask usage stats, streamed sub-agent text deltas, a nested parent
hierarchy, a new SSE event, a new route or sheet, transcript-item models in
the client, analytics.

## Evidence And Accepted Risk

| Concern | Classification | Decision |
|---|---|---|
| Agent calls invisible; sub-agent work unreadable | observed (user report, code) | core scope |
| Stuck "running" subtask after abrupt bridge death | ordinary reachable flow (bridge restart/update while agents run) | sweep finalizes an idle root's open subtask parts to `cancelled` (no child-status lookup; a busy root is never swept), Step 4 |
| Duplicate descriptions pick the wrong transcript under title matching | ordinary flow (fan-outs reuse labels) | `childSessionID`, Step 2 |
| Part update arrives before the child binding commits | theoretical ordering | accept: pending-event queue orders it; worst case the tile is untappable until the next update or reload |
| Idle reaper / safe stop would kill running sub-agents once the launching turn ends | ordinary reachable flow (every background agent outlives its turn; reap timeout is on by default) | running tasks keep the session busy and defer the reap, Step 3 |
| Abort kills running sub-agents with the process | existing abort semantics (interrupt + teardown); the user reports this is often unwanted day to day | scoped stop, Step 6: a plain stop is refused with a typed rejection while sub-agents run; the user chooses main-agent-only (`keep`, process stays resident) or everything (`stop`); until Step 6 lands, abort keeps today's semantics and cancelled sub-agents are the observable outcome |
| A task that never reports `task_notification` pins the session busy and the process resident | theoretical (CLI always emits a terminal notification in every observed flow) | accept; abort/delete/exit clear it; Step 3 evaluates `background_tasks_changed` as a reconciliation snapshot |
| An interrupted foreground agent renders `cancelled` live (notification `stopped`) but `error` on replay, because the transcript persists only its error tool result and no notification record, and tool-result text is never matched | cosmetic divergence | accept; recorded as a known limitation in Step 7 |
| External terminal session's running agent shows cancelled until its notification lands | rare, self-corrects | accept |
| `task_started`/`task_notification` absent on the 2.1.221 floor | unverified (no floor build on the dev machine) | every lifecycle trigger has a typed substitute: the `asyncLaunched`/`completed` tool result starts the child lifecycle (only `asyncLaunched` adds to the running-task set), and the completed tool result or parsed `<task-notification>` ends them, so parts, children, and reap deferral all work without task frames; the floor is probed in Step 3 if obtainable, else recorded as untested |
| Nested sub-agents flattened under the root | design | accept; activity tracking is one level deep anyway |
| A root whose only resident work is a non-sub-agent background task (shell, workflow) is busy in its status but absent from `getActiveSessionsSummary` (`mainAgentRunning` false, no busy child) | contract gap (`PluginActiveSession` has no background-task slot); rarer than sub-agents | accept; the session still shows busy and is never reaped; no mislabeling as main-agent or child activity; revisit only if project roll-ups for background shells are requested |
| Catalog import gains one row per sub-agent transcript | cost | accept; children read meta + stat only |

## Compatibility, Privacy, And Data

- Wire: two additive changes (`cancelled`, `childSessionID`), both tolerated by
  older peers as described; no new `MessagePartType` (older clients cannot
  decode unknown part types). No SSE event change. No relay change.
- Bridge DB: no migration; `childSessionID` and `cancelled` ride in
  `history_parts.partJson`; child sessions use the existing `parentSessionId`
  column through the existing import and live observation paths.
- Privacy: subtask `prompt`/`description`/summary are transcript content that
  already crosses the encrypted client contract as tool input/output today;
  nothing is logged. Logs keep ids and operation context, never prompt text.
- Stop: `subAgents` on the abort request uses `@Default(stop)` with a dated
  `COMPATIBILITY` comment, so an older client keeps today's stop-everything
  behavior and an older bridge ignores the field and stops everything without
  confirmation; the 409 `SessionAbortRejection` is only ever sent to a client
  that asked for `confirm`. The plugin `abortSession` signature/result change
  is an internal contract updated in lockstep across all plugins.
- Claude CLI floor unchanged; no new launch flag.

## Cleanup Assessment

- Update the `ponytail:` note at `claude_event_dispatcher.dart:79-80` and the
  stale layout comment at `claude_transcript_catalog_repository.dart:192-197`
  when touched (Steps 3/4).
- `SubtaskPartWidget._findChildSession` stays as the OpenCode fallback; it
  becomes removable only when OpenCode sets `childSessionID` (outside scope).
- `ClaudeTaskProgressMessage`/`ClaudeToolProgressMessage` remain parsed and
  unused; not caused by this work, left alone.
- No obsolete fields, columns, or flags are created.

## Non-Goals

- Removing or redesigning `BackgroundTasksBar`, the session-list task badge,
  or inline-only rendering for other plugins (separate cross-plugin effort;
  Claude children will appear in the bar automatically meanwhile).
- Rendering `task_progress`, usage, cost, or TodoWrite content.
- Stopping one sub-agent individually from Sesori (`stop_task`), or
  remembering a default stop policy; the scoped-stop dialog asks every time.
- Streaming sub-agent text deltas (`--forward-subagent-text`).
- Sub-agent permission prompts (`agent_id` on `can_use_tool`) — unchanged.
- Surfacing the legacy flat sub-agent transcript layout.
- Any OpenCode/ACP/Codex/Pi producer change.

## Regression Coverage

Affected feature documents: `docs/regression/tools-and-file-changes.md`
(primary: subtask part lifecycle incl. cancelled, child attribution, open to
read), `session-history-and-recovery.md` (the sweep finalizes an idle root's open
subtask parts to cancelled, never a busy root's; child transcripts reload
with stable identity),
`projects-and-sessions.md` (Claude sub-agent transcripts as child sessions in
import and listing), `session-turns.md` (Claude `<task-notification>` records
are internal, never rendered as user messages; a Claude session returns to
idle only after its last running task and the wake-up turn settle; a plain
stop while sub-agents run is refused and confirmed as main-agent-only or full
stop), `notifications.md` (completion fires once, after the last sub-agent
settles), `plugin-setup-and-lifecycle.md` (idle reap and safe stop defer
while a Claude task runs). `popup-alerts.md` was listed for the stop-scope
dialog but covers the transient alert surface, not modal dialogs; the dialog
is documented under `session-turns.md` instead (Step 7 decision, 2026-09-02).

Highest level needed: **L4**. Matrix: Claude plugin for all new behavior;
OpenCode representative proof that a `state: null` subtask part still renders
and opens as before; release-target phone; release-target bridge host. L3
proves client rendering, lifecycle transitions, and open-to-read through the
phone; L4 proves reload identity, bridge restart sweeping a dead sub-agent to
cancelled without touching a live background one, and child attribution.

## Fixed PR Series

| Step | Exact PR title | Target | Outcome |
|---|---|---|---:|
| 1/8 | `🌱 [claude-inline-subtasks] docs: plan inline Claude sub-agent subtasks [step 1/8]` | 450-650 | Plan and tracker |
| 2/8 | `⚙️ [claude-inline-subtasks] contract: subtask lifecycle state, cancelled status, child link [step 2/8]` | 500-800 | Shared/interface enums + field, bridge mapping and id translation, client tile and tool tile rendering, l10n, tests |
| 3/8 | `🚧 [claude-inline-subtasks] claude: live and replayed subtask lifecycle for Agent calls [step 3/8]` | 900-1,300 | Task frames parsed, task map, subtask parts, terminal rules, running-task lifecycle, process-exit cancel, hidden notification records, tests |
| 4/8 | `🚧 [claude-inline-subtasks] claude: sub-agent transcripts as child sessions [step 4/8]` | 900-1,400 | Child enumeration, child history read, live child create/status, delete paths, bridge sweep of open subtask parts, tests |
| 5/8 | `⚙️ [claude-inline-subtasks] claude: stream sub-agent frames into child sessions [step 5/8]` | 300-500 | Route forwarded frames to children, nested routing, tests |
| 6/8 | `🚧 [claude-inline-subtasks] stop: confirm main-agent-only or full stop while sub-agents run [step 6/8]` | 600-1,000 | Abort policy + 409 rejection on the wire, plugin abort result, Claude keep/stop semantics, client dialog, tests |
| 7/8 | `🌱 [claude-inline-subtasks] docs: reconcile regression docs [step 7/8]` | 80-200 | Feature documents updated |
| 8/8 | `🌱 [claude-inline-subtasks] docs: run coverage and retire the plan [step 8/8]` | 40-120 | L4 matrix recorded, plan moved to completed |

Targets are additions plus deletions including generated code and tests.
`TRACKER.md` bookkeeping is excluded from the step comparisons, because its
count would include the lines that record it; each step records its measured
non-tracker diff in the tracker.

## Step 1/8 - Plan

Add this `PLAN.md` and `TRACKER.md`; run `architecture-plan-review` through a
sub-agent and apply valid findings without re-review.

Verification: `git diff --check`; plan and tracker agree on slug, titles, and
the eight-step total.

## Step 2/8 - Contract And Client Tile

Scope:

- `shared`: `ToolStatus.cancelled`; `MessagePart.childSessionID`; codegen.
- `sesori_plugin_interface`: `PluginToolStatus.cancelled`;
  `PluginMessagePart.childSessionID`; update every in-repo constructor call
  (all plugins pass `childSessionID: null` except where a later step sets it).
- `bridge/app`: `plugin_to_shared_mapping.dart` (+ part mapping of the field);
  `session_event_mapper.dart` rewrites `childSessionID` through an optional
  lookup that never joins the required `backendSessionIds` set (a part with an
  unbound child id is still delivered, with null);
  `SessionRepository.getSessionMessages` best-effort read-path translation;
  `bridge_event_mapper_test`/event-mapper tests including the unbound case.
- `client/app`: `SubtaskPartWidget` lifecycle from `part.state`,
  `childSessionID` navigation, fallback preserved; `ToolPartWidget`
  cancelled; l10n; widget tests (status rendering per state, navigation by id
  inside and outside `SessionSplitScope`, OpenCode-shaped part unchanged).

Verification: codegen in shared/interface/client; `dart analyze
--fatal-infos` for touched packages; `dart test` in shared, interface,
bridge/app (mapping/event mapper/session repository tests); `flutter test`
session-detail widgets in `client/app`.

## Step 3/8 - Claude Subtask Lifecycle

Scope:

- `models/claude_task_status.dart`: closed `ClaudeTaskStatus` enum;
  `repositories/mappers/`: the single `toPluginToolStatus()` mapping.
- `models/claude_tool_use_result.dart`: sealed `ClaudeToolUseResult`
  (`asyncLaunched(agentId)`, `completed(agentId?)`, `absent`, `unknown`).
- `claude_stream_message.dart`: `ClaudeTaskStartedMessage`,
  `ClaudeTaskNotificationMessage` (status parsed to `ClaudeTaskStatus`);
  `ClaudeUserMessage.toolUseResult` parsed to `ClaudeToolUseResult`.
- `claude_content_mapper.dart`: `ClaudeMappedTaskNotificationContentBlock`
  (marker-prefix parse; never rendered).
- `claude_tool_tracker.dart`: `task` kind; per-session task map surviving
  turns; terminal rules; `cancelAll(sessionId)`.
- `claude_event_dispatcher.dart`: task frame handling; consumes the typed
  notification block; `cancelTasks(sessionId:)` and
  `residentTaskToolUseIds(sessionId:)` accessors (`childSessionStatuses` lands
  with its consumer in Step 4). The one subtask/tool part builder is
  `ClaudeTrackedTool.toPart`, shared with replay. Forwarded sub-agent frames
  stay dropped until Step 5.
- `claude_history_mapper.dart` + transcript DTO/record: `toolUseResult`,
  `agentId`; `map(..., residentTaskToolUseIds)` owns the running→cancelled
  downgrade.
- `claude_plugin_impl.dart`: `getSessionMessages` passes
  `residentTaskToolUseIds`; `_handleProcessEvent` handles
  `ClaudeSessionProcessExited` via `cancelTasks`; `deleteSession`/dispose call
  it before `forgetSession`.
- `models/claude_task_type.dart`: closed `ClaudeTaskType` (`subAgent` for
  `local_agent`, `other`), parsed on `ClaudeTaskStartedMessage`.
- `services/claude_session_service.dart`: parses `<task-notification>` text
  through the shared `ClaudeTaskNotification.tryParse` (in `models/`) directly
  on raw user content, the way `_trackWakeupSchedule` reads raw tool_use
  blocks, so no `ClaudeContentMapper` dependency is added (implementation
  refinement 2026-09-01, see `TRACKER.md`); `_SessionTurnState.runningTaskIds` (`{taskId → ClaudeTaskType}`) tracked
  from `ClaudeTaskStartedMessage`/`ClaudeTaskNotificationMessage` in
  `_handleProcessEvent` (beside `_trackWakeupSchedule`), cleared on process
  exit and abort; folded into `sessionStatuses`, `_syncWorkState`,
  `interruptActiveWork`, the `abort` eligibility guard, and the idle gate of
  `_finish`, `_endSelfStartedTurn`, and `_scheduleIdleReap`; floor
  substitutes keyed by task id (async-launch result's `agentId` adds,
  completed result's `agentId` or the parsed block's `taskId` removes); a
  notification (or notification-bearing user frame) while no turn is active
  opens a self-started turn; `_trackSelfStartedTurn` ignores forwarded child
  assistant/stream frames; `isTurnRunning(sessionId)` accessor. Tests: reap
  deferred while a task runs and armed only after the wake-up turn's result;
  no transient idle between the last notification and the wake-up turn; work
  state busy across the turn boundary; abort/exit clear; a forwarded child
  frame after the root result does not open a root turn; dispatch mode
  unchanged.
- Tests: parse, tracker lifecycle (foreground, background, failed, stopped,
  async-launched tool result, process exit), dispatcher event sequences,
  history replay fixtures (inline Dart maps), hidden notification records.
- One live capture against the pinned CLI confirming the background
  `<task-notification>` user-frame shape; record bounded facts in the tracker.

Verification: `dart analyze --fatal-infos` and `dart test` in
`bridge/sesori_plugin_claude`; `git diff --check`.

## Step 4/8 - Sub-Agent Child Sessions

Scope:

- `claude_transcript_api.dart` + `api/models/claude_subagent_meta_dto.dart`
  (Freezed): `readSubagentMeta`, `deleteDirectory`; no classification.
  `models/claude_subagent_session_id.dart` owns the `agent-<agentId>` rule.
- `claude_transcript_catalog_repository.dart` + `ClaudeSessionRecord.parentId`:
  child detection, `agent-` id resolution, legacy exclusion, root/child
  delete decisions, roots-only `getSessions`.
- `claude_history_mapper.dart`: child mode keyed by `agentId`.
- `claude_event_dispatcher.dart`: `beginTurn({sessionId, directory})`; child
  `PluginSession` construction and ordered created/status/part emission on
  the first agent-id-bearing signal (`task_started` or an agent-id tool
  result); idle on terminal/cancel; `childSessionStatuses` accessor.
- `claude_plugin_impl.dart`: `getChildSessions`; passes the root directory to
  `beginTurn`; `getSessionStatuses` disjoint union;
  `getActiveSessionsSummary` fills `childSessionIds` from busy children,
  derives `mainAgentRunning` from `isTurnRunning`, and includes a root when
  either is true.
- `bridge/app`: `ChatHistoryService._containsOpenToolPart` counts open
  subtask parts; `ChatHistoryRepository.finalizeOpenToolParts` finalizes them
  to `cancelled`; tests (a busy root is never swept; an idle root's open
  subtask parts become cancelled on both triggers).
- Tests: catalog (children, missing parent, legacy layout excluded), child
  history read, live event sequences, delete paths, sweep keeps busy children
  and cancels dead ones.

Verification: `dart analyze --fatal-infos` and `dart test` in
`bridge/sesori_plugin_claude` and `bridge/app`; manual phone check: a Claude
session with a running and a finished sub-agent shows both tiles, tap opens the
child transcript; catalog import lists children under the root.

## Step 5/8 - Live Sub-Agent Streaming

Scope: dispatcher routing of `parent_tool_use_id` frames to child ids; the
tracker's task map indexed by tool_use id globally with the owning rendered
session on each record, so root-process lifecycle frames for nested tasks
bind their nested child; tests proving isolation from the root session,
nested binding, and convergence with the replayed child transcript.

Verification: `dart analyze --fatal-infos` and `dart test` in
`bridge/sesori_plugin_claude`; manual: open a running sub-agent tile and watch
parts appear.

## Step 6/8 - Scoped Stop

Scope:

- `shared`: `AbortSessionRequest { sessionId, subAgents:
  SessionAbortSubAgentPolicy @Default(stop) }` with the dated
  `COMPATIBILITY` comment (`SessionIdRequest` untouched);
  `SessionAbortRejection { runningSubAgentCount, mainAgentRunning }`;
  codegen.
- `sesori_plugin_interface`: `abortSession({sessionId, subAgents:
  PluginAbortSubAgentPolicy})` → `PluginAbortResult` (`aborted` |
  `rejectedSubAgentsRunning(count, mainAgentRunning)`); every plugin updated
  (non-Claude plugins return `aborted` and ignore the policy).
- `bridge/app`: `SessionRepository.abortSession({sessionId, subAgents}) →
  SessionAbortResult` with the policy/result mappings in
  `plugin_to_shared_mapping.dart`; `SessionAbortService` wraps it and emits
  `abortedSessions` for `stop`, `abortFailedSessions` (clear pending) for
  `rejected` and `keep`; `AbortSessionHandler` switches to
  `AbortSessionRequest` and maps `rejected` → 409; plugin stop/suspend paths
  pass `stop`; tests including the stream emissions per outcome.
- `sesori_plugin_claude`: `ClaudeSessionService.abort({subAgents})` —
  `confirm` rejects with the `subAgent` count + `isTurnRunning` while
  sub-agents run, `keep` interrupts without teardown while tasks run, `stop`
  unchanged; `ClaudeSessionProcessRepository` closes the `interrupted` window
  under `keep` at the next `sendTurn` or the first task notification after the
  interrupt's result; `ClaudePlugin.abortSession` forwards; one live capture
  of post-interrupt frames with a kept process confirming the window's frame
  shapes; tests for all three policies with and without running tasks (incl.
  non-sub-agent-only tasks), and that `keep` leaves the running set, reap
  deferral, and child statuses intact and renders the later wake-up turn.
- `client`: `SessionApi.abortSession({sessionId, subAgents})` sends
  `AbortSessionRequest` and parses the 409 → `SessionAbortApiRejectedException`;
  `SessionRepository.abortSession` updated in lockstep (there is no
  `capabilities/session/SessionService` abort seam — implementation
  refinement 2026-09-02, see `TRACKER.md`); `SessionDetailCubit.abort({subAgents})`
  sealed outcome, side-effect-free `confirm` (queue clearing and the child
  fan-out only after a root `aborted` under `stop`, queue clearing also on
  `keep`); stop action sends `confirm`, shows the scope dialog on rejection,
  retries with `keep`/`stop`, dismiss leaves everything running; l10n;
  widget/cubit tests (dialog options per `mainAgentRunning`, dismissal keeps
  queued prompts, single root request per attempt).

Verification: codegen in shared/interface/client; `dart analyze
--fatal-infos` and `dart test` in shared, interface, bridge/app,
`bridge/sesori_plugin_claude`, `client/module_core`; `flutter test` for the
session-detail dialog; manual phone check: stop with a running sub-agent
shows the dialog, "main agent only" leaves the sub-agent tile running and
its wake-up turn later arrives, "stop all" cancels it.

## Step 7/8 - Regression Docs

Reconcile every feature document named in Regression Coverage above (seven:
tools and file changes, session history and recovery, projects and sessions,
session turns, notifications, plugin setup and lifecycle, popup alerts); add
the Claude sub-agent exploration guidance and failure signals (stuck running
tile, notification XML rendered as a user message, wrong transcript opened,
sub-agent killed by the idle reap or a plain stop without confirmation).

## Step 8/8 - Retire

Run the L4 matrix recorded above through the authoritative boundaries, record
results in `TRACKER.md`, and move the plan to `.plan/completed/`.
