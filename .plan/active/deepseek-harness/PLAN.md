# DeepSeek Harness Support

## Status

- **Plan slug:** `deepseek-harness`
- **Status:** Step 4/15 merged; Step 5/15 ready for review
- **Plan date:** 2026-08-22
- **Implementation base:** `origin/main` at
  `ebcc09bf255e1410720be616b883fa40af95d4a4`
- **Upstream baseline:** DeepSeek Harness `0.1.1-rc.2`, tag
  `dsh-v0.1.1-rc.2`, commit
  `b150a551b8d465e31e418e1b2eaf5e79bbb7d28e`
- **Repositories:** this monorepo plus a new
  `sesori-ai/sesori-deepseek-acp` runtime repository
- **Delivery:** fifteen sequential PRs: one planning PR, five runtime-source
  PRs, four bridge-plugin PRs, one runtime-release PR, two activation/runtime
  PRs, one regression-documentation PR, and one verification/retirement PR

## Goal

Add DeepSeek Harness as a first-class Sesori coding backend without running its
private Web BFF or allowing two processes to control the same session. Sesori
installs one checksummed Node runtime, communicates over one ACP v1 NDJSON stdio
connection, and uses narrow versioned `deepseek/*` extensions only where ACP
cannot carry required DeepSeek behavior.

The delivered product supports Sesori-created DeepSeek sessions and sessions
previously created by the same Sesori plugin state. It does not claim to import
or attach to ordinary `dsh` Web, CLI, or headless sessions under the user's
normal DeepSeek session root.

## Success Criteria

1. `GET /plugin` advertises `deepseek` as `DeepSeek Harness`, with honest setup,
   install, lifecycle, attachment, and session-option capabilities.
2. Install downloads one immutable adapter archive for the exact host target,
   verifies its SHA-256, and atomically adopts the complete Node/package tree
   under DeepSeek's plugin-managed state. No npm command runs on the user's
   machine.
3. An explicit `--deepseek-bin` remains authoritative. Otherwise a compatible
   `sesori-deepseek-acp` on PATH wins over the pinned managed adapter; an absent
   or too-old PATH adapter falls back to the managed pin.
4. The adapter owns one Node process, one Cordis `Context`, one
   `AgentSideConnection`, one JSONL persistence backend, and all live DeepSeek
   agents. No HTTP server, port, Web BFF, second stdio process, or direct Dart
   session-file reader is introduced.
5. DeepSeek settings, credentials, environment-provider configuration, and
   skills are read from the user's normal `DSH_HOME`. Sesori session logs,
   attachments, query state, and spills are written only below the plugin state
   directory. The runtime never saves a phone selection as the user's global
   DeepSeek default.
6. Upstream DeepSeek telemetry is disabled for every Sesori-owned process so
   source, prompts, reasoning, tool data, and session logs cannot enter its raw
   session exporter through inherited environment configuration.
7. New sessions use DeepSeek's durable UUID, selected cwd, workspace-write
   sandbox, and ask approval policy. Multiple sessions may be resident and run
   concurrently because every DeepSeek approval and question retains exact
   session ownership.
8. Session enumeration and detached paginated history are served by the same
   process through owner APIs over the Sesori persistence root. History reads do
   not resume an agent or launch a scratch adapter process.
9. Live and replayed text, reasoning, images, tool lifecycle, plans/todos,
   titles, usage, retries, compaction, errors, and completion map into existing
   plugin messages/events without duplicate user messages after restart.
10. Text and supported inline images reach DeepSeek. File paths, URLs,
    non-image data, and oversized/invalid images fail visibly before prompt
    acceptance and never become accidental prompt strings.
11. Provider/model/reasoning catalogs and commands come from the composed
    DeepSeek context. Exact opaque selection values round-trip through standard
    ACP config options; no provider or model names are hardcoded in Dart.
12. Standard ACP permissions and `deepseek/ask_user_question` requests round
    trip through existing Sesori permission/question contracts. Abort, process
    exit, session close, and disposal settle every pending request.
13. Local deletion closes live DeepSeek ownership and purges/tombstones Sesori
    state. The upstream adapter artifact remains on disk because DeepSeek
    exposes no persistence-delete owner API; private path deletion is not added.
14. No relay route, client/bridge wire model, database column, message-part
    variant, or backend-specific client state branch is added. Older clients use
    the unknown-harness presentation fallback and newer clients connected to an
    older bridge receive no DeepSeek entry.
15. Every implementation PR is independently buildable and normally remains at
    or below 1,500 changed lines, including tests and generated output.

## Authoritative Upstream Facts

Research was refreshed on 2026-08-22 against the pinned commit and published
npm packages:

- DeepSeek Harness has tagged prereleases; `0.1.1-rc.2` is the latest release
  and all GitHub releases remain prereleases.
- `@deepseek-ai/dsh@0.1.1-rc.2` is npm `latest`. The ACP packages' `latest`
  dist-tag still points to `0.0.1-rc.1`; every dependency must therefore use an
  exact version rather than `latest`.
- Node support is `^22.19.0 || >=24.0.0`. The adapter artifacts pin one Node 24
  patch release and never depend on a system Node installation.
- `@deepseek-ai/dsh-base` is the full coding profile bundle. It composes the
  agent loop, JSONL sessions, settings, credentials, sandbox, approvals,
  questions, tools, skills, jobs, plans, subagents, compaction, and provider
  adapters. Its JavaScript entry exports no runtime API; its published bundle
  patch is consumed through DeepSeek's profile loader.
- The base profile defaults new sessions to `deepseek-official` /
  `deepseek-v4-flash`, workspace-write, and ask. Settings may provide another
  default and additional providers.
- `@deepseek-ai/dsh-acp@0.1.1-rc.2` is intentionally automation-only. It
  implements initialize, no-op authenticate, session/new, prompt, cancel,
  committed assistant text/images, and one-shot permissions. It does not
  implement list, load/resume, history, rich events, questions, config options,
  commands, close, or extension registration.
- `@deepseek-ai/dsh-acp-demo@0.1.1-rc.2` exposes `dsh-acp-demo`; the ACP package
  itself exposes no executable. The demo composes the smaller
  `dsh-agent-spine-demo`, not the full product profile.
- `@agentclientprotocol/sdk@0.25.1` supports standard handlers plus
  `extMethod`/`extNotification` on one `AgentSideConnection`.
