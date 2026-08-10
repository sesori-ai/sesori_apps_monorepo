# Claude Code stream-json Protocol: Ground Truth

## Status

- **State:** verified against a live CLI. Sections below are observed fact unless
  explicitly marked **OPEN**.
- **Pinned CLI version:** `2.1.221 (Claude Code)`.
- **Cross-checked against:** `@anthropic-ai/claude-agent-sdk@0.3.221`
  (`package/sdk.d.ts` for declared shapes, `package/sdk.mjs` for the exact
  argument vector the SDK builds). The SDK patch number tracks the CLI's.
- **Observed on:** 2026-08-04, macOS (darwin 25.6.0), account on a `max`
  subscription with first-party (`claude.ai` OAuth) auth.
- **Method:** a Python driver held one long-lived process open over stdio,
  recorded every frame verbatim, and answered control requests. Captures live in
  the session scratchpad, not in the repository — transcript and prompt content
  is user data.

This document is the single source of wire truth for the plugin. Later steps
cite it instead of re-deriving shapes. When a later observation contradicts it,
replace the text here and record the correction in `TRACKER.md` under Findings
And Plan Deltas.

## 1. Invocation

**Verified.** The working invocation is:

```
claude -p --input-format stream-json --output-format stream-json \
       --verbose --include-partial-messages \
       --permission-prompt-tool stdio \
       [--permission-mode <mode>] [--model <id>] [--effort <level>] \
       [--session-id <uuid> | --resume <uuid>]
```

Load-bearing details, each observed:

- **`-p` / `--print` is mandatory.** `--input-format`, `--output-format`,
  `--include-partial-messages`, and `--forward-subagent-text` are all documented
  as "only works with `--print`". The plan's original research omitted it.
- **`--permission-prompt-tool stdio` is REQUIRED to receive permission
  requests.** This is the single most important finding. The flag does not
  appear in `claude --help`; it was found in `sdk.mjs`, which builds
  `if (canUseTool) push("--permission-prompt-tool", "stdio")`. Empirically:
  - without it, a permission-gated tool is **silently auto-denied**. No
    `control_request` is emitted, the turn completes `subtype: "success"`, and
    the only trace is an entry in `result.permission_denials`;
  - an `initialize` control request alone does **not** enable prompts;
  - with it, `can_use_tool` arrives as documented in section 5.

  A plugin that omits this flag would appear to work while every write, edit,
  and command was refused. Its presence is not optional and must have a test.
- **The process exits when stdin closes.** Keeping stdin open is what makes the
  process long-lived across turns. This is the residency mechanism.
- cwd is the session's directory; one process serves exactly one session.
- The bridge's environment is inherited. `HOME` is **never** overridden — doing
  so breaks macOS keychain lookup and reports a logged-in user as logged out.
  `CLAUDE_CONFIG_DIR` is for test isolation only.
- **The SDK joins id flags with `=`.** `sdk.mjs` emits `--resume=${id}` *and*
  `--session-id=${id}`, both single tokens. The CLI accepts the two-token form
  too, so this is parity rather than correctness — but the launch spec matches
  the SDK on both flags so there is one less place to drift.

**OPEN:** the auto-update and telemetry environment variables to set for a
supervised child. Not yet probed; resolve before the descriptor lands.

### Flags relevant to this plugin

| Flag | Status | Note |
|---|---|---|
| `--session-id <uuid>` | verified | Must be a valid UUID. Pre-binds a new session's id. |
| `--resume [value]` | verified | Resumes by session id. |
| `--fork-session` | verified present | Out of scope. |
| `--effort <level>` | verified | `low`, `medium`, `high`, `xhigh`, `max`. |
| `--agent <agent>` | verified present | Selects a first-party agent. See section 6. |
| `--permission-mode <mode>` | verified | Choices differ from the control API — see section 6. |
| `--forward-subagent-text` | verified present | Opt-in; forwards subagent text/thinking with `parent_tool_use_id` set. Not used in v1. |
| `--replay-user-messages` | verified present | Re-emits stdin user messages on stdout for acknowledgment. Candidate for `sendPrompt` acceptance. |
| `--include-hook-events` | verified present | Not used. |
| `--no-session-persistence` | verified present | Must **not** be used — it disables the transcripts the catalog enumerates. |

