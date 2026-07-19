# Setup-Aware Transient Plugin Lifecycle

## Status

- **Plan slug:** `setup-aware-plugin-lifecycle`
- **Status:** redesign approved; implementation stack is being rebuilt
- **Implementation base:** latest `origin/main` at `5a91f582`
- **Predecessor:** parallel-plugin Stages 0-9 and bridge-app-onboarding W02 are merged
- **Delivery:** five stacked PRs; the old unmerged PRs #507-#511 are closed and
  are reopened only after their replacement stage is implemented and verified

This plan replaces the first unmerged implementation. Nothing introduced only
by that implementation needs compatibility handling. Released contracts still
receive ordinary app/bridge compatibility treatment.

## Goal

Make every bundled backend plugin automatically discoverable and cheap to keep
available:

- setup inspection never installs, logs in, or starts a backend;
- one durable denylist is the only plugin-eligibility preference;
- eligible plugins start only for concrete demand and stop after configurable
  confirmed idle time;
- the bridge, relay, catalog, setup API, and management API remain available
  with zero usable plugins;
- headless clients and the redesigned mobile Settings surface can inspect and
  control the same lifecycle seam; and
- backend-specific setup, activity, authentication, and launch behavior stays
  inside the owning plugin package.

## Locked Product Decisions

### Eligibility and configuration

- Remove repeated `--plugin`, `enabledPlugins`, `remoteEnabledPlugins`, selection
  authority, user-defined plugin order, remote reset, and the legacy automatic
  OpenCode provisioning fallback.
- `--plugin` is an ordinary unknown option. There is no compatibility parser.
- Register every bundled plugin's namespaced runtime options on `run`. An
  explicitly supplied invalid value remains a fatal CLI usage error even when
  that plugin is denied.
- Eligibility is exactly `plugin id not in plugins.disabled`.
- Unknown disabled IDs and unknown plugin configuration objects survive a
  current bridge rewrite. Local config commands reject unknown IDs to catch
  typos.
- Existing allowlist values are ignored and removed on a later canonical write;
  they are not migrated into the denylist.
- Local `config plugins` mutations require bridge restart. Authenticated
  management API mutations apply live.

### Setup and installation

- Inspect every eligible registration at startup. Denied plugins are not
  probed and report `notInspected` until explicit refresh or enable.
- Setup states are `notInspected`, `ready`, `runtimeMissing`,
  `authenticationRequired`, `unavailable`, and `unknown`.
- Remove `canProvision` from current domain and wire models.
- No lifecycle path downloads or installs a runtime. Existing low-level pinned,
  checksummed downloader primitives may remain, but are unreachable from this
  lifecycle plan.
- No polling and no hidden probe on an ordinary operation against a blocked
  plugin. Recovery requires enable, explicit refresh, restart, or bridge
  restart.
- `GET /plugin/setup` returns the current snapshot only and never activates or
  probes. Explicit refresh is allowed while the plugin is denied.

### Ordering and defaults

- All plugin lists use case-insensitive display-name order with plugin ID as the
  deterministic tie-breaker.
- The bridge default is the first currently selectable plugin in that order.
- No default or last-used plugin is persisted by the bridge.
- The mobile new-session chooser persists last-used plugin per client and
  bridge. It uses that plugin when still routable and otherwise uses the
  bridge-derived default.

### Residency and idle behavior

- Every setup-ready plugin starts dormant after bridge startup.
- A concrete plugin operation, marker-missing catalog hydration, or live enable
  starts it. Reads served only from the durable catalog never start it.
- The hardcoded idle fallback is 10 minutes.
- `plugins.default.idleTimeoutMins` overrides that fallback.
- `plugins.<id>.idleTimeoutMins` overrides the effective default for one plugin.
- Any integer is accepted and preserved exactly. Values `<= 0` mean demand-start
  and never idle-stop; they do not mean eager startup.
- Automatic hydration is real demand. A plugin configured `<= 0` remains
  resident after hydration.
