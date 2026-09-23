# Quota reset evidence

Collected read-only on 2026-09-23 from recent local sessions for this repository
and its worktrees. No prompts, full transcripts, credentials or account
identifiers are included. Samples demonstrate error shapes, not feature support.

## Local observations

| Harness | Observation | Meaning |
|---|---|---|
| Claude Code | 2026-09-23 14:12:51 UTC: tagged `rate_limit` / `isApiErrorMessage` with “You've hit your session limit · resets 6:30pm (Europe/Sofia)”. A 2026-09-16 sample uses `2pm`. | A real tagged quota error carries time and named zone; minutes are optional. |
| Pi, `openai-codex` | 2026-09-16 19:34:27 UTC: assistant `stopReason: error`, “You have hit your ChatGPT usage limit (pro plan). Try again in ~5918 min.” | A real error carries a relative duration spanning several days. The absolute reset must be anchored to this error's timestamp. |
| Pi, `openai-codex` | 2026-09-16 19:40:40 UTC: “Codex error: The usage limit has been reached”. | The same provider can omit reset information. |
| Pi, `openai-codex` | Connection errors containing “disconnect/reset before headers” also occur. | Searching for the word `reset` is not a quota classifier. |
| Codex | Recent repository rollout `token_count` events contain `rate_limits.limit_id`, `primary.used_percent`, `window_minutes`, and `resets_at`. | Structured reset information exists locally, but sampled windows were not exhausted. No terminal quota error occurred in the six repository rollouts among the 30 most recently modified Codex files inspected. |

Scope: 32 Claude repository transcript files, 35 most recently modified Pi
repository transcript files, and the Codex sample described above. Historical
model labels identify examples only; eligibility must not depend on model-name
allowlists. The installed Pi package inspected was
`@earendil-works/pi-coding-agent` 0.87.1; that is not proof of the version that
wrote every historical record. The repository Claude target is 2.1.269.

## Code pointers

- Claude: `bridge/sesori_plugin_claude/lib/src/api/models/claude_stream_message.dart`
  and `lib/src/claude_event_dispatcher.dart`: parsed rate-limit frame currently
  ignored; `ClaudeApiRetryMessage` already drives native retry state.
- Pi: `bridge/sesori_plugin_pi/lib/src/services/pi_event_dispatcher.dart` and
  `lib/src/repositories/mappers/pi_history_mapper.dart`: native retry lifecycle
  and preserved terminal assistant errors.
- Codex: `bridge/sesori_plugin_codex/lib/src/codex_event_mapper.dart`,
  `test/codex_event_mapper_test.dart`, `test/codex_rollout_api_test.dart`:
  terminal usage-limit errors become visible error messages.
- OpenCode: `bridge/sesori_plugin_opencode/lib/src/assistant_message_mapper.dart`:
  backend error maps are available before presentation is flattened. Reset
  metadata and provider attribution still need validation.
- Shared: `bridge/sesori_plugin_interface/lib/src/bridge_sse_event.dart` and
  `lib/src/models/plugin_session_status.dart`; no quota scheduling contract.
- Core: `bridge/app/lib/src/services/session_prompt_service.dart`,
  `session_operation_dispatcher.dart`, `session_event_service.dart`, and
  `bridge/app/lib/src/orchestrator.dart` are existing ownership seams.

## Primary external sources

- [Claude SDK rate-limit types](https://github.com/anthropics/claude-agent-sdk-python/blob/main/src/claude_agent_sdk/types.py)
  model rejected/allowed states and reset timestamps. The
  [wire parser](https://github.com/anthropics/claude-agent-sdk-python/blob/main/src/claude_agent_sdk/_internal/message_parser.py)
  confirms camel-case `resetsAt` inside `rate_limit_info`.
- [Codex app-server account limits](https://developers.openai.com/codex/app-server#6-rate-limits-chatgpt)
  documents read/update operations, per-bucket views, and reset timestamps in
  Unix seconds. These are account signals; turn/bucket attribution still matters.
- [Pi's current Codex transport](https://github.com/earendil-works/pi/blob/main/packages/ai/src/api/openai-codex-responses.ts)
  distinguishes terminal limits from retryable errors and reads retry headers.
  Native HTTP handling does not prove those headers survive the Pi RPC seam.
- [ACP schema](https://agentclientprotocol.com/protocol/v1/schema) does not provide
  a general quota-reset contract. Adapter error data/extensions must be inspected
  individually; absence of a standard field is not proof of impossibility.

These moving upstream sources were read on 2026-09-23. During implementation,
verify the pinned driven runtime and commit/release before advertising support.
