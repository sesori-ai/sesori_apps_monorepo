# Grok Build Harness Support

## Status

- **Plan slug:** `grok-harness`
- **Status:** active; Step 1/9 in progress
- **Plan date:** 2026-08-27
- **Implementation base:** `origin/main`
- **Delivery:** nine PRs with fixed titles and order below
- **Initial product scope:** user-installed Grok Build CLI; no bridge-managed runtime installation

## Goal

Add xAI's Grok Build CLI as a first-class Sesori harness through its official ACP v1 stdio mode. A configured
Grok installation should appear in harness settings, import persisted Grok sessions, create and continue sessions,
stream messages/reasoning/tools, request phone-mediated permissions, expose selectable models and reasoning effort,
replay history, abort work, and recover after plugin or bridge restart.

This plan deliberately integrates the Grok **harness**. Merely using an xAI model through an existing OpenCode or Pi
provider remains a separate configuration path and needs no Grok plugin.

## Authoritative Upstream Facts

Research baseline:

- Grok Build stable channel: `1.0.5` from <https://x.ai/cli/stable> on 2026-08-27.
- Public source snapshot: `xai-org/grok-build` commit `9684fa3cdbf2995e30ea8b9b637f1db008f144fc`, synced
  from monorepo revision `70ec060ec3d28e77b9c4593be43c2ab0128bcd21`.
- Official agent-mode documentation:
  <https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/15-agent-mode.md>.

Facts verified in that documentation and source:

- The local ACP entry point is `grok agent stdio`; ACP is JSON-RPC 2.0 over newline-delimited stdio.
- `initialize` negotiates ACP protocol version 1 and advertises standard load plus session list, resume, and close.
- Standard ACP owns session creation, load/replay, resume, prompt streaming, cancellation, tool updates, and permission
  requests.
- Normal ask mode remains active unless the caller passes `--always-approve`/`--yolo`. Sesori must not pass either.
- `--no-leader` forces the spawned process to own its local agent rather than attaching to Grok's shared leader.
- `--no-auto-update` suppresses update checks for an embedded/headless process.
- Authentication is local to the bridge machine through `grok login`, `XAI_API_KEY`, enterprise auth, or a configured
  custom model. ACP advertises usable auth methods and `authenticate` is the runtime authority.
- Initialize metadata includes `grokShell`, `agentVersion`, and pre-session `modelState`. New/load responses also carry
  Grok's model state.
- Grok 1.0.5 still exposes the older ACP `models` shape and `session/set_model`. Reasoning effort is carried in model
  metadata (`supportsReasoningEffort`, `reasoningEfforts`, and `reasoningEffort`) and selected through
  `_meta.reasoningEffort` on `session/set_model`.
- The model surface is no longer part of current stable ACP. It is therefore a Grok-owned compatibility surface, not a
  reason to widen generic `sesori_plugin_acp` contracts.
- Prompt capability does not advertise images in the reviewed source. Initial Grok support is text/embedded-context
  only and must not claim image attachment support.
- `session/close` releases a resident session but does not delete Grok persistence. Sesori deletion therefore keeps the
  existing local tombstone behavior and does not invoke `grok sessions delete` in this plan.

Step 2 must validate the released `1.0.5` binary itself before freezing `minVersion`, launch argument ordering, model
fixtures, and setup expectations. If the binary contradicts these source facts, the released binary wins and this plan
is corrected before production code relies on the mismatch.

## Locked Product Decisions

- Plugin ID is `grok`; display name is `Grok Build`.
- Use the user's installed `grok` binary from PATH, or authoritative `--grok-bin <path>`.
- Set the initial minimum and target versions to the released binary verified in Step 2. A lower floor is allowed only
  with direct release evidence for every required capability.
- Do not add a managed install. Grok already has an official six-target installer and self-update flow; Sesori will not
  duplicate it without a separate product request and immutable artifact-digest review.
- Launch a dedicated process with auto-update and leader attachment disabled, but keep ask-mode permissions enabled.
- Setup inspection is runtime-only. It never reads credential contents, invokes login, starts an ACP server, or treats
  the mere presence of `auth.json` as proof. The live ACP initialize/authenticate handshake is authoritative and an auth
  failure flips the existing plugin setup state with local-login guidance.
