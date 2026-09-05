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
  package. The generic ACP plugin gains only the backend-neutral seams below,
  each landing with its first production consumer rather than ahead of it:
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
     a lifecycle-derived tile represents the same work, defer a permission-
     gated decision, or track a tile-only task. A Layer-2
     `AcpDeferredToolCallTracker`
     (`bridge/sesori_plugin_acp/lib/src/repositories/trackers/acp_deferred_tool_call_tracker.dart`)
     is constructed at the harness composition point and injected into
     `AcpEventMapper`. For `defer`, that tracker—not the mapper—owns the typed
     standard call by session and tool call id and resolves it from the later
     permission/tool update; denial or cancellation can then emit and
     terminally settle the generic card even when no child is spawned. The
     mapper only classifies each update and delegates the state transition.
     `AcpPlugin` forgets one session's deferred calls on deletion and clears the
     tracker on disconnect and process exit. The tile-only outcome carries the
     stable tool call id, prompt,
     agent/description, and observed tool state; the generic standard-update
     path feeds that typed fact into `AcpChildSessionTracker` instead of
     rendering a card. A session-backed tile is still opened only from a
     lifecycle event that carries the child id. Grok uses `defer` because its
     tool call and child lifecycle share no id; Cursor uses the tile-only
     outcome because its standard and extension frames do. Neither path matches
     by description or arrival order, so concurrent spawns stay deterministic.
  3. The scoped-stop policy, once, in `AcpPlugin.abortSession`: `confirm` with
     running children is side-effect free and rejects with their count,
     `mainAgentRunning = pending > 0`, and `mainAgentOnlySupported` true only
     when every running child is background. For `keep`, when only children are
     running the plugin sends no cancellation and returns
     `PluginAbortAccepted(workKept: true)` for the retained children. When the
     main turn is running but
     `mainAgentOnlySupported` is false, it returns the typed rejection before
     any side effect, so a stale or direct caller cannot silently cancel
     children; otherwise `keep` sends `session/cancel` only. `stop` sends
     `session/cancel` plus `cancelChild` per cancellable child. Each running
     child also carries `canCancel`; when a non-cancellable child survives a
     `stop`, the result is `PluginAbortAccepted(workKept: true)` and the root
     stays busy until that child finishes, so the partial stop is never
     reported as complete. `interruptActiveWork` uses `stop`.
  4. One abstract backend seam `cancelChild({sessionId, childSessionId})` on
     the per-harness ACP API; Grok and DeepSeek supply only the request shape.
  5. A narrow backend-neutral replay replacement hook on
     `AcpReplayCollector`, which consumes `session/update` frames into
     `PluginMessageWithParts` without running the live mapper. A harness
     repository may replace one fully materialized generic tool part with a
     backend-neutral message part using the standard tool-call id. The callback
     receives immutable replay data, performs no I/O, and never reads or mutates
     live trackers, subscriptions, or the event buffer. DeepSeek consumes this
     narrow replacement form: its repository indexes typed metadata from those
     same replayed standard updates, then asks its pure mapper to replace the
     delegation card with one subtask tile. Grok's earlier seam-5 work instead
     uses collector-provided replay context to route historical extension frames;
     it does not use the generic-tool replacement callback. `mapExtension` stays
     live-only for the DeepSeek path.
  Harness subclasses add only the parsing, mapping, and transport overrides
  required by the capability currently being delivered.
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
  `thread/started` (probe), so the event mapper parses the parent's
  `subAgentActivity started` into a typed fact carrying `agentThreadId` and
  `agentPath`. Layer-3 `CodexSessionService` coordinates the rest:
  `CodexThreadRepository` reads/maps the child through
  `CodexAppServerApi.readThread`, a pure `CodexSessionMapper` maps the record
  and root directory/project into the child `Session` and created/status
  events, and the service updates `CodexSubAgentTracker` and returns the
  ordered events. `CodexPlugin` only dispatches the typed fact to the service
  and buffers its returned events; it constructs no session and owns no child
  state. The catalog maps `thread_source == subagent` rollouts with their
  parent and excludes them from `getSessions` (roots only) while keeping them
  in `listAllSessions`; `CodexSessionService.getChildSessions` merges catalog
  children with the live tracker and the plugin delegates to it. Children
  inherit the parent's directory so their events carry the parent's project
  id. Child history reads by thread id; the copied parent prefix is trimmed
  only for rollouts created with `fork_turns: true` (detected by the duplicate
  parent `session_meta`).
