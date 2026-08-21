# Reliability Cleanup Series

## Status

- **Plan slug:** `reliability-cleanup`
- **Status:** Approved by owner 2026-08-21 with an explicit vagueness waiver
  (see Owner Waivers). Both permitted architecture-plan-review attempts
  rejected Steps 5-6's type-level detail as too vague; the owner accepted the
  current design level, so exact constructor signatures/seam types are pinned
  inside each implementation PR instead and reviewed there via
  `architecture-implementation-review`. Do not re-run plan review on this
  basis. Ready for Step 1 when the owner says go.
- **Plan date:** 2026-08-21
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at `084b30276`
- **Delivery:** fourteen numbered PRs executed one by one; Step 13 reconciles
  regression documents, Step 14 runs the recorded verification matrix and
  retires this plan
- **Investigation inputs:** five parallel code investigations (bridge app,
  bridge plugins, client module_core, client UI shells, shared/tooling) plus
  targeted verification of every high-confidence finding cited below.
  Findings that could not be verified were excluded or explicitly deferred.

This plan and `TRACKER.md` are the authority for implementation. The code and
released product behavior remain authoritative where this document becomes
stale.

## Workspace And Package Map

Applicability of workspace-level instruction sets per step. `shared/sesori_shared`,
`client/module_auth`, `client/desktop`, `client/module_desktop_core`,
`client/design_catalog`, and the external relay/auth servers are **not touched
by any step** (B-Shared not applicable).

| Step | Bridge workspace packages | Client workspace modules |
|---|---|---|
| 2 | `app`, `sesori_plugin_codex`, `sesori_plugin_opencode`, `sesori_plugin_runtime` | none |
| 3 | `app` | none |
| 4 | `app` | none |
| 5 | `app` | none |
| 6 | `app` | none |
| 7 | `sesori_plugin_runtime` (+ pubspec dep additions), `sesori_plugin_acp`, `sesori_plugin_codex`, `sesori_plugin_claude`; `bridge/AGENTS.md` module-order doc | none |
| 8 | `sesori_plugin_interface`, `sesori_plugin_runtime`, `sesori_plugin_acp`, `sesori_plugin_codex`, `sesori_plugin_claude`, `sesori_plugin_opencode`, `sesori_plugin_cursor`, `sesori_plugin_omp`, `sesori_plugin_pi` | none |
| 9 | none | `module_core`, `app` |
| 10 | none | `module_prego`, `app` |
| 11 | none | `app` |
| 12 | none (repo-root CI/installer files only) | none |
| 13–14 | docs only | docs only |

## Goal

Spend a focused series of PRs making the existing system more reliable and
maintainable without shipping new features:

1. **Remove duplication that has already drifted.** Several subsystems exist as
   two or three near-identical copies with concrete behavioral divergences.
   Each copy is an independent failure surface and a place where a fix applied
   to one silently misses the others.
2. **Reduce failure points in oversized coordinators.** The Orchestrator,
   PluginRuntime, and several client widgets each own too many unrelated
   mutable concerns in one scope, so every change risks unrelated paths. Move
   cohesive responsibilities behind single owners without changing behavior.
3. **Delete dead and expired code.** Unused implementations, dead navigation
   helpers, redundant delegation layers, and compatibility paths for releases
   older than the approved baseline all add surface area that must be read,
   tested, and reasoned about forever.
4. **Make recovered failures observable.** A handful of catches swallow errors
   without any trace or interpolate caught errors into strings, discarding
   stack traces exactly where diagnosis is hardest.

The series intentionally optimizes for fewer lines, fewer mutable parts, fewer
async/error paths, and single ownership of each invariant. It is not a bug hunt:
no new behavior, guards, retries, registries, or validation layers are added.

## Non-Goals

- No new user-facing features and no product behavior changes. Every step must
  preserve observable behavior except where a swallowed failure becomes logged.
- No wire contract changes between client and bridge, no database migrations,
  and no changes to relay framing or crypto layouts.
- No new defensive machinery: no retry frameworks, event buses, universal
  async-state widgets, dedupe caches, or speculative abstractions (see
  Complexity Budget).
- No consolidation of the three approval/pending-input registries' stateful
  implementations (see Deferred Work — reviewer-confirmed contract-only rule
  for `sesori_plugin_interface` plus real policy drift makes promotion unsafe
  without a driving bug).
- No refactoring of `SessionDetailCubit`'s refresh state machine or
  `NewSessionCubit`'s configuration plumbing while the active
  `session-refresh-reconnects` plan is mid-flight on the same files (see
  Deferred Work).
- No decomposition of `acp_plugin.dart` immediately after PR #1013 simplified
  it (see Deferred Work).
- No removal of the desktop control stack — deliberate Phase 2 WIP owned by
  `docs/desktop/PLAN.md` (owner decision recorded below).
- No removal of compatibility paths at or after v1.5.x, and no removal of
  managed-runtime/data-format compat markers whose peer is an on-disk artifact
  rather than a released Sesori surface.

## Owner Decisions Recorded

- **Vagueness waiver (2026-08-21):** after two architecture-plan-review
  rejections citing the same theme — exact Dart types/signatures for the Step 5
  and Step 6 extraction contracts, transport adapter names, the voice-controller
  callback seam, and tooling file paths — the owner explicitly waived deeper
  design detail and approved proceeding as written. Consequence: each
  implementation PR pins its own exact signatures/types at implementation time,
  stays inside the contracts above, and carries its design through
  `architecture-implementation-review`. This decision supersedes the review
  rejections; do not re-review the plan on this basis.
