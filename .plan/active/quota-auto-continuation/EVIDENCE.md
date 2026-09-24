# Quota reset evidence

Collected read-only on 2026-09-23 from recent local sessions for this repository
and its worktrees. No prompts, full transcripts, credentials or account
identifiers are included. Samples demonstrate error shapes, not feature support.

## Local observations

### Harness: Claude Code

**Observation:** 2026-09-23 14:12:51 UTC: tagged `rate_limit` / `isApiErrorMessage` with “You've hit your
session limit · resets 6:30pm (Europe/Sofia)”. A 2026-09-16 sample uses `2pm`.

**Meaning:** A real tagged quota error carries time and named zone; minutes are optional.

### Harness: Pi, `openai-codex`

**Observation:** 2026-09-16 19:34:27 UTC: assistant `stopReason: error`, “You have hit your ChatGPT usage
limit (pro plan). Try again in ~5918 min.”

**Meaning:** A real error carries a relative duration spanning several days. The absolute reset must be
anchored to this error's timestamp.

### Harness: Pi, `openai-codex`

**Observation:** 2026-09-16 19:40:40 UTC: “Codex error: The usage limit has been reached”.

**Meaning:** The same provider can omit reset information.

### Harness: Pi, `openai-codex`

**Observation:** Connection errors containing “disconnect/reset before headers” also occur.

**Meaning:** Searching for the word `reset` is not a quota classifier.

### Harness: Codex

**Observation:** Recent repository rollout `token_count` events contain `rate_limits.limit_id`,
`primary.used_percent`, `window_minutes`, and `resets_at`.

**Meaning:** Structured reset information exists locally, but sampled windows were not exhausted. No
terminal quota error occurred in the six repository rollouts among the 30 most recently modified Codex files
inspected.

Scope: 32 Claude repository transcript files, 35 most recently modified Pi
repository transcript files, and the Codex sample described above. Historical
model labels identify examples only; eligibility must not depend on model-name
allowlists. The installed Pi package inspected was
`@earendil-works/pi-coding-agent` 0.87.1; that is not proof of the version that
wrote every historical record. The repository Claude target is 2.1.269.
The repository Pi manifest targets 0.85.1 and accepts PATH versions from 0.84.1.
The historical files do not prove terminal quota delivery through either
supported runtime's live RPC/retry path; that capability remains unverified.

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

- [Claude SDK rate-limit types][claude-types]
  model rejected/allowed states and reset timestamps. The
  [wire parser][claude-parser]
  confirms camel-case `resetsAt` inside `rate_limit_info`.