- Grok model IDs remain opaque. Expose them under one Grok-owned provider grouping and send the exact model ID back to
  `session/set_model`; never split or infer provider identity from punctuation.
- Reasoning options use exact advertised values as variant IDs and advertised labels as presentation. Unknown or
  malformed options are skipped without rejecting otherwise usable models.
- A requested model/effort change must succeed before prompt dispatch. On failure, preserve the original error as the
  cause, fail the accepted turn visibly, and do not record a partially applied selection.
- Only standard ACP permission requests are supported. No Grok-specific question protocol or automatic approval is
  invented.
- Existing generic plugin analytics remain unchanged. No Grok-specific event is added because no new product decision
  requires one, and analytics policy forbids provider/model names.

## Scope

### Included

- New pure-Dart `bridge/sesori_plugin_grok/` package over `sesori_plugin_acp`.
- Typed Grok model-state and reasoning-option DTOs with generated JSON parsing.
- Grok-local ACP API, catalog repository, session-options service, binary definition, plugin implementation, and
  descriptor.
- Runtime version probing, explicit/PATH precedence, read-only setup inspection, pre-start revalidation, dedicated ACP
  process ownership, crash degradation/reconnect, and idempotent shutdown.
- Standard ACP session import, creation, prompt/command delivery, streaming, permissions, abort, history replay,
  resume, and close behavior inherited from the shared ACP implementation.
- Pre-session model discovery from initialize metadata, explicit refresh through a short-lived initialize-only ACP
  process, exact model/effort selection, and last-good catalog retention.
- Bridge registry/workspace/CI inventory, built-in `Harness.grok` identity, client name/logo mapping, README and
  architecture documentation.
- Regression-document reconciliation and live Grok verification through the matrix below.

### Excluded

- Bridge-managed Grok download, installation, upgrade, rollback, or artifact checksums.
- Browser/device login through the phone; users authenticate locally with Grok's supported flows.
- Grok hosted WebSocket/relay mode, leader mode, cloud sandboxes, dashboard, plugins, or Grok-specific `x.ai/*`
  extensions not required for the listed behavior.
- Image prompts until Grok advertises and successfully verifies the standard ACP image capability.
- Upstream session deletion, session fork/rewind, quota display, worktree APIs, or import from another harness.
- Parsing model IDs to infer provider/family/release metadata.
- New database tables, columns, bridge/client transport fields, preferences, routes, analytics events, or compatibility
  shims.

## Architecture

```text
client <-> relay <-> bridge app <-> sesori_plugin_grok <-> grok agent --no-leader stdio
                                  \-> sesori_plugin_acp (standard ACP ownership)
```

### Ownership Boundaries

- `sesori_plugin_interface` remains unchanged and backend-neutral.
- `sesori_plugin_acp` continues to own standard ACP transport, handshake, process recovery, derived projects, session
  enumeration/load, turn lanes, event mapping, replay, cancellation, commands, and permission mechanics.
- `sesori_plugin_grok` owns every Grok identifier, CLI argument, version/setup rule, initialize identity check,
  deprecated model-state shape, reasoning metadata, model selection call, and Grok-facing error guidance.
- Bridge app imports Grok only at `plugin_registry.dart`, its supported composition point.
- Client behavior continues to use opaque plugin IDs; only the built-in presentation mapping recognizes `grok`.

### Planned Grok Collaborators

- `GrokPluginIdentity`: stable `grok` ID and `Grok Build` display name.
- `GrokBinary`: default executable and dedicated ACP launch spec.
- `GrokModelInfoDto`, `GrokModelMetadataDto`, `GrokReasoningEffortOptionDto`, and
  `GrokSessionModelStateDto`: typed boundary parsing for the reviewed Grok wire shape.
- `GrokAcpApi`: initialize-only catalog probe plus `session/set_model`; no business mapping.
- `GrokCatalogRepository`: validates Grok initialize identity and maps exact model/effort values into a catalog.
- `GrokCatalogTracker`: sole owner of the last-good immutable catalog and its replace-on-success/retain-on-failure
  invariant across initialize capture, new/load capture, and explicit refresh.
- `GrokSessionOptionsService`: consumes the repository and tracker to coordinate discovery, project one primary
  agent/provider, and apply exact session-local selections before turns without storing duplicate catalog state.
