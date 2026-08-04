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
  - with it, `can_use_tool` arrives as documented in section 4.

  A plugin that omits this flag would appear to work while every write, edit,
  and command was refused. Its presence is not optional and must have a test.
- **The process exits when stdin closes.** Keeping stdin open is what makes the
  process long-lived across turns. This is the residency mechanism.
- cwd is the session's directory; one process serves exactly one session.
- The bridge's environment is inherited. `HOME` is **never** overridden — doing
  so breaks macOS keychain lookup and reports a logged-in user as logged out.
  `CLAUDE_CONFIG_DIR` is for test isolation only.
- The SDK writes resume as `--resume=<id>` (single token). Both forms are
  accepted; match the SDK.

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

**OPEN:** the exhaustive `subtype` and `terminal_reason` value sets for error
turns (usage limit, auth expiry, max turns). Capture before the event mapper
maps error envelopes.

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
| `permission_suggestions` | the only rules `always` may ever echo |
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
| `always` | `allow` plus an echo of the request's own `permission_suggestions`; never a broader rule; not offered at all when `suppress_always_allow_rule` is set |
| `reject` | `deny` with a short message |

**Design note on `permission_suggestions`:** the observed suggestion was
`{"type":"setMode","mode":"acceptEdits","destination":"session"}` — a *session
mode change*, not a per-tool rule. Echoing it for `always` would switch the
whole session to auto-accepting edits, which is materially broader than "always
allow this tool". Step 9 must decide whether `always` echoes `setMode`
suggestions or only rule-shaped ones. Recommendation: echo rule-shaped
suggestions and decline to escalate on `setMode`.

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

**Design collision to resolve (Step 11/13).** The plan proposed exposing
permission modes as `PluginAgent`s named "Default" and "Plan", following the
Codex collaboration-mode precedent. But Claude has a *first-party* `agents`
concept — the initialize response returned 5 of them and `--agent` selects one.
Exposing permission modes under the same word as a real, different Claude
concept is ambiguous.

Both readings are defensible; this is a product decision, not a technical one,
and it is recorded here rather than silently chosen.

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
un-munge**. The filename minus `.jsonl` is the session id.

Observed record types in a single-turn transcript: `ai-title`,
`queue-operation`, `user`, `attachment`, `assistant`, `last-prompt`.

| Record | Observed keys |
|---|---|
| `user` | `cwd`, `entrypoint`, `gitBranch`, `isSidechain`, `message`, `parentUuid`, `permissionMode`, `promptId`, `promptSource`, `sessionId`, `timestamp`, `type`, `userType`, `uuid`, `version` |
| `assistant` | as above plus `effort`, `requestId`; no `promptId`/`promptSource` |
| `attachment` | `attachment`, `cwd`, `entrypoint`, `gitBranch`, `isSidechain`, `parentUuid`, `sessionId`, `timestamp`, `type`, `userType`, `uuid`, `version` |
| `ai-title` | `aiTitle`, `sessionId`, `type` |
| `last-prompt` | `lastPrompt`, `leafUuid`, `sessionId`, `type` |
| `queue-operation` | `operation`, `sessionId`, `timestamp`, `type` |

Consequences for the catalog and history mapper:

- **`ai-title.aiTitle` is the session title source.** No heuristic needed.
- **`isSidechain` is the sidechain marker** — a boolean on the record itself, not
  a separate directory. Exclude sidechain records from enumeration.
- Every content record carries its own `cwd`, so project attribution needs no
  directory-name parsing.
- `gitBranch` is present and free; `version` records the writing CLI version.
- `attachment` records are context attachments (memory files and similar), not
  user images.

**OPEN:** the `attachment.attachment` payload shape, and whether user-supplied
images appear as `user` message content blocks or as `attachment` records.
Resolve before Step 6.

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
| `attachment` record payload shape | Step 6 |
| Auto-update / telemetry environment variables | Step 13 |
| Permission-mode versus agent product decision | Step 11 |

## 12. Captured Fixtures

Real captures live in the session scratchpad and are **not** committed —
they contain the developer's own environment, MCP server names, account email,
and organization id. Fixtures committed into `test/` are hand-trimmed to the
fields under test, with all identifiers replaced by synthetic values, following
the house style of inline Dart map literals rather than golden files.
