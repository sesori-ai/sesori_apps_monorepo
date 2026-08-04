# Claude Code Harness Plugin

## Status

- **Plan slug:** `claude-code-plugin`
- **Status:** Step 1/17 plan PR open
- **Plan date:** 2026-08-04
- **Plan delivery:** this document, `TRACKER.md`, and the `PROTOCOL.md` skeleton
  are Step 1/17
- **Implementation base:** `origin/main` at
  `ca7470fd6ead8f7e1ff0d58e3591e7ce25a5314d`
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Delivery:** one planning PR, thirteen sequential bridge PRs, one activation
  PR, one client PR, one live-verification PR, and one plan-retirement PR

## Goal

Add Claude Code as a first-class Sesori harness by driving the `claude` CLI's
headless **stream-json** protocol directly from a new bespoke bridge plugin, at
full parity with the existing harnesses: sessions, live streaming, tools,
permissions and questions, plan mode, model selection, interrupt, resume with
history replay, slash commands, and image attachments.

The plugin speaks the same ndjson stdio protocol the official Agent SDK speaks
internally, so it needs no Node runtime — the `claude` CLI is a self-contained
binary the user already has installed and logged in.

## Success Criteria

1. `GET /plugin` advertises a `claude` plugin with displayName `Claude Code`,
   correct setup state, and a working brand mark in the mobile picker.
2. A new Claude session created from the phone streams assistant text
   token-by-token, renders thinking, and renders tool cards through their
   pending → running → completed lifecycle.
3. Tool permission requests reach the phone as permission cards; once, always,
   and reject all round-trip correctly, and `always` never escalates beyond the
   permissions the backend itself suggested.
4. `AskUserQuestion` and `ExitPlanMode` render as question cards and their
   answers reach the backend in the exact shapes the CLI expects.
5. Model catalog and mid-session model switching work, and the client nav-bar
   subtitle reflects the switch because every assistant message envelope carries
   both `providerID` and `modelID`.
6. Interrupt stops a running turn promptly and clears any pending permission or
   question card; no stale prompt survives an abort, a session stop, or a
   process exit.
7. History survives a bridge restart: sessions enumerate from the on-disk
   transcript index, open with a full replay whose shapes match live rendering,
   and accept a follow-up turn through `--resume`.
8. Sessions started in an external terminal appear in Sesori after a refresh,
   under the project matching their working directory.
9. No Claude-specific concept — tool name, model id, permission mode, transcript
   path — escapes the plugin package into shared, bridge, or client code.
10. No new `MessagePartType` value and no breaking wire change; the client
    remains data-driven from `GET /plugin` apart from the brand asset and the
    attachment gate.
11. Every implementation PR is independently buildable and targets no more than
    1,500 changed lines as a soft cap, counting additions plus deletions,
    generated output, and tests against that PR's base.

## Current Behavior And Evidence

### There is no prior Claude work in this repository

- Branch `claude-code-support` is 0 commits ahead of `main`; `.plan/` contains
  nothing for Claude.
- The single mention is `README.md:147`, the harness table row
  `| [Claude Code](https://claude.com) | Coming soon | ... |`.
- `shared/sesori_shared/lib/src/models/sesori/plugin_identity.dart` declares
  `enum Harness { opencode, codex, cursor }`.
- `bridge/app/lib/src/bridge/runtime/plugin_registry.dart` registers exactly
  three descriptors.

### The plugin seam is already sufficient

Three shipped plugins cover the two shapes this work needs:

- **Cursor** (`bridge/sesori_plugin_cursor/`) is the closest lifecycle model: a
  CLI subprocess with no port and no ownership file, wrapped in
  `SteadyPluginLifecycle` rather than `ManagedProcessService`, with
  `projectOwnership = bridgeDerived` and `sessionOptionsScope = plugin`.
  `cursor_plugin_descriptor.dart` is the template for probe-then-start.
- **ACP** (`bridge/sesori_plugin_acp/`) owns the mechanics this plugin needs
  verbatim: `AcpStdioClient` line framing and teardown, `AcpApprovalRegistry`
  permission/question bifurcation, `AcpPlugin`'s per-session turn queue with
  generation fencing, and `FakeAcpProcess` as the test seam pattern.
- **Codex** (`bridge/sesori_plugin_codex/`) owns the enumeration model: a global
  on-disk transcript index read through an injected-environment API, scanned in
  `Isolate.run`, with `primeSessionDirectory` a documented no-op.

### The client already renders an unknown harness gracefully

Sessions, messages, tools, permissions, questions, models, and agents are all
data-driven from `GET /plugin`. The only client work is the brand asset, its two
lookup cases, and widening the temporary composer attachment gate.

### Local runtime evidence

