# Claude Inline Sub-Agent Subtasks: Tracker

## Current State

- **Plan slug:** `claude-inline-subtasks`
- **Implementation base:** `main` at `ba725ec84`
- **Plan branch:** `inline-subtask-plan`
- **Series state:** Step 1/7 plan PR
  [#1027](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1027) open
- **Next action:** merge the plan, then Step 2/7 (contract + client tile)
- **Pinned facts source:** `PLAN.md` "Claude Code CLI 2.1.237 facts"; the
  completed `claude-code-plugin/PROTOCOL.md` is historical and is not edited

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
- [x] Abort keeps interrupt + teardown, so running sub-agents become
  `cancelled`; `stop_task` is not needed.
- [x] Open subtask parts are swept to `cancelled` only when the root is idle
  (the busy-while-tasks-run rule already protects live sub-agents); no
  child-status lookup in the sweep.
- [x] `ClaudeEventDispatcher` (over the tracker task map) is the sole owner of
  task state, child-session statuses, resident task ids, and `childSessionIds`;
  `ClaudeSessionService` gains no field. `ClaudePlugin` forwards the disjoint
  union of root and child statuses and emits the child `session.created`
  event on `ClaudeTaskStartedMessage`.
- [x] `ClaudeHistoryMapper.map(..., residentTaskToolUseIds)` owns the replayed
  running→cancelled downgrade; the composition root passes data only.
- [x] `ClaudePlugin._handleProcessEvent` owns process-exit cancellation through
  `ClaudeEventDispatcher.cancelTasks`; delete/dispose call the same.
- [x] One `ClaudeTaskStatus` enum, one `toPluginToolStatus()` mapping, and one
  `<task-notification>` parser (`ClaudeMappedTaskNotificationContentBlock` in
  `ClaudeContentMapper`) serve both live and replay paths.
- [x] Child enumeration splits dumb reads (`ClaudeTranscriptApi.readSubagentMeta`
  → `ClaudeSubagentMetaDto`, `deleteSessionDirectory`) from catalog decisions
  (`ClaudeTranscriptCatalogRepository`, `ClaudeSessionRecord.parentId`).
- [x] No analytics, no tasks-bar change, no `task_progress` rendering.

## Delivery Steps

| Done | Step | Exact PR title | Target | State |
|---|---|---|---:|---|
| [ ] | 1/7 | `🌱 [claude-inline-subtasks] docs: plan inline Claude sub-agent subtasks [step 1/7]` | 450-650 | [PR #1027](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1027) open |
| [ ] | 2/7 | `⚙️ [claude-inline-subtasks] contract: subtask lifecycle state, cancelled status, child link [step 2/7]` | 500-800 | Pending |
| [ ] | 3/7 | `🚧 [claude-inline-subtasks] claude: live and replayed subtask lifecycle for Agent calls [step 3/7]` | 900-1,300 | Pending |
| [ ] | 4/7 | `🚧 [claude-inline-subtasks] claude: sub-agent transcripts as child sessions [step 4/7]` | 900-1,400 | Pending |
| [ ] | 5/7 | `⚙️ [claude-inline-subtasks] claude: stream sub-agent frames into child sessions [step 5/7]` | 300-500 | Pending |
| [ ] | 6/7 | `🌱 [claude-inline-subtasks] docs: reconcile regression docs [step 6/7]` | 80-200 | Pending |
| [ ] | 7/7 | `🌱 [claude-inline-subtasks] docs: run coverage and retire the plan [step 7/7]` | 40-120 | Pending |

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

- [ ] Does the 2.1.221 floor emit `task_started`/`task_notification`? The
  lifecycle degrades without them (tool-result finalization plus the
  `<task-notification>` user-frame parse); confirm during Step 3's live capture
  if a floor build is available, otherwise record as untested.
- [ ] Exact live shape of the background `<task-notification>` user frame
  (whether it carries `isReplay`/`origin`); Step 3 capture.
- [ ] Whether `system/background_tasks_changed {tasks}` lists live task ids in
  a shape usable to reconcile `runningTaskIds` (a task whose notification
  never arrives would otherwise pin the process until abort/exit); Step 3
  capture decides adopt-or-skip.

## Verification Log

- **Step 1:** `git diff --check` passed; plan/tracker slug, seven exact
  titles, and step total agree; PR
  [#1027](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1027) open.
  Changed lines (informational, not a pass/fail check): `git diff --numstat
  <merge-base>..HEAD -- .plan/active/claude-inline-subtasks/PLAN.md` = 685
  additions / 0 deletions at the last plan edit — 35 lines over the 450-650
  target after the user-review lifecycle amendment and the third bot round;
  accepted deviation, target unchanged.
  Per the plan's series note, `TRACKER.md` bookkeeping is excluded from the
  comparison because its count would include the lines that record it; the
  final tracker size is visible in the merged PR.
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
  work, which Step 6 is.
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