- `GrokPlugin`: thin `AcpPlugin` specialization that captures initialize/new/load model state, exposes options, opts
  into fail-closed selection and stop-and-send, and delegates Grok-specific work.
- `GrokPluginDescriptor`: CLI option, version/setup probes, pre-start runtime validation, composition, and lifecycle.

No Grok event mapper, approval registry, process supervisor, persistence store, timer, lock, dedupe set, or custom
session registry is planned because standard ACP already owns those concerns.

### Catalog And Selection Flow

```text
plugin start -> standard ACP initialize
             -> validate grokShell + version metadata
             -> map initialize._meta.modelState
             -> seed last-good options/defaults

explicit option refresh -> short-lived dedicated grok ACP process
                        -> initialize/authenticate only
                        -> map modelState
                        -> dispose without session/new
                        -> replace last-good catalog only on success

create/send -> validate exact requested model + variant against catalog
            -> session/set_model(sessionId, modelId, _meta.reasoningEffort?)
            -> record selection only after success
            -> standard ACP session/prompt
```

A short-lived refresh process is justified by a normal user flow: Grok model configuration can change while the bridge
runs, while the reviewed public ACP surface has no stable model-list request. It creates no session or durable state.
Concurrent refreshes may duplicate this bounded probe; no Grok-specific lock or in-flight registry is added because the
impact is low and bridge-owned option caching already limits ordinary calls.

### Setup And Authentication

`inspectSetup` runs a bounded `--version` probe only. It classifies missing, malformed, below-floor, ready, and unknown
runtime states with sanitized guidance. `ensureRuntime` repeats the same read-only resolution immediately before start.
An explicit path is authoritative and never falls through to PATH.

The descriptor does not inspect `HOME`, `GROK_HOME`, `auth.json`, model config, or environment-key contents. Those are
incomplete evidence because Grok supports several auth methods and custom model credentials. The live ACP handshake
selects the first non-terminal method through existing generic behavior. A rejected/no-usable method remains a typed
`PluginAuthenticationRequiredException`, allowing bridge lifecycle code to block only Grok and show local
`grok login`/credential guidance.

## Compatibility And Security

- Plugin IDs remain strings on the wire. Older clients show the generic icon and bridge-provided name; newer clients
  connected to an older bridge receive no Grok entry.
- No public production compatibility baseline contains Grok, so package-internal contracts can be introduced cleanly.
- No `--always-approve`, `--yolo`, client terminal, or client filesystem capability is enabled. Grok's local tools run
  under Grok's own permission/sandbox policy and standard ACP approvals remain phone-mediated.
- `--no-leader` keeps subprocess/session lifecycle within the plugin generation rather than attaching to an unrelated
  shared daemon. `--no-auto-update` prevents the owned child from mutating its executable during bridge operation.
- Credentials, auth payloads, model configuration, raw initialize metadata, prompts, transcripts, paths, and tool
  payloads are never logged or persisted by new Grok-specific code.
- Grok's own provider traffic, telemetry, retention, and enterprise policy remain governed by the user's Grok
  configuration; Sesori neither weakens nor silently overrides them.
- Unknown model metadata is ignored at the typed boundary. Exact recognized values are retained without interpretation.
- Standard close is used only for lifecycle cleanup; local deletion retains a plugin-scoped tombstone so an upstream
  Grok row cannot reappear through later explicit import.

## Complexity Budget And Cleanup

New persistent mutable state:

- None in Sesori. Existing session/catalog/history tables and tombstones are reused.
- Grok continues to own its existing session/auth/config files; Sesori does not mutate their layout directly.

New in-memory mutable state:

- One last-good immutable Grok model catalog owned by `GrokCatalogTracker` inside the plugin generation. It is required
  so options remain usable after a failed explicit refresh; initialize, new/load capture, and refresh all replace it
  through that one owner.
- Existing `AcpSessionConfigurationTracker` owns process defaults and per-session model identity. The service and plugin
  store no duplicate catalog or selection map.

Deliberately omitted coordination:

- No refresh mutex, process pool, background watcher, timer, reconnect registry, auth cache, model-ID parser, or
  secondary command/approval tracker.
- No managed-runtime state or installer lifecycle.
- No compatibility migration or database backfill.

Cleanup assessment:

- No existing field, route, cache, setting, listener, job, or compatibility path becomes obsolete.
- Directly caused cleanup is limited to keeping hard-coded workspace/module/registry/branding inventories exact. Git
  history remains the audit trail; no tombstone documentation for unshipped behavior is added.

Evidence level for safeguards:

- Dedicated process ownership, disabled auto-update, fail-closed selection, and permission ask mode protect ordinary
  launch/turn flows with meaningful lifecycle or security impact.
- Last-good catalog retention protects an ordinary explicit refresh failure.
- Duplicate concurrent refresh probes are accepted as bounded and self-correcting rather than adding coordination.

## Analytics Assessment

No event is added. Existing authoritative session-creation and turn outcomes already measure generic product use without
exposing harness/model identity. A Grok-specific event would not answer an approved decision and would conflict with the
closed analytics privacy contract forbidding coding provider/model names.

## Delivery Steps

1. `🌱 [grok-harness] docs: plan Grok Build harness support [step 1/9]`
   - Add and architecture-review this plan/tracker; no production behavior.
2. `🌿 [grok-harness] feat(grok): scaffold the Grok plugin package [step 2/9]`
   - Add the workspace package, identity, binary launch spec, typed DTOs/fixtures, released-binary contract evidence,
     and focused parsing/launch tests. Freeze the validated floor and invocation.
3. `⚙️ [grok-harness] feat(grok): expose models and reasoning effort [step 3/9]`
   - Add the ACP API, catalog repository/tracker, options service, exact model/effort mapping, refresh/last-good
     behavior, selection calls, and tests.
4. `⚙️ [grok-harness] feat(grok): compose ACP sessions and turns [step 4/9]`
   - Add `GrokPlugin`, initialize identity/catalog capture, standard ACP lifecycle hooks, stop-and-send/fail-closed
     behavior, history/permission/tool conformance tests, and idempotent disposal.
5. `⚙️ [grok-harness] feat(grok): add direct-CLI setup and lifecycle [step 5/9]`
   - Add descriptor version/setup probes, explicit/PATH precedence, ensureRuntime revalidation, production composition,
     crash/reconnect/auth degradation tests, and local setup guidance.
6. `⚙️ [grok-harness] feat(bridge): activate Grok Build [step 6/9]`
   - Add app dependency/registry and built-in identity, update exact-set fixtures and architecture inventories, enable
     Grok by default, and verify backend-neutral listing/routing.
7. `🌿 [grok-harness] feat(client): brand Grok Build [step 7/9]`
   - Add approved official light/dark artwork, built-in name mapping, widget tests, README support/setup/security notes,
     and unknown-ID fallback coverage.
8. `🌱 [grok-harness] docs: reconcile Grok regression coverage [step 8/9]`
   - Penultimate step: update affected `docs/regression/` contracts, matrices, sources, and honest limitations without
     changing unrelated historical gaps.
9. `⚙️ [grok-harness] test: verify Grok and retire the plan [step 9/9]`
   - Run and record the required matrix against the released Grok binary, fix only in-scope defects, move the passing
     plan to `.plan/completed/grok-harness/`, and update the tracker.

Each step targets fewer than 1,500 changed lines, including tests and generated output. Step 3 may approach that cap
because its typed generated DTOs and behavioral tests are one coherent mapping boundary; split only if measured changed
lines
exceed the cap and an independently valid boundary exists. The fixed nine-step total otherwise remains unchanged.

## Step Details

### Step 1/9: Plan Grok support

- Record source-backed protocol facts, ownership, product limits, complexity budget, exact PR series, and retirement
  matrix.
- Run `architecture-plan-review` through a sub-agent and apply valid in-scope findings directly.
- Validate only plan Markdown, links/paths, exact titles, and Git whitespace.

### Step 2/9: Scaffold and pin the released contract

- Create `bridge/sesori_plugin_grok/` with workspace metadata, exports, build options, `GrokPluginIdentity`,
  `GrokBinary`, and typed model-state DTOs.
- Validate Grok 1.0.5 `--version`, exact agent argument ordering, initialize identity/capabilities, auth-method shape,
  model metadata, permission mode, and clean process exit without creating a session.
- Store privacy-safe deterministic fixtures derived from structure, never credentials or real model/account payloads.
- Add package parsing and launch-spec tests; do not register the plugin yet.