The development machine has `claude` 2.1.221 on PATH. Step 2 pins the verified
floor version and records the exact wire shapes observed at that version.

## Protocol Reference

The stream-json control protocol is SDK-internal and not formally versioned.
`PROTOCOL.md` in this directory is the durable ground truth: Step 2 fills it from
direct observation of the pinned CLI plus the SDK's own type declarations, and
every later step cites it rather than re-deriving wire shapes.

Condensed research carried into Step 2 (all marked verify-at-implementation in
`PROTOCOL.md`):

- Invocation: `claude --input-format stream-json --output-format stream-json
  --verbose --include-partial-messages [--model <id>] [--permission-mode <mode>]
  [--session-id <uuid> | --resume <uuid>]`, cwd = the session directory, one
  process per session kept alive by streaming stdin.
- Stdout types: `system` (`init`, `api_retry`, `permission_denied`),
  `assistant`, `user`, `stream_event` (raw Anthropic SSE deltas), `result`,
  `control_request`, `control_response`.
- Permissions arrive as `can_use_tool` control requests answered with
  `{"behavior":"allow"|"deny", ...}`; `AskUserQuestion` and `ExitPlanMode` are
  ordinary tools whose approval is a user question rather than a permission.
- Transcripts live at `$CLAUDE_CONFIG_DIR ?? ~/.claude` +
  `/projects/<munged-cwd>/<session-id>.jsonl`; the filename is the session id
  and each record carries its own `cwd` and timestamps, so the munged directory
  name is never un-munged.
- Auth is the user's existing `claude` login. The plugin never runs a login
  flow and never overrides `HOME`, which would break macOS keychain lookup.

## Locked Scope And Product Decisions

### Included

- A bespoke `bridge/sesori_plugin_claude/` package (pub name `claude_plugin`)
  driving stream-json over stdio, one child process per live session.
- Full `BridgePluginApi` surface plus `PersistedSessionCleanupApi`.
- Global transcript enumeration, history replay, and `--resume` continuation.
- Permission modes surfaced as two agents, **Default** and **Plan**.
- Model catalog with mid-session `set_model` switching.
- Text and image prompt parts; slash commands.
- Brand assets and the two client lookups.

### Excluded

- The `claude-agent-acp` Node adapter route (decided against: adds a Node
  dependency and hides half the protocol behind an adapter).
- `--fork-session`, subagent sessions as first-class children (subagent work
  renders inside its Task tool card), and MCP server management.
- Any managed runtime, download, or version provisioning. The plugin resolves an
  existing binary and reports setup state; it never installs one.
- Any login flow, credential storage, or auth mutation.
- Reasoning-effort variants unless Step 11 finds first-party support; the
  decision is recorded there with evidence rather than assumed now.
- New shared wire types, new `MessagePartType` values, relay changes, database
  migrations, and product analytics. This harness adds no new authoritative user
  action beyond the ones the existing harnesses already instrument.

### Naming

`Harness.claude` with id `claude`; displayName `Claude Code`; package directory
`bridge/sesori_plugin_claude/`; pub name `claude_plugin`; plan slug
`claude-code-plugin`.

## Final Architecture

### Lifecycle shape

Cursor-style lifecycle, codex-style enumeration, per-session processes:

- `SteadyPluginLifecycle`, not `ManagedProcessService` — there is no port to
  reclaim and no ownership file to arbitrate.
- `ensureRuntime` stays the inherited no-op. There is no `RuntimeManifest`
  because there is no first-party download this plugin may legitimately perform.
- The binary is `--claude-bin` (declared as the bare option name `bin`) else
  `claude` on PATH, gated in `inspectSetup` by a typed `SemanticVersion` floor.
- `start()` is cheap: construct, `markReady()`. Authentication failures surface
  at use time as `PluginAuthenticationRequiredException`, which
  `PluginRuntime.use()` already converts into a setup-state flip.
- Per-session child processes spawn lazily on the first turn, are reaped after
  an idle window, and respawn transparently through `--resume`.

### Type

`ClaudePlugin extends BridgeDerivedProjectsPluginApi implements
PersistedSessionCleanupApi`. Claude has no project concept, so projects are
bridge-derived from session working directories. `listAllSessions` ignores
`knownDirectories` because the transcript index is global, and
`primeSessionDirectory` is a documented no-op, both matching Codex.

### Package layout

