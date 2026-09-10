# Codex Sub-Agent Probe (codex-cli 0.148.0, app-server v2 over stdio)

Date: 2026-09-02. Binary:
`~/.codex/packages/standalone/releases/0.148.0-aarch64-apple-darwin/bin/codex app-server --listen stdio://`.
Scratch project under `/tmp`, `approvalPolicy: never`, `sandbox: workspace-write`.
`gpt-5-mini` was rejected (`The 'gpt-5-mini' model is not supported when using
Codex with a ChatGPT account`), so the configured default model ran. Ids below
are redacted to `P` (parent), `C` (child), `T` (turn), `call_*` (tool call).

Three runs: (A) spawn one sub-agent that replies "done"; (B) spawn a child
that runs `sleep 90`, then `turn/interrupt` the parent; (C) same, then
`turn/interrupt` the child.

## Current-pin correction (codex-cli 0.153.4, 2026-09-08)

A bounded production-shaped stdio probe against managed 0.153.4 supersedes the
0.148.0 rollout-input assumptions below without erasing their historical value:

- persisted started activity is
  `event_msg/item_completed/item/SubAgentActivity`; its `id` exactly equals the
  preceding `spawn_agent.call_id` for both forked and nonforked children;
- `thread/read(includeTurns: true)` exposed no initial child user item, and live
  app-server output emitted no stable child `userMessage` or public raw-response
  notification;
- initial child input appended after child `turn/started` as adjacent
  `inter_agent_communication_metadata` and `response_item/agent_message` records;
  normal model-origin payload was encrypted, while existing rollout tails can
  observe the append without another watcher or timer;
- user-approved prompt provenance for encrypted input is only the exact nonblank
  `message` from the matching spawn call id. Never use a parent user message,
  copied history, task name, child order, timing, or the agent-message envelope
  header. A valid child-owned plaintext `NEW_TASK` payload may replace that
  fallback for the initial delegated turn.

A second bounded managed-0.153.4 stop probe used real `CodexPlugin.composed`
and production WebSocket transport with owned `/tmp` sessions and harmless
bounded sleep work. Parent interrupt produced parent `turn_aborted` while two
direct children and one nested grandchild remained busy. Direct interrupt of
one named child produced that child's `turn_aborted`, while its sibling and
grandchild remained busy; later exact cleanup interrupts settled both. This
confirms main-agent-only support and exact per-thread child interruption, but
rules out atomic native subtree authority. Scoped full stop must fan out over a
known snapshot and report `subAgentsHandled: false`. Step 8 automated policy
coverage implements that behavior.

Step 9 actual-plugin policy QA on 2026-09-10 used the same managed 0.153.4
entrypoint through `CodexPlugin.composed` and production WebSocket transport.
Three newly owned trees verified root confirmation (three running descendants,
main running, main-only supported) and named-child confirmation (one nested
descendant) with zero abort/status/input effects; root `keep` aborted only the
root and a later confirmation accurately reported main idle with three running
descendants; named-child full stop aborted that child and its grandchild while
its ancestor and sibling remained busy; root full stop aborted the root, both
direct children, and nested grandchild. Every selected target had persisted
`turn_aborted`. Named-child and full-root stop targets became non-busy in plugin
status; after root `keep`, only its own turn stopped (`mainAgentRunning: false`),
while effective root status stayed busy for retained descendants. Every accepted
atomic-opt-in response retained `subAgentsHandled: false`, and the owned runtime
survived each case.
No pending question or permission surfaced, so live pending-input policy was
unexecuted; focused Step 8 automation remains its evidence. Natural sleep
expiry, runtime death, and disconnect were excluded as stop proof.

Raw probe payloads remain private under the owned `/tmp` artifacts. Native source
was pinned to Codex commit `3d2ee51ca2d5db578f328aa75e20aa22c0197c9a`.

## Frame order on the parent connection (run A)

1. `thread/started {thread: {id: P, parentThreadId: null, agentNickname: null,
   agentRole: null, threadSource: null, status: {type: idle}, sessionId: P}}`
2. `thread/status/changed {threadId: P, status: {type: active}}`,
   `turn/started {threadId: P, turn: {id: T}}`, `item/started` +
   `item/completed` for the `userMessage`.
3. `thread/status/changed {threadId: C, status: {type: idle}}` - first sight
   of the child. **No `thread/started` is emitted for C** (all three runs).
4. `item/started {threadId: P, turnId: T, item: {type: subAgentActivity,
   id: call_spawn, kind: started, agentThreadId: C, agentPath: "/root/<task_name>"}}`
   followed immediately by `item/completed` with the same item.
5. `thread/status/changed {threadId: C, status: {type: active}}`,
   `turn/started {threadId: C, turn: {id: T_c}}`.
6. `item/started {threadId: P, item: {type: collabAgentToolCall, id: call_wait,
   tool: wait, status: inProgress, senderThreadId: P, receiverThreadIds: [],
   prompt: null, model: null, reasoningEffort: null, agentsStates: {}}}`.