## 2. Stdout Message Types

**Verified.** One JSON object per line. Every frame carries `uuid` and
`session_id`.

| `type` | Observed key fields | Maps to |
|---|---|---|
| `system` / `init` | `session_id`, `model`, `permissionMode`, `capabilities`, `tools`, `slash_commands`, `agents`, `skills`, `plugins`, `mcp_servers`, `output_style`, `apiKeySource`, `claude_code_version`, `cwd`, `memory_paths`, `uuid` | init handshake, capability detection |
| `system` / `status` | `status` (e.g. `"requesting"`) | work-state signal |
| `rate_limit_event` | `rate_limit_info` = `{status, resetsAt, rateLimitType, overageStatus, overageDisabledReason, isUsingOverage}` | rate-limit surface |
| `assistant` | `message` (full Anthropic message), `parent_tool_use_id`, `timestamp`, `request_id` | complete message envelope plus parts |
| `user` | echoed message; carries `tool_result` blocks | tool completion, matched by `tool_use_id` |
| `stream_event` | `event` (raw Anthropic SSE), `parent_tool_use_id`, `uuid`, `ttft_ms` on `message_start` | live part deltas |
| `result` | see below | turn end |
| `control_request` | `request_id`, `request.subtype` | permissions and questions |
| `control_response` | `response.subtype`, `response.request_id`, `response.response` | replies to our requests |

`rate_limit_event` and `system/status` were **not** in the plan's research. They
confirm why tolerant unknown-type absorption is mandatory rather than defensive.

**`system`/`init` is turn-triggered, not spawn-triggered.** Verified in Step 3 by
driving the real CLI through `ClaudeStreamClient`: after `connect()` completed
its `initialize` handshake in ~1.1 s, no `init` frame had arrived two seconds
later, and the only frame seen was the handshake's own control response. The
Step 2 captures agree — `init` appears after the first user turn is written.

Consequences:

- The `initialize` control **response** is the only connect-time catalog. Nothing
  in the connect path may require `init`.
- `init.capabilities` — and therefore capability detection — is unavailable until
  a turn has run. For `interrupt.cancel_queued` this is harmless: the SDK
  documents that older CLIs ignore the field and behave as if it were false, so
  it can always be sent rather than gated on a capability that may not have
  arrived yet.
- `init.permissionMode` likewise cannot be read before the first turn; the
  launch flag is the authority for the starting mode.

### `stream_event` inner events

Observed for a plain text turn, in order: `message_start`,
`content_block_start`, `content_block_delta` (×N, `delta.type = "text_delta"`),
`content_block_stop`, `message_delta` (carries `stop_reason` and final usage),
`message_stop`.

**Ordering trap, verified:** the complete `assistant` envelope arrives
**before** `content_block_stop` / `message_delta` / `message_stop`, not after
the stream events. The mapper must not assume "all deltas, then the complete
message".

**Model id trap, verified:** `init.model` was `claude-opus-5[1m]` while the same
turn's `message_start.message.model` and `assistant.message.model` were
`claude-opus-5`. The `[1m]` context-window suffix is a *selection* token, not
the resolved model. Stamp message envelopes from `message.model`; use the
catalog's `resolvedModel` when mapping a selection back to a display name.

### `result`

Observed keys: `subtype`, `is_error`, `result`, `stop_reason`,
`terminal_reason`, `duration_ms`, `duration_api_ms`, `time_to_request_ms`,
`ttft_ms`, `ttft_stream_ms`, `num_turns`, `total_cost_usd`, `usage`,
`modelUsage`, `api_error_status`, `permission_denials`, `fast_mode_state`,
`fast_mode_disabled_reason`, `session_id`, `uuid`.

A successful turn is `subtype: "success"`, `is_error: false`,
`stop_reason: "end_turn"`, `terminal_reason: "completed"`.

`permission_denials` is an array of `{tool_name, tool_use_id, tool_input}`. It
is populated when a tool was refused **without** the host being asked — the
silent-denial signature described in section 1.

The pinned SDK declares error subtypes `error_during_execution`,
`error_max_turns`, `error_max_budget_usd`, and
`error_max_structured_output_retries`. Its `TerminalReason` union is the typed
source for terminal classification; unknown additions degrade to a generic
error rather than being matched as strings above the transport boundary.