- **Tiles.** A per-parent `CodexSubAgentTracker`
  (`repositories/codex_sub_agent_tracker.dart`, beside
  `CodexToolLifecycleTracker`) owns lifecycle state. `CodexSessionService`
  feeds it typed activity/child-turn facts and has `CodexSessionMapper` render
  tracker results as bridge events; the plugin only buffers those returned
  events. The tracker and mapper never perform transport:
  `subAgentActivity started` records the child and emits its session and busy
  status, and the `subtask` part
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
  the parent rollout persists both `spawn_agent` and `sub_agent_activity
  started`, whose activity id equals the function call id. A pure Codex history
  mapper joins them by that id and replaces the generic spawn tool part with
  the one subtask tile in both rollout-tail and full-history projection.
  `CodexSessionService.prepareSessionMessageRead` also reads the catalogued
  child rollouts of that root through `CodexRolloutRepository` and passes each
  child's terminal state into `CodexMessageRepository.projectMessages`, so the
  same projection settles the tile instead of leaving it running. Neither the
  repository nor mapper reads live tracker state; the service supplies the
  required context as data.
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
| ⚙️ | `codex: sub-agent threads become child sessions` | repository/mapper/service child-session flow, `parentID` live and from the catalog, roots-only listing, service-owned `getChildSessions` merge, directory attribution, summary rolls busy children into the root. Fixes the root-leak defect |
| 🚧 | `codex: inline subtask tiles for spawned agents` | service-coordinated tracker, mapper cases, cancel on close/disconnect, call-id replacement of the generic spawn card in rollout-tail and full-history replay, child-rollout terminal join |
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
  cancels and sets the child idle. Tiles are lifecycle-derived only. For the
  earlier standard `spawn_subagent` call, which shares no id with
  `subagent_spawned`, the Grok classifier returns seam 2's deferred outcome
  while permission is pending. `AcpDeferredToolCallTracker` owns the buffered
  call; the mapper delegates the same tool call's permission/tool update to
  resolve it. Approval suppresses it before the lifecycle tile arrives, while
  denial or cancellation emits and terminally settles the generic card because
  no child will exist.
  This never pairs a standard call with a lifecycle event, so concurrent spawns
  cannot duplicate or cross-bind tiles.
- **Child history and streaming.** Child `session/update`s flow through the
  existing mapper once the child exists, and `session/load` accepts child ids
  (probe). A root load replays `subagent_spawned` and `subagent_finished` as
  `_x.ai/session/update`, but the spawn still has no prompt and the standard
  `spawn_subagent` call shares no id. The child-history PR first adds a bounded
  denied/cancelled `session/load` capture. If Grok replays a typed permission
  outcome, `GrokSessionHistoryRepository` includes it in the prepared replay
  context and the replay-local deferred tracker retains the terminal generic
  card. If no outcome is persisted, successful and denied calls cannot be
  correlated safely: replay suppresses every standard spawn card to preserve
  one tile per actual child, and a denied attempt remains visible live but is
  absent after reload. That cosmetic omission is accepted rather than adding
  Sesori-owned persistence for Grok history. Before the collector materialises
  the root, `GrokSessionService` asks the Layer-2
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
| ⚙️ | `grok: parse sub-agent lifecycle notifications` | DTOs, `GrokEventMapper.mapExtension`, `AcpChildSessionTracker` (seam 1), `AcpDeferredToolCallTracker` plus deferred classification and denied/cancelled generic-card retention (seam 2), mapper/tracker lifecycle fixtures including forget/disconnect/exit cleanup |
| ⚙️ | `acp: child sessions keep the root busy` | typed tracker-change stream and owned subscription teardown; `AcpPlugin` composes tracker statuses, idle/wake-up deferral, summary `childSessionIds`, and exit cleanup; `GrokSessionStoreApi` → `GrokSessionCatalogRepository` returns persisted children and Layer-3 `GrokSessionService` merges them with the tracker for `getChildSessions` |
| 🌿 | `grok: child session history` | `session/load` for child ids plus denied/cancelled replay probe; seam 5 replay context and pure Grok projection; `GrokSessionStoreApi` → `GrokSessionHistoryRepository` → `GrokSessionService` prepares child prompts and any persisted permission outcomes |
| ⚙️ | `grok: scoped stop for sub-agents` | policy in `AcpPlugin.abortSession` (seam 3), including side-effect-free unsupported-`keep` rejection and child-only `keep`; `cancelChild` seam and its Grok request (seam 4); `interruptActiveWork` uses stop |
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

## DeepSeek (`sesori-deepseek-acp` 0.1.3 source over dsh 0.1.1-rc.2; release pending)

### Verified facts

- dsh emits `subagent/start` and `subagent/end` under the owning root context;
  child headers retain direct `parentSession`, `origin: "subagent"`,
  `delegationDepth`, and the inherited `cwd`.