```
bridge/sesori_plugin_claude/
  pubspec.yaml            claude_plugin; publish_to: none; resolution: workspace
  analysis_options.yaml   include: ../app/analysis_options.yaml
  build.yaml              freezed {format:false,map:false,when:false};
                          json_serializable {any_map:true,explicit_to_json:true}
  lib/claude_plugin.dart          barrel; exports ClaudePluginDescriptor
  lib/claude_testing.dart         barrel; exports FakeClaudeProcess
  lib/src/api/
    claude_stream_client.dart     ndjson stdio client for ONE process
    claude_process_factory.dart   launch spec + host-routed factory
    claude_transcript_api.dart    ~/.claude/projects reader
    models/                       freezed stream, control, and transcript DTOs
  lib/src/repositories/
    claude_catalog_repository.dart      transcript scan -> session records
    mappers/claude_event_mapper.dart    stream messages -> BridgeSseEvent
    mappers/claude_history_mapper.dart  transcript -> PluginMessageWithParts
    mappers/claude_content_mapper.dart  content blocks -> parts/attachments
    trackers/claude_tool_tracker.dart   tool_use lifecycle + delta buffering
  lib/src/services/
    claude_session_service.dart   residency, turn queue, idle reaping, interrupt
    claude_catalog_service.dart   model/agent/command catalog + applied cache
  lib/src/claude_approval_registry.dart  can_use_tool -> permissions/questions
  lib/src/claude_plugin_impl.dart        ClaudePlugin
  lib/src/runtime/
    claude_plugin_descriptor.dart  const descriptor
    claude_bridge_plugin.dart      SteadyPluginLifecycle wrapper
  lib/src/testing/fake_claude_process.dart
  test/                            flat *_test.dart + test/runtime/ + test/support/
```

Layering follows the house style: `api/` is the wire boundary, `repositories/`
normalizes, `services/` coordinates, `runtime/` is descriptor and lifecycle glue.

### Component contracts

**`ClaudeStreamClient`** — one per resident session process. Ports
`AcpStdioClient`'s load-bearing mechanics: `utf8.decoder` plus `LineSplitter` on
stdout; stderr line-logged at debug through `Utf8Decoder(allowMalformed: true)`
(the lenient decoder comes from `managed_runtime_monitor.dart`, because crashing
children emit non-UTF-8 bytes); `unawaited(process.stdin.done.catchError(...))`
to absorb broken pipes; connection-generation fencing across teardown; fail-fast
requests once exited; `_failPending` on teardown; POSIX SIGTERM then SIGKILL,
straight kill on Windows. It also carries Codex's `_redactForLog` secret
redaction for frame and error logging. Surface: a `ClaudeStreamMessage` stream, a
resolved init future, `sendUserMessage`, `sendControlRequest` with request-id
correlation, `sendControlResponse`, a process-exit future, and `dispose`.
Unknown message types are debug-logged and dropped, never warned per line.

**`ClaudeSessionService`** — owns per-session residency (client, applied model,
applied agent, idle timer) plus the turn queue ported from
`AcpPlugin._SessionTurnState`: a `tail` future chain, a `pending` count, and a
`generation` re-checked after every await. The first pending turn emits busy
status plus a project-updated event; turn completion emits idle or error.
Residency reuses a live process, otherwise spawns with `--resume` for an
existing session or `--session-id` for a new one. Idle reaping runs off
`host.clock` and gracefully disposes only that session's client. An unexpected
exit mid-turn finishes the turn as interrupted rather than errored when the
bridge sent the signal, cancels that session's approvals, and drops residency.

**`ClaudeApprovalRegistry`** — architecturally identical to
`AcpApprovalRegistry`: injected emit and respond callbacks, bridge-minted `br-N`
ids, permission/question bifurcation, and a `cancelForSession`/`dispose` contract
that resolves every pending request *and* emits its replied or rejected event.
Claude specifics: requests arrive on a known session's own process, so there is
no session-resolution ambiguity; `AskUserQuestion` and `ExitPlanMode` become
questions and everything else a permission; `once` maps to a plain allow,
`always` echoes only the backend's own `permission_suggestions`, and `reject`
maps to deny with a short message.

**`ClaudeEventMapper`** — the hard contract shared with the Codex and ACP
mappers: every `info` map on a session or message event is sesori-schema JSON
built from `sesori_shared` typed models via `.toJson()`. It maps stream deltas to
message and part updates, `tool_result` blocks to tool completion or error,
edit-shaped tool completions to a session diff signal, `TodoWrite` to the
content-free todo-staleness signal, `api_retry` to a retry status, and error
`result` subtypes to an error message envelope. Every assistant message envelope
is stamped with both `providerID` and `modelID`, because the client nav-bar
subtitle derives from the latest assistant message and renders only when both are
non-null. Per-turn state is pruned at turn boundaries and per-session maps are
nested rather than keyed by composite strings.