- Applying one timeout to all plugins sets the default and removes every known
  per-plugin timeout override while preserving unrelated unknown fields.
- Safe automatic or manual stop requires no operation lease, affirmative plugin
  idle state, and no unsettled lifecycle transition or event handoff.

### Live management

- Live enable removes the deny entry, persists intent, inspects setup, and
  starts/retries the plugin when ready even if it was already eligible.
- A non-ready enable remains durably eligible and returns blocked state without
  installing anything.
- Live disable safely stops first and then persists the deny entry. A confirmed
  force request may interrupt work. Failed persistence restores live eligibility
  and remains observable.
- Restart preserves eligibility and re-inspects setup before replacing the
  generation. Non-ready setup returns the current blocked snapshot.
- Refresh updates setup facts only; newly ready plugins remain dormant.
- Management revision and `plugin.management.changed` SSE invalidation remain
  process-local. Consumers coalesce a fresh management GET and never poll.

### Client settings

- Add Plugins as a dedicated sub-page of the merged redesigned Settings screen.
- The mobile shell remains thin and uses Prego settings/grouped-row primitives.
- Shared client ownership remains API -> repository -> service -> cubit.
- The page shows all registrations, setup/runtime/work status, eligibility,
  effective timeout, global timeout, per-plugin override, refresh, restart, and
  safe disable with explicit force confirmation.
- The page does not expose runtime installation or backend login.
- Desktop compiles against shared module-core changes but gets no plugin settings
  UI in this plan.

## Durable Configuration

The exact optional shape is:

```json
{
  "plugins": {
    "disabled": ["cursor"],
    "default": {
      "idleTimeoutMins": 30
    },
    "opencode": {
      "idleTimeoutMins": 0
    }
  }
}
```

- The entire `plugins` root is omitted from a newly created default config.
- Missing `disabled` means an empty denylist.
- Missing timeout fields inherit through plugin -> default -> hardcoded 10.
- Empty strings are invalid IDs, duplicates are canonicalized, and writes use a
  deterministic ID order.
- A malformed `plugins` root or `disabled` list fails a bridge run rather than
  silently enabling plugins. Malformed timeout fields are reported, removed at
  that scope, and fall back without discarding the denylist or unknown entries.
- `BridgeSettingsRepository` remains the sole settings owner and preserves raw
  unknown plugin entries/fields while updating known values.

Local commands are:

```text
sesori-bridge config plugins
sesori-bridge config plugins enable <id>
sesori-bridge config plugins disable <id>
```

Listing shows known plugins alphabetically and separately identifies preserved
unknown disabled IDs. Mutations print that restart is required.

## Architecture

### Touched workspaces

- `bridge/sesori_plugin_interface`, `bridge/sesori_bridge_foundation`, and the
  OpenCode, Codex, ACP, and Cursor plugin packages own generic setup/runtime
  contracts and concrete backend evidence.
- `bridge/app` owns configuration, composition, lifecycle policy, runtime slots,
  persistence coordination, routes, catalog triggers, and shutdown.
- `shared/sesori_shared` owns setup/management DTOs, the additive lifecycle SSE,
  and plugin-list bridge identity.
- `client/module_core` owns transport, persistence APIs/repositories, reactive
  management logic, new-session preference, and cubits.
- `client/app` owns redesigned mobile routes and Prego presentation.
- `client/desktop` receives no plugin UI; it is a downstream analysis target.

### Descriptor-owned setup

`BridgePluginDescriptor.inspectSetup(...)` is read-only and receives validated
plugin config, bounded host-process access, environment, and read-only state
directory. Concrete OpenCode, Codex, and Cursor descriptors classify their own
runtime and authentication evidence and return only generic setup status and a
sanitized nullable action hint.

Probe output is bounded and discarded inside the plugin package. Tokens,
accounts, credential paths, and raw command output never cross the descriptor
contract. Ambiguous output, timeout, or command failure maps to `unknown`.

