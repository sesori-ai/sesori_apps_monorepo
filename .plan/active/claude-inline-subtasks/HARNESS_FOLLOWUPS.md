# Inline Sub-Agent Subtasks: Harness Follow-Ups

## Status

- **Plan slug:** `claude-inline-subtasks` (the plan is reactivated under
  `.plan/active` until the four coverage PRs, Codex, Grok Build, DeepSeek,
  and Cursor, merge, then moved back)
- **Plan date:** 2026-09-02
- **Base:** `main` at `6e9028c4c6`
- **Delivery:** PRs titled `<emoji> [claude-inline-subtasks] <description>` with
  no step counters. The four harness chains run in parallel; within a
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
Hermes, Pi, Oh My Pi) are out of scope; their verdicts and versions are
recorded in the capability matrix. Cursor supports a subset (tile and stop
confirmation, no child session or partial stop) and gets that subset.

## Shared Rules

- Backend payloads, DTOs, and lifecycle mapping stay inside the owning plugin
  package. The generic ACP plugin gains exactly five backend-neutral seams,
  introduced by the Grok chain (their first consumer) and reused by DeepSeek
  and Cursor:
  1. `AcpChildSessionTracker`
     (`bridge/sesori_plugin_acp/lib/src/repositories/trackers/acp_child_session_tracker.dart`),
     a Layer-2 tracker with one instance per plugin, constructed at the harness
     composition point (where the plugin builds its mapper) and injected into
     both the mapper and `AcpPlugin` (merged in PR #1270). It is the single
     owner of child lifecycle and has two faces: a push API used only by
     mappers (`spawn`, `appendPrompt`, `finish`, carrying the parent id, child
     id, `isBackground`, `canCancel`, and the terminal state) that returns the
     bridge events to emit (child `session.created`, busy/idle status, the
     `subtask` part), and a snapshot API used only by the plugin
     (`childStatuses`, `busyChildIds`, `runningChildren`,
     `forgetSession(sessionId)`, `clear()`), plus a typed broadcast
     `Stream<AcpChildSessionTrackerChange> changes`; every change carries the
     affected root session id. `AcpPlugin` owns the sole live subscription,
     registers it at composition, and cancels it during teardown; the
     composition owner disposes the tracker with the plugin. The `subtask` part
     requires a prompt, so
     a harness whose spawn event carries none (Grok, Codex) emits the child
     session and its busy status at spawn and renders the tile only once the
     child's own first user message has streamed under the child id; nothing
     is fabricated. The spawn input is sealed: a session-backed child carries
     a required child session id and emits the child session and status,
     while a tile-only task (Cursor) is keyed by its tool call id and emits
     only the tile, with no nullable child id on the session-backed variant;
     the Cursor PR introduces the second variant. Lifecycle ownership is
     keyed by the root: descendants at any depth roll up into the root's busy
     set and cancel targets, while displayed parentage stays direct. On every
     change the
     plugin re-runs `_syncWorkState` (so `PluginWorkState` stays busy and the
     lifecycle service never suspends the process while a child runs) and, when
     a root's idle was deferred and its busy set is now empty, emits that root
     idle; this is how a background child finishing after the parent prompt
     settled releases the root. `AcpPlugin` composes the disjoint union in
     `getSessionStatuses`, defers the root idle in `_finishTurn` while
     `busyChildIds` is non-empty, reports `childSessionIds` in the summary,
     calls the root-scoped `forgetSession(sessionId)` when a root or child is
     deleted (siblings under other roots keep their busy state and cancel
     targets), and calls `clear()` only on process exit. The child directory
     is `directoryForSession(root)`, never the launch directory.
  2. A protected tool-call classification method on `AcpEventMapper` returns a
     sealed `AcpToolCallClassification`: render as a tool card, suppress because
     a lifecycle-derived tile represents the same work, or track a tile-only
     task. The tile-only outcome carries the stable tool call id, prompt,
     agent/description, and observed tool state; the generic standard-update
     path feeds that typed fact into `AcpChildSessionTracker` instead of
     rendering a card. A session-backed tile is still opened only from a
     lifecycle event that carries the child id. Cursor alone uses the tile-only
     outcome because its standard and extension frames share a stable id; that
     keeps one tile per task under concurrent spawns.
  3. The scoped-stop policy, once, in `AcpPlugin.abortSession`: `confirm` with
     running children rejects with the count, `mainAgentRunning = pending > 0`,
     and `mainAgentOnlySupported = every running child isBackground`; `keep`
     sends `session/cancel` only; `stop` sends `session/cancel` plus
     `cancelChild` per cancellable child. Each running child also carries
     `canCancel`; when a non-cancellable child survives a `stop`, the result is
     `PluginAbortAccepted(workKept: true)` and the root stays busy until that
     child finishes, so the partial stop is never reported as complete.
     `interruptActiveWork` uses `stop`.
  4. One abstract backend seam `cancelChild({sessionId, childSessionId})` on
     the per-harness ACP API; Grok and DeepSeek supply only the request shape.
  5. A backend-neutral replay hook: `getSessionMessages` builds history from
     `AcpReplayCollector`, which consumes `session/update` frames into
     `PluginMessageWithParts` and never runs the live mapper. The collector
     therefore accepts a harness-supplied replay projection that turns the
     non-`session/update` notifications replayed by `session/load` into the
     same `subtask` parts and child records the collector materialises. The
     projection owns a replay-local `AcpChildSessionTracker` instance created
     per `getSessionMessages` call; it never touches the live tracker, its
     change-stream subscription, or the event buffer, so reading history cannot
     leave the plugin busy or emit live status transitions. Before the collector
     runs, a harness may have its Layer-3 session service prepare an immutable,
     backend-neutral `AcpReplayContext` through the harness API and repository;
     the pure projection receives that context and performs no data access.
     Grok uses this part of seam 5 to supply child prompts keyed by child id.
     `mapExtension` stays a live-only seam.
  Harness subclasses therefore override payload parsing, tool-call
  classification, `mapExtension`, the replay projection, and `cancelChild`, and
  nothing else.
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
  `session-turns.md`, `projects-and-sessions.md`,
  `plugin-setup-and-lifecycle.md` (work state, safe stop, exit cleanup, and
  idle-reap protection are harness-specific there), and where relevant
  `session-history-and-recovery.md` and `notifications.md`.
- `docs/HARNESS_CAPABILITIES.md` footnotes are corrected as soon as a probe
  verifies or lifts a limitation, not deferred to the coverage PR; cells
  change when the capability ships.

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
  item to `collabToolCall`; 0.148.0 does not carry that shape, so the parser
  accepts only `collabAgentToolCall` and is updated when the pinned release
  changes and a probe confirms the new shape.
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
  closed enums and `unknown` fallbacks (only the 0.148.0 item names).
- **Child sessions.** `CodexThreadRecord.parentId`. Children never emit
  `thread/started` (probe), so a child is learned from the parent's
  `subAgentActivity started` (`agentThreadId`): `CodexAppServerApi.readThread`
  → `CodexThreadRepository` → `CodexSessionService.resolveSubAgentThread`
  reads and maps it (`parentThreadId`, `agentNickname`), and `CodexPlugin`
  emits `Session(parentID: parent, title: nickname ?? agentPath)` and feeds the
  record into the tracker. The catalog maps `thread_source == subagent` rollouts with their parent and
  excludes them from `getSessions` (roots only) while keeping them in
  `listAllSessions`; `getChildSessions(root)` merges catalog children with the
  live spawn map. Children inherit the parent's directory so their events carry
  the parent's project id. Child history reads by thread id; the copied parent
  prefix is trimmed only for rollouts created with `fork_turns: true`
  (detected by the duplicate parent `session_meta`).
- **Tiles.** A per-parent `CodexSubAgentTracker`
  (`repositories/codex_sub_agent_tracker.dart`, beside
  `CodexToolLifecycleTracker`), fed by `CodexPlugin._handleNotification` with
  the mapper rendering from tracker output, as the existing composition does.
  The tracker never performs transport: `subAgentActivity started` records the
  child and emits its session and busy status, and the `subtask` part
  (`messageID` = the activity item id, `childSessionID` = `agentThreadId`,
  description from `agentPath` or the resolved nickname, `taskState` running)
  renders once the prompt is known, because the part requires one and the
  activity item carries none: the child's first `userMessage` item under the
  child thread id supplies it, and when the child streams no such item the
  `thread/read` result (the child's turns) is used instead; the tile PR
  verifies which source 0.148.0 provides. The child's own `turn/completed` completes it, a
  child `turn/interrupt` cancels it, and `thread/closed` cancels it only while
  it is pending or running; a prior completed, failed, interrupted, or errored
  terminal state wins over the later close. A child turn failure errors it,
  and a disconnect cancels open tiles. `collabAgentToolCall` items
  (`wait`, `closeAgent`, ...) and `agentsStates` only refresh the same tile's
  state; `spawnAgent` items and `receiverThreadIds` are not relied on because
  0.148.0 does not emit them. The tracker survives the root's idle transition
  because child completion arrives after the parent `turn/completed`. Replay:
  the parent rollout persists only `sub_agent_activity started`, so
  `CodexSessionService.prepareSessionMessageRead` also reads the catalogued
  child rollouts of that root (`CodexRolloutRepository`) and passes each
  child's terminal state into `projectMessages`, so a reloaded root shows
  completed tiles instead of running ones.
- **Live streaming.** Nothing to route: child items already arrive under the
  child thread id and render once the child session exists.
- **Busy accounting.** The root status stays busy while the tracker holds a
  running child: the idle transition after the root `turn/completed` is
  deferred until the last child completes, interrupts, or closes, so the idle
  reaper and safe stops never kill a running child and the completion push
  fires once. Summary iterates roots; `childSessionIds` are the busy children;
  `mainAgentRunning` is the root's own turn.
- **Scoped stop.** `confirm` with busy children rejects with the count,
  `mainAgentRunning`, and `mainAgentOnlySupported: true` (children survive a
  parent interrupt, probe). `stop` interrupts the root then each busy child
  with the child's `turnId` tracked from its `turn/started`. `keep`
  interrupts the root only and returns `workKept: true`. Busy state and cancel
  targets roll descendants up to the root.

### PRs

| Emoji | Description | Scope |
|---|---|---|
| 🌿 | `codex: parse sub-agent thread and item metadata` | DTO fields, collab/activity parser and enums, fixtures from the probe |
| ⚙️ | `codex: sub-agent threads become child sessions` | `parentID` live and from the catalog, roots-only listing, `getChildSessions`, directory attribution, summary rolls busy children into the root. Fixes the root-leak defect |
| 🚧 | `codex: inline subtask tiles for spawned agents` | tracker, mapper cases, cancel on close/disconnect, replay from rollout if persisted |
| ⚙️ | `codex: scoped stop for sub-agent threads` | policy switch, per-child interrupt, `mainAgentOnlySupported` per probe, `interruptActiveWork` covers children |
| 🌱 | `docs: record Codex sub-agent coverage` | matrix footnote ³ resolved, regression docs |

### Probe results (0.148.0, 2026-09-02, details in `followups/codex-probe.md`)

- Children never emit `thread/started`; a child first appears as
  `thread/status/changed` followed by the parent's `subAgentActivity started`
  (`agentThreadId`, `agentPath`). No `spawnAgent` collab item was emitted, only
  `wait`, and `receiverThreadIds` was empty on every collab item, so the tile
  opens on `subAgentActivity started` and the tracker reads the child through
  `thread/read` (which returns `parentThreadId` and `agentNickname`).
- No `subAgentActivity completed | interrupted` was emitted; child completion
  is derived from the child's own `turn/completed` and idle status.
- A parent interrupt does not stop children, so `keep` is honored and
  `mainAgentOnlySupported` is true for Codex. A child `turn/interrupt`
  requires `turnId`, which arrives on the same connection in the child's
  `turn/started` and is tracked per child.
- Parent rollouts persist the `spawn_agent`/`wait_agent` function calls and
  `sub_agent_activity started` only; child rollouts copy the parent history
  only with `fork_turns: true`. Replay opens tiles from `sub_agent_activity
  started` and closes them from the child rollout's state.
- `thread/list {parentThreadId}` returned nothing; catalog children come from
  rollout metadata.

### Open questions (resolved by the probe unless noted)

1. Resolved: children never emit `thread/started` and `receiverThreadIds` is
   always empty; the child is learned from `subAgentActivity.agentThreadId`
   and read through the API/repository/service chain.
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
- Root and child directories persist in the normal sessions tree. A child's
  `summary.json` carries `session_kind: "subagent"` and `agent_name` but no
  parent id; the root's `updates.jsonl` carries `subagent_spawned` records with
  the parent id, child id, type, and description needed to reconstruct links.

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
  enum and push into `AcpChildSessionTracker` (Shared Rules, seam 1). This
  chain introduces the five shared seams.
- **Tiles.** `subagent_spawned` emits the child session (`parentID` = root,
  title = description, directory = root's) and busy status; the `subtask` part
  (`agent` = subagent type, `childSessionID` = child session id, running)
  renders on the child's first `user_message_chunk`, which carries the prompt
  the spawn notification lacks and arrives under the child id right after
  the spawn (merged in PR #1270 as `appendPrompt`).
  `subagent_progress` is ignored. `subagent_finished` completes, errors, or
  cancels and sets the child idle. Tiles are lifecycle-derived only: if the
  spawn also arrives as a standard `tool_call` for `spawn_subagent`, which
  shares no id with `subagent_spawned`, the Grok mapper suppresses that tool
  card through seam 2, so concurrent spawns cannot duplicate or cross-bind
  tiles.
- **Child history and streaming.** Child `session/update`s flow through the
  existing mapper once the child exists, and `session/load` accepts child ids
  (probe). A root load replays `subagent_spawned` and `subagent_finished` as
  `_x.ai/session/update`, but the spawn still has no prompt and the standard
  `spawn_subagent` call shares no id, so that card stays suppressed. Before the
  collector materialises the root, `GrokSessionService` asks the Layer-2
  `GrokSessionHistoryRepository` (backed only by Layer-1
  `GrokSessionStoreApi`) for immutable replay context containing each
  discovered child's initial `user_message_chunk`, keyed by child id. The pure
  Grok projection receives that context and feeds spawn, prompt, and finish
  into its replay-local tracker. The rebuilt tile is therefore deterministic
  and never depends on description or ordering.
- **Busy accounting.** Through seam 1: root idle is deferred while
  `busyChildIds` is non-empty. `GrokEventMapper` alone parses
  `subagent_finished.will_wake` and recognizes the matching root
  `turn_completed` prompt id `subagent-completed-<child id>`. It translates
  those Grok facts into backend-neutral tracker hold/release operations keyed
  by the root id and an opaque hold id; `AcpChildSessionTracker` knows no Grok
  methods, payload fields, or prompt-id conventions. The hold replaces the
  finishing child, so root status and `PluginWorkState` stay busy during the
  autonomous turn even though no client `session/prompt` increments `pending`;
  releasing it emits the deferred idle. Cancel, delete, disconnect, and
  process exit clear outstanding holds with the rest of tracker state.
- **Children after a restart.** The tracker is process-local and
  `session/list` returns roots only, so `getChildSessions(root)` cannot be
  served from either after a bridge restart, and catalog import calls it for
  every root before any history is opened. A Layer-1 `GrokSessionStoreApi`
  performs the filesystem reads and parses typed DTOs from each root's
  `updates.jsonl` and each child's `summary.json`; a Layer-2
  `GrokSessionCatalogRepository` derives parent-child links from the persisted
  spawn records and returns persisted child sessions only. Layer-3
  `GrokSessionService` depends on that repository and
  `AcpChildSessionTracker`, merges persisted and live children, and is consumed
  by `GrokPlugin.getChildSessions`. Replayed tiles then resolve their
  `childSessionID` to a stored session without looking for a nonexistent parent
  field in the child summary.
- **Scoped stop.** Through seam 3; `GrokAcpApi.cancelChild` sends
  `_x.ai/subagent/cancel {subagentId}` (leading underscore, as probed) with
  the child session id, which the probe showed equals `subagent_id` in every
  frame. `isBackground` comes from the spawn
  payload; if it exposes no background flag and the probe shows a foreground
  child dying with the parent tool call, every child is recorded as
  foreground, so `mainAgentOnlySupported` is false as for OpenCode.

### PRs

| Emoji | Description | Scope |
|---|---|---|
| ⚙️ | `grok: parse sub-agent lifecycle notifications` | DTOs, `GrokEventMapper.mapExtension`, `AcpChildSessionTracker` (seam 1) and the tool-call classification (seam 2), mapper fixtures from the probe |
| ⚙️ | `acp: child sessions keep the root busy` | typed tracker-change stream and owned subscription teardown; `AcpPlugin` composes tracker statuses, idle/wake-up deferral, summary `childSessionIds`, and exit cleanup; `GrokSessionStoreApi` → `GrokSessionCatalogRepository` returns persisted children and Layer-3 `GrokSessionService` merges them with the tracker for `getChildSessions` |
| 🌿 | `grok: child session history` | `session/load` for child ids; seam 5 replay context and pure Grok projection; `GrokSessionStoreApi` → `GrokSessionHistoryRepository` → `GrokSessionService` prepares child prompts |
| ⚙️ | `grok: scoped stop for sub-agents` | policy in `AcpPlugin.abortSession` (seam 3), `cancelChild` seam and its Grok request (seam 4), `interruptActiveWork` uses stop |
| 🌱 | `docs: record Grok Build sub-agent coverage` | matrix footnote ¹⁰ resolved, regression docs |

### Probe results (Grok Build 1.0.5, 2026-09-03, details in `followups/grok-probe.md`)

- Persisted layout (verified while building PR #1272): a child's `summary.json`
  carries `session_kind: "subagent"` and `agent_name` but no parent id;
  parentage lives only in the root's `updates.jsonl` as `subagent_spawned`
  records (`parent_session_id`, `child_session_id`, `subagent_type`,
  `description`). The Grok session catalog derives children from those records
  and reads the child summary for title and times.
- The live method names carry a leading underscore: `_x.ai/session_notification`
  and, on `session/load` replay, `_x.ai/session/update`; the same facts are
  replayed under the latter, so seam 5 feeds that method to `mapExtension`.
- The envelope `sessionId` is the parent; `subagent_id` equals
  `child_session_id`; no background flag and no tool call id are present.
- Child `session/update`s (the child's own prompt, thoughts, tool calls)
  arrive on the same connection under the child id right after
  `subagent_spawned`; `session/load` accepts a child id even while it runs;
  `session/list` returns roots only with no parent marker.
- A standard `spawn_subagent` `tool_call` arrives first with
  `_meta["x.ai/tool"].name`; it shares no id with the lifecycle event and is
  suppressed through seam 2. A background finish with `will_wake: true`
  triggers a wake-up turn without a client prompt.
- A root `session/cancel` cancels foreground and background children alike
  (`subagent_finished {status: cancelled}`), so every Grok child is recorded
  as foreground and `mainAgentOnlySupported` is false. `_x.ai/subagent/cancel
  {subagentId}` cancels one child without touching siblings or the root turn
  and returns `{subagentId, cancelled, outcome: cancelled | already_finished}`.

### Open questions (resolved by the probe)

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

- **Adapter extension (protocol v2, additive; v1 stays frozen).** New
  notification `deepseek/subagent` sealed by `kind`: `started {sessionId,
  childSessionId, toolCallId, label, mode: foreground | background}` and
  `ended {sessionId, childSessionId, stopReason, summary?}` (bounded text of
  the last assistant message). `toolCallId` is required: the probe showed the
  `AsyncLocalStorage` scope around the root `tools/execute` waterfall gives
  every `subagent/start` its executing call id, including parallel calls and
  forks, so there is no uncorrelated variant and no lifecycle-derived tile
  path. Mode derives from the call's `run_in_background` argument with the
  tool defaults; label is the call's `description`. Labels are never used for
  correlation. The adapter also applies the owning root's provider/model
  selection to its descendants through a root-level `agent/request`
  listener, because children inherit `AgentOptions.provider/model`, which
  the adapter never sets, and otherwise fail at once (probe defect). Child
  transcripts: the adapter projects events for every descendant of an owned
  root (ancestry resolved by walking each header's `parentSession`, since a
  grandchild names the child, not the root) as ordinary `session/update`s
  under the child id, while the tile keeps the direct parent. New method
  `deepseek/subagent/interrupt {sessionId, childSessionId}` calls
  `ctx.subagents.interrupt`. History replay: the parent log never names a
  foreground child and parallel calls open overlapping windows, so the
  adapter persists `toolCallId -> childSessionId` in its own session store at
  `subagent/start`, and `history` folds that start/end info into the `_meta`
  envelope of the parent's `subagent` tool call so a reload rebuilds the tile
  from one page without timing-window attribution.
- **Plugin.** DTOs and payload parsing live in `sesori_plugin_deepseek`;
  lifecycle goes through `AcpChildSessionTracker` (seam 1). `started` opens
  the tile keyed by its `toolCallId` and the matching `subagent*` `tool_call`
  card is suppressed (seam 2). `started` binds `childSessionID`, label, and
  `isBackground` from `mode`; `ended` maps `aborted` to cancelled and
  `error`, `max-tokens`, `refusal` to error. Adapter exit clears the
  tracker. Tracker state is independent of the per-turn `_liveTools` clear.
  Replay does not pass through seam 5's notification hook, because
  `DeepSeekHistoryRepository` feeds `session/update` envelopes straight into
  `AcpReplayCollector.consume`: that repository parses the folded `_meta`
  envelope of each `subagent*` tool call itself and hands the resulting
  `subtask` parts to the collector, so the generic collector never learns
  DeepSeek payloads.
- **Busy accounting and scoped stop.** Through seams 1 and 3;
  `DeepSeekAcpApi.cancelChild` sends `deepseek/subagent/interrupt`.
  Uninterruptible one-shot fork jobs are recorded with `canCancel: false`
  and as foreground, so they never make `mainAgentOnlySupported` true, a
  `stop` that leaves one running reports `workKept: true`, and the matrix
  notes they cannot be stopped alone.
- **Adapter version.** `EXTENSION_PROTOCOL_VERSION` becomes 2. The runtime
  manifest raises `targetVersion` and `minPathVersion` to 0.1.3, so an
  explicitly configured or PATH adapter below 0.1.3 is reported by setup as
  needing an update instead of failing at initialization; setup tests cover
  the floor. With the floor raised no flow launches a v1 adapter, so the
  plugin has no v1 fallback path.

### PRs

| Repo | Emoji | Description | Scope |
|---|---|---|---|
| adapter | ⚙️ | `sessions: sub-agent lifecycle notifications and child transcripts` | `subagent/*` and descendant `session/event` listeners, root-level `agent/request` provider/model propagation to descendants, child records, persisted call-to-child correlation, `deepseek/subagent`, `_meta` history fold, schema and fixtures, protocol version 2 |
| adapter | ⚙️ | `sessions: per-child interrupt; release v0.1.3` | `deepseek/subagent/interrupt`, schema, version bump, release checksums |
| monorepo | 🚧 | `deepseek: inline subtask tiles and live child sessions` | DTOs, mapper feeding seams 1 and 2, `_meta` fold parsed in `DeepSeekHistoryRepository`, runtime manifest target and PATH floor 0.1.3 with setup tests; lands after the Grok lifecycle PRs |
| monorepo | ⚙️ | `deepseek: scoped stop for sub-agents` | `DeepSeekAcpApi.cancelChild` (seam 4), mixed foreground/background policy tests through seam 3 |
| monorepo | 🌱 | `docs: record DeepSeek sub-agent coverage` | matrix footnote ⁹ resolved, regression docs |

### Probe results (dsh 0.1.1-rc.2, 2026-09-03, details in `followups/deepseek-probe.md`)

- Root-context listeners receive `subagent/start`, `subagent/end`, and every
  child `session/event`; no per-agent registration is needed.
- Correlation is deterministic: an `AsyncLocalStorage` scope around the root
  `tools/execute` waterfall gives every `subagent/start` the executing call
  id, including two parallel calls in one step and a fork. `started` always
  carries `toolCallId`, so the design has no uncorrelated variant. The label
  is the call's `description` (the descriptor lands after the start event).
- Foreground and fork children run inside the tool call (`tool/result` after
  `subagent/end`); a continuable child returns its `tool/result` within
  milliseconds, the parent reports idle while the child runs, and settlement
  opens a new parent turn through `followup` with no in-flight prompt.
- Adapter defect found: children inherit `AgentOptions.provider/model`, which
  the adapter never sets, so every child failed at once with "has no
  provider/model". The adapter PR applies the owning root's selection to
  descendants through a root-level `agent/request` listener.
- Replay: the parent log never names a foreground child; it is attributed to
  the persisted child header created inside the call window. Continuable
  children are named by the result text and settled from the
  `subagent-settled` notice.

### Open questions (resolved by the probe)

1. Do scoped `subagent/*` emits and child `session/event`s reach a root-context
   listener, or must the adapter register per agent at `newSession` and
   `loadSession`?
2. Ordering of `tool/call(subagent)`, `subagent/start`, `tool/result` for
   foreground versus continuable; can one step open several children before a
   result?
3. Does the parent report idle while a continuable child runs, and does its
   later "subagent reported" turn arrive with no inflight prompt?

## Cursor (cursor-agent 2026.07.23, ACP stdio)

### Verified facts

- A subagent surfaces over ACP as a standard `tool_call` titled `Task: …` with
  `rawInput {_toolName: "task", prompt, description, subagentType}` plus a
  `cursor/task` extension notification `{toolCallId, agentId, subagentType,
  model, durationMs}` that shares the tool call id. No child transcript
  crosses ACP; `session/cancel` is turn-wide and no per-subagent cancel exists.

### Design

- `CursorEventMapper.mapExtension` (existing) parses `cursor/task` into a
  Freezed DTO and pushes the tile-only spawn variant of seam 1 (keyed by
  `toolCallId`, no child session id, `isBackground: false`,
  `canCancel: false`) and the matching finish into `AcpChildSessionTracker`;
  the tile carries no `childSessionID`, so tapping it opens nothing. The design
  branches on the probe's timing verdict: if `cursor/task` fires at start and
  finish, it drives both edges and seam 2 suppresses the matching `Task:` card.
  If it fires only at finish (its payload carries no lifecycle discriminator),
  the standard `Task:` `tool_call` returns seam 2's typed tile-only outcome and
  the generic standard-update path opens the tracker tile from its stable
  `toolCallId`; `cursor/task` closes that same tile. Either way one task is one
  tile, with no mapper override outside the declared seams.
- **Replay.** The implementation starts with a bounded wire probe covering
  live timing, cancel survival, and `session/load`, recorded in
  `followups/cursor-probe.md`. When `cursor/task` replays, the Cursor projection
  joins that extension frame to the persisted `Task:` call by `toolCallId`.
  When only the standard call replays with its stable id, `rawInput`, and
  terminal status, seam 2's typed tile-only outcome reconstructs and settles
  the tile without a generic card. If neither replay shape retains those facts,
  the coverage PR records tile replay as unsupported in footnote ⁵ and keeps
  the honest generic `Task:` history card instead of claiming parity.
- Busy accounting and the scoped stop come from seams 1 and 3 unchanged:
  `confirm` rejects with the count and `mainAgentOnlySupported: false`; `stop`
  is `session/cancel`. No `cancelChild` request exists, so the Cursor API seam
  is a no-op. `workKept` follows seam 3 rather than a constant: it is `false`
  when the turn cancel ends every running task, and `true`, with the root
  kept busy until the task finishes, if the probe shows a background task
  surviving `session/cancel`, since such a task is non-cancellable.

### PRs

| Emoji | Description | Scope |
|---|---|---|
| ⚙️ | `cursor: subtask tiles and stop confirmation for task subagents` | bounded live/replay probe in `followups/cursor-probe.md`; DTO, mapper push, seam 2 tile-only classification, replay projection, and tests; lands after the Grok lifecycle and scoped-stop PRs |
| 🌱 | `docs: record Cursor sub-agent coverage` | tile and child-session matrix rows plus footnote ⁵ updated, regression docs |

### Open questions (probe)

1. Does `cursor/task` fire at start, at finish, or both, and does a background
   subagent survive `session/cancel`?
2. Does `session/load` replay `cursor/task`, and does the persisted standard
   `Task:` call retain the stable id, `rawInput`, and terminal status needed for
   the fallback replay projection?

## Non-Goals

- Per-child stop from the tile, progress rendering, per-subtask usage.
- Generalizing ACP seams before Grok needs them.
- Migrating Codex children already imported as roots.
- Cursor child sessions or partial stops, and any work for Copilot, Hermes,
  Pi, Oh My Pi.
