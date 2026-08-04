# Claude Code stream-json Protocol: Ground Truth

## Status

- **State:** skeleton — every section below is unverified research until Step 2
  replaces it with observed ground truth.
- **Pinned CLI version:** _to be pinned in Step 2_ (development machine currently
  has `2.1.221 (Claude Code)`).
- **Supported floor (`ClaudePluginDescriptor.minVersion`):** _to be decided in
  Step 2 from the observed capability set._
- **Observed on:** _date + platform, recorded in Step 2._
- **Cross-checked against:** _Agent SDK declaration files for the matching
  release, recorded in Step 2 with the exact package version._

This document is the single source of wire truth for the plugin. Later steps cite
it instead of re-deriving shapes. When a verification finds something different
from the research below, replace the research rather than annotating around it,
and note the correction in `TRACKER.md` under Findings And Plan Deltas.

Every heading marked **UNVERIFIED** carries a hypothesis from external research
(the headless and Agent SDK documentation, the SDK's own declaration files, and
two working open-source integrations). Step 2 must turn each into either a
confirmed shape or a recorded absence — never leave a marker in place.

## 1. Invocation

**UNVERIFIED.** Hypothesis:

```
claude --input-format stream-json --output-format stream-json --verbose \
       --include-partial-messages [--model <id>] [--permission-mode <mode>] \
       [--session-id <uuid> | --resume <uuid>]
```

To record in Step 2:

- The exact accepted flag set, from `claude --help` at the pinned version.
- Whether `--verbose` is genuinely required for full stream-json output.
- Whether `--include-partial-messages` is required for token-level deltas.
- Whether `--permission-prompt-tool` (or an equivalent) is required for
  `can_use_tool` control requests to arrive on stdout, or whether registering
  callbacks in the `initialize` control request is sufficient.
- Whether an `initialize` control request must be sent before the first turn,
  and its exact payload.
- The auto-update and telemetry environment variables the pinned version honors
  for supervised children.
- Confirmation that the process stays alive between turns while stdin is open.

Fixed decisions that verification cannot change:

- cwd is the session's directory; one process serves exactly one session.
- The bridge's environment is inherited. `HOME` is **never** overridden —
  doing so breaks macOS keychain lookup and reports a logged-in user as logged
  out. `CLAUDE_CONFIG_DIR` is for test isolation only.

## 2. Stdout Message Types

**UNVERIFIED.** One JSON object per line. Hypothesised envelope set:

| `type` | Key fields | Maps to |
|---|---|---|
| `system` / `init` | `session_id`, `model`, `tools`, `slash_commands`, `mcp_servers`, `capabilities` | init handshake, command catalog, capability detection |
| `system` / `api_retry` | `attempt`, `max_retries`, `retry_delay_ms`, `error` | retry session status |
| `system` / `permission_denied` | `tool_name`, `decision_reason_type` | local log only |
| `assistant` | `message.content[]`, `parent_tool_use_id` | complete message envelope plus parts |
| `user` | echoed message; carries `tool_result` blocks | tool completion, matched by `tool_use_id` |
| `stream_event` | `event` (raw Anthropic SSE), `parent_tool_use_id`, `session_id` | live part deltas |
| `result` | `result`, `total_cost_usd`, token counts, `session_id`, error subtypes | turn end → idle or error |
| `control_request` | `request_id`, `request.subtype` | permissions and questions |
| `control_response` | reply to requests we sent | model switch, interrupt acknowledgement |

To record in Step 2: a captured real line for each type, trimmed and anonymized,
plus the full `stream_event` inner event set actually observed
(`message_start`, `content_block_start`, `content_block_delta` with its delta
variants, `content_block_stop`, `message_delta`, `message_stop`), the exhaustive
`result` subtype list, and every `system` subtype encountered.

`parent_tool_use_id != null` marks subagent traffic. Confirm which subagent
blocks are forwarded on the root process at the pinned version.

## 3. Stdin Message Types

**UNVERIFIED.** Hypothesised shapes:

- User turn:
  `{"type":"user","message":{"role":"user","content":[{"type":"text","text":…}]},
  "session_id":…}`, with images as
  `{"type":"image","source":{"type":"base64","media_type":…,"data":…}}`.
- Control response:
  `{"type":"control_response","response":{"subtype":"success","request_id":…,
  "response":{…}}}`.
- Control request:
  `{"type":"control_request","request_id":…,"request":{"subtype":"interrupt"}}`,
  plus `set_permission_mode` and `set_model` subtypes.

To record in Step 2: the exact envelope the pinned CLI accepts for each, the
exhaustive control-request subtype list it supports, whether `session_id` is
required on the user turn, and the error shape when a malformed frame is sent.

## 4. Permission Protocol

**UNVERIFIED.** Hypothesis: `can_use_tool` control requests carry `tool_name`,
`input`, and optionally `permission_suggestions`, `blocked_path`, and
`decision_reason`. The response payload is
`{"behavior":"allow"|"deny", "updatedInput":{…}, "updatedPermissions":[…],
"message":"…"}`.

