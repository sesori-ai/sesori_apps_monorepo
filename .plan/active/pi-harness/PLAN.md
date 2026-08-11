# Pi And Oh My Pi Harness Support

## Status

- **Plan slug:** `pi-harness`
- **Status:** Step 4/21, Pi and Oh My Pi plan revision
- **Plan date:** 2026-08-10
- **Revised:** 2026-08-11 after Steps 1-3 merged
- **Implementation base:** `origin/main` at
  `ca550a7b8ff98db06d7fdb2873aa0867fd754f55`
- **Upstream research baselines:** Pi Agent Harness `v0.84.1`, published
  2026-08-07 from `earendil-works/pi`, and Oh My Pi `v17.2.13`, published
  2026-08-11 from `can1357/oh-my-pi`
- **Plan delivery:** `PLAN.md`, `TRACKER.md`, and Pi `PROTOCOL.md` landed in
  Step 1/21; this revision and `OMP_PROTOCOL.md` are Step 4/21
- **Delivery:** two planning PRs, fifteen bridge package/runtime PRs, one joint
  activation PR, one client/docs PR, one live-verification PR, and one
  plan-retirement PR

## Goal

Add both [Pi Agent Harness](https://github.com/earendil-works/pi) and
[Oh My Pi](https://github.com/can1357/oh-my-pi) (OMP) as independent first-class
Sesori coding backends. Sesori must install and verify each backend's official
runtime, drive Pi through its documented JSONL RPC mode, drive OMP through ACP
v1, and expose both experiences from phone and desktop surfaces without
conflating their identities, storage, protocols, or release trains.

"Full support" in this plan means:

- managed runtime install on every supported platform for which each upstream
  publishes a compatible release;
- existing and Sesori-created Pi and OMP sessions grouped by their real working
  directories;
- new and resumed sessions;
- persisted history and live text/reasoning streaming;
- tool calls, partial output, completion, errors, retries, compaction, and
  abort;
- configured providers, models, model-specific thinking levels, commands,
  skills, image prompts, and reachable extension dialogs for both backends;
- the existing plugin management, picker, catalog, relay, and client flows; and
- explicit, honest degradation for backend features that the selected Pi RPC or
  OMP ACP boundary does not expose.

## Success Criteria

1. `GET /plugin` advertises separate `pi` and `omp` entries with display names
   `Pi` and `Oh My Pi`, correct setup/install capabilities, and distinct
   first-party brand marks.
2. Tapping Install downloads the pinned asset for the current host, checks its
   SHA-256, installs Pi's complete package tree or OMP's bare executable under
   separate managed-runtime directories, and starts only the selected plugin.
3. A compatible PATH binary wins over its managed copy; a too-old PATH binary
   falls back to that plugin's exact pin. Explicit `--pi-bin` and `--omp-bin`
   values remain authoritative and independently disable managed install.
4. A new phone-created Pi session uses a bridge-generated ID; OMP returns its
   own stable ID from ACP `session/new`. Both launch in the chosen
   project/worktree, stream text/reasoning/tools, and remain resumable after a
   bridge restart.
5. Existing Pi sessions import through a bounded metadata-only file scan. OMP
   sessions import through paginated ACP `session/list`; Sesori never parses OMP
   transcript files merely to enumerate them.
6. Imported Pi sessions retain resolvable `parentSession` relationships. OMP
   parent/child lineage is explicitly unavailable because ACP `session/list`
   does not expose it; no private-file scan is added solely to infer that field.
7. Multiple sessions run concurrently. Pi owns one lazy RPC process per active
   session; OMP uses one lazy ACP process that natively hosts multiple sessions.
8. Model/provider discovery is project-scoped. Pi probes a non-persisted RPC
   session; OMP probes ACP config options in an isolated temporary session root.
   Both expose exact per-model thinking levels without hardcoded provider rules.
9. Pi RPC dialogs and OMP ACP form elicitations round-trip as Sesori questions.
   Backend notifications and local-login guidance use backend-neutral toast
   presentation where the selected protocol exposes them.
10. Pi's native no-permission-prompt behavior is preserved. OMP's inherited
    `tools.approvalMode` is preserved: its default `yolo` mode asks nothing,
    while a user-configured stricter mode uses standard ACP permissions.
11. Project-scoped discovery and prompt failures use ordinary operation/session
    failure plus privacy-safe local `/login` guidance; they never disable either
    backend for unrelated projects through plugin-global auth state.
12. Supported inline image data reaches Pi RPC or OMP ACP. Unsupported
    attachment forms fail visibly and never become accidental prompt strings.
13. Pi behavior stays in `bridge/sesori_plugin_pi/`; OMP behavior stays in
    `bridge/sesori_plugin_omp/`. Only standard ACP behavior is shared through
    `sesori_plugin_acp`; no Pi-family protocol or storage abstraction is added.
14. No new relay route, database column, or `MessagePartType` is introduced.
    Older clients treat unknown `pi` and `omp` identities through existing
    data-driven compatibility and retain generic failures.
15. Every implementation PR is independently buildable and normally stays at
    or below 1,500 changed lines, including tests and generated output.

## Research Findings

`PROTOCOL.md` is the canonical Pi record and `OMP_PROTOCOL.md` is the canonical
OMP record. The load-bearing conclusions are:

- Pi exposes strict-LF JSONL RPC, not ACP, with request-ID correlation but no
  handshake or capability version.
- RPC controls one loaded session and exposes turns, history, models, commands,
  tools, retries/compaction, abort, rename, and extension dialogs, but no global
  session list, delete, login, attach, or native permission protocol.
- Catalog import therefore reads only bounded metadata from Pi's documented
  JSONL session files; it never reads transcript text merely to enumerate.
- Upstream supports new, absolute-path resume, and parent-fork launches; new
  files appear only after the first assistant message is persisted.
- Auth uses normal Pi environment/config or local `/login`; pending dialogs are
  process-local and cannot survive process replacement.
- Official standalone releases are complete package trees, not lone binaries.
- OMP is an independently versioned hard fork, not a wire-compatible Pi build.
  Its current RPC mode adds negotiation/chunking and removes Pi commands and
  launch flags on which the merged Pi code depends.
- OMP exposes ACP v1 through `omp acp`; source and a live `v17.2.13` binary
  verified `initialize`, authentication, global/scoped paginated session lists,
  persistent `session/new`, `session/load`, `session/resume`, models/thinking/
  modes through config options, commands, images, tools, permissions, and form
  elicitations.
- OMP ACP solves the missing caller-owned session-ID problem because
  `session/new` returns OMP's durable ID. Reusing `sesori_plugin_acp` also avoids
  implementing OMP's separate JSONL RPC dialect and tracks the protocol OMP
  actively exposes to editor clients.
- OMP `v17.2.13` publishes seven checksummed bare executables: macOS arm64/x64,
  Linux glibc arm64/x64, Linux musl arm64/x64, and Windows x64. It publishes no
  Windows arm64 asset.

Pi `v0.84.1` publishes these six checksummed assets:

| Target | Asset | SHA-256 |
|---|---|---|
| macOS arm64 | `pi-darwin-arm64.tar.gz` | `683c84261f40b870b4a7ccf181a48ad6ecd71853b0112d1bb617539530c6121d` |
| macOS x64 | `pi-darwin-x64.tar.gz` | `f9060962b9cca5438d7fb97b60adae9c9302503d39b68d8aea8b891e2eb3e786` |
| Linux arm64 | `pi-linux-arm64.tar.gz` | `ab95c058a4651b5ff5d8c878e524edfb776263c7a444f325505f247c056eecfc` |
| Linux x64 | `pi-linux-x64.tar.gz` | `5634d7ebd18274b63af3371e942f342d74bea012389575c1d1ff15ce6ca80c2f` |
| Windows arm64 | `pi-windows-arm64.zip` | `d118a96ddc5ba16b0b0ebf5fa4662d62f2a3682e0063d41ce3cf43d922f6eb66` |
| Windows x64 | `pi-windows-x64.zip` | `20dd3a07cfe0bdc6919dfbc479c694798ec5ea88a9c60f6e12678cecae1e5dfa` |

Unix archives wrap `pi/`; Windows is flat. Managed install uses the shared
package-directory layout and never invokes npm or Pi's installer scripts.

## Locked Product Decisions

Pi decisions 1-7 were confirmed with the user on 2026-08-10. Decisions 8-12
follow the user's 2026-08-11 request to add Oh My Pi and authorization to choose
ACP when research strongly supported it:

1. The target is `earendil-works/pi` and its `pi` CLI.
2. Preserve Pi's native no-permission-prompt policy.
3. Use the user's normal Pi data and configuration. Do not override
   `PI_CODING_AGENT_DIR`, `PI_CODING_AGENT_SESSION_DIR`, or `PI_PACKAGE_DIR` to
   create a Sesori-only profile.
4. Local Pi `/login` is sufficient. Phone/provider login is excluded.
5. Launch RPC with `--approve`, always trusting project-local Pi settings,
   extensions, skills, and prompt templates.
6. Import external terminal-created sessions, but document a handoff: exit the
   terminal Pi before continuing the same session from Sesori. Pi has no attach
   API or reliable ownership marker, so no brittle process guard is added.
7. OpenCode remains the preferred default plugin.
8. The second target is `can1357/oh-my-pi` and its `omp` CLI, with a distinct
   `omp` plugin identity. It is not presented as another Pi binary.
9. OMP uses `omp acp`, not its divergent JSONL RPC mode. There is no shared
   Pi-family package; `sesori_plugin_pi` and `sesori_plugin_omp` are sibling
   concrete plugins, with OMP reusing only the existing protocol-level
   `sesori_plugin_acp` package.
10. Use the user's normal OMP profile, data, model, plugin, and credential
    configuration. Inherit `OMP_PROFILE`, legacy `PI_PROFILE`,
    `PI_CODING_AGENT_DIR`, XDG roots, and provider credentials rather than
    creating a Sesori-only profile.
11. Preserve OMP's configured approval policy. Do not pass `--yolo` or otherwise
    weaken a user's `always-ask`/`write` policy; standard ACP permission requests
    reach the phone when OMP emits them.
12. Local OMP `/login`/setup is sufficient. Phone-side provider login and ACP
    terminal-auth orchestration are excluded from this series.

Decision 5 is security-relevant. Pi project extensions execute arbitrary code
with the bridge user's permissions. The implementation must test that
`--approve` is always present and documentation must state the consequence.

Decision 11 is also security-relevant. OMP defaults `tools.approvalMode` to
`yolo`, but users can configure stricter policies. Sesori inherits that choice
instead of silently forcing either approval or denial behavior.

## Scope

### Included

- New `bridge/sesori_plugin_pi/` pure-Dart package.
- New `bridge/sesori_plugin_omp/` pure-Dart ACP adapter package.
- Focused standard ACP additions for form elicitations, `session/close`, and a
  narrow backend failure-presentation hook used by OMP.
- Bespoke strict-JSONL RPC, metadata-only session catalog, bridge-derived
  projects, and default/configured/known session roots.
- Full reachable plugin API mapping: new/resume, rename/delete, history,
  commands/prompts, abort, health, catalogs, summaries, and cleanup.
- Per-session process residency with idle reap and full teardown.
- Text, thinking, tools, image attachments, retry/compaction/status events.
- Project-scoped model/provider/thinking/command discovery and one synthesized
  primary Pi agent because upstream has no agent preset concept.
- Extension dialogs and notifications that fit existing Sesori contracts.
- Official managed runtime download, Pi identity/branding/guidance, and runtime
  update-skill support.
- OMP ACP session enumeration/load/resume, live/replay mapping, modes, commands,
  provider/model/thinking selection, configured permissions, and isolated
  catalog probing.
- OMP persisted deletion through OMP's own loaded-session `/session delete`
  flow after standard ACP close, so OMP owns writer and artifact cleanup.
- Direct-binary managed-runtime provisioning, OMP glibc/musl selection, OMP
  identity/branding/guidance, and runtime update-skill support.

### Excluded

- Provider login or credential entry from phone.
- A Sesori permission-gate Pi extension.
- Attaching to an already-running terminal Pi process.
- Sesori-created parent forks; the current generic create flow supplies no
  parent ID. Imported upstream parent relationships remain supported.
- Pi TUI-only pickers/settings/themes/components/clipboard/raw input.
- New relay routes, database schema, shared message-part variants, or a
  Pi-specific client state branch.
- Generic files, Pi SDK embedding, npm installation, or bundled Node.
- Provider/model/tool/command names in analytics.
- OMP's JSONL RPC mode, a `sesori_plugin_pi_family` package, or sharing Pi wire,
  launch, storage, or process classes with OMP.
- OMP RPC-only host tools, host URIs, subagent frames, handoff, protocol-v2
  chunking, or other features absent from ACP.
- ACP client-owned filesystem/terminal execution. Sesori advertises those
  capabilities as false, so OMP continues to execute tools locally.
- ACP URL elicitations, phone-driven OMP terminal auth, or OMP parent/child
  lineage not present in standard ACP session metadata.

## Architecture

### Backend boundary decision

The two upstreams share ancestry, but not a stable integration contract:

| Concern | Pi `v0.84.1` | OMP `v17.2.13` |
|---|---|---|
| Supported boundary | strict-LF JSONL RPC | ACP v1 (`omp acp`) |
| Session ID creation | caller supplies `--session-id` | ACP `session/new` returns OMP ID |
| Resume/history | absolute `--session`, `get_entries` tree | ACP `session/load` replay |
| Catalog | file metadata scan | ACP `session/list` pages |
| Completion | `agent_settled` event | `session/prompt` response |
| Selection | Pi RPC model/thinking commands | ACP config options |
| Permissions/dialogs | Pi extension UI, no native permissions | ACP permissions and form elicitations |
| Runtime | extracted package directory | bare executable |

OMP's JSONL RPC is not a compatible alternative: it has a `ready` handshake,
protocol negotiation and chunk frames, adds many OMP-only methods, removes Pi's
`get_entries`, `get_tree`, `get_commands`, and thinking-level command, and does
not accept Pi's `--session-id` or `--approve` flags. A shared Pi-family base
would therefore branch on the backend at every meaningful API and would couple
two independently released protocols. The only honest shared boundary is ACP:

```text
sesori_plugin_pi  -> plugin interface + foundation + runtime + shared
sesori_plugin_omp -> sesori_plugin_acp + plugin interface + foundation + runtime + shared
```

No production class moves out of `sesori_plugin_pi`. If later evidence shows a
small backend-neutral utility has multiple real consumers, extraction can be
considered then; ancestry alone is not evidence.

### Pi plugin type and lifecycle

`PiPlugin` extends `BridgeDerivedProjectsPluginApi` and implements
`PersistedSessionCleanupApi`.

- Pi has no project model. `listAllSessions` returns sessions with their real
  header cwd and bridge core groups them into projects.
- `sessionOptionsScope` is `project`, because `--approve` loads project-local
  providers, extensions, skills, templates, and settings.
- The plugin wrapper uses `SteadyPluginLifecycle`. There is no shared server,
  socket, port, ownership file, or independently restartable daemon.
- Child RPC processes are session resources owned by the plugin, not separate
  bridge plugins.
- The descriptor remains transient under normal bridge lifecycle policy.
- Prompt attachments are declared supported because Pi RPC accepts images.

### Pi package layout

```text
bridge/sesori_plugin_pi/
  pubspec.yaml, analysis_options.yaml, build.yaml
  lib/pi_plugin.dart, lib/pi_testing.dart
  lib/src/api/{pi_launch_spec,pi_process_factory,pi_rpc_client}.dart
  lib/src/api/pi_session_storage_api.dart
  lib/src/api/models/                 # Pi wire DTOs only
  lib/src/models/                     # Pi domain variants/enums
  lib/src/repositories/{pi_session_catalog_repository,pi_session_process_repository}.dart
  lib/src/repositories/pi_backend_catalog_repository.dart
  lib/src/repositories/mappers/{pi_content_mapper,pi_history_mapper}.dart
  lib/src/trackers/{pi_catalog_tracker,pi_tool_tracker,pi_extension_ui_tracker}.dart
  lib/src/services/{pi_session_service,pi_catalog_service}.dart
  lib/src/services/{pi_extension_ui_service,pi_event_dispatcher}.dart
  lib/src/pi_plugin_impl.dart
  lib/src/runtime/{pi_runtime_manifest,pi_plugin_descriptor,pi_bridge_plugin}.dart
  lib/src/testing/fake_pi_process.dart
  test/
```

The placement follows `Foundation -> API -> Repository -> Service -> Consumer`:

- `api/` owns process invocation, wire framing, and session-file input.
- repositories consume APIs and own mapping, without Layer-2 peer dependencies;
- trackers own queryable Layer-2 catalog and tool state;
- services and the Layer-3 event dispatcher coordinate repositories/trackers;
- the plugin implementation is the consumer and composition root.

No generic RPC abstraction is extracted into shared packages. ACP, Claude, Pi,
and OMP RPC have materially different framing, request, event, and lifecycle
contracts.

### OMP plugin type and lifecycle

`OmpPlugin` extends the existing `AcpPlugin` and implements
`PersistedSessionCleanupApi`.

- It launches `omp acp` over stdio and uses the generic ACP handshake, session
  enumeration, history replay, live content/tool mapping, turn serialization,
  abort, permission, and process-recovery behavior already used by Cursor.
- OMP has no bridge-visible project model. `session/list` returns each real cwd,
  so `OmpPlugin` remains a `BridgeDerivedProjectsPluginApi` through its base.
- `sessionOptionsScope` is `project`: OMP model/plugin/command configuration can
  vary by cwd.
- One lazy ACP child hosts multiple OMP sessions. It is not forced into Pi's
  one-process-per-session model.
- The descriptor uses `SteadyPluginLifecycle`; there is no port, daemon socket,
  ownership file, or independently restarted server.
- Standard ACP prompt image blocks are supported. Client-side fs/terminal
  capabilities stay false because OMP owns local tool execution.
- OMP's `agent` auth method acknowledges use of existing local credentials; it
  is not proof that a usable model exists. Project catalog/prompt paths remain
  the authoritative readiness checks.

### OMP package layout

```text
bridge/sesori_plugin_omp/
  pubspec.yaml, analysis_options.yaml
  lib/omp_plugin.dart, lib/omp_testing.dart
  lib/src/omp_binary.dart
  lib/src/omp_event_mapper.dart
  lib/src/omp_plugin_impl.dart
  lib/src/api/omp_catalog_probe_api.dart
  lib/src/models/omp_catalog_models.dart
  lib/src/repositories/{omp_catalog_repository,omp_session_cleanup_repository}.dart
  lib/src/trackers/omp_catalog_tracker.dart
  lib/src/services/{omp_catalog_service,omp_session_options_service}.dart
  lib/src/runtime/{omp_runtime_manifest,omp_plugin_descriptor,omp_bridge_plugin}.dart
  test/
```

The OMP package owns OMP config-option IDs, model-ID splitting, commands,
failure classification, deletion command, launch flags, versions, release
assets, libc choice, and setup guidance. `sesori_plugin_acp` owns only standard
ACP method/schema/lifecycle behavior. OMP never imports `sesori_plugin_pi`, and
Pi never imports OMP or ACP.

### `PiRpcClient`

One client owns one child process and:

- launches from a typed `PiLaunchSpec`;
- consumes stdout and stderr continuously so neither pipe can stall Pi; stdout
  uses the LF-only UTF-8 framer, while stderr retains only a bounded redacted
  diagnostic tail;
- decodes top-level response, event, extension-UI, and unknown envelopes;
- correlates responses by request ID without assuming a prompt response arrives
  before agent events;
- buffers parsed frames until the first routing listener attaches, then exposes
  a broadcast stream tagged later with its owning session ID;
- never logs raw stdout frames, prompts, transcript content, tool payloads, or
  extension input;
- redacts known credential fields from diagnostic strings;
- fails all pending requests on exit/teardown; and
- closes stdin first, then uses bounded SIGTERM/SIGKILL on POSIX and bounded
  process termination on Windows.

Transport envelopes and the response, event, extension-dialog, and assistant-
delta discriminator variants are hand-written sealed types with explicit
unknown fallbacks. Closed leaf payloads use generated DTOs and land with their
first consumer so codegen does not create unconsumed multi-thousand-line PRs.
Step 3 consumes no closed leaf payload, so its generated DTO count is zero;
Step 10 adds codegen with the first closed session metadata leaves.
This matches the existing Claude transport boundary while keeping every known
Pi top-level variant typed.

### Standard ACP additions for OMP

The OMP adapter reuses `AcpStdioClient`, `AcpPlugin`, `AcpEventMapper`,
`AcpReplayCollector`, `AcpCommandTracker`, and `AcpApprovalRegistry`. Step 5
adds only protocol behavior demonstrated by OMP and valid for any ACP v1 agent:

- advertise `clientCapabilities.elicitation.form` and handle
  `elicitation/create` server requests;
- map bounded object properties of type string, string enum, and boolean into
  Sesori questions, preserving property keys only inside the ACP package;
- map accepted answers back to typed ACP scalar content, and map reject/abort/
  disposal to `decline` or `cancel` without leaving stale cards;
- degrade unsupported schemas by declining with a bounded local diagnostic;
- present editor defaults as a bounded labelled full-replacement prefill because
  the shared question contract has no editable-prefill field;
- parse `sessionCapabilities.close` and close a resident ACP session during
  delete before dropping local state; and
- add a narrow overridable post-dispatch failure mapper. The base still emits
  the generic session error; OMP may add privacy-safe local `/login` guidance
  for the demonstrated `No model selected` response without forwarding the
  response's local `agent.db` path.

The form implementation does not advertise URL elicitation or terminal auth.
It does not add OMP names or schemas to ACP core, and it does not refactor
Cursor's existing catalog package.

### OMP sessions, history, and live events

The generic ACP implementation already matches OMP's verified boundary:

- `session/list` is called unfiltered and for known directories, follows opaque
  `nextCursor` values with the existing page bound, deduplicates by OMP session
  ID, and attributes each session to the returned cwd;
- `session/new` returns the durable OMP UUID and immediately materializes a
  discoverable file, so OMP needs no Pi pending-new marker;
- `session/load` replays the active OMP transcript as standard
  `session/update` notifications on a short-lived client for history and makes
  an existing session resident before a new turn;
- `session/prompt` completion owns busy/idle settlement; text, thought, image,
  tool, plan, title, command, and usage updates use existing ACP mapping;
- `session/cancel` aborts a turn and resolves pending permissions/forms; and
- one ACP process may host independent concurrent sessions while the base keeps
  one serialized turn lane per session.

OMP ACP does not return parent metadata. `getChildSessions` therefore remains
empty for OMP, while imported Pi lineage remains fully supported. Standard ACP
also has no rename method. Sesori's title override remains authoritative for
the phone; users may invoke OMP's advertised `/rename` command when they also
want the OMP-native title changed. This is explicit degradation, not a private
OMP JSONL rewrite.

### OMP catalogs and selection

`OmpCatalogProbeApi` owns a bounded throwaway `omp acp` client launched in the
requested project cwd with `--session-dir` pointing to a plugin-state scratch
directory. The probe creates one ACP session, captures its result and bootstrap
notifications, sweeps model selections, closes the session, disposes the
process, and removes only that scratch directory. It never creates catalog
sessions in the user's normal OMP history.

`OmpCatalogRepository` maps:

- `configOptions` category/id `model` values of
  `<provider>/<model-id>` into providers and models by splitting only the first
  slash, while retaining the exact combined value for ACP writes;
- mode options into primary `PluginAgent` values, with OMP's current/default
  mode first;
- each selected model's returned `thinking` options into exact
  `PluginSessionVariant` values; and
- `available_commands_update` into existing command values.

`OmpCatalogTracker` owns the last coherent snapshot per normalized project.
`OmpCatalogService` coordinates the repository and tracker: reuse returns the
tracked snapshot or probes when absent, while refresh always probes. A no-model
result is a project-scoped failed discovery with local `/login` guidance and
never replaces the last good snapshot.

`OmpSessionOptionsService` consumes the catalog service/tracker plus the ACP
command tracker and is the project-scoped owner of `getSessionOptions`,
`getAgents`, `getProviders`, and `getCommands`; the superclass still receives
its required process-scoped `AcpSessionOptionsService` for generic ACP state.
`OmpPlugin.applyTurnSelection` reads the OMP tracker and sets model, mode, and
thinking immediately before the queued turn through
`session/set_config_option`, preserving full exact OMP wire values inside the
OMP package.

### OMP permissions, dialogs, and cleanup

OMP's default `tools.approvalMode` is `yolo`; users can configure `write` or
`always-ask`. Sesori passes no approval override. When OMP emits
`session/request_permission`, the existing ACP registry presents the supplied
allow-once/allow-always/reject options and echoes OMP's exact option ID.

OMP extension `select`, `confirm`, `input`, and `editor` plus plan approval use
the standard ACP form support above. OMP `notify` currently remains a local OMP
debug notification because upstream ACP emits no client notification for it.
Unsupported custom components, terminal input, theme, and decorations remain
upstream no-ops.

Normal bridge deletion first invokes standard ACP `session/close`, tombstones
the row, and removes it from live state. `OmpSessionCleanupRepository`, used by
`PersistedSessionCleanupApi`, then opens a bounded isolated ACP lease, finds the
exact tombstoned ID through `session/list`, loads it in its returned cwd, sends
OMP's advertised `/session delete`, closes the session, and disposes the lease.
Not-found is idempotent. This delegates JSONL writer shutdown and artifact
cleanup to OMP rather than reimplementing OMP's profile/XDG/session layout in
Dart. As with Pi, concurrently operating the same session from a terminal and
Sesori is an explicitly unsupported handoff.

### Pi session catalog

`PiSessionStorageApi` is the single resolver from a Pi session ID to its
absolute JSONL path and resolves roots without directly reading `HOME`:

1. inherited `PI_CODING_AGENT_SESSION_DIR`, when set;
2. the normal Pi agent directory selected by inherited
   `PI_CODING_AGENT_DIR`, otherwise `resolveUserHomeDirectory()` +
   `/.pi/agent`;
3. Pi's configured global session directory when present; and
4. default per-cwd session directories under the normal `sessions/` tree,
   including directories supplied through `knownDirectories`.

The exact root precedence is verified against the pinned Pi source in Step 2.
Scans run in `Isolate.run`, deduplicate normalized absolute paths, and never
follow an unbounded symlink tree.

Both `PiSessionCatalogRepository` and `PiSessionProcessRepository` consume this
Layer-1 resolver directly; neither repository depends on the other. Duplicate
paths fail. A missing file is new only with that API's pending marker; otherwise
it is not-found rather than a guessed path.

For each candidate JSONL file:

- stream bytes through a bounded LF/discriminator scanner that retains only
  header and `session_info` records; discard other/oversized bodies through the
  newline without materializing or JSON-decoding them;
- parse the bounded first session header;
- inspect only `session_info` records for the latest explicit name;
- use file mtime as updated time;
- map `parentSession` path to the parent header ID; and
- skip malformed or half-written records without printing their source text.

Catalog reads do not decode user/assistant/tool content. A missing file is not
enough to invalidate a bridge-created row because Pi persists lazily.

### Pi history and content mapping

`PiSessionProcessRepository.loadHistory` owns the client lease, RPC
`get_entries`, `leafId` branch traversal, and invocation of the repository-local
`PiHistoryMapper`; no `PiRpcClient` or Pi DTO escapes Layer 2. It reuses a
resident client or opens a bounded non-resident lease for the resolved path and
tears it down afterward. Rename uses the same lease path, while history retains
pre-compaction entries without making reads resident.

If a resolved persisted session cannot start RPC specifically because auth/model
selection fails before request dispatch, `PiSessionStorageApi` reads the file
entry DTOs only. The repository-local mapper applies pinned v1-v3 migration in
memory and selects the last valid tree entry as leaf, matching upstream reload.
The repository logs the cause; arbitrary RPC/parse failures remain thrown.

Mapping rules:

- `userVisibleText` and `userVisibleArguments` identify authored suffixes; the
  repository wraps only proven leading execution context in a plugin-owned
  marker before RPC, and strips it in live and replay paths;
- remaining user text/images become a user envelope plus text/file parts; an
  unprovable split fails creation rather than exposing or duplicating context;
- assistant text, thinking, and tool calls become existing text, reasoning, and
  tool parts;
- tool-result messages update the originating tool part by `toolCallId`;
- visible custom extension messages map conservatively to displayable text;
- direct bash-execution messages map to a tool card;
- successful compaction becomes the visible completed `compact` tool card used
  by Codex without exposing summary text; branch-summary metadata is ignored;
- model/thinking/label/custom-state entries produce no chat message; and
- unknown roles/blocks are ignored with bounded diagnostics.

Pi messages do not carry a persistent message ID. Live and replay both derive
IDs from session, role, timestamp-or-sentinel, and the occurrence ordinal among
matching messages in event/active-branch order. This disambiguates synchronous
same-millisecond custom messages. Tool call IDs remain Pi's stable IDs.

History failures throw a cause-preserving `PluginOperationException`. Only a
successfully loaded active branch with no visible messages returns `[]`.

### Pi live events and tools

Layer-3 `PiEventDispatcher` coordinates `PiToolTracker` and pure mappers to map:

- `message_start/update/end` with content-index text/reasoning deltas;
- `toolcall_end` into a pending tool part, followed by
  `tool_execution_start/update/end` running and terminal updates;
- cumulative `tool_execution_update.partialResult` by replacement, never
  append;
- `auto_retry_*` and compaction events into existing retry/status/compacted
  signals plus the replay-equivalent visible compaction card;
- authoritative assistant envelopes from `message_end`;
- `agent_settled`, not `agent_end`, into true completion/idle; and
- typed edit/write built-in tool completion into existing diff staleness rather
  than leaking raw tool names upward.

`message_end.message` is authoritative. Deltas build a provisional live part;
the final message repairs it. Live/replay parity is a direct test requirement.

### Pi extension UI

`PiExtensionUiTracker` keeps pending dialog state per session:

| Pi method | Sesori mapping |
|---|---|
| `select` | one single-select question with supplied options |
| `confirm` | one Yes/No question |
| `input` | one custom-answer question |
| `editor` | one custom-answer question with bounded labelled prefill in its prompt |
| `notify` | existing `BridgeSseTuiToastShow` |
| `setStatus`, `setWidget`, `setTitle`, `set_editor_text` | parsed, debug-recorded, deliberately ignored |

`PiExtensionUiService` coordinates the catalog repository, process repository,
and tracker: it resolves display roots, routes Pi's exact response variants, and
exposes typed asked/replied/rejected lifecycle notifications after tracker
mutation. `PiPlugin` maps those to `BridgeSseQuestionAsked`,
`BridgeSseQuestionReplied`, and `BridgeSseQuestionRejected`. Reject, timeout,
abort, reap, exit, and disposal reject every card; no state is persisted.

At request time the service resolves the owning session's top-most imported
parent and normalized cwd from the catalog/process snapshot. The tracker stores
`displaySessionId` plus `projectId` and indexes by owner/root/project, so root
and `getProjectQuestions` queries need no session-tree rescan.

`PluginQuestionInfo` has no editable-prefill field. For `editor`, the service
therefore appends a bounded, clearly labelled prefill excerpt to the question
and tells the user that their answer is the complete replacement. Truncation is
stated in the prompt; no hidden prefill is silently retained.

`getPendingPermissions` always returns `[]`; `replyToPermission` reports not
found. A user's own permission extension can still ask through generic Pi
dialogs, which appear as questions because Pi supplies no permission semantics.

### Pi session processes and turns

`PiSessionProcessRepository` owns:

- `sessionId -> resident PiRpcClient`;
- new/resume launch choice using `PiSessionStorageApi` paths/pending markers;
- bounded resident-or-transient client leases for history and rename;
- process connection generations and late-spawn rollback;
- applied provider/model/thinking state;
- request dispatch and extension-dialog responses; and
- merged session-tagged frame/exit streams.

`PiSessionService` owns per-session turn admission, status/work state, abort,
and idle reap. Prompt admission marks the session busy and returns immediately;
the lane later applies selection, dispatches, and tracks settlement. A command
is rejected synchronously while any turn is active/queued; otherwise its turn
owns an acceptance completer. `sendCommand` returns when either the correlated
response succeeds or a generation-matched extension dialog proves Pi began
handling it. Pre-acceptance failure/exit throws; later failures emit events.
IDs are secure UUIDs validated by `PiLaunchSpec`.

A correlated prompt `success: false` is terminal without `agent_settled`: emit
the session error/auth toast, clear the active turn, advance the next queued
prompt, and return to idle when the queue is empty.

A generation-matched process exit before `agent_settled` fails the active turn
and clears resident/dialog state. The lane re-resolves for the next admitted
turn and becomes idle only when its queue empties; resolution uses the file or
pending-new marker, so none remains indefinitely busy.

Creation asks `PiSessionStorageApi` to write a per-session pending-new marker
before spawn and remove it only after the JSONL file is observable. Resolution
prefers a file; otherwise the marker relaunches `--session-id` in its recorded
cwd. Delete clears both, so external missing sessions are never resurrected.

Creation emits a synthetic `BridgeSseSessionCreated` before admitting the first
turn. Bridge core can then buffer early status/message/dialog events until the
binding commit, matching the established ACP creation ordering.

`PiSessionProcessRepository` also maps prompts. Text remains text; inline
`fileData` with a supported image MIME becomes Pi's base64 `images` field after
the existing attachment-size and base64 validation. `filePath`, `fileUrl`, and
non-image data are not fetched, stringified, or silently dropped: dispatch fails
before acceptance with a privacy-safe `PluginOperationException` explaining
that Pi supports inline image data only.

Commands use Pi's normal `/name args` prompt path only from an idle lane. A
dialog-first acceptance detaches the phone request while response/dialog failure
continues through session events. Every prompt path, including manually typed
slash commands, applies the same no-run classifier: after the prompt response,
if no generation-matched `agent_start` arrived, hold the lane through a
`get_state` barrier and earlier protocol events; settle when state is neither
streaming nor pending, otherwise await `agent_settled`. Command context uses the
same marker; presentation uses only `userVisibleArguments`.

Abort invalidates the session generation, rejects pending dialogs and queued
turns, sends Pi's `abort`, and tears down that session process. Teardown is
required because Pi's RPC `abort` does not clear its steering/follow-up queues.
The next accepted turn resumes from the persisted session.

Delete resolves imported descendants, invalidates/rejects every affected lane
and dialog, and stops their resident processes before removing only the named
root's marker/file. Exit callbacks cannot advance or relaunch tombstoned work.

### Pi catalogs and selections

`PiBackendCatalogRepository` owns a bounded short-lived lease over the injected
`PiProcessFactory`/`PiRpcClient` boundary, launched in project cwd with
`--mode rpc --no-session --approve`. It maps Pi DTOs and always tears the client
down. `PiCatalogTracker` owns the last coherent snapshot for each normalized
project; `PiCatalogService` only coordinates the repository and tracker.

The repository answers every probe `extension_ui_request` with deterministic
cancellation, including editor; no probe dialog enters session UI state.

- `get_available_models` supplies provider/model IDs, display names, reasoning,
  and image support.
- Initial `get_state.model` is captured before the thinking sweep; its provider
  is ordered first and publishes that model as `defaultModelID`.
- For each reasoning-capable model, the probe selects it and asks
  `get_available_thinking_levels`; this is safe because the session is
  in-memory.
- Thinking values are parsed into a closed Pi enum at the boundary and exposed
  as `PluginModel.variants` (`off`, `minimal`, `low`, `medium`, `high`, `xhigh`,
  and `max` when upstream returns them).
- Providers use existing named `PluginProvider` variants where IDs match and
  `custom` otherwise. Auth type stays `unknown`; Pi does not report one in the
  model object.
- `get_commands` maps extension/prompt-template/skill sources to existing
  command source values.
- One primary `PluginAgent` named `pi` represents the upstream harness. Pi has
  no first-party agent preset list to expose.

For `PluginSessionOptionsDiscoveryMode.reuse`, the service returns the tracked
project snapshot when present and probes only when none exists. `refresh`
always probes. A coherent full probe returns `observed` with `complete`; a
usable snapshot missing an optional catalog component returns `observed` with
`partial`. A total probe failure returns `failed` and never replaces the last
good tracker snapshot. Bridge core remains the owner of durable cache and
retention policy.

### Pi runtime and setup

`PiRuntimeManifest` is a `packageDirectory` manifest with semantic versions.
The implementation starts from the researched `v0.84.1` pin and refreshes to
the latest stable release at Step 17 if a newer release exists and passes the
same protocol/E2E checks.

- PATH executable: `pi`.
- Managed entry: `pi` / `pi.exe`.
- Release URLs:
  `https://github.com/earendil-works/pi/releases/download/v<version>/<asset>`.
- PATH floor: the oldest version whose exact RPC fields this plugin uses. The
  initial plan floor is `0.84.1` because `agent_settled`, delta-only updates,
  current command metadata, auth checks, and the documented session entry API
  are all assumed.
- Managed pin: exact current tested stable release.

`inspectSetup` mirrors managed precedence and validates only runtime
availability/version. Its contract has no project cwd, so an empty cwd-less
model catalog is never classified as unauthenticated. Authentication is checked
by the approved project-scoped catalog/prompt path, which preserves the typed
failure cause and presents local `/login` guidance without globally blocking
plugin startup.

Project-scoped auth failures never escape as
`PluginAuthenticationRequiredException`, which bridge core interprets as
plugin-global auth loss. Catalog discovery returns
`PluginSessionOptionsDiscoveryResult.failed` plus an existing bounded guidance
toast rendered by Step 19; admitted turns emit existing `session.error` plus
that toast. Other synchronous calls use ordinary cause-preserving operation
failures. No new wire event is required.

`ensureRuntime` uses `ManagedRuntimeProvisionService` and remains read-only.
`installRuntime` uses `ManagedRuntimeInstallService` and the package-directory
layout. Install capability is declared only when no explicit bin is configured
and the current platform has a pinned asset.

The launch environment inherits the user's Pi variables and credentials. It
sets `PI_SKIP_VERSION_CHECK=1` because Sesori owns managed runtime updates, but
does not force `PI_OFFLINE` or `PI_TELEMETRY`; model/package behavior and the
user's telemetry choice remain Pi's.

### OMP runtime and setup

`OmpRuntimeManifest` starts from the live-verified `v17.2.13` floor and pin.
The exact pin is refreshed in Step 9 only after the same ACP probe passes.

- PATH executable: `omp` (`omp.exe` is not the published Windows asset name,
  but the managed canonical entry is normalized to `omp.exe`).
- Version output: `omp/<semver>`; the manifest parser owns this prefix.
- Release URLs:
  `https://github.com/can1357/oh-my-pi/releases/download/v<version>/<asset>`.
- Assets: macOS arm64/x64, Linux glibc arm64/x64, Linux musl arm64/x64, and
  Windows x64; Windows arm64 is unsupported until upstream publishes it.
- Linux libc is selected through one OMP-owned host probe before choosing the
  manifest asset. It follows upstream's ordinary Alpine/`ldd` distinction and
  is injected in tests; `PlatformTarget` is not widened for one publisher.

OMP assets are raw executables rather than archives. Step 8 extends the shared
runtime asset model with an honest direct-binary variant that carries no archive
format/member fields. Download, checksum verification, executable permission,
atomic placement, sentinel-last installation, version probing, and stale-version
sweep remain shared. Existing archive/package variants and consumers are
updated in lockstep; no nullable archive sentinel fields are introduced.

`inspectSetup` validates runtime only. OMP ACP always advertises the local
`agent` auth method and accepts `authenticate` even with no configured model, so
that handshake is not an authentication probe. Project-scoped catalog discovery
returns failed with local `/login` guidance when model options are absent;
prompt errors use the same privacy-safe guidance without forwarding OMP's local
database path.

The launch inherits OMP profile/XDG/credential/configuration variables. It does
not force approval mode, telemetry, marketplace refresh, offline mode, or a
Sesori profile. ACP mode does not run OMP's interactive version-check path.

### Pi `BridgePluginApi` mapping

| Contract | Pi implementation |
|---|---|
| `getSessions` | metadata catalog filtered by normalized cwd |
| `listAllSessions` | global/custom-root metadata scan plus known directories |
| `launchDirectory` | descriptor start cwd, matching derived-project plugins |
| `primeSessionDirectory` | retain bridge attribution until file metadata is observable |
| `getCommands` | project-scoped throwaway RPC `get_commands` |
| `getSessionOptions` | reuse/refresh through project tracker; observed complete/partial or failed |
| `createSession` | emit created, then admit first turn only when `parts` is non-empty |
| `renameSession` | resident or bounded transient lease for RPC `set_session_name` |
| `deleteSession` | stop root/descendant work, then delete the named root marker/file |
| `deletePersistedSession` | resolve by ID and idempotently delete the exact file without spawning Pi |
| `archiveSession`, `deleteWorkspace` | no-op under best-effort contracts |
| `getChildSessions` | catalog filter by resolved parent ID |
| `getSessionStatuses` | session service work/queue state |
| `getSessionMessages` | RPC/file active-branch history; throw on non-fallback failure |
| `sendPrompt` | admit exact turn immediately; later dispatch failures become events |
| `sendCommand` | reject busy; await response-or-dialog acceptance; event later failures |
| `abortSession` | abort and process teardown, clearing queued work/dialogs |
| `getAgents` | one synthesized primary Pi agent |
| questions | extension UI service with owner/root/project tracker indexes |
| permissions | empty/not-found; Pi has no native permission protocol |
| `healthCheck` | bounded resolved-binary `--version`, independent of project models |
| `getProviders` | project-scoped catalog result |
| `getActiveSessionsSummary` | synchronous session-service summary by cwd |
| `dispose` | idempotent process/dialog/event teardown |

### OMP `BridgePluginApi` mapping

| Contract | OMP implementation |
|---|---|
| `getSessions`, `listAllSessions` | standard paginated ACP `session/list` |
| `launchDirectory`, `primeSessionDirectory` | inherited ACP derived-project attribution |
| `getCommands` | ACP `available_commands_update` project snapshot |
| `getSessionOptions` | isolated OMP ACP project probe with reuse/refresh |
| `createSession` | ACP `session/new`, then optional queued first turn |
| `renameSession` | bridge-local title override; OMP `/rename` remains an advertised command |
| `deleteSession` | abort if active, ACP `session/close`, then local state cleanup |
| `deletePersistedSession` | isolated list/load plus OMP `/session delete` and close |
| `archiveSession`, `deleteWorkspace` | no-op under best-effort contracts |
| `getChildSessions` | empty; ACP list exposes no parent metadata |
| `getSessionStatuses` | inherited ACP per-session turn state |
| `getSessionMessages` | short-lived ACP `session/load` replay |
| `sendPrompt`, `sendCommand` | inherited ACP turn lane plus OMP selection application |
| `abortSession` | ACP cancel plus pending permission/form cancellation |
| `getAgents`, `getProviders` | OMP mode/config-option project snapshot |
| questions | standard ACP form elicitations |
| permissions | standard ACP permission registry, preserving OMP policy |
| `healthCheck` | ACP connection/handshake after descriptor runtime probe |
| `getActiveSessionsSummary` | inherited ACP session/cwd summary |
| `dispose` | catalog lease plus inherited ACP teardown |

## Registration And Client Work

Step 2 added the app-invisible Pi package to the bridge workspace, Makefile, CI,
and dependency-update inventory. Step 6 does the same for OMP. The app does not
depend on or register either new backend until Step 18, after both descriptors
are complete.

Step 18 adds `Harness.pi` and `Harness.omp`, both app dependencies, and the two
concrete registrations in `plugin_registry.dart`, then updates exact-set
fixtures. OpenCode remains the preferred default; string plugin identity keeps
both additive changes wire-safe.

Step 19 adds Pi/OMP assets, branding, and docs plus backend-neutral toast
presentation. `SseToastCubit` lives in `module_core/lib/src/cubits/` and maps
existing toast events into closed presentation variants;
the relay-connected mobile shell renders them through its root messenger.
Existing attachment capability drives composer behavior; no Pi or OMP checks
enter shared client state.

## Analytics Assessment

No new analytics event is planned.

- Pi and OMP session creation and message actions use existing authoritative
  product events.
- Rendering transport toasts is transient presentation, not a product outcome
  or reporting question.
- Managed install already emits the bounded completed/failed harness install
  outcome.
- Existing privacy rules deliberately keep harness identity and provider/model
  names off the analytics wire.

A backend-specific adoption event would require reopening that privacy decision
and a corresponding reporting question. This series does neither.

## Dependencies And Sequencing

1. **Package-directory runtime support:** Pi Step 17 depends on
   `phone-harness-install` Step 5 landing `RuntimeAssetLayout.packageDirectory`.
   Its local branch also generalizes `RuntimeVersion`; Pi consumes that if it
   lands, but its semantic pin does not independently require the generalization.
   Do not duplicate or cherry-pick either primitive. If deferred, pause before
   Step 17 and ask whether package-directory support moves into this series.
2. **Direct-binary runtime support:** OMP publishes no runtime archives. Step 8
   extends the merged runtime asset variants after the package-directory branch
   lands; it must not implement a parallel installer before that dependency is
   reconciled.
3. **Claude activation overlap:** Claude's workspace/CI inventory has merged;
   its outstanding activation still owns `Harness`, app pubspec, registry, and
   exact-set fixtures, followed by branding. Joint Step 18 waits if Claude
   activation is not merged, then registration/client work rebases and
   preserves every Claude entry rather than stale exact-set assertions.
4. Every series PR targets `main` and follows the prior numbered step. Steps 1-3
   are already merged; Step 4 is the plan delta and no Step 5 production change
   is bundled into it.

## Cleanup Assessment

This is additive and makes no production model, database field, transport field,
cache, job, or listener obsolete.

Directly caused cleanup is included:

- README copy that hardcodes exactly three harness names becomes scalable;
- the runtime update skill's stated backend list expands to include Pi and OMP;
- exact known-harness fixtures expand rather than adding fallback shims.

The only shared production cleanup is directly caused by OMP: runtime assets
become honest archive/package/direct-binary variants instead of adding nullable
archive fields, and ACP closes sessions it deletes. Cursor's catalog code is not
moved or generalized because OMP's isolated scratch-session probe has different
inputs and lifecycle.

The existing OpenCode compatibility default remains required for released peers
that omit plugin identity. No unrelated plugin/runtime refactor is planned.

## Delivery Rules

- `TRACKER.md` is canonical for the revised fixed twenty-one exact PR titles,
  complexity, line targets, order, and current state. Step 1 raised this
  directory, Step 4 records the requirement change, and Step 21 moves it to
  `.plan/completed/pi-harness/`.
- Every step follows repository line-count, generated-file, internal-contract,
  PR-body, sequential merge, and architecture-review rules.
- Production Steps 2-3 and 5-19 run applicable codegen, focused/full
  owning-package tests, fatal analysis, `git diff --check`, and architecture
  implementation review.

## Step Details And Verification

### Step 1/21: Raise the Pi plan

- Add `PLAN.md`, `TRACKER.md`, and researched Pi `PROTOCOL.md` under
  `.plan/active/pi-harness/`.
- Record the original Pi decisions, sources, release digests, fixed sequence,
  risks, dependencies, and verification.
- Run architecture plan review and documentation validation. This step is
  merged as PR #811.

### Step 2/21: Scaffold the Pi protocol package

- Create `sesori_plugin_pi`, launch/process seams, exact Pi launch variants,
  `--approve`, environment policy, protocol enums, fixture helpers, and
  app-invisible workspace/CI inventory.
- Test Pi arguments, absolute resume, executable naming, and environment
  preservation. This step is merged as PR #819.

### Step 3/21: Add the Pi JSONL RPC transport

- Add the sealed Pi transport boundary, strict LF framing, correlation,
  continuous draining, bounded diagnostics, process lifecycle, and test fake.
- Cover framing, ordering, unknown frames, exits, backpressure, broken pipes,
  redaction, and bounded teardown. Closed generated leaf DTOs begin at Step 10.
- This step is merged as PR #820.

### Step 4/21: Expand the plan to Oh My Pi

- Reconcile the branch with merged Step 3 and research OMP source, releases,
  ACP, RPC divergence, storage, runtime, config/auth, permissions, and live ACP
  behavior at the exact selected tag.
- Record the no-shared-Pi-family/OMP-over-ACP decision, add
  `OMP_PROTOCOL.md`, revise success/degradation criteria, and rebaseline the
  remaining exact sequence from 15 to 21 steps.
- Update the titles of merged PRs #811, #819, and #820 to the `/21` denominator
  after this plan revision opens, so the whole series has one fixed total.
- Run architecture plan review, `git diff --check`, and Markdown/reference
  validation. No Dart/Flutter suites for this documentation-only step.

### Step 5/21: Bridge ACP form elicitations

- Extend only standard `sesori_plugin_acp` contracts: form elicitation
  capability/request/reply handling, supported scalar schemas, bounded editor
  default presentation, session-close capability, and OMP's narrow sanitized
  turn-failure presentation hook.
- Keep Cursor behavior stable and URL elicitation/terminal auth unadvertised.
- Cover enum/string/boolean and multi-property forms, typed answer conversion,
  unsupported schemas, late/rejected replies, abort/delete/exit/disposal,
  close-supported/unsupported agents, and sensitive prefill/error non-logging.

### Step 6/21: Add the OMP ACP plugin core

- Create `sesori_plugin_omp`, public/testing barrels, `OmpBinary` launch spec,
  `OmpPlugin` over `AcpPlugin`, OMP event/failure mapping, and only this step's
  dependencies.
- Preserve inherited profiles, credentials, project config, plugins, and
  approval mode; advertise no client filesystem/terminal capabilities.
- Add app-invisible workspace, Makefile, CI, and dependency-update inventory.
- Cover `omp acp` arguments, environment preservation, handshake/auth, global
  and cwd session lists, new/load/resume, history/live/tool/image mapping,
  configured permissions/forms, cancellation, reconnect, and disposal with the
  ACP fake plus redacted upstream fixtures.

### Step 7/21: Expose OMP options and persisted cleanup

- Add OMP-owned catalog API/repository/service/tracker over an isolated
  `--session-dir` scratch ACP process.
- Map project modes, commands, provider/model IDs, and each model's exact
  thinking options; apply selections through `session/set_config_option`.
- Add OMP persisted cleanup through bounded ACP list/load, `/session delete`,
  close, and disposal after normal live-session close. Keep not-found
  idempotent and title rename explicitly bridge-local.
- Cover no-model/login guidance, custom providers and slash-containing model
  IDs, per-model thinking changes, command bootstrap timing, coherent refresh,
  scratch cleanup, tombstoned deletion, failures, and no payload/path leakage.

### Step 8/21: Install direct binary runtime assets

- Rebase on the package-directory/runtime-version dependency and model runtime
  assets as honest archive-package versus direct-binary variants.
- Extend shared provisioning to download, verify, atomically place, chmod,
  sentinel, probe, and sweep a checksummed bare executable without fake archive
  fields or a second installer.
- Update every internal manifest/test consumer in lockstep.
- Cover direct success, checksum failure, cancellation, stale staging, Windows
  executable placement, existing archive/package behavior, and cleanup.

### Step 9/21: Add OMP managed runtime and lifecycle

- Add `OmpRuntimeManifest` for the seven official `v17.2.13` assets, semantic
  `omp/<version>` parser, glibc/musl choice, explicit-bin/PATH/managed
  precedence, descriptor, setup, install, lifecycle, and abort rollback.
- Preserve OMP environment/config/approval policy and extend
  `update-backend-runtimes` with OMP release, checksum, raw-binary, and ACP
  checks.
- Cover all seven targets, no Windows arm64 capability, libc selection,
  install/version failures, project-independent setup, connection degradation,
  restart, and teardown.
- Perform a local official managed install and isolated `initialize`,
  `session/list`, `session/new`, `session/load`, and cleanup probe.

### Step 10/21: Enumerate persisted Pi sessions

- Add minimal generated Pi session-header/settings DTOs plus
  `PiSessionStorageApi` and `PiSessionCatalogRepository`.
- Discover environment, normal/configured/default/known roots; scan bounded
  metadata in an isolate; map explicit titles, parent paths, lazy attribution,
  pagination, and private exact paths.
- Cover malformed/half-written/oversized records, title changes, duplicate
  roots/IDs, external parents, custom roots, deleted cwd, symlinks, privacy-safe
  diagnostics, and a structural real-root scan when available.

### Step 11/21: Replay Pi session history

- Add consumed entry/message/content DTOs and codegen, history file input,
  `PiSessionProcessRepository` history operation, and active-branch mappers.
- Map text, reasoning, images, tools/results, custom messages, bash, errors,
  compaction cards, and branch-summary omission with deterministic IDs for Step
  12 live parity.
- Preserve cause-bearing failures and cover branches, compaction, v1-v3 file
  fallback, attachment bounds, hidden context, equal timestamps, parity, and no
  payload logging.

### Step 12/21: Map Pi live messages and tools

- Add `PiToolTracker` and Layer-3 `PiEventDispatcher` over session-tagged frames
  and pure mappers.
- Map deltas/finals, tool lifecycle/cumulative output, retries, compaction,
  errors, statuses, diff staleness, and true `agent_settled` completion.
- Prove complete live shapes equal Step 11 replay and cover interleaving,
  content indices, late tool args, duplicate terminal frames, provider errors,
  abort, and unknown variants.

### Step 13/21: Bridge Pi extension dialogs

- Add `PiExtensionUiTracker` and `PiExtensionUiService` for
  select/confirm/input/editor, lifecycle events, display-root/project indexes,
  bounded toasts, exact replies, and explicit decorative-UI degradation.
- Clear/reject state on timeout, abort, process exit/replacement, idle reap, and
  disposal; keep Pi permissions honestly empty.
- Cover imported parents/worktrees, late replies, prefill replacement and
  truncation, multiline answers, and sensitive field non-logging.

### Step 14/21: Manage Pi session residency and turns

- Extend `PiSessionProcessRepository` and add `PiSessionService` with one lazy
  process per active session, pending-new markers, secure IDs, generation-fenced
  connects, selections, per-session lanes, merged events, and idle reap.
- Map validated inline images, reject unsupported attachments, preserve
  cross-session concurrency, and tear the process down after abort.
- Cover spawn/serialization/resume races, transient history/rename leases,
  immediate prompt admission, busy commands, dialog-first acceptance, no-run
  commands, post-acceptance exits, auth guidance, shutdown, and queued work.

### Step 15/21: Expose Pi models and commands

- Add generated catalog DTOs, `PiBackendCatalogRepository`,
  `PiCatalogTracker`, and `PiCatalogService` over bounded approved no-session
  project probes.
- Map providers/models/thinking variants/commands, preserve the initial default,
  synthesize one Pi agent, and implement coherent project reuse/refresh with
  complete/partial/failed results.
- Cover custom providers, duplicate IDs, reasoning support, `max`, command
  sources, project resources, no-model/auth, probe-dialog cancellation, exit,
  and last-good fallback.

### Step 16/21: Implement the Pi plugin API

- Add `PiPlugin` as the composition root over merged Step 3 and Steps 10-15,
  implementing every `BridgePluginApi`/`PersistedSessionCleanupApi` member.
- Wire events, catalog/path lookup, creation, rename/delete, children, history,
  prompts/commands, questions, statuses, providers, health, summaries, and
  idempotent disposal.
- Cover empty-parts command creation, created-before-output buffering, missing
  paths, lazy persistence, active root/child deletion, cause-preserving errors,
  no-op contracts, and disposal order.

### Step 17/21: Add Pi managed runtime and lifecycle

- Require merged package-directory support; add the six refreshed official Pi
  assets, package layout, semantic pin/floor, descriptor/setup/install/lifecycle,
  and start/abort rollback.
- Set `PI_SKIP_VERSION_CHECK=1`, preserve other Pi config, pass `--approve` to
  every real/probe process, and extend runtime-update checks.
- Cover precedence, explicit bin, six targets, archive tree, capability,
  checksum/setup/health/lifecycle failures, and package preservation.
- Perform an official managed install, `--version`, and RPC `get_state` probe.

### Step 18/21: Register Pi and OMP

- Add `Harness.pi` and `Harness.omp`, both app dependencies, registry
  descriptors, and every intentional exact known-plugin fixture.
- Preserve merged Claude entries and OpenCode as preferred default.
- Verify shared identity, registry/lifecycle/catalog, both plugin suites, app
  fatal analysis, and architecture implementation review.

### Step 19/21: Add Pi and OMP branding and guidance

- Add official light/dark assets and display-name cases for both backends with
  widget/unit coverage.
- Add backend-neutral `SseToastCubit` under `module_core/lib/src/cubits/` with
  sealed idle/show state, monotonic sequence, and closed
  info/success/warning/error variants; render it at the mobile app root without
  backend-specific client branches.
- Document both managed installs, local `/login`, `--pi-bin`, `--omp-bin`, Pi
  project trust, OMP approval-policy inheritance, unsupported ACP features,
  profile behavior, and terminal-session handoff.
- Make backend headline copy scalable and test guidance, notifications,
  duplicate/empty toasts, asset rendering, links, and touched client analysis.

### Step 20/21: Verify both integrations end to end

- Pin authenticated Pi and OMP fixtures without committing credentials or raw
  captures.
- Exercise phone-driven managed install/setup, new and imported sessions, text
  and image prompts, reasoning, tools, models/thinking/modes, commands,
  Pi dialogs, OMP forms/permissions, retry/error, abort, process restart/resume,
  rename semantics, delete cleanup, handoff, Pi parents, and missing auth.
- Verify OMP glibc/musl selection where hosts are available and explicitly
  record unavailable platform checks.
- Confirm no backend logic escaped declared plugin/identity/brand seams; record
  redacted evidence and corrections in both protocol files and `TRACKER.md`.
- Run focused package/app/client suites and fatal analysis.

### Step 21/21: Retire the plan

- Confirm Steps 1-20 merged and tracker/E2E evidence is complete.
- Move `.plan/active/pi-harness/` to `.plan/completed/pi-harness/`.
- Run `git diff --check`; no Dart/Flutter suites.

## Evidence And Accepted Risks

- Official docs/source, the `v0.84.1` x64 archive/digest, `pi --version`, and a
  no-auth RPC probe were inspected; `PROTOCOL.md` records the evidence.
- OMP tag/source, npm identity, all `v17.2.13` release assets/digests, the
  official macOS arm64 binary, `omp/17.2.13`, and an isolated live ACP
  initialize/auth/list/new/prompt probe were inspected; `OMP_PROTOCOL.md`
  records the evidence.
- The absent handshake is handled by a tested floor/pin and tolerant unknown
  variants for Pi, not invented negotiation. OMP uses ACP's real v1 initialize
  handshake instead of OMP RPC's separate negotiation protocol.
- Terminal ownership, process-local dialogs, lazy first-file visibility, and
  ignored decorative UI are accepted limitations with explicit user impact.
- Always-approved project code is a locked security decision with mandatory
  documentation and argument tests.
- Supply-chain checks require official assets, pinned digests, full-package
  extraction for Pi, direct-binary placement for OMP, sentinel-last placement,
  and no npm execution.
- Per-session lanes address reachable concurrent sends; no global lock or
  cross-backend process registry is planned.
- OMP ACP does not expose parent metadata or a standard rename method; imported
  child relationships are absent and Sesori title overrides remain local. These
  bounded degradations are preferred over parsing private OMP transcripts or
  inventing a second protocol.
- OMP releases frequently. The managed pin changes only through the runtime
  update workflow after the exact ACP and asset checks pass; release cadence is
  not a reason to accept unverified latest binaries.

## Plan Review Record

Architecture plan review rejected the initial draft on six wiring gaps. All
required corrections were applied; `TRACKER.md` records them. Per repository
policy, the corrected plan was not re-reviewed merely for approval.

The Step 4 Pi/OMP architecture review accepted the core boundary and rejected
four documentation gaps. Snapshot ownership, session-options ownership, cubit
placement, and overage recording were corrected; `TRACKER.md` records the
result. Per repository policy, the corrected plan was not re-reviewed merely
for approval.
