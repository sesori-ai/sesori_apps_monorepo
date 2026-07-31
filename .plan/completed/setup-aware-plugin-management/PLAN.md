# Setup-Aware Plugin Management

## Status

- **Plan slug:** `setup-aware-plugin-management`
- **Parent plan:** `.plan/completed/setup-aware-plugin-lifecycle`
- **Status:** complete; P01-P06 merged and frozen PR #510 closed as superseded
- **Completion base:** `origin/main` at final Stage 12 merge `6cedf5bd`
- **Reference only:** PR #510, substantive commit `c4104e73`, fixture follow-up
  `bf0433b8`

This child plan owns the replacement delivery sequence for parent Stage 12. It
inherits the parent's locked product decisions and final architecture. Frozen
PR #510 is evidence, not mergeable history: no replacement branch rebases,
merges, or cherry-picks it.

## Goal

Deliver observable attach-only residency and the complete headless plugin
management seam in six independently reviewable PRs. Each merged slice is
useful on its own, preserves existing client behavior, and leaves no temporary
public contract that a later slice must break.

## Locked Boundaries

- Backend-specific configuration interpretation stays in the owning plugin
  descriptor. Bridge core consumes only generic residency/setup/runtime state.
- `BridgeSettingsRepository` remains the only JSON settings owner. Runtime-only
  residency policy never rewrites a user's default or per-plugin timeout.
- Management transport additions remain backward/forward compatible across app
  and bridge versions. Internal Dart interfaces update all repository consumers
  in lockstep and receive no compatibility shims.
- `PluginRuntime` owns mechanics; `PluginLifecycleRepository` maps them;
  `PluginLifecycleService` owns policy, persistence sequencing, management
  snapshots, and change tokens; handlers only parse/map HTTP; `Orchestrator` alone
  emits SSE.
- The existing `PluginCatalogHydrationListener` remains the only automatic
  hydration trigger. Management code widens its ready-ID input rather than
  creating a second trigger.
- Current-main durable commit, stream cancellation, generation fencing,
  OpenCode-preferred default, and bridge-owned project behavior are preserved.
- Keep exactly one open PR and one local successor branch. While step N is in
  review, build step N+1 from its latest reviewed head but do not open N+1.
- After step N merges, merge updated `origin/main` into the local N+1 branch,
  resolve conservatively, reverify, and only then open N+1. Start N+2 locally
  after N+1 opens; never build farther than one successor ahead.

## Delivery Sequence

| Step | Branch | Exact PR title | Review boundary |
|---|---|---|---|
| 1/6 | `setup-aware-plugin-management-resident-attach` | `[setup-aware-plugin-management] fix(bridge): keep attach-only plugins resident [step 1/6]` | Generic residency declaration, OpenCode mapping, effective timeout `0`, and start/stop diagnostics. |
| 2/6 | `setup-aware-plugin-management-read-snapshots` | `[setup-aware-plugin-management] feat(bridge): expose plugin management snapshots [step 2/6]` | Shared read DTOs and read-only GET route. |
| 3/6 | `setup-aware-plugin-management-invalidation` | `[setup-aware-plugin-management] feat(bridge): invalidate plugin management snapshots [step 3/6]` | Opaque snapshot tokens and additive SSE invalidation. |
| 4/6 | `setup-aware-plugin-management-idle-timeouts` | `[setup-aware-plugin-management] feat(bridge): update plugin idle timeouts live [step 4/6]` | Typed timeout writes, settings serialization, and live timer resync. |
| 5/6 | `setup-aware-plugin-management-disable` | `[setup-aware-plugin-management] feat(bridge): add transactional plugin disable [step 5/6]` | End-to-end safe/force disable with runtime access gates and durable commit/rollback. |
| 6/6 | `setup-aware-plugin-management-commands` | `[setup-aware-plugin-management] feat(bridge): add remaining plugin lifecycle commands [step 6/6]` | Enable/restart/refresh, setup fencing, and dynamic default/catalog eligibility. |

## Stage 12-P01: Attach-Only Residency