Step 8 captured two terminal failures live against CLI 2.1.226:

- A minimal positive `--max-budget-usd` emitted `subtype:
  "error_max_budget_usd"`, `is_error: true`, `terminal_reason:
  "budget_exhausted"`, and an `errors` string list.
- An unavailable model emitted the protocol's non-obvious API-error shape:
  `subtype: "success"`, `is_error: true`, `terminal_reason: "api_error"`, and
  `api_error_status: 404`. The preceding assistant frame carried
  `error: "model_not_found"` and a synthetic explanatory message.

The event mapper therefore treats `is_error` as authoritative even when the
subtype says success. It never forwards raw `result` or `errors` strings into
the error envelope because backend failures may echo request details; it maps
typed terminal reasons and HTTP status to bounded, privacy-safe presentation.

### `system`/`api_retry`

The pinned SDK declares this required shape (no matching local transcript was
found during the redacted structural survey):

```ts
{
  type: 'system', subtype: 'api_retry', attempt: number,
  max_retries: number, retry_delay_ms: number,
  error_status: number | null, error: SDKAssistantMessageError,
  uuid: string, session_id: string
}
```

`error` is a closed category such as `rate_limit`, `overloaded`,
`authentication_failed`, or `server_error`, not free-form text. The mapper
uses that category for a privacy-safe retry status and converts
`retry_delay_ms` into the absolute epoch-millisecond `SessionStatus.retry.next`
value expected by the existing client contract.

## 3. Stdin Message Types

**Verified.** The following were accepted by the pinned CLI:

- User turn — `session_id` may be included and was accepted:
  ```json
  {"type":"user","message":{"role":"user","content":[{"type":"text","text":"…"}]},"session_id":"…"}
  ```
- Control request:
  ```json
  {"type":"control_request","request_id":"init-1","request":{"subtype":"initialize"}}
  ```
- Control response (answering `can_use_tool`):
  ```json
  {"type":"control_response","response":{"subtype":"success","request_id":"…","response":{"behavior":"deny","message":"…"}}}
  ```

`request_id` is caller-minted for requests we send (the CLI echoes it back) and
CLI-minted (a UUID) for requests it sends us.

**OPEN:** the image content-block shape has not been exercised live. The SDK
declares the standard Anthropic
`{"type":"image","source":{"type":"base64","media_type":…,"data":…}}`; verify
before the attachment gate is widened in Step 15.

### Control request subtypes

Declared in `sdk.d.ts` (names verified; only the marked ones exercised live):

`initialize` ✓, `can_use_tool` ✓ (inbound), `interrupt`, `set_model`,
`set_permission_mode`, `set_max_thinking_tokens`, `list_models`,
`rename_session`, `get_plan`, `get_workspace_diff`, `get_context_usage`,
`get_session_cost`, `get_usage`, `get_settings`, `apply_flag_settings`,
`get_binary_version`, `read_file`, `rewind_files`, `seed_read_state`,
`register_repo_root`, `set_color`, `stop_task`, `background_tasks`,
`cancel_async_message`, `cancel`, `elicitation`, `request_user_dialog`,
`file_suggestions`, `reload_plugins`, `reload_skills`, `mcp_*`.

Exact shapes for the ones this plugin uses:

```ts
{subtype: 'interrupt', cancel_queued?: boolean}
{subtype: 'set_model', model?: string | null}   // null/'default' resets
{subtype: 'set_permission_mode', mode: PermissionMode}
{subtype: 'list_models'}
{subtype: 'rename_session', title: string}
```

`interrupt.cancel_queued` also cancels queued commands and is gated by the
`interrupt_cancel_queued_v1` capability, which the observed `init.capabilities`
advertised. A Stop button sets it true so one round-trip halts the session.

## 4. The `initialize` Handshake

**Verified.** Every field of the request is optional; `{"subtype":"initialize"}`
is valid. Useful fields: `hooks`, `agents`, `systemPrompt`,
`appendSystemPrompt`, `planModeInstructions`, `toolAliases`, `title`, `skills`,
`forwardSubagentText`, `supportedDialogKinds`.

**The response is the whole catalog.** Observed top-level keys:

```
account, agents, available_output_styles, commands, fast_mode_disabled_reason,
fast_mode_state, ide_rc_auto_enable_gate, models, output_style, pid,
remote_control_auto_enable, remote_control_auto_on_by_default
```

- `commands` — 66 entries of `{name, description, argumentHint}`. This is the
  slash-command catalog; no separate probe is needed.
- `agents` — 5 entries of `{name, description}`. First-party agents. See the
  design note in section 6.
- `models` — the model catalog, shape below.
- `account` — `{apiProvider, email, organization, subscriptionType}`.
  **Contains PII.** Never log or forward it; the plugin may read only what it
  needs and must not persist the rest.
- `pid` — the CLI's process id.

One handshake therefore yields commands, agents, models, and account state
together. The catalog service needs no separate startup probes.

### `models`

```json
{
  "value": "opus[1m]",
  "resolvedModel": "claude-opus-5[1m]",
  "displayName": "Opus (1M context)",
  "description": "Opus 5 with 1M context · Best for everyday, complex tasks",
  "supportsEffort": true,
  "supportedEffortLevels": ["low", "medium", "high", "xhigh", "max"],
  "supportsAdaptiveThinking": true,
  "supportsFastMode": true,
  "supportsAutoMode": true
}
```

Five models were returned; `value: "default"` is the session default entry.
Effort support is declared **per model** — the Haiku entry carried no effort
fields at all.

**This resolves the Step 11 effort question: variants are first-party and
declared.** `supportedEffortLevels` maps directly onto codex-style
`PluginModel.variants`, default-first, with models lacking the field shipping
without variants. No hardcoded catalog and no version gate is required.

## 5. Permission Protocol

**Verified live.** With `--permission-prompt-tool stdio`, a `Write` in `manual`
mode produced:

```json
{"type":"control_request","request_id":"<uuid>","request":{
  "subtype":"can_use_tool","tool_name":"Write","display_name":"Write",
  "input":{"file_path":"…","content":"hello\n"},
  "description":"probe.txt",
  "permission_suggestions":[{"type":"setMode","mode":"acceptEdits","destination":"session"}],
  "tool_use_id":"toolu_…"}}
```

Replying `{"behavior":"deny","message":"…"}` was accepted and the turn completed
normally with the model explaining the block.

Full declared request shape (`SDKControlPermissionRequest`), with the fields the
plan's research did not have:

| Field | Meaning for the registry |
|---|---|
| `tool_name`, `display_name`, `description`, `input` | card content |
| `tool_use_id` | **links the permission to its tool part** |
| `agent_id` | set for subagent-originated asks |
| `permission_suggestions` | candidate rules for `always`, **filtered** — see the eligibility rule below |
| `blocked_path` | path that triggered the ask |
| `decision_reason` | **may contain ANSI escapes — sanitize before rendering** |
| `decision_reason_type` | typed: `rule`, `mode`, `subcommandResults`, `permissionPromptTool`, `hook`, `asyncAgent`, `sandboxOverride`, `workingDir`, `safetyCheck`, `classifier`, `other` |
| `classifier_approvable` | false = a safety check requires manual approval |
| `suppress_always_allow_rule` | **true = the host MUST NOT offer "always"** |
| `matched_ask_rule` | a user ask-rule forced this prompt |
| `requires_user_interaction` | **true = one-tap approve/deny must not be offered; the tool's own card is the interaction surface** |

Two of these change the planned design:

1. **`requires_user_interaction` replaces the hardcoded tool-name list.** The
   plan proposed bifurcating permissions from questions by matching
   `AskUserQuestion` and `ExitPlanMode` by name. The CLI declares this
   first-party. Bifurcate on the flag, not on names — it stays correct as new
   interaction-shaped tools appear.
2. **`suppress_always_allow_rule` is a hard constraint.** When set, the phone
   must not render an "always" affordance, because accepting it would write a
   rule broader than the ask's own verb.

Fixed reply mapping (unchanged by verification):

| Sesori reply | Claude response |
|---|---|
| `once` | plain `allow`; never send `updatedPermissions` |
| `always` | `allow` plus **eligible** suggestions only (below); a plain `allow` when none are eligible; not offered at all when `suppress_always_allow_rule` is set |
| `reject` | `deny` with a short message |

### `always` must filter `permission_suggestions`, not echo them

