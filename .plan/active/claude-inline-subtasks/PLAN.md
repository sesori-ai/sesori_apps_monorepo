# Claude Inline Sub-Agent Subtasks

## Status

- **Plan slug:** `claude-inline-subtasks`
- **Status:** Active - Step 1/7 plan
- **Plan date:** 2026-08-22
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main` at `ba725ec84`
- **Plan branch:** `inline-subtask-plan`
- **Plan PR:** [#1027](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1027)
- **Delivery:** seven PRs: plan, contract + client tile, Claude lifecycle,
  Claude child sessions, Claude live sub-agent streaming, regression docs,
  retirement

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
  a typed `ClaudeMappedTaskNotificationContentBlock({toolUseId, status:
  ClaudeTaskStatus, summary})` for a text block that starts with that marker
  (the same marker-prefix rule as `containsInternalCommandOutput`), so the
  live dispatcher and the history mapper both consume the typed block as a
  second terminal source and neither renders it as a user message. The status
  mapping is the shared `toPluginToolStatus()` above.
- Session process exit has one owner: `ClaudePlugin._handleProcessEvent`
  handles `ClaudeSessionProcessExited` by calling
  `ClaudeEventDispatcher.cancelTasks(sessionId:)` (which delegates to the
  tracker's `cancelAll`) and adds the returned part updates and child idle
  events to `_eventBuffer`; `deleteSession` and dispose call the same method
  before `forgetSession`. `ClaudeSessionService` never touches the dispatcher
  or tracker.
- **Running tasks keep the session alive (lifecycle owner:
  `ClaudeSessionService`).** `_SessionTurnState` gains `runningTaskIds`,
  maintained exactly like `wakeupAt`/`selfStartedTurn` from typed frames in
  `_handleProcessEvent`: `ClaudeTaskStartedMessage` adds `task_id`,
  `ClaudeTaskNotificationMessage` removes it, `ClaudeSessionProcessExited`
  and `abort` clear it. It covers **every** `task_type` (sub-agents,
  background shells, workflows, nested `owned_by_subagent` tasks), because
  any of them lives only inside the resident process. The set extends the
  existing "work in flight" predicate wherever it is evaluated:
  `sessionStatuses` (the root reports **busy** while a task runs, even after
  its turn's `result`), `_syncWorkState` (plugin `PluginWorkState.busy`, so
  safe stop/suspension refuse and a forced stop interrupts observably),
  `interruptActiveWork`'s active set, and the idle gate in
  `_finish`/`_endSelfStartedTurn`/`_scheduleIdleReap`. A notification that
  empties the set while nothing else runs emits `BridgeSseSessionIdle`, syncs
  work state, and arms the reap, symmetrically with a self-started turn
  ending; the CLI's wake-up turn that usually follows is a self-started turn
  and is handled by the existing code. On a CLI floor without task frames the
  service uses the same typed substitutes as the dispatcher: an
  `asyncLaunched` `ClaudeToolUseResult` adds the task and a completed tool
  result or a user frame carrying `ClaudeMappedTaskNotificationContentBlock`
  (via `ClaudeContentMapper`, Layer 2) removes it. `_trackSelfStartedTurn`
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
- Abort keeps today's semantics — interrupt **then teardown** — so running
  sub-agents die with the process and surface as `cancelled` through the
  process-exit rule; `stop_task` is not needed. Residual: if the CLI ever
  emits no `task_notification` for a task, the session stays busy and the
  process pinned until abort/delete/exit; Step 3's live capture checks whether
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
    `description`, `toolUseId`, `spawnDepth`), `deleteSessionDirectory(...)`,
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
  the root itself is already in the summary
  because the session service reports it busy while a task runs (lifecycle
  rule in Step 3), so the `:387` running/awaiting filter needs no change.
  This reaches the bar, `hasActiveWork`,
  activity roll-ups, and push grouping through the plugin's existing contract
  surfaces (`session.created`/`session.status` events, `getSessionStatuses`,
  `childSessionIds`); no bridge/app change is needed for that.
- Delete: root deletion also removes `<root>/` (its `subagents/`) through the
  API's `deleteSessionDirectory`; child deletion removes the `.jsonl` and
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
  parts with their own `childSessionID`.
- History and live use the same ids (transcript `uuid`/`message.id`/tool ids),
  so an open child screen converges after a reload without duplicates, exactly
  as the root session does today.

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

Deliberately not added: `stop_task` (abort already tears the process down),
a service→dispatcher query for task state, `task_progress` rendering,
per-subtask usage stats, streamed sub-agent text deltas, a nested parent
hierarchy, a new SSE event, a new route or sheet, transcript-item models in
the client, analytics.

## Evidence And Accepted Risk

| Concern | Classification | Decision |
|---|---|---|
| Agent calls invisible; sub-agent work unreadable | observed (user report, code) | core scope |
| Stuck "running" subtask after abrupt bridge death | ordinary reachable flow (bridge restart/update while agents run) | sweep extension keyed on child status, Step 4 |
| Duplicate descriptions pick the wrong transcript under title matching | ordinary flow (fan-outs reuse labels) | `childSessionID`, Step 2 |
| Part update arrives before the child binding commits | theoretical ordering | accept: pending-event queue orders it; worst case the tile is untappable until the next update or reload |
| Idle reaper / safe stop would kill running sub-agents once the launching turn ends | ordinary reachable flow (every background agent outlives its turn; reap timeout is on by default) | running tasks keep the session busy and defer the reap, Step 3 |
| Abort kills running sub-agents with the process | existing abort semantics (interrupt + teardown) | accept; they surface as `cancelled`, which is the observable outcome the user asked for |
| A task that never reports `task_notification` pins the session busy and the process resident | theoretical (CLI always emits a terminal notification in every observed flow) | accept; abort/delete/exit clear it; Step 3 evaluates `background_tasks_changed` as a reconciliation snapshot |
| An interrupted foreground agent renders `cancelled` live (notification `stopped`) but `error` on replay, because the transcript persists only its error tool result and no notification record, and tool-result text is never matched | cosmetic divergence | accept; recorded as a known limitation in Step 6 |
| External terminal session's running agent shows cancelled until its notification lands | rare, self-corrects | accept |
| `task_started`/`task_notification` absent on the 2.1.221 floor | unverified (no floor build on the dev machine) | every lifecycle trigger has a typed substitute: the `asyncLaunched`/`completed` tool result starts the child lifecycle and the running-task set, and the completed tool result or parsed `<task-notification>` ends them, so parts, children, and reap deferral all work without task frames; the floor is probed in Step 3 if obtainable, else recorded as untested |
| Nested sub-agents flattened under the root | design | accept; activity tracking is one level deep anyway |
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
- Stopping one sub-agent individually from Sesori (`stop_task`); abort
  cancels all work by tearing the process down, as today.
- Streaming sub-agent text deltas (`--forward-subagent-text`).
- Sub-agent permission prompts (`agent_id` on `can_use_tool`) — unchanged.
- Surfacing the legacy flat sub-agent transcript layout.
- Any OpenCode/ACP/Codex/Pi producer change.

## Regression Coverage

Affected feature documents: `docs/regression/tools-and-file-changes.md`
(primary: subtask part lifecycle incl. cancelled, child attribution, open to
read), `session-history-and-recovery.md` (sweep covers open subtask parts keyed
on child status; child transcripts reload with stable identity),
`projects-and-sessions.md` (Claude sub-agent transcripts as child sessions in
import and listing), `session-turns.md` (Claude `<task-notification>` records
are internal, never rendered as user messages; a Claude session returns to
idle only after its last running task and the wake-up turn settle, and abort
cancels running sub-agents), `notifications.md` (completion fires once, after
the last sub-agent settles), `plugin-setup-and-lifecycle.md` (idle reap and
safe stop defer while a Claude task runs).

Highest level needed: **L4**. Matrix: Claude plugin for all new behavior;
OpenCode representative proof that a `state: null` subtask part still renders
and opens as before; release-target phone; release-target bridge host. L3
proves client rendering, lifecycle transitions, and open-to-read through the
phone; L4 proves reload identity, bridge restart sweeping a dead sub-agent to
cancelled without touching a live background one, and child attribution.

## Fixed PR Series

| Step | Exact PR title | Target | Outcome |
|---|---|---|---:|
| 1/7 | `🌱 [claude-inline-subtasks] docs: plan inline Claude sub-agent subtasks [step 1/7]` | 450-650 | Plan and tracker |
| 2/7 | `⚙️ [claude-inline-subtasks] contract: subtask lifecycle state, cancelled status, child link [step 2/7]` | 500-800 | Shared/interface enums + field, bridge mapping and id translation, client tile and tool tile rendering, l10n, tests |
| 3/7 | `🚧 [claude-inline-subtasks] claude: live and replayed subtask lifecycle for Agent calls [step 3/7]` | 900-1,300 | Task frames parsed, task map, subtask parts, terminal rules, process-exit cancel, hidden notification records, tests |
| 4/7 | `🚧 [claude-inline-subtasks] claude: sub-agent transcripts as child sessions [step 4/7]` | 900-1,400 | Child enumeration, child history read, live child create/status, delete paths, bridge sweep of open subtask parts, tests |
| 5/7 | `⚙️ [claude-inline-subtasks] claude: stream sub-agent frames into child sessions [step 5/7]` | 300-500 | Route forwarded frames to children, nested routing, tests |
| 6/7 | `🌱 [claude-inline-subtasks] docs: reconcile regression docs [step 6/7]` | 80-200 | Feature documents updated |
| 7/7 | `🌱 [claude-inline-subtasks] docs: run coverage and retire the plan [step 7/7]` | 40-120 | L4 matrix recorded, plan moved to completed |

Targets are additions plus deletions including generated code and tests.
`TRACKER.md` bookkeeping is excluded from the step comparisons, because its
count would include the lines that record it; each step records its measured
non-tracker diff in the tracker.

## Step 1/7 - Plan

Add this `PLAN.md` and `TRACKER.md`; run `architecture-plan-review` through a
sub-agent and apply valid findings without re-review.

Verification: `git diff --check`; plan and tracker agree on slug, titles, and
the seven-step total.

## Step 2/7 - Contract And Client Tile

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

## Step 3/7 - Claude Subtask Lifecycle

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
- `claude_event_dispatcher.dart`: subtask part builder; task frame handling;
  consumes the typed notification block; `cancelTasks(sessionId:)`,
  `residentTaskToolUseIds(sessionId:)`, `childSessionStatuses(sessionId:)`
  accessors (the last is used by Step 4). Forwarded sub-agent frames stay
  dropped until Step 5.
- `claude_history_mapper.dart` + transcript DTO/record: `toolUseResult`,
  `agentId`; `map(..., residentTaskToolUseIds)` owns the running→cancelled
  downgrade.
- `claude_plugin_impl.dart`: `getSessionMessages` passes
  `residentTaskToolUseIds`; `_handleProcessEvent` handles
  `ClaudeSessionProcessExited` via `cancelTasks`; `deleteSession`/dispose call
  it before `forgetSession`.
- `services/claude_session_service.dart`: `_SessionTurnState.runningTaskIds`
  tracked from `ClaudeTaskStartedMessage`/`ClaudeTaskNotificationMessage` in
  `_handleProcessEvent` (beside `_trackWakeupSchedule`), cleared on process
  exit and abort; folded into `sessionStatuses`, `_syncWorkState`,
  `interruptActiveWork`, and the idle gate of `_finish`,
  `_endSelfStartedTurn`, and `_scheduleIdleReap`; an emptied set emits idle
  and arms the reap; floor substitutes (async-launch result adds, completed
  result or parsed notification block removes); `_trackSelfStartedTurn`
  ignores forwarded child assistant/stream frames. Tests: reap deferred while
  a task runs and armed after its notification; work state busy across the
  turn boundary; abort/exit clear; a forwarded child frame after the root
  result does not open a root turn; dispatch mode unchanged.
- Tests: parse, tracker lifecycle (foreground, background, failed, stopped,
  async-launched tool result, process exit), dispatcher event sequences,
  history replay fixtures (inline Dart maps), hidden notification records.
- One live capture against the pinned CLI confirming the background
  `<task-notification>` user-frame shape; record bounded facts in the tracker.

Verification: `dart analyze --fatal-infos` and `dart test` in
`bridge/sesori_plugin_claude`; `git diff --check`.

## Step 4/7 - Sub-Agent Child Sessions

Scope:

- `claude_transcript_api.dart` + `api/models/claude_subagent_meta_dto.dart`:
  `readSubagentMeta`, `deleteSessionDirectory`; no classification.
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
  `getActiveSessionsSummary` fills `childSessionIds`.
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

## Step 5/7 - Live Sub-Agent Streaming

Scope: dispatcher routing of `parent_tool_use_id` frames to child ids,
nested mapping, tests proving isolation from the root session and convergence
with the replayed child transcript.

Verification: `dart analyze --fatal-infos` and `dart test` in
`bridge/sesori_plugin_claude`; manual: open a running sub-agent tile and watch
parts appear.

## Step 6/7 - Regression Docs

Reconcile the four feature documents listed above; add the Claude sub-agent
exploration guidance and failure signals (stuck running tile, notification
XML rendered as a user message, wrong transcript opened).

## Step 7/7 - Retire

Run the L4 matrix recorded above through the authoritative boundaries, record
results in `TRACKER.md`, and move the plan to `.plan/completed/`.
