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
   `_x.ai/subagent/cancel {subagentId}` (leading underscore) is a request. The
   JSON-RPC response is `result -> result -> {subagentId, cancelled, outcome}`:
   after ACP transport unwraps the outer JSON-RPC result, the application
   envelope still contains required `result`. `outcome.kind: cancelled` applies
   to a running child; `outcome.kind: already_finished` includes
   `status: <finished status>` otherwise.
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

Persisted `session/load` facts normally replay under `_x.ai/session/update`
(same `{sessionId, update: {sessionUpdate, ...}}` shape): a root load replays
`subagent_spawned`, `subagent_finished`, and `turn_completed`; a child load
replays the child's `turn_completed`. Standard frames (`user_message_chunk`,
`tool_call` with its terminal status) replay as ordinary `session/update`.
A bounded 2026-09-10 cancellation probe added one ordering case: after a loaded
unfinished episode returned its load response, authoritative settlement arrived
through `_x.ai/session_notification`. Replay therefore consumes both Grok
methods until the existing quiet-window drain completes.

## 2026-09-10 cancellation and denial follow-up

A root cancelled immediately after its spawn call still persisted typed
`subagent_spawned` and terminal `subagent_finished {status: cancelled}`. The
cancelled child's own fresh `session/load` succeeded but replayed no
`user_message_chunk` or `turn_completed`; without a child-owned prompt, Sesori
must not fabricate a tile. Intended denied/cancelled-permission attempts exposed
zero `session/request_permission` frames because the unchanged runtime/config
resolved interaction automatically. Denial persistence is therefore unverified:
no permission-outcome model or generic-card replay guarantee is justified.

## 2026-09-10 actual-plugin scoped-stop QA

Corrected bounded QA ran through the production Grok plugin, ACP transport,
API/repository/service/tracker/event layers, and real Grok 1.0.5 processes after
Step 6/7 merged as PR #1429. Executed scope passed:

- Active-root `keep` returned the typed rejection with two children and no
  outbound cancellation or local input mutation.
- Named-child stop sent one exact child request, no root cancellation, parsed
  `cancelled`, settled that child, and left the root and sibling active.
- Idle-root child-only `keep` sent no cancellation, retained the child through
  natural completion with `will_wake: true`, observed its autonomous root turn,
  and released one final root idle.
- Root and child replay preserved one exact parent/child link and used the
  nonblank child-owned first prompt for the one root tile.
- Cancelling a naturally finished child parsed `already_finished`, retained no
  work, and did not rewrite terminal lifecycle.
- Full stop sent root cancellation before the immutable two-child fanout,
  parsed both nested `cancelled` outcomes, observed authoritative cancelled
  root/child terminals and plugin idle settlement, and kept the runtime usable.
- Fresh sessions after named cleanup, already-finished handling, and full stop
  dispatched and settled on the same runtime.

Root `confirm` was not rerun: its earlier side-effect-free production-composition
pass remains valid because Step 6 changed only response-envelope decoding.
Unchanged configuration emitted zero `session/request_permission` requests, so
permission preservation, isolation, and cleanup remain unexecuted. No Grok
question capability is claimed.

## Phone-through-relay gate

On 2026-09-10, source phone build, source bridge health, production relay
connection, and phone connection all succeeded. `mobile-mcp` then timed out
starting WebDriverAgent 0.0.23 before the first screenshot or visible
interaction. An agent reinstall scoped to the owned simulator succeeded, but
next startup timed out identically.

On 2026-09-12, the user refreshed Grok login and authorized its private use.
The owned run used current phone/bridge source plus a checksum-verified isolated
official Grok 1.0.5; the installed 1.0.30 runtime and global auth/config remained
untouched. Grok alone was enabled, yolo stayed off, production relay and exact
phone connection passed, and normal native permission sheets used one-time
approval only.

Visible phone results passed Grok-only session creation, exactly two running
child tiles, exact two-child Stop copy/count, dismissal with no stop, confirmed
full cancellation, same-session/runtime reuse, natural completion, cold root
reload, persisted cancelled/completed tile states, and exact read-only child
navigation without mutating controls. Background completion notification was
attempted but no OS delivery was observed, so push is not claimed.

Cold child history failed materially: the initial child-owned user row remained
single, but the same assistant/tool/final sequence rendered twice under distinct
rows. Reopening the same child reproduced the same duplicate without growth.
Stored-only bridge history already had one user row followed by two three-row
assistant/tool/final-shaped sequences under distinct identities. The native
child store held one nine-frame turn, and a fresh direct official-1.0.5
`session/load` emitted one standard sequence. Stored identity shapes separated
into replay-imported rows and retained live rows.

A later fresh headless Grok 1.0.5 reproduction classified the mismatch without
retaining private content. Live held an assistant/tool/assistant fragment with
no leading user; direct replay added the user. The first assistant and tool rows
were exactly equal after current normalization. The final live
`MessagePartText.text` was a strict prefix of replay by a small extension;
reasoning, part order/shape, normalized info, and every other typed field were
exact, with no timestamps on either side. One opaque typed `toolCallId` was
identical across live and replay and uniquely adjacent to those assistant rows,
but shared ACP mapping placed it in different generated message/part identities.
A second genuine backend backfill retained the same three old rows without new
growth.

Local production changes now centralize deterministic standalone tool message
and part identity across ACP live and replay. Repository reconciliation adds one
atomic exception around that exact shared anchor: preceding assistant content
must match exactly, following replay text must be the sole differing field and a
strict extension of nonempty live text, known times must agree, and all three
rows must form one uniquely consumed contiguous window. Distinct/reused anchors,
ambiguous windows, reverse prefixes, unrelated text, second differences,
part-shape/order changes, timestamp conflicts, and unmatched newer suffixes
remain distinct. Focused ACP and repository coverage passes locally. No Grok
strings, generated-ID parsing, schema field, or general semantic relaxation was
added.

The plan remains active for exact owned-phone cold child-history confirmation
after review. Owned diagnostic bridge/runtime/scratch/home/log/database/private
evidence resources were removed; protected resources stayed untouched.

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