Add `PluginResidencyPolicy { transient, resident }` to
`sesori_plugin_interface`.
`BridgePluginDescriptor.residencyPolicy({required PluginConfig config})` is pure
and defaults to `transient`. `OpenCodePluginDescriptor` returns
`resident` exactly when validated config has `no-auto-start`; all other bundled
plugins retain the default.

`BridgeRuntimeRunner` evaluates that descriptor-owned policy and includes it in
the immutable registered metadata passed to `PluginLifecycleService`. The
service centralizes effective timeout calculation:

```text
resident descriptor policy -> effective idle timeout 0
otherwise -> plugin override -> default override -> hardcoded 10
```

The settings object is never changed by this read-time override. Therefore a
user can leave an explicit timeout configured, run attach-only temporarily, and
recover the same configured value when returning to managed mode. Existing
timer cancellation follows automatically because non-positive effective values
cannot schedule an idle timer.

Add runtime-level debug diagnostics that identify plugin and generation for
start attempt/success and command stop begin/success. Add idle-policy diagnostics
for timer expiry and applied/current/conflict/failure outcomes. Warning/error
paths that already surface failures remain single-logged.

Production files:

- `bridge/sesori_plugin_interface/lib/src/lifecycle/plugin_residency_policy.dart`
- `bridge/sesori_plugin_interface/lib/src/lifecycle/bridge_plugin_descriptor.dart`
- `bridge/sesori_plugin_interface/lib/sesori_plugin_interface.dart`
- `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_plugin_descriptor.dart`
- `bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart`
- `bridge/app/lib/src/bridge/runtime/plugin_runtime.dart`
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`

## Stage 12-P02: Read-Only Snapshots

Add shared read types only: forward-safe runtime/work enums,
`PluginManagementMetadata`, and `PluginManagementResponse`. The first response
contains nullable derived default ID, configured default timeout, and every
registration in deterministic display-name/ID order. Each row contains setup,
runtime/work state, effective timeout, whether a persisted per-plugin override
exists, and a sanitized action hint. Resident policy reports effective timeout
`0` while retaining the persisted-override boolean.

`PluginLifecycleService.managementSnapshot` maps existing lifecycle and settings
state without adding mutation state. `Orchestrator.create` registers
`GetPluginManagementHandler(lifecycleService: _pluginLifecycleService)` once in
the existing `RequestRouter.handlers` list. `BridgeRuntimeRunner` continues to
give `DebugServer` the resulting `BridgeRuntime.session.router`, so relay and
debug requests use the same router and service instance. The GET never probes,
starts, stops, or writes.

Production files:

- `shared/sesori_shared/lib/src/models/sesori/plugin_management.dart` and barrel
- generated Freezed/JSON companions from that source
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`
- `bridge/app/lib/src/routing/get_plugin_management_handler.dart`
- `bridge/app/lib/src/bridge/orchestrator.dart`
- `bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart`

## Stage 12-P03: Snapshot Tokens And Invalidation

Add `required String? snapshotToken` to `PluginManagementResponse`, with
`// COMPATIBILITY 2026-07-25 (v1.6.1): Stage 12-P02 and older bridge payloads
omit snapshotToken; null means that peer cannot identify snapshot changes. Make
non-null when those bridge versions are unsupported.`, and add the
`plugin.management.changed` variant to `SesoriSseEvent`. The lifecycle service
retains one plain `PluginManagementResponse` as its last published snapshot and
owns a broadcast `StreamController<String>` as the only management change
stream. It generates a random 128-bit base64url token for the initial complete
snapshot and each materially changed public snapshot. Comparison reuses the
previous token to ignore snapshot identity, then caches the changed response
with its new token before synchronously emitting that token.

Every externally visible runtime/setup/work transition is independently
queryable and invalidated. One plugin's in-progress transition does not suppress
another plugin's public change, and a transient state can never remain paired
with an older token. `managementSnapshot` remains the cached synchronous GET
value, so each returned token identifies exactly that returned content; there is
no unused `managementSnapshots` stream.

`Orchestrator.create` passes
`PluginLifecycleService.managementSnapshotTokens` into `OrchestratorSession`.
The session subscribes in its constructor, maps each value to
`SesoriSseEvent.pluginManagementChanged(snapshotToken: snapshotToken)`, and adds
the subscription to its existing `_subscriptions` composite. The existing
`_subscriptions.cancel()` in `OrchestratorSession.run` disposes it before the
lifecycle service is closed. No lower layer emits SSE.