Runtime start resolves only an already-present executable. The old
`RuntimeProvisionMode`, setup `canProvision`, and automatic install path are
removed. A missing executable is setup-blocked rather than downloaded.

The concrete Stage 10 data flow is:

```text
RunCommand
  -> registers every knownPlugins descriptor option through PluginCliOptionsMapper
  -> parses/validates Map<pluginId, PluginConfig>
BridgeSettingsRepository.loadSettings
  -> BridgePluginSettings(disabled ids, default entry, plugin entries, passthrough)
BridgeRuntimeRunner
  -> PluginLifecycleService.registerPlugins(alphabetical metadata)
  -> inspectSetup only for ids absent from disabledPluginIds
  -> fill denied ids with PluginSetupNotInspected
  -> PluginLifecycleService.initialize(disabled ids, setup map)
  -> check existing-runtime availability only for setup-ready eligible ids
  -> compose zero or more eager Stage-10 starts and every non-plugin subsystem
GetPluginSetupHandler / GetPluginsHandler
  -> immutable lifecycle snapshots; never descriptor calls
```

`BridgePluginSettings` in `bridge_settings.dart` owns typed known values and raw
passthrough maps. `PluginLifecycleSettings` is the same optional object shape for
`default` and each plugin and currently contains nullable `idleTimeoutMins`.
`BridgeSettingsRepository` is the only JSON read/repair/write owner.
`BridgeConfigService` remains the local config use-case owner; CLI command
classes only parse arguments, invoke it, and render results.

### Startup and zero-plugin composition

```text
full CLI parser registers every plugin option
  -> parse and validate one PluginConfig per registered descriptor
  -> authenticate and resolve bridge identity/settings
  -> mark denied registrations notInspected
  -> inspect eligible registrations concurrently and read-only
  -> derive eligible/setup/default state alphabetically
  -> run the bounded standalone onboarding checkpoint
  -> predecessor wait and single-live-bridge gate
  -> compose every registration as a dormant runtime slot
  -> compose database, relay, catalog, setup and management routes even when no slot is routable
```

The onboarding checkpoint remains standalone/interactive and no longer depends
on at least one usable plugin. Project operations that still require a default
return the existing typed unavailable response when none exists.

### Runtime boundary

Concrete `PluginRuntime` owns the mechanical runtime state machine: registered
slots, one joined start per plugin, generation numbers, start abort controllers,
operation/event subscriptions, leases, applied access gates, and bounded
generation shutdown. It never reads settings, derives eligibility/setup policy,
chooses idle behavior, or persists decisions.

`PluginLifecycleRepository` maps generic runtime/setup snapshots without owning
settings. `PluginLifecycleService` owns denylist policy, derived default,
effective timeout, setup refresh, safe/force commands, idle timers, management
revision, and lifecycle snapshots. `BridgeRuntimeRunner` remains the Layer-5
composer. `Orchestrator` owns management SSE emission and dynamic backend-event
routing.

Every plugin-backed operation uses `PluginRuntime.use`, `useStream`, or
`useIfActive`. Catalog-only reads never acquire. Aggregate status reads inspect
active generations only. A generation result or event is accepted only while
its captured generation remains current.

Concrete `PluginGenerationFactory` lives at
`bridge/app/lib/src/bridge/runtime/plugin_generation_factory.dart`; there is no
one-implementation interface. It accepts one immutable
`PluginRuntimeRegistration` (descriptor, validated config, state directory) and
a start-abort signal, then emits progress plus one started plugin. Its required
constructor dependencies are `ManagedRuntimePaths`, current `ProcessIdentity`,
owner session ID, `StartupMutexRepository`, `BridgeInstanceService`,
`ProcessRepository`, root `RuntimeFileApi`, `ServerClock`, environment, and
nullable current `ProcessUser`. It constructs a fresh `BridgePluginHostImpl` and
plugin state `RuntimeFileApi` per generation; it owns the existing startup mutex,
single-live-bridge check, existing-runtime resolution, and descriptor start.