- **Compatibility baseline (2026-08-21):** remove compatibility paths for
  pre-v1.4.0 Sesori releases only (v1.0.9–v1.3.x markers). Keep every v1.5.x+
  marker. Managed-runtime and on-disk-data compat (Codex rollout formats,
  OpenCode runtime events) stay regardless of marker age unless their peer is
  itself a released Sesori surface older than v1.4.
- **Desktop control stack:** keep `ControlChannelServer`,
  `ControlMessageDispatcher`, and the trackers. They are shipped Phase 2
  deliverables of the paused-but-active desktop workstream documented in
  `docs/desktop/PLAN.md`.

## Current Behavior And Findings

### Bridge app (`bridge/app/lib/src/bridge`)

**F1 — Orchestrator owns three jobs in one file (observed).**
`orchestrator.dart` is 2,485 lines. Two regions are cohesive state machines
buried inside orchestration composition and SSE decisions:

- Relay connection/session transport (`orchestrator.dart:1147-1313`,
  `1824-2461`): read/reconnect loop, shutdown close ownership, token refresh
  and identity-triggered reauthentication, wire decoding/key exchange/resume,
  phone incarnations, routed-response encryption/delivery, reconnect backoff,
  send fencing. Its state (`_relayConnection`, `_shutdownRelayCloseFuture`,
  `_backoffJitter`, incarnations, room key) is used almost exclusively by this
  responsibility.
- Plugin-event capture and SSE delivery (`orchestrator.dart:1358-1807`):
  per-plugin ordering tails (`_pluginEventProcessingTails` at `1358-1380` and
  `_projectsSummaryTail` at `1676-1687` duplicate one completer-chain
  pattern), generation fencing checked seven separate times along one event's
  path, history capture, policy decisions, delivery, summary rebuilding.

**F2 — PluginRuntime repeats its command-transition scaffolding three times
(observed drift).** `_stop`, `_prepareDisable`, and `_restart`
(`plugin_runtime.dart:717-1073`) each independently repeat access-gate checks,
force-takeover calculation, conflict checks, transition owner/completer
creation, generation stop, failed-state conversion, and settlement. Concrete
drift: `_prepareDisable` returns early at `plugin_runtime.dart:887` retaining
preparation state, while `_stop`/`_restart` always settle in `finally`.
Each `_PluginRuntimeSlot` also manually tracks three nullable subscriptions
(`statusSubscription`, `workSubscription`, `eventSubscription`) installed at
`1426-1497` and canceled via a temporary list at `1727-1737` instead of the
mandated `CompositeSubscription`.

**F3 — Swallowed failures and interpolated errors (observed).**
`orchestrator.dart:1528` swallows failure-reporter errors with
`.catchError((_) {})` while the same file demonstrates the correct logged
pattern at `1735-1741`. Caught errors are string-interpolated instead of passed
as logger arguments at `orchestrator.dart:869,1516,1723,1829-1848,1985-2003`,
`bridge_event_mapper.dart:184,227`, `sse_manager.dart:201`, and
`maintenance_push_listener.dart:74`. The relay-connect catch
(`orchestrator.dart:963-1036`) wraps `_client.connect()` *and* listener setup,
summary construction, permission approval, and token subscription into one
`throw Exception("failed to connect to relay: $e")`, discarding typed errors
and stack traces and mislabeling non-relay failures. Resume/rekey send failures
and resume-ack framing failures silently continue (`orchestrator.dart:2035-2103`).

**F4 — Redundant delegation layer (verified).**
`default_editor_repository.dart` is a single pass-through method over
`DefaultEditorApi`, violating the explicit "no pointless 1:1 interfaces"
rule; tests fake the repository only because the service depends on it.

**F5 — Abortable-request plumbing repeated (observed).**
`sesori_server_api.dart`, `token_manager.dart`, and
`bridge_registration_api.dart` each hand-roll completer + deadline timer +
`AbortableRequest` + finally-cancel sequences; `_postSessionMetadata` adds a
second abort subscription with repeated `isCompleted` checks.

**F6 — Expired compatibility paths (owner-approved for removal).**
Pre-v1.4 markers verified present: `BridgeIdMigrationService` +
`readLegacyBridgeId` + two startup invocations (v1.3.0),
`legacy_post_update_relaunch.dart` (v1.1.2), `pending_interaction_service.dart`
legacy owner resolution (v1.1.0), `codex_config_reader.dart` fallback reads
(v1.1.2), three `open_code_plugin_descriptor.dart` CLI flag aliases (v1.1.1),
`runtime_start_intent.dart` side-file model/store (v1.0.9). All other markers
(v1.5.1+) stay per the owner decision above.

### Bridge plugins

**F7 — NDJSON subprocess transport exists three times with real drift
(observed).** `acp_stdio_client.dart` (454 lines),
`codex_stdio_app_server_client.dart` (348), and `claude_stream_client.dart`
(407) each independently implement frame writing, line decoding,
pending-request correlation, timeout removal, stale-generation fencing,
fail-all-pending teardown, and process kill sequencing. Verified divergences:
malformed JSON fails all pending Codex requests but is discarded by ACP and
Claude; Claude redacts malformed frames while ACP logs raw content; ACP kills
the process directly and does not close stdin first, Claude closes stdin before
signals, Codex uses `HostProcessService`; error logging styles differ. The
transport mechanics are not backend-specific; only frame classification and
error policy are.

**F8 — Approval/pending-input registry mechanics triplicated with drift
(observed, consolidation deferred).** `acp_approval_registry.dart`,
`codex/approval_registry.dart`, and `claude_approval_registry.dart` repeat
session/project indexing, pending queries, cancel-for-session, and reply
lifecycles with real policy drift (Codex `dispose` silently catches
`_denyPending` at `approval_registry.dart:122-130`; entry-removal timing
relative to backend response differs per family). Only the observability fix
ships in this series; structural consolidation is deferred with reason.

