# Inline Sub-Agent Subtasks: Harness Follow-Ups

## Status

- **Plan slug:** `claude-inline-subtasks` (follow-ups to the completed series)
- **Plan date:** 2026-09-02
- **Base:** `main` at `6e9028c4c6`
- **Delivery:** PRs titled `<emoji> [claude-inline-subtasks] <description>` with
  no step counters. The three harness chains run in parallel; within a
  chain PRs stack. E2E testing happens after each PR merges, not before.
  Progress is tracked in `TRACKER.md` "Harness Follow-Ups".

## Goal

Bring the capability shipped for Claude and OpenCode to every harness whose
seam can carry it, per `docs/HARNESS_CAPABILITIES.md`:

- sub-agents render inline as subtask tiles with their own lifecycle and open a
  child session;
- child sessions stream live and reload from history;
- the root stays busy while a child runs, so the idle reaper and safe stops
  never kill a running sub-agent and the completion push fires once;
- stop is scoped through the existing `abortSession({sessionId, subAgents})`
  contract, and `mainAgentOnlySupported` is declared honestly per harness.

The contract, bridge translation, sweep, client tile, and dialog already exist
and are not changed here. Every follow-up is plugin-internal work plus, for
DeepSeek, work in Sesori's own adapter repository.

Harnesses verified as not supportable over the seam Sesori drives (Copilot,
Hermes, Pi, Oh My Pi) and the Cursor tile-only variant are out of scope; their
verdicts and versions are recorded in the capability matrix.

## Shared Rules

- Backend payloads, DTOs, and lifecycle mapping stay inside the owning plugin
  package. The generic ACP plugin gains only backend-neutral seams, and only
  when the Grok work (its first consumer) needs them; DeepSeek reuses them.
- Child session ids are the harness's own session or thread ids. Parentage is
  data on the session record, never an id prefix.
- One child equals one tile. Progress events do not update the tile; only
  start, finish, interrupt, close, and process exit do.
- A child whose finish never arrives is cleared by abort, delete, or process
  exit, exactly as for Claude. No reconciliation timers.
- Nested children are flattened under the root where the harness does not
  itself model the tree; where it does (DeepSeek `delegationDepth`, Codex
  `parentThreadId`), the direct parent is kept.
- Each chain starts with a live probe PR-less capture recorded in the tracker
  (bounded facts only, no prompt or transcript text). Open questions below
  name the probe that resolves them; design branches that depend on a probe
  state both outcomes.
- Each chain ends by updating `docs/HARNESS_CAPABILITIES.md` (footnote and
  cells) and the regression documents `tools-and-file-changes.md`,
  `session-turns.md`, `projects-and-sessions.md`, and where relevant
  `session-history-and-recovery.md` and `notifications.md`.

## Codex (codex-cli 0.148.0, app-server v2)

### Verified facts

- `multi_agent` is stable. Thread objects carry `parentThreadId`,
  `agentNickname`, `agentRole`, `threadSource` (`subAgent`,
  `subAgentReview`, `subAgentCompact`, `subAgentThreadSpawn`, ...).
  `thread/list` accepts `sourceKinds` and `parentThreadId`.
- Item `collabAgentToolCall` (`tool`: `spawnAgent | sendInput | resumeAgent |
  wait | closeAgent`; `senderThreadId`, `receiverThreadIds`, `prompt`,
  `status`, `agentsStates` with agent status `pendingInit | running |
  completed | failed | interrupted | errored | shutdown | notFound`). Item
  `subAgentActivity` (`kind`: `started | interacted | interrupted |
  completed`; `agentThreadId`, `agentPath`). Upstream `main` has renamed the
  item to `collabToolCall` with `receiverThreadId`/`newThreadId`; 0.148.0 does
  not carry those strings, so the parser accepts both type names.
- Parent-owned children reject `turn/start` and `turn/steer`
  (`direct app-server input is not allowed for multi-agent v2 sub-agents`);
  `turn/interrupt` is allowed on them. `thread/delete` and `thread/archive`
  cascade to descendants. A child's `subAgentActivity completed` may arrive
  after the parent's `turn/completed`.