- DeepSeek's JSONL persistence service exposes list, inspect, prepare/resume,
  load, read-from-seq, and immutable metadata. It exposes no delete operation.
- Session headers carry authoritative id, creation time, cwd, parent,
  subagent origin, and preset metadata. Session events carry stable sequence,
  time, message, tool-call, turn, and reasoning identities.
- `DSH_HOME` precedence is explicit path, nonblank `DSH_HOME`, then `~/.dsh`.
  JSONL persistence has an independent root. Attachment and spill roots are
  independently configurable by the composing profile.
- The Web API is an internal browser BFF with no protocol version,
  authentication, TLS, or compatibility policy. It is evidence for mappings,
  not a supported remote boundary.
- The repository and published packages are MIT licensed. Distributed source,
  package code, Node, and native dependencies still require complete license
  and notice aggregation.

Canonical protocol and package evidence is recorded in `PROTOCOL.md`.

## Locked Product Decisions

1. Use one enhanced ACP runtime, not stock ACP plus `dsh web`.
2. The enhanced runtime lives in `sesori-ai/sesori-deepseek-acp`; bridge code
   remains pure Dart and does not embed Node source or `node_modules`.
3. The adapter is implemented directly on the ACP SDK and published DeepSeek
   core packages. It does not wrap the non-extensible stock ACP plugin or copy
   the unsupported Web BFF contract.
4. Standard ACP remains authoritative for session lifecycle and common live
   events. Versioned `deepseek/*` methods carry only catalogs, detached history,
   title mutation, questions, and status variants ACP cannot represent.
5. One long-lived adapter process hosts all sessions. Detached history and
   catalog reads use the same connection and do not create scratch processes.
6. Use the user's normal `DSH_HOME` read-only for settings, credentials, and
   skills. Use the plugin state directory for every Sesori-owned mutable
   session artifact. Do not import normal DeepSeek sessions or provide a
   terminal/Web handoff in v1.
7. Force telemetry off. Do not inherit a telemetry opt-in into a Sesori-owned
   process because DeepSeek's exporter can transmit raw session records.
8. Fix the deployment default to workspace-write plus ask. Do not inherit
   `danger-full-access`; no v1 phone setting weakens this policy.
9. Local DeepSeek setup is sufficient. The phone does not edit provider
   credentials or settings. Setup proves adapter availability/composition, not
   a network credential; project catalog and prompt errors provide sanitized
   local `dsh` setup guidance.
10. Expose one primary `deepseek` agent. Provider, model, reasoning effort, and
    commands are discovered; agent presets, Web workspaces, Web settings pages,
    and browser-only presentation are excluded.
11. Keep DeepSeek's stable session/message/tool identities. A narrow optional
    ACP prompt-identity hook lets the DeepSeek adapter persist the same user
    message id the bridge renders live; existing ACP plugins keep their current
    behavior.
12. Local deletion uses close plus Sesori purge/tombstone. Retaining the
    adapter's JSONL and attachment data is an explicit limitation until an
    upstream owner API can delete it safely.
13. OpenCode remains the preferred default harness. DeepSeek registration is
    additive and uses the generic client icon in v1; no unlicensed trademark
    asset is introduced.

## Scope

### Included

- New `sesori-ai/sesori-deepseek-acp` TypeScript/Node repository.
- Exact DeepSeek/ACP dependency pin, lockfile integrity, notices, SBOM, release
  checksums, and six target-specific package-directory archives.
- Full `dsh-base` composition with Sesori state-root overrides, fixed sandbox
  and approval policy, and telemetry disabled.
- Standard ACP initialize, list, new, load, prompt, cancel, config-option,
  close, replay, permissions, images, tools, plans, titles, and usage.
- Versioned DeepSeek catalog, detached-history, rename, question, and bounded
  status extensions described in `PROTOCOL.md`.
- One process-local runtime session registry and exact handle ownership.
- New pure-Dart `bridge/sesori_plugin_deepseek/` package over
  `sesori_plugin_acp`.
- Narrow generic ACP hooks for plugin-owned outbound prompt identity and a
  protected `requireConnectedClient()` borrow of the lifecycle-owned live
  connection; existing concrete plugins remain unchanged.
- DeepSeek-specific API DTOs, catalog/history repositories, session-options
  service, event mapper, approval registry, binary/descriptor/manifest, setup,
  managed install, lifecycle, and plugin composition.
- `deepseek` shared identity, bridge registration, generic client icon/name,
  local setup/security guidance, exact-set fixtures, workspace/CI inventory,
  and runtime-update skill support.
- Regression-document reconciliation and live packaged verification.

### Excluded

- `dsh web`, ApiProxy/WebSocket integration, local HTTP ports, or any Web BFF
  authentication/TLS wrapper.
- Stock `dsh-acp-demo` as the product runtime.
- Import, mutation, or handoff of ordinary `~/.dsh/sessions` data.
- Direct Dart reads of DeepSeek JSONL, SQLite, attachment, credential, or
  settings files.
- Phone-side credential entry, provider settings editing, marketplace/plugin
  management, or terminal authentication.
- `danger-full-access`, approval auto-grants, and phone-controlled permission
  mode in v1.
- DeepSeek Web workspaces, session search, exports, feedback, preset authoring,
  browser directories, themes, and other browser-only UI.
- Parent-fork creation. Persisted DeepSeek subagent parent/child metadata is
  mapped when present, but generic session creation supplies no parent id.
- Upstream persisted deletion, attachment garbage collection, or JSONL layout
  mutation without a supported owner API.
- New relay/client transport models, database schema, message parts, or
  DeepSeek-specific client cubits/widgets.
- Provider, model, agent, command, path, session, or error identities in
  analytics.

## Architecture

```text
phone/desktop
      <-> relay
      <-> bridge app
      <-> sesori_plugin_deepseek (pure Dart)
      <-> one ACP v1 NDJSON stdio connection
      <-> sesori-deepseek-acp (managed Node package)
      <-> one Cordis Context + dsh-base + custom ACP adapter
      <-> Sesori-owned DeepSeek persistence root
```

### Ownership Boundaries

- `sesori_plugin_interface` remains the backend-neutral product contract.
- `sesori_plugin_acp` owns generic ACP transport, handshake, process lifecycle,
  turn lanes, prompt queueing, standard replay/event mapping, and permission
  mechanics. It gains only optional generic hooks demonstrated by DeepSeek.