**F9 — Small helpers duplicated across plugin families (observed).**
`_tryNormalizeBase64` byte-identical in ACP/Codex/OpenCode mappers plus a Pi
variant; identical MIME normalization/essence helpers in ACP and Codex; the
managed-install capability decision repeated in five plugin descriptors; GitHub
release URL assembly repeated in five runtime manifests;
`archiveSession`/`deleteWorkspace`/`getChildSessions` implemented as trivial
no-ops/empty lists by multiple plugins without interface defaults (the
interface already uses default methods for `getQueuedPrompts` et al.).

### Client module_core

**F10 — Dead concurrency implementations (verified).**
`ConcurrentCache` (`impl/concurrent_cache.dart`, 55 lines) and `MessageQueue`
(`impl/message_queue.dart`, 97 lines) have zero production consumers; only old
`client/app/test/core/concurrency/*` tests reference them. The isolate pool
itself stays — `dto_parser.dart:17` uses `isolatesPool`.

**F11 — Observability gaps in cubits/services (observed).**
`session_detail_cubit.dart:800-814,1008-1021` swallow failure-reporter errors
with `.catchError((_) {})`; `session_list_cubit.dart:581-585` silently ignores
Git-context refresh failures; interpolated-error logging at
`session_detail_load_service.dart:51-56,80-85,328-334`,
`session_list_cubit.dart:389-459,608-615`, `project_list_cubit.dart:609,797`,
`registered_bridges_service.dart:158-167`, `session_api.dart:258-264`.

**F12 — Layer violation and dead surface (verified).**
`session_list_cubit.dart` imports `../../api/session_api.dart` solely because
`SessionCleanupRejection`/`SessionCleanupRejectedException` are defined there
while the archive/delete flows run cubit → `SessionService`
(`capabilities/session/session_service.dart`) → `SessionRepository` → API.
`SessionDetailLoadResult.isBridgeConnected` is written but never read outside
tests. `GoRouterNavigation` extension (`client/app/lib/core/routing/app_router.dart:245-253`)
has no callers. Twelve barrel exports in `sesori_dart_core.dart` have no
external references. `test_helpers.dart:535-537` declares a dead helper.

**F13 — Manual subscription bookkeeping (observed).**
`session_detail_cubit.dart` (five subscriptions), `plugin_management_cubit.dart`,
and `diff_cubit.dart` track nullable subscriptions by hand while sibling cubits
already use `CompositeSubscription`.

### Client UI shells

**F14 — Visual primitives duplicated across features (observed).**
Centered error/retry states are near-copies in `project_list/widgets/error_view.dart`
and `session_list_content.dart:156-187` with variants in three more screens.
Four modals capture top inset and repeat `showModalBottomSheet` plumbing
(`permission_modal.dart:40-71`, `question_modal.dart:36-64`,
`reasoning_modal.dart:50-74`, `add_project_dialog.dart:24-36`) plus body-cap
math in three of them. `model_picker_sheet.dart` and `command_picker_sheet.dart`
repeat sheet sizing, async filtering, query caching, search-field decoration,
and loading indicators with verified drift (4px vs 8px gap; different
empty-failure presentation).

**F15 — Oversized widgets coordinate unrelated mutable concerns (observed).**
`prompt_input.dart` (1,795 lines) coordinates text editing, paste interception,
attachments, voice recording state machine, gestures, animation, layout, and
navigation from one `State`. `harnesses_settings_screen.dart` (1,172 lines)
repeats drift-prone `isLast` boolean chains across three card sections.
`question_modal.dart` (918 lines) mutates answer-draft controllers, focus
nodes, sets, and disposition fields directly inside widget build state.
`session_detail_message_list.dart` (1,015 lines) mixes detached snapshots/
paging/controller synchronization, row resolution, and a gesture timestamp
machine in one class.

### Tooling

**F16 — CI and installer drift risk (observed).** `bridge-ci.yml` duplicates 12
analyze + 12 test steps that differ only by working directory; adding a package
requires editing both lists. Generated OpenCode client/event outputs have no
CI freshness assertion. `install.sh` supports `GITHUB`/`GITHUB_API` overrides
that `install.ps1` hardcodes past, and stable-version validation differs
(regex vs `[version]::TryParse` accepting four-component versions), so the two
installers can select different releases from identical metadata.

## Design

Design rules for every step: behavior-preserving; smallest change that removes
the duplication/failure point; backend-neutral facts move to neutral homes,
backend-specific policies stay local; no new interfaces beyond what Dart 3
`implements` faking requires; every extracted collaborator owns lifecycle,
state, or an invariant — never extracted merely to shorten a file.

### Step 2 — compatibility removals

Deletes exactly the six F6 items plus their tests, wiring, and startup
invocations:

| Item | Files touched | Peer surface (must be released Sesori ≤ v1.3.x) |
|---|---|---|
| Legacy bridge-id migration | delete `bridge_id_migration_service.dart`; remove `readLegacyBridgeId` from `token.dart`; remove invocations in `bin/bridge.dart` + `bridge_runtime_runner.dart` + tests | token.json written by installs ≤ v1.3.x |
| Post-update relaunch marker | empty `legacy_post_update_relaunch.dart`; remove consumers | environment set by pre-v1.1.2 updater binary |
| Rejection sessionId omission fallback | `pending_interaction_service.dart` legacy owner-resolution branch | clients ≤ v1.0.x omitting sessionId |
| Codex config fallback reads | `codex_config_reader.dart` fallback branches + call sites | VERIFY: only if peer is released-Sesori-era data, not live rollout format — otherwise keep with reason |
| OpenCode CLI flag aliases ×3 | `open_code_plugin_descriptor.dart` alias branches | user scripts predating namespaced flags (introduced v1.1.1) |
| RuntimeStartIntent side-file model/store | `runtime_start_intent.dart` side-file classes + store | bridges ≤ v1.0.8 sharing a data directory |

