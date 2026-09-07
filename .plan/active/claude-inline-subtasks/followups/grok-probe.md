# Grok Build sub-agent probe (2026-09-03)

Live capture against the official macOS arm64 artifact `grok 1.0.5
(5115b46bc909)` launched as `grok --no-auto-update agent --no-leader stdio`
(ACP v1 over NDJSON) from a scratch project under `/tmp`, authenticated with
the developer's `cached_token`. Three runs: one background child; a background
plus a foreground child with a root `session/cancel`; the same pair with a
single `_x.ai/subagent/cancel` and no turn cancel. Only shapes, field names,
ordering, and enum values are recorded; no prompt or transcript text.

## Answers to the plan's open questions

1. **Notification JSON.** The live method is `_x.ai/session_notification`
   (leading underscore; the un-prefixed name in the binary survey is not what
   reaches the wire). Params: `{sessionId, update: {sessionUpdate, ...}}`,
   snake_case inside `update`. The envelope `sessionId` is the **parent**
   for all three sub-agent updates. `subagent_id == child_session_id` in every
   frame.
   - `subagent_spawned`: `subagent_id`, `parent_session_id`, `parent_prompt_id`,
     `child_session_id`, `subagent_type`, `description`,
     `effective_context_source`, `model`. **No background flag** and no tool
     call id.
   - `subagent_progress`: `subagent_id`, `parent_session_id`,
     `child_session_id`, `duration_ms`, `turn_count`, `tool_call_count`,
     `tokens_used`, `context_window_tokens`, `context_usage_pct`, `tools_used`,
     `error_count`. Roughly every 8-10 s per running child.
   - `subagent_finished`: `subagent_id`, `child_session_id`, `status`,
     `tool_calls`, `turns`, `duration_ms`, `tokens_used`, `will_wake`, plus
     `output` (final text) on `completed` and `error` (short reason string) on
     `cancelled`. Observed `status` values: `completed`, `cancelled`; the binary
     also renders a `failed` outcome. Nothing in the payload names the
     launching tool call.
2. **Child updates.** Yes: the child's `session/update`s (`user_message_chunk`
   with the child prompt, `agent_thought_chunk`, `tool_call`,
   `tool_call_update`) and its own `_x.ai/session_notification` frames
   (`turn_completed`, `tool_call_delta_chunk`, ...) arrive on the same
   connection under the child id, immediately after `subagent_spawned`.
3. **`session/load` / `session/list`.** `session/load {sessionId: child, cwd:
   root cwd}` succeeds for a child id (also while it runs) and replays the
   child's `user_message_chunk` plus `_x.ai/session/update` frames
   (`turn_completed`). `session/list` returns **roots only**; children never
   appear, so there is no parent marker to read from the list. A root
   `session/load` replays `subagent_spawned`, the `spawn_subagent` tool_call
   (with `status: completed`), `subagent_finished`, and `turn_completed` under
   the method name `_x.ai/session/update` (not `_x.ai/session_notification`).
4. **Cancel.** `session/cancel` must be sent as a JSON-RPC notification (a
   request form is answered "Method not found"). A root `session/cancel`
   cancelled the running **background and foreground** children alike: each
   child got `turn_completed {stop_reason: cancelled}` and the parent got
   `subagent_finished {status: cancelled, error, will_wake: false}`; the root
   prompt resolved `stopReason: cancelled`. The binary survey's "subagents keep
   running" claim does not hold on this seam, so main-agent-only stop is not
   supportable on 1.0.5 (`mainAgentOnlySupported = false`).
   `session/close` on the root also cancels its children the same way.
   `_x.ai/subagent/cancel {subagentId}` (leading underscore) is a request;
   response `{result: {subagentId, cancelled: bool, outcome: {kind}}}` with
   `outcome.kind: cancelled` for a running child and
   `outcome.kind: already_finished, status: <finished status>` otherwise.
   Cancelling one child does not affect its sibling or the root turn; the
   parent then receives `subagent_finished {status: cancelled}`.
5. **`spawn_subagent` tool call and wake-up.** The spawn is also a standard
   `tool_call` that arrives **before** `subagent_spawned`, with `title:
   spawn_subagent`, `rawInput {description, prompt, subagent_type,
   background}`, and `_meta {"x.ai/tool": {name: spawn_subagent, kind: task,
   namespace, label, read_only}, subagentBackground: bool}`. It is followed by
   a permission round (`pending_interaction` / `session/request_permission` /
   `interaction_resolved`) and a `tool_call_update` that sets `kind: other`
   and `title` = description. A background spawn's tool call reports
   `status: completed` right after approval, before `subagent_spawned`; a
   foreground spawn's tool call stays open and completes only after
   `subagent_finished`. A denied or cancelled spawn leaves the foreground tool
   call without a terminal update. A background child finishing with
   `will_wake: true` triggers a wake-up turn on the parent with no client
   prompt: `user_message_chunk` (a `<system-reminder>` text), a
   `get_command_or_subagent_output` tool call, and `_x.ai/session/update`
   `turn_completed` for prompt id `subagent-completed-<child id>`; the original
   `session/prompt` had
   already resolved `end_turn`. A cancelled child reports `will_wake: false`
   and no wake-up turn.

## Replay of the extension frames

`session/load` does **not** replay `_x.ai/session_notification`. The same
sub-agent facts come back under a different method, `_x.ai/session/update`
(same `{sessionId, update: {sessionUpdate, ...}}` shape): a root load replays
`subagent_spawned`, `subagent_finished`, and `turn_completed`; a child load
replays the child's `turn_completed`. Standard frames (`user_message_chunk`,
`tool_call` with its terminal status) replay as ordinary `session/update`.

## Consequences for the design

- The `spawn_subagent` tool call and `subagent_spawned` share no id, so the
  tool call renders nothing (seam 2 drops the card and its later updates) and
  the tile is opened from `subagent_spawned` only, keyed by
  `child_session_id`: one child, one tile, deterministically.
- The tile's prompt is the child's own first `user_message_chunk`, which
  arrives under the child id right after `subagent_spawned`; the tile renders
  on that chunk. Nothing is matched by description or order.
- No background flag reaches the lifecycle notification, and a root
  `session/cancel` stops background children too, so every child is recorded
  as foreground and `mainAgentOnlySupported` stays false.
- The parent tile after a reload depends on the child-history PR reading the
  `_x.ai/session/update` replay frames.
