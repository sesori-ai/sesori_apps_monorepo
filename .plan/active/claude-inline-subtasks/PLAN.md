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
   bridge session id at the two existing id-translation seams:
   `SessionEventMapper` (`backendSessionIds` collects it; the rewrite maps it
   through the same binding lookup) and the history read path in
   `SessionRepository.getSessionMessages` (resolve child bindings for the
   distinct ids on the page). An unresolvable id maps to null, which degrades
   the tile to the existing title fallback until a later update resolves it.
   Older bridges omit the field; older clients ignore it.

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
  `cancelled`; `unknown` → `unknown`. Terminal is sticky.
- A `user` tool-result frame for a task whose `tool_use_result.status ==
  "async_launched"` never finalizes the part. Any other tool result (foreground
  completion, error, or an older CLI that omits `tool_use_result`) finalizes
  per `is_error` exactly like a tool, unless already terminal. No tool-result
  text is matched.
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
- Abort (`interrupt`) is unchanged: it stops the foreground turn; background
  agents keep running, as in the CLI. Stopping them (`stop_task`) is a
  follow-up, not part of this plan.

History replay, in `ClaudeHistoryMapper`:

- `Agent`/`Task` tool_use → subtask part; the tool-result record's
  `toolUseResult.status == "async_launched"` → `running` and
  `toolUseResult.agentId` → `childSessionID`; any other tool result finalizes
  per `is_error`; a `ClaudeMappedTaskNotificationContentBlock` in a user
  record finalizes with its status/summary. The transcript DTO gains `agentId`
  and `toolUseResult` (`status`, `agentId`).
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
- Live child sessions — one status owner. `ClaudeEventDispatcher` (over the
  tracker task map) is the sole source of child-session status and exposes
  `childSessionStatuses({sessionId})`; `ClaudePlugin.getSessionStatuses()`
  returns the disjoint union of `ClaudeSessionService.sessionStatuses` (roots)
  and that accessor (children) with no decision of its own, and
  `ClaudePlugin.getActiveSessionsSummary()` fills
  `PluginActiveSession.childSessionIds` from the same accessor (today
  `const []` at `claude_plugin_impl.dart:396`). Emission: the dispatcher emits
  `BridgeSseSessionStatus(child, busy)` on `task_started` and `idle` on
  terminal/`cancelTasks` inside `map()` (precedent: `_mapRetry` already emits
  session status). `ClaudePlugin._handleProcessEvent` emits
  `BridgeSseSessionCreated(child)` when the frame is a
  `ClaudeTaskStartedMessage`, building the child `PluginSession` from
  `_findSession(root)` (directory/projectID) plus the frame's description, and
  adds it to `_eventBuffer` **before** the dispatcher's events for that frame
  (precedent: the typed `ClaudeInitMessage`/`ClaudeApiRetryMessage` handling
  at `:574-586`). This reaches the bar, `hasActiveWork`, activity roll-ups,
  and push grouping through the plugin's existing contract surfaces
  (`session.status` events, `getSessionStatuses`, `childSessionIds`); no
  bridge/app change is needed for that.
- Delete: root deletion also removes `<root>/` (its `subagents/`) through the
  API's `deleteSessionDirectory`; child deletion removes the `.jsonl` and
  `.meta.json`. Rename/archive on a child are no-ops, as today for OpenCode
  children.
- Legacy flat `agent-<slug>-<hex>.jsonl` transcripts stay excluded (no title,
  no tool link) — honest limitation.
