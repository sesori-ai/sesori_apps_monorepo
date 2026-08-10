# Pi Harness Support

## Status

- **Plan slug:** `pi-harness`
- **Status:** Step 1/15, plan PR open
- **Plan date:** 2026-08-10
- **Implementation base:** `origin/main` at
  `3803df12d2afa41abe6894df88146ad6543e9ec6`
- **Upstream research baseline:** Pi Agent Harness `v0.84.1`, published
  2026-08-07 from `earendil-works/pi`
- **Plan delivery:** this document, `TRACKER.md`, and `PROTOCOL.md` are Step
  1/15
- **Delivery:** one planning PR, ten bridge package/runtime PRs, one activation
  PR, one client/docs PR, one live-verification PR, and one plan-retirement PR

## Goal

Add the [Pi Agent Harness](https://github.com/earendil-works/pi) as a
first-class Sesori coding backend. Sesori must be able to download a pinned Pi
standalone release, verify it, preserve its complete runtime package, launch its
documented JSONL RPC mode, and expose the useful Pi experience from phone and
desktop surfaces without leaking Pi-specific behavior outside the plugin.

"Full support" in this plan means:

- managed runtime install on every platform for which Pi publishes a release;
- existing and Sesori-created Pi sessions grouped by their real working
  directories;
- new and resumed sessions;
- persisted history and live text/reasoning streaming;
- tool calls, partial output, completion, errors, retries, compaction, and
  abort;
- configured providers, models, model-specific thinking levels, Pi extensions,
  skills, prompt templates, image prompts, and RPC-capable extension dialogs;
- the existing plugin management, picker, catalog, relay, and client flows; and
- explicit, honest degradation for Pi features that its RPC protocol does not
  expose.

## Success Criteria

1. `GET /plugin` advertises `pi` with display name `Pi`, correct setup and
   install capabilities, and a first-party brand mark.
2. Tapping Install downloads the pinned standalone asset for the current
   OS/architecture, checks its SHA-256, installs the complete extracted package
   under Pi's isolated plugin runtime directory, and starts Pi when setup is
   ready.
3. A PATH Pi at or above the compatibility floor wins over the managed copy; a
   too-old PATH Pi falls back to the exact managed pin; an explicit `--pi-bin`
   remains authoritative and disables managed install.
4. A new phone-created session uses a bridge-generated ID, launches in the
   chosen project/worktree, streams text and thinking, renders tools through
   pending/running/completed or error states, and remains resumable after the
   bridge restarts.
5. Existing sessions under the user's normal Pi session store import without
   reading prompt or transcript text merely to build the catalog. Explicit Pi
   names are used as titles; first prompts are not promoted into bridge titles.
6. Imported Pi sessions retain resolvable `parentSession` relationships and
   appear through the existing child-session catalog.
7. Multiple Pi sessions may run concurrently. Each active session owns its own
   lazily spawned RPC process; idle processes are reaped and resume from their
   absolute session file on the next turn.
8. Model/provider discovery is project-scoped, includes project extensions
   because Pi is launched with `--approve`, and exposes exact thinking levels
   by probing a non-persisted RPC session rather than hardcoding provider rules.
9. Pi extension `select`, `confirm`, `input`, and `editor` dialogs round-trip as
   Sesori questions. Notifications use existing toast events and render through
   backend-neutral client presentation. Unsupported fire-and-forget decorations
   are parsed and deliberately ignored rather than breaking the run.
10. Pi's native no-permission-prompt behavior is preserved. The plugin reports
    no pending permissions and does not install a Sesori permission extension.
11. Project-scoped discovery and prompt failures use ordinary operation/session
    failure plus a rendered guidance toast for local `/login`; they never disable
    Pi for other projects through plugin-global auth state.
12. Supported inline image data reaches Pi's RPC `images` field. Path, URL, and
    non-image variants fail visibly and never become accidental prompt strings.
13. No Pi protocol value, path layout, provider assumption, tool name, or
    runtime quirk escapes `bridge/sesori_plugin_pi/`. The intentional shared
    exceptions are Pi identity, registration, and branding. Existing toast
    events gain backend-neutral presentation with no Pi-specific branch.
14. No new relay route, database column, or `MessagePartType` is introduced.
    Older clients render unknown `pi` through data-driven contracts but ignore
    notification and `/login` toasts until upgraded; generic failures remain.
15. Every implementation PR is independently buildable and normally stays at
    or below 1,500 changed lines, including tests and generated output.

## Research Findings

`PROTOCOL.md` is the canonical researched protocol/runtime record. The
load-bearing conclusions for this plan are:

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

Confirmed with the user on 2026-08-10:

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

Decision 5 is security-relevant. Pi project extensions execute arbitrary code
with the bridge user's permissions. The implementation must test that
`--approve` is always present and documentation must state the consequence.

## Scope

### Included

- New `bridge/sesori_plugin_pi/` pure-Dart package.
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

## Architecture

### Plugin type and lifecycle

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

### Package layout

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

No generic RPC abstraction is extracted into shared packages. ACP, Claude, and
Pi have materially different framing, request, event, and lifecycle contracts.

### `PiRpcClient`

One client owns one child process and:

- launches from a typed `PiLaunchSpec`;
- consumes stdout and stderr continuously so neither pipe can stall Pi; stdout
  uses the LF-only UTF-8 framer, while stderr retains only a bounded redacted
  diagnostic tail;
- decodes top-level response, event, extension-UI, and unknown envelopes;
- correlates responses by request ID without assuming a prompt response arrives
  before agent events;
- exposes a broadcast event stream tagged later with its owning session ID;
- never logs raw stdout frames, prompts, transcript content, tool payloads, or
  extension input;
- redacts known credential fields from diagnostic strings;
- fails all pending requests on exit/teardown; and
- closes stdin first, then uses bounded SIGTERM/SIGKILL on POSIX and bounded
  process termination on Windows.

Only top-level discriminator routing and the unknown-envelope fallback are
hand-written. Every known response, event, dialog, and nested payload uses a
generated DTO; DTOs land with their first consumer so codegen does not create
unconsumed multi-thousand-line PRs.

### Session catalog

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

### History and content mapping

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

### Live events and tools

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

### Extension UI

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

### Session processes and turns

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
owns an acceptance completer and `sendCommand` returns only after the correlated
Pi prompt response succeeds. Pre-acceptance failure/exit completes it with an
error; later failures emit session events. IDs are secure UUIDs validated by `PiLaunchSpec`.

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

Commands use Pi's normal `/name args` prompt path only from an idle lane. The
correlated successful prompt response completes `sendCommand` acceptance; the
service then holds the lane through a `get_state` barrier and earlier protocol
events. It treats a command as no-run only when no generation-matched
`agent_start` arrived and state reports neither streaming nor pending messages;
otherwise it waits for `agent_settled`. Command context uses the same marker
scheme, and live/replay presentation uses only `userVisibleArguments`.

Abort invalidates the session generation, rejects pending dialogs and queued
turns, sends Pi's `abort`, and tears down that session process. Teardown is
required because Pi's RPC `abort` does not clear its steering/follow-up queues.
The next accepted turn resumes from the persisted session.

### Catalogs and selections

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

### Runtime and setup

`PiRuntimeManifest` is a `packageDirectory` manifest with semantic versions.
The implementation starts from the researched `v0.84.1` pin and refreshes to
the latest stable release at Step 11 if a newer release exists and passes the
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
toast rendered by Step 13; admitted turns emit existing `session.error` plus
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

### `BridgePluginApi` mapping

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
| `deleteSession` | stop resident process, clear dialogs/cache, resolve then delete exact JSONL file |
| `deletePersistedSession` | resolve by ID and idempotently delete the exact file without spawning Pi |
| `archiveSession`, `deleteWorkspace` | no-op under best-effort contracts |
| `getChildSessions` | catalog filter by resolved parent ID |
| `getSessionStatuses` | session service work/queue state |
| `getSessionMessages` | RPC/file active-branch history; throw on non-fallback failure |
| `sendPrompt` | admit exact turn immediately; later dispatch failures become events |
| `sendCommand` | reject busy; otherwise await acceptance; event later failures |
| `abortSession` | abort and process teardown, clearing queued work/dialogs |
| `getAgents` | one synthesized primary Pi agent |
| questions | extension UI service with owner/root/project tracker indexes |
| permissions | empty/not-found; Pi has no native permission protocol |
| `healthCheck` | bounded resolved-binary `--version`, independent of project models |
| `getProviders` | project-scoped catalog result |
| `getActiveSessionsSummary` | synchronous session-service summary by cwd |
| `dispose` | idempotent process/dialog/event teardown |

## Registration And Client Work

Step 2 adds the app-invisible package to the bridge workspace, Makefile, CI, and
dependency-update inventory. The app does not depend on or register it until
Step 12, after the complete plugin and descriptor exist.

Step 12 adds `Harness.pi`, the app dependency, and the sole concrete registration
in `plugin_registry.dart`, then updates exact-set fixtures. OpenCode remains the
preferred default; string plugin identity keeps this additive change wire-safe.

Step 13 adds Pi assets/branding/docs plus backend-neutral toast presentation.
`SseToastCubit` maps existing toast events into closed presentation variants;
the relay-connected mobile shell renders them through its root messenger.
Existing attachment capability drives composer behavior; no Pi checks enter
shared client state.

## Analytics Assessment

No new analytics event is planned.

- Pi session creation and message actions use existing authoritative product
  events.
- Rendering transport toasts is transient presentation, not a product outcome
  or reporting question.
- Managed install already emits the bounded completed/failed harness install
  outcome.
- Existing privacy rules deliberately keep harness identity and provider/model
  names off the analytics wire.

A Pi-specific adoption event would require reopening that privacy decision and
a corresponding reporting question. This series does neither.

## Dependencies And Sequencing

1. **Package-directory runtime support:** Step 11 depends on
   `phone-harness-install` Step 5 landing `RuntimeAssetLayout.packageDirectory`.
   Its local branch also generalizes `RuntimeVersion`; Pi consumes that if it
   lands, but its semantic pin does not independently require the generalization.
   Do not duplicate or cherry-pick either primitive. If deferred, pause before
   Step 11 and ask whether package-directory support moves into this series.
2. **Claude activation overlap:** Claude's workspace/CI inventory has merged;
   its outstanding activation still owns `Harness`, app pubspec, registry, and
   exact-set fixtures, followed by branding. Pi Step 12 waits if Claude
   activation is not merged, then Pi registration/client work rebases and
   preserves every Claude entry rather than stale exact-set assertions.
3. Every Pi PR targets `main` and follows the prior Pi step. No implementation
   worktree or successor PR is created by this plan PR.

## Cleanup Assessment

This is additive and makes no production model, database field, transport field,
cache, job, or listener obsolete.

Directly caused cleanup is included:

- README copy that hardcodes exactly three harness names becomes scalable;
- the runtime update skill's stated backend list expands to include Pi; and
- exact known-harness fixtures expand rather than adding fallback shims.

The existing OpenCode compatibility default remains required for released peers
that omit plugin identity. No unrelated plugin/runtime refactor is planned.

## Delivery Rules

- `TRACKER.md` is canonical for the fixed fifteen exact PR titles, complexity,
  line targets, order, and current state. Step 1 raises this directory and Step
  15 moves it to `.plan/completed/pi-harness/`.
- Every step follows repository line-count, generated-file, internal-contract,
  PR-body, sequential merge, and architecture-review rules.
- Steps 2-13 run applicable codegen, focused/full owning-package tests, fatal
  analysis, `git diff --check`, and architecture implementation review.

## Step Details And Verification

### Step 1/15: Raise the plan

- Add `PLAN.md`, `TRACKER.md`, and researched `PROTOCOL.md` under
  `.plan/active/pi-harness/`.
- Record user decisions, upstream sources, release digests, dependencies,
  fixed titles, estimates, risks, and verification.
- Run architecture plan review, apply valid findings, `git diff --check`, and
  Markdown/reference checks. No Dart/Flutter suites for documentation-only work.

### Step 2/15: Scaffold the protocol package

- Re-check the latest stable Pi release. Keep `0.84.1` as the compatibility
  baseline unless a newer pin is selected and the protocol record is updated.
- Create `sesori_plugin_pi`, public/testing barrels, analysis config, and only
  the dependencies used in this step.
- Add `PiLaunchSpec`, process handle/factory seam, new/resume launch
  variants, `--approve`, and inherited-environment policy.
- Add the closed Pi thinking-level enum and protocol fixture helpers.
- Land Wave-1 workspace, Makefile, CI, and dependency-update inventory entries.
- Unit-test exact argument vectors, absolute-path resume behavior, Windows entry
  name, and environment preservation.

### Step 3/15: Add the JSONL RPC transport

- Add hand-written discriminator/unknown routing plus generated DTOs for every
  known response, event, dialog, and consumed nested payload.
- Add `PiRpcClient` with strict LF framing, request IDs, asynchronous prompt
  acknowledgement, continuous stdout draining, bounded stderr diagnostics,
  pending failure on exit, and graceful/forced teardown.
- Add `FakePiProcess` and `pi_testing.dart` exports.
- Cover split/multiple UTF-8 chunks, CRLF input tolerance, U+2028/U+2029 inside
  JSON strings, response/event reordering, unknown frames, process exit,
  stdout/verbose-stderr backpressure, broken pipes, bounded redaction, and
  teardown fencing.

### Step 4/15: Enumerate persisted sessions

- Add minimal generated session-header/settings DTOs only where closed JSON
  parsing warrants them.
- Add `PiSessionStorageApi` and `PiSessionCatalogRepository` with environment,
  normal config, default nested root, configured root, and known-directory
  discovery.
- Scan metadata in an isolate, map explicit titles and parent paths, preserve
  lazy-new-session bridge attribution, and expose exact session paths privately.
- Cover malformed headers, half-written final lines, title clear/replace,
  oversized non-metadata records, duplicate roots/IDs, parent outside the first
  root, custom session dirs, deleted cwd, symlinks, pagination, and privacy-safe
  diagnostics.
- Validate against a synthetic tree and a privacy-preserving structural scan of
  a real Pi session root when available.

### Step 5/15: Replay Pi session history

- Add the session-entry/message/content DTOs this step consumes and run codegen.
- Add history DTO/file input plus the `PiSessionProcessRepository` operation and
  mappers over RPC/file entries with active-branch traversal.
- Map text, reasoning, images, tool calls/results, visible custom messages,
  bash execution, errors, visible compaction cards, and branch-summary omission.
- Keep replay message/part IDs deterministic for Step 6 live parity.
- Throw cause-preserving failures; never turn transport/auth/parse failure into
  empty history.
- Cover branches, pre-compaction history, unknown entries, timestamp fallback,
  no-model/auth file fallback, v1-v3 migration, tool results, compaction parity,
  attachment bounds, hidden-context stripping, marker-like prompt/command text,
  equal-timestamp ordinals, live/replay parity, and no payload logging.

### Step 6/15: Map live messages and tools

- Add `PiToolTracker` and Layer-3 `PiEventDispatcher` over session-tagged RPC
  frames and pure mappers.
- Map message deltas/finals, tool start/cumulative update/end, retries,
  compaction, typed failures, status, diff staleness, and true settlement.
- Treat final messages/results as authoritative and prune all per-turn/session
  state at exact boundaries.
- Prove complete live shapes equal Step 5 replay shapes.
- Cover interleaving, multiple content indices, tool-call args that become known
  only at `toolcall_end`, duplicate terminal frames, provider errors, abort, and
  unknown event absorption.

### Step 7/15: Bridge extension dialogs

- Add `PiExtensionUiTracker` and coordinating `PiExtensionUiService` for
  select/confirm/input/editor questions, lifecycle events, and bounded toasts.
- Implement exact value/confirmed/cancelled responses and session-keyed routing.
- Resolve/store each dialog's display root and aggregate descendant cards for
  root-session queries; index normalized cwd for project-level queries.
- Present editor prefill as a bounded labelled excerpt and make full-replacement
  semantics explicit because the shared question contract has no prefill field.
- Parse and explicitly degrade unsupported fire-and-forget UI methods.
- Clear or reject on timeout, abort, process exit, idle reap, and disposal.
- Keep permissions empty by the locked native-Pi decision.
- Cover late replies, timeout races, process replacement, reject semantics,
  imported parent chains, project/worktree queries, multiline answers, prefill
  truncation/replacement, and sensitive prefill/title non-logging.

### Step 8/15: Manage session residency and turns

- Extend `PiSessionProcessRepository` and add `PiSessionService` with one lazy
  process per active session, generation-fenced connects, new/resume launch,
  selection state, per-session turn lanes, merged events, and idle reap.
- Persist privacy-safe pending-new markers until file observation; relaunch an
  unpersisted session as new after child/bridge restart.
- Mint secure UUID session IDs in the service and validate Pi's ID grammar in
  `PiLaunchSpec`; map validated inline image data to RPC and reject path, URL,
  or non-image parts before prompt acceptance.
- Apply model/thinking immediately before each queued turn; prompts return on
  lane admission, while commands reject busy and otherwise await correlated
  backend acceptance; later run failures surface through session events.
- Abort by invalidating queued work, rejecting dialogs, sending `abort`, and
  tearing down the process so Pi's own hidden queues cannot continue.
- Preserve concurrent turns across different sessions.
- Cover spawn races, serialization, cross-session parallelism, lazy persistence,
  resume after reap, transient history/rename leases, ID/attachment validation,
  immediate prompt admission, busy-command rejection, acceptance completers,
  rejection followed by the next prompt, response-before-`agent_start` barriers,
  command-without-run, post-acceptance exit, project-scoped auth/toast behavior,
  abort, and shutdown.

### Step 9/15: Expose models and commands

- Add generated model/command DTOs, `PiBackendCatalogRepository`,
  `PiCatalogTracker`, and coordinating `PiCatalogService`.
- Let the repository own each bounded project-cwd, no-session client lease and
  enumerate/map models, thinking variants, providers, and commands; synthesize
  one Pi agent.
- Preserve the initial state model as the default and order its provider first.
- Implement project-scoped `reuse`/`refresh`, complete/partial observed results,
  explicit failed results, and atomic replacement of coherent snapshots only.
- Classify no-model/auth preflight honestly without logging provider account
  data or credentials.
- Cover custom providers, known provider mapping, duplicate IDs, reasoning and
  non-reasoning models, `max`, command sources, project-specific resources,
  empty/auth state without global teardown, probe-dialog cancellation, probe
  exit, and refresh fallback.

### Step 10/15: Implement the plugin API

- Add `PiPlugin` as the full composition root over Steps 3-9 and implement every
  `BridgePluginApi`/`PersistedSessionCleanupApi` member.
- Wire buffered plugin events, catalog/path lookup, session creation, rename,
  delete, child sessions, history, prompt/command, questions, statuses,
  providers, health, summaries, and idempotent disposal.
- Empty creation `parts` starts an idle session only; the bridge's subsequent
  `sendCommand` owns the first execution.
- Emit session-created before first-turn admission so pre-commit events buffer.
- Keep archive/workspace operations honest no-ops and permission methods
  honest empty/not-found results.
- Cover full contract behavior, missing session/path, lazy persistence,
  empty-parts command creation, created-before-output ordering, buffered first
  event listener, operation errors with causes, and disposal order.

### Step 11/15: Add managed runtime and lifecycle

- Require merged package-directory runtime support from the dependency section.
- Add `PiRuntimeManifest` with the six official assets, full-package layout,
  semantic pin/floor, URLs, and digests refreshed for the chosen stable release.
- Add descriptor config/capability/runtime-only setup inspection, read-only
  ensure, explicit install, start/abort rollback, and `PiBridgePlugin` lifecycle.
- Set `PI_SKIP_VERSION_CHECK=1`, preserve other Pi environment/config, and pass
  `--approve` to every real/probe process.
- Extend `update-backend-runtimes` with Pi release/API/digest/package checks.
- Test runtime precedence, explicit-bin behavior, six targets, archive layout,
  install capability, checksum failure, cwd-less setup/sessionless health,
  lifecycle status/work state, and package asset preservation.
- Perform a local managed install from the official asset and run `--version`
  plus an RPC `get_state` probe from the installed tree.

### Step 12/15: Register the Pi harness

- Add `Harness.pi`, app dependency, registry import/descriptor, and exact known
  plugin tests.
- Update any build/runtime enumeration fixture that intentionally lists every
  registered plugin.
- Wait for and rebase on merged Claude activation; keep OpenCode preferred.
- Verify shared identity tests, app registry/lifecycle/catalog tests, Pi suite,
  app fatal analysis, and implementation review.

### Step 13/15: Add Pi branding and guidance

- Add official light/dark Pi SVGs and brand/display-name cases with widget/unit
  coverage.
- Add backend-neutral `SseToastCubit` in `module_core` with sealed idle/show
  state; each show carries a monotonic sequence, title/message, and closed
  `info|success|warning|error` variant. Null/unknown maps to info; empty is ignored.
- Render the cubit's title/message/variant from the mobile app root through its
  `ScaffoldMessenger`, independent of the current route.
- Do not instantiate relay state solely in desktop's current auth-only shell;
  reuse the shared cubit when its relay/session surface lands.
- Update README/bridge docs for Pi, managed install, local `/login`,
  `--pi-bin`, project trust, and terminal-session handoff.
- Make headline copy scalable instead of appending a fourth hardcoded backend.
- Test pure-Dart event mapping and mobile root presentation, including auth
  guidance, extension notifications, variants, duplicates, and empty payloads.
- Verify client/module_prego analysis, asset rendering, links, and diff checks.

### Step 14/15: Verify the end-to-end integration

- Pin a release/authenticated local account or API-key fixture without
  committing credentials or captures.
- Exercise phone-driven managed install, setup refresh, new session, text and
  image prompt, live reasoning, read/edit/bash tools, model/thinking switch,
  skill/template/extension command, extension dialog, retry/error, abort,
  resume after process reap/bridge restart, rename, delete, external import,
  documented terminal handoff, imported parent relationships, and missing auth.
- Run the applicable mobile and desktop presentation paths and confirm no Pi
  logic exists outside declared identity/brand points.
- Record redacted results and any protocol corrections in `PROTOCOL.md` and
  `TRACKER.md`; fix concrete failures in this PR without broad cleanup.
- Verify package/app/client focused suites and fatal analysis.

### Step 15/15: Retire the plan

- Confirm Steps 1-14 merged and tracker/E2E evidence is complete.
- Move `.plan/active/pi-harness/` to `.plan/completed/pi-harness/`.
- Run `git diff --check`; no Dart/Flutter suites.

## Evidence And Accepted Risks

- Official docs/source, the `v0.84.1` x64 archive/digest, `pi --version`, and a
  no-auth RPC probe were inspected; `PROTOCOL.md` records the evidence.
- The absent handshake is handled by a tested floor/pin and tolerant unknown
  variants, not invented negotiation.
- Terminal ownership, process-local dialogs, lazy first-file visibility, and
  ignored decorative UI are accepted limitations with explicit user impact.
- Always-approved project code is a locked security decision with mandatory
  documentation and argument tests.
- Supply-chain checks require official assets, pinned digests, full-package
  extraction, sentinel-last placement, and no npm execution.
- Per-session lanes address reachable concurrent sends; no global lock or
  cross-backend process registry is planned.

## Plan Review Record

Architecture plan review rejected the initial draft on six wiring gaps. All
required corrections were applied; `TRACKER.md` records them. Per repository
policy, the corrected plan was not re-reviewed merely for approval.