`PluginRuntime` lives at
`bridge/app/lib/src/bridge/runtime/plugin_runtime.dart` and is constructed with
required registrations, concrete `PluginGenerationFactory`, setup process
service, environment, clock, and shutdown budget. It owns slots, generations,
subscriptions, leases, transition locks, and abort controllers.
`PluginLifecycleRepository` at
`bridge/app/lib/src/repositories/plugin_lifecycle_repository.dart` depends only
on that concrete runtime and maps mechanical snapshots/results.
`PluginLifecycleService` is
the Layer-3 policy owner. In Stage 11-P01 it depends on the lifecycle repository;
Stage 11-P02 adds the shared `BridgeSettingsRepository` and `ServerClock` when
idle policy first needs them. `BridgeRuntimeRunner` constructs every owner and
injects the same instances into `Orchestrator` and `DebugServer`.

The Stage 11-P01 method migration is complete before the branch is done:

| Consumer | Acquisition |
|---|---|
| `SessionRepository` concrete backend operations | `use` the request or persisted binding's plugin; durable writes occur only after a current-generation result. |
| `SessionRepository` aggregate activity/status reads | `useIfActive`; never wake every plugin. |
| `ProjectRepository` open/rename | `use` the live nullable derived default; missing default remains typed unavailable. |
| `AgentRepository`, `ProviderRepository` | `use` the explicit plugin ID. |
| `QuestionRepository`, `PermissionRepository` | `use` the persisted session binding; aggregate project questions use active generations only. |
| `WorktreeRepository` backend cleanup | observable best-effort `use` after git success; its future retains the lease and logs recovered failure. |
| `CatalogImportRepository` | `useStream` for enumeration through atomic publication/cancellation. |
| `PluginEventListener`, `SessionEventDispatcher` | one generation-attributed runtime event stream; no startup API-map subscriptions. |

Stage 11-P01 is independently coherent: every eligible setup-ready plugin still
starts eagerly and remains resident, matching Stage 10 while all backend access
and events move behind the dynamic boundary. Stage 11-P02 alone switches initial
residency to dormant and enables idle stop.

The exact operation path is:

```text
handler -> service -> owning repository -> PluginRuntime.use/useStream
  -> per-plugin transition lock checks eligibility and setup
  -> join or start one generation
  -> increment lease before API escapes the lock
  -> run callback/stream
  -> verify captured generation before accepting result/publication
  -> release lease in finally/cancel/error
```

The exact stop/replace path is:

```text
acquire per-plugin transition lock and fence new acquisitions
  -> safe: require zero leases + idle work + settled transition/event handoff
     force: abort a start, reject new leases, grant bounded drain
  -> increment/fence generation
  -> cancel and await source status/work/backend-event subscriptions
  -> bounded plugin shutdown
  -> publish dormant/disabled/failed snapshot
  -> release transition lock
```

Process shutdown first calls `PluginRuntime.beginShutdown`, then drains
imports and routed requests, disposes started APIs, closes runtime streams, and
only then closes Orchestrator/database/relay resources. Late starts observe the
shutdown fence and are disposed rather than routed.

### Work state, idle timers, and authentication loss

Live plugins expose generic replay-latest work state: `idle`, `busy`, or
`unknown`. Concrete plugins derive it from backend-specific evidence. Unknown
is conservative and blocks safe stop.

For a positive effective timeout, the lifecycle service starts a full timer only
while work is idle, leases are zero, and transitions are settled. New work,
unknown/busy state, or a transition cancels it. Expiry attempts the same safe
stop gate and leaves eligibility unchanged.

An authoritative plugin-owned authentication failure fences new acquisitions,
marks setup authentication-required, drains existing leases where safe, and
stops that generation. Durable catalog reads remain available. Recovery is
explicit; the denylist is never rewritten because of setup loss.

