# Claude Inline Sub-Agent Subtasks: Tracker

## Current State

- **Plan slug:** `claude-inline-subtasks`
- **Implementation base:** `main` at `86ccc283fb`
- **Series state:** Steps 1/8 to 5/8 merged; Step 6/8 (scoped stop) in PR
  (branch `claude-scoped-stop`)
- **Next action:** merge Step 6/8, then Step 7/8 (regression docs)
- **Pinned facts source:** `PLAN.md` "Claude Code CLI 2.1.237 facts" plus the
  Step 3 capture below (CLI 2.1.257); the completed
  `claude-code-plugin/PROTOCOL.md` is historical and is not edited

## Locked Decisions

- [x] Reuse `MessagePartType.subtask`; no new part type or SSE event.
- [x] `state` on a subtask part is the subtask's own lifecycle when present;
  OpenCode keeps `null` and the child-status fallback.
- [x] Add `cancelled` to both tool-status enums; older clients degrade to
  `unknown`.
- [x] Add nullable `childSessionID` to both part models; bridge translates
  backend → bridge ids at the existing two seams.
- [x] Sub-agent transcripts become child sessions `agent-<agentId>` under the
  root; nested agents flattened; legacy flat layout excluded.
- [x] Complete sub-agent frames are routed to child sessions; no
  `--forward-subagent-text`.
- [x] Running tasks keep the Claude session alive: `ClaudeSessionService`
  tracks `runningTaskIds` per session from typed task frames (every
  `task_type`) and folds them into busy status, plugin work state, the
  active-work set, and the idle gate/reap, so the idle reaper and safe stops
  never kill a running sub-agent; dispatch mode is unchanged. (User review
  2026-08-22: the idle process reaper had not been considered.)
- [x] Stop is scoped (Step 6, user direction 2026-08-22): a dedicated
  `AbortSessionRequest { sessionId, subAgents: confirm | keep | stop }`
  (`@Default(stop)` for older clients); Claude refuses `confirm` with a 409
  `SessionAbortRejection { runningSubAgentCount, mainAgentRunning }` while
  typed sub-agents run, `keep` interrupts without teardown so resident tasks
  continue (interrupt window owned by `ClaudeSessionProcessRepository`),
  `stop` is today's interrupt + teardown; `SessionRepository.abortSession`
  maps policy/result in Layer 2; `SessionAbortService` clears the pending
  abort mark for `rejected`/`keep`; the client probe is side-effect free and
  the dialog mirrors `session_force_dialog.dart`. Until Step 6, abort keeps
  today's mechanics and sub-agents surface as `cancelled`.
- [x] Open subtask parts are swept to `cancelled` only when the root is idle
  (the busy-while-tasks-run rule already protects live sub-agents); no
  child-status lookup in the sweep.
- [x] `ClaudeEventDispatcher` (over the tracker task map) is the sole owner of
  task state, child-session statuses, resident task ids, and `childSessionIds`
  (presentation state); `ClaudeSessionService` gains no presentation field —
  its separate lifecycle `runningTaskIds` set is a distinct, already-locked
  structure (see the running-tasks decision above). `ClaudePlugin` forwards
  the disjoint union of root and child statuses; the dispatcher constructs the
  child session and emits created/status/part in order on the first
  agent-id-bearing signal (`task_started` or an agent-id tool result), with
  the root directory passed as data via `beginTurn`.
- [x] `ClaudeHistoryMapper.map(..., residentTaskToolUseIds)` owns the replayed
  running→cancelled downgrade; the composition root passes data only.
- [x] `ClaudePlugin._handleProcessEvent` owns process-exit cancellation through
  `ClaudeEventDispatcher.cancelTasks`; delete/dispose call the same.
- [x] One `ClaudeTaskStatus` enum, one `toPluginToolStatus()` mapping, and one
  `<task-notification>` parser (`ClaudeMappedTaskNotificationContentBlock` in
  `ClaudeContentMapper`) serve both live and replay paths.