### Step 3/9: Models and reasoning effort

- Implement typed initialize/new/load model-state mapping with exact opaque model IDs.
- Add `GrokCatalogTracker` as the only owner of last-good catalog replacement and retention.
- Expose one primary Grok agent and one Grok-owned provider group; map per-model reasoning options to variants.
- Route production initialize, new/load capture, and explicit initialize-only refresh through the tracker; a failed
  refresh retains its prior catalog.
- Send exact model plus optional `_meta.reasoningEffort` through `session/set_model` before a turn; reject unknown/stale
  selections and retain original causes.
- Cover malformed peers, empty/partial catalogs, default ordering, refresh failure, model-only/effort-only changes, and
  no partial tracker write.

### Step 4/9: ACP plugin core

- Compose the existing ACP trackers/mapper/process factory with Grok-specific options.
- Validate Grok identity metadata before accepting the connection and capture refreshed model state after new/load.
- Use standard per-session concurrency, cancellation, permission handling, command tracking, list/load/replay/close,
  and crash recovery. Enable stop-and-send and fail-closed selection only where Grok's verified behavior requires them.
- Cover two sessions, accepted-send timing, cancellation, tool/reasoning mapping, permissions, history suppression,
  reconnect, and disposal with deterministic ACP fakes.

### Step 5/9: Descriptor and setup

- Add `--grok-bin`, version parsing/floor, bounded output, explicit/PATH precedence, read-only setup classification,
  ensureRuntime revalidation, and sanitized local install/login guidance.
- Launch through `PluginHost.processes`; never call `io.Process.start` directly.
- Compose one `AcpBridgePlugin`, connect within a bounded budget, and degrade only Grok on auth/start/crash failure.
- Cover missing/malformed/outdated/current binaries, explicit-path authority, aborts, auth rejection, crash/reconnect,
  reported version, and clean owned shutdown.

### Step 6/9: Activate the bridge

- Add the app dependency and descriptor to `knownPlugins`; add `Harness.grok` so exact registry tests remain true.
- Update bridge workspace/Makefile/module order, package inventories, app docs, root architecture, and relevant CI/test
  fixtures.
- Preserve OpenCode as preferred default. Grok is eligible by default but starts only on demand after setup allows it.
- Verify unknown older clients remain safe because transport IDs are strings.

### Step 7/9: Brand and document

- Source official Grok artwork from an xAI-controlled asset, record its origin, and add theme-appropriate SVGs without
  embedding scripts, remote references, metadata, or unneeded complexity.
- Extend `PregoBrandLogo` and tests for `grok`/`Grok Build`; retain generic fallback for unknown IDs.
- Update README harness list and Grok notes: version floor, official install, `--grok-bin`, local auth, ask-mode
  permissions, text-only attachments, model selection, session import, and retained upstream rows after local deletion.

### Step 8/9: Reconcile regression documents

Update at least:

- `plugin-setup-and-lifecycle.md`
- `projects-and-sessions.md`
- `session-creation-and-options.md`
- `session-turns.md`
- `session-history-and-recovery.md`
- `questions-and-permissions.md`
- `tools-and-file-changes.md`
- `session-archiving-and-deletion.md`

Add `attachments-and-images.md` only if the implementation discovers an advertised image capability; otherwise keep the
unsupported behavior in Grok support notes without manufacturing a feature claim. `plugin-runtime-installation.md` is
unchanged because Grok deliberately has no managed install.

### Step 9/9: Verify and retire

- Run focused package/app/client tests and analyzers after the final code state.
- Execute the matrix below with a real supported Grok release and account.
- Record Pass/Partial/Fail/Blocked with privacy-safe evidence and cleanup in `TRACKER.md`.
- Do not retire on incomplete required coverage unless the user explicitly accepts a named reduction in this plan.

## Regression And Retirement Matrix

Highest required level: **L3 Release** for every affected feature through Grok's complete authoritative boundary. L1-L3
are cumulative. Existing non-Grok plugins need only unchanged automated registry/exact-set checks; the live matrix adds
Grok as a newly supporting production plugin.

Release matrix:

- **Grok runtime:** released stable at or above the frozen Step 2 floor; record exact version.
- **Bridge host:** macOS arm64 release-target host for live/client evidence; deterministic descriptor tests cover other
  host-independent PATH behavior. No alternate-host packaged claim exists because there is no managed install.