- `sesori_plugin_deepseek` owns every DeepSeek identifier, extension schema,
  catalog mapping, prompt identity, setup rule, binary argument, runtime pin,
  state environment, and degradation decision.
- `sesori-deepseek-acp` owns DeepSeek package composition, Cordis service use,
  session/agent handles, event-to-ACP projection, extension protocol, adapter
  versioning, Node/native dependency closure, and release artifacts.
- Bridge app code knows DeepSeek only at package inventory and the production
  plugin registry composition point.
- Client shared code knows only the additive `deepseek` built-in identity and
  display name. Unknown IDs retain existing fallback behavior.

The runtime repository's versioned JSON Schema and conformance corpus are the
machine-verifiable extension-contract source of truth. `PROTOCOL.md` explains
that contract but does not define an independent wire representation. Release
and consumer ordering is fixed under "Protocol Source And Release Order"
below.

### Runtime Composition And State

The adapter uses DeepSeek's profile loader with `@deepseek-ai/dsh-base` and one
adapter-owned overlay. The overlay:

- mounts the custom ACP transport instead of `@deepseek-ai/dsh-acp`;
- points JSONL sessions, attachment storage, query/index state, and spill files
  below an absolute `--state-dir` supplied by the bridge;
- leaves settings, credentials, provider profiles, workspace instructions, and
  skills on the resolved normal `DSH_HOME`;
- disables the session telemetry plugin regardless of inherited
  `DSH_TELEMETRY_MODE`;
- sets workspace-write and ask as the deployment defaults; and
- mounts no Host, Web, frontend, HMR, or HTTP plugin.

The adapter never writes a global model default. Session config options install
selection in the live agent scope, and the next request header persists the
selection in that session's own log. A resumed session uses its latest request
header before the user's current default.

The runtime CLI has three bounded modes:

```text
sesori-deepseek-acp --version
sesori-deepseek-acp check --state-dir <absolute-path>
sesori-deepseek-acp serve --state-dir <absolute-path>
```

`check` verifies package/profile composition and state-path validity without a
model request, session creation, normal-DSH_HOME write, or long-lived process.
`serve` reserves stdout exclusively for NDJSON; bounded diagnostics go to
stderr. `--version` reports both adapter and pinned DeepSeek versions.

### Session Lifecycle And Single Ownership

The runtime maintains one `sessionId -> AgentHandle` map for live root sessions.
DeepSeek's registry and persistence services remain authoritative:

- `session/list` reads materialized headers from the isolated persistence
  service and never resumes agents;
- `session/new` mints a UUID, validates absolute cwd, installs the selected
  model state, and creates one owned root agent;
- `session/load` inspects/resumes the exact persisted id and emits standard ACP
  replay updates before returning;
- `session/prompt` admits one prompt per session, freezes the caller-supplied
  message identity, and settles only after admission, agent idle, ordered event
  delivery, and persistence checkpointing;
- `session/cancel` cancels admission or the live agent and resolves pending
  approvals/questions;
- `session/close` cancels and drains the exact live handle, then disposes it
  without deleting persistence; and
- adapter disposal closes admission, cancels roots, drains continuable children,
  flushes ordered output, disposes all handles, then disposes the Cordis tree.

Per-session ACP lanes already serialize turns on the Dart side. DeepSeek's
approval/question seams carry exact `Agent`, session, and tool-call ownership,
so no process-wide prompt lane, global current-session field, or cross-session
dedupe registry is added.

### History And Canonical Identity

`deepseek/session/history` reads immutable live or cold persistence inspection
through the same context, paginates at complete human-message boundaries, and
returns standard ACP `session/update` parameter objects. The Dart history
repository feeds those objects through `AcpReplayCollector`; it does not add a
second mapper or parse DeepSeek records.

The adapter puts stable message ids on every text/reasoning update and stable
call ids on every tool update. User-authored prompts preserve the exact
caller/DeepSeek id. Assistant updates use one deterministic adapter projection
id derived from the durable DeepSeek turn/step identity, because the pinned
runtime creates its random assistant message id only after token chunks have
already streamed. Live chunks and replay derive the same id without a sidecar,
which preserves token-live output and replay identity together. For
user-authored prompts:

1. the ACP base asks the concrete mapper for one outbound ACP message id;
2. the DeepSeek plugin adds that id under the namespaced prompt `_meta` field;
3. the adapter validates it and freezes the DeepSeek `UserMessage` with the same
   id rather than minting another; and
4. live presentation and detached replay use the same ACP `messageId` mapping.

The default hook preserves all existing ACP plugin behavior. No post-hoc ID
repair map or persisted correlation sidecar is added.

History projects only direct human user messages, assembled assistant content,
reasoning, tools/results, and user-visible status. Plugin-injected model context,
request headers, raw tool arguments, hidden compaction summaries, credentials,
and replacement-only model surface copies do not become transcript messages.

### Events, Options, Commands, And Interaction

Common output remains standard ACP:

- text and images -> `agent_message_chunk`;
- reasoning -> `agent_thought_chunk`;
- tool calls/results -> `tool_call` / `tool_call_update`;
- todo snapshots -> `plan`;
- title changes -> `session_info_update`;
- commands -> `available_commands_update`;
- model/reasoning state -> `config_option_update`; and
- terminal turn outcome -> the `session/prompt` stop reason plus existing
  bridge busy/idle/error lifecycle.

Only retry, compaction, and other demonstrated status values without a standard
ACP representation use `deepseek/session/status`. Unknown future kinds are
logged locally and ignored without failing the session.

`deepseek/catalog` reads current registered providers/models, exact reasoning
efforts, current default, and commands. The adapter encodes each provider/model
pair as an opaque versioned selection id; Dart never splits model ids on `/`.
Standard `session/set_config_option` applies model and reasoning values and
fails before prompt dispatch if any requested value is invalid or rejected.
One synthesized primary agent represents the full DeepSeek coding composition.

Both command-picker sends and manually typed exact slash commands travel through
`session/prompt`; the adapter recognizes the command at its admission boundary
and invokes DeepSeek's command service. It never guesses commands from ordinary
prose beginning with `/` when the name is not in the advertised catalog.