**`ClaudeTranscriptApi` + `ClaudeCatalogRepository`** — resolve the transcript
root as `environment["CLAUDE_CONFIG_DIR"]` else `resolveUserHomeDirectory(...)`
plus `/.claude`, mirroring `CodexRolloutApi`'s injected-environment pattern; that
injected map is also the tests' pinning seam. Directory scans run in
`Isolate.run`. JSONL decoding is per-record tolerant because the last line may be
half-written, and that specific case is not warned. Malformed-line diagnostics
report a redacted schema shape and never raw content, because transcript content
is user data. Sidechain and subagent records are excluded from enumeration. No
live tailer is needed: the live stream carries everything, and externally started
sessions appear on the next enumeration.

**`ClaudeHistoryMapper`** — transcript records to `PluginMessageWithParts`,
reusing the content mapper so replayed history matches live rendering. A failed
load throws `PluginOperationException`; it never returns an empty list, because
an empty list means a genuinely empty thread and the phone renders
error-with-retry only for throws.

**`ClaudePluginDescriptor`** — templated on `cursor_plugin_descriptor.dart`. It
declares id, displayName, `bridgeDerived` ownership, `plugin` options scope, and
the single `bin` value option as a bare name that the bridge's option mapper
namespaces to `--claude-bin`. `inspectSetup` runs a bounded `--version` probe
through `HostProcessCommandExecutor`, applies the typed `SemanticVersion` floor,
then probes auth, returning one of the five inspectable statuses — never
`PluginSetupNotInspected`, which is the bridge's own disabled marker — with a
non-empty `actionHint` on each non-ready variant. `start()` checks
`host.startAborted` at entry and after construction, rolls back through
`shutdown(budget: null)` on abort, builds the process factory through
`host.processes` with `runInShell: Platform.isWindows`, and returns a
`ClaudeBridgePlugin`.

**`ClaudeBridgePlugin`** — `with SteadyPluginLifecycle implements BridgePlugin`.
`describe()` reports `{"transport": "claude-stream-json"}`;
`interruptActiveWork` delegates to the session service bounded by the budget;
`onShutdown` disposes the plugin, which reaps every child and resolves every
approval. Per-session process exits are session-level events, not plugin-level
degradation: `markDegraded(recoverable)` fires only when a spawn fails at the
binary level, and `markReady` on the next success.

### BridgePluginApi method mapping

| Method | Implementation |
|---|---|
| `getSessions(projectId)` | catalog scan filtered by normalized directory |
| `getCommands` | slash commands from `system/init`; `PluginCommandSource.command` |
| `getSessionOptions` | aggregate agents, providers, and commands; `refresh` re-probes |
| `createSession` | pre-generate the session UUID, spawn with `--session-id`, dispatch the first prompt through the turn queue |
| `renameSession` | optimistic only; the mobile database is authoritative (Cursor precedent) |
| `deleteSession` | kill the resident process, cancel approvals, delete the transcript, forget caches |
| `archiveSession` / `deleteWorkspace` | no-ops under the best-effort contract |
| `getChildSessions` | `const []`; subagents render inside their Task tool card |
| `getSessionStatuses` | derived from turn bookkeeping |
| `getSessionMessages` | history mapper; throws on failed load |
| `sendPrompt` | ensure residency, apply model/agent selection, queue the turn, write the user message |
| `sendCommand` | dispatch `/command args` as the turn text; completes on write acceptance, not turn completion |
| `abortSession` | interrupt control request, generation bump, `cancelForSession` |
| `getAgents` | Default and Plan permission-mode agents |
| pending / reply / reject permission and question | approval registry |
| `healthCheck` | cheap and instantaneous; `status` is the debounced signal |
| `getProviders` | one Anthropic provider, models from the catalog service |
| `getActiveSessionsSummary` | synchronous; grouped by directory |
| `listAllSessions` | full catalog scan, ignoring `knownDirectories` |
| `launchDirectory` | the same source Cursor's descriptor uses |
| `primeSessionDirectory` | documented no-op (global index) |
| `deletePersistedSession` | idempotent transcript delete |
| `dispose` | reap processes, cancel approvals, close the event channel; idempotent |

### Prompt parts to content blocks

`PluginPromptPartText` becomes a text block. `fileData` with an image MIME
becomes a base64 image block; non-image `fileData` is dropped with a warning,
mirroring the ACP inline-content null case. `filePath` becomes a text block
carrying the path, because Claude reads files itself. `fileUrl` becomes a text
block carrying the URL.

## Registration Waves

Registration lands in two waves. The workspace, Makefile, and CI lists are all
explicit, so a package absent from them is both locally unbuildable and invisible
to CI; the plumbing must therefore land with the scaffold while the app stays
unaware until the flip.

**Wave 1 — with the scaffold in Step 2, app-invisible:**

1. `bridge/pubspec.yaml` — add `sesori_plugin_claude` to `workspace:`. A
   `resolution: workspace` package that is not a member fails `dart pub get`.