- Child rollouts persist `session_meta.parent_thread_id`,
  `thread_source: "subagent"`, `agent_nickname`, `agent_path`, and (on 0.144.1)
  a copied parent history prefix.
- **Existing defect:** every `thread/started` becomes a root session and the
  catalog never reads `thread_source`, so Codex children already appear as
  root sessions in Sesori. The first Codex PR fixes this regardless of tiles.

### Current plugin

- `codex_thread_dto.dart` and `codex_thread_record.dart` have no parent
  fields. `codex_event_mapper.dart` `mapThreadStarted` emits `parentID: null`;
  `_itemToEvents` drops collab and activity items.
- `codex_plugin_impl.dart`: `abortSession` ignores the policy and interrupts
  only the named thread; `getChildSessions` returns `[]`;
  `getActiveSessionsSummary` hard-codes `childSessionIds: const []`.
- `codex_catalog_repository.dart` maps every rollout as a root.
- History: `CodexMessageRepository.projectMessages` renders a persisted
  `spawn_agent` call as a generic tool card.

### Design

- **Boundary parsing.** `CodexThreadDto` and the rollout session-meta DTO gain
  the parent, nickname, role, source, and agent-path fields. A new Freezed
  parser yields sealed `CodexCollabItem` (`spawnAgent`, `wait`, `closeAgent`,
  `sendInput`, `resumeAgent`, `unknown`) and `CodexSubAgentActivity` with
  closed enums and `unknown` fallbacks.
- **Child sessions.** `CodexThreadRecord.parentId`; `thread/started` with a
  parent emits `Session(parentID: parent, title: nickname ?? agentPath)`.
  The catalog maps `thread_source == subagent` rollouts with their parent and
  excludes them from `getSessions` (roots only) while keeping them in
  `listAllSessions`; `getChildSessions(root)` merges catalog children with the
  live spawn map. Children inherit the parent's directory so their events carry
  the parent's project id. Child history reads by thread id; the copied parent
  prefix is trimmed only if the 0.148.0 probe still shows it.
- **Tiles.** A per-parent `CodexSubAgentTracker`: `spawnAgent` opens a
  `subtask` part (`messageID` = item id, `prompt`, description from agent path
  or nickname, `childSessionID` = first receiver thread, `taskState` pending
  then running on `started`); `completed` completes, `interrupted` and
  `shutdown`/`notFound` cancel, `failed`/`errored` error; a child
  `thread/closed` or a disconnect cancels open tiles. `wait`, `sendInput`, and
  `resumeAgent` only refresh the same tile's state. The tracker survives the
  root's idle transition because completion can arrive after
  `turn/completed`.
- **Live streaming.** Nothing to route: child items already arrive under the
  child thread id and render once the child session exists.
- **Busy accounting.** Summary iterates roots; `childSessionIds` are the busy
  children; `mainAgentRunning` is the root's own turn.
- **Scoped stop.** `confirm` with busy children rejects with the count and
  `mainAgentRunning`. `stop` interrupts the root then each busy child.
  `keep` interrupts the root only and returns `workKept: true` if the probe
  shows children survive a parent interrupt (`mainAgentOnlySupported: true`);
  otherwise it is refused while the root runs, as for OpenCode.

### PRs

| Emoji | Description | Scope |
|---|---|---|
| 🌿 | `codex: parse sub-agent thread and item metadata` | DTO fields, collab/activity parser and enums, fixtures from the probe |
| ⚙️ | `codex: sub-agent threads become child sessions` | `parentID` live and from the catalog, roots-only listing, `getChildSessions`, directory attribution, summary rolls busy children into the root. Fixes the root-leak defect |
| 🚧 | `codex: inline subtask tiles for spawned agents` | tracker, mapper cases, cancel on close/disconnect, replay from rollout if persisted |
| ⚙️ | `codex: scoped stop for sub-agent threads` | policy switch, per-child interrupt, `mainAgentOnlySupported` per probe, `interruptActiveWork` covers children |
| 🌱 | `docs: record Codex sub-agent coverage` | matrix footnote ³ resolved, regression docs |

