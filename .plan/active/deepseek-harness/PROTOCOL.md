# Sesori DeepSeek ACP Protocol: Ground Truth

## Status And Sources

- **State:** runtime protocol, Dart consumer, managed package, bridge plugin,
  and product activation are implemented; regression documentation is open for
  review in Step 15.
- **Observed:** 2026-08-22.
- **DeepSeek baseline:** `0.1.1-rc.2`, tag `dsh-v0.1.1-rc.2`, commit
  `b150a551b8d465e31e418e1b2eaf5e79bbb7d28e`.
- **ACP SDK baseline:** `@agentclientprotocol/sdk@0.25.1`, protocol version 1.
- **Repository:** <https://github.com/deepseek-ai/deepseek-harness>.
- **Runtime repository:** `sesori-ai/sesori-deepseek-acp`.
- **Primary upstream source:**
  `packages/acp/acp/src/index.ts`, `packages/examples/acp-demo/`,
  `packages/bundle/base/cordis.patch.yml`, `packages/core/session/`,
  `packages/core/agent/`, `packages/session/session-persistence*/`,
  `packages/interaction/user-approval/`,
  `packages/interaction/user-questions/`, and
  `packages/host/apiproxy/` at the pinned commit.
- **Sesori source:** `bridge/sesori_plugin_acp/`, plugin interface/runtime
  packages, and the Pi/OMP/Hermes plugin precedents at the plan base.

This document explains the shipped adapter contract. The sole machine-verifiable
source is the runtime repository's `protocol/v1/deepseek-acp.schema.json` plus
its synthetic conformance corpus. The runtime validates handlers/types against
that source. The monorepo vendors the exact schema/corpus commit and digests in
a test-only package workspace and Makefile inventory, tests their integrity,
and validates generated Dart DTOs against every fixture. If
implementation discovers an upstream mismatch, change the runtime schema/corpus
first, then update this explanation and the vendored Dart consumer in the release
order recorded in `PLAN.md`.

## 1. Why A Custom Adapter Exists

The published DeepSeek ACP server is not sufficient for Sesori:

| Concern | Stock `dsh-acp` | Required adapter |
|---|---|---|
| Composition | Small demo spine | Full `dsh-base` coding profile |
| Sessions | New only | List, new, load/resume, close |
| History | None | Detached paginated replay |
| Output | Committed text/images | Text, reasoning, tools, plans, titles, usage, status |
| Options | Fixed provider/model config | Provider/model/reasoning catalog and writes |
| Interaction | One-shot permission | Permission plus DeepSeek questions |
| Commands | None | Catalog and exact slash dispatch |
| Extensibility | No registration hook | Versioned methods on same connection |

Running stock ACP beside `dsh web` does not solve this. Each entry point boots a
separate Cordis context, agent registry, persistence coordinator, event stream,
and lifecycle owner. Two processes operating the same session root would have
no supported live-owner negotiation. The planned adapter replaces the transport
plugin inside one context instead.

## 2. Package And Version Contract

The adapter has an independent semantic version and exact package closure.
Initial research pins:

```text
@deepseek-ai/dsh-base                 0.1.1-rc.2
@agentclientprotocol/sdk              0.25.1
Node                                  one exact 24.x patch selected in Step 12
```

Every direct and transitive DeepSeek package is locked to the same upstream
release by the runtime repository lockfile. npm dist-tags are never used for a
release build because ACP package `latest` is stale.

CLI version output is one parseable line:

```text
sesori-deepseek-acp/<adapter-semver> deepseek-harness/<harness-semver> acp/1
```

The Dart descriptor checks adapter semantic version. The ACP initialize
handshake checks standard protocol version plus extension version. Either check
may reject an incompatible PATH runtime before session work starts.

Protocol source/release order is runtime schema and fixtures, runtime
validation/types, vendored Dart schema and DTO/mapping tests, cross-repository
conformance, adapter release, then monorepo artifact pin. Every consuming PR
runs the complete fixture corpus. A breaking schema change increments the
extension protocol integer; Markdown and independently hand-authored fixtures
are never competing sources of truth.

## 3. Invocation And Environment

```text
sesori-deepseek-acp --version
sesori-deepseek-acp check --state-dir <absolute-path>
sesori-deepseek-acp serve --state-dir <absolute-path>
```