2. `bridge/Makefile` — add to `MODULES`.
3. `.github/workflows/bridge-ci.yml` — add the analyze and test step pair.

**Wave 2 — the activation flip in Step 14:**

4. `bridge/app/pubspec.yaml` — path dependency on the new package.
5. `bridge/app/lib/src/bridge/runtime/plugin_registry.dart` — import and register
   `ClaudePluginDescriptor()`. `preferredDefaultPluginId` is untouched. This is
   the only place app code may import the plugin.
6. `shared/sesori_shared/.../plugin_identity.dart` — extend `Harness` with
   `claude`. Additive and wire-safe: identity travels as strings and an absent
   value still decodes to OpenCode.
7. `bridge/app/test/bridge/runtime/plugin_registry_test.dart` — the id-set
   assertion.

## Client Changes

Three files, two assets, and the affected tests:

- `client/module_prego/assets/svgs/brands/claude_light.svg` and `claude_dark.svg`
  (the directory is declared wholesale, so no pubspec edit).
- `client/module_prego/lib/components/icons/prego_brand_logo.dart` — one case in
  `_assetFor` and one in `displayNameFor`.
- `client/module_core/lib/src/foundation/models/composer/composer_attachment_support.dart`
  — widen the dated temporary gate to include Claude, only in the step where
  image forwarding is implemented and verified, keeping the dated comment.
- Tests: `prego_brand_logo_test.dart`, `session_tile_states_test.dart`, and the
  attachment-gate consumers, reusing `findBrandLogo(String pluginId)` from
  `client/app/test/helpers/test_helpers.dart`.

Forward-compatibility guardrail: introduce no new `MessagePartType` value. That
enum has no unknown fallback, so a new value crashes released clients. Every
Claude part kind maps onto an existing type inside the plugin.

## Cleanup Assessment

This is additive work against an untouched harness slot, so it makes nothing
obsolete. Two items are in scope as directly caused updates rather than cleanup:
the README harness row moves from "Coming soon" to Beta in Step 16, and the
temporary composer attachment gate — already carrying a dated comment — gains one
more harness in Step 15 rather than being removed, because Codex and Cursor still
do not accept prompt attachments. No obsolete calculation, model field, column,
transport field, cache, flag, job, or test was found.

## Delivery Rules

- The series has exactly seventeen steps. Every PR title uses the fixed
  `<emoji> [claude-code-plugin] <description> [step <x>/17]` form below.
- Step 1 raises this plan, the tracker, and the protocol skeleton, and registers
  mobile-mcp in `.mcp.json` for the Step 16 simulator run. It runs documentation
  validation, not Dart or Flutter suites.
- Step 17 retires the plan by moving `.plan/active/claude-code-plugin/` to
  `.plan/completed/claude-code-plugin/`, with no production change.
- Steps form one ordered dependency chain and **only one PR is open at a time**.
  Do not stack a successor on an open predecessor. The next step is developed
  locally on its own branch and its PR is opened only after the current PR
  merges, so every PR targets `main` and reviewers never face a queue of
  interdependent branches. Merges therefore occur in numeric order by
  construction, and every PR is independently valid at its own base.
- Count additions plus deletions from `git diff --numstat`, including generated
  code and tests. Target no more than 1,500 changed lines per PR as a soft cap,
  reassessing at roughly 1,300. In this repository tests run about 1.2–1.9× the
  production source and Freezed emits committed `.freezed.dart`/`.g.dart`; the
  estimates below budget for that.
- Do not merge neighboring steps because one lands under estimate. If a step is
  projected to exceed the cap after codegen, find a smaller independently valid
  split and update this plan; if no coherent split is practical, record the
  reason before opening the PR.
- Generated files change only through code generation.
- Internal package contracts update every in-repository caller in lockstep. No
  compatibility shims for internal Dart APIs.
- Every production class introduced by a step has a production consumer or an
  explicitly stated next-step consumer recorded in that step's PR body.
- Run `aristotle-impl-review` on Steps 2–14, each scoped to that PR's branch
  against its base, at most twice per step before asking the user. Steps 1 and
  15–17 are documentation, assets, localized client copy, and mechanical moves,
  and are not reviewed.
- Monitor every PR with `pr-monitor:watch` after opening it.

## Delivery Sequence