- [Codex app-server account limits](https://developers.openai.com/codex/app-server#6-rate-limits-chatgpt)
  documents read/update operations, per-bucket views, and reset timestamps in
  Unix seconds. These are account signals; turn/bucket attribution still matters.
- [Pi's current Codex transport][pi-codex]
  distinguishes terminal limits from retryable errors and reads retry headers.
  Native HTTP handling does not prove those headers survive the Pi RPC seam.
- [ACP schema](https://agentclientprotocol.com/protocol/v1/schema) does not provide
  a general quota-reset contract. Adapter error data/extensions must be inspected
  individually; absence of a standard field is not proof of impossibility.

These moving upstream sources were read on 2026-09-23. During implementation,
verify the pinned driven runtime and commit/release before advertising support.

## Step 2 implementation evidence — 2026-09-24

- Pi's pinned [0.85.1 formatter][pi-pinned-error] constructs the observed
  ChatGPT usage-limit text and approximate minutes from provider `resets_at`.
  Raw generic 429 text does not qualify in Sesori.
- Live RPC probes ran the published Pi **0.85.1** and **0.84.1** packages with an
  isolated synthetic provider, no tools, no discovered extensions, no persisted
  session and no model API requests. On both versions:
  - The observed quota text arrived as an assistant `message_end` with
    `provider: openai-codex`, `stopReason: error`, and numeric timestamp, followed
    by `agent_end(willRetry: false)` and `agent_settled`.
  - A retryable failure followed by success emitted `auto_retry_end(success:
    true)` before final `agent_settled`.
  - A retryable failure exhausting the one-retry test budget emitted
    `auto_retry_end(success: false)` before final `agent_settled`.
  These are runtime/protocol probes, not evidence of live account exhaustion.
  They agree with the pinned [target][pi-pinned-session] and
  [PATH-floor][pi-floor-session] retry/settlement implementations.
- Focused plugin tests bind each observation to the visible error ID, wait for
  terminal settlement, and exclude successful recovery, cancellation, generic
  failures and forwarded Claude child errors. Core tests preserve that ID when
  translating the session ID and prevent internal quota events reaching client
  SSE directly. Unknown resets stay typed as unknown.
- Claude uses the locally observed tagged session-limit text. The SDK's
  process-wide `rate_limit_event` has no verified failed-message binding and
  remains unused. Date-less times are accepted only on the original local date;
  unsupported dates, ambiguous DST times and stale times remain unknown.
- Codex and the other harnesses retain their unverified reporting status. This
  step adds no account-bucket guesses, scheduler, database state or chat controls.

### Reproduction and measured revisions

Initial plugin/core checks measured commit
`b2ea432f33d85a0e73df4cb7b6a3746ddb1f3a06`. The review follow-up measured
`94854f5bde9f9a8cb4108b7e9daefca4927cd6c1`, including the main merge and the
Claude trailing-stream fix. Commands ran on the same file contents immediately
before these commits. The evidence-only update does not change tested sources.
Toolchain: repository-pinned Dart 3.13.4 / Flutter 3.47.5.

All working directories below are relative to the repository root. Each listed
command exited 0; counts refer to that command, not an inferred full-suite run.

| Revision | Working directory | Exact command | Result |
|---|---|---|---|
| Initial | `bridge/sesori_plugin_pi` | `dart test test/pi_session_service_test.dart` | 74 passed |
| Initial | `bridge/sesori_plugin_pi` | `dart test test/pi_quota_interruption_mapper_test.dart` | 3 passed |
| Initial | `bridge` | `dart analyze sesori_plugin_interface sesori_plugin_claude sesori_plugin_pi app` | No issues |
| Follow-up | `bridge/sesori_plugin_claude` | `dart test test/claude_session_service_test.dart --name 'quota observation'` | 8 passed |
| Follow-up | `bridge/sesori_plugin_claude` | `dart test test/claude_session_service_test.dart test/claude_quota_interruption_mapper_test.dart test/claude_plugin_impl_test.dart` | 83 passed |
| Follow-up | `bridge/app` | `dart test test/bridge/repositories/mappers/session_event_mapper_test.dart test/bridge/sse/bridge_event_mapper_test.dart` | 31 passed |
| Follow-up | `bridge` | `dart analyze sesori_plugin_claude app` | No issues |
| Follow-up | `bridge` | `dart pub get --enforce-lockfile --offline` | Succeeded; no lockfile diff |

The new trailing-stream regression failed before the fix (the expected quota
event was absent). After the fix, trailing frames preserve the complete error,
while a new root `message_start` supersedes it.

The committed [RPC probe][quota-probe] and [synthetic provider][quota-fixture]
replace the original local-only probe scripts. Run from the repository root:

```sh
npx --yes --package=@earendil-works/pi-coding-agent@0.85.1 -- node bridge/sesori_plugin_pi/tool/quota_settlement_probe.mjs 0.85.1
npx --yes --package=@earendil-works/pi-coding-agent@0.84.1 -- node bridge/sesori_plugin_pi/tool/quota_settlement_probe.mjs 0.84.1
```

Both commands passed on the follow-up revision: three scenarios each
(`terminal`, `recover`, `exhausted`). The probe checks the actual CLI version,
uses isolated settings under `bridge/.dart_tool/`, and prints JSON event
summaries. It asserts assistant provider/timestamp/stop reason and retry-end
ordering before final settlement. npm may download the pinned runtime; the
synthetic model itself makes no network requests and consumes no account quota.

[quota-probe]: ../../../bridge/sesori_plugin_pi/tool/quota_settlement_probe.mjs
[quota-fixture]: ../../../bridge/sesori_plugin_pi/tool/quota_probe_provider.ts

[pi-pinned-error]:
  https://github.com/earendil-works/pi/blob/v0.85.1/packages/ai/src/api/openai-codex-responses.ts
[pi-pinned-session]:
  https://github.com/earendil-works/pi/blob/v0.85.1/packages/coding-agent/src/core/agent-session.ts
[pi-floor-session]:
  https://github.com/earendil-works/pi/blob/v0.84.1/packages/coding-agent/src/core/agent-session.ts

[claude-types]:
  https://github.com/anthropics/claude-agent-sdk-python/blob/main/src/claude_agent_sdk/types.py
[claude-parser]:
  https://github.com/anthropics/claude-agent-sdk-python/blob/main/src/claude_agent_sdk/_internal/message_parser.py
[pi-codex]:
  https://github.com/earendil-works/pi/blob/main/packages/ai/src/api/openai-codex-responses.ts
