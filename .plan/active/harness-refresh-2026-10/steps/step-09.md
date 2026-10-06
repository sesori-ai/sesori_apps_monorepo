# Step 9 — Cursor ACP sub-agent wire probe

Date: 2026-10-06. Target: Cursor CLI `2026.10.01-e373342`, darwin/arm64.

This is a probe note only. It changes no production code and feeds the
architecture review and implementation of Step 10.

## Method

- **Runtime.** Downloaded the pinned `darwin/arm64/agent-cli-package.tar.gz`
  into a disposable directory. Its SHA-256 matched the manifest
  (`629e51de…145afc`), and `cursor-agent --version` printed
  `2026.10.01-e373342`.
- **Isolation.** Ran `cursor-agent acp` with a fresh empty `HOME` (and XDG/TMP
  directories under it), a minimal `PATH`, and a `sandbox-exec` profile that
  denies outbound IP traffic. No real Cursor login or credentials were used.
- **Live wire.** Live checks covered `initialize` with several
  capability shapes and an unauthenticated `session/new`.
- **Source reading.** Everything after `initialize` needs an
  authenticated Cursor account. Those shapes come from the shipped bundle's
  ACP modules (`src/acp/cursor-acp-agent.ts`, `agent-session.ts`,
  `session-resources.ts`, `subagent-history.ts`,
  `subagent-completion-drain.ts`, `session-update-presenter.ts`,
  `types.ts`, all in `3351.index.js`).

Status per fact: **live** = observed on the wire; **source** = read from the
pinned build's code, not observed live.

## 1. Capability negotiation

| `clientCapabilities` sent | `agentCapabilities.sessionCapabilities` | Status |
|---|---|---|
| no sub-agent field (today's Sesori) | `{"list":{}}` | live |
| `_meta: {"subagents": true, …}` | `{"list":{},"subagents":{}}` | live |
| `_meta: {"subagents": {}}` | `{"list":{},"subagents":{}}` | live |
| top-level `subagents: {}` | `{"list":{}}` (not enabled) | live |
| top-level `subagents: true` | `{"list":{}}` (not enabled) | live |

- Cursor's predicate accepts both `subagents` and `_meta.subagents`, each when
  it is `true` or an object (`types.ts` `h`). However, the bundled ACP SDK
  parses `ClientCapabilities` as a schema object with only
  `_meta`/`fs`/`terminal`, so a top-level `subagents` key is stripped before
  `initialize` sees it.
- **Only `_meta.subagents` works on this build.** This matches the plan's
  Step 10 default: add `"subagents": true` to `CursorBinary.acpCapabilityMeta`
  without a shared `buildClientCapabilities` change or a per-plugin getter.
- The rest of the initialize response is unchanged: protocol `1`,
  `loadSession: true`, auth method `cursor_login`.
- The capability is per connection. `initialize` stores it on the agent, and
  every `session/new` and `session/load` on that process inherits it.
- Unauthenticated `session/new` returns `-32000 "Authentication required"`
  (live), so nothing past `initialize` could be exercised.

## 2. Child creation and link (source)

Children are announced as a **`session/update` on the parent session**, not as
an extension method:

```json
{"sessionId": "<parentSessionId>",
 "update": {"sessionUpdate": "subagent_spawned",
            "subagentSessionId": "<childSessionId>",
            "name": "<subagentType or 'subagent'>",
            "task": "<task title or ''>",
            "capabilities": {},
            "_meta": {"cursor": {"toolCallId": "<parent Task toolCallId>",
                                  "agentId": "<agentId>",
                                  "model": "<model, only when known>"}}}}
```

- **Child session id.** It is the sub-agent's `agentId` on its first run. When
  a finished child is resumed (a later Task call with `resume`/`agentId`),
  each new run gets `<agentId>.<n>` (n = 2, 3, …) and a new `subagent_spawned`.
- **Parent.** The `sessionId` is the session that launched the child: the root
  session, or a running child's session id for nested sub-agents.
- **Task link.** The link to the parent Task tool call is
  `_meta.cursor.toolCallId`. The parent's ordinary `tool_call` /
  `tool_call_update` for the Task tool (kind `other`) is still emitted.
- **Announcement timing.** Announcement waits for the run-started event
  (task/model known), not the earlier session-created event. A child that
  finishes before it was announced is announced immediately before its
  terminal state.
- **Ordering.** Frames for one child are serialized through a per-child queue.

## 3. Child updates (source)

- Each announced child has its own presenter bound to `<childSessionId>`.
  Child text (`agent_message_chunk`), thinking (`agent_thought_chunk`) and
  tools (`tool_call`, `tool_call_update`) arrive as ordinary `session/update`
  frames whose `sessionId` is the **child** session id.
- No `user_message_chunk` carrying the task prompt is emitted for the child.
  The prompt only appears in the parent's Task tool input (and the `task`
  title).