| Step | Branch | Exact PR title | Estimate |
|---|---|---|---:|
| 1/17 | `claude-code-support` | `🌱 [claude-code-plugin] docs: plan Claude Code harness plugin [step 1/17]` | 900-1,100 |
| 2/17 | `claude-code-plugin-protocol-scaffold` | `⚙️ [claude-code-plugin] feat(claude): ground protocol and scaffold package [step 2/17]` | 1,100-1,500 |
| 3/17 | `claude-code-plugin-stream-client` | `⚙️ [claude-code-plugin] feat(claude): add stream-json transport [step 3/17]` | 1,000-1,400 |
| 4/17 | `claude-code-plugin-transcript-catalog` | `⚙️ [claude-code-plugin] feat(claude): enumerate transcript sessions [step 4/17]` | 1,100-1,500 |
| 5/17 | `claude-code-plugin-content-mapper` | `⚙️ [claude-code-plugin] feat(claude): map content blocks to parts [step 5/17]` | 900-1,300 |
| 6/17 | `claude-code-plugin-history-mapper` | `⚙️ [claude-code-plugin] feat(claude): replay transcript history [step 6/17]` | 1,000-1,400 |
| 7/17 | `claude-code-plugin-tool-tracker` | `⚙️ [claude-code-plugin] feat(claude): track tool lifecycle [step 7/17]` | 1,000-1,400 |
| 8/17 | `claude-code-plugin-event-mapper` | `🚧 [claude-code-plugin] feat(claude): map stream events to SSE [step 8/17]` | 1,200-1,500 |
| 9/17 | `claude-code-plugin-approvals` | `🚧 [claude-code-plugin] feat(claude): add permission and question registry [step 9/17]` | 1,100-1,500 |
| 10/17 | `claude-code-plugin-session-service` | `🚧 [claude-code-plugin] feat(claude): add session residency and turn queue [step 10/17]` | 1,200-1,500 |
| 11/17 | `claude-code-plugin-catalog-service` | `⚙️ [claude-code-plugin] feat(claude): add model and agent catalog [step 11/17]` | 900-1,300 |
| 12/17 | `claude-code-plugin-plugin-impl` | `🚧 [claude-code-plugin] feat(claude): implement the plugin API surface [step 12/17]` | 1,200-1,500 |
| 13/17 | `claude-code-plugin-descriptor` | `⚙️ [claude-code-plugin] feat(claude): add descriptor and lifecycle [step 13/17]` | 1,100-1,500 |
| 14/17 | `claude-code-plugin-activation` | `⚙️ [claude-code-plugin] feat(claude): register the Claude Code harness [step 14/17]` | 250-500 |
| 15/17 | `claude-code-plugin-client-polish` | `🌿 [claude-code-plugin] feat(client): add Claude Code branding [step 15/17]` | 400-800 |
| 16/17 | `claude-code-plugin-e2e` | `🌿 [claude-code-plugin] docs: record Claude Code live verification [step 16/17]` | 200-500 |
| 17/17 | `claude-code-plugin-retire` | `🌱 [claude-code-plugin] docs: retire Claude Code plugin plan [step 17/17]` | 50-200 |

## Step Details And Verification

### Step 1/17 — Raise The Plan

- Add `PLAN.md`, `TRACKER.md`, and the `PROTOCOL.md` skeleton under
  `.plan/active/claude-code-plugin/`.
- Register mobile-mcp in `.mcp.json` for the Step 16 simulator run, translating
  `opencode.json`'s entry to the `.mcp.json` schema.
- Validate the fixed slug, titles, totals, estimates, and dependencies, and run
  `git diff --check`. No Dart or Flutter suites, no implementation review.

### Step 2/17 — Ground The Protocol And Scaffold The Package

- Pin the CLI version; capture real stream-json transcripts and `--help` output;
  cross-check flags, control subtypes, the stdin user-message envelope, and the
  transcript record schema against the Agent SDK's own declarations.
- Fill `PROTOCOL.md` with observed ground truth, replacing every verify marker
  with either a confirmed shape or a recorded absence.
- Create the package with its pubspec, analysis options, build config, and
  barrels, plus Wave-1 workspace, Makefile, and CI plumbing.
- Add the Freezed and JSON DTOs for stream messages, control payloads, and
  transcript records, with tolerant unknown variants, and run codegen.
- Verify: `dart pub get` at `bridge/`, `dart analyze --fatal-infos` and
  `dart test` in the new package, `make codegen`, implementation review.

### Step 3/17 — Add The Stream-JSON Transport

- Add `ClaudeStreamClient` with line framing, request-id correlation, lenient
  stderr decoding, redacted frame logging, generation fencing, pending-request
  failure on teardown, and platform-correct termination.
- Add `FakeClaudeProcess` and the `claude_testing.dart` barrel.
- Cover framing, exit mid-request, generation fencing, redaction, and
  unknown-type absorption.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 4/17 — Enumerate Transcript Sessions

- Add `ClaudeTranscriptApi` with injected-environment root resolution and
  `ClaudeCatalogRepository` with isolate-backed scanning.
- Add captured, trimmed, anonymized transcript fixtures as inline Dart literals.
- Cover the scan, malformed lines, the half-written last line, sidechain
  exclusion, and privacy-safe diagnostics.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 5/17 — Map Content Blocks To Parts

