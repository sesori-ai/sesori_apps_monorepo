# Pi RPC And Runtime Protocol: Ground Truth

## Status And Sources

- **State:** researched from official docs/source and a live standalone binary.
- **Pinned baseline:** Pi Agent Harness `v0.84.1`.
- **Published:** 2026-08-07.
- **Observed:** 2026-08-10 on macOS using the official x64 archive.
- **Repository:** `https://github.com/earendil-works/pi`.
- **Primary docs:** `packages/coding-agent/docs/rpc.md`,
  `packages/coding-agent/docs/session-format.md`, and the package README.
- **Primary source:** `rpc-types.ts`, `rpc-mode.ts`, `json-event.ts`,
  `agent-session.ts`, `agent-session-runtime.ts`, `session-manager.ts`,
  `main.ts`, and `scripts/build-binaries.sh` at tag `v0.84.1`.

Official docs and source disagree in a few places. This document records source
behavior where they differ. Step 2 rechecks the selected implementation pin,
and Step 14 records live authenticated traces with all content redacted.

## 1. Identity And Version

- Binary: `pi` (`pi.exe` on Windows).
- Version command: `pi --version` or `pi -v`.
- `v0.84.1` output observed: exactly `0.84.1` on stdout, exit 0 (a Bun CPU
  warning may appear on stderr in constrained x64 environments).
- npm package: `@earendil-works/pi-coding-agent@0.84.1`.
- npm engine: Node >=22.19.0. The managed integration does not use npm.
- License: MIT.

The RPC protocol has no version handshake and no capability-negotiation frame.
The bridge version-gates the executable before launch and absorbs unknown
frames/content variants.

## 2. Invocation

Base invocation:

```text
pi --mode rpc --approve <session-selection>
```

Session selection:

```text
# New, caller-owned ID
--session-id <id>

# Resume, always an absolute path
--session </absolute/path/to/session.jsonl>

# Parent fork into process cwd with caller-owned ID
--fork </absolute/path/to/parent.jsonl> --session-id <id>

# Discovery only, no persistence
--no-session
```

Session ID grammar from `assertValidSessionId`:

```text
^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$
```

Important constraints:

- `--fork` rejects `--session`, `--continue`, `--resume`, and `--no-session`.
- `--session-id` rejects `--session`, `--continue`, and `--resume`.
- `--fork` plus `--session-id` is explicitly valid.
- RPC rejects `@file` CLI arguments. Images travel in the prompt command.
- Bare `--session <id>` can trigger an interactive cross-project confirmation
  on stdin. The plugin must always use an absolute file path.
- `--approve` trusts project-local `.pi` settings/resources/extensions. This is
  an explicit product decision and must be present on real and discovery
  processes.
- Process cwd is the new/forked session cwd. A resumed session's header cwd
  becomes the effective runtime/tool cwd.

Environment policy:

- Inherit provider credentials and Pi's normal config/session/package
  overrides.
- Set `PI_SKIP_VERSION_CHECK=1` for supervised processes.
- Do not force `PI_OFFLINE`; it changes model/package behavior.
- Do not force `PI_TELEMETRY`; preserve the user's Pi setting.
- Never override `HOME`; Sesori code resolves it with
  `resolveUserHomeDirectory` when metadata scanning needs a default path.

## 3. Framing

- stdin commands: one JSON object followed by LF (`\n`).
- stdout responses/events: one JSON object followed by LF.
- Split only on LF.
- Accept CRLF input by removing one trailing `\r` from the record.
- Do not split on bare CR, U+2028, or U+2029.
- UTF-8 chunks may split a multi-byte character or contain many records.
- stderr is diagnostic only and never part of framing.

Pi applies stdout backpressure to the agent. The bridge must install one
unconditional stdout consumer as soon as the process starts and continue
draining unknown/ignored events.

## 4. Command And Response Envelope

Every command accepts optional string `id`:

```json
{"id":"sesori-1","type":"get_state"}
```

Success:

```json
{"id":"sesori-1","type":"response","command":"get_state","success":true,"data":{}}
```

Failure:

```json
{"id":"sesori-1","type":"response","command":"get_state","success":false,"error":"..."}
```