### Open questions (probe)

1. Does 0.148.0 emit `thread/started` for V2 children on our connection, and
   are `receiverThreadIds` present at `item/started` or only `item/completed`?
   If children never announce themselves, the tile PR reads the child through
   `thread/read` on first sight of a receiver id.
2. Does interrupting the parent interrupt or shut down its children? Does a
   child `turn/interrupt` need a turn id we may never receive?
3. Do 0.148.0 parent rollouts persist collab and activity items, and do child
   rollouts still copy the parent history?
4. Existing bridge-originated children already sit in users' lists as roots.
   Proposed: accept the re-parenting on the next catalog import; no migration.

## Grok Build (1.0.5, ACP stdio)

### Verified facts (binary string survey)

- Extension notification `x.ai/session_notification` wraps an internally
  tagged `SessionUpdate` (`sessionUpdate` key, snake_case) including
  `subagent_spawned` (`subagent_id`, `parent_session_id`,
  `child_session_id`, `subagent_type`, `capability_mode`, `persona`,
  `resumed_from`, `workflow_run_id`, ...), `subagent_progress`
  (`duration_ms`, `turn_count`, `tool_call_count`, ...),
  `subagent_finished` (`tool_calls`, `turns`, ...), plus `task_backgrounded`
  and `task_completed` with `tool_call_id`.
- Extension request `x.ai/subagent/cancel` with `subagentId`. The kill tool
  sends cancel and shutdown to subagents. Nesting depth is one.