Each marker gets a one-line verification note in the `TRACKER.md` ledger. If a
marker fails the peer check during implementation, it stays and the reason is
recorded — the step shrinks honestly instead of forcing removals.

### Step 3 — bridge observability and layer sweep

All changes inside `bridge/app`:

1. **Failure-reporter swallow:** `orchestrator.dart:1528` adopts the existing
   logged pattern from `1735-1741` (typed catch, `Log.w("msg", error, stack)`).
   Same treatment for resume/rekey/framing silent paths (`2035-2103`) with
   connection IDs retained.
2. **Logger args:** replace every interpolated `${error}`/`${e}` citation in F3
   with `Log.w/<logger>("context", error, stackTrace)`; message keeps IDs and
   operation context, never the payload.
3. **Relay-connect catch:** narrow the `catch` around `_client.connect()`;
   post-connect setup steps get their own typed failures; the connect rethrow
   becomes a typed wrapper carrying `innerError` + original stack trace.
4. **Delete `DefaultEditorRepository`:** move `openFile(String)` into
   `BridgeSettingsRepository` as `openInDefaultEditor(...)` wrapping the same
   `DefaultEditorApi` (the repository already owns config-file lifecycle:
   `ensureConfigExists`, `configFilePath`). `BridgeConfigService` drops the
   second dependency and calls the settings repository. Layering preserved:
   API → Repository → Service. Delete the repository file, its DI registration
   in `bin/bridge.dart`, and its test fake.
5. **Abortable-request helper:** new final class `AbortableRequestSender` in
   `sesori_bridge_foundation/lib/src/http/abortable_request_sender.dart`
   (foundation is the documented home for bridge-wide transport primitives;
   `bridge/app` already depends on it, so no new edges). Single method
   `Future<http.StreamedResponse> send({required http.Client client, required http.AbortableRequest request, required Duration deadline, Stream<Object>? abortSignal})`
   owning the deadline timer, external-abort subscription, and one finally-path
   cleanup. Callers keep status handling and retry policy: `SesoriServerApi`
   (including `_postSessionMetadata`'s merged cancellation), `TokenManager`,
   `BridgeRegistrationApi`.

### Step 4 — PluginRuntime command transitions

One private transition skeleton inside `plugin_runtime.dart` owning gate checks,
takeover calculation, conflict validation, owner/completer acquisition,
generation stop, failed-state conversion, and settlement;
`_stop`/`_prepareDisable`/`_restart` become small outcome-specific bodies whose
differences (including the disable early-return retaining preparation state)
are explicit against one shared path. Each `_PluginRuntimeSlot` gains one
`CompositeSubscription` per generation, recreated at generation start and
canceled once at teardown, replacing the three nullable fields and temporary
cancel list. Operation-stream callback futures stay separate (they are not
subscriptions). No public API changes.

### Step 5 — RelayConnectionCoordinator extraction

New file `bridge/app/lib/src/bridge/relay_connection_coordinator.dart`.

**Class contract:**

- `final class RelayConnectionCoordinator` — owns exactly one invariant: the
  bridge's relay session lifecycle.
- **Constructor dependencies (all required):** relay connect factory/client,
  account/room identity source, token refresher + identity-change stream,
  session key material provider (room key), phone-incarnation registry,
  reconnect policy (base/jitter), shutdown signal, failure reporter.
- **Owned state (moved, not new):** current connection, shutdown-close future,
  backoff jitter, incarnation fencing state, room key cache.
- **Inbound seam:** exposes `Stream<RelayInbound>` — sealed variants for
  routed request contexts, control messages, and resume outcomes. Consumed by
  `OrchestratorSession`, which keeps request routing and all SSE decisions.
- **Outbound seams:** `sendResponse(...)`, `sendEventFrame(...)`,
  `requestRekey()` — accept typed payloads, own encryption/framing/send-fencing
  internally. Never emits SSE; never touches plugin or database layers.
- **Lifecycle:** constructed by the composition root, started by
  `OrchestratorSession.start`, disposed inside the existing teardown sequence
  before the shared HTTP client closes; internal subscriptions held on one
  `CompositeSubscription`.
- **Dependency direction:** orchestrator → coordinator (downward); coordinator
  depends only on transport/crypto/token primitives.

**Composition root:** graph assembly moves out of orchestration code into
`bridge/app/lib/src/bridge/orchestrator_composition.dart` — a factory building
the object graph (repositories, APIs, push subsystem, services, listeners,
route handlers, session collaborators) and returning it as a typed structure
consumed by `Orchestrator.create`. `Orchestrator.create` becomes thin startup
sequencing; `OrchestratorSession` receives the coordinator instead of the ~15
scattered relay/session fields.

Shutdown ordering remains sequenced in `OrchestratorSession._teardown` exactly
as today; the coordinator adds no new ordering rules.

### Step 6 — plugin-event delivery pipeline extraction

New file `bridge/app/lib/src/bridge/plugin_event_delivery_pipeline.dart`.

**Class contract:**

- `final class PluginEventDeliveryPipeline` — Orchestrator-owned collaborator
  (child of `OrchestratorSession`, never a global service). Owns one invariant:
  ordered, generation-valid capture-to-delivery of normalized plugin events.
- **Constructor dependencies (required):** runtime/plugin lookup, event mapper,
  history service, unseen-event/project-activity collaborators, permission
  policy, failure reporter.
- **Owned state (moved):** per-plugin serial tails, projects-summary tail,
  pending part captures — the two duplicated completer-chain implementations
  collapse onto one private `_SerialTails` keyed executor defined in the same
  file (single consumer, stays private).
- **Outbound seam:** exposes `Stream<OutboundSseDelivery>`; `OrchestratorSession`
  subscribes and forwards to the SSE manager. Push-based per repo rules; the
  Orchestrator remains the sole SSE decision owner and emitter boundary.
- **Generation fences:** each await boundary inside the pipeline is labeled
  with the validity check it requires. No existing check is deleted in this
  step; pruning provably redundant checks may happen later only with a tracker
  note naming the await boundary that makes each removed check dead.
- **Lifecycle:** constructed by the composition root; drained by
  `OrchestratorSession._teardown` at exactly today's position (before
  normalized-output cancellation), then disposed.