- Adapter PRs #13, #14, and #15 are merged. Protocol v2 (source commit
  `d7a48471bf5339793beb0c9e1c1889e63f76ec92`) emits
  `deepseek/subagent` `started {sessionId, childSessionId, toolCallId, prompt,
  label, mode}` and `ended {sessionId, childSessionId, stopReason, summary?}`.
  The normalized presentation prompt is required and bounded to 32,768 Unicode
  scalar values. There is no settlement variant, settlement outcome,
  post-child action, or uncorrelated-start wire shape.
- History replay annotates the enclosing standard ACP delegation update at
  `_meta["sesori.ai/deepseek"].subagent` with prompt, label, mode, optional
  child id, and optional terminal outcome. Its `toolCallId` remains the
  enclosing update's standard field rather than being duplicated in metadata.
  Protocol v1 remains byte-for-byte frozen.
- The same adapter source includes `deepseek/subagent/interrupt`, but the
  monorepo consumes that method only in the separate scoped-stop PR.

### Approved consumer design (delivery split below)

- Typed DeepSeek DTOs parse and validate protocol-v2 lifecycle and replay
  metadata once at the boundary. For protocol v2, `DeepSeekEventMapper`
  suppresses the matching standard `subagent` or `subagent_fork` tool card,
  `DeepSeekDelegationTracker` owns its cross-turn lifecycle correlation, and the
  mapper feeds start/end facts through the shared `AcpChildSessionTracker`;
  child standard updates retain the child session id. Typed tool-call lookup
  carries cross-session ambiguity through standard nested permission routing,
  which cancels rather than falling back to an unrelated active turn. Exact
  title-bearing updates reordered ahead of their call are deferred too, and
  lifecycle frames stay behind an accepted prompt while its frame is writing.
  Protocol v1 retains its generic delegation card because it supplies no
  lifecycle replacement. The protocol has no authoritative settlement
  lifecycle, so DeepSeek creates
  no Grok-style autonomous root hold.
- `DeepSeekHistoryRepository` indexes boundary-validated typed replay metadata
  by the enclosing update's `toolCallId`. A narrow replay-local
  `AcpReplayCollector` replacement callback turns the generic delegation tool
  into one subtask part without reading or mutating live tracker state. Splitting
  its child-owned envelope preserves the order of surrounding ordinary parts;
  every additional parent run gets deterministic storage-safe message and part
  identities.
- `DeepSeekSessionService` merges persisted child rows with direct live tracker
  children, preferring persisted title/time metadata by id. Live descendants
  inherit the tracker's root project before persistence catches up. Live and
  replay tiles stay in the direct parent's transcript, while shared ACP child
  activity rolls up to the owning root. Deleting a parent clears its full tracked
  descendant subtree and leaves process-scoped tombstones against late frames;
  existing disconnect, process-exit, and disposal cleanup owns cancellation and
  releases those tombstones after the old event source drains.
- User-directed release change (2026-09-05): publish adapter 0.1.3 before
  slice 4 merges, using an exact pushed live-consumer commit for conformance.
  Slice 4 removes v1 compatibility and must pin the managed target and minimum
  accepted version to 0.1.3 using verified published checksums before it is ready.
  Replay remains slice 5; scoped interrupt consumption remains a later PR.

### PRs

| Repo | Emoji | Description | Scope |
|---|---|---|---|
| adapter | ⚙️ | `sessions: sub-agent lifecycle notifications and child transcripts` | Merged PR #13 (`0a85fb2`): lifecycle, descendant transcripts, bindings, and protocol v2 |
| adapter | ⚙️ | `sessions: per-child interrupt; release v0.1.3` | Merged PR #14 (`1f839c3`): interrupt contract and package version; release intentionally pending |
| adapter | 🌿 | `protocol: carry sub-agent prompts for tile replay` | Merged PR #15 (`d7a4847`): required normalized prompt in live and replay metadata |
| monorepo | ⚙️ | DeepSeek consumer replacement steps 1–5 below | Replaces oversized PR #1293; slice 4 also pins runtime 0.1.3 |
| adapter | 🌱 | `release: prepare v0.1.3 for the live consumer` | Before slice 4 merge: record its tested commit, human-merge release metadata, tag, publish, and verify assets |
| monorepo | ⚙️ | `deepseek: scoped stop for sub-agents` | Pending: consume interrupt and test mixed modes; runtime pinning moves to slice 4 |
| monorepo | 🌱 | `docs: record DeepSeek sub-agent coverage` | Pending final E2E matrix and plan retirement |

### Consumer replacement series