- Permission requests that originate in a child (web search, web fetch) use
  `session/request_permission` with the child's session id. Interactive
  questions inside a child are auto-rejected ("not supported in ACP subagent
  mode"), and so are mode-switch requests from a child.
- **Legacy extension.** `cursor/task` is still sent when the parent's Task tool
  call completes (`session-update-presenter.ts`, not gated on the capability).
  Step 10 must drop or ignore it on capability-enabled connections, or each
  task renders twice.

## 4. Terminal state (source)

```json
{"sessionId": "<parentSessionId>",
 "update": {"sessionUpdate": "subagent_state_update",
            "subagentSessionId": "<childSessionId>",
            "state": "completed | failed | cancelled | disconnected",
            "_meta": {"cursor": {"toolCallId": "…", "agentId": "…", "model": "…"}}}}
```

- **Live state mapping.** `completed` → `completed`, `error` → `failed`,
  `aborted` → `cancelled`. A child moved to the background sends no state
  update until it really finishes.
- **`disconnected`.** Emitted when the cancel cascade times out (see 5), and in
  replay for runs whose final status is unknown or still running.
- **No running state.** No `running` state update is sent; `subagent_spawned`
  implies running.
- **Background children hold the prompt open.** With the capability enabled,
  the root `session/prompt` does not return while background sub-agents are
  still running. After the main turn it drains their completions, runs
  follow-up turns on the root, and only then answers `end_turn`. Without the
  capability this drain is skipped.

## 5. Cancel semantics (source)

- `session/cancel` is resolved only against root sessions. A child session id
  is not in the session map, so cancelling it is a **silent no-op**; there is
  no per-child cancel.
- **Root cascade.** Cancelling the root (capability enabled) aborts the
  current turn's running children, then waits up to **10 s** for every child
  of that turn to reach a terminal state.
  - Children that finish in time send their real state (usually `cancelled`).
  - On timeout each remaining child gets `subagent_state_update` `disconnected`.
  - Only after this does the root prompt answer `{"stopReason":"cancelled"}`.
- **Step 10 consequence.** The scoped-stop capability can honestly offer only
  root stop with a confirmed child cascade, not individual child stop. The
  root-cancel confirmation and surviving-child check can be backed by
  `AcpChildSessionTracker` reaching terminal states before the prompt
  response.

## 6. `session/load` replay (source)

- **What replays.** When the loading connection negotiated the capability,
  each replayed Task tool call (`toolCallId` = `replay-<turn>-<index>`, the
  same id as the replayed parent tool call) is followed by:
  - `subagent_spawned`, with the same shape as live and the parent = the
    loaded root;
  - immediately after, `subagent_state_update` with a terminal state.
- **Replay state source.** It comes from the conversation's recorded sub-agent
  run (`SUCCESS`/`ERROR`/`ABORTED` → completed/failed/cancelled;
  running/backgrounded/unspecified → `disconnected`). With no recorded run, it
  falls back to the Task tool result: success → `completed` (background →
  `disconnected`), error → `failed`, otherwise `disconnected`.
- **No child transcript.** Replay sends no text, tools or thinking with the
  child session id; only the lifecycle is replayed.
- **Old sessions.** Replay is not gated on when the session was created, only
  on the loading connection's capability and on the Task call carrying an
  `agentId` (in its result or `agentId`/`resume` args).
  - Sessions created before Sesori advertises the capability replay natively
    whenever their stored Task calls carry an `agentId`.
  - Whether Cursor stored `agentId` in older transcripts was not verified (no
    authenticated account). `cursor/task` is still emitted during replay for
    every completed Task call.

## Unverified (needs an authenticated Cursor account)

- Observing any of sections 2–6 live: a real `subagent_spawned` /
  `subagent_state_update` pair, child streaming, a root cancel cascade, and a
  reload of a session that ran a sub-agent.
- Whether `session/load` on a **child** session id returns that child's
  transcript, and whether `session/list` lists child sessions.
- Whether pre-capability Cursor transcripts carry `agentId` on Task calls,
  which decides if old sessions' sub-agents replay natively.

These rows stay in the plan's L2 matrix (Cursor sub-agent live, after reload,
and stop) and the Cursor-scoped L3 tile check. Step 10 implements against the
source-derived shapes above and must confirm them live, or record the gap under
the plan's retirement gate.

## Implications for Step 10

- **Capability.** Add `"subagents": true` to `CursorBinary.acpCapabilityMeta`.
  The standard field does not work on the pinned build, but no per-plugin
  getter is needed either.
- **Mapping hook.** Cursor's spawn and finish arrive as `session/update` kinds
  `subagent_spawned` / `subagent_state_update`, not as an extension method.
  - `AcpEventMapper.map` currently drops unknown `sessionUpdate` kinds, and
    `mapExtension` only sees non-`session/update` methods.
  - Step 10 therefore needs a mapper hook for these update kinds that feeds
    `mapChildSpawned` and the finish calls. Its plan and review should settle
    where that hook lives before implementation.
  - Link the child to the parent Task card through `_meta.cursor.toolCallId`.
- **Task card.** Recognize the parent's Task `tool_call` via
  `isSubagentSpawnToolCall`, and ignore `cursor/task` when the capability is
  on.
- **Child prompt.** The child's prompt is not echoed as a `user_message_chunk`.
  Take it from the Task call's input or the `task` title.
- **Stop.** Use root-only stop with the 10 s confirmed cascade. Child session
  ids cannot be cancelled individually.
- **Cleanup.** The replay-cleanup decision (delete or keep
  `cursor_task_dto`, `cursor_task_mapper`, `cursor_task_replay_tracker`)
  depends on the unverified `agentId`-in-old-transcripts question. Without
  live evidence, the plan's conservative branch (keep those three) applies.