**Decided, not open.** Echoing the request's suggestions verbatim is unsafe. The
SDK's `PermissionUpdate` union (`sdk.d.ts`) has six variants and a `destination`
that reaches beyond the session:

```ts
{type:'addRules'|'replaceRules'|'removeRules', rules, behavior, destination}
{type:'setMode', mode, destination}
{type:'addDirectories'|'removeDirectories', directories, destination}

destination: 'userSettings'|'projectSettings'|'localSettings'|'session'|'cliArg'
```

The one suggestion actually observed was
`{"type":"setMode","mode":"acceptEdits","destination":"session"}` — a **session
mode change**, not a per-tool rule. A user tapping "always" on a single `Write`
means "stop asking me about this"; echoing that suggestion would instead put the
whole session into `acceptEdits`, silently auto-approving every later edit. The
same blind echo could widen the accessible directory set (`addDirectories`) or
write a rule into `userSettings`, which **outlives the session and the project**.

Eligibility rule for `always`:

- Echo **only** `addRules`.
- Echo **only** `destination: "session"`.
- Never echo `setMode`, `addDirectories`, `removeDirectories`, `replaceRules`,
  or `removeRules`.
- If nothing survives the filter, `always` sends a plain `allow` — the same
  effect as `once` for that ask. Degrading is correct: the grant the user asked
  for is not expressible, and silently granting a broader one is the failure
  this rule exists to prevent.

This satisfies Success Criterion 3 literally: `always` never escalates beyond
what the backend suggested *and* never beyond what the user asked for. The two
are not the same thing, which is the trap.

**OPEN:** live `can_use_tool` captures for `AskUserQuestion` and `ExitPlanMode`,
including whether answer keys are the full question text. Capture before Step 9.

## 6. Models, Agents, And Modes

**Verified — the CLI flag and the control API disagree on one name.**

- `--permission-mode` accepts: `acceptEdits`, `auto`, `bypassPermissions`,
  `manual`, `dontAsk`, `plan`.
- `set_permission_mode` documents: `default`, `acceptEdits`, `bypassPermissions`,
  `plan`, `dontAsk`, `auto`.

The CLI flag spells the prompt-for-dangerous-operations mode `manual`; the
control API spells it `default`. Observed `init.permissionMode` was `auto` for a
run with no flag, so **`auto` is the default**, and `auto` uses a model
classifier to approve or deny prompts. Parse both spellings at the boundary and
never hardcode one across both surfaces.

**Design collision — resolved 2026-08-04.** The plan exposes permission modes as
`PluginAgent`s named "Default" and "Plan", following the Codex
collaboration-mode precedent. Claude also has a *first-party* `agents` concept:
the initialize response returned 5 of them and `--agent` selects one, so the
word is overloaded.

The user decided the phone's agent picker drives **permission modes**, as
originally planned. Plan mode is the headline feature in scope and the thing
users toggle mid-session; Claude's own agents stay internal, dispatched by the
main agent. Surfacing the first-party agent list is a deliberate follow-up
outside this series, not an oversight.

Consequence for Step 11: the picker sends `set_permission_mode`, and the
`agents` array from the initialize response is deliberately not mapped to
`getAgents`.

## 7. Slash Commands

**Verified.** `initialize` returns 66 commands as
`{name, description, argumentHint}`, and `system/init` carries a
`slash_commands` list as well.

**OPEN:** whether sending `/command args` as ordinary turn text actually
dispatches the command in stream-json mode. Verify before Step 12 wires
`sendCommand`; if it does not, `sendCommand` degrades to a
`PluginOperationException`.

## 8. Authentication

**Verified — the preferred probe exists.** `claude auth status` defaults to JSON:

```json
{"loggedIn": true, "authMethod": "claude.ai", "apiProvider": "firstParty",
 "email": "…", "orgId": "…", "orgName": "…", "subscriptionType": "max"}
```

The plugin reads **only `loggedIn`**. Everything else is PII and must never be
logged, persisted, or forwarded. Subcommands are `login`, `logout`, `status`;
the plugin never invokes the first two.

This eliminates the planned zero-token init-probe fallback: the probe is a fast,
bounded, structured subcommand. `inspectSetup` runs `--version` first, then
`auth status`, and degrades to `PluginSetupUnknown` on timeout or unparseable
output.

## 9. Session Storage