- [x] Child enumeration splits dumb reads (`ClaudeTranscriptApi.readSubagentMeta`
  → `ClaudeSubagentMetaDto`, `deleteDirectory`) from catalog decisions
  (`ClaudeTranscriptCatalogRepository`, `ClaudeSessionRecord.parentId`).
- [x] No analytics, no tasks-bar change, no `task_progress` rendering.
- [x] Step 3 implementation refinements (recorded 2026-09-01, code is truth):
  the `<task-notification>` parser is `ClaudeTaskNotification.tryParse` in
  `models/`, called by `ClaudeContentMapper` (typed block) and directly by
  `ClaudeSessionService` on raw user text the way `_trackWakeupSchedule`
  already reads raw tool_use blocks — the service gains no
  `ClaudeContentMapper` dependency; `_SessionTurnState.hasWork` is the one
  "work in flight" predicate; the history mapper replays task lifecycle
  through a fresh `ClaudeToolTracker` so terminal precedence has one
  implementation, and `ClaudeTrackedTool.toPart` is the one subtask/tool part
  builder; a subtask part is first emitted when its input names
  `description` and `prompt` (the assistant frame or `content_block_stop`),
  never with placeholder text; completion `output` prefers the envelope's
  `<result>` over `<summary>` (the system frame has only `summary`, which
  carries the result text); `deleteSession`/dispose rely on the teardown's
  `ClaudeSessionProcessExited` reaching `cancelTasks` instead of a second
  call; `childSessionStatuses` and `isTurnRunning` land with their first
  consumer in Step 4.