Fixed mapping decisions, independent of verification:

| Sesori reply | Claude response |
|---|---|
| `once` | plain `allow`; **never** send `updatedPermissions` |
| `always` | `allow` plus an echo of the request's own `permission_suggestions` when present, else a plain allow — never a broader rule than the backend itself suggested |
| `reject` | `deny` with a short message |

Two tools are questions rather than permissions:

- **`AskUserQuestion`** — `input.questions[]` carries question, header, options,
  and multi-select, which maps onto `PluginQuestionInfo` directly. The reply is
  `allow` with `updatedInput`. **UNVERIFIED:** whether answer keys are the full
  question text at the pinned version. Research says yes for SDK ≥ 2.1.121;
  confirm against a real request before Step 9 consumes it.
- **`ExitPlanMode`** — becomes an approve-or-keep-planning question whose body is
  `input.plan`. Approve replies `allow` and then returns the permission mode to
  default; keep-planning replies `deny` with a continue-planning message.

To record in Step 2: a captured `can_use_tool` request for an ordinary tool, one
for `AskUserQuestion`, and one for `ExitPlanMode`, plus the observed effect of
each response variant.

## 5. Session Storage

**UNVERIFIED.** Hypothesis: transcripts live at
`$CLAUDE_CONFIG_DIR ?? ~/.claude` + `/projects/<munged-cwd>/<session-id>.jsonl`.

Fixed decisions:

- The munged directory name is **never** un-munged. Each transcript's own records
  supply `cwd`, timestamps, and title.
- The filename minus `.jsonl` is the session id, cross-checked against record
  content.
- Subagent sidechains are excluded from enumeration.

To record in Step 2: the exact record schema (one anonymized example per record
kind), how sidechains are marked or separated, which record supplies a usable
session title, whether a half-written trailing line is common in practice, and
whether `--session-id` reliably pre-binds a new session's id.

## 6. Models, Agents, And Modes

**UNVERIFIED.** Hypotheses:

- A model catalog is reachable from the CLI through a control request; the SDK
  exposes it as a supported-models call. If it is unusable from the CLI, derive
  from `system/init` plus a version-gated fallback list.
- `set_model` switches models mid-session and `set_permission_mode` switches
  modes.
- Permission modes are `default`, `acceptEdits`, `plan`, `bypassPermissions`, and
  possibly `dontAsk`.
- Reasoning effort may be settable per session.

Fixed decisions: only **Default** and **Plan** are exposed as agents in this
series. Applied model and agent selections are cached per resident process and
the cache is cleared on respawn.

To record in Step 2: the working model-listing mechanism (or its confirmed
absence), the exact `set_model` and `set_permission_mode` request and response
shapes, the exhaustive permission-mode list, and whether per-session reasoning
effort exists — which decides whether Step 11 ships model variants.

## 7. Slash Commands

**UNVERIFIED.** Hypothesis: `system/init.slash_commands` lists available commands
and sending `/command args` as ordinary turn text executes them.

To record in Step 2: whether slash text is actually parsed in stream-json mode.
If it is not, `sendCommand` degrades to a `PluginOperationException` and the
catalog reports no commands.

## 8. Authentication

Fixed decision: the plugin relies entirely on the user's existing `claude` login
and never runs a login flow.

**UNVERIFIED.** Probe options, in order of preference:

1. A status-style subcommand, if the pinned CLI has one.
2. A zero-token init probe: spawn stream-json with no prompt, read the init
   response for account and auth information, then kill. Bounded by a timeout.
3. Otherwise report `PluginSetupUnknown` with an action hint.

To record in Step 2: which probe works, its observed latency, and the exact
signal that distinguishes logged-in from logged-out.

## 9. Known Traps

Carried from prior integrations; each is a fixed constraint, not a hypothesis.

1. Never override `HOME` for isolation — it breaks keychain lookup. Use
   `CLAUDE_CONFIG_DIR` in tests only.
2. On Windows, an npm-shim `claude.cmd` needs `runInShell`. The repository
   already does this everywhere through the host process seam.
3. `AskUserQuestion` answers are keyed by full question text (verify at the
   pinned version, section 4).
4. Unknown stream message types are absorbed with a debug log, never a warning
   per line — the protocol adds message types frequently.
5. A signal-killed child mid-turn surfaces as interrupted, not as an error.
6. Pending permission and question requests must be resolved when a session stops
   or its process exits, or the phone shows a stale card forever.
7. Feature-detect from `system/init.capabilities` rather than sniffing versions
   wherever possible.
8. Idle resident processes cost real memory; reap them and rely on `--resume`.

## 10. Captured Fixtures

**Empty until Step 2.** Real captured lines, trimmed and anonymized, that the
package's tests reuse as inline Dart literals. No golden files — that is the
house style. Nothing here may contain prompt text, transcript content, file
paths, account identifiers, or tokens.