Stage 11-P02 introduces
`PluginCatalogHydrationListener({required Stream<List<String>> readyPluginIds,
required CatalogImportService catalogImportService})` as the sole automatic
trigger; no inline runner hydration remains. Its first complete emission models
startup additions. `CatalogImportService` checks the durable marker before
`CatalogImportRepository.useStream` acquires. Stage 12 keeps the same listener
and widens the existing ready-ID stream to emit additions after live
enable/refresh. Explicit import handlers remain direct user triggers and
intentionally bypass the automatic marker gate.

### Headless contracts

`GET /plugin` remains the released new-session discovery seam. It returns only
eligible, setup-ready, routable choices in alphabetical order. Dormant choices
remain `ready` because request-time activation is transparent. Stage 13 adds a
nullable `bridgeId` to this response together with its client consumer so a new
client can key its local favorite; old bridges decode as null and new bridges
remain readable by older clients.

New lifecycle routes are:

| Method/path | Behavior |
|---|---|
| `GET /plugin/setup` | Alphabetical snapshot of every registration; no probe or activation. |
| `GET /plugin/management` | Current revision, nullable derived default ID, default timeout, and all registration rows. |
| `POST /plugin/:id/command` | Typed enable, disable, restart, or refresh request. |
| `PATCH /plugin/idle-timeout` | Typed apply-all, set-override, or clear-override request. |

The management response has no authority, persisted order, serialized `enabled`,
or per-row `isDefault`. Each alphabetical row carries setup, runtime state, work
state, effective `idleTimeoutMins`, `hasIdleTimeoutOverride`, and nullable action
hint. `PluginRuntimeState.isEnabled` and routability are derived helpers that
fail closed for unknown state.

Malformed requests are 400, unknown IDs are 404, safe/transition conflicts are
409 with typed current state, and unexpected mechanical failures are 500 while
remaining visible in lifecycle state/logging. Force is never inferred or used as
a missing-value default.

Stage 12 shared models live in
`shared/sesori_shared/lib/src/models/sesori/plugin_management.dart`:

- `PluginRuntimeState`, `PluginManagementWorkState`, `PluginStopMode`, and
  `PluginLifecycleConflictReason` enums;
- `PluginManagementMetadata` and `PluginManagementResponse`;
- sealed `PluginLifecycleCommandRequest` variants;
- sealed `PluginIdleTimeoutUpdateRequest` variants; and
- `PluginLifecycleConflict` carrying current state.

The handlers are `get_plugin_management_handler.dart`,
`post_plugin_lifecycle_command_handler.dart`, and
`patch_plugin_idle_timeout_handler.dart` under `bridge/app/lib/src/routing/`.
They depend only on `PluginLifecycleService`, parse generated shared models, and
map typed service exceptions to HTTP status. `GetPluginSetupHandler` remains the
separate snapshot handler.

`PluginLifecycleService` exposes `managementSnapshot`, replay-latest
`managementSnapshots`, `managementRevisions`, `command(pluginId, request)`, and
`updateIdleTimeout(request)`. It owns one short global settings-mutation tail and
one active-command record per plugin. Equal commands join. A different command
for the same transitioning plugin returns a typed `transitioning` 409. Different
plugins can start/stop concurrently; only shared config writes enter the global
tail.

Disable uses explicit downward state transitions; no lower layer invokes a
settings callback:

```text
service command slot -> repository applies accessGate=draining
  -> runtime safe/force gate, stop, and fence generation
  -> conflict: repository restores accessGate=enabled; no durable write
  -> success: service persists denylist through BridgeSettingsRepository
     -> commit: repository applies accessGate=disabled; publish revision
     -> failure: repository restores accessGate=enabled/dormant without restart;
        return explicit failure
```

Enable persists removal from the denylist in the settings tail, applies live
eligibility, inspects, then starts if ready. Restart and refresh use the same
per-plugin command serialization. Revision advances only after a materially new
final snapshot is queryable, and Orchestrator alone maps it to SSE.

### Client ownership