Rules:

- `--state-dir` is required, absolute, and resolved once. It is not accepted
  from prompt/RPC input.
- `serve` writes only ACP NDJSON to stdout. Logs and fatal diagnostics use
  stderr and never contain raw frames/content.
- `check` performs no model request, session creation, settings write, normal
  session-root write, or long-lived watch/process. It validates adapter files,
  profile composition, normal DeepSeek config readability, and state-path
  suitability.
- The bridge inherits provider credential environment and `DSH_HOME`.
- The adapter resolves normal `DSH_HOME` using DeepSeek's own precedence; Dart
  never reads `HOME`/`USERPROFILE` or DeepSeek config files.
- The bridge supplies an adapter-owned state environment/overlay for sessions,
  attachments, query/index, and spills.
- The profile structurally disables DeepSeek session telemetry. Environment
  cannot re-enable it.
- The profile structurally selects workspace-write and ask. It does not inherit
  `danger-full-access` from `DSH_PERMISSION_MODE`.
- No Web/Host/frontend/HMR/HTTP plugin is mounted. No socket is opened.

## 4. State Layout And Ownership

The shipped layout confines all mutable session data below the supplied root:

```text
<state-dir>/
  sessions/                 DeepSeek JSONL/Zstandard session artifacts
  attachments-home/        attachment-local's private dshHome
  query/                    optional adapter query/index files
  spills/                   bounded tool spill files
```

Settings, credentials, provider profiles, and skills continue to resolve from
normal `DSH_HOME`; the adapter exposes no method that writes those documents.
The adapter must not read or enumerate normal `DSH_HOME/sessions`.

One `serve` process is the only writer to this root during ordinary Sesori
operation. Bridge plugin lifecycle already serializes start/stop for one plugin
instance, and separate bridges receive separate plugin state directories. No
additional lock or ownership file is planned.

## 5. Framing And Negotiation

- Transport is ACP NDJSON JSON-RPC 2.0 over stdin/stdout.
- Records terminate with LF. Input accepts CRLF by stripping one trailing CR.
- UTF-8 chunks and multiple records per chunk are handled by the ACP SDK.
- stderr is diagnostic only.
- Unknown standard/extension methods return JSON-RPC method-not-found.
- Parse/invalid-parameter errors retain bounded structural detail but no prompt,
  transcript, image, credential, tool payload, or settings value.

Initialize returns standard ACP protocol version 1, adapter identity, supported
prompt/session capabilities, and no phone-owned auth method. It also returns:

```json
{"_meta":{"sesori.ai/deepseek":{"extensionProtocolVersion":1,"adapterVersion":"<semver>","harnessVersion":"<semver>","persistenceOwner":"sesori"}}}
```

The metadata key and fields are pinned. Future optional fields may be added.
Changing required meaning requires a new integer extension protocol version.

Advertised standard capabilities:

- session list, load, and close;
- text and image prompts;
- standard config options;
- standard permissions;
- no client filesystem or terminal capability;
- no ACP authentication flow; local DeepSeek configuration is out of band.

## 6. Standard ACP Methods

| Method | Adapter behavior |
|---|---|
| `initialize` | Negotiate ACP v1 and DeepSeek extension v1; advertise exact capabilities. |
| `authenticate` | No-op only if the SDK requires it; no auth methods are advertised. |
| `session/list` | Page materialized headers from the isolated persistence root without resuming agents. |
| `session/new` | Validate absolute cwd/no injected MCP or additional roots, mint DeepSeek UUID, create one root agent, return config/command state. |
| `session/load` | Resume or reuse exact persisted id, replay standard updates in order, return current config/command state. |
| `session/prompt` | Admit text/images or an exact advertised slash command, then settle after owned work/output/durability quiesces. |
| `session/cancel` | Cancel image admission or agent work and withdraw pending permissions/questions for that session. |
| `session/set_config_option` | Validate/apply the opaque model selection or exact reasoning effort before the next prompt. |
| `session/close` | Cancel/drain/dispose the live handle; retain persistence. Idempotent when already nonresident. |

`session/fork`, client-owned filesystem/terminal calls, MCP injection,
additional working roots, audio, embedded context, and terminal authentication
are not advertised.