Parse failure uses `command: "parse"` and no request ID.

Response error strings are not typed. The plugin classifies only demonstrated
preflight/auth/process cases and otherwise preserves the original error as a
local cause while sending privacy-safe presentation upward.

### Prompt acceptance ordering

`prompt` is special. Its handler starts asynchronous preflight and returns no
immediate response from the command switch. The success response is emitted by
the preflight callback. Agent events may therefore arrive before or after the
matching prompt response.

Rules:

- Correlate only by `id`; never infer from output order.
- `success: true` means accepted, queued, or handled by an extension command.
- A pre-acceptance failure emits one `success: false` response.
- A post-acceptance model/tool/provider failure emits events/messages, not a
  second response.

## 5. Commands Used By Sesori

### Prompt and control

```json
{"id":"p1","type":"prompt","message":"text","images":[]}
{"id":"a1","type":"abort"}
```

When Pi itself is already streaming, `prompt` requires
`streamingBehavior: "steer" | "followUp"`. The planned plugin serializes its
own exact per-turn selection and normally dispatches only while idle.

Pi also exposes `steer` and `follow_up`, but Sesori has no separate steering UI
in this series.

`abort` aborts retry/current agent work and waits for idle. It does not call
Pi's `clearQueue()`, so hidden steering/follow-up queues survive. Sesori tears
the process down after abort.

### State

```json
{"id":"s1","type":"get_state"}
```

Response data fields:

```text
model, thinkingLevel, isStreaming, isCompacting,
steeringMode, followUpMode, sessionFile, sessionId, sessionName,
autoCompactionEnabled, messageCount, pendingMessageCount
```

Observed no-auth/no-session state in the official binary used an `unknown`
model and returned an empty available-model list. Implementations must also
handle upstream startup exiting before RPC when no model is selected.

### Models and thinking

```json
{"id":"m1","type":"get_available_models"}
{"id":"m2","type":"set_model","provider":"anthropic","modelId":"..."}
{"id":"t1","type":"get_available_thinking_levels"}
{"id":"t2","type":"set_thinking_level","level":"high"}
```

Closed thinking vocabulary in `v0.84.1`:

```text
off, minimal, low, medium, high, xhigh, max
```

`get_available_thinking_levels` describes the currently selected model.
Enumerate exact levels by selecting each model in a `--no-session` process so
model/thinking change entries are never persisted.

### Commands

```json
{"id":"c1","type":"get_commands"}
```

Source shape in `v0.84.1`:

```json
{
  "name":"skill:example",
  "description":"...",
  "source":"extension|prompt|skill",
  "sourceInfo":{}
}
```

The prose RPC doc still shows older `location`/`path` fields. Source
`sourceInfo` is authoritative. Built-in TUI commands are absent and cannot be
sent through this catalog.

Invoke an available command through ordinary prompt text:

```json
{"id":"c2","type":"prompt","message":"/command arguments"}
```

An extension command may complete entirely during prompt preflight and emit no
`agent_start`/`agent_settled` pair.

### History/tree

```json
{"id":"h1","type":"get_entries"}
{"id":"h2","type":"get_entries","since":"entry-id"}
{"id":"h3","type":"get_tree"}
```

`get_entries` response:

```json
{"entries":[],"leafId":"entry-id-or-null"}
```

Entries are append order and include pre-compaction history and abandoned
branches. Walk parent links from `leafId` to replay only the active branch.
Unknown `since` returns `success: false`.

The pinned file loader rebuilds its leaf as the last valid parsed entry. A
read-only file fallback can reproduce that active branch without model/auth
startup and must apply the loader's v1-v3 migration semantics in memory.

### Rename

```json
{"id":"n1","type":"set_session_name","name":"New title"}
```

Name is trimmed, newline-normalized, and appended as a `session_info` entry.
Empty names are rejected.

## 6. Event Stream

Top-level event types include agent/turn/message start-update-end, tool/bash
execution, queue updates, compaction/retry/summarization lifecycle,
`entry_appended`, `session_info_changed`, `thinking_level_changed`,
`extension_error`, `extension_ui_request`, and final `agent_settled`.

Typical order is `agent_start` -> `turn_start` -> user/assistant message frames
and tool execution -> `turn_end` -> `agent_end` -> `agent_settled`.