- **Client:** iOS simulator/device as the release-target client platform for L3 rendering and end-to-end flows.
- **Account:** one locally authenticated Grok account/API-key/custom-model setup with at least two selectable models or
  one model with two effort levels where the account catalog permits. Record only bounded capability presence, never
  account/model identifiers.

- **`plugin-setup-and-lifecycle.md`**
  - Evidence: missing/malformed/below-floor/current PATH and explicit probes; inert registration; demand start; auth
    failure isolation; version display; enable/disable/restart/idle override; branding and catalog refresh.
  - Boundary: automated, headless bridge, live plugin, and client E2E.
- **`projects-and-sessions.md`**
  - Evidence: explicit import of persisted Grok sessions; DB-only ordinary reads; non-destructive re-import and plugin
    attribution.
  - Boundary: headless bridge and live plugin.
- **`session-creation-and-options.md`**
  - Evidence: current default, exact model IDs, advertised effort variants, stale rejection/refresh, creation, and
    remembered plugin defaults.
  - Boundary: automated, live plugin, and client E2E.
- **`session-turns.md`**
  - Evidence: text/reasoning/tool/status streaming, accepted-send timing, model/effort application, abort,
    stop-and-send, two-session concurrency, visible failure, and idle completion.
  - Boundary: live plugin and client E2E.
- **`session-history-and-recovery.md`**
  - Evidence: first load replay, long-session paging, live/replay parity, cold reopen, plugin restart, and bridge
    restart.
  - Boundary: headless bridge, live plugin, and client E2E.
- **`questions-and-permissions.md`**
  - Evidence: standard permission once/reject plus every advertised scope, exact session/tool correlation, abort
    cleanup, and no auto-approval.
  - Boundary: live plugin and client E2E.
- **`tools-and-file-changes.md`**
  - Evidence: tool lifecycle, bounded output, file diff content, and live/replay identity/status parity.
  - Boundary: live plugin and client E2E.
- **`session-archiving-and-deletion.md`**
  - Evidence: archive/read-only behavior; active delete orders cancel/settle/close; local purge/tombstone prevents
    re-import while the upstream row remains documented.
  - Boundary: headless bridge, live plugin, and client E2E.
- **Compatibility/presentation**
  - Evidence: automated unknown-ID fallback and current-client Grok name/artwork; no new wire field or migration.
  - Boundary: automated and client E2E.

## Risks And Test Focus

- **Released/source drift:** public source is a synchronized monorepo snapshot and may lead stable binaries. Step 2 pins
  black-box released behavior before code relies on it.
- **Unstable model surface:** Grok uses an ACP model API removed from current stable ACP. Keep it plugin-local, validate
  identity/version, parse tolerantly, and fail closed before prompting.
- **Authentication diversity:** file/env presence cannot prove every supported auth mode. Keep setup runtime-only and
  the live handshake authoritative.
- **Permission safety:** accidentally passing yolo/always-approve would bypass the core product interaction. Assert the
  exact launch arguments and observe a real permission request before retirement.
- **Leader ownership:** attaching to a shared leader would break generation ownership and shutdown assumptions. Assert
  `--no-leader` and verify the owned child exits.
- **Auto-update mutation:** a child update during operation could replace the runtime under the bridge. Assert
  `--no-auto-update`; users update Grok out of band.
- **Catalog refresh:** a second initialize-only process may fail or see a changing catalog. Replace only on complete
  success and accept duplicate concurrent probes rather than adding coordination.
- **History/delete semantics:** close is not delete. Verify tombstones prevent explicit re-import and document retained
  Grok persistence honestly.
- **Privacy:** keep model/account names, credentials, prompts, transcripts, paths, raw metadata, and logs out of
  committed fixtures and verification evidence.

## Expected Result

A supported local Grok Build installation appears as a built-in, on-demand harness. Users can import or create Grok
sessions, choose advertised models and reasoning effort, control ask-mode permissions, stream and recover work through
the existing encrypted relay, and manage Grok independently of every other plugin. Sesori adds no credentials,
database schema, transport shape, managed runtime, or Grok-specific analytics, and remains honest about text-only
prompt support and retained upstream persistence after local deletion.