### Step 7 — shared NDJSON subprocess transport

**Home decision:** `sesori_plugin_runtime/lib/src/transport/ndjson_process_transport.dart`.
Rationale: `sesori_plugin_runtime` is the plugin-only process-infrastructure
package (supervision today; framed subprocess transport is the same audience);
`sesori_plugin_interface` must stay contract/foundation-only (review constraint),
and `sesori_bridge_foundation` is for primitives shared with the main app, which
this is not. `sesori_plugin_acp` and `sesori_plugin_claude` gain a pubspec
dependency on `sesori_plugin_runtime` (direction stays downward:
plugins → runtime → interface/foundation; Codex already depends on runtime);
`bridge/AGENTS.md`'s module-order list is updated in the same PR.

**Class contract:**

- `final class NdjsonProcessTransport` — one framed request/response channel
  over a subprocess's stdio.
- **Process abstraction:** minimal `NdjsonProcessHandle` interface declared in
  the same file (stdin sink, broadcast stdout line stream, done future, kill)
  with thin adapters mapping each plugin's existing handle types onto it.
- **Policy via values, not callbacks:** constructor takes
  `MalformedFramePolicy {discard, failPending}` (ACP/Claude discard, Codex fail
  all pending), `redactMalformedFrames` flag (Claude true, others false), and
  `logTag`. Request timeout duration is a method argument.
- **API:** `Future<Map<String, dynamic>> request(Map<String, dynamic> envelope, {required Duration timeout})`
  correlating IDs through an internal pending map with timeout removal;
  `Stream<Map<String, dynamic>> notifications` for protocol-specific inbound
  lines the owning plugin interprets; `dispose({required String reason})`
  failing all pending, closing stdin, waiting briefly, terminating, then
  force-killing. Stale-generation callbacks are fenced internally via a
  generation counter bumped by `attach(NdjsonProcessHandle)`.
- **Preserved divergences:** frame classification, notification semantics,
  redaction, and malformed-policy remain explicit caller choices — nothing is
  unified by accident.
- **One intended unification, recorded:** teardown order becomes close-stdin →
  short drain wait → terminate → timed force-kill for all three adopters (ACP
  currently skips the stdin-close). Teardown-only, observable solely in process
  exit timing/logs; recorded in `TRACKER.md` as an accepted behavior delta.
- Optional stretch within the same diff budget: converge the ACP/Claude/Pi
  process-handle wrappers onto `HostProcessService` where their fakes prove
  interchangeable; skipped if it inflates the diff past target.

### Step 8 — plugin shared-primitive batch

Exact homes, signatures, and affected implementors:

| Primitive | Exact home | Consumers migrated |
|---|---|---|
| Base64/MIME normalization | `sesori_plugin_interface/lib/src/messages/attachment_normalization.dart`: pure top-level functions `String? tryNormalizeBase64(String)`, `String? normalizeMimeValue(String?)`, `String mimeEssence(String)` beside existing attachment validators (interface stays pure/contract-grade — no state, no I/O) | `acp_content_mapper.dart`, `codex_image_attachment_mapper.dart`, `message_part_mapper.dart` (OpenCode); Pi variant adopted only if byte-equivalent semantics, else left with a tracker note |
| Descriptor install capability | `sesori_plugin_runtime/lib/src/provisioning/descriptor_install_policy.dart`: pure function taking manifest, resolved explicit-binary path, platform target → capability set | descriptors of OpenCode, Codex, Cursor, OMP, Pi; setup-hint strings stay plugin-local |
| Release asset URL | default member on the existing manifest base in `sesori_plugin_runtime/lib/src/provisioning/runtime_manifest.dart`: `Uri releaseAssetUrl({required String assetName})` using each manifest's publisher/repo/tag fields | all five manifests delete private URL builders; any manifest with differing tag convention overrides and notes why |
| Unsupported-op defaults | default members on `BridgePluginApi` in `sesori_plugin_interface`: `archiveSession` no-op, `deleteWorkspace` no-op, `getChildSessions` → `const []` (matches existing default-method precedent) | trivial overrides deleted wherever the analyzer proves them redundant (known: Claude, Pi, ACP) |
| Contract documentation | doc comments on `BridgePluginApi` question/permission methods stating pending-input lifecycle expectations (reply/dispose/cancel must resolve or log) | interface-only documentation |
| Codex observability fix | `sesori_plugin_codex/lib/src/approval_registry.dart:122-130`: silent catch logs like ACP/Claude | Codex-local |

### Step 9 — module_core sweep

1. Delete `ConcurrentCache`/`MessageQueue` impls and orphaned
   `client/app/test/core/concurrency/*` tests; isolate pool untouched.