- Bridge sweep extension (bridge/app, same PR), layered: `ChatHistoryService`
  (Layer 3, which already holds `_sessionRepository` and
  `_chatHistoryRepository`) resolves the statuses of the `childSessionID`s
  referenced by open subtask parts through `SessionRepository.getSessionStatus`
  and passes the keep-open set down as data:
  `ChatHistoryRepository.finalizeOpenToolParts({sessionId, updatedAt,
  keepOpenChildSessionIds})`. The repository performs no status lookup and
  never imports `SessionRepository`. The ids come from the in-memory page on
  the read trigger (`chat_history_service.dart:117-118`) and from a dumb
  repository read `openSubtaskChildSessionIds(sessionId:)` on the
  idle-transition trigger (`chat_history_service.dart:452`); both triggers run
  the same service-level resolution. `_containsOpenToolPart` also counts
  subtask parts with an open `state`. The repository finalizes an open subtask
  part to `cancelled` (no error text) unless its `childSessionID` is in the
  keep-open set; an open subtask part without `childSessionID` is finalized to
  `cancelled` as well. Tool parts keep today's `error` finalization. This is
  what repairs a stuck spinner after an abrupt bridge death, uniformly with
  tool parts, without sweeping live background agents.

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
  output}`) owned through `ClaudeEventDispatcher`, plus the derived
  `parent_tool_use_id → childSessionId` routing view over it. Cleared on
  `forgetSession`/`cancelTasks` only. Child statuses, resident task ids, and
  `childSessionIds` are accessors over that one map; `ClaudeSessionService`
  gains no field.
- Bridge/app: none persistent. The sweep reads existing session statuses.
- Client: none.

Deliberately not added: parent-session busy derivation from sub-agents,
`stop_task` on abort, `task_progress` rendering, per-subtask usage stats,
streamed sub-agent text deltas, a nested parent hierarchy, a new SSE event, a
new route or sheet, transcript-item models in the client, analytics.

## Evidence And Accepted Risk

| Concern | Classification | Decision |
|---|---|---|
| Agent calls invisible; sub-agent work unreadable | observed (user report, code) | core scope |
| Stuck "running" subtask after abrupt bridge death | ordinary reachable flow (bridge restart/update while agents run) | sweep extension keyed on child status, Step 4 |
| Duplicate descriptions pick the wrong transcript under title matching | ordinary flow (fan-outs reuse labels) | `childSessionID`, Step 2 |
| Part update arrives before the child binding commits | theoretical ordering | accept: pending-event queue orders it; worst case the tile is untappable until the next update or reload |
| Background agents keep running after abort | CLI semantics | accept; `stop_task` follow-up |
| External terminal session's running agent shows cancelled until its notification lands | rare, self-corrects | accept |
| `task_started`/`task_notification` absent on the 2.1.221 floor | unverified | lifecycle also honors tool-result finalization and the `<task-notification>` user-frame parse, so it degrades without stuck state |
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
- Stopping sub-agents from Sesori, or deriving parent busy state from them.
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
are internal, never rendered as user messages).

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
  `session_event_mapper.dart` collects and rewrites `childSessionID`;
  `SessionRepository.getSessionMessages` read-path translation;
  `bridge_event_mapper_test`/event-mapper tests.
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
- `claude_stream_message.dart`: `ClaudeTaskStartedMessage`,
  `ClaudeTaskNotificationMessage` (status parsed to `ClaudeTaskStatus`);
  `ClaudeUserMessage.toolUseResult` (status, agentId).
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
  it before `forgetSession`. `ClaudeSessionService` is untouched.
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
- `claude_event_dispatcher.dart`: child `BridgeSseSessionStatus` events,
  `childSessionStatuses` accessor.
- `claude_plugin_impl.dart`: `getChildSessions`; child
  `BridgeSseSessionCreated` on `ClaudeTaskStartedMessage`;
  `getSessionStatuses` disjoint union; `getActiveSessionsSummary`
  `childSessionIds`; `childSessionID` on the part via the dispatcher.
- `bridge/app`: `ChatHistoryService` resolves keep-open child ids for both
  sweep triggers; `ChatHistoryRepository.finalizeOpenToolParts(...,
  keepOpenChildSessionIds)` + `openSubtaskChildSessionIds`; tests.
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