- [x] Step 4 implementation refinements (recorded 2026-09-01, code is truth):
  the `agent-<agentId>` id rule has one owner, `ClaudeSubagentSessionId`
  (`models/`), used by the tracker, the catalog, and the plugin;
  `ClaudeSubagentMetaDto` is a Freezed DTO with tolerant converters (the
  bridge workspace forbids manual JSON parsing); `ClaudeTranscriptApi` gains
  `readSubagentMeta`, `deleteDirectory`, and the `subagentMetaPath` rule;
  child records reuse the root's `cwd`/branch/version and take `createdAt`
  from the meta file's mtime; `getChildSessions` is a catalog scan filtered by
  `parentId` (no live-only children — the CLI writes the child transcript at
  spawn); a live child `PluginSession` carries `time: null`, like a
  transcript-derived root with no timestamps; `ClaudeHistoryMapper.map`
  takes `agentId` for child mode (records attributed by `agentId`, since
  sub-agent records carry the parent's session id and `isSidechain: true`);
  the dispatcher announces a child on the first agent-id-bearing update and
  emits its idle status on the same update when it is already terminal
  (foreground agents appear at completion); `childSessionStatuses()` reports
  every announced child across roots and `busyChildSessionIds` feeds
  `PluginActiveSession.childSessionIds`.
- [x] Step 5 implementation refinements (recorded 2026-09-01, code is truth):
  the tracker's task map is indexed by tool-use id across sessions and each
  task remembers its owning rendered session (`ClaudeTrackedTool.sessionId`),
  so `taskStarted`/`taskNotified`/`isKnownTask`/`task`/`cancelTask` resolve
  by tool-use id alone while `runningTaskToolUseIds`/`cancelAll`/
  `forgetSession` stay per owner; `childSessionIdForToolUse` maps a
  `parent_tool_use_id` to its child session; the dispatcher keeps a
  child→root map, announces nested children under the root (flattened, one
  level), keys announced/busy sets by root, and `cancelTasks`/`forgetSession`
  on a root cover its children's tasks and rendered state; a forwarded frame
  arriving before the launching task knows its sub-agent id is dropped (no
  session exists to render it into).
- [x] Step 6 implementation refinements (recorded 2026-09-02, code is truth):
  the plugin contract is `abortSession({sessionId, subAgents:
  PluginAbortSubAgentPolicy}) → PluginAbortResult` (`PluginAbortAccepted` |
  `PluginAbortRejectedSubAgentsRunning`), non-Claude plugins wrap their
  existing abort and answer accepted; the bridge repository returns a sealed
  `SessionAbortResult` (`SessionAborted` | `SessionAbortRejected`) mapped in
  `plugin_to_shared_mapping.dart`; `SessionAbortService` emits
  `abortedSessions` only for an accepted non-`keep` stop and
  `abortFailedSessions` (clear pending) for `keep` and rejections; the Claude
  `keep` path interrupts and returns without touching `wakeupAt` or the
  running set, and `ClaudeSessionProcessRepository` closes the interrupt
  window at the first `task_notification` that arrives while no turn is
  active (a `sendTurn` also closes it, as before); the client has no
  `capabilities/session/SessionService` abort seam (none exists), so
  `SessionApi` → `SessionRepository` → `SessionDetailCubit.abort({subAgents})`
  returning a sealed `SessionAbortOutcome` is the whole chain, the 409 body is
  the shared `SessionAbortRejection` (no module_core mirror), and the scope
  dialog lives in `client/app/.../session_abort_scope_dialog.dart` next to
  the view that owns the stop button, reusing the existing cancel label.

## Delivery Steps

| Done | Step | Exact PR title | Target | State |
|---|---|---|---:|---|
| [x] | 1/8 | `🌱 [claude-inline-subtasks] docs: plan inline Claude sub-agent subtasks [step 1/8]` | 450-650 | [PR #1027](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1027) merged |
| [x] | 2/8 | `⚙️ [claude-inline-subtasks] contract: subtask lifecycle state, cancelled status, child link [step 2/8]` | 500-800 | [PR #1044](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1044) merged |
| [x] | 3/8 | `🚧 [claude-inline-subtasks] claude: live and replayed subtask lifecycle for Agent calls [step 3/8]` | 900-1,300 | [PR #1247](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1247) merged |
| [x] | 4/8 | `🚧 [claude-inline-subtasks] claude: sub-agent transcripts as child sessions [step 4/8]` | 900-1,400 | [PR #1249](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1249) merged |
| [x] | 5/8 | `⚙️ [claude-inline-subtasks] claude: stream sub-agent frames into child sessions [step 5/8]` | 300-500 | [PR #1253](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1253) merged |
| [ ] | 6/8 | `🚧 [claude-inline-subtasks] stop: confirm main-agent-only or full stop while sub-agents run [step 6/8]` | 600-1,000 | In PR |
| [ ] | 7/8 | `🌱 [claude-inline-subtasks] docs: reconcile regression docs [step 7/8]` | 80-200 | Pending |
| [ ] | 8/8 | `🌱 [claude-inline-subtasks] docs: run coverage and retire the plan [step 8/8]` | 40-120 | Pending |

## Step 1 Checklist

- [x] Verify current contract, client, plugin, and CLI behavior against code
  and a live CLI probe; record bounded facts only (no prompt/transcript text).
- [x] Lock part shape, lifecycle rules, child-session model, streaming rule,
  sweep rule, and non-goals.
- [x] Record complexity budget, evidence classification, accepted risk,
  compatibility, cleanup, and regression matrix.
- [x] Run `architecture-plan-review` through a sub-agent; apply valid findings
  (six applied, see Plan Review).
- [x] `git diff --check`; plan/tracker titles and step total agree.
- [x] Commit, push, open the Step 1 PR
  ([#1027](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1027)).

## Open Questions

- [ ] Does the 2.1.221 floor emit `task_started`/`task_notification`? No floor
  build on the dev machine; recorded as untested. The typed substitutes
  (`asyncLaunched`/`completed` tool result, `<task-notification>` text) are
  implemented and unit-tested.
- [x] Live shape of the background notification (Step 3 capture, CLI
  2.1.257): the CLI does **not** echo the `<task-notification>` user message
  on stdout even with `--replay-user-messages`; live, only the
  `system/task_notification` frame carries the outcome (`summary` = the
  agent's result text). The persisted transcript has the `user` record with
  `origin: {kind: "task-notification"}`, a plain-string content envelope with
  `<summary>Agent "…" finished</summary>` and `<result>…</result>`, and
  `isSidechain: false` / no `isMeta` — so without Step 3 it renders as a user
  bubble. The wake-up turn after the notification starts with a second
  `system/init` frame, then assistant text, then `result`.
- [x] `system/background_tasks_changed {tasks: [{task_id, task_type,
  description}]}` does list live task ids, but the capture shows it fires
  *before* the matching `task_started` and, emptied, *before* the
  `task_notification`. Reconciling the running set from it would either be a
  no-op (it cannot settle idle without reintroducing the transient idle the
  notification-opens-the-wake-up-turn rule exists to avoid) or race the
  frames that follow it. Not adopted; the "notification never arrives"
  residual stays accepted (abort/delete/exit clear it).
- [ ] Which frame shapes the CLI emits between an acknowledged interrupt and
  the next turn when the process is kept alive for running sub-agents
  (`keep`); the owner and policy are fixed (`ClaudeSessionProcessRepository`
  closes the interrupted window at the next `sendTurn` or the first task
  notification after the interrupt's result), the Step 6 capture only confirms
  what is dropped inside that window.

## Verification Log

- **Step 1:** `git diff --check` passed; plan/tracker slug, eight exact
  titles, and step total agree; PR
  [#1027](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1027) open.
  Changed lines (informational, not a pass/fail check): `git diff --numstat
  <merge-base>..HEAD -- .plan/active/claude-inline-subtasks/PLAN.md` = 907
  additions / 0 deletions at the last plan edit — 257 lines over the 450-650
  target after the user-review lifecycle amendment, the scoped-stop step the
  user added, two architecture reviews, and the bot rounds; accepted
  deviation, target unchanged.
- **Step 2:** implemented on `main` at `5ffd05c5e`. Codegen re-run for
  `sesori_shared`, `sesori_plugin_interface`, and `flutter gen-l10n`.
  `dart analyze --fatal-infos` clean in `sesori_shared`,
  `sesori_plugin_interface`, `bridge/app`, and every plugin package;
  `flutter analyze` clean in `client/app`. `dart test`: shared 358,
  interface 153, `bridge/app` 2,692, `module_core` 1,315, opencode 434,
  acp 260, codex 392, pi 260, claude 253 — all pass; `flutter test`
  `client/app` 853 — all pass. Changed lines: 716 additions / 63 deletions
  across 53 files (779 changed lines, within the 500-800 target), of which
  202/37 are non-generated production code; the rest is generated output and
  the mechanical `childSessionID: null` argument a required nullable field
  forces at every existing construction site.
- **Step 2 PR:** [#1044](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1044) open
  Per the plan's series note, `TRACKER.md` bookkeeping is excluded from the
  comparison because its count would include the lines that record it; the
  final tracker size is visible in the merged PR.
- **Step 3:** implemented on `main` at `86ccc283fb`. Codegen re-run for the
  transcript record DTO (`toolUseResult`, `origin.kind`). `dart analyze
  --fatal-infos` clean and `dart test` 276/276 in `bridge/sesori_plugin_claude`
  (18 new tests: frame/envelope parsing, tracker precedence and cancel-all,
  dispatcher launch→turn end→notification and hidden/visible envelopes,
  replay incl. resident downgrade and DTO-level `origin`/`toolUseResult`,
  service busy-past-turn/no-transient-idle/reap deferral/exit/abort, plugin
  process-exit cancellation). Live capture: `claude` 2.1.257 with the
  plugin's flags minus the permission tool, one background `Agent` launch;
  facts in Open Questions. Merged as `c683beb290` after one architecture
  finding and two bot rounds (see Plan Review).
- **Step 4:** implemented on `main` at `c683beb290`. Codegen re-run for the
  transcript record DTO (`agentId`). `dart analyze --fatal-infos` clean in
  `bridge/sesori_plugin_claude` and `bridge/app`; `dart test` 283/283 in the
  plugin (7 new: id rule, catalog children/orphans/legacy, roots-only paging,
  root/child delete, child-mode replay, dispatcher child created→busy→idle
  and cancel/forget) and the bridge tool-finalization suite 12/12 (1 new:
  open subtask swept to cancelled, terminal and OpenCode-shaped parts
  untouched). Changed lines: see the PR diff stat.
- **Step 4:** merged as `911b6935f1` after one architecture finding and three
  bot rounds (see Plan Review).
- **Step 5:** implemented on `main` at `911b6935f1` (branch
  `claude-subagent-streaming`). `dart analyze
  --fatal-infos` clean; `dart test` 285/285 in the plugin (2 new: forwarded
  frames route into the child session only once its id is known; a nested
  Agent call inside a child binds through the root's `task_started`, renders
  its part in the child, and its grandchild is flattened under the root).
- **Step 5:** merged as `8ff7fba910`; both bot rounds declined (tool-use ids
  are globally unique Anthropic block ids).
- **Step 6:** implemented on `main` at `8ff7fba910` (branch `claude-scoped-stop`;
  rebased across the desktop transcripts move of the loaded view into
  `module_app_ui`, so the stop dialog is wired from
  `client/app/.../session_detail_composer_controls.dart`). Codegen re-run for `sesori_shared`
  (`AbortSessionRequest`, `SessionAbortRejection`) and `flutter gen-l10n`.
  `dart analyze --fatal-infos` clean in shared, interface, bridge/app, every
  plugin, `client/module_core`; `flutter analyze` clean in `client/app`.
  Tests: Claude 289/289 (3 new: confirm refused with count and
  `mainAgentRunning`, keep leaves the process and tasks resident and settles
  once after the wake-up turn, stop tears down), acp 275, codex 380, opencode
  425, pi 291, bridge/app routing+services+repository 516, module_core
  session-detail+repositories 350, client body test 94 — all pass. Changed
  lines 1,257 across 49 files including generated code and the mechanical
  `subAgents` argument at every plugin, fake, and test call site; the
  non-generated production change is well inside the 600-1,000 target.
- **Final disposition:** pending

## Plan Review

- **Reviewer:** `architecture-plan-review` (sub-agent)
- **Date:** 2026-08-22
- **Reviewed scope:** complete `.plan/active/claude-inline-subtasks/`
- **Verdict:** rejected on first pass with six blocking ownership/layering
  findings; no client or shared findings. All six were applied directly to
  `PLAN.md` per repository policy (no re-review of applied fixes):
  1. sweep child-status lookup moved to `ChatHistoryService`, repository
     receives the keep-open set as data; cancelled for parts without a child
     id;
  2. replayed running→cancelled downgrade moved from `ClaudePlugin` into
     `ClaudeHistoryMapper` with `residentTaskToolUseIds` passed as data;
  3. single child-status owner (`ClaudeEventDispatcher` accessor), named
     emitters for child created/status events, and
     `getActiveSessionsSummary().childSessionIds` populated (the "no bridge
     change" claim was corrected to name the plugin-contract surfaces used);
  4. process-exit cancellation owned by `ClaudePlugin._handleProcessEvent`
     via `ClaudeEventDispatcher.cancelTasks`; session service untouched;
  5. one `ClaudeTaskStatus` enum, one `toPluginToolStatus()` mapping, one
     `<task-notification>` parser in `ClaudeContentMapper`;
  6. child enumeration split into `ClaudeTranscriptApi.readSubagentMeta` +
     `ClaudeSubagentMetaDto` (Layer 1) and `ClaudeTranscriptCatalogRepository`
     decisions with `ClaudeSessionRecord.parentId` (Layer 2).
- **Not re-reviewed:** the corrected plan was not resubmitted; a later
  considerable change would trigger another review.
- **PR bot review rounds (cubic-dev-ai, chatgpt-codex-connector), applied as
  plan refinements:** task notification is the authoritative terminal source
  and the tool result a replaceable fallback (interrupted-foreground replay
  divergence accepted); `task_id == agentId` evidence recorded; tool-use
  results parsed at the boundary into sealed `ClaudeToolUseResult`; the
  dispatcher owns child `PluginSession` construction and ordered
  created/status/part emission (root directory passed via `beginTurn`),
  superseding the earlier "plugin emits child created" wording;
  `getActiveSessionsSummary` keeps idle roots with running children; sweep
  resolves child statuses from one `getSessionStatuses({sessionIds})`
  snapshot; tracker bookkeeping excluded from step line targets. Declined:
  updating `docs/regression/` in every behavior PR — the regression README
  explicitly allows reconciliation in the penultimate step of durable planned
  work, which Step 7 is (it was Step 6 until the series grew to eight).
- **User review (2026-08-22), applied:** the plan had not considered the
  Claude idle process reaper (`ClaudeSessionService._scheduleIdleReap`), the
  plugin work state that gates safe stops, or that Sesori's abort tears the
  process down. Amendment: running tasks keep the session busy and defer the
  reap (lifecycle owner `ClaudeSessionService`, all task types); abort
  cancels sub-agents via process exit; the sweep no longer needs child-status
  resolution (supersedes the keep-open-set design and the batched
  `getSessionStatuses({sessionIds})` refinement, and the idle-root special
  case in `getActiveSessionsSummary`); regression scope gains
  `notifications.md` and `plugin-setup-and-lifecycle.md`.
- **Third bot round (chatgpt-codex-connector), applied:** `childSessionID`
  is an optional reference in bridge translation (never part of the required
  `backendSessionIds`, unbound → null) so Step 3 parts stay deliverable
  before Step 4; `childSessionIds` lists busy/retry children only;
  `_trackSelfStartedTurn` ignores forwarded child assistant/stream frames;
  the child lifecycle and the running-task set start on the first
  agent-id-bearing signal (`task_started` or an agent-id tool result), so the
  2.1.221 floor degrades without losing children or reap deferral. Two
  further threads (abort teardown, reap deferral) were already answered by
  the user-review amendment.
- **Fourth bot round (chatgpt-codex-connector, cubic-dev-ai), applied:** a
  task notification (or notification-bearing user frame) arriving while no
  turn is active opens a self-started turn, so busy spans launch → background
  work → wake-up turn and the 500 ms completion debounce never sees a
  transient idle; `getActiveSessionsSummary` derives `mainAgentRunning` from
  `ClaudeSessionService.isTurnRunning`, not the conflated busy status; risk
  row and tracker wording aligned (only `asyncLaunched` adds to the running
  set; dispatcher-owned child creation; `runningTaskIds` is already locked).
- **User direction (2026-08-22), applied:** stop must not silently kill
  running sub-agents. Added Step 6/8 "scoped stop" (abort `subAgents`
  policy, 409 rejection with count and `mainAgentRunning`, Claude `keep`
  without teardown, client dialog modeled on the delete/archive force flow);
  the series grows to eight steps and PR #1027's title moves to `[step
  1/8]`. The scoped-stop section is architecture-bearing (wire contract,
  plugin API, cross-layer flow) and is submitted to `architecture-plan-review`
  as a considerable change.
- **Fifth bot round (chatgpt-codex-connector), applied:** the abort
  eligibility guard includes `runningTaskIds` (a background-only session can
  be stopped); the `<task-notification>` parser hides and applies only a
  complete envelope whose tool-use id matches a known task (transcript
  `origin.kind` is authoritative provenance); Step 7 reconciles every listed
  regression document. Declined: namespacing child ids by root — `agentId`
  is a 17-hex random id, a cross-root collision is not a reachable flow, and
  namespacing would complicate lookups for no observable benefit.
- **Second `architecture-plan-review` (sub-agent, 2026-08-22) on the
  scoped-stop and lifecycle changes: rejected with eight findings, all
  applied directly (no re-review):** dedicated `AbortSessionRequest` instead
  of the shared `SessionIdRequest`; `SessionAbortRejection` reduced to
  `{ runningSubAgentCount, mainAgentRunning }`; count limited to typed
  sub-agents (`ClaudeTaskType` parsed at the boundary, set keeps every type);
  `SessionRepository.abortSession → SessionAbortResult` with the mappings in
  Layer 2; abort-service stream emissions defined per outcome (`stop` →
  aborted, `rejected`/`keep` → clear pending so the later completion push is
  kept); `keep` post-interrupt window owned by `ClaudeSessionProcessRepository`
  (closes at the next `sendTurn` or first task notification after the
  interrupt's result); `ClaudeSessionService` takes `ClaudeContentMapper`
  and keys floor add/remove by task id (block gains `taskId`); client
  `SessionRepository`/`SessionService.abortSession` in lockstep. The reviewer
  explicitly passed the two-structure lifecycle design, the sweep
  simplification, and the disjoint-union status composition.
- **Step 3 `architecture-implementation-review` (sub-agent, 2026-09-01), scope
  commit `573a6b244e`: rejected with one finding, applied in `7d9ecd6658`:**
  `ClaudeTrackedTool` flattened tool-vs-task into `bool isTask` plus a nullable
  `childSessionId`; now a sealed type with `ClaudeTrackedToolCall` and
  `ClaudeTrackedTask` (the latter owns `childSessionId`). Layering, boundary
  parsing, and the recorded refinements passed; not re-reviewed.
- **Step 5 `architecture-implementation-review` (sub-agent, 2026-09-02), scope
  branch vs `origin/main`: approved, no findings; its out-of-scope note about
  two unused `sessionId` parameters on the dispatcher task mappers was applied.**
- **Step 4 `architecture-implementation-review` (sub-agent, 2026-09-01), scope
  branch vs `origin/main`: rejected with one finding, applied in `0a6bd0b67a`:**
  the tracker still encoded `agent-<id>` as a literal while
  `ClaudeSubagentSessionId` claimed ownership; it now calls `fromAgentId`.
  Layering, sweep neutrality, and the recorded refinements passed; not
  re-reviewed.
- **Step 3 PR bot round (chatgpt-codex-connector, 2026-09-01):** applied —
  `ClaudeSessionProcessRepository.teardown` publishes
  `ClaudeSessionProcessExited` (an abort, delete, reap, or effort restart had
  removed the process silently, leaving launched sub-agents running in live
  parts and resident ids; this also supersedes the Step 3 note that
  delete/dispose rely on the exit event — they now genuinely do);
  `ClaudeUserMessage.taskNotifications` parsed at the transport boundary
  replaces the service's raw-content walk. Declined — regression docs stay in
  Step 7/8; refusing an effort-triggered process replacement while sub-agents
  run is Step 6/8's scoped-stop decision (the replacement now cancels them
  observably instead of pinning the session).
- **Sixth bot round (chatgpt-codex-connector, cubic-dev-ai), applied:**
  side-effect-free `confirm` (no queue clearing, no child fan-out before a
  root `aborted` under `stop`); nested-task lifecycle frames resolved through
  a tool-use-indexed task map; the Step 3 guard extension is recorded as a
  behavior change for background-only stops; tracker step wording.
  Accepted limitation: a root whose only resident work is a non-sub-agent
  background task is busy but absent from the activity summary (no contract
  slot); recorded in the risk table.