**Verified.** Transcripts live at
`$CLAUDE_CONFIG_DIR ?? ~/.claude` + `/projects/<munged-cwd>/<session-id>.jsonl`.

Munging replaces path separators with `-`, producing names like
`-private-tmp-…-scratchpad-probe1`. It is lossy and ambiguous — **never
un-munge**.

### Most files under `projects/` are not sessions

Corrected in Step 4. The original capture came from one freshly created
single-turn transcript, which made the tree look far more uniform than it is. A
survey of a real long-lived `~/.claude` found **1,888 transcript files, of which
193 had UUID session filenames**. The rest are subagent transcripts named
`agent-<slug>-<hex>.jsonl`, sitting in the same `projects/<munged-cwd>/`
directories.

Of those 193 UUID-named candidates, 13 contained only sidechain records, leaving
**180 sessions** after both filters were applied.

So "the filename minus `.jsonl` is the session id" holds **only for files whose
stem is a UUID**. Enumerating every `.jsonl` reports roughly ten times too many
sessions, most with ids that are not ids at all.

Two independent filters are both required:

1. **The filename stem must be a UUID.** This removes the `agent-*` bulk.
2. **The records must not all be `isSidechain: true`.** Five of 120 sampled
   UUID-named files contained zero non-sidechain records — a subagent transcript
   that happens to be UUID-named. The per-record flag alone would not have caught
   the `agent-*` files, and the filename alone would not have caught these.

### Record types

The single-turn capture recorded six types. The same survey found **sixteen**,
which is the strongest evidence in this document that tolerant unknown
absorption is a requirement rather than a precaution:

`assistant`, `user`, `mode`, `last-prompt`, `attachment`, `ai-title`,
`permission-mode`, `bridge-session`, `queue-operation`, `file-history-snapshot`,
`system`, `pr-link`, `file-history-delta`, `agent-name`, `started`, `result`.

Only four carry `cwd` and `isSidechain`: `user`, `assistant`, `attachment`, and
`system`. Those four are the project-attribution and sidechain-detection
surface; everything else is metadata keyed by `sessionId` alone.

`mode` and `permission-mode` records are the persisted counterpart of the
control protocol's mode switching (section 6) and are worth revisiting at Step
11. `pr-link` carries `prNumber`/`prUrl`/`prRepository`, which the Sesori
session list already has a slot for; out of scope here, noted as a later
opportunity.

| Record | Observed keys |
|---|---|
| `user` | `cwd`, `entrypoint`, `gitBranch`, `isSidechain`, `message`, `parentUuid`, `permissionMode`, `promptId`, `promptSource`, `sessionId`, `timestamp`, `type`, `userType`, `uuid`, `version` |
| `assistant` | as above plus `effort`, `requestId`; no `promptId`/`promptSource` |
| `attachment` | `attachment`, `cwd`, `entrypoint`, `gitBranch`, `isSidechain`, `parentUuid`, `sessionId`, `timestamp`, `type`, `userType`, `uuid`, `version` |
| `ai-title` | `aiTitle`, `sessionId`, `type` |
| `last-prompt` | `lastPrompt`, `leafUuid`, `sessionId`, `type` |
| `queue-operation` | `operation`, `sessionId`, `timestamp`, `type` |

Consequences for the catalog and history mapper:

- **`ai-title.aiTitle` is the session title source.** No heuristic needed — but
  it is not always written. It was present in 143 of 180 real sessions (79%);
  the remaining fifth are genuinely untitled and map to a null `PluginSession
  .title`. `last-prompt.lastPrompt` would raise coverage to about 88%, and is
  deliberately **not** used: it is the user's own prompt text, and putting
  prompt content into a session title moves user data somewhere new for a
  9-point gain. Revisit only if untitled sessions look wrong in the Step 16
  live run.
- **`isSidechain` is the sidechain marker** — a boolean on the record itself, not
  a separate directory. Necessary but not sufficient; see the filename rule
  above.
- Every content record carries its own `cwd`, so project attribution needs no
  directory-name parsing. All 180 real sessions had one.
- `gitBranch` is present and free; `version` records the writing CLI version.
  Both were populated on all 180.
- The filename id and the records' own `sessionId` agreed on 120 of 120 sampled
  transcripts, so cross-checking them is cheap and a disagreement is a real
  anomaly worth skipping.