The additive client variant is globally scoped and ignored by existing session
consumers. Update every exhaustive switch in exactly these source files:

- `client/module_core/lib/src/capabilities/server_connection/models/sse_event.dart`
  maps it to null session ID;
- `client/module_core/lib/src/services/sse_event_tracker.dart` ignores it;
- `client/module_core/lib/src/cubits/session_list/session_list_cubit.dart`
  ignores it; and
- `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`
  ignores it in both global relevance and global processing switches.

No management API, service, cubit, DI, or UI enters this slice.

Production files:

- `shared/sesori_shared/lib/src/models/sesori/plugin_management.dart`
- `shared/sesori_shared/lib/src/models/sesori/sesori_sse_event.dart`
- generated `plugin_management.freezed.dart`, `plugin_management.g.dart`,
  `sesori_sse_event.freezed.dart`, and `sesori_sse_event.g.dart`
- `shared/sesori_shared/test/models/plugin_management_contract_test.dart` and
  `shared/sesori_shared/test/models/sesori_sse_event_test.dart`
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`
- `bridge/app/lib/src/bridge/orchestrator.dart`
- the four named `client/module_core` source files above

## Stage 12-P04: Live Timeout Mutations

Add the sealed apply-all, set-override, and clear-override requests with strict
integer decoding. `PatchPluginIdleTimeoutHandler` parses the generated request,
validates known IDs through `PluginLifecycleService.updateIdleTimeout`, and maps
bad input to 400, unknown IDs to 404, and failed writes to 500. The service owns
one `_settingsMutationTail`; each operation enters that tail, calls
`BridgeSettingsRepository.loadSettings()`, derives one new `BridgeSettings`,
then calls `saveSettings(settings: updated)` before changing live policy.

In `bridge_settings.dart`, replace
`BridgePluginSettings.withDefaultIdleTimeout({idleTimeoutMins,
clearOverrides})` with
`withDefaultIdleTimeout({required int idleTimeoutMins, required Set<String>
clearOverridePluginIds})`. It clears `idleTimeoutMins` only when an entry key is
in that known-ID set, preserving every unknown plugin entry and all
`PluginLifecycleSettings.additionalProperties`. `withPluginIdleTimeout` remains
the one-entry set/clear primitive. `BridgeSettingsRepository` remains the sole
I/O owner; no second settings repository or writer is added.

After a successful durable write, resynchronize existing timers and publish one
new management snapshot token if the public snapshot changed. Resident plugins
still report and execute effective timeout `0`; their persisted overrides
remain editable and recover when residency returns to transient. Failed writes
return an explicit failure and do not publish success.

`Orchestrator.create` registers
`PatchPluginIdleTimeoutHandler(lifecycleService: _pluginLifecycleService)` in the
same `RequestRouter.handlers` list as P02's GET. `DebugServer` continues using
`BridgeRuntime.session.router`; no debug-only handler, router, service, or
repository is constructed.

Production files:

- `shared/sesori_shared/lib/src/models/sesori/plugin_management.dart` plus
  generated companions and `plugin_management_contract_test.dart`
- `bridge/app/lib/src/repositories/bridge_settings.dart`
- `bridge/app/lib/src/repositories/bridge_settings_repository.dart` as the
  existing load/save dependency, with no new persistence owner
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`
- `bridge/app/lib/src/routing/patch_plugin_idle_timeout_handler.dart`
- `bridge/app/lib/src/bridge/orchestrator.dart`

## Stage 12-P05: Transactional Disable

Ship safe/force disable end-to-end, so every mechanical seam introduced here has
a production caller. The P05 version of sealed
`PluginLifecycleCommandRequest` contains the final-wire `disable` variant and
`PluginStopMode`; P06 additively adds the other variants. Add the typed conflict
response and forward-safe conflict-reason enum now.

In `PluginRuntime`, replace the eligible boolean with
`PluginRuntimeAccessGate { enabled, draining, disabled }` and add these exact
mechanical methods:

```dart
Future<PluginRuntimeCommandResult> prepareDisable({
  required String pluginId,
  required PluginStopIntent intent,
});
void commitDisable({required String pluginId});
void rollbackDisable({required String pluginId});
```