- A turn cancel does not cancel subagents ("background tasks, subagents, and
  the rest of the queue keep running"); `cancel_subagents_on_turn_cancel` is a
  TUI-side preference, not agent behavior Sesori can toggle.
- Children persist in the normal sessions tree with `parentSessionId`,
  `sessionKind`, `subagentType`, `subagentRole`, `subagentDepth`.

### Current plugin

- `acp_event_mapper.dart` routes non-`session/update` methods to
  `mapExtension`, whose base returns `[]`; Grok uses the base mapper, so every
  `x.ai/*` notification is dropped. Child updates, if they arrive, lack a
  preceding `session.created` and are discarded by the bridge binding.
- `acp_plugin.dart`: `abortSession` ignores the policy and sends
  `session/cancel`; `getChildSessions` returns `[]`; `childSessionIds` are
  empty; work state derives from `pending` only. `sessionParentId` is an
  overridable hook (DeepSeek already overrides it).
- History replays `session/load` through `AcpReplayCollector`, which knows only
  standard updates.

### Design

- **Ownership.** `GrokEventMapper extends AcpEventMapper` overrides
  `mapExtension`; Freezed DTOs parse the snake_case payloads into a sealed
  `GrokSubagentUpdate` (`spawned | progress | finished`) with a closed status
  enum. The generic ACP plugin gains three backend-neutral seams, introduced
  here because Grok is their first consumer and DeepSeek the second: a helper
  that emits a live child (created, busy status, subtask part), a child-status
  map merged into `getSessionStatuses` and the summary's `childSessionIds`,
  and an `abortSession` decision hook.
- **Tiles.** `subagent_spawned` emits the child session (`parentID` = root,
  title = description, directory = root's), busy status, and a `subtask` part
  (`agent` = subagent type, `childSessionID` = child session id, running).
  `subagent_progress` is ignored. `subagent_finished` completes, errors, or
  cancels and sets the child idle. If the spawn also arrives as a standard
  `tool_call` for `spawn_subagent`, the mapper suppresses that tool card so one
  tile renders (probe decides).
- **Child history and streaming.** Child `session/update`s flow through the
  existing mapper once the child exists. `getSessionMessages(child)` works if
  `session/load` accepts child ids (probe). If `session/load` does not replay
  `x.ai` frames, the parent tile after reload degrades to a `spawn_subagent`
  tool card; accepted and recorded in the matrix.
- **Busy accounting.** Root idle emission is deferred while children run and
  released on the last `subagent_finished`; process exit cancels tracked
  children.
- **Scoped stop.** `confirm` rejects with the running count. `stop` sends
  `session/cancel` plus `x.ai/subagent/cancel` per child. `keep` sends
  `session/cancel` only. `mainAgentOnlySupported` is true when every running
  child is background (they survive a turn cancel by documented behavior); if
  the spawn payload exposes no background flag and the probe shows a
  foreground child dying with the parent tool call, report false as for
  OpenCode.

### PRs

| Emoji | Description | Scope |
|---|---|---|
| ⚙️ | `grok: parse sub-agent lifecycle notifications` | DTOs, `GrokEventMapper.mapExtension`, ACP live-child helper, subtask part and child created/status emission, mapper fixtures from the probe |
| ⚙️ | `acp: child sessions keep the root busy` | child-status map, idle deferral, summary `childSessionIds`, exit cleanup, Grok `getChildSessions`/`sessionParentId` |
| 🌿 | `grok: child session history` | `session/load` for child ids, parent replay of `x.ai` frames if replayed |
| ⚙️ | `grok: scoped stop for sub-agents` | `abortSession` hook, `x.ai/subagent/cancel` in the Grok API, `mainAgentOnlySupported` rule, `interruptActiveWork` uses stop |
| 🌱 | `docs: record Grok Build sub-agent coverage` | matrix footnote ¹⁰ resolved, regression docs |

### Open questions (probe with `grok --no-auto-update agent --no-leader stdio`)

1. Exact JSON of the three notifications; is the envelope `sessionId` the
   parent; is `subagent_id` equal to `child_session_id`; is a background flag
   present?
2. Do child `session/update`s arrive on the same connection under the child id,
   starting with the child's prompt?
3. Do `session/load` and `session/list` accept or return child ids with a
   parent marker?
4. Fate of a foreground child on `session/cancel`; response shape of
   `x.ai/subagent/cancel` and the resulting `subagent_finished` status.
5. Is `spawn_subagent` also surfaced as a standard `tool_call`; does a
   background finish trigger a wake-up turn?

## DeepSeek (`sesori-deepseek-acp` 0.1.2 over dsh 0.1.1-rc.2)

### Verified facts

- dsh emits `subagent/start {runId, provider, id}` and `subagent/end
  {..., stopReason: completed | aborted | error | max-tokens | refusal,
  lastAssistantMessage?}` with the parent as scoped carrier; neither carries a
  label, mode, or the parent tool call id. A log-only `subagent/descriptor`
  records `mode: one-shot | continuable` and `label`.
- Child headers inherit the parent `cwd` and set `parentSession`,
  `origin: "subagent"`, `delegationDepth`.
- The `subagent` tool is background (continuable) by default;
  `run_in_background: false` runs a foreground one-shot. `subagent_fork` is
  one-shot. A foreground child is cancelled by the parent tool's signal;
  continuable children survive a parent cancel and are disposed only with the
  parent agent. `ctx.subagents.interrupt(childId, {kind: "user",
  parentSessionId})` interrupts continuable children; one-shot background
  fork jobs cannot be interrupted individually.
- The adapter (`src/sessions.ts`) forwards `tool/call` as a generic
  `tool_call`, never forwards `subagent/*`, drops `session/event` for sessions
  it does not own (so child events are discarded today), and already exposes
  `parentSessionId`, `origin`, `delegationDepth` in `listSessions`.
  `loadSession` and history work for any persisted id with a matching `cwd`,
  so child history is reachable now. `_meta["sesori.ai/deepseek"]` is the
  established extension envelope; the schema is Ajv-validated and
  `EXTENSION_PROTOCOL_VERSION = 1`.

### Current plugin

- `deepseek_plugin_impl.dart` already parses `parentSessionId` from `_meta`
  and lists persisted children through `listAllSessions`. Live child status,
  tiles, and links are missing. `deepseek_event_mapper.dart` overrides
  `mapExtension` for `deepseek/session/status`.

### Design

- **Adapter extension (protocol v2, additive).** New notification
  `deepseek/subagent` sealed by `kind`: `started {sessionId, childSessionId,
  toolCallId?, label, mode: foreground | background}` and `ended {sessionId,
  childSessionId, stopReason, summary?}` (bounded text of the last assistant
  message). Mode derives from the open `subagent`/`subagent_fork` call's
  `run_in_background` argument with the tool defaults; label from
  `subagent/descriptor`. When several calls are open, `toolCallId` is null and
  the label matches. Child transcripts: the adapter projects events for
  sessions whose header `parentSession` is an owned root as ordinary
  `session/update`s under the child id. New method
  `deepseek/subagent/interrupt {sessionId, childSessionId}` calls
  `ctx.subagents.interrupt`. History replay folds the same start/end info into
  the `_meta` envelope of the parent's `subagent` tool call so a reload
  rebuilds the tile from one page.
- **Plugin.** DTOs, tracker, and mapping live in `sesori_plugin_deepseek`,
  reusing the ACP seams introduced by the Grok chain. `tool_call` for
  `subagent*` opens a `subtask` tile; `started` binds `childSessionID` and
  label; `ended` maps `aborted` to cancelled and `error`, `max-tokens`,
  `refusal` to error. Adapter exit cancels open tiles. The tracker survives the
  per-turn `_liveTools` clear.
- **Busy accounting.** Root busy while any tracked child runs;
  `mainAgentRunning` is `pending > 0`.
- **Scoped stop.** `confirm` rejects with the count and
  `mainAgentOnlySupported: everyRunningChildIsBackground`. `keep` (only when
  supported) sends `session/cancel`. `stop` sends `session/cancel` plus
  `deepseek/subagent/interrupt` per running child; uninterruptible one-shot
  fork jobs are reported honestly in the matrix. On an adapter without v2
  metadata the plugin keeps today's behavior.

### PRs

| Repo | Emoji | Description | Scope |
|---|---|---|---|
| adapter | ⚙️ | `sessions: sub-agent lifecycle notifications and child transcripts` | listeners, child records, `deepseek/subagent`, `_meta` history fold, schema and fixtures, protocol version 2 |
| adapter | ⚙️ | `sessions: per-child interrupt; release v0.1.3` | `deepseek/subagent/interrupt`, schema, version bump, release checksums |
| monorepo | 🚧 | `deepseek: inline subtask tiles and live child sessions` | DTOs, tracker, mapper, history fold, runtime manifest target 0.1.3, ACP seam reuse |
| monorepo | ⚙️ | `deepseek: scoped stop for sub-agents` | `abortSession` override, `interruptSubagent` API, mixed foreground/background policy tests |
| monorepo | 🌱 | `docs: record DeepSeek sub-agent coverage` | matrix footnote ⁹ resolved, regression docs |

### Open questions (probe)

1. Do scoped `subagent/*` emits and child `session/event`s reach a root-context
   listener, or must the adapter register per agent at `newSession` and
   `loadSession`?
2. Ordering of `tool/call(subagent)`, `subagent/start`, `tool/result` for
   foreground versus continuable; can one step open several children before a
   result?
3. Does the parent report idle while a continuable child runs, and does its
   later "subagent reported" turn arrive with no inflight prompt?
4. Protocol version: bump to 2 with the plugin accepting 1 or higher
   (proposed), or detect by notification presence.

## Non-Goals

- Per-child stop from the tile, progress rendering, per-subtask usage.
- Generalizing ACP seams before Grok needs them.
- Migrating Codex children already imported as roots.
- Cursor tile-only rendering, and any work for Copilot, Hermes, Pi, Oh My Pi.