`client/module_core` adds the management API/repository/service/cubit and a
small secure-storage-backed plugin preference repository. Management refresh is
triggered by connection/reconnect and the lifecycle invalidation SSE, with one
coalesced refresh tail and no polling.

The preference repository keys a nullable last-used plugin ID by the connected
bridge ID returned by `GET /plugin`. Layer-3 `NewSessionPluginService` combines
plugin discovery and that preference: it prefers the saved ID only when
routable, otherwise uses the response's derived default, and records a valid
choice when session creation is submitted. Persistence failure is logged and
never blocks creation. When an older bridge omits its ID, the service uses the
bridge default and does not invent a cross-bridge key.

`client/app` adds a Plugins row to the redesigned Settings landing page and a
dedicated Prego `PluginSettingsScreen`. Business decisions, command convergence,
and force intent remain in module-core. All copy is localized.

The concrete client classes are:

- Layer 1 `PluginApi` (`client/module_core/lib/src/api/plugin_api.dart`) for
  discovery, management, commands, and timeout requests through
  `RelayHttpApiClient`.
- Layer 1 `PluginPreferenceApi`
  (`client/module_core/lib/src/api/plugin_preference_api.dart`) constructed with
  required `SecureStorage`; it owns encoded per-bridge storage keys and raw
  reads/writes/deletes.
- Layer 2 `PluginRepository` maps management 404 and typed 409 conflicts while
  otherwise returning shared DTOs.
- Layer 2 `PluginPreferenceRepository` depends only on `PluginPreferenceApi` and
  exposes typed read/write of a nullable plugin ID.
- Layer 3 `PluginManagementService({required PluginRepository
  pluginRepository, required ConnectionService connectionService})` owns initial
  GET, one coalesced refresh tail, mutation publication, and subscriptions to
  `ConnectionService.status` and `ConnectionService.events`. Connected state and
  `plugin.management.changed` are symmetric staleness triggers.
- Layer 4 `PluginManagementCubit({required PluginManagementService service})`
  owns loading/action state, integer input validation, and typed safe-to-force
  confirmation. It calls no API directly.
- Layer 3 `NewSessionPluginService({required PluginRepository pluginRepository,
  required PluginPreferenceRepository pluginPreferenceRepository})` resolves
  discovery plus saved/default selection and owns the observable unawaited write
  when valid creation is submitted.
- Existing `NewSessionCubit` receives required `NewSessionPluginService`, invokes
  those use cases, and only maps results to composer state.

`configureCoreDependencies` registers both APIs, both repositories, and the
service; cubits remain `BlocProvider`-constructed. `client/app` adds
`AppRouteDef.settingsPlugins`, `AppRoute.settingsPlugins()`, the route mapping in
`app_router.dart`, a Plugins landing row in `settings_screen.dart`, and
`features/settings/plugin_settings_screen.dart`. The screen resolves the service
through DI, watches the cubit, and composes only Prego widgets and localized
copy.

### Concurrent management invariants

- Runtime transition locks are per plugin and own start/stop/restart fencing.
- The lifecycle service settings tail serializes denylist and timeout
  read-modify-write operations across all clients, preventing lost updates.
- Equal commands join; conflicting same-plugin commands fail while unrelated
  plugin transitions proceed.
- Setup results apply only if the command/generation that requested them is
  still current.
- No durable write publishes success before commit. A recovered failed write
  returns explicit failure and leaves a truthful live snapshot.
- Event/status/work callbacks capture generation and are ignored after fencing.
- Management revision is monotonic within one process and publishes only after
  the identified state is queryable.

## Compatibility Boundary

- No adapter, dual write, or migration is retained for unmerged
  `remoteEnabledPlugins`, authority/order DTOs, preset idle policy, old
  management response, or the abandoned first client screen.
- Released `GET /plugin`, session attribution, and plugin-specific namespaced
  flags remain compatible except for the explicitly approved removal of
  `--plugin`, `enabledPlugins`, and automatic managed-runtime installation.