`prepareDisable` moves enabled to draining before checking safe/force stop,
which fences new starts and acquisitions. Conflict/failure restores enabled
before returning its existing typed `PluginRuntimeCommandResult`. Success,
including an already-dormant generation, retains the slot's
`commandTransitionOwner`, `commandTransitionCompleter`, draining gate, and
stopping transition. `commitDisable` changes draining to disabled and clears
start permission; `rollbackDisable` restores enabled/dormant. Both validate the
retained state, clear the owner/transition, complete the retained completer so
shutdown cannot hang, and publish a final snapshot. Ordinary `stop` used by idle
suspension remains non-transactional and settles directly to dormant.

`PluginLifecycleRepository` mirrors those three methods without policy. The
lifecycle service's per-plugin active-command record is the sole production
consumer and equal disable commands join. Its disable flow is:

```text
repository.prepareDisable
  -> conflict/failure: map typed result; no settings write
  -> prepared: enter P04 settings tail
       -> load latest settings
       -> save with plugins.withPluginDisabled(disabled: true)
       -> success: repository.commitDisable, update eligible/default metadata
       -> failure: repository.rollbackDisable, restore live metadata,
                   return explicit command failure
```

The service always commits or rolls back a prepared disable in `try/catch`; it
never leaves draining state after a persistence outcome. No settings callback or
repository dependency enters `PluginRuntime`.

`PostPluginLifecycleCommandHandler` parses the P05 disable request and maps 400,
404, typed 409 conflict, and explicit 500 failure. `Orchestrator.create`
registers it in the one existing `RequestRouter.handlers` list; the debug server
continues to reuse `BridgeRuntime.session.router` and the same lifecycle service.
Preserve existing durable-commit drain, operation-stream cancellation, lease
drain, generation event fencing, and bounded shutdown behavior from current
`main`.

Production files:

- `shared/sesori_shared/lib/src/models/sesori/plugin_management.dart`, its
  generated companions, barrel export, and
  `shared/sesori_shared/test/models/plugin_management_contract_test.dart`
- `bridge/app/lib/src/bridge/runtime/plugin_runtime.dart`
- `bridge/app/lib/src/repositories/plugin_lifecycle_repository.dart`
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`
- `bridge/app/lib/src/routing/post_plugin_lifecycle_command_handler.dart`
- `bridge/app/lib/src/bridge/orchestrator.dart`
- `bridge/app/tool/benchmarks/benchmark_plugin_runtime.dart` and
  `multi_plugin_startup_benchmark.dart` only for required snapshot/access-gate
  constructor updates

## Stage 12-P06: Remaining Commands And Dynamic Eligibility

Add the `enable`, `restart`, and `refresh` variants to the existing sealed
request. The P05 handler and route remain unchanged and decode the expanded
union; no second command handler or route is added. Restart reuses
`PluginRuntime.restart`; enable reuses `PluginRuntime.start`; refresh only
inspects setup.

`PluginLifecycleService` owns one active command per plugin. Equal commands join;
a different same-plugin command conflicts; unrelated plugin commands may run
concurrently. All denylist writes share the P04 settings tail.

```text
enable: persist eligible -> apply access -> inspect -> start when ready
restart: require eligible -> inspect -> replace generation when ready
refresh: inspect only -> update setup/access -> leave newly ready plugin dormant
```

Add a per-slot `setupInspectionRevision`. `PluginRuntime.inspectSetup` captures
that revision and generation before each asynchronous descriptor probe and
applies a result only if both still match. Auth loss and disable increment the
revision, so stale enable/restart/refresh results cannot overwrite newer setup or
generation state. `PluginLifecycleRepository.inspect` remains the mapping seam.

Eligibility/default metadata is rebuilt from final state while preserving the
parent plan's OpenCode-preferred deterministic fallback. The existing ready-ID
stream emits additions after successful enable/refresh; the one existing
`PluginCatalogHydrationListener` applies its durable marker gate and no second
hydration owner is added.

To make that listener work after startup, add all registered IDs in deterministic
display-name/ID order to `PluginCompositionView.orderedPluginIds`. Remove
`CatalogImportService`'s startup-fixed `_enabledPluginIds`; it continues to
depend only on its existing `CatalogImportRepository` plus static ordered IDs
and hydration policies:

```dart
CatalogImportService({
  required CatalogImportRepository repository,
  required List<String> orderedPluginIds,
  required Map<String, CatalogEmptyHydrationPolicy> emptyHydrationPolicies,
});
```

The service stores an immutable ordered list/set and reads the injected
repository's new runtime-backed `eligiblePluginIds` and existing
`importEligiblePluginIds` getters at validation/status time. Unknown means
absent from the static set; not enabled means absent from `eligiblePluginIds`;
unavailable means enabled but absent from `importEligiblePluginIds`.
`CatalogImportRepository` already owns `PluginRuntime`, so these getters map
existing runtime access/start gates at the Layer-2 boundary and do not create a
new dependency. Build `emptyHydrationPolicies` for every ordered registration
rather than only the startup-enabled subset. `latestStatuses` walks
`orderedPluginIds` and includes only IDs currently in `eligiblePluginIds`.

The exact dynamic flow is:

```text
enable/refresh command settles
  -> PluginLifecycleService applies runtime access/setup and publishes readyPluginIds
  -> existing PluginCatalogHydrationListener observes a newly added ID
  -> existing listener calls CatalogImportService.start(automatic)
  -> CatalogImportService validates static known IDs plus CatalogImportRepository's
     runtime-backed enabled/import-eligible sets
  -> marker-gated import proceeds