Permissions use standard `session/request_permission` with allow-once and reject
outcomes; the adapter never invents a durable allow-always grant because
DeepSeek's approval seam is one-shot. `deepseek/ask_user_question` is a
server-originated extension request carrying exact session id and a bounded
question batch. `DeepSeekApprovalRegistry` parses that request and registers it
in the single inherited `AcpApprovalRegistry` pending map; it adds no map or
subscription of its own and returns exact selected labels/custom answers.

### Dart Package Shape

```text
bridge/sesori_plugin_deepseek/
  pubspec.yaml, analysis_options.yaml, build.yaml
  lib/deepseek_plugin.dart, lib/deepseek_testing.dart
  lib/src/deepseek_binary.dart
  lib/src/deepseek_identity.dart
  lib/src/deepseek_event_mapper.dart
  lib/src/deepseek_approval_registry.dart
  lib/src/api/deepseek_acp_api.dart
  lib/src/api/models/                    # Generated extension DTOs
  lib/src/repositories/mappers/deepseek_catalog_mapper.dart
  lib/src/repositories/deepseek_catalog_repository.dart
  lib/src/repositories/deepseek_history_repository.dart
  lib/src/services/deepseek_session_options_service.dart
  lib/src/deepseek_plugin_impl.dart
  lib/src/runtime/deepseek_runtime_manifest.dart
  lib/src/runtime/deepseek_plugin_descriptor.dart
  lib/src/runtime/deepseek_bridge_plugin.dart
  test/
```

The package follows `Foundation -> API -> Repository -> Service -> Consumer`.
Straightforward history reads stop at Repository and are consumed directly;
options need a Service because one operation coordinates catalog policy and
connection-scoped ACP config writes. All external DTO-to-product mapping stays
in repositories or repository-owned pure mappers. No Service maps wire DTOs.

`DeepSeekEventMapper` is the existing ACP transport-projection seam, not a
catalog DTO mapper: it receives already-decoded `AcpNotification` maps and
returns normalized `BridgeSseEvent` values while inheriting the base mapper's
per-session stream accumulators. DeepSeek extension catalog/history DTOs never
enter it.

### Dart Collaborator Ownership

| Class | Layer and stored collaborators | State/lifecycle responsibility | Composition and consumer |
|---|---|---|---|
| `DeepSeekIdentity` | Foundation; no collaborators | Immutable id/display constants only | Read by the package composer and registration |
| `DeepSeekBinary` | Foundation builder; no stored collaborators | Pure explicit/PATH/managed launch spec and environment construction | Called by `DeepSeekPluginDescriptor` before plugin composition |
| `DeepSeekAcpApi` | API; no stored live client | Validates/serializes extension requests and generated DTO responses; no state/disposal | Constructed once by `DeepSeekBridgePlugin`; each method receives the exact borrowed `AcpStdioClient` supplied for that operation |
| generated extension DTOs | API models; no collaborators | Closed wire values only | Consumed only by `DeepSeekAcpApi` and repositories |
| `DeepSeekCatalogMapper` | Repository-owned pure mapper; identity only | Maps catalog DTOs to `PluginAgent`, `PluginProvider`, `PluginModel`, variants, and commands; no state | Injected into `DeepSeekCatalogRepository` by `DeepSeekBridgePlugin` |
| `DeepSeekCatalogRepository` | Repository; API + catalog mapper | One catalog request and DTO-to-domain mapping; no cache, subscription, or disposal | Injected into `DeepSeekSessionOptionsService` |
| `DeepSeekHistoryRepository` | Repository; API + DeepSeek event mapper/identity needed by `AcpReplayCollector` | Owns bounded cursor pagination and reconstructs `PluginMessageWithParts`; no process/client ownership or cache | Injected directly into `DeepSeekPlugin`; receives a borrowed live client per history operation |
| `DeepSeekSessionOptionsService` | Service; catalog repository + identity/config ids | Owns coherent options/agent/provider/command discovery and the business rule that every requested model/reasoning write succeeds before prompt dispatch; no cache | Injected into `DeepSeekPlugin`; receives `AcpSessionConfigRepository` per turn from the base hook |
| `DeepSeekEventMapper` | Transport mapper; extends `AcpEventMapper` and stores only inherited mapping trackers | Maps standard/status notifications, stable ids, and live turn finalization; base/plugin disposal clears inherited session state | Constructed by `DeepSeekBridgePlugin` and injected into both `AcpPlugin` and history repository |
| `DeepSeekApprovalRegistry` | Request registry; extends `AcpApprovalRegistry` | Uses the one inherited subscription and pending map for standard permissions plus DeepSeek questions; adds parsing only, no second state | Built by the `DeepSeekPlugin.buildApprovalRegistry` hook for each live connection; base `AcpPlugin` attaches/cancels/disposes it |
| `DeepSeekPlugin` | Consumer/composition recipient; event mapper, history repository, options service, and normal ACP base dependencies | Owns no child construction; delegates live connection/turn/session lifecycle to `AcpPlugin` and backend operations to injected peers | Constructed only by `DeepSeekBridgePlugin` |
| `DeepSeekRuntimeManifest` | Runtime foundation; no mutable collaborators | Pure version/target/archive/checksum data | Injected into descriptor provisioning services by app composition |
| `DeepSeekPluginDescriptor` | Runtime consumer; manifest, command executor, managed provision/install services, and binary builder | Setup inspection, runtime precedence, install/ensure/start policy; no live ACP child | Constructed in bridge app registry composition and creates `DeepSeekBridgePlugin` only from resolved host capabilities |
| `DeepSeekBridgePlugin` | Lifecycle/composition root; host process service, resolved binary/state, and immutable descriptor inputs | Constructs all peer collaborators once, injects them into `DeepSeekPlugin`, and delegates start/exit/reset/dispose to `AcpBridgePlugin` | Returned only by `DeepSeekPluginDescriptor.start` |

`DeepSeekPlugin` receives already-constructed peers and never constructs a
repository/service from dependencies passed through its constructor. The
composer may construct child mappers inside their owning repository constructor
call, but every peer shown above is constructed side by side and injected.

No 1:1 interfaces, manager/helper classes, DeepSeek file API, history Service,
catalog Service, or mutable catalog tracker is introduced. Tests implement
concrete classes directly where needed.

### ACP Live-Connection Hook