7. Child items (`reasoning`, `agentMessage`, `commandExecution`, deltas) arrive
   under `threadId: C, turnId: T_c` on the same connection.
8. `turn/completed {threadId: C, turn: {status: completed}}`,
   `thread/status/changed {threadId: C, status: {type: idle}}`.
9. `item/completed` for `call_wait` with `status: completed`;
   `receiverThreadIds` and `agentsStates` are still empty.
10. Parent `agentMessage`, `turn/completed {threadId: P}`,
    `thread/status/changed {threadId: P, status: {type: idle}}`.

Facts:

- **No `collabAgentToolCall` with `tool: spawnAgent` was emitted** in any run.
  The spawn is visible on the wire only as `subAgentActivity kind: started`,
  whose `id` equals the persisted `spawn_agent` call id.
- `subAgentActivity` arrived only with `kind: started`. No `completed`,
  `interrupted`, or `interacted` activity was emitted in any run, including
  after the child finished (A) or was interrupted (C). Child completion is
  observable only through the child's own `turn/completed` and
  `thread/status/changed idle`.
- `receiverThreadIds` was `[]` at both `item/started` and `item/completed` of
  every `wait`; `agentsStates` was `{}`. The child id comes from
  `subAgentActivity.agentThreadId`, not from collab items.
- `thread/read {threadId: C}` returns `parentThreadId: P`, `agentNickname` set
  (a generated first name), `agentRole: null`, **`threadSource: null`**, and a
  live `status`. Thread objects also carry `canAcceptDirectInput`.
- `thread/list {parentThreadId: P}` returned `data: []` in runs B and C while
  the child existed (likely gated behind experimental capabilities).

## Interrupts

- Run B, `turn/interrupt {threadId: P, turnId: T}` -> `{}`;
  `turn/completed {threadId: P, turn: {status: interrupted}}`. The child kept
  running: no child `turn/completed`, no activity item, and 20 s later
  `thread/read C` reported `status: {type: active}`. The parent rollout stores
  the `wait_agent` output as `aborted by user after N.Ns` then `turn_aborted`.
  **Parent interrupt does not stop children.**
- Run C, `turn/interrupt {threadId: C}` without a turn id ->
  `error {code: -32600, message: "Invalid request: missing field `turnId`"}`.
  With `turnId: T_c` (taken from the child's `turn/started`) -> `{}`, then
  `turn/completed {threadId: C, turn: {status: interrupted}}` and
  `thread/status/changed {threadId: C, status: {type: idle}}`. No parent-side
  activity item followed; the parent issued further `wait` collab items and
  had not completed its turn after 200 s. **A child interrupt needs the child
  turn id, which the same connection receives via `turn/started`.**

## Rollouts (`~/.codex/sessions/YYYY/MM/DD/rollout-*-<thread>.jsonl`)

Parent rollout (`session_meta` has none of the parent fields):

- `response_item function_call {name: spawn_agent, call_id: call_spawn,
  arguments: {fork_turns, message, task_name}}`
- `event_msg sub_agent_activity {kind: started, agent_thread_id: C,
  agent_path: "/root/<task_name>"}`
- `response_item function_call_output {call_id: call_spawn,
  output: {"task_name": "/root/<task_name>"}}`
- `response_item function_call {name: wait_agent, arguments: {timeout_ms}}` and
  its output `{"message":"Wait completed.","timed_out":false}`.
- No collab item is persisted as such, and no `sub_agent_activity` other than
  `started` appears.

Child rollout `session_meta` payload keys: `agent_nickname`, `agent_path`,
`parent_thread_id`, `thread_source: "subagent"`, `multi_agent_version`,
`forked_from_id`, plus the usual `id`, `cwd`, `cli_version`, `model_provider`,
and `source: {subagent: {thread_spawn: {parent_thread_id, depth: 1,
agent_path, agent_nickname, agent_role: null}}}`.

- With `fork_turns: true` (run B) the child rollout copies the parent history
  prefix, including a **second `session_meta` line (the parent's)** and the
  parent's `task_started`/user message lines, before its own `task_started`.
- With `fork_turns: false` (run A) nothing is copied; the child rollout holds
  only its own developer/user messages and turn.

## Verdicts for the plan's open questions

1. `thread/started` for children: **no**. The child announces itself through
   `thread/status/changed` and `subAgentActivity started`; `receiverThreadIds`
   never carried the child id. The tile PR must open the tile on
   `subAgentActivity started` and read the nickname through `thread/read`.
2. Parent interrupt **does not** stop children. Child `turn/interrupt`
   **requires `turnId`**; it is available from the child's `turn/started`.
3. Parent rollouts persist the `spawn_agent`/`wait_agent` function calls and
   `sub_agent_activity started` (no collab items, no terminal activity). Child
   rollouts copy the parent history **only when `fork_turns` is true**.
4. No migration for already-imported roots; accepted as planned.