- New client -> released old bridge: management 404 is an unsupported state;
  ordinary plugin discovery/session flows continue. Missing bridge ID disables
  local favorite persistence.
- Released old client -> new bridge: extra response fields/events are additive;
  dormant choices activate transparently.
- Downgrading to an older bridge may ignore the new `plugins` root and therefore
  lose denylist enforcement for that run. The new bridge does not mirror legacy
  allowlists.

## Per-Stage Production File Ledger

Generated Freezed/JSON/Injectable/localization companions are regenerated from
the listed source files and committed with their stage.

### Stage 10 / PR #507 files

| Workspace | Production files/classes |
|---|---|
| Plugin interface/foundation | `sesori_plugin_interface/lib/src/lifecycle/bridge_plugin_descriptor.dart`, `plugin_setup_status.dart`, `plugin_project_ownership.dart`, exports; `sesori_bridge_foundation/lib/src/host_process_command_executor.dart` for bounded probes. |
| Concrete plugins | OpenCode/Codex/Cursor descriptor setup implementations under each package's `lib/src/runtime/*_plugin_descriptor.dart`; ACP only where Cursor setup shares behavior. |
| Shared | `plugin_setup_response.dart`, `sesori_shared.dart`. |
| Bridge config/CLI | `bridge/app/bin/bridge.dart`; `bridge_settings.dart`, `bridge_settings_repository.dart`; `bridge_config_service.dart`; `plugin_registry.dart`, `plugin_cli_options_mapper.dart`, `bridge_cli_options.dart`. Delete `plugin_bootstrap_selection.dart`. |
| Bridge startup/policy/routes | `bridge_runtime_runner.dart`, `plugin_lifecycle_service.dart`, `orchestrator.dart`, `project_repository.dart`, `catalog_import_service.dart`, `get_plugin_setup_handler.dart`, `get_plugins_handler.dart`. |

### Stage 11-P01 / PR #508 files

| Workspace | Production files/classes |
|---|---|
| Mechanical runtime | Add concrete `plugin_generation_factory.dart`, `plugin_runtime.dart`, and `plugin_lifecycle_repository.dart`; modify `bridge_runtime_runner.dart` and `plugin_lifecycle_service.dart`. |
| Event composition | `orchestrator.dart`, `plugin_event_listener.dart`, `session_event_dispatcher.dart`, `bridge_runtime.dart`. |
| Plugin-backed repositories | `session_repository.dart`, `project_repository.dart`, `agent_repository.dart`, `provider_repository.dart`, `question_repository.dart`, `permission_repository.dart`, `worktree_repository.dart`, `catalog_import_repository.dart`. |
| Owning services | `session_creation_service.dart`, `session_lifecycle_service.dart`, `permission_auto_approval_service.dart`, `project_activity_service.dart`, `catalog_import_service.dart`. |

### Stage 11-P02 / PR #509 files

| Workspace | Production files/classes |
|---|---|
| Plugin contract | Add `plugin_work_state.dart` and `plugin_authentication_required_exception.dart`; modify `bridge_plugin.dart`, steady lifecycle, and exports. |
| Plugin implementations | OpenCode active-session tracker/plugin, Codex plugin, ACP plugin, and Cursor adapter map concrete work/auth evidence. |
| Bridge policy/settings | `plugin_runtime.dart`, `plugin_lifecycle_repository.dart`, `plugin_lifecycle_service.dart`, `bridge_settings.dart`, `bridge_settings_repository.dart`, `bridge_runtime_runner.dart`. |
| Dormancy cleanup | Add `plugin_catalog_hydration_listener.dart`; modify `catalog_import_repository.dart`, `catalog_import_service.dart`, session/project repositories, `project_activity_service.dart`, `orchestrator.dart`. |

### Stage 12 / PR #510 files