Step 7 adds one protected `AcpPlugin.requireConnectedClient()` method that
awaits the existing private connection path and returns the exact current
`AcpStdioClient` or the existing typed authentication/connection failure. It
does not expose connection creation/reset/disposal, does not retain a lease, and
does not change public `BridgePluginApi` behavior. `DeepSeekPlugin` calls it at
the start of catalog/history operations and passes that client down as a method
argument; repositories/APIs never cache it. Existing prompt operations retain
the base's private lifecycle path, and Cursor/Hermes/OMP tests prove unchanged
respawn, history, and disposal behavior.

### Pending Interaction Ownership

There is one pending owner on each side of the wire:

- In Node, DeepSeek's approval/user-question call owns the waiting Promise and
  abort signal; `AgentSideConnection` owns JSON-RPC id correlation. The adapter
  provider holds no second pending map. Session cancel/close aborts the owning
  call before agent-handle disposal; connection/context disposal rejects any
  remaining SDK requests.
- In Dart, the one connection-scoped `AcpApprovalRegistry._pending` map owns
  both standard permissions and DeepSeek questions. The subclass only validates
  exact session/question schema and calls `addPendingQuestion`. `AcpPlugin`
  owns the registry subscription, cancels session entries on abort/close, then
  disposes the registry before the stdio client so cancellation replies and SSE
  cleanup are attempted while the connection is available.

Every request is correlated by JSON-RPC id plus explicit session id. DeepSeek
questions never use `activeTurnSessionId` fallback; absent/malformed session id
is rejected. A response after either side settled is ignored by the SDK/base
registry and cannot recreate pending UI.

### Protocol Source And Release Order

Step 2 creates `protocol/v1/deepseek-acp.schema.json` and a synthetic JSON
conformance corpus in `sesori-deepseek-acp`. That JSON Schema is the sole
machine-verifiable extension source. Runtime handlers/types validate against
it; `PROTOCOL.md` is explanatory.

Step 7 vendors the exact schema/corpus under the DeepSeek plugin's test fixtures
with a source manifest containing runtime repository commit and SHA-256 values.
Generated Dart DTOs and extension tests must accept every success fixture and
reject every invalid fixture. Each later protocol-consuming PR reruns the full
vendored corpus. A protocol change follows this order:

1. merge schema, runtime validation/types, and corpus in the runtime repository;
2. vendor that exact commit/digests and update Dart DTO/mapping tests;
3. run cross-repository conformance;
4. publish the adapter release; and
5. pin its immutable assets in the monorepo.

A backward-incompatible change increments the extension protocol integer. Step
11 may fix packaging but may not change protocol v1 after the consumer corpus
has passed; a required protocol change pauses the series and rebaselines the
plan/tracker before another PR opens. No shared production schema package or
network-dependent CI check is added.

### Managed Runtime And Release Ownership

`sesori-deepseek-acp` publishes one package-directory archive for each Sesori
bridge target:

| Target | Archive |
|---|---|
| macOS arm64 | `sesori-deepseek-acp-v<version>-darwin-arm64.tar.gz` |
| macOS x64 | `sesori-deepseek-acp-v<version>-darwin-x64.tar.gz` |
| Linux arm64 | `sesori-deepseek-acp-v<version>-linux-arm64.tar.gz` |
| Linux x64 | `sesori-deepseek-acp-v<version>-linux-x64.tar.gz` |
| Windows arm64 | `sesori-deepseek-acp-v<version>-windows-arm64.zip` |
| Windows x64 | `sesori-deepseek-acp-v<version>-windows-x64.zip` |

Each archive contains a relative launcher (`sesori-deepseek-acp` or `.cmd`),
the pinned official Node executable, compiled adapter output, production
`node_modules`, lockfile/SBOM, and third-party notices. Windows launch uses the
existing ACP host process shell behavior; Unix launchers resolve their sibling
Node path and `exec` it. Release CI installs/builds dependencies on each target,
runs adapter `--version`, `check`, initialize, list, new, history, prompt with a
deterministic provider fixture, close, and restart/load smoke, then publishes
SHA-256 sums. A target is not advertised in Dart until that exact artifact
passes; Step 11 cannot complete with an unverified target silently listed.

`DeepSeekRuntimeManifest` uses `packageDirectory`, adapter semantic versioning,
the six immutable URLs/digests, and launcher member paths. Managed install
reuses existing checksum, atomic placement, sentinel, permission, and sweep
behavior. The monorepo pins the adapter version, not DeepSeek's npm version;
the adapter release owns its exact DeepSeek dependency closure.

## Compatibility And Security

- Standard ACP protocol version is 1. Initialize metadata advertises DeepSeek
  extension protocol version 1, adapter version, and pinned harness version.
  The Dart plugin refuses an absent/unsupported extension version before
  exposing DeepSeek-only capabilities.
- Once publicly released, extension version 1 remains backward/forward
  compatible within its documented optional-field and unknown-variant rules.
  Before that first production release, both repositories update in lockstep
  without compatibility shims.
- No client/bridge wire shape changes. Plugin ids remain strings. The existing
  unknown-id icon/raw-name behavior covers older clients.
- The adapter binds no socket. Stdout is protocol-only; stderr and bridge logs
  retain errors, stack traces, versions, safe paths, and operation context but
  never print raw NDJSON, prompts, transcript content, reasoning, image bytes,
  tool arguments/results, credentials, or settings documents.
- RPC errors sent to clients are bounded and privacy-safe. The adapter and Dart
  wrappers preserve the original cause locally when translating failures.
- Package and Node artifacts are immutable and checksum-verified. Release
  notices cover MIT and every redistributed native/runtime dependency.
- DeepSeek tools execute with the bridge user's OS identity. Workspace-write is
  the default policy, but model tools still read project content and execute
  sandboxed commands; setup guidance states this before activation.
- Multiple bridges naturally use distinct plugin state directories. No global
  lock, ownership file, or cross-bridge registry is added for a state collision
  normal product flows do not produce.

## Analytics Assessment

No new analytics event is planned.

- Session creation, message submission, abort, questions, permissions, and
  managed-install outcomes already have authoritative backend-neutral events.
- Existing managed-install analytics intentionally omits harness identity.
- A DeepSeek-specific adoption event would expose a coding backend identity and
  requires a separate reporting and privacy decision this integration does not
  need.

## Complexity Budget And Cleanup