- Add `ClaudeContentMapper` converting content blocks to plugin parts and
  attachments under the existing tool-output and inline-attachment limits.
- Cover text, thinking, tool use, tool results, images, oversize degradation, and
  unsupported kinds.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 6/17 — Replay Transcript History

- Add `ClaudeHistoryMapper` producing `PluginMessageWithParts` from transcript
  records through the Step 5 mapper.
- Prove throw-on-failure rather than empty-list, and record the shape parity that
  Step 8 must match.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 7/17 — Track Tool Lifecycle

- Add `ClaudeToolTracker` owning `tool_use` lifecycle, streamed `input_json_delta`
  buffering, `tool_result` matching by id, and edit-shaped diff detection.
- Cover out-of-order updates, partial input JSON, unmatched results, and errors.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 8/17 — Map Stream Events To SSE

- Add `ClaudeEventMapper` over the Step 5 and Step 7 components: message and part
  envelopes, text and thinking deltas, tool parts, retry status, the todo
  staleness signal, error result envelopes, and provider/model stamping.
- Prove live shapes match the Step 6 history shapes.
- The Codex analog ran larger than this budget; if codegen or coverage pushes
  this past the cap, record the overage rationale here before opening the PR.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 9/17 — Add The Permission And Question Registry

- Add `ClaudeApprovalRegistry` with permission/question bifurcation, the three
  reply behaviors, `AskUserQuestion` answer-key handling, `ExitPlanMode` approval,
  and teardown that resolves every pending request and emits its outcome.
- Cover cancel-on-abort, cancel-on-dispose, and cancel-on-process-exit.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 10/17 — Add Session Residency And The Turn Queue

- Add `ClaudeSessionService` with residency, the serialized turn queue with
  generation fencing re-checked after every await, interrupt, idle reaping, and
  interrupted-not-errored classification for signalled exits.
- Cover turn serialization, fencing, resume-versus-new spawn arguments, idle reap
  followed by transparent resume, and approval cancellation on exit.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 11/17 — Add The Model And Agent Catalog

- Add `ClaudeCatalogService` owning models, agents, providers, and commands, plus
  `set_model` and `set_permission_mode` application with an applied-selection
  cache cleared on respawn.
- Record the reasoning-effort variant decision with the evidence gathered in
  Step 2; ship without variants if the pinned CLI has no first-party support.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 12/17 — Implement The Plugin API Surface

- Add `ClaudePlugin` implementing the full `BridgePluginApi` plus
  `PersistedSessionCleanupApi` over the Step 3–11 components, as the composition
  root that injects every collaborator explicitly.
- Cover contract-level behavior: not-found handling, the buffered event channel,
  session creation identity, delete semantics, and the activity summary.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 13/17 — Add The Descriptor And Lifecycle

- Add `ClaudePluginDescriptor` with the option declaration, the bounded version
  probe, the auth probe, and the five inspectable setup states with action hints;
  add `ClaudeBridgePlugin` over `SteadyPluginLifecycle`.
- Cover probe sequencing through a stubbed process service, abort rollback, and
  the degraded/ready transitions.
- Verify: focused and full package tests, fatal analysis, implementation review.

### Step 14/17 — Register The Harness

- Extend `Harness` with `claude`, add the app path dependency, register the
  descriptor in `knownPlugins`, and update the registry and identity tests.
- Verify: `cd bridge && make analyze && make test`, plus a
  `dart run bin/bridge.dart --version` smoke run, and implementation review.

### Step 15/17 — Add Claude Code Branding

- Add the light and dark brand SVGs matching the existing brand assets'
  conventions, add the logo and display-name cases, widen the composer attachment
  gate, and update the affected client tests.
- Verify: `flutter test` in `client/module_prego`, `client/module_core`, and
  `client/app` for the touched tests. Asset-rendering tests may be flaky locally
  in a worktree; trust CI for those.

### Step 16/17 — Record Live Verification

- Run the E2E matrix below on the simulator against a source-run bridge and a
  real logged-in `claude` CLI; record `E2E.md` in this directory.
- Move the README harness row from "Coming soon" to Beta.
- Failures become ordinary single-PR fixes with normal titles between Steps 15
  and 16, or explicitly labelled non-blocking follow-ups.

### Step 17/17 — Retire The Plan

- Record the final merged PR and verification evidence in the tracker, then move
  the plan tree from `.plan/active/` to `.plan/completed/` in the same commit.
- Confirm all seventeen PRs merged in order and run `git diff --check`. No suites
  and no implementation review.

## Live Verification Matrix

Recorded in `E2E.md` at Step 16, following
`.plan/completed/setup-aware-harness-settings/E2E.md`.