```

`BridgeRuntimeRunner` and `Orchestrator` retain their current composition
contract; P06 forwards no new lifecycle collaborator between them.
`Orchestrator` already constructs one `CatalogImportRepository` from its injected
runtime and passes that repository to `CatalogImportService`. There is no
callback, duplicate repository, same-layer service dependency, or second
hydration listener. The P05 command handler stays registered in
`Orchestrator.create`'s one router, and debug continues sharing
`BridgeRuntime.session.router`.

Production files:

- `shared/sesori_shared/lib/src/models/sesori/plugin_management.dart`, its
  generated companions, and `plugin_management_contract_test.dart` for the
  three new variants
- `bridge/app/lib/src/bridge/runtime/plugin_runtime.dart` for inspection fencing
- `bridge/app/lib/src/repositories/plugin_lifecycle_repository.dart`
- `bridge/app/lib/src/repositories/catalog_import_repository.dart` for dynamic
  runtime-backed enabled/import-eligible getters
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`
- `bridge/app/lib/src/services/catalog_import_service.dart`
- `bridge/app/lib/src/bridge/orchestrator.dart`

`plugin_catalog_hydration_listener.dart` remains unchanged production code;
focused listener/service integration tests prove that its existing additions
logic drives a newly enabled plugin through the dynamic service validation.

## Verification Gates

- P01: interface descriptor tests and fatal analysis; OpenCode descriptor tests
  and fatal analysis; bridge lifecycle/runtime tests and fatal analysis.
- P02: shared contract tests/codegen/fatal analysis; bridge lifecycle/handler,
  orchestrator/debug-router tests and fatal analysis.
- P03: shared management/SSE tests/codegen/fatal analysis; bridge token/SSE
  tests; affected module-core tests and fatal analysis.
- P04: shared request tests/codegen/fatal analysis; bridge settings,
  lifecycle, handler, and concurrency tests plus fatal analysis.
- P05: shared command/conflict tests/codegen/fatal analysis; focused runtime,
  repository, lifecycle, disable-route, router, benchmark compilation, and
  bridge-app fatal analysis.
- P06: shared command/conflict tests/codegen/fatal analysis; bridge lifecycle,
  routing, hydration, catalog, runner, orchestrator, and debug-server tests plus
  fatal analysis.
- Every architecture-bearing implementation slice receives one Aristotle
  implementation review after relevant local verification and before delivery.
- Do not rerun unchanged passing commands; CI supplies the full repository
  matrix after each PR opens.

## Completion

Stage 12 completed after all six PRs merged, frozen PR #510 closed as
superseded, and the parent tracker recorded the merge commits and verification.
Stage 13 can now be rebuilt from the merged P06 result.
