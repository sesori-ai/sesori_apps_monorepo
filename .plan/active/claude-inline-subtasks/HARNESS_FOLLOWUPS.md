# Inline Sub-Agent Subtasks: Harness Follow-Ups

## Status

- **Plan slug:** `claude-inline-subtasks` (the plan remains under
  `.plan/active` until the Codex, Grok Build, DeepSeek, and Cursor coverage
  gates are reconciled or explicitly accepted; a docs PR does not close a
  blocked live gate)
- **Plan date:** 2026-09-02
- **Base:** `main` at merged Grok child-cancel envelope repair `2ebcc7d01a`
  (#1429).
- **Delivery:** one open PR at a time, following current repository rules.
  Grok Step 6/7 merged under its exact title. Corrected actual-plugin coverage
  passed its executed stop, lifecycle, replay, and runtime-reuse scope; live
  permission coverage remains unexecuted because no request surfaced. Phone
  setup reached a healthy source build and relay connection, but UI automation
  was blocked before any visible case. Step 7/7 records that partial matrix and
  keeps the phone gate open. Codex has nine steps: merged metadata,
  child-session, historical prompt preparation, and cleanup remain steps
  1/9–4/9. Native rollout facts are
  step 5/9, live/replay tile integration 6/9, lifecycle coverage 7/9, scoped
  stop 8/9, and coverage 9/9. Step 8 merged as PR #1421 at `77165f784f`;
  Step 9 merged as PR #1424 at `b945755bfe` after actual-plugin policy QA
  passed against managed 0.153.4. Historical
  PR titles are unchanged. Progress is tracked in
  `TRACKER.md` "Harness Follow-Ups". The DeepSeek phone handoff is recorded in
  `followups/deepseek-phone-qa.md`; desktop remains deferred.

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
  2. `AcpEventMapper.isSubagentSpawnToolCall` is the current narrow live
     classifier: exact backend metadata may suppress a generic card when a
     lifecycle-derived tile owns presentation. Grok uses this because its
     standard call and child lifecycle share no id. No deferred permission
     tracker or permission-outcome model exists; a denied Grok generic card may
     be absent after replay. Replay has a separate typed suppression callback,
     while DeepSeek's existing nullable replacement callback keeps null meaning
     “retain generic.” Cursor's future tile-only mapping must land with its own
     production need rather than prebuilding unused classification machinery.
  3. The scoped-stop policy, once, in `AcpPlugin.abortSession`: `confirm` with
     running children is side-effect free and rejects with their count,
     `mainAgentRunning` from pending prompts or an active named child, and `mainAgentOnlySupported` true only
     when every running child is background. For `keep`, when only children are
     running the plugin sends no cancellation and returns
     `PluginAbortAccepted(workKept: true)` for the retained children. When the
     main turn is running but
     `mainAgentOnlySupported` is false, it returns the typed rejection before
     any side effect, so a stale or direct caller cannot silently cancel
     children; otherwise `keep` sends `session/cancel` only. Current atomic
     opt-in `stop` either invokes declared complete native authority or snapshots
     and fans out named plus exact child targets; released-client opt-out keeps
     root/named cancellation and client fanout. Outcomes are typed; no
     `canCancel` field is invented. Foreground children
     are covered by cancellation of their parent; directly targeting a child
     with no effective interrupt retains that child without cancelling siblings.
     `workKept` means retained work, not pending lifecycle delivery. Unknown-child
     responses do not fabricate either retained work or terminal state.
     `interruptActiveWork` uses `stop` and waits for authoritative lifecycle.
  4. Closed `AcpScopedStopCapability` plus a typed `AcpPlugin.cancelChild`
     hook matches current composition. `unsupported` is the standard ACP default,
     `perChildSnapshot` selects exact-child fanout for Grok, and
     `completeNativeAtomic` declares DeepSeek's complete native subtree authority.
     Other ACP harnesses keep existing behavior until their transport seam lands. A child with a
     bridge-owned standard prompt uses `session/cancel`, not its former ancestry.
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

## Codex (codex-cli 0.153.4, app-server v2)

### Verified facts

- `multi_agent` is stable. Thread objects carry `parentThreadId`,
  `agentNickname`, `agentRole`, `threadSource` (`subAgent`,
  `subAgentReview`, `subAgentCompact`, `subAgentThreadSpawn`, ...).
  `thread/list` accepts `sourceKinds` and `parentThreadId`.
- Current 0.153.4 persisted activity is nested under
  `event_msg/item_completed/item/SubAgentActivity`; its item id exactly
  matches the preceding `spawn_agent.call_id`. Live app-server activity uses
  `subAgentActivity` with `agentThreadId` and `agentPath`. Historical 0.148.0
  probes also observed `collabAgentToolCall` wait items, but those empty
  receiver/state fields are not current tile identity or lifecycle authority.
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

- Thread and rollout metadata preserve direct parent identity. The catalog
  keeps children out of root lists while exposing them under their direct
  parent, and the service merges persisted and live children.
- `CodexSubAgentTracker` owns ancestry, exact call-correlated tile lifecycle,
  recursive descendants, root busy roll-up, and deferred idle. Current
  `event_msg/item_completed/item/SubAgentActivity` facts replace only the
  matching parent-local generic `spawn_agent` card.
- `CodexPlugin.abortSession` applies side-effect-free scoped preflight, exact
  named-thread `keep`, and full per-thread snapshot fanout. Every accepted ACK
  remains `subAgentsHandled: false` because Codex has no atomic subtree stop.
- Active summaries keep named/root work distinct from busy descendants and
  child pending input, while authoritative native notifications settle state.
- Bounded [actual-plugin policy QA](followups/codex-plugin-qa.md) on
  2026-09-10 used `CodexPlugin.composed`, production WebSocket transport,
  managed 0.153.4, and only owned `/tmp` work. Root and named-child confirmation
  had zero effects and exact counts; root `keep`, named-child subtree stop, and
  root full stop preserved their scope. Every selected target produced
  `turn_aborted`; full-stop targets became non-busy in plugin status. After root
  `keep`, its own turn stopped but effective root status stayed busy for retained
  descendants. The runtime survived each case; every
  atomic-opt-in accepted response retained `subAgentsHandled: false`. Executed
  policy scope passed. Live matrix remains partial because no pending input
  surfaced; that case is unexecuted live and remains covered by focused
  automation.

### Design

- **Boundary parsing.** `CodexThreadDto` and the rollout session-meta DTO gain
  the parent, nickname, role, source, and agent-path fields. A new Freezed
  parser yields sealed `CodexCollabItem` (`spawnAgent`, `wait`, `closeAgent`,
  `sendInput`, `resumeAgent`, `unknown`) and `CodexSubAgentActivity` with
  closed enums and `unknown` fallbacks at the current boundary.
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
  renders from child-owned rollout input when a valid plaintext `NEW_TASK`
  payload exists. On the normal encrypted 0.153.4 path, it uses only the exact
  nonblank `message` from the `spawn_agent` call whose call id matches the
  activity id. This user-approved fallback is delegated task text, not a parent
  `user_message`; parent history, task names, child order, and timing are never
  prompt provenance. `thread/read(includeTurns: false)` remains metadata-only.
  The child's own `turn/completed` completes it, a
  child `turn/interrupt` cancels it, and `thread/closed` cancels it only while
  it is pending or running; a prior completed, failed, interrupted, or errored
  terminal state wins over the later close. A child turn failure errors it,
  and a disconnect cancels open tiles. Historical `collabAgentToolCall`
  wait/state fields are not relied on. The tracker survives the root's idle
  transition because child completion arrives after the parent
  `turn/completed`. Replay: the current parent rollout persists `spawn_agent`
  plus `event_msg/item_completed/item/SubAgentActivity`, whose item id equals
  the function call id. A pure Codex history
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
- **Scoped stop.** `confirm` with running descendants rejects before effects
  with the exact count, named-thread `mainAgentRunning`, and
  `mainAgentOnlySupported: true`. `keep` interrupts only a running named
  thread. `stop` initiates exact interrupts for the named thread plus every
  active or pending-input descendant in the immutable known scope, including
  pending admissions whose `turnId` arrives later; ancestors and siblings are
  excluded. The 0.153.4 probe proves each interrupt is exact-thread, not atomic
  subtree authority, so every accepted result reports
  `subAgentsHandled: false` and retains client fallback.

### PRs

| Step | Emoji | Description | Scope |
|---|---|---|---|
| 1/9 | 🌿 | `codex: parse sub-agent thread and item metadata` | Merged historical title unchanged; DTO fields, collab/activity parser and enums, fixtures from the probe |
| 2/9 | ⚙️ | `codex: sub-agent threads become child sessions` | Merged historical title unchanged; repository/mapper/service child-session flow, roots-only listing, and busy-child summaries |
| 3/9 | ⚙️ | `codex: parse typed child prompts from thread reads [step 3/6]` | PR #1387 merged under this historical title; preparation superseded by 0.153.4 evidence |
| 4/9 | 🌿 | `codex: remove obsolete child-prompt cache [step 4/7]` | PR #1396 merged at `7f6fb8cb50`; metadata-only `thread/read`, no discarded cache |
| 5/9 | ⚙️ | `codex: parse native rollout facts for sub-agent tiles [step 5/9]` | PR #1398 merged at `d801d722f2`; typed DTOs and repository facts only, no tile activation |
| 6/9 | 🚧 | `codex: integrate live and replay tiles [step 6/9]` | PR #1399 merged at `db2b71134d`; full live/replay production integration, lifecycle, busy accounting, focused tests, and behavior docs |
| 7/9 | 🌿 | `codex: cover live tile lifecycle [step 7/9]` | PR #1420 merged at `ae2a9297e3`; write-path/lifecycle regressions and documentation |
| 8/9 | ⚙️ | `codex: scoped stop for sub-agent threads [step 8/9]` | PR #1421 merged at `77165f784f`; per-thread policy, pending-admission fencing, and automated isolation/failure coverage |
| 9/9 | 🌱 | `docs: record Codex sub-agent coverage [step 9/9]` | PR #1424 merged at `b945755bfe`; managed-0.153.4 actual-plugin scoped-stop policy QA passed; pending-input live case unexecuted |

### Probe results (0.148.0 and 0.153.4; details in `followups/codex-probe.md`)

- Current 0.153.4 rollouts persist activity as
  `event_msg/item_completed/item/SubAgentActivity`; its item id equals the
  matching `spawn_agent.call_id`. Normal child input is an encrypted
  `response_item/agent_message` after `inter_agent_communication_metadata`,
  while `thread/read` exposes no initial child user item. Existing rollout
  tails observe the append; no watcher or timer is added.
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
- Current parent rollouts persist `spawn_agent`/`wait_agent` function calls
  and nested `event_msg/item_completed/item/SubAgentActivity`; child rollouts
  copy parent history only with `fork_turns: true`. Replay opens tiles from the
  nested activity item and closes them from the child rollout's state.
- `thread/list {parentThreadId}` returned nothing; catalog children come from
  rollout metadata.

### Open questions (resolved by the probe unless noted)

1. Resolved: children never emit `thread/started` and `receiverThreadIds` is
   always empty; the child is learned from `subAgentActivity.agentThreadId`
   and read through the API/repository/service chain.
2. Resolved on 0.153.4: parent interrupt leaves direct and nested children
   running. Exact child interrupt works with the child `turnId` received on the
   same connection and leaves sibling/grandchild work untouched.
3. Resolved for current shape: parent rollouts persist
   `event_msg/item_completed/item/SubAgentActivity`; child rollouts still copy
   parent history only when forked.
4. Existing bridge-originated children already sit in users' lists as roots.
   Proposed: accept the re-parenting on the next catalog import; no migration.

## Grok Build (1.0.5, ACP stdio)

### Verified facts (native 1.0.5 probes)

- Extension notification `_x.ai/session_notification` wraps internally tagged
  `subagent_spawned`, `subagent_progress`, and `subagent_finished` updates.
  Captured lifecycle carried exact parent/child ids and `will_wake`, but no
  background flag or task-background/task-completion lifecycle variants.
- Extension request `_x.ai/subagent/cancel` takes exact `subagentId`. The probe
  established exact child isolation; it did not establish nested-depth support.
- `session/cancel` on the root cancels foreground and background children on
  the ACP seam Sesori drives. Main-agent-only stop is therefore unsupported.
- Root and child directories persist in the normal sessions tree. A child's
  `summary.json` carries `session_kind: "subagent"` and `agent_name` but no
  parent id; the root's `updates.jsonl` carries `subagent_spawned` records with
  the parent id, child id, type, and description needed to reconstruct links.

### Current plugin

- `GrokEventMapper` parses both Grok lifecycle methods into the shared
  `AcpChildSessionTracker`; children render live, roll into root activity, and
  survive restart through the persisted catalog chain.
- `GrokSessionStoreApi` already reads typed session summaries/updates for
  catalog recovery. It never reads credential or configuration files.
- Scoped stop uses ACP-owned policy and immutable snapshot fanout. Exact child
  cancellation stays behind Grok API → control repository → session service →
  plugin layers. After ACP transport unwraps JSON-RPC, the Grok API requires the
  native application `{result: child outcome}` envelope and returns its existing
  inner DTO; the repository's identity/outcome policy is unchanged. Native ACKs
  never settle lifecycle. History uses inherited ACP `session/load` plus
  extension-aware root projection without a second transport.
- Corrected Grok 1.0.5 production-composition QA after PR #1429 passed
  active-root keep rejection, named-child isolation, idle-child retention and
  autonomous wake-up, already-finished handling, root full-stop fanout and
  settlement, exact root/child replay, fresh-session checks, and runtime reuse.
  Root confirmation reuses its earlier passing run. Zero standard permission
  requests surfaced under unchanged configuration, so live permission behavior
  remains unexecuted and no question channel is claimed. Source phone and relay
  setup was healthy, but `mobile-mcp` could not start WebDriverAgent before any
  visible case; no phone behavior is claimed.

### Design

- **Ownership.** `GrokEventMapper extends AcpEventMapper` overrides
  `mapExtension`; Freezed DTOs parse snake_case payloads into a sealed
  `GrokSubagentUpdate` and push into the existing `AcpChildSessionTracker`.
  History adds only an extension-aware ACP replay collector plus typed immutable
  context preparation; child tracking, busy ownership, generic replay
  replacement, and scoped-stop policy seams already exist.
- **Tiles.** `subagent_spawned` emits the child session (`parentID` = root,
  title = description, directory = root's) and busy status; the `subtask` part
  (`agent` = subagent type, `childSessionID` = child session id, running)
  renders on the child's first `user_message_chunk`, which carries the prompt
  the spawn notification lacks and arrives under the child id right after
  the spawn (merged in PR #1270 as `appendPrompt`).
  `subagent_progress` is ignored. `subagent_finished` completes, errors, or
  cancels and sets the child idle. Tiles are lifecycle-derived only. The exact
  typed `_meta["x.ai/tool"].name == spawn_subagent` classifier suppresses the
  generic card; there is no tool-call/lifecycle id join, deferred permission
  tracker, description matching, or ordering correlation. Denied generic-card
  replay may therefore be absent; native denial persistence remains unverified.
- **Child history and streaming.** Child ids use inherited `session/load` and
  replay their own standard prompt/tool/text stream. For root replay,
  `GrokSessionStoreApi` preserves typed persisted records in file order;
  `GrokSessionHistoryRepository` uses each exact spawned child's first child-owned
  user-message run only when that run is nonblank; `GrokSessionService` resolves
  the canonical directory and returns immutable context; and pure
  `GrokSessionReplayCollector` inserts/settles deterministic tiles without reading
  live state. Unknown non-user updates end the first run. A blank or missing first
  run produces no tile, and later runs never substitute. Both Grok lifecycle
  methods are consumed through the existing post-response quiet drain. No
  permission outcome, persistence, or deferred machinery is implemented.
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
- **Scoped stop.** Through seam 3; `GrokAcpApi.cancelSubagent` sends
  `_x.ai/subagent/cancel {subagentId}` (leading underscore, as probed) with
  the child session id, which equalled `subagent_id` in every captured frame.
  Lifecycle exposes no background flag, so every child is recorded as
  foreground and active-root main-agent-only stop is unsupported. Current
  clients get root-first cancellation plus every exact running-child request
  from one pre-mutation snapshot; all futures are constructed before failures
  are observed. This is non-atomic and reports `subAgentsHandled: false`.
  `cancelled` and `already_finished` are non-retained outcomes; lifecycle alone
  settles tracker state. Released-client `useAtomicStop: false` stays root-only.

### PRs

| Emoji | Description | Scope |
|---|---|---|
| ⚙️ | `grok: parse sub-agent lifecycle notifications` | Historical original title unchanged (now step 1/7); DTOs, `GrokEventMapper.mapExtension`, `AcpChildSessionTracker`, exact metadata-based generic spawn suppression, and lifecycle cleanup |
| ⚙️ | `acp: child sessions keep the root busy` | Historical original title unchanged (now step 2/7); typed tracker-change stream and owned subscription teardown, persisted children, and Layer-3 catalog/live merging |
| 🚧 | `grok: child session history [step 3/6]` | Historical title unchanged (now step 3/7); full root/child replay production, generated DTOs, essential ACP and Grok integration/regression coverage, and supported-behavior docs |
| 🌿 | `grok: cover child session history [step 4/6]` | Historical title unchanged (now step 4/7); PR #1427 merged at `4d0d8de7e3`; collector/repository/service regressions and documentation |
| ⚙️ | `grok: scoped stop for sub-agents [step 5/6]` | PR #1428 merged at `3934f32ec9`; historical title unchanged (now step 5/7); ACP policy/atomic-authority split, root-first non-atomic snapshot fanout, and typed layered child cancellation |
| 🌿 | `grok: decode child-cancel response envelope [step 6/7]` | PR #1429 merged at `2ebcc7d01a` under exact title; required typed native application envelope, inner DTO unchanged, malformed/identity/outcome regressions, and no flat-format fallback |
| 🌱 | `docs: record Grok sub-agent coverage [step 7/7]` | Current reconciliation: actual-plugin executed scope passed; permissions unexecuted; phone gate infrastructure-blocked before visible UI |

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
  as foreground and `mainAgentOnlySupported` is false. `_x.ai/subagent/cancel`
  with `{subagentId}` cancels one child without touching siblings or the root
  turn. Its JSON-RPC response is structurally `result -> result ->
  {subagentId, cancelled, outcome}`: after generic transport unwraps the outer
  result, Grok's application envelope still contains required `result`.
- Bounded actual-plugin QA after PR #1429 passed the corrected executed scope:
  active-root `keep` rejection with no effect, exact named-child isolation,
  idle-child retention through autonomous wake-up, both child-cancel outcomes,
  root-first full-stop fanout, authoritative lifecycle/plugin settlement, exact
  root/child replay, fresh-session checks, and runtime reuse. Root `confirm`
  reuses its earlier passing actual-plugin result. Zero standard permission
  requests surfaced, leaving permission preservation/isolation/cleanup
  unexecuted; no question support is claimed.
- Phone setup verified the source build, bridge, and relay path, but
  `mobile-mcp` timed out starting WebDriverAgent 0.0.23 before any visible UI
  interaction, including after reinstalling the agent only on the owned
  simulator. Every phone case is blocked and unexecuted, not a product failure.
  Owned resources were cleaned; protected resources were untouched. No phone
  stop, history, read-only child, notification, or push QA is claimed.

### Open questions (resolved by the probe)

1. Exact JSON of the three notifications; is the envelope `sessionId` the
   parent; is `subagent_id` equal to `child_session_id`; is a background flag
   present?
2. Do child `session/update`s arrive on the same connection under the child id,
   starting with the child's prompt?
3. Do `session/load` and `session/list` accept or return child ids with a
   parent marker?
4. Fate of a foreground child on `session/cancel`; response shape of
   `_x.ai/subagent/cancel` and the resulting `subagent_finished` status.
5. Is `spawn_subagent` also surfaced as a standard `tool_call`; does a
   background finish trigger a wake-up turn?

## DeepSeek (`sesori-deepseek-acp` 0.1.3 over dsh 0.1.1-rc.2)

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
- Adapter 0.1.4 owns atomic subtree cancellation and emits ordered
  `deepseek/input/cancel`. The bridge consumes its frozen additive contract in
  step 4/5, then moves full stop policy to existing ACP ownership in step 5/5.

### PRs

| Repo | Emoji | Description | Scope |
|---|---|---|---|
| adapter | ⚙️ | `sessions: sub-agent lifecycle notifications and child transcripts` | Merged PR #13 (`0a85fb2`): lifecycle, descendant transcripts, bindings, and protocol v2 |
| adapter | ⚙️ | `sessions: per-child interrupt; release v0.1.3` | Merged PR #14 (`1f839c3`): interrupt contract and package version; release completed through PR #16 |
| adapter | 🌿 | `protocol: carry sub-agent prompts for tile replay` | Merged PR #15 (`d7a4847`): required normalized prompt in live and replay metadata |
| monorepo | ⚙️ | Completed live/replay consumer steps 1–5 below | Merged #1298/#1301/#1304/#1306/#1317; distinct from the native-stop series |
| adapter | 🌱 | `release: prepare v0.1.3 for the live consumer` | PR #16 merged at `3976bcd`; v0.1.3 published with all six package/checksum checks passing |
| monorepo | ⚙️ | `[claude-inline-subtasks] DeepSeek scoped sub-agent stops [step 1/2]` | #1346 merged at `2cc1485d7c`; historical title retained |
| adapter | 🚧 | `[claude-inline-subtasks] DeepSeek atomic subtree cancellation [step 2/3]` | #17 merged at `5eecdf68a3`; historical title retained |
| adapter | 🌱 | `release: prepare v0.1.4 for atomic-stop consumer` | #18 merged at `e2ea207f21`; v0.1.4 and six archives verified |
| monorepo | ⚙️ | `[claude-inline-subtasks] DeepSeek native stop contract and input ordering [step 4/5]` | Frozen native corpus, ordered input cancel, initialize floor, target and digests; no stop-policy change |
| monorepo | 🚧 | `[claude-inline-subtasks] DeepSeek completes ACP-owned scoped stop [step 5/5]` | Replace direct-child fanout with complete native authority at the existing ACP owner |
| monorepo | 🌱 | `docs: record DeepSeek sub-agent coverage` | Pending final E2E matrix and plan retirement |

### Scoped-stop replacement

The [replacement design](followups/deepseek-stop-replacement.md) fixes both slices' ownership and compatibility flow.
PR #1356 closed without merge; its former step 4/4 is superseded. Step 4/5
lands only the verified native contract/input consumer and keeps current scoped
stop behavior. Step 5/5 will use one ACP-owned operation, native atomic authority,
and no residual-ID handshake or new long-lived state. Final phone/desktop E2E
remains user-owned; finish DeepSeek before Codex. Automatic managed-runtime upgrade
machinery remains outside this series.

### Completed live/replay consumer series (historical)

PR #1293 was replaced by merged PRs #1298, #1301, #1304, #1306, and #1317.
The original slice boundaries below use their historical 1/5–5/5 numbering;
these are not the current native-stop steps 4/5 (#1363) and 5/5.
The complete source remains at `948de715804c7120623f7ff379112f4d65c6adde`
on `claude-inline-subtasks-deepseek-tiles`; do not rewrite or force-push it.

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