2. Delete `GoRouterNavigation`; delete dead `testHealthResponse` helper.
3. Prune the twelve unused barrel exports; delete underlying implementations
   only where a full-workspace grep plus DI/generated-config check proves
   orphanhood, else export-only removal.
4. Remove `SessionDetailLoadResult.isBridgeConnected` (field + test usage).
5. **Cleanup-rejection layering fix (exact flow):** `session_api.dart` keeps a
   private DTO parse of the 409 body and throws its API-layer
   `SessionCleanupRejectedException` carrying that DTO; `SessionRepository`
   catches it and maps DTO → domain model `SessionCleanupRejection` defined in
   new file `client/module_core/lib/src/capabilities/session/session_cleanup_rejection.dart`
   beside the domain exception it rethrows; `SessionService` passes through;
   `session_list_cubit.dart` deletes its API import and consumes only the
   capabilities-layer type.
6. Catch/logging fixes mirroring Step 3 patterns (F11 citations).
7. `CompositeSubscription` adoption in `session_detail_cubit`,
   `plugin_management_cubit`, `diff_cubit`.

### Step 10 — Prego primitive consolidation

Single chosen design per primitive (no alternatives):

1. `PregoCenteredStatus` — new file
   `client/module_prego/lib/components/status/prego_centered_status.dart`;
   required title, optional message, icon, action label/callback, semantics
   config. Consumers migrated in the same PR: `error_view.dart`,
   `session_list_content.dart`, `add_project_dialog.dart`,
   `diff_error_view.dart`, `session_detail_scaffold_sections.dart`.
2. `showPregoBottomSheetRoute(...)` — lower-level presenter added to
   `client/module_prego/lib/components/surfaces/prego_bottom_sheet.dart`,
   owning top-inset capture, scroll-control, transparency, safe-area-off, and
   height caps; the existing `showPregoBottomSheet` refactors to build on it.
   Consumers migrated: `permission_modal.dart`, `question_modal.dart`,
   `reasoning_modal.dart`, `add_project_dialog.dart`; body-cap duplication in
   three modals replaced by the route's cap support.
3. `PregoSearchablePickerBody<T>` — new file
   `client/module_prego/lib/components/pickers/prego_searchable_picker_body.dart`;
   bounded height, async filter slot, query caching, search field, loading and
   empty presentation. Consumers: `model_picker_sheet.dart`,
   `command_picker_sheet.dart` (domain builders and localized labels stay in
   app; the 4px/8px gap and empty-failure drift unify on the Prego defaults).

Feature state switches and sliver wrappers stay local; no universal
async-state widget.

### Step 11 — app-widget state-owner splits

All collaborators are feature-local presentation-state owners created and
disposed by their widget `State`; none imports services, repositories, APIs,
or cubits; business orchestration stays in cubits (BLoC/Cubit and thin-shell
rules intact — these own ephemeral UI invariants only):

| Collaborator | File | Owns | Left behind |
|---|---|---|---|
| `PromptVoiceController` | `client/app/lib/features/session_detail/widgets/composer/prompt_voice_controller.dart` | recording state machine, pointer tracking, transcription-call lifecycle, cancellation, haptics triggers; rebuild signaling via injected callback | visual hold-to-talk widget, composer layout |
| `PromptAttachmentStaging` | same folder, `prompt_attachment_staging.dart` | staged attachment list, paste interception results, initial-attachment copy-once + consumed acknowledgement | attachment strip rendering |
| `_QuestionDraftController` | private class in `question_modal.dart` | drafts, selection sets, page index/navigation, answer conversion, controller disposal | option tiles, decline-confirm UI |
| `_MessageListSynchronizer` | private class in `session_detail_message_list.dart` | detached snapshots, paging completion, controller synchronization, transient-submission handoff | row resolution, gesture timestamp machine (untouched) |
| Ordered-row builder | private function in `harnesses_settings_screen.dart` | builds visible harness rows as one list; `isLast` derives from position | screen shell, sheets moved to separate private widget files in the same feature folder |

Public widget facades and constructor signatures do not change; screens and
cubits are untouched except imports if files move.

### Step 12 — tooling

1. `.github/workflows/bridge-ci.yml`: one checked-in package list drives
   analysis and test loops preserving per-package output and fail-fast.
2. Codegen freshness job: regenerate OpenCode generated client/event outputs
   from committed schema/manifest inputs and fail on diff (network-based
   acquisition excluded from CI).
3. `install.ps1` gains `$env:GITHUB`/`$env:GITHUB_API` handling and exact
   three-component stable-version validation matching `install.sh`.
4. Fixture-driven parity tests (extending `bridge/app/test/tool/installers_test.dart`)
   covering release selection/order, partial releases, checksum parsing,
   archive/checksum URL construction (including env overrides), and manifest
   writing for both scripts.

### Step 13 — documentation reconciliation

Wording/boundary reconciliation only, of the documents listed under Regression
Documentation. No coverage reductions.

### Step 14 — verification and retirement

Run the recorded L2 matrix, record evidence and any Partial/Blocked rows
honestly in `TRACKER.md`, then move the plan to `.plan/completed/`. Any
required row that cannot run keeps the plan active per
`docs/regression/README.md`.

## Complexity Budget

### Mutable parts removed

- Three copies of plugin command-transition bookkeeping → one skeleton;
  −3 nullable subscription fields per slot via composites;
- Two duplicated serial-tail implementations → one private keyed executor;
- Relay/session state scattered across ~15 `OrchestratorSession` fields →
  moved (not added) into one coordinator;
- Three drifted NDJSON transports → one shared implementation (net −2
  stateful classes);