The exact tool/message interleaving can vary with sequential versus parallel
tool execution and provider behavior. Correlate by message content index and
tool call ID, not adjacency.

### Completion

- `agent_end` ends one low-level run and includes `willRetry`.
- Retry, compaction recovery, or queued continuation may follow.
- `agent_settled` means no automatic continuation remains. It is the only true
  completion/idle signal for Sesori.

### Message streaming

`message_start` and `message_end` carry an `AgentMessage`.

`message_update` intentionally omits cumulative message snapshots and strips
the upstream `partial` field. It carries one `assistantMessageEvent`:

```text
text_start(contentIndex)
text_delta(contentIndex, delta)
text_end(contentIndex, content)
thinking_start(contentIndex)
thinking_delta(contentIndex, delta)
thinking_end(contentIndex, content)
toolcall_start(contentIndex)
toolcall_delta(contentIndex, delta)
toolcall_end(contentIndex, toolCall)
```

The full tool ID/name/arguments are guaranteed at `toolcall_end`; start/delta
do not carry the stripped cumulative snapshot. `message_end.message` is final
authority.

### Tool execution

Start:

```json
{"type":"tool_execution_start","toolCallId":"...","toolName":"bash","args":{}}
```

Update:

```json
{"type":"tool_execution_update","toolCallId":"...","toolName":"bash","args":{},"partialResult":{}}
```

`partialResult` is cumulative. Replace displayed output on each update.

End:

```json
{"type":"tool_execution_end","toolCallId":"...","toolName":"bash","result":{},"isError":false}
```

Tool result content is an array of text/image blocks plus optional details and
usage. Apply existing Sesori output and inline-attachment limits.

### Retry and compaction

- `auto_retry_start`: attempt, maxAttempts, delayMs, errorMessage.
- `auto_retry_end`: success, attempt, optional finalError.
- `compaction_start`: reason `manual|threshold|overflow`.
- `compaction_end`: result or errorMessage, aborted, willRetry.
- summarization retry events can occur around compaction/branch summaries.

Raw provider error text can contain request details. Map typed/bounded status to
the phone and retain useful raw diagnostics only in local logs when appropriate.

## 7. Message And Entry Shapes

### Session header

First parsed session line:

```json
{
  "type":"session",
  "version":3,
  "id":"session-id",
  "timestamp":"ISO-8601",
  "cwd":"/absolute/project",
  "parentSession":"/optional/parent.jsonl"
}
```

Session versions:

- v1: linear legacy, no version field;
- v2: tree IDs/parent IDs;
- v3: current, custom-message role naming.

Pi migrates old sessions when opened. The metadata scanner accepts old headers
without mutating them.

### Entry base

Every non-header entry has:

```text
type, id, parentId, timestamp
```

Known entry types:

```text
message
thinking_level_change
model_change
compaction
branch_summary
custom
custom_message
label
session_info
```

### Agent messages

User:

```text
role: user
content: string | [text|image]
timestamp: unix milliseconds
```

Assistant:

```text
role: assistant
content: [text|thinking|toolCall]
api, provider, model, usage, stopReason, errorMessage?, timestamp
```

Stop-reason values:

```text
pending, stop, length, toolUse, error, aborted, deferred
```

Tool result:

```text
role: toolResult
toolCallId, toolName, content, details?, usage?, isError, timestamp
```

Other roles:

```text
bashExecution
custom
branchSummary
compactionSummary
```

Message IDs are not part of Pi's base user/assistant message objects. Session
entry IDs are stable in replay, while live frames arrive before the entry ID is
reported. Sesori uses a plugin-local deterministic timestamp identity and tests
live/replay equality.

### Session naming and persistence

- Explicit names are latest `session_info.name`; trimmed empty explicitly clears
  the name.
- Default session files live under
  `~/.pi/agent/sessions/--<encoded-cwd>--/<timestamp>_<id>.jsonl`.
- `PI_CODING_AGENT_DIR`, `PI_CODING_AGENT_SESSION_DIR`, and settings can alter
  roots.
- A new persisted session computes its path immediately but does not create the
  file until an assistant message exists.