| Workspace | Production files/classes |
|---|---|
| Shared | Add `plugin_management.dart`; modify `sesori_sse_event.dart` and barrel exports. |
| Bridge settings/policy | `bridge_settings.dart`, `bridge_settings_repository.dart`, `plugin_runtime.dart`, `plugin_lifecycle_repository.dart`, `plugin_lifecycle_service.dart`. |
| Triggers/composition | Keep `plugin_catalog_hydration_listener.dart`; widen its ready-ID source through `plugin_lifecycle_service.dart`; modify `catalog_import_service.dart`, `bridge_runtime_runner.dart`, `orchestrator.dart`. |
| Routes | Add `get_plugin_management_handler.dart`, `post_plugin_lifecycle_command_handler.dart`, `patch_plugin_idle_timeout_handler.dart`; wire the same instances into relay/debug routing. |
| Client exhaustive switches | Only minimum `SseEvent`/tracker changes needed for the additive invalidation event; no management feature yet. |

### Stage 13 / PR #511 files

| Workspace | Production files/classes |
|---|---|
| Shared and module-core transport/persistence | Add nullable `bridgeId` to `plugin_list_response.dart`; modify `plugin_api.dart`, add `plugin_preference_api.dart`, `plugin_repository.dart`, management result models, add `plugin_preference_repository.dart`, DI source, barrel exports. |
| Module-core orchestration/state | Add `plugin_management_service.dart`, `new_session_plugin_service.dart`, `cubits/plugin_management/*`; modify `new_session_cubit.dart`. |
| Mobile routing/presentation | `app_routes.dart`, `app_router.dart`, `settings_screen.dart`, add `plugin_settings_screen.dart`, `app_en.arb`. |
| Downstream | Desktop/module-core exhaustive compilation only; no desktop route or screen. |

## Delivery Stages

### Stage 10 / PR #507 — setup discovery and denylist

- config model/repository and local plugin commands;
- unconditional plugin CLI option registration;
- descriptor setup states/probes without installation;
- alphabetical eligibility/default and zero-plugin startup;
- snapshot setup API and compatible plugin list.

### Stage 11-P01 / PR #508 — dynamic runtime boundary

- concrete generation factory, runtime, and lifecycle repository;
- migrate every backend operation and dynamic event source to acquisition;
- retain generation fencing, independent failure, and zero-plugin composition.

### Stage 11-P02 / PR #509 — dormant runtime and numeric idle timeout

- plugin-owned work state and authentication-loss signal;
- all-ready-dormant startup, demand activation, marker-before-hydration;
- numeric default/override config and safe idle suspension;
- remove startup/reconnect enumeration that wakes dormant plugins.

### Stage 12 / PR #510 — headless management

- simplified management DTOs/routes, safe/force commands, revision/SSE;
- live denylist mutations and setup refresh;
- numeric idle-timeout updates and one hydration listener.

### Stage 13 / PR #511 — redesigned mobile plugin settings

- module-core API -> repository -> service -> cubit and preference storage;
- per-bridge last-used new-session choice;
- Settings landing row and dedicated Plugins sub-page using merged Prego
  settings primitives;
- focused interaction, conflict/force, reconnect, and route tests.

Each branch is rebuilt from its predecessor after #507 starts at latest
`origin/main`. Histories may be force-with-lease rewritten as explicitly
approved. A closed PR is reopened only after its replacement stage passes
focused verification.

## Verification

- Run code generation only from source models; never edit generated output.
- Run `dart analyze --fatal-infos` sequentially in every changed Dart/Flutter
  package.
- Run directly affected setup/config/runtime/lifecycle/routing tests per bridge
  stage, plus affected plugin package tests.
- Shared wire changes run shared tests and downstream module analysis.
- Client stage runs focused module-core and Flutter settings/new-session tests,
  then mobile and desktop fatal analysis.
- Do not rerun unchanged passing commands. CI supplies the full repository matrix.

## Deferred Installation

Phone-requested managed runtime installation remains a separate draft. This
plan exposes setup truth but no install command, progress model, or login flow.