- Dead `ConcurrentCache`/`MessageQueue`, dead navigation extension, unused
  exports, `DefaultEditorRepository`, six legacy compat paths, orphaned tests;
- N hand-rolled deadline-timer/abort-subscription pairs → one stateless-per-
  call sender (timers go down, not up).

### Mutable parts added (each justified)

- `RelayConnectionCoordinator`: owns state that already existed, giving relay
  lifecycle exactly one owner;
- `PluginEventDeliveryPipeline` + private `_SerialTails`: same — owns existing
  tails/captures; one outbound stream replaces scattered inline emission;
- `AbortableRequestSender`: stateless per call;
- `NdjsonProcessTransport` + `NdjsonProcessHandle`: one stateful class plus a
  thin interface replacing three drifted ones;
- Three Prego primitives: presentation-only, stateless or timer-scoped,
  replacing five+ drifted copies;
- Four app-local widget-state controllers: move existing mutable state out of
  monolithic `State` classes; net field count does not grow.

### Deliberately not added

No retry framework, no event bus, no universal async-state widget, no installer
code generation, no new DI scopes, no interface for the coordinator/pipeline/
controllers beyond what tests need (`implements` works), no locks/registries/
watchers anywhere, no telemetry, no approval-registry base class.

If implementation reveals an extraction needs a new persistent queue,
cross-owner lock, or second stream, stop and ask before expanding scope.

## Delivery Plan

| Step | Exact PR title | Target | Scope |
|---|---|---|---|
| 1/14 | `🌱 [reliability-cleanup] docs: plan the reliability cleanup series [step 1/14]` | plan + tracker | Raise reviewed plan only. |
| 2/14 | `⚙️ [reliability-cleanup] refactor: drop pre-v1.4 compatibility paths [step 2/14]` | 150-350 lines | Six F6 removals with per-marker peer verification; keep v1.5.x+. |
| 3/14 | `🌿 [reliability-cleanup] fix(bridge): make swallowed failures observable [step 3/14]` | 150-300 lines | F3/F4/F5: logging fixes, relay-connect error preservation, settings-repository fold, `AbortableRequestSender`. |
| 4/14 | `⚙️ [reliability-cleanup] refactor(bridge): unify plugin command transitions [step 4/14]` | 150-300 lines | Transition skeleton + slot composite subscriptions (F2). |
| 5/14 | `🚧 [reliability-cleanup] refactor(bridge): extract the relay connection coordinator [step 5/14]` | 1,200-2,000 changed (mostly relocation) | Step 5 design incl. composition root. |
| 6/14 | `🚧 [reliability-cleanup] refactor(bridge): extract the plugin-event delivery pipeline [step 6/14]` | 700-1,300 changed (mostly relocation) | Step 6 design; label fences; delete none without proof. |
| 7/14 | `🚧 [reliability-cleanup] refactor(plugins): share the ndjson subprocess transport [step 7/14]` | 600-1,100 lines | Step 7 design; acp/claude gain runtime dep; AGENTS.md order update. |
| 8/14 | `🌿 [reliability-cleanup] refactor(plugins): consolidate shared plugin primitives [step 8/14]` | 300-550 lines | Step 8 table: helpers, descriptor policy, URLs, interface defaults, contract docs, Codex log fix. |
| 9/14 | `🌿 [reliability-cleanup] refactor(client): remove dead code and fix observability [step 9/14]` | 250-500 lines | F10-F13 incl. cleanup-rejection layering flow. |
| 10/14 | `⚙️ [reliability-cleanup] feat(ui): consolidate sheet, status, and picker primitives [step 10/14]` | 500-900 lines | Step 10 designs + full consumer migration. |
| 11/14 | `⚙️ [reliability-cleanup] refactor(app): split state-heavy composer and settings widgets [step 11/14]` | 900-1,400 changed (mostly relocation) | Step 11 collaborator table. |
| 12/14 | `🌿 [reliability-cleanup] chore(tooling): tighten CI, codegen freshness, installer parity [step 12/14]` | 200-450 lines | F16 items. |
| 13/14 | `🌱 [reliability-cleanup] docs: reconcile regression coverage [step 13/14]` | 80-200 lines | Penultimate reconciliation; cleanup audit vs actual merges. |
| 14/14 | `🌿 [reliability-cleanup] test: verify the reliability cleanup series [step 14/14]` | 60-200 lines | Run recorded L2 matrix, record evidence, retire plan. |

Notes: Steps 5-7 and 11 will exceed the 1,500-line soft cap counting pure
relocations (moved lines count twice). The overage is mechanical movement of
existing code behind new seams, not new logic; review focus is the seam
definition and preserved policies. If any other step exceeds its target,
prefer splitting tests by owner over widening scope. Bridge and client
production work never combine in one PR. Step titles carry fixed complexity
emoji chosen now; if evidence changes an estimate before opening, update
plan/tracker rather than publishing a stale rating.

## Per-Step Verification

Every step: `dart analyze --fatal-infos` in each touched module plus the owning
packages' focused tests. Additional, per step:

- **2:** removed tests deleted with paths; headless bridge start proves
  registration/minting works without migration reads; tracker ledger complete.
- **3:** orchestrator/mapper/listener suites green; config-service test fakes
  the API directly through the settings repository; sender unit tests cover
  deadline, external abort, and cleanup-without-leak.
- **4:** plugin runtime/lifecycle suites prove stop/disable/restart outcomes
  and settle semantics unchanged, including the disable early-return.
- **5-6:** orchestrator/runtime/SSE suites green without assertion changes;
  changed tests may alter wiring only; shutdown-ordering tests prove drain
  order intact; pipeline stream consumed exactly as the old inline emission.