- File deletion is Pi's documented session deletion mechanism.

Catalog privacy rule: do not use first user message as a Sesori title and do not
decode message content merely to enumerate sessions.

## 8. Models And Providers

Model object fields:

```text
id, name, api, provider, baseUrl, reasoning,
input, contextWindow, maxTokens, cost
```

`input` may contain `text` and `image`. The RPC prompt `images` field is an
array of:

```json
{"type":"image","data":"base64","mimeType":"image/png"}
```

RPC image input is inserted directly into the user message. Pi's CLI `@file`
resize path is separate and unavailable in RPC. Sesori applies its own existing
attachment bounds before sending.

Provider auth type is not included in model objects. The plugin maps known
provider identities for presentation and uses `unknown` auth type.

## 9. Extension UI

Dialog requests on stdout:

```text
select:  id, title, options[], timeout?
confirm: id, title, message, timeout?
input:   id, title, placeholder?, timeout?
editor:  id, title, prefill?
```

Responses on stdin:

```json
{"type":"extension_ui_response","id":"...","value":"..."}
{"type":"extension_ui_response","id":"...","confirmed":true}
{"type":"extension_ui_response","id":"...","cancelled":true}
```

Fire-and-forget requests:

```text
notify
setStatus
setWidget
setTitle
set_editor_text
```

Dialog promises live only in an in-process map. They cannot be re-enumerated or
answered after process replacement. Select, confirm, and input timeouts
auto-resolve inside Pi; editor has no upstream timeout. The plugin owns editor
expiry and mirrors the other timeouts to remove the phone card.

Pi RPC declares `ctx.mode == "rpc"` and `ctx.hasUI == true`, but terminal-only
custom components, headers/footers, theme changes, raw input, and editor
inspection are unavailable or no-ops.

## 10. Authentication

Supported sources include:

- provider environment variables;
- `~/.pi/agent/auth.json`;
- subscription OAuth written by interactive `/login`;
- custom provider configuration/extensions; and
- `--api-key` (not used by Sesori because command-line secrets are unsafe).

There is no generic RPC login command.

`pi auth check` requires a provider or model:

```text
pi auth check --provider <id> --json [--no-refresh]
```

Shape:

```json
{"status":"ready|not_ready|invalid","provider":"...","reason":"..."}
```

Setup validates runtime only because it has no project cwd. Authentication is
classified by approved project-scoped discovery or prompt preflight, where
custom providers and models are loaded.

Action hint is local: run Pi, execute `/login`, then refresh setup. Auth output
may contain credentials/account data and is never logged or forwarded.

## 11. Official Standalone Distribution

Release URL template:

```text
https://github.com/earendil-works/pi/releases/download/v<version>/<asset>
```

`v0.84.1` assets and SHA-256 values are recorded in `PLAN.md`.

Archive layout:

- macOS/Linux `.tar.gz`: wrapper directory `pi/`, entry `pi/pi`.
- Windows `.zip`: flat package, entry `pi.exe`.

Published siblings include asset/theme/export/native/module trees, docs,
examples, package metadata, and `photon_rs_bg.wasm`.

The release script builds x64 Bun baseline targets and arm64 targets. No other
OS/architecture assets are promised. Managed capability is absent outside the
six published targets.

Pi's own startup network features:

- version check, disabled by `PI_SKIP_VERSION_CHECK=1`;
- install/update telemetry, controlled by user setting or `PI_TELEMETRY`; and
- model/package refresh, disabled only by `PI_OFFLINE`.

Sesori owns managed version updates but preserves the latter two user/runtime
choices.

## 12. Verification Still Required During Implementation

- Refresh all source facts against the exact managed pin selected in Step 11.
- Capture redacted authenticated event ordering and model readiness for API-key,
  OAuth, and extension-defined providers.
- Verify cross-platform custom roots and all six assets, including one live host
  install; verify missing worktrees and imported-parent identity/path mapping.
- Verify extension dialogs, editor-prefill degradation, supported inline image
  MIME/size handling, and visible rejection of other attachment variants.
- Measure cold start/RSS before choosing idle reap; add no process pool without
  evidence.
- Perform the documented terminal-to-Sesori handoff, never concurrent writers.