**Environment.** iPhone 17 simulator with `com.sesori.app` installed and signed
into the same account as the bridge; the bridge run from source with
`dart run bin/bridge.dart --debug-port 9977 --data-dir
/Users/daniil/.local/share/sesori-dev --log-level debug`; a real logged-in
`claude` on PATH. Assertions are hybrid: `curl http://127.0.0.1:9977` against the
same router the relay uses, alongside mobile-mcp UI observation using element-list
point coordinates rather than screenshot pixels. Turns consume the user's own
quota, so prompts stay minimal.

| ID | Check |
|---|---|
| E2E-01 | `GET /plugin` shows claude ready with the correct display name |
| E2E-02 | `--claude-bin /nonexistent` yields RuntimeMissing with an action hint |
| E2E-03 | The new-session picker lists Claude Code with its brand mark |
| E2E-04 | A tiny first prompt streams token-by-token and the session row appears |
| E2E-05 | An extended-thinking prompt renders a reasoning part |
| E2E-06 | A file-listing prompt renders a tool card through to Done with output |
| E2E-07 | A file-creating prompt raises a permission card; approve once succeeds, reject continues the turn with a denial |
| E2E-08 | Approving always lets the next same-tool call proceed without a prompt |
| E2E-09 | A question-provoking prompt renders a question card and the answer reaches the turn |
| E2E-10 | Plan agent plus a change request yields an ExitPlanMode card; approval resumes execution in default mode |
| E2E-11 | The catalog lists real models and a mid-session switch updates the nav-bar subtitle after the next reply |
| E2E-12 | Stopping a long task goes idle promptly with sane process state |
| E2E-13 | Aborting with a pending permission clears the card |
| E2E-14 | After a bridge restart the session list is intact, history replays fully, and a follow-up resumes |
| E2E-15 | A session started in an external terminal appears under its project after refresh |
| E2E-16 | An attached photo is described correctly |
| E2E-17 | The command catalog lists slash commands and one executes |
| E2E-18 | A follow-up after the idle-reap window resumes transparently |
| E2E-19 | The harness settings card disables and re-enables Claude Code |
| E2E-20 | The debug-level bridge log has no unhandled errors and no `claude` process leaks after shutdown |

## Compatibility

- The client/bridge wire contract is unchanged. Plugin identity already travels
  as a string with a documented OpenCode fallback for absence, so adding
  `Harness.claude` is additive in both directions.
- An older app against a new bridge sees Claude sessions rendered through the
  existing unknown-harness fallback: a generic mark instead of the brand asset,
  everything else identical.
- A newer app against an older bridge simply never sees the harness, because the
  picker is populated from `GET /plugin`.
- Internal Dart package APIs update all monorepo consumers in lockstep, with no
  deprecated aliases or optional compatibility parameters.

## Material Risks And Mitigations

| Risk | Evidence level | Mitigation |
|---|---|---|
| The stream-json control protocol is SDK-internal and drifts between CLI releases. | Known upstream property | Pin a floor in `inspectSetup`, feature-detect from `init.capabilities`, parse tolerantly, and keep `PROTOCOL.md` as dated ground truth for the pinned version. |
| Verify-at-implementation items (stdin envelope, control subtypes, permission-prompt flag, model listing, effort support, slash dispatch, auth probe, transcript schema) turn out different from the research. | Unresolved by design | Step 2 resolves each against the pinned CLI and the SDK declarations before any consumer is written; each resolution is recorded in `PROTOCOL.md`. |
| The auth probe costs seconds inside `inspectSetup`. | Ordinary flow | Run the version probe first, bound the auth probe, and accept `PluginSetupUnknown` as honest degradation. |
| Overriding `HOME` for test isolation breaks keychain auth and reports a logged-in user as logged out. | Observed in prior integrations | Never override `HOME`; isolate tests through `CLAUDE_CONFIG_DIR` only, and assert that in the transcript tests. |
| A stale permission or question card survives a stop, an abort, or a process exit. | Observed in prior integrations | The registry teardown contract resolves every pending request and emits its outcome; Steps 9 and 10 cover all three paths. |
| Idle resident processes accumulate memory. | Known upstream property | Reap after an idle window and rely on `--resume` to make respawn invisible. |
| Coordination machinery grows beyond the evidence. | Repository rule | The ported turn queue with generation fencing is the ceiling of allowed coordination; anything beyond it requires an observed failure first. |
| Live verification consumes the user's own token quota. | Certain | Keep every E2E prompt minimal and note consumption in the E2E cleanup section. |

## Plan Review Record

`aristotle-plan-review` is an architecture reviewer for architecture-bearing
production plans, which this is. The review verdict, date, reviewed scope, and
any applied corrections are recorded in `TRACKER.md` when the review runs, before
Step 2 begins.