PR #1293 reached 5,431 changed lines and is superseded at the user's request.
Preserve its complete implementation at `948de715804c7120623f7ff379112f4d65c6adde`
on `claude-inline-subtasks-deepseek-tiles`; extract the following five slices in
order, with one open PR at a time. Do not rewrite or force-push the archived
branch. Count additions plus deletions, including tests, fixtures, codegen, and
plan updates, before publishing each slice. Target about 1,500 lines per PR.

This replaces only the existing consumer step, not the completed original
8-step series or its remaining harness follow-ups. The plan already landed;
record this split with the first slice. The existing release, scoped-stop,
regression-document reconciliation, and final coverage/retirement gates remain
required. Per the 2026-09-05 user request, adapter publication now precedes
slice 4 merge. Its cross-repository conformance uses the pushed live-consumer
commit; final replay and E2E coverage remain separate, uncompleted gates.

1. `⚙️ [claude-inline-subtasks] acp: child lifecycle and request attribution [step 1/5]`
   - About 650 production/test/doc lines plus this split bookkeeping.
   - Shared live child identities, prompt ordering, subtree cleanup, and typed
     permission attribution. No DeepSeek-v2 or replay callback consumption.
   - Expected: correct ACP parentage and permission routing; no database change.
     Verify ACP tests/analyzer and unchanged DeepSeek/Grok consumers.
2. `🌿 [claude-inline-subtasks] deepseek: vendor protocol v2 fixtures [step 2/5]`
   - 1,596 lines: four verbatim v2 files plus integrity tests. This small soft-cap
     overage keeps the authoritative fixture bundle whole, not minified or
     partially vendored solely to lower the displayed diff.
   - Expected: integrity evidence only; no runtime, user-visible, or database
     change. Verify hashes, frozen v1 bytes, and protocol integrity tests.
3. `⚙️ [claude-inline-subtasks] deepseek: parse typed subagent protocol [step 3/5]`
   - About 750–900 lines: API validation, DTOs, generated serializers, and
     conformance coverage. Preserve live initialization gating until step 4.
   - Expected: validated typed boundary data; no tiles or database change.
     Regenerate from source, run conformance tests and DeepSeek analysis.
4. `🚧 [claude-inline-subtasks] deepseek: live subagent tiles and children [step 4/5]`
   - About 1,300–1,500 lines: event mapper, delegation tracker, live-only methods
     of `DeepSeekSubagentMapper`, catalog/service composition, and live tests.
     Update existing test constructors together; defer replay methods and
     unrelated formatting churn to step 5.
   - Expected: protocol-v2 live tiles and child sessions; no schema change.
     Verify lifecycle/correlation/catalog regressions and DeepSeek analysis.
5. `⚙️ [claude-inline-subtasks] deepseek: replay child tiles with stable identities [step 5/5]`
   - About 800–1,100 lines: required shared replay callback and all call sites,
     history projection, mapper replay methods, identity tests, and remaining
     consumer regression/capability documentation.
   - Expected: live/replayed tile convergence and ordered storage-safe history;
     no schema migration. Verify ACP and DeepSeek replay tests and analysis.

These delivery boundaries preserve intended behavior and valid review fixes,
not the archived implementation verbatim. The user authorizes meaningful
simplification and correctness improvements within each slice. Keep ownership
clear and the diff near its budget; do not add state, compatibility layers, or
abstractions solely to make a slice stand alone. Verify the assembled consumer
against the required behavior rather than requiring byte-for-byte source parity.

### Probe results (dsh 0.1.1-rc.2, 2026-09-03, details in `followups/deepseek-probe.md`)

- Root-context listeners receive `subagent/start`, `subagent/end`, and every
  child `session/event`; no per-agent registration is needed.
- Correlation is deterministic: an `AsyncLocalStorage` scope around the root
  `tools/execute` waterfall gives every `subagent/start` the executing call id
  and typed arguments, including two parallel calls in one step and a fork.
  `started` always carries `toolCallId` and the exact call's prompt, so the
  design has no uncorrelated or prompt-less variant. The label is that call's
  `description` (the descriptor lands after the start event).
- Foreground and fork children run inside the tool call (`tool/result` after
  `subagent/end`); a continuable child returns its `tool/result` within
  milliseconds, the parent reports idle while the child runs, and settlement
  opens a new parent turn through `followup` with no in-flight prompt. Its
  `subagent-settled` notice names the child through `senderSessionId`, providing
  the deterministic child-to-settlement-turn link.
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
| ⚙️ | `cursor: subtask tiles and stop confirmation for task subagents` | bounded live/replay probe in `followups/cursor-probe.md`; DTO, mapper push, seam 2 tile-only classification, replay projection, and stop-policy tests including unsupported `keep`; lands after the Grok lifecycle and scoped-stop PRs |
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