New persistent mutable state:

- DeepSeek-owned JSONL sessions, normalized attachments, query/index files, and
  spill files under the existing plugin state directory. Each is required by
  the coding runtime and has one writer in one process.
- No new Sesori database table, column, transport field, preference, marker, or
  compatibility record. Existing session rows, transcript storage, managed
  runtime state, disable list, and deleted-session tombstones are reused.

New in-memory mutable coordination:

- Runtime `sessionId -> AgentHandle` ownership and per-session in-flight prompt
  state. These are the minimum live resources and mirror upstream's current ACP
  owner.
- Pending DeepSeek questions/permissions live in the existing ACP approval
  registry and runtime service promises. No second pending registry is added.
- Existing `AcpPlugin` turn lanes and event mapper trackers remain the bridge
  owners. No DeepSeek process pool, catalog cache, event dedupe set, timer,
  socket, global current-session field, or scratch-client registry is added.

Safeguards cover ordinary flows with meaningful impact: bridge restart/resume,
two live sessions, abort during prompt/image admission, process exit, and a
client answer arriving after cancellation. The plan deliberately accepts a
retained upstream artifact after local deletion and stale ordering metadata on
a cold adapter-only row rather than adding private storage mutation or a new
projection cache.

This feature is additive and makes no production model, database field, route,
job, or listener obsolete. Directly caused cleanup is limited to expanding
hardcoded package/registry/workspace/runtime-update inventories and keeping
exact-set fixtures accurate. Stock DeepSeek ACP/Web code is not copied into the
monorepo, and no existing ACP plugin is refactored beyond the two narrow hooks.

## Dependencies And Sequencing

1. Step 1 lands this plan before production work.
2. Steps 2-6 land in `sesori-ai/sesori-deepseek-acp`; they use the canonical
   JSON Schema/corpus and a deterministic provider and do not publish a
   production asset yet.
3. Steps 7-10 land in this monorepo and can test against a local runtime checkout
   or packed npm workspace supplied by the runtime repository.
4. Step 11 runs cross-repository conformance, pins final dependency versions,
   verifies all six targets, and publishes the first immutable adapter release.
5. Step 12 pins only that published release and checksums in the Dart manifest.
6. Step 13 activates the registered plugin only after setup, lifecycle, and
   mandatory security/local-setup guidance exist.
7. Step 14 reconciles all affected regression feature documents.
8. Step 15 runs the recorded level/matrix and retires the plan only after Steps
   1-14 merge and required evidence passes. Any reduction requires explicit
   owner acceptance in this file.

## Delivery Rules

- `TRACKER.md` is canonical for the fixed fifteen exact PR titles, repository,
  complexity, line target, order, and state.
- Every PR targets its repository's main branch and follows the prior numbered
  step. Cross-repository PR titles still use the exact `deepseek-harness` slug
  and `/15` denominator.
- Production Steps 2-13 run owning tests, strict analysis/lint, build or codegen
  where applicable, `git diff --check`, and architecture implementation review
  when required by repository scope.
- Runtime fixtures contain no real source, prompts, credentials, paths, or raw
  authenticated traces. Deterministic transcripts use synthetic content.
- A step expected to exceed 1,500 changed lines must first split coherently or
  record why an independently valid split is not practical.

## Step Details

### Step 1/15: Plan DeepSeek Harness support

- Add this `PLAN.md`, `TRACKER.md`, and `PROTOCOL.md` under
  `.plan/active/deepseek-harness/`.
- Record the exact upstream baseline, one-process architecture, state/config
  boundary, extension protocol, fixed delivery sequence, risks, and retirement
  matrix.
- Run architecture plan review and Markdown/diff validation. No Dart, Flutter,
  or Node suites run for this documentation-only step.

### Step 2/15: Scaffold the DeepSeek ACP adapter

- Create `sesori-ai/sesori-deepseek-acp` with TypeScript ESM, Node 24 toolchain,
  exact ACP/DeepSeek pins, lockfile, lint/test/build scripts, CLI parsing,
  stdout/stderr discipline, typed errors, fixture transport, license, notices,
  and protocol constants.
- Add canonical `protocol/v1/deepseek-acp.schema.json`, synthetic valid/invalid
  conformance fixtures, runtime schema validation/types, `--version`,
  side-effect-free `check`, and a minimal initialize-only `serve` composition
  using `AgentSideConnection`.
- Cover LF/CRLF/chunk framing, request correlation, unknown methods, malformed
  JSON, stdout purity, bounded diagnostics, SIGINT/SIGTERM, EOF, and version
  metadata. No session map or model invocation lands yet.

### Step 3/15: Compose the DeepSeek coding runtime

- Load exact `dsh-base` through a package-owned profile/overlay and mount the
  custom transport in one Cordis context.
- Add state-root resolution and overrides for sessions, attachments, query, and
  spills; keep normal `DSH_HOME` for read-only settings/credentials/skills;
  force telemetry off and workspace-write/ask defaults.
- Add deterministic provider fixtures and profile invariants proving no Web,
  Host, HMR, HTTP, global-default write, normal-session-root write, or stdout
  logger is mounted.
- Cover default/custom `DSH_HOME`, environment credentials, two project cwd
  policies, state permissions, missing/unwritable state, teardown order, and
  absent credential behavior without a network request.

### Step 4/15: Add durable ACP sessions and replay

- Implement standard list/new/load/close and exact `AgentHandle` ownership,
  persisted resume, load replay, detached paginated `deepseek/session/history`,
  stable session/message identity, config-option state, and process disposal.
- Project only user-visible append-origin history and map parent/subagent header
  metadata without importing the normal DeepSeek session root.
- Cover blank/lazily materialized sessions, cold/live list, restart/load, two
  resident sessions, duplicate ids, cwd conflicts, pagination boundaries,
  unknown required events, interrupted-tail recovery, close without deletion,
  and no-agent detached reads.

### Step 5/15: Stream DeepSeek turns and interactions

- Implement prompt/image admission, canonical caller message ids, prompt/cancel
  settlement, text/reasoning/image/tool/todo/title/usage updates, standard
  permissions, DeepSeek questions, and bounded retry/compaction status.
- Keep exact per-session ownership across concurrent turns and drain pending
  interaction/output work before handle/context disposal.