## 7. DeepSeek Extension Methods

Extension methods use the `deepseek/` namespace and the initialize-negotiated
version. Fields shown as optional may be added/omitted compatibly; enum/string
variants not documented here must not silently change product state.

### `deepseek/catalog` (client -> agent)

Request is `{"cwd":"/absolute/project/path"}`. The response contains one
`agent`, provider groups with model entries, `defaultSelectionId`, commands,
and bounded per-provider failures. A model carries opaque `id`, diagnostic
`upstreamModelId`, display name, exact reasoning efforts/default, and image
support.

Rules:

- Provider/model pairs are encoded as an opaque URL-safe `v1` value. Dart
  stores/returns it as `PluginModel.id`; it never parses delimiters.
- `upstreamModelId` is diagnostic/display mapping only and never analytics.
- One provider failure does not discard sound groups; total failure is an
  explicit failed discovery and does not replace bridge core's last cache.
- Default selection comes from the current DeepSeek settings/default-model
  owner at request time.
- Catalog reads do not create sessions or call a model.
- Commands include only user-invocable commands in the current composition.

### `deepseek/session/history` (client -> agent)

Request is
`{"sessionId":"deepseek-session-id","beforeSeq":123,"maxMessages":50}`.

`beforeSeq` is absent for the tail page. `maxMessages` defaults to 50 and is
bounded to 100. Response:

Response fields are standard ACP `updates`, optional `nextBeforeSeq`, and
`hasMore`.

Rules:

- Every `updates` entry is exactly a standard ACP `session/update` params
  object, so Dart reuses `AcpReplayCollector`.
- Pagination counts direct human and assistant message boundaries, never cuts
  a message's chunks/tools in half, and returns updates in conversation order.
- Reads use immutable live/cold `sessionPersistence.inspect`; they do not resume
  an agent, mutate/repair cold persistence, or start another process.
- Only `source.kind == user` user messages are presented. Plugin-injected user
  context stays hidden.
- Append-origin conversation is preserved across compaction. Replacement-only
  model surface copies and raw compaction summaries stay hidden.
- Unknown required events fail the page. Unknown `ignorable: true` events are
  locally diagnosed and skipped.

### `deepseek/session/rename` (client -> agent)

```json
{"sessionId":"deepseek-session-id","title":"bounded nonblank title"}
```

The adapter invokes DeepSeek's title owner for a live or safely resumed
session, returns the normalized title, and emits the same title update used by
ordinary automatic titles. It does not rewrite JSONL directly.

### `deepseek/ask_user_question` (agent -> client request)

Params contain exact `sessionId` and a nonempty `questions` list. Each question
has id/text plus optional header, detail, options, multi-select, and plan-review
intent. The response contains one ordered answer per question with id, unique
selected labels, and optional custom replacement.

Rules:

- Exact session ownership is required and validated against the live root agent.
- Empty batches, duplicate ids, duplicate labels, invalid approve intent, and
  answers not matching the request are rejected.
- Single-select accepts one selected label or one nonblank custom answer, not
  both. Multi-select accepts unique advertised labels and optional custom input
  only where the shared Sesori contract can represent it honestly.
- Abort, close, process exit, disposal, and question rejection settle the
  request as cancelled; a late response is discarded.
- A subagent-owned/delegated caller cannot open a phone question and receives
  DeepSeek's existing delegated-caller failure.

## 8. DeepSeek Extension Notifications

### `deepseek/session/status` (agent -> client notification)

Params contain `sessionId`, closed `kind` (`retry`, `compaction_started`,
`compaction_completed`, or `warning`), and only the applicable bounded attempt,
limit, or privacy-safe presentation fields.

Only fields meaningful for the selected kind are present. This notification is
for demonstrated DeepSeek statuses without a standard ACP update. Text from a
model, tool, prompt, transcript, or raw error never enters `message`. Unknown
future kinds are logged locally and ignored by Dart.

Dart emits completed compaction and a generic session error for warning. It
validates but does not emit retry or compaction-started: the shared retry state
requires a next-attempt timestamp that DeepSeek does not provide, while an
active turn is already busy. No timestamp is fabricated to force that shape.