- `attachment` records are context attachments (memory files and similar), not
  user images.
- A full-tree shape survey before Step 6 confirmed `attachment.attachment` is
  always an internal context object: observed variants covered reminders,
  skills, plans, hooks, directory state, allowed tools, and similar CLI
  metadata. User-pasted images instead appear as `image` blocks in
  `user.message.content`, so history replay skips `attachment` records and sends
  user image blocks through the normal content mapper.
- One persisted Anthropic assistant message is commonly split across multiple
  transcript records: grouping by `message.id` found between 1 and 18 records
  per message. The top-level record `uuid` was distinct from `message.id`, so it
  is not an assistant message-id fallback.

### History shape contract

Step 6 established the history shape that Step 8 live mapping must match:

- User envelopes use the transcript record `uuid`; assistant envelopes use the
  nested Anthropic `message.id` and group every record carrying that id.
- Assistant envelopes stamp `agent: claude`, `providerID: anthropic`, and the
  nested message model. User envelopes keep `agent` null.
- `time.created` is the persisted record timestamp in epoch milliseconds and
  `time.completed` is null. Every part repeats the envelope's session and
  message ids.
- Assistant content blocks retain transcript order. A user `tool_result` record
  updates the matching assistant `tool_use` part by tool id rather than becoming
  a duplicate user or tool message.
- Sidechain, meta, transcript-only, system, attachment, unknown, and records
  without their role's persisted message identity do not produce messages.
- A missing or unreadable transcript throws `PluginOperationException`; an
  empty list means the transcript loaded but held no replayable messages.

### Enumeration cost

Reading these transcripts in full is not viable: the surveyed tree held
**1,060 MiB across 1,888 files**, median session 536 KiB, p90 ~7 MiB, largest
17.6 MiB.

Everything the catalog needs sits at the top of the file. Across 60 sampled
transcripts the `ai-title` record's line number was at most 50 (median 13), and
`cwd`/`sessionId`/`gitBranch`/`version` arrive on the first content record. A
bounded 64-line header read therefore covers the observed range with margin, and
a title written past the bound degrades to an untitled session rather than a
wrong one.

`updatedAt` cannot come from a bounded header, so it comes from the transcript's
mtime — exact for an append-only file.

Measured end to end on the surveyed tree: 37 ms to enumerate paths, **993 ms to
scan 180 session headers** inside `Isolate.run`. Acceptable for a refresh-time
operation off the main isolate; it would not be acceptable on it.

## 10. Known Traps

1. **`--permission-prompt-tool stdio` or permissions silently fail.** Section 1.
2. Never override `HOME` — it breaks keychain lookup. `CLAUDE_CONFIG_DIR` in
   tests only.
3. On Windows an npm-shim `claude.cmd` needs `runInShell`; the repository's host
   process seam already does this.
4. Unknown stream types are absorbed with a debug log, never a warning per line.
   `rate_limit_event` and `system/status` were both absent from the research and
   present in the very first capture.
5. The complete `assistant` envelope interleaves with stream events rather than
   following them.
6. `init.model` carries a selection suffix that the message model does not.
7. A signal-killed child mid-turn surfaces as interrupted, not as an error.
8. Pending permission requests must be resolved when a session stops or its
   process exits.
9. `decision_reason` may contain ANSI escapes.
10. `account` and `auth status` output contain PII.
11. Closing stdin ends the process — that is the reap mechanism, and also the
    accidental-death mechanism if the writer is careless.

## 11. Open Items

Carried into their consuming steps rather than blocking the scaffold:

| Item | Needed by |
|---|---|
| Error `result` subtypes and `terminal_reason` values | Step 8 |
| `AskUserQuestion` / `ExitPlanMode` live captures and answer-key shape | Step 9 |
| Image content-block round-trip | Step 15 |
| Slash-command dispatch in stream-json | Step 12 |
| Auto-update / telemetry environment variables | Step 13 |

## 12. Captured Fixtures

Real captures live in the session scratchpad and are **not** committed —
they contain the developer's own environment, MCP server names, account email,
and organization id. Fixtures committed into `test/` are hand-trimmed to the
fields under test, with all identifiers replaced by synthetic values, following
the house style of inline Dart map literals rather than golden files.