- **7:** each adopting plugin's protocol suites prove identical frame/error
  semantics (Codex fail-all-on-malformed, Claude redaction, ACP discard);
  fake-process round-trips cover timeout, broken pipe, stale generation, kill
  ordering; teardown-order delta asserted intentionally.
- **8:** mapper/descriptor unit tests prove identical normalization outputs and
  capability decisions across all five descriptors; analyzer proves removed
  overrides were trivially redundant.
- **9:** module_core + app suites green; grep proves deleted symbols unreferenced;
  analyzer/config check proves the cubit no longer imports the API package.
- **10:** widget tests for migrated sheets/pickers/statuses prove layout,
  keyboard, safe-area, and empty/failure presentations unchanged.
- **11:** existing prompt-input/harness/question/message-list suites green;
  controller-level tests only where they add confidence (voice race, draft
  restore, paging handoff).
- **12:** CI dry-run produces identical per-package commands; freshness job
  fails when an output is dirtied locally; parity tests prove identical
  URL/checksum/manifest decisions from shared fixtures including PS1 overrides.
- **13/14:** docs reconcile cleanly against merged diffs; matrix evidence
  recorded in the tracker.

## Regression Documentation And Final Matrix

Affected feature documents (Step 13 reconciles):

- `docs/regression/plugin-setup-and-lifecycle.md` — descriptor install-policy
  consolidation, command-transition unification, `runtime_start_intent` cleanup;
- `docs/regression/questions-and-permissions.md` — pending-input contract
  documentation, Codex disposal logging;
- `docs/regression/attachments-and-images.md` — shared base64/MIME helper home;
- `docs/regression/session-turns.md` — event-delivery pipeline ownership;
- `docs/regression/bridge-connectivity.md` — relay coordinator ownership,
  unchanged reconnect/resume semantics;
- `docs/regression/bridge-installation-and-updates.md` — installer env override
  parity, version-validation alignment;
- `docs/regression/voice-input.md` — composer voice-controller extraction;
- `docs/regression/navigation-transitions.md`, `popup-alerts.md`,
  `design-catalog.md` — new Prego primitives and modal-route ownership.

### Highest required level

**L2 Routine.** The series claims no user-visible behavior change; delivered
behaviors are internal refactors proven through automated boundaries, plus
consolidated UI components and plugin transport whose complete invariant needs
one live pass. L3's production-plugin enumeration would re-prove unchanged
behavior; skipping it is justified because no step changes any declared
capability. Any reduction concern should be raised at plan review.

### Required matrix (recorded for Step 14)

- **Automated:** full analyze + test suites green for every touched package
  (CI-enforced; recorded here).
- **Headless bridge:** start the bridge; exercise plugin stop/disable/restart
  transitions and graceful shutdown drain (Steps 4-6 surfaces).
- **Live plugin:** one ACP-family plugin (Cursor, OMP, or Hermes), plus Codex
  and Claude: create a session, exchange turns, answer one question/permission
  prompt, archive or delete where supported (Steps 7-8 surfaces).
- **Client end to end:** release-target phone: open a session detail, send a
  prompt, present permission + question modals, filter and select via model and
  command pickers, render one error/retry state, record and submit one voice
  input (Steps 10-11 surfaces).
- **Packaged/external:** `install.sh` on macOS and `install.ps1` on Windows
  complete a real or fixture-served install (Step 12 surfaces).

Compatibility rows: none newly claimed; the codegen freshness job asserts no
wire-shape diffs (Step 12).

## Risks And Accepted Limits

- **Orchestrator extraction regressions** (Steps 5-6) threaten reconnect/resume
  and SSE ordering — the highest-stakes risk in the series. Mitigation: pure
  moves, existing lifecycle/SSE suites as the safety net, shutdown ordering
  left sequenced in `OrchestratorSession`, one extraction per PR so bisect
  stays trivial.
- **Transport consolidation** could silently change per-plugin error semantics.
  Mitigation: policies ported explicitly as constructor values with named
  tests; the single intentional teardown-order delta is recorded.
- **Compat removals** assume the owner-set baseline (pre-v1.4 unsupported).
  Per-marker peer verification prevents deleting on-disk-data compat that old
  managed runtimes still need.
- **Widget splits** can break subtle gesture/focus/animator behavior.
  Mitigation: facade signatures unchanged; existing widget suites gate; manual
  L2 checklist covers voice and modals.
- **Accepted limits:** known duplication judged not worth consolidating is left
  alone (approval-registry internals, Claude/Pi queue-emission twins,
  `SessionEncryptor` wrapper, oversized but cohesive Codex/Pi internals,
  pure-delegation client repositories required by the layering rule). Deferred
  items below are recorded, not forgotten.

## Deferred Work

- **Approval-registry consolidation:** the three registries are stateful with
  real policy drift; `sesori_plugin_interface` is contract/foundation-only, and
  no neutral stateful home fits without expanding a package mandate. Revisit
  only with a concrete bug or a purpose-built shared home.
- **`SessionDetailCubit` refresh-state machine + snapshot reducer,
  `NewSessionCubit` configuration object:** blocked by the active
  `session-refresh-reconnects` plan working the same files evidence-first.
  Revisit once that plan concludes.
- **`acp_plugin.dart` internal decomposition:** deferred; PR #1013 just
  simplified the ACP base and cursor/omp/hermes should stabilize first.
- **`MessageImageRepository` simplification:** security-sensitive machinery;
  simplifying requires targeted evidence that registries overlap, which
  investigation did not establish.
- **Desktop control stack wiring/removal:** owned by `docs/desktop/PLAN.md`.
- **Image-viewer promotion to `module_prego`:** speculative until a second
  consumer exists.