No generic raw `deepseek/session/event` notification is added. Standard ACP
remains the canonical common event stream, which avoids dual-feed deduplication.

## 9. Prompt Identity And Admission

Sesori and DeepSeek must persist one user identity:

1. The Dart ACP base derives a stable ACP message id from the session's initial
   identity or accepted `promptId`.
2. `sesori_plugin_deepseek` adds it to prompt metadata:

   (`{"_meta":{"sesori.ai/deepseek":{"messageId":"..."}}}`).

3. The adapter accepts only a bounded nonblank id, brands it as DeepSeek's
   `MessageId`, and uses `freezeMessage` with `source.kind = user`.
4. The `user/message` event persists that id. Load/history emits it as ACP
   update `messageId`. Existing Dart live/replay mapping then produces the same
   plugin message and part ids.

Assistant token chunks arrive before the pinned DeepSeek loop creates its random
durable assistant message id. To keep token-live streaming without a correlation
sidecar, the adapter derives the ACP assistant `messageId` deterministically from
the session's durable turn/step identity. Every live chunk and the assembled
assistant replay event use that same projection id. DeepSeek's own random
message id remains unchanged in its log and model-facing state.

An absent metadata id is valid for non-Sesori ACP clients and makes the adapter
mint its normal DeepSeek id. Invalid metadata fails prompt admission before any
attachment or session event is committed. Existing Sesori ACP plugins do not
send or depend on this metadata.

Prompt content rules:

- text remains text;
- inline PNG/JPEG/WebP/GIF data is decoded, bounded, normalized, and stored by
  DeepSeek attachment services below adapter state;
- path, URL, non-image data, bad base64, unsupported MIME, and over-limit input
  fail before acceptance;
- an exact `/name arguments` whose `name` is currently advertised invokes the
  command service; an unknown slash prefix remains ordinary user text; and
- one prompt per session may be in flight, while different sessions may run
  concurrently.

## 10. Event Projection

Live projection uses stable DeepSeek session event fields and standard ACP
updates:

| DeepSeek source | ACP projection |
|---|---|
| direct `user/message` during load/history | `user_message_chunk` with message id |
| `assistant/chunk` text delta | `agent_message_chunk` with assistant message id |
| `assistant/chunk` reasoning delta | `agent_thought_chunk` with assistant message id |
| assembled assistant image | `agent_message_chunk` image content |
| `tool/call` | `tool_call` with exact `callId`, name/kind/title, bounded presenter content |
| `tool/result` | `tool_call_update` with exact `callId`, terminal status, result/diff content |
| `todo/write` | standard `plan` snapshot |
| title owner update | `session_info_update` |
| command catalog change | `available_commands_update` |
| selection change | `config_option_update` |
| assistant usage | terminal `session/prompt` response only; no separate Dart event |
| retry/compaction status | `deepseek/session/status` |
| turn end | `session/prompt` stop reason or bounded error |

Raw chunks are live transport detail; assembled durable messages are replay
authority. Tests require the completed live message/tool/plan projection to
equal detached replay. Tool presenter failure degrades to a generic bounded
tool card without dropping the call/result.

Stop-reason mapping:

| DeepSeek turn end | ACP result |
|---|---|
| completed | `end_turn` |
| user/owner abort | `cancelled` |
| blocked/refused | `refusal` when semantically a refusal, otherwise bounded error |
| max tokens | `max_tokens`; usage remains adapter response-only |
| provider/tool/internal error | JSON-RPC internal error with sanitized message and local cause |
| recovered interrupted turn | history status only; never reported as a new live success |

## 11. Options And Commands

Standard config option ids are pinned within extension protocol v1:

```text
deepseek.model
deepseek.reasoning_effort
```

- `deepseek.model` values are opaque catalog selection ids.
- Selecting a model returns a refreshed config state whose reasoning values are
  exact for that model.
- `deepseek.reasoning_effort` accepts only a currently advertised value.
- Writes are rejected while their target session is unknown or selection is
  invalid. The Dart plugin applies every requested write before prompt dispatch
  and fails the turn closed on rejection/partial application.
- A resumed session derives current selection from its latest request header;
  otherwise it uses the current default from settings.
- Selection is session-local and is not saved to the user's settings file.

The adapter exposes one agent:

```json
{"id":"deepseek","name":"DeepSeek","primary":true}
```

No preset roster is composed in v1. Commands preserve upstream stable names and
descriptions. Command-specific UI, forms, and browser components are not
invented; a command that needs a normal DeepSeek question uses the question
extension above.

## 12. Permissions And Questions

DeepSeek's default approval policy is ask. The adapter registers one answerer:

- `approval/request` becomes standard ACP `session/request_permission` with the
  exact session id and tool call id;
- options are allow once and reject once;
- ACP cancelled, missing client, transport failure, close, or abort fails closed;
- the exact response option maps back to DeepSeek's `allowed-once`, `rejected`,
  or `cancelled`; and
- approval asked/decided audit events remain in the DeepSeek session log but are
  not transcript messages.

Allow always is not advertised. DeepSeek's seam has no durable allow-always
outcome, so mapping Sesori's existing visual affordance to one would overclaim
authority.

The user-question provider uses `deepseek/ask_user_question` and waits on the
same ACP connection. Multiple sessions are safe because both requests carry
session identity. No process-wide prompt serialization is needed.

## 13. Session List, Parentage, Rename, And Deletion

`session/list` returns only materialized adapter-owned headers. It maps:

- id -> DeepSeek header id;
- cwd -> absolute header cwd;
- created time -> header `createdAt`;
- updated time -> bounded adapter-owned artifact metadata when cheaply
  available, otherwise creation time;
- parent/subagent metadata -> namespaced `_meta` fields consumed only by the
  DeepSeek plugin; and
- title -> optional when a cheap projection is available. Sesori's durable
  title remains authoritative for already imported rows.

List pagination uses an opaque cursor and a fixed page bound. Duplicate session
ids or a header/path identity mismatch fail loudly. Normal `DSH_HOME/sessions`
is never scanned.

Rename goes through the title service extension. Standard close releases live
ownership only. There is no persistence delete API in the pinned DeepSeek
service; therefore:

- Dart does not remove JSONL/attachments directly;
- the adapter does not infer private paths and delete them;
- Sesori purges its database/transcript/worktree state and records its existing
  plugin-scoped tombstone; and
- a later explicit import cannot resurrect the retained DeepSeek row.

## 14. Errors, Privacy, And Unknown Data

- Runtime and Dart code never log raw protocol frames.
- Prompts, responses, reasoning, image bytes, tool arguments/results, settings
  documents, credentials, and provider keys never enter logs or committed test
  evidence.
- Local logs retain adapter/harness versions, session id where diagnostic,
  operation, safe path, original error/cause, and stack trace.
- Client errors omit raw paths/output and carry a stable bounded category plus
  actionable local setup guidance where applicable.
- Unknown optional fields are ignored. Unknown enum variants become explicit
  unknown variants at the boundary and degrade where safe.
- An unknown required DeepSeek history event refuses reconstruction unless its
  persisted event declares `ignorable: true`.
- Recovered failures that continue are logged once. Surfaced/rethrown failures
  are not double-logged.

## 15. Conformance Fixtures

The runtime repository owns deterministic protocol fixtures for:

- initialize metadata/capabilities and incompatible extension versions;
- list/new/load/close and restart with two cwd values;
- detached history pagination and stable initial/later prompt ids;
- text/reasoning/images, tools/results/diffs, todos, titles, usage, retries,
  compaction, refusal/error/max-token/cancel;
- providers/models containing `/` and Unicode, reasoning options, partial
  catalog failures, and exact slash commands;
- permissions and question batches across two sessions, late answers, abort,
  and missing answerers;
- telemetry/state/config isolation and stdout/content-log privacy; and
- archive relocation/launch on all six target artifacts.

The monorepo vendors the runtime repository's synthetic wire corpus and schema
in a test-only package workspace and Makefile inventory, with a manifest
recording the source commit and SHA-256 values; it does not copy DeepSeek private
session files or add production DTOs, APIs, or ACP hooks. Generated consumer DTO
tests pass every fixture. Cross-repository conformance and all six matching-native
package jobs passed before publication. Runtime and Dart protocol-changing PRs
must update and run that corpus in source/consumer order. Step 16 still repeats
the complete product boundary with the exact managed artifacts pinned by the bridge.