- Cover deltas/finals/replay parity, tool call/result pairing, diff presenters,
  cancellation before/during image persistence/model/tool work, refusal/error/
  max-token outcomes, late answers, missing answerer fail-closed behavior,
  subagent question rejection, process shutdown, and content non-logging.

### Step 6/15: Expose DeepSeek catalogs and commands

- Implement `deepseek/catalog`, opaque provider/model selection ids, exact
  reasoning efforts, current/default selection, one primary DeepSeek agent, and
  available commands.
- Apply model/reasoning through standard ACP config options and route only exact
  advertised slash commands through DeepSeek's command service at prompt
  admission.
- Add `deepseek/session/rename` through the title owner; leave archive and
  persisted deletion unsupported.
- Cover providers/models containing slashes and Unicode, partial provider
  catalog failure, changing settings, selection before first prompt, resumed
  selection, invalid/partial writes failing closed, command-vs-prose parsing,
  synchronous/turn-driving commands, rename, and no credential/error leakage.

### Step 7/15: Scaffold the DeepSeek bridge plugin

- Create `bridge/sesori_plugin_deepseek`, public/testing barrels, identity,
  binary launch spec, generated extension DTOs, `DeepSeekAcpApi`, event mapper,
  approval registry, and app-invisible bridge workspace/CI/dependency inventory.
- Add the narrow ACP base hooks for plugin-owned outbound prompt identity and
  metadata plus protected `requireConnectedClient()` while preserving all
  existing Cursor/Hermes/OMP behavior.
- Vendor the exact runtime JSON Schema/corpus with source commit/digests; add
  adapter extension-version validation at initialize and generated DTO tests
  against every fixture.
- Cover launch args/environment, exact extension schemas, incompatible adapter,
  prompt metadata, existing ACP regression suites, unknown extension variants,
  and generated JSON omission rules.

### Step 8/15: Map DeepSeek sessions and history

- Add history repository pagination over the live ACP client borrowed only
  through `AcpPlugin.requireConnectedClient()` and feed returned standard
  updates through `AcpReplayCollector`.
- Implement list/import mapping, bridge-derived projects, stable DeepSeek IDs,
  parents/children, load/resume, canonical live/replay user identity, and local
  close/delete behavior.
- Ensure `getSessionMessages` never launches a scratch ACP process and normal
  catalog reads remain database-only outside explicit import.
- Cover cold/live/restart history, page boundaries, two sessions, initial and
  later prompt IDs, hidden context omission, unknown events, upstream artifact
  retention/tombstone, and cause-preserving failures.

### Step 9/15: Map DeepSeek turns and interactions

- Map DeepSeek standard updates and status extensions into existing live text,
  reasoning, image, tool, plan, title, usage, retry, compaction, error, and diff
  behavior.
- Route permissions through standard ACP and questions through the DeepSeek
  approval registry, preserving exact session/tool/question correlation.
- Cover live/replay parity, concurrent sessions, prompt queueing, abort and
  recovery, once/reject permissions, multi/single/custom questions, unsupported
  question degradation, late reply cleanup, and process exit/disposal.

### Step 10/15: Expose DeepSeek options and lifecycle

- Add catalog repository and history-independent session-options service, one
  primary agent, providers/models/reasoning variants, commands, selection
  application, rename, health, status summary, and every remaining
  `BridgePluginApi` method.
- Add plugin descriptor and bridge wrapper around an explicit/PATH runtime for
  setup inspection, ensureRuntime, lazy activation, restart, disable, and
  shutdown. Managed install remains disabled until Step 12.
- Cover complete/partial/failed catalog discovery, opaque values, current
  default, refresh, selection failure before prompt, local setup guidance,
  runtime crash/restart, no-op contracts, and idempotent disposal.

### Step 11/15: Release the managed DeepSeek adapter

- Recheck the latest DeepSeek prerelease. Keep `0.1.1-rc.2` unless a newer exact
  release passes the complete protocol/conformance suite; record any refreshed
  baseline in both plan and protocol files before publishing.
- Pin the adapter version and Node patch, aggregate licenses/SBOM, build all six
  package-directory archives on matching targets, run target smoke and
  cross-repository conformance, and publish immutable assets plus SHA-256 sums.
- Verify Node/native dependency loading, launcher relocation, no system Node/npm,
  stdout purity, check/initialize/list/new/prompt/history/load/close, restart,
  and telemetry/state isolation on every target. Rerun the canonical and
  vendored conformance corpus without changing protocol v1. A missing target is
  Blocked, not silently supported.

### Step 12/15: Install the managed DeepSeek runtime

- Add `DeepSeekRuntimeManifest` with the exact Step 11 version, six assets,
  checksums, package layout, semantic floor, explicit/PATH/managed precedence,
  descriptor install capability, provision/install services, and setup output.
- Pass only adapter/state/security environment owned by the plugin and extend
  `update-backend-runtimes` to verify adapter release checksums, extension
  version, and reported DeepSeek pin.
- Cover six target mappings, checksum failure, cancellation/interruption,
  atomic package adoption, stale sweep, explicit/PATH precedence, too-old PATH
  fallback, reported version, no-install unsupported state, and local managed
  install plus ACP smoke.

### Step 13/15: Activate DeepSeek Harness

- Add `Harness.deepseek`, bridge app dependency and registration in
  `bridge/app/lib/src/runtime/plugin_registry.dart`, exact known-plugin fixtures,
  display name, generic icon presentation, local setup/security/state ownership
  guidance, and scalable harness documentation copy.
- Preserve OpenCode as preferred default and unknown-id fallback. Do not add
  backend checks to client cubits/widgets or a DeepSeek analytics event.
- Verify registry/setup/management/catalog/picker behavior, install controls,
  light/dark generic presentation, older-client fallback, app/client analysis,
  and architecture implementation review.

### Step 14/15: Reconcile DeepSeek regression coverage

- Update the affected `docs/regression/` files listed below with shipped
  DeepSeek behavior, supported matrix, state/config isolation, generic icon,
  local setup, standard/extension interaction, and retained-artifact limits.
- Correct `PROTOCOL.md` and `TRACKER.md` from implementation evidence and remove
  no-longer-true assumptions. Do not describe unexecuted behavior as passing.
- Run Markdown/reference checks and `git diff --check`; no Dart/Flutter suites
  for this documentation-only step.

### Step 15/15: Verify DeepSeek and retire the plan

- Run the complete matrix below with the published managed adapter and record
  versions, platforms, build ids, privacy-safe evidence, outcomes, and cleanup
  in `TRACKER.md`/`PROTOCOL.md`.
- Confirm Steps 1-14 merged and every required row passes. Move
  `.plan/active/deepseek-harness/` to `.plan/completed/deepseek-harness/` only
  then. A reduction requires explicit owner acceptance recorded here.
- This PR is verification/evidence/retirement only and contains no production
  fix or runtime release. A discovered defect keeps Step 15 blocked; open
  separate owning-repository correction and, when needed, adapter release plus
  monorepo pin PRs. Rebaseline the fixed series total/titles in the plan/tracker
  before those PRs open, complete them, then rerun only affected evidence and
  resume Step 15.

## Regression And Retirement Matrix

The highest required level is **L5 Full** because the product claims a
checksummed packaged runtime on six host targets. Feature behavior requires the
listed cumulative L3/L4 evidence; this does not require unrelated L5 checks
outside DeepSeek's delivered behavior.

| Feature document | Required DeepSeek evidence | Boundary and matrix |
|---|---|---|
| `plugin-runtime-installation.md` | Missing/too-old install through checksum, extraction, enable, version report, interruption/checksum failure, stale sweep, and exact release digests | L5; packaged/external; all six advertised hosts |
| `plugin-setup-and-lifecycle.md` | Inert registration, explicit/PATH/managed precedence, check/ready, missing/old adapter, local setup guidance, on-demand start, restart, disable/enable, crash recovery, clean shutdown, unknown-client fallback | L4 plus L5 registry listing; headless bridge + client E2E + live plugin; release host and one alternate OS |
| `projects-and-sessions.md` | Explicit import only from adapter state, no normal `DSH_HOME` session import, bridge-derived projects, parent/child metadata, normal database-only reads | L4; headless bridge + live plugin |
| `session-creation-and-options.md` | New cwd/session identity, provider/model/reasoning catalog, default/current selection, opaque custom ids, fail-closed selection, one primary agent | L4; client E2E + live plugin |
| `session-turns.md` | Text/reasoning/status, queue, two concurrent sessions, slash command and prose distinction, abort/recovery, refusal/error/max-token, process restart | L4; client E2E + live plugin |
| `session-history-and-recovery.md` | Paginated detached history, initial/later message-id parity, no scratch process, plugin/bridge restart, synced reopen while stopped, interrupted-tail recovery | L4; headless bridge + client E2E + live plugin |
| `questions-and-permissions.md` | Allow once/reject, missing answerer fail closed, single/multi/custom questions, two-session correlation, abort/exit/late-answer cleanup | L4; client E2E + live plugin |
| `attachments-and-images.md` | Valid inline image to a vision-capable model, output image when available, invalid/oversized/path/URL/non-image rejection | L3 plus targeted L4 failures; client E2E + live plugin |
| `tools-and-file-changes.md` | Tool call/running/result/error, bounded output, presenter diff, replay parity, real workspace file result | L3; client E2E + live plugin |
| `session-archiving-and-deletion.md` | Local close/purge/tombstone, no re-import, retained adapter artifact documented, no private-file deletion | L3; headless bridge + live plugin |
| Compatibility | Adapter extension-version refusal/unknown optional fields; older-client generic icon/raw fallback; older bridge has no DeepSeek entry | Automated + client E2E with the required build pair |
| Security/privacy | State root isolation, normal `DSH_HOME` read-only behavior, telemetry forced off, workspace-write/ask, no HTTP listener, no sensitive logs/evidence | Automated + live plugin + packaged inspection on every host |

Retirement evidence uses one release-target mobile client through the real
client -> relay -> bridge -> plugin path. Alternate client-platform coverage is
required only for shared generic presentation behavior; runtime behavior is
host-scoped. Authenticated model checks may use one real supported provider,
while deterministic provider fixtures prove errors, retries, permissions,
questions, tools, and platform packaging without committing credentials.

## Risks And Test Focus

- **Prerelease drift:** DeepSeek session format is version 0 and explicitly has
  no compatibility promise. Exact package pins, adapter protocol versioning,
  fixtures, and release conformance absorb this; no speculative migration is
  added.
- **Cross-repository skew:** the Dart plugin and adapter release separately.
  Initialize extension metadata plus descriptor minimum version fails setup
  before a missing method can corrupt a session.
- **Persistence ownership:** two writers could corrupt append-only logs. The
  isolated bridge-specific root and one process/context are load-bearing; do not
  add Web/CLI attach or a second adapter process.
- **Privacy:** DeepSeek telemetry can export raw records. The overlay disables
  it structurally and tests inherited opt-in environment cannot re-enable it.
- **Credentials:** a bootable catalog does not prove the provider works. Setup
  never makes a model request; prompt/catalog failures preserve the local cause
  and show bounded local configuration guidance.
- **Selection correctness:** provider/model ids may contain `/` or Unicode.
  Treat adapter selection ids as opaque and require every config write before
  prompt dispatch.
- **Replay parity:** duplicate user messages damage durable transcripts. Test
  initial and later prompts across plugin/bridge restart using the exact
  caller-owned message identity path.
- **Rich event drift:** only documented event variants map. Unknown ignorable
  events are logged/dropped; unknown required history events fail the read
  rather than silently producing a wrong transcript.
- **Platform closure:** npm packages can contain target-specific native code.
  A successful TypeScript build is insufficient; each distributed archive must
  run on its target before advertisement.
- **Deletion residue:** local deletion does not erase DeepSeek JSONL/attachments.
  Tombstones prevent user-visible resurrection. This bounded disk residue is
  accepted instead of mutating private layouts.

## Expected Result

A user can install DeepSeek Harness from Sesori, complete provider setup locally,
select it in the normal harness picker, create or resume Sesori-owned DeepSeek
sessions, choose discovered models/reasoning, stream rich coding work, answer
questions and permissions, send images, abort, restart, and replay history from
phone or desktop. Other harnesses remain unaffected when DeepSeek is missing,
misconfigured, incompatible, or crashes.

The change is user-visible through a new harness and managed install. It adds no
Sesori database schema or client/bridge wire shape. DeepSeek session artifacts
are new plugin-owned persisted data under the bridge state directory, with the
retained-deletion limitation stated explicitly.
