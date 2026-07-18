# Setup-Aware Transient Plugin Lifecycle

## Status

- **Plan slug:** `setup-aware-plugin-lifecycle`
- **Status:** Corrected after the second architecture review and re-audited after
  bridge-app-onboarding W02; ready to implement after this plan lands
- **Generated:** 2026-07-18
- **Implementation base:** monorepo `main`
- **Initial audited tip:** `c491d7c40a0ef86c7bfeabf71ccbe1b9009849b0`
- **Post-W02 audited tip:** `2acd7b876667c4abeb7613ae6e46d0010a1241be`
- **Predecessor:** completed parallel-plugin Stages 0-9, merged through PR #497
- **Entry dependency:** satisfied — bridge-app-onboarding W02 merged through
  PR #504 at the post-W02 audited tip

The audited SHAs are staleness metadata, not implementation branch points.
Every implementation PR starts from the then-current `main` after checking drift
from this plan and from any other active plan touching bridge startup,
`Orchestrator`, session repositories, shared plugin contracts, or client plugin
selection.

## Goal

Make a large plugin ecosystem cheap and controllable:

- discover whether each registered backend runtime is installed and authenticated
  without starting, installing, or logging in the plugin;
- automatically enable setup-ready plugins when the bridge is in automatic
  selection mode;
- keep enabled plugins dormant until an operation needs them, then start them
  once and stop them after a user-configurable idle period;
- let the phone enable/start, disable/stop, and safely or forcibly restart one
  plugin without restarting the bridge;
- keep the bridge, durable catalog, relay, and plugin-management API available
  with zero enabled or active plugins; and
- preserve headless operation and compatibility with released clients and
  bridges throughout delivery.

The bridge continues to bundle registered plugin implementations. “Installed”
in this plan means that the backend runtime/CLI needed by a descriptor is
already present. Installing runtimes and authenticating backends from the phone
are product direction but belong to a separate future plan.

## Success Criteria

1. A descriptor can inspect setup through a bounded, read-only contract and
   report ready, runtime missing, authentication required, unavailable, or
   unknown without provisioning, starting, opening a login flow, or exposing
   credentials.
2. With no durable phone override, no explicit local plugin list, and no
   `--plugin` flags, the bridge derives the enabled set from every setup-ready
   registered plugin in stable registry order. Explicit local configuration and
   CLI behavior remain unchanged until a phone deliberately claims durable
   selection authority.
3. A durable phone override wins across bridge restarts even when old
   `--plugin` arguments are replayed. A local config command clears that remote
   override and reveals the unchanged local CLI/settings/automatic policy.
4. The bridge starts and connects with zero enabled or active plugins. Database
   catalog browsing, bridge health, setup inspection, and lifecycle control
   remain available; plugin-backed operations fail with an explicit setup or
   enablement result rather than stopping the bridge.
5. Every plugin-backed operation that actually needs a backend acquires its
   plugin generation. Concurrent callers share one start, in-flight work holds a
   lease, and catalog-only reads never activate plugins.
6. A setup-ready enabled plugin becomes dormant after it has no operation
   leases, reports no active work, and remains inactive for its effective idle
   policy. Each plugin supports `suspendAfter(duration)` or `alwaysOn`; the
   inherited default is ten minutes. Headless configuration may override one
   plugin, while the first mobile UI applies one policy to all plugins.
7. Unknown activity or an unsettled start/stop/restart blocks automatic and
   ordinary manual shutdown. A confirmed force operation may interrupt work,
   remains observable, and cannot leave a stale generation routed or emitting
   events.
8. Phone enablement immediately persists the remote override and attempts a hot
   start. Phone disablement safely stops and makes the plugin ineligible; a
   confirmed force disable may interrupt work. Restart preserves enablement and
   replaces only that plugin generation.
9. A plugin that becomes logged out is setup-blocked and unavailable for every
   backend operation, including transcript retrieval and import. Its durable
   catalog remains browseable, and an explicit user enablement preference is not
   silently rewritten.
10. Existing automatic catalog hydration checks the durable marker before
    activation, activates only when an import is actually required, and releases
    its lease afterward. Startup/reconnect activity reconciliation does not wake
    every dormant plugin or restore continuous plugin enumeration.
11. Old clients continue browsing and controlling supported sessions through a
    new bridge. New clients talking to an old bridge hide or disable unsupported
    lifecycle controls and retain existing plugin-selection behavior.
12. Every implementation PR is independently releasable: it either preserves
    shipped behavior or completes a user-visible stage, passes directly relevant
    analysis/tests, and leaves no partially routed lifecycle mode enabled.

## Terms And Locked Product Decisions

| Term | Meaning |
|---|---|
| **Registered** | A descriptor implementation is bundled in this bridge build. |
| **Setup-ready** | The descriptor found the runtime and sufficient backend authentication for activation. A plugin with no installation or login requirement may report ready directly. |
| **Enabled** | Current policy permits Sesori to use the plugin. Enablement is durable eligibility, not proof that a process is resident. |
| **Active** | One live plugin generation has been started and not yet stopped. |
| **Operational** | The active generation can currently serve backend operations. |
| **Dormant** | Enabled and setup-ready, but intentionally not active. A routed backend operation may wake it. |
| **Blocked** | Enabled by explicit preference but not setup-ready, unavailable, or failed. Catalog data remains. |

Locked decisions from the user interview:

- Automatic mode derives all setup-ready plugins in stable order.
- Phone selection is durable and overrides replayed CLI selection until a local
  reset explicitly returns authority.
- Phone enable/start and disable/stop are one user action each; runtime state is
  still shown so an enabled plugin may visibly be dormant after idle shutdown.
- Restart remains a separate action.
- Safe stop/restart is the default; a separate confirmation allows force.
- Idle policy is per-plugin-capable from the start: `suspendAfter(duration)` or
  `alwaysOn`. The default is ten minutes. Headless configuration/API may set
  individual overrides; the first mobile UI exposes only one apply-to-all
  control, where `Never` maps to `alwaysOn` for every plugin.
- Any targeted backend operation wakes an eligible dormant plugin. Catalog-only
  reads and management/status reads do not.
- Backend runtime installation and backend login from the phone are separate
  future-plan work.
- Mobile ships first while business logic remains in shared `module_core` so a
  desktop surface can adopt it later without moving ownership.
- Bridge-app-onboarding W02 must be complete before implementation; PR #504 now
  satisfies that dependency.

## Scope

### In Scope

- A setup-inspection contract on `BridgePluginDescriptor`, implemented by the
  OpenCode, Codex, and Cursor descriptors without backend details crossing the
  interface.
- A generic setup result rich enough to distinguish missing runtime,
  authentication required, blocked/unavailable, transient unknown, and ready.
- Stable automatic selection, explicit local selection, and durable remote
  selection authority with an exact local reset path.
- A bridge that runs with no selected, enabled, or active plugin.
- Dynamic per-plugin setup inspection, provisioning, start, sourced events,
  status, safe/force stop, restart, disposal, and generation fencing.
- An operation lease/acquisition seam used by every plugin-backed repository and
  import path, with no activation from database-only catalog reads.
- Plugin-owned generic busy/idle/unknown activity reporting plus bridge-owned
  in-flight lease accounting and per-plugin effective idle policy.
- Dynamic event attachment and per-plugin ordering across repeated generations.
- Additive headless HTTP/SSE control and status APIs.
- Durable bridge settings for remote selection authority, a default idle policy,
  and optional per-plugin idle-policy overrides.
- Mobile settings/control UI through module-core API -> repository -> service or
  cubit -> thin Flutter screen ownership.
- Compatibility handling, focused verification, and removal or narrowing of
  automatic enumeration paths that would defeat dormancy.

### Non-Goals

- Downloading/installing a backend runtime from the phone.
- Starting a backend login, entering credentials, opening a provider URL, or
  completing OAuth/device-code authentication from the phone.
- Downloading plugin implementation code or loading third-party executable
  extensions into the bridge process.
- Moving a live session between plugins.
- Periodically polling setup/authentication state when no management request or
  activation attempt needs it.
- Treating a transient setup probe failure as logout or rewriting an explicit
  enablement preference automatically.
- Persisting process IDs, operation leases, idle timers, or active generations
  across bridge process restarts.
- Keeping a plugin alive merely to mirror direct harness activity; external
  work remains import-driven.
- Per-plugin idle controls in the first mobile UI, arbitrary timeout entry,
  analytics, cost metering, or a general job scheduler.
- Desktop lifecycle-control UI in this plan.
- Broad auth, terminal, onboarding, catalog, or client-state refactors unrelated
  to dynamic plugin ownership.

## Audited Current Behavior

- `bridge/app/lib/src/bridge/runtime/plugin_registry.dart` registers OpenCode,
  Codex, and Cursor descriptors at compile time. Registration is inert.
- `PluginSelector` resolves CLI values, then persisted `enabledPlugins`, then the
  sole OpenCode fallback before the full parser and runtime exist. Only selected
  descriptors contribute parsed configs.
- `BridgePluginDescriptor.checkAvailability` means “may attempt startup,” not
  “already installed and logged in.” OpenCode and Codex report available with
  default config because `ensureRuntime` may download a managed runtime; Cursor
  performs a real binary probe.
- `BridgeRuntimeRunner` probes selected descriptors, provisions and starts them,
  then constructs one fixed `PluginLifecycleService` composition. It exits when
  no selected descriptor is available.
- `PluginLifecycleService.registerSelection` is one-shot, requires a non-empty
  list and exactly one default, and removes failed APIs from one mutable
  operational map. It cannot create a later generation.
- `Orchestrator.create` snapshots enabled IDs, builds plugin event listeners for
  the then-operational APIs, and injects the operational map into repositories.
- `SessionRepository`, `ProjectRepository`, agent/provider/question/permission/
  worktree repositories, and `CatalogImportRepository` access that map directly.
  Missing entries become “plugin is not running” rather than activating a
  dormant plugin.
- `CatalogImportService` receives fixed enabled IDs and starts one automatic
  marker-gated import for each startup-operational plugin.
- Project activity reconciliation runs at bridge startup and plugin
  `server.connected`; derived plugins may enumerate all sessions even after
  hydration. Native active-root compatibility may enumerate a project’s roots.
- `GET /plugin` returns only selected plugin metadata. Shared
  `PluginLifecycleState` has unavailable/ready/degraded/failed but does not
  separate setup, enablement, dormancy, active generation, or selection
  authority.
- The client has only `PluginApi.listPlugins`; plugin metadata is consumed by the
  new-session chooser. There is no lifecycle settings repository/cubit/screen.
- `BridgeSettings.enabledPlugins` is nullable and ordered. CLI currently wins,
  and the settings repository has no plugin-selection or idle-timeout update
  operation.
- The completed parallel-plugin architecture makes project/root/detail/child
  catalog reads database-only, so keeping those reads online with zero plugins
  does not require a fallback backend.
- Bridge-app-onboarding W02 is merged through PR #504. Its
  `BridgeRuntimeRunner.shouldRunAppOnboarding` gate runs the bounded checkpoint
  only for standalone interactive startup after concurrent enabled-plugin
  availability leaves at least one available descriptor and before predecessor
  wait, startup mutex, provisioning, or plugin start. The post-merge audit found
  no lifecycle-boundary change; Stage 10 deliberately widens only the
  availability part of that gate when zero-plugin startup becomes valid.

## Architecture And Ownership

### 1. Setup inspection remains descriptor-owned

Add a read-only method to `BridgePluginDescriptor`, because the descriptor exists
before a live `BridgePluginApi`:

```dart
Future<PluginSetupStatus> inspectSetup({
  required PluginConfig config,
  required HostProcessService processes,
  required Map<String, String> environment,
});
```

`PluginSetupStatus` is sealed because variants carry different guidance and
provisionability. The exact source names may change during implementation, but
the domain variants are fixed:

- ready;
- runtime missing, including whether existing bridge provisioning can install it
  after an explicit enable;
- authentication required;
- unavailable/unsupported with an actionable message; and
- unknown after a timeout, transient command failure, or ambiguous result.

The inspection contract never installs, logs in, opens a browser, starts the
long-lived backend, mutates credentials, or returns account/token details. A
bounded short-lived noninteractive status command is allowed. A plugin without a
reliable check returns unknown and is not automatically enabled.

The first implementations are concrete and stay inside their plugin packages:

- OpenCode reuses its existing bounded executable/version resolver. A usable
  existing executable is setup-ready because OpenCode has no bridge-start login
  prerequisite; provider credentials remain an operation/provider concern. A
  missing default executable is `runtimeMissing(canProvision: true)`, while a
  missing explicit `--opencode-bin` is not silently replaced.
- Codex first resolves a usable existing executable, then runs bounded
  `codex login status`. Its explicit logged-in result is ready, its explicit
  logged-out result is authentication-required, and unrecognized output,
  timeout, or command failure is unknown. A missing default executable is
  provisionable; a missing explicit override is not.
- Cursor first reuses its current bounded `cursor-agent --version` CalVer gate,
  then runs bounded `cursor-agent status` (or accepts a non-empty
  `CURSOR_API_KEY` already supplied to the process). Explicit logged-out output
  is authentication-required; unrecognized output is unknown. Cursor runtime
  installation remains external and therefore is never bridge-provisionable.

Probe output is classified and discarded inside the descriptor. Account names,
credential paths, tokens, and raw command output never cross the descriptor
contract or enter the management DTO. Tests pin classification against the
targeted runtime versions rather than teaching bridge core their output strings.

Keep `checkAvailability` and `ensureRuntime` separate. `ensureRuntime` gains a
required generic `RuntimeProvisionMode` (`existingOnly` or `allowInstall`) so it
can still resolve an existing launch path without downloading. Only explicit
local CLI/settings selection and the dated OpenCode fallback use
`allowInstall`. Automatic and remote/phone selection always use `existingOnly`.
If phone enablement finds a missing runtime, it persists the explicit preference
and returns setup-blocked status; it does **not** invoke installation. This is
the hard boundary between this plan and the deferred phone-install plan.

The bridge constructs default `PluginConfig` values directly from declared
`PluginOption` defaults for unselected descriptors. It does not register every
plugin’s options merely to inspect setup, and it does not make disabled-plugin
flags appear in ordinary focused CLI help.

### 2. Selection policy, parse-time configuration, and durable authority

`plugin_registry.dart` adds the exact pre-parser record
`PluginBootstrapSelection`:

```dart
enum LocalPluginSelectionSource { cli, settings, automatic }

typedef PluginBootstrapSelection = ({
  LocalPluginSelectionSource localSource,
  List<String> localPluginIds,
  List<String>? remotePluginIds,
  List<String> parserPluginIds,
});
```

`remotePluginIds == null` means no remote authority; an empty list is a valid
remote selection. `localPluginIds` is empty only for automatic mode.
`parserPluginIds` is the stable de-duplicated union of raw CLI ids, the selected
local-settings ids, remote ids, and the OpenCode help fallback when all three are
absent. This accepts a replayed launch script's namespaced flags while remote
authority controls runtime eligibility; it does not register every known
plugin's flags in ordinary focused help.

`PluginCliOptionsMapper` adds `defaultsFor(options:)`. `RunCommand` creates a
`PluginConfig` for every registered descriptor from declared defaults, overlays
parsed values only for `parserPluginIds`, and calls every descriptor's pure
`validateConfig` before authentication or startup locking. `BridgeCliOptions`
replaces `enabledPluginIds` with the required `bootstrapSelection`; runtime
selection is not falsely finalized at parse time.

Final local precedence remains:

```text
local policy = CLI --plugin values
            ?? persisted enabledPlugins
            ?? automatic setup-ready registry order
```

`PluginLifecycleService` materializes one `EffectivePluginSelection` in
`plugin_lifecycle_service.dart` with ordered enabled ids, a nullable default id,
selection authority, and per-id provisioning mode. A separately persisted
`remoteEnabledPlugins` list wins over the local policy across standalone
successors and supervised respawns. The first remote enable/disable seeds that
list from the current effective order. The exact local recovery command is
`sesori-bridge config plugins reset-remote`; it removes only
`remoteEnabledPlugins`, reports that restart is required, and leaves CLI args and
`enabledPlugins` untouched.

Automatic mode is derived rather than persisted. A management refresh
recomputes automatic membership; otherwise newly installed/authenticated plugins
appear on the next bridge start. Stable registry order chooses the nullable
default. The fixed legacy missing-plugin identity remains OpenCode and never
means “current default.”

For the first release, preserve released unset-selection bootstrap behavior with
a dated compatibility exception: if automatic inspection finds no ready plugin,
select only provisionable OpenCode with `allowInstall`. Explicit remote empty
selection bypasses this fallback and produces a zero-plugin bridge. Remove the
fallback only in the separate phone install/login work after supported clients
can recover an unconfigured machine without local terminal intervention.

### 3. Ordered startup and zero-plugin phase model

The final startup flow is explicit:

```text
raw argv + read-only BridgeSettings peek
  -> PluginSelector builds PluginBootstrapSelection
  -> full parser registers parserPluginIds only
  -> default PluginConfig for every descriptor + parsed overlays + pure validation
  -> Sesori authentication / identity resolution
  -> setup inspection (S10 runner-owned; S11+ `PluginRuntimeApi.inspectSetup`)
  -> PluginLifecycleService resolves remote/local/automatic effective selection
  -> checkAvailability for effective candidates
  -> bridge-app-onboarding W02 checkpoint (standalone interactive only; runs even
     when the effective set is empty)
  -> predecessor wait and cross-instance start gate
  -> register every descriptor/config, apply eligibility/default, start only the
     generations required by the current stage/policy
  -> compose database, relay, management API, and Orchestrator even with no default
```

Stage 10 performs the same ordering with the existing eager starter; S11-P01
moves inspection/start mechanics behind `PluginRuntimeApi` without changing
results.
S11-P02 starts `alwaysOn` plugins and the dated fallback eagerly while ordinary
`suspendAfter` plugins begin dormant.

This is the exact W02 integration delta from current `main`: S10 removes the
early `availableDescriptors.isEmpty` exit and removes `hasAvailablePlugins` from
`shouldRunAppOnboarding`, while preserving its standalone + interactive checks
and its position before predecessor wait/startup locking. A bridge that will now
continue with an empty effective set still offers the bounded onboarding
checkpoint; supervised and noninteractive runs still skip it.

The S10 ownership transition is explicit, not an unnamed temporary boundary.
After auth, `BridgeRuntimeRunner` calls every descriptor's `inspectSetup` with
the validated config, shared `BridgeHostProcessService`, and environment in one
bounded `Future.wait`; it freezes the result map and calls:

```dart
PluginLifecycleService.initialize({
  required PluginBootstrapSelection bootstrap,
  required BridgeSettings settings,
  required Map<String, PluginSetupStatus> setupById,
});
```

The service stores that immutable map, resolves selection, and exposes
`setupSnapshot` for `GetPluginSetupHandler`. S11-P01 changes only the producer:
`BridgeRuntimeRunner` obtains the same map from
`PluginLifecycleRepository.inspect`, which delegates to
`PluginRuntimeApi.inspectSetup`, then calls the unchanged `initialize`
signature. S10 constructs `PluginLifecycleService()` with no repository
dependency; S11-P01 adds the final repository/settings/clock constructor shown
below when those owners exist. No setup owner is invented between releases.

The nullable default is represented honestly as `String?`, never an empty
string. `PluginLifecycleService`, `PluginRuntimeApi`, `ProjectRepository` and the
`GET /plugin` mapper are the only default consumers. Default-targeted project
open/rename returns a typed 503 when null; catalog/health/setup/management routes
do not require a default. `CatalogImportService` accepts an empty effective list,
and the client already treats an empty `PluginListResponse.plugins` as “no new
session target” rather than a bridge connection failure.

### 4. Exact runtime boundary and dependency ownership

The one-shot runner is replaced by named owners; no new class is a test-only
interface or a repository peer dependency.

#### Foundation start capability and Layer-5 implementation

`bridge/app/lib/src/bridge/foundation/plugin_generation_starter.dart` defines
`PluginGenerationStarter`, a narrow cross-layer capability whose `start(...)`
stream emits provision progress and one terminal started `BridgePlugin`. It is
defined below the API layer because request-time `PluginRuntimeApi` must not import
runner/services. This is the permitted shared-layer-interface case, not a 1:1
testability wrapper.

```dart
abstract interface class PluginGenerationStarter {
  Stream<PluginGenerationStartEvent> start({
    required BridgePluginDescriptor descriptor,
    required PluginConfig config,
    required RuntimeProvisionMode provisionMode,
    required StartAbortSignal startAborted,
  });
}
```

`PluginGenerationStartEvent` is sealed with `progress(event:)` and terminal
`started(plugin:)` variants; startup failures remain stream errors using the
existing typed exceptions.

`bridge/app/lib/src/bridge/runtime/bridge_plugin_generation_starter.dart` adds
the sole production `BridgePluginGenerationStarter`. Its required constructor
collaborators are:

```dart
BridgePluginGenerationStarter({
  required ManagedRuntimePaths managedRuntimePaths,
  required ProcessIdentity currentBridgeIdentity,
  required String ownerSessionId,
  required StartupMutexRepository startupMutexRepository,
  required BridgeInstanceService bridgeInstanceService,
  required ProcessRepository processRepository,
  required RuntimeFileApi runtimeFileApi,
  required ServerClock clock,
  required Map<String, String> environment,
  required ProcessUser? currentUser,
});
```

This adapter owns the exact mechanics currently embedded in
`BridgeRuntimeRunner.startPluginsUnderStartupMutex`: two-attempt startup-lock
contention handling, single-live-bridge enforcement, state-directory creation,
fresh per-generation `BridgePluginHostImpl` construction,
`ensureRuntime(mode:)`, `provisionedRuntimePath`, and
`descriptor.start(host)` while the cross-instance mutex remains held. It
consumes the supplied `StartAbortSignal`; it never creates or owns its write
side. It caches only state-directory `RuntimeFileApi` instances; hosts, live
plugins, and generations are never reused. `BridgeRuntimeRunner` constructs this
adapter after authentication/identity resolution and keeps predecessor waiting
and the W02 checkpoint outside it.

#### Layer 1: `PluginRuntimeApi`

`bridge/app/lib/src/api/plugin_runtime_api.dart` adds concrete
`PluginRuntimeApi` and
its internal sealed result/snapshot types. Its constructor is complete:

```dart
PluginRuntimeApi({
  required List<PluginRuntimeRegistration> registrations,
  required PluginGenerationStarter generationStarter,
  required HostProcessService setupProcesses,
  required Map<String, String> environment,
  required ServerClock clock,
  required Duration shutdownBudget,
});
```

Each immutable `PluginRuntimeRegistration` contains exactly one descriptor and
its validated config. The descriptor also declares
`PluginProjectOwnership.native` or `.bridgeDerived`; this small enum is added to
`BridgePluginDescriptor` because dormant/blocked registrations need the same
generic project-ownership fact before a live API subtype exists. On start,
`PluginRuntimeApi` verifies the returned `NativeProjectsPluginApi` or
`BridgeDerivedProjectsPluginApi` matches that declaration.

The public mechanical surface is fixed:

```dart
Future<Map<String, PluginSetupStatus>> inspectSetup({required Set<String>? pluginIds});
void applySelection({
  required List<PluginRuntimeEligibility> entries,
  required String? defaultPluginId,
});
Future<void> startEager({required List<String> pluginIds});
Future<T> use<T>({
  required String pluginId,
  required String operation,
  required Future<T> Function(BridgePluginApi api) body,
});
Stream<T> useStream<T>({
  required String pluginId,
  required String operation,
  required Stream<T> Function(BridgePluginApi api) body,
});
Future<T?> useIfActive<T>({
  required String pluginId,
  required Future<T> Function(BridgePluginApi api) body,
});
Future<PluginRuntimeCommandResult> start({required String pluginId});
Future<PluginRuntimeCommandResult> stop({
  required String pluginId,
  required PluginStopIntent intent,
});
Future<PluginRuntimeCommandResult> disable({
  required String pluginId,
  required PluginStopIntent intent,
  required Future<void> Function() persistSelection,
});
Future<PluginRuntimeCommandResult> restart({required String pluginId, required PluginStopIntent intent});
void beginShutdown();
Future<void> disposeStartedApis();
Future<void> dispose();
```

It exposes replay-latest `snapshots`, source-attributed `backendEvents`, and
`provisionProgress` streams. It owns registered slots, enabled/provision-mode
enforcement, one start future per plugin, generation numbers, operation/event
subscription counts, status/work-state subscriptions, raw backend-event
subscriptions, bounded stop, and process-shutdown disposal. It does not read or
write bridge settings, choose automatic membership, schedule idle timers, map
wire DTOs, or emit phone SSE.

`PluginRuntimeSnapshot` contains plugin id/project ownership, latest setup
status, eligibility and provisioning mode, nullable generation, runtime state,
work state, lease count, and transition kind. `PluginRuntimeCommandResult` is
sealed as `applied(snapshot:)`, `current(snapshot:)`,
`conflict(snapshot:, reasons:)`, or `failed(snapshot:, message:)`; it carries no
backend-specific payload. `stop` is suspension and always retains eligibility.
`disable` is a callback-scoped transition: while its per-plugin transition lock
is held, it blocks acquisitions, passes the safe/force gate, stops/fences, marks
live eligibility disabled, awaits the supplied durable-selection write, and only
then unlocks. If that write throws, it restores prior eligibility as dormant and
returns failure without automatically restarting.

`PluginRuntimeApi` creates and retains one fresh `StartAbortController` in each
starting slot, passes only `controller.signal` to `PluginGenerationStarter`, and
clears it after that start settles. Force stop/restart and process shutdown call
the retained controller's `abort()` before waiting for settlement. Ordinary safe
stop never aborts a start; it reports `transitioning` until that start settles.

`use` increments a generation lease before invoking `body` and releases in
`finally`. `useStream` retains the lease until stream completion, error, or
cancellation; this is required for catalog import. `useIfActive` never starts a
generation and returns null when none is routable. All three reject disabled or
setup-blocked slots with typed plugin-operation errors. Plugin API results are
returned only if the captured generation remains current; repository durable
writes happen after that success so a forced/stale completion cannot publish a
successor's result.

#### Layer 2 and Layer 3

`bridge/app/lib/src/repositories/plugin_lifecycle_repository.dart` adds
`PluginLifecycleRepository({required PluginRuntimeApi runtimeApi})`. It maps setup and
runtime snapshots into bridge-domain lifecycle records and delegates inspect,
eligibility, start, safe/force stop, and restart. It has no settings dependency.

Its public methods mirror the policy use cases without exposing
`BridgePluginApi`: `inspect({required Set<String>? pluginIds})`,
`applySelection({required EffectivePluginSelection selection})`,
`start({required String pluginId})`,
`stop({required String pluginId, required PluginStopIntent intent})`,
`disable({required String pluginId, required PluginStopIntent intent, required Future<void> Function() persistSelection})`,
and `restart({required String pluginId, required PluginStopIntent intent})`, plus
replay-latest `snapshots` and a synchronous `snapshot` getter.

The existing `BridgeSettingsRepository` remains the **only** Layer-2 settings
owner. It gains atomic in-process read-modify-write methods for
`remoteEnabledPlugins`, the default idle policy, and plugin overrides. It never
depends on `PluginLifecycleRepository`.

For disable, `PluginLifecycleService` supplies a one-shot
`persistSelection` closure that invokes `BridgeSettingsRepository`; the closure
passes through `PluginLifecycleRepository` into `PluginRuntimeApi.disable` so the
API can keep its per-plugin transition lock across the durable commit. Neither
repository stores or depends on its peer, and the runtime API knows only whether
the callback succeeded. This is the same callback-scoped-lock pattern preferred
for a single protected operation.

`PluginLifecycleService` becomes the Layer-3 policy owner with this constructor:

```dart
PluginLifecycleService({
  required PluginLifecycleRepository lifecycleRepository,
  required BridgeSettingsRepository bridgeSettingsRepository,
  required ServerClock clock,
});
```

It owns selection precedence, effective/default order, setup gating, the dated
fallback, provisioning mode, one short global management-command queue for
settings consistency, per-plugin idle timers, safe/force policy, remote
mutations, monotonically increasing process-local management revision, and
public status snapshots. The global queue serializes rare settings mutations
from multiple clients; start/stop locks, leases, backend operations, and idle
timers remain independent per plugin. A failed settings write is observable and
returns the runtime API's already rolled-back snapshot; the service does not
perform a second eligibility transition.

Its public use cases are
`initialize({required PluginBootstrapSelection bootstrap, required BridgeSettings settings, required Map<String, PluginSetupStatus> setupById})`,
`refreshSetup({required String? pluginId})`,
`enable({required String pluginId})`,
`disable({required String pluginId, required PluginStopIntent intent})`,
`restart({required String pluginId, required PluginStopIntent intent})`,
`updateOrder({required List<String> pluginIds})`, and
`updateIdlePolicy({required PluginIdlePolicyUpdate update})`. Each returns the
current management snapshot or a typed conflict/failure.
`managementSnapshots` is replay-latest and carries the process-local revision.
S12 also exposes replay-latest `catalogHydrationReadyPluginIds`, containing the
complete enabled/setup-ready id list in registry order for the sole hydration
listener; it is an internal service stream, not a wire contract.

`BridgeRuntimeRunner` is still the Layer-5 process composer. It constructs one
shared settings repository, starter, runtime, lifecycle repository and lifecycle
service; wires shutdown phases to `PluginRuntimeApi`; and performs initial
inspection/selection/start. `Orchestrator` receives the same `PluginRuntimeApi` and
`PluginLifecycleService` instances, injects runtime into plugin-backed
repositories, and subscribes once to dynamic backend events and once to
lifecycle snapshots. `DebugServer` continues to reuse its router.

S11-P01 performs this mechanical cutover while calling `startEager` for the
current effective list and using an effective `alwaysOn` policy. S11-P02 alone
enables dormant starts and idle shutdown. There is no release where a reachable
plugin operation still reads the old static map.

### 5. Acquisition, generation, event, and shutdown flow

```text
targeted handler -> service -> owning repository -> PluginRuntimeApi.use/useStream
  -> reject disabled or setup-blocked
  -> join one in-flight start or ask PluginGenerationStarter for one generation
  -> attach status/work/backend-event subscriptions
  -> invoke BridgePluginApi under a generation lease
  -> fence result against generation -> release in finally

plugin backend event -> generation check -> PluginRuntimeApi.backendEvents
  -> one PluginEventListener -> SessionEventDispatcher
  -> Orchestrator per-plugin ordered tail -> shared Sesori SSE

PluginStatus / PluginWorkState -> PluginRuntimeApi snapshot
  -> PluginLifecycleRepository -> PluginLifecycleService policy/revision
  -> Orchestrator maps management invalidation SSE

bridge shutdown signal -> PluginRuntimeApi.beginShutdown + import/session cancellation
  -> drain imports and routed requests -> disposeStartedApis
  -> cancel generation subscriptions + BridgePlugin.shutdown -> dispose subjects
  -> close Orchestrator/database/relay shared resources
```

Starts/stops/restarts serialize per plugin; different plugin slots remain
independent. Concurrent acquisitions join one start. Every event/status/work
callback captures a generation number and is ignored after fencing. Stop cancels
and awaits that generation's source subscriptions before a successor is
routable. Events accepted before cancellation are immutable bridge-pipeline
input and retain per-plugin order; they never call the stopped API. A terminal
failure fences only that generation. A later routed operation may retry if
eligibility and setup still allow it.

`BridgePlugin` gains replay-latest `PluginWorkState` (`idle`, `busy`, `unknown`)
plus a synchronous current value. OpenCode derives it from
`ActiveSessionTracker`; Codex derives it from active-turn/session status; ACP
(and therefore Cursor) derives it from queued/in-flight prompt counts. Each
starts unknown until its initial transport/status baseline is trustworthy,
becomes busy if any backend work is active, and returns idle only on affirmative
plugin-owned evidence. Backend-specific states never leave those packages.

An authoritative backend authentication failure is surfaced as the new generic
`PluginAuthenticationRequiredException` from the plugin package. `PluginRuntimeApi`
fences new acquisitions, records authentication-required setup, and requests a
safe generation stop; bridge core never parses backend error text. OpenCode has
no global start-auth requirement, while Codex and ACP/Cursor map only reliable
backend evidence to this exception. Ambiguous failures remain unknown/failed.

#### Method-level migration matrix

| Owner and methods | Activation rule | Lease and completion rule |
|---|---|---|
| `SessionRepository.createSession`, `renameSession`, `getCommands`, `sendCommand`, `sendPrompt`, `getSessionMessages`, `deleteSession`, `notifySessionArchived`, `abortSession` | `use` the request or stored binding's plugin; all are concrete backend operations | Prime derived-directory state inside the callback. Hold through the backend call(s); map and perform durable projection/tombstone writes only after a current-generation success. Release in `finally`, including not-found/error paths. |
| `SessionRepository.ensurePluginAvailable` -> `ensurePluginRoutable`, and `requireActiveStoredSession` -> `requireRoutableStoredSession` | Acquire/release once to fail before session/worktree side effects; later repository backend calls reacquire and normally reuse the same idle generation | No API escapes the repository. The default ten-minute timer prevents churn between the preflight and the actual call; correctness does not rely on that timer because the actual call reacquires. |
| `SessionRepository.getProjectActivitySummaries`, `getSessionStatuses`, `_hydrateActiveRootBindings` | Iterate runtime active ids and `useIfActive`; never start dormant plugins | One bounded lease per active source. Timeout/error releases and reports that source unavailable; native active-root compatibility remains inside the same active lease. |
| All other public `SessionRepository` catalog/projection methods (`getSessionsForProject`, enrichment, stored-session/path/child reads, unseen/title/archive rows, binding projection, prompt defaults) | Database/git only; no runtime acquisition | Unchanged durable behavior. |
| `ProjectRepository.resolveProjectOpenTarget`, `renameProject` | `use` nullable effective default; a missing default is typed 503 | Hold through native/derived decision and backend call. `ProjectOpenTarget` gains `PluginProjectOwnership`, so `persistOpenedProject` is database-only and never re-reads a live API. |
| `ProjectRepository.listProjectActivityEvidence` and `ProjectActivityService.reconcile` plus Orchestrator startup/`server.connected` calls | Removed in S11-P02 | Durable catalog plus accepted live events own activity. `getProjects`, `getProject`, base-branch, remote, unseen and activity-row methods remain database/git only. |
| `AgentRepository.getAgents`; `ProviderRepository.getProviders` | `use` explicit plugin id | Resolve project path and complete plugin query/mapping within one callback; release on every result/error. |
| `QuestionRepository.getPendingQuestions`, `replyToQuestion`, `rejectQuestion` | Binding-derived `use`; the legacy null-session reject uses fixed OpenCode identity | Hold across tombstone checks and every backend call in that operation. Explicit auth/setup failure is preserved. |
| `QuestionRepository.getProjectQuestions` | Aggregate only `useIfActive` sources; do not wake all enabled plugins | One deadline-bound lease per active source, including derived enumeration and pending-question fan-out. All failed sources -> existing typed 503. |
| `PermissionRepository.getPendingPermissions`, `replyToPermission` | Binding-derived `use` | Hold across tombstone/pending validation and reply; release in `finally`. |
| `WorktreeRepository.removeWorktree` backend `deleteWorkspace` | After successful git removal, start one observable best-effort `use` for that plugin | The fire-and-forget future owns its lease to completion and logs recovered failure; the user response still follows git removal semantics. |
| `CatalogImportRepository.importCatalog` | `useStream` explicit plugin id | Lease spans enumeration, cancellation checks and atomic publication; cancellation/error releases. `getHydrationCompletion` stays database-only. |
| `CatalogImportService._run` | Check hydration marker before calling the acquisition stream | Marker hit never starts. Missing marker or explicit/headless import acquires. Fixed operational-id checks are replaced by lifecycle-repository eligibility/setup results. |
| `PermissionAutoApprovalService.approvePending` | Activity discovery sees active generations only; each concrete permission read/reply then uses its binding and may wake that one plugin | Existing errors remain observable; no scan wakes every plugin. |
| `PluginEventListener`, `SessionEventDispatcher`, `Orchestrator` | Runtime owns one raw subscription per active generation; one dynamic listener consumes all generations | Source cancellation/fencing occurs before successor routing; existing dispatcher and Orchestrator tails preserve per-plugin event order. |
| `HealthRepository`, `GetPluginsHandler`, setup/management handlers, and all database catalog handlers | Management/database only; never acquire | Read lifecycle snapshots or DAOs. Dormant, blocked and zero-plugin states remain inspectable. |

Aggregate status and project-summary reads therefore do not wake all plugins.
Only a request naming a plugin, a stored session binding, an explicit import, or
the nullable default for a concrete project operation may acquire.

### 6. Busy state, idle shutdown, and force

Add generic plugin-owned work state to the live lifecycle contract: idle, busy,
or unknown. Plugins map backend-specific turns/process/input semantics internally.
Unknown is conservative and blocks automatic or ordinary manual stop.

The bridge separately counts operation leases and lifecycle transitions. Idle
settings use the shared sealed `PluginIdlePolicy` rather than a sentinel
duration:

- `suspendAfter(preset)` accepts exactly ten, thirty, or sixty minutes; and
- `alwaysOn` keeps that enabled plugin resident until disable, restart, failure,
  setup loss, or whole-bridge shutdown.

Settings persist one inherited default plus optional plugin-id overrides. The
default is `suspendAfter(10 minutes)`. Headless config/API can set or clear an
override. A global apply-to-all update changes the default and clears every
override, so the mobile control truthfully governs all registered plugins. A new
plugin inherits the current default without a settings migration.

An active plugin using `suspendAfter` becomes an idle-shutdown candidate only
when:

- no operation lease exists;
- the live plugin reports idle;
- no start, stop, restart, import publication, or event drain is unsettled; and
- its effective policy is not `alwaysOn`.

Any new lease or transition from idle to busy/unknown cancels the timer; a later
affirmative idle transition starts a fresh full interval. Arbitrary backend
events, including heartbeats, never reset inactivity. An event only blocks stop
while its current source/drain hand-off is unsettled; if it represents work, the
plugin must report that through `PluginWorkState`. After the effective duration,
the service safely shuts down that generation and publishes dormant state
without disabling the plugin.

Ordinary phone disable/restart uses the same atomic runtime safe gate. Safe
disable changes eligibility only after the gate succeeds; a conflict leaves the
durable and live selection unchanged. On success the service stops/fences first,
marks live eligibility disabled, persists the new remote list through the
runtime API's callback-scoped transition, and only then releases the per-plugin
lock. A failed persistence write restores the last durable eligibility as
dormant without restarting automatically. A force request is a separate
confirmed action, signals the `PluginRuntimeApi`-owned in-flight start controller,
closes new leases, gives imports/operations one bounded drain, invokes bounded
shutdown, and records any interruption/failure. Force never deletes catalog data.

### 7. Setup loss and recovery

Setup is inspected at startup, on explicit management refresh, before enable or
restart, and after a backend failure indicates setup/authentication may have
changed. There is no background polling timer.

If an active or enabled plugin becomes unauthenticated:

- publish authentication-required and unavailable-for-new-session status;
- reject all backend operations, including message history and import, rather
  than guessing which reads remain usable;
- preserve database-only catalog browsing;
- preserve explicit enablement preference;
- stop the active generation safely when possible, using failed/degraded cleanup
  if the backend already rejected operations; and
- allow a later explicit refresh or routed operation to re-inspect and activate
  after the user logs in externally.

Automatic-mode membership follows current setup readiness because it has no
explicit preference to preserve. Unknown/transient inspection does not rewrite
durable state.

### 8. Catalog hydration and activity reconciliation

Automatic hydration first checks the database marker without acquiring a plugin.
Only a missing current-version marker acquires, imports, and releases that
plugin. Explicit import does the same regardless of marker and keeps its lease
until enumeration/publication settles or cancellation drains.

S12 makes
`PluginCatalogHydrationListener({required Stream<List<String>> readyPluginIds, required CatalogImportService catalogImportService})`
the **sole** automatic-hydration trigger. `PluginLifecycleService` owns that
replay-latest stream; every emission is the complete enabled/setup-ready id list
in registry order. The listener treats its first emission as additions from an
empty set and later invokes marker-gated hydration only for newly added ids, so
startup, hot enable, and an automatic refresh that makes a plugin ready share one
path. S12 removes `BridgeRuntimeRunner.startCatalogImports` and its inline
automatic loop. Explicit/headless import handlers remain direct user triggers
because they intentionally bypass the hydration marker.

Remove the assumption that bridge startup/reconnect must reconcile project
activity through every plugin. Dormant plugins stay dormant; known-session events
from active plugins update catalog state, explicit import discovers external
work, and the native active-root compatibility path runs only inside an already
active generation. This aligns actual plugin I/O with the database-owned catalog
direction completed in Stage 9.

### 9. Headless contracts and mobile ownership

Keep `GET /plugin` compatible for existing new-session clients. It continues to
return only enabled, setup-ready choices. Dormant choices map to existing
`PluginLifecycleState.ready`, so an old client can select one and wake it
transparently. Disabled/setup-blocked registrations are absent. An empty list is
valid. The existing `PluginMetadata` shape and legacy OpenCode attribution do not
change.

#### Shared setup and management models

Stage 10 adds
`shared/sesori_shared/lib/src/models/sesori/plugin_setup_response.dart`:

- `PluginSetupState`: `ready`, `runtimeMissing`,
  `authenticationRequired`, `unavailable`, `unknown` (unknown enum fallback is
  `unknown`);
- `PluginSetupMetadata`: id, display name, state, `canProvision`,
  and nullable plugin-authored action hint; and
- `PluginSetupResponse`: stable registry-ordered list.

Authentication-required plus the action hint is sufficient for this plan. No
login capability is declared until the deferred phone-login flow has a concrete
consumer and trust design.

Stage 11 adds the shared sealed `PluginIdlePolicy` in
`shared/sesori_shared/lib/src/models/sesori/plugin_idle_policy.dart`:
`suspendAfter(preset:)` or `alwaysOn()`, where the closed preset enum is
`tenMinutes`, `thirtyMinutes`, or `sixtyMinutes`. Bridge settings reuse this
domain type rather than creating a wire-identical record.

Stage 12 adds
`shared/sesori_shared/lib/src/models/sesori/plugin_management.dart`:

- enums `PluginSelectionAuthority` (`automatic`, `localCli`, `localSettings`,
  `remote`), `PluginRuntimeState` (`disabled`, `blocked`, `dormant`, `starting`,
  `active`, `degraded`, `stopping`, `failed`, `unknown`),
  `PluginManagementWorkState` (`idle`, `busy`, `unknown`),
  `PluginStopMode` (`safe`, `force`), and generic
  `PluginLifecycleConflictReason` (`inFlight`, `busy`, `workStateUnknown`,
  `transitioning`, `notEnabled`);
- `PluginManagementMetadata`: setup metadata, effective enablement/default,
  runtime/work state, effective idle policy, `hasIdleOverride`, and nullable
  action hint;
- `PluginManagementResponse`: process-local revision, authority, ordered plugin
  list, and default idle policy;
- sealed `PluginLifecycleCommandRequest`: `enable`, `disable(mode:)`,
  `restart(mode:)`, or `refreshSetup`; missing stop mode defaults safely to
  `safe`, while an unknown value is invalid JSON and never becomes force;
- `PluginOrderRequest` containing the complete current enabled-id permutation;
- sealed `PluginIdlePolicyUpdateRequest`: `applyAll(policy:)`,
  `setOverride(pluginId:, policy:)`, or `clearOverride(pluginId:)`; and
- `PluginLifecycleConflict`: plugin id, generic reason list, and current
  `PluginManagementResponse`.

Every model is Freezed, exported from `sesori_shared.dart`, omits nullable keys
through package defaults, and is generated rather than hand-edited. The bridge
maps plugin-interface setup/work types to these wire types in
`PluginLifecycleRepository`; `PluginLifecycleService` adds policy/authority and
returns the final response. No shared/client class switches on a concrete plugin
id.

#### Exact headless routes

| Method and path | Handler | Request / success | Error semantics |
|---|---|---|---|
| `GET /plugin/setup` | `GetPluginSetupHandler` in `lib/src/routing/get_plugin_setup_handler.dart` | `PluginSetupResponse`; read-only snapshot, no activation | Setup probe failures appear as `unknown` entries; only unexpected handler failure is 500. |
| `GET /plugin/management` | `GetPluginManagementHandler` in `lib/src/routing/get_plugin_management_handler.dart` | `PluginManagementResponse`; all registered plugins, no activation | 500 only for unexpected failure. Old bridges naturally return 404. |
| `POST /plugin/:id/command` | `PostPluginLifecycleCommandHandler` in `lib/src/routing/post_plugin_lifecycle_command_handler.dart` | `PluginLifecycleCommandRequest` -> current `PluginManagementResponse` | 400 malformed/invalid force value; 404 unknown id; safe conflict or restart-while-disabled is 409 JSON `PluginLifecycleConflict`; unexpected mechanical failure is 500 and remains in the lifecycle snapshot/log. |
| `PATCH /plugin/order` | `PatchPluginOrderHandler` in `lib/src/routing/patch_plugin_order_handler.dart` | `PluginOrderRequest` -> current response | 400 unless ids are a duplicate-free permutation of currently enabled ids; success claims remote authority and persists order/default. |
| `PATCH /plugin/idle-policy` | `PatchPluginIdlePolicyHandler` in `lib/src/routing/patch_plugin_idle_policy_handler.dart` | `PluginIdlePolicyUpdateRequest` -> current response | 400 unknown id/invalid policy; apply-all updates default and clears every override atomically. |

Enable/disable are idempotent and are the only command variants that mutate
remote selection authority. Enable persists first, marks eligible, re-inspects,
and starts immediately only when existing setup is ready; missing runtime/auth
returns 200 with enabled-but-blocked status and does not provision. Safe disable
leaves selection untouched on 409; success performs the locked
stop-disable-persist sequence above. Restart
preserves selection. Refresh re-inspects without polling and, in automatic mode,
recomputes membership. Repeated equal transitions join or return the current
snapshot; conflicting transitions return generic 409.

These handlers are registered in `Orchestrator`'s existing `RequestRouter`, so
remote calls use the existing authenticated relay connection and E2E-encrypted
request seam. The same router instance remains available on the optional
loopback debug server for headless local control; no unauthenticated network
listener is added.

`SesoriSseEvent` gains only
`plugin.management.changed({required int revision})`. `Orchestrator`, and no
lower layer, emits it when `PluginLifecycleService` advances revision. It carries
no credentials or backend payload; clients coalesce a `GET /plugin/management`.
Revision is comparable only within one live bridge process and resets on
reconnect, where GET is authoritative. Released clients may report-and-drop this
unknown additive event under their existing parser, but all prior session flows
continue; the event is emitted only on lifecycle/work/setup transitions, never a
polling cadence.

#### Exact module-core and mobile ownership

Stage 13 **extends**, rather than replaces, current `PluginApi` and
`PluginRepository`:

- `PluginApi` (`client/module_core/lib/src/api/plugin_api.dart`) adds
  `getManagement`, `command`, `updateOrder`, and `updateIdlePolicy` over
  `RelayHttpApiClient`.
- `PluginRepository` parses management 404 into the sealed
  `PluginManagementLoadResult.unsupported`, parses 409 JSON into
  `PluginLifecycleConflictException`, and otherwise returns shared DTOs without
  a duplicate record model. That result/exception lives in
  `client/module_core/lib/src/repositories/models/plugin_management_result.dart`.
- New `PluginManagementService` in
  `client/module_core/lib/src/services/plugin_management_service.dart` has the
  constructor
  `PluginManagementService({required PluginRepository pluginRepository, required ConnectionService connectionService})`.
  It owns initial
  GET, one coalesced refresh tail, command publication, connection/reconnect
  refresh, and filtering `plugin.management.changed`; it exposes replay-latest
  supported/unsupported/failure snapshots. It never polls.
- New pure-Dart `PluginManagementCubit` and `PluginManagementState` under
  `client/module_core/lib/src/cubits/plugin_management/` depend only on
  `PluginManagementService`. The cubit owns loading/action state and the UI
  decision to show force confirmation after a typed safe conflict; it never
  calls API/transport or another cubit.
- `PluginApi`, `PluginRepository`, and `PluginManagementService` are registered
  by `configureCoreDependencies`; the cubit is constructed in `BlocProvider`.

The mobile shell owns presentation in
`client/app/lib/features/settings/plugins/plugin_settings_section.dart`, not
`module_app_ui` and not desktop. Existing `SettingsScreen` adds a
`BlocProvider(create: (_) => PluginManagementCubit(service:
getIt<PluginManagementService>()))` and renders that section; no shared
`AppRoute` or desktop router changes are needed for a mobile-first settings
surface. The section shows one generic row per registration,
enable/disable/restart/setup-refresh, “Make default” plus up/down ordering for
enabled rows, and one apply-all selector (10m, 30m, 60m, Never). A generic
custom-policy badge appears when any override exists; choosing a global value
clears overrides. A management 404 renders a concise unsupported-old-bridge
state while ordinary `PluginRepository.listPlugins` continues its existing
OpenCode fallback. All copy is localized in `app_en.arb`; Flutter holds no
lifecycle decisions or plugin-id checks.

## Backward Compatibility And Release Safety

### Wire compatibility

- Existing `PluginMetadata` and `PluginListResponse` are not widened; dormant
  maps to their existing ready state and blocked registrations are omitted.
- New setup/management DTO enums use unknown fallbacks only for read-side state;
  command enums reject unknown values and force can never be a default.
- New management endpoints avoid changing `GET /plugin` from “enabled
  choices” to “every registered descriptor,” preventing old choosers from showing
  disabled plugins unexpectedly.
- New mobile clients treat management-route 404 as unsupported and explain the
  limitation; existing new-session selection remains available.
- Old clients see dormant enabled plugins as routable; request-time activation is
  transparent. Setup-blocked plugins remain unavailable.
- The additive lifecycle SSE is best-effort for old clients: their current
  parser reports and drops unknown variants without terminating the connection.
- Missing legacy `pluginId` continues to mean OpenCode in both directions.

### Settings and downgrade behavior

- Existing `enabledPlugins` and CLI behavior remain untouched until a phone
  creates the separate remote override.
- `BridgeSettings` persists exact additive keys `remoteEnabledPlugins`,
  `pluginIdlePolicy`, and `pluginIdlePolicyOverrides`. Missing keys decode to no
  remote authority, `suspendAfter(tenMinutes)`, and no overrides. Empty remote
  selection remains distinct from absence.
- Older bridges ignore these keys and therefore restore CLI/`enabledPlugins`
  precedence while downgraded. An old bridge config rewrite can drop unknown
  keys, so downgrade may intentionally clear remote/idle policy; the new mobile
  UI surfaces old-bridge unsupported rather than pretending those controls
  remain authoritative.
- A local reset clears only remote authority and never rewrites the user’s
  original CLI or `enabledPlugins` choice.
- Idle policy defaults honestly when absent. Existing config files require no
  rewrite merely to add it; missing per-plugin entries inherit the default.

### Every PR remains releasable

1. Contract/model additions ship only with defaults and no behavior activation.
2. Mechanical runtime refactoring initially preserves eager startup and existing
   routing; it may merge independently without changing product behavior.
3. Dormancy activates only after all reachable plugin operations and dynamic
   event subscriptions use the acquisition seam.
4. Headless lifecycle APIs are additive and useful before mobile adoption.
5. Mobile controls ship only with old-bridge graceful degradation and never
   become required for ordinary session creation.
6. No PR leaves generated sources stale, exposes a route without an owner, or
   changes the default timeout before safe-stop evidence passes.

## Value-Bearing Stages

### Stage 10 — Setup-Aware Automatic Plugins

**User value:** a bridge with no manual plugin list detects already installed and
authenticated backends, enables them in stable order, exposes why other backends
are unavailable, and remains useful with zero active plugins.

Implementation includes:

- descriptor setup inspection and implementations for current plugins;
- default-config inspection for unselected descriptors;
- typed automatic/local/remote-ready selection model, with remote authority not
  yet exposed to clients;
- zero-plugin runtime/orchestrator support;
- all-registered setup/status headless read API;
- compatible `GET /plugin` behavior and OpenCode transition fallback; and
- re-integration of the completed bridge onboarding checkpoint after setup
  selection settles, including zero-plugin startup.

Release gate:

- Explicit CLI and `enabledPlugins` starts behave exactly as before.
- Automatic inspection never downloads or logs in a plugin; only the dated
  no-ready OpenCode compatibility fallback may provision that one runtime.
- A failed/unknown setup check cannot prevent the relay/catalog from starting.
- Old/new bridge-client combinations retain session browsing and creation where
  they worked before.

### Stage 11 — Transient On-Demand Runtime

**User value:** enabled plugins consume process, memory, connection and event
resources only while needed, wake transparently for real operations, and suspend
after the configured idle period.

Delivery may use two PRs, both releasable:

1. Route eager startup and every plugin-backed operation/event through the new
   runtime acquisition/generation boundary while retaining eager activation and
   an effective `alwaysOn` compatibility policy.
2. Enable demand activation, dynamic events, marker-before-activation imports,
   conservative busy state, per-plugin-capable idle policies with an inherited
   ten-minute default, and removal of startup/reconnect enumeration that wakes
   dormant plugins.

Release gate:

- The migration PR has no product behavior change.
- The cutover has no reachable static-map bypass and no ordinary/safe stop can
  remove an operation's generation before completion; confirmed force may.
- Stopping one plugin never disconnects relay/catalog/other plugins.
- Existing clients transparently wake dormant plugins.

### Stage 12 — Headless Hot Lifecycle Control

**User value:** the same API seam used by future clients and automation can
inspect, enable/start, disable/stop, restart, refresh setup, set the global idle
policy or one plugin's override/`alwaysOn` policy, and safely force one plugin
without restarting the bridge.

Implementation includes:

- management status and command handlers;
- Layer-2 runtime lifecycle repository plus the existing independent settings
  repository, coordinated by the Layer-3 lifecycle service;
- durable phone/remote selection authority, even though the initial caller may
  be debug/headless API tooling;
- local authority-reset config command;
- safe/force conflict and failure responses;
- lifecycle/setup SSE; and
- multi-client command serialization and status convergence.

Release gate:

- APIs are additive and authenticated through the existing E2E bridge request
  seam.
- Repeated commands are idempotent or return the current transition.
- Restart/disable cannot silently interrupt active work without force.
- Remote empty selection leaves the bridge online and browseable.

### Stage 13 — Mobile Plugin Control

**User value:** phone users can manage plugin eligibility/runtime and apply one
idle policy to every plugin, with clear setup, dormant, busy, blocked and failure
state.

Implementation includes:

- the locked module-core API -> repository -> `PluginManagementService` ->
  `PluginManagementCubit` flow;
- a mobile settings section and plugin rows;
- enable/start, disable/stop, restart, setup refresh and safe/force confirmation;
- default/order and global apply-to-all idle controls, without per-plugin idle
  configuration;
- reconnect/SSE convergence; and
- unsupported-old-bridge degradation.

Release gate:

- The app remains releasable against old bridges; unsupported controls are
  hidden or explained rather than failing startup/session screens.
- The bridge remains releasable before the app UI ships because Stage 12 is
  headless and additive.
- No backend-specific auth/install UI is implied by generic action hints.

## Per-PR Production File Ledger And Cutover Gates

Tests mirror the named owners below. Freezed/JSON/Injectable/localization
companions are generated from their source files and are never hand-edited.
Before each PR, re-audit current `main`; a renamed file updates this ledger
without changing the owner or boundary.

### S10-P01 — setup-aware selection and zero-plugin bridge

| Workspace | Exact production files / classes | Before -> after and release gate |
|---|---|---|
| `bridge/sesori_plugin_interface` | New `lib/src/lifecycle/plugin_setup_status.dart`, `plugin_project_ownership.dart`, `runtime_provision_mode.dart`; modify `bridge_plugin_descriptor.dart` and `lib/sesori_plugin_interface.dart` | Descriptor has only availability/provision/start -> adds read-only setup, pre-start project ownership, and install policy. Gate: every implementor compiles and setup inspection cannot invoke provision/start. |
| OpenCode/Codex/Cursor plugin packages | `sesori_plugin_opencode/lib/src/runtime/open_code_plugin_descriptor.dart`; `sesori_plugin_codex/lib/src/runtime/codex_plugin_descriptor.dart`; `sesori_plugin_cursor/lib/src/runtime/cursor_plugin_descriptor.dart` | Startup-oriented availability only -> exact existing-runtime/auth classification above. Gate: real targeted CLI probes are bounded, redact output, and preserve explicit local startup/provision behavior. |
| `shared/sesori_shared` | New `lib/src/models/sesori/plugin_setup_response.dart`; modify `lib/sesori_shared.dart` | No setup wire model -> additive generic setup response. Gate: generated decode uses unknown setup fallback and contains no backend/account data. |
| `bridge/app` CLI/startup | `bin/bridge.dart`; `lib/src/bridge/runtime/plugin_registry.dart`, `plugin_cli_options_mapper.dart`, `bridge_cli_options.dart`, `bridge_runtime_runner.dart`; `lib/src/repositories/bridge_settings.dart`, `bridge_settings_repository.dart`; `lib/src/services/plugin_lifecycle_service.dart` | Plugin set finalized before parser/auth and non-empty -> bootstrap selection/default configs, post-auth effective selection, nullable default and zero set. Gate: CLI/settings explicit runs are byte-for-behavior compatible; automatic mode follows setup order plus the documented one-plugin fallback. |
| `bridge/app` composition/routes | `lib/src/bridge/orchestrator.dart`; `lib/src/bridge/repositories/project_repository.dart`; `lib/src/services/catalog_import_service.dart`; new `lib/src/routing/get_plugin_setup_handler.dart`; modify `lib/src/routing/get_plugins_handler.dart` | Orchestrator/default/import assume non-empty -> relay, database, catalog, setup and health compose empty. Gate: default-targeted routes fail explicitly while catalog routes and W02 remain online. |

### S11-P01 — dynamic boundary under unchanged eager behavior

| Workspace | Exact production files / classes | Before -> after and release gate |
|---|---|---|
| `bridge/app` foundation/API/lifecycle | New `lib/src/bridge/foundation/plugin_generation_starter.dart`, `lib/src/bridge/runtime/bridge_plugin_generation_starter.dart`, `lib/src/api/plugin_runtime_api.dart`, `lib/src/repositories/plugin_lifecycle_repository.dart`; modify `lib/src/bridge/runtime/bridge_runtime_runner.dart`, `lib/src/services/plugin_lifecycle_service.dart` | Runner/static map owns starts -> named generation starter + runtime API + repository + policy service. Gate: `startEager` and effective `alwaysOn` preserve startup, provisioning order/output, failure isolation and shutdown. |
| `bridge/app` routing/event composition | `lib/src/bridge/orchestrator.dart`; `lib/src/listeners/plugin_event_listener.dart`; `lib/src/bridge/services/session_event_dispatcher.dart`; `lib/src/bridge/runtime/bridge_runtime.dart` | One listener/static API per startup plugin -> one sourced runtime stream with generation attribution and existing per-plugin ordering. Gate: same externally visible session SSE and no listener survives its generation. |
| `bridge/app` plugin-backed repositories | `lib/src/bridge/repositories/session_repository.dart`, `project_repository.dart`, `agent_repository.dart`, `provider_repository.dart`, `question_repository.dart`, `permission_repository.dart`, `worktree_repository.dart`; `lib/src/repositories/catalog_import_repository.dart` | Direct `Map<String, BridgePluginApi>` reads -> `PluginRuntimeApi.use`, `useStream`, or `useIfActive` according to the matrix. Gate: repository search finds no static operational map and every callback releases on success/error/cancel. |
| `bridge/app` affected services | `lib/src/bridge/services/session_creation_service.dart`, `session_lifecycle_service.dart`, `permission_auto_approval_service.dart`, `project_activity_service.dart`; `lib/src/services/catalog_import_service.dart` | “is running” preconditions/fixed ids -> routable preflight, active-only aggregates and runtime-backed import. Gate: behavior remains eager and current route responses stay compatible. |

### S11-P02 — demand activation and idle suspension

| Workspace | Exact production files / classes | Before -> after and release gate |
|---|---|---|
| `shared/sesori_shared` | New `lib/src/models/sesori/plugin_idle_policy.dart`; modify `lib/sesori_shared.dart` | No shared idle policy -> one typed 10/30/60/always-on domain model reused by persisted bridge settings and later clients. Gate: generated round-trip has no sentinel duration. |
| Plugin lifecycle contract | New `bridge/sesori_plugin_interface/lib/src/lifecycle/plugin_work_state.dart` and `plugin_authentication_required_exception.dart`; modify `lifecycle/bridge_plugin.dart`, `steady_plugin_lifecycle.dart`, and `lib/sesori_plugin_interface.dart` | Lifecycle status has no generic work truth -> replay-latest idle/busy/unknown and authoritative auth-loss exception. Gate: unknown blocks stop and no core backend-string parsing exists. |
| Plugin implementations | OpenCode `lib/src/active_session_tracker.dart`, `runtime/open_code_bridge_plugin.dart`, `opencode_plugin_impl.dart`; Codex `lib/src/codex_plugin_impl.dart`, `runtime/codex_bridge_plugin.dart`; ACP `lib/src/acp_plugin.dart`, `runtime/acp_bridge_plugin.dart`; Cursor `lib/src/cursor_plugin_impl.dart` only if its inherited mapping needs an override | Core can only infer activity from API calls -> each plugin owns aggregate work state and reliable auth mapping. Gate: real busy work never reports idle; ambiguous/disconnected state is unknown. |
| Runtime/policy/settings | `bridge/app/lib/src/api/plugin_runtime_api.dart`; `lib/src/repositories/plugin_lifecycle_repository.dart`, `bridge_settings.dart`, `bridge_settings_repository.dart`; `lib/src/services/plugin_lifecycle_service.dart`; `lib/src/bridge/runtime/bridge_runtime_runner.dart` | Eager/always-on -> dormant acquisition, typed 10/30/60/never policy, inherited default/overrides, timer cancellation and bounded safe stop. Gate: dormancy is enabled only after S11-P01 inventory passes. |
| Import/activity/event cleanup | `bridge/app/lib/src/repositories/catalog_import_repository.dart`; `lib/src/services/catalog_import_service.dart`; `lib/src/bridge/repositories/session_repository.dart`, `project_repository.dart`; `lib/src/bridge/services/project_activity_service.dart`; `lib/src/bridge/orchestrator.dart` | Startup import/activity may enumerate active set -> marker-before-acquire, active-only native hydration, no startup/reconnect full reconciliation. Gate: completed marker and aggregate reads produce zero starts. |

### S12-P01 — headless hot lifecycle control

| Workspace | Exact production files / classes | Before -> after and release gate |
|---|---|---|
| `shared/sesori_shared` | New `lib/src/models/sesori/plugin_management.dart`; modify `lib/src/models/sesori/sesori_sse_event.dart`, `lib/sesori_shared.dart` | No management commands/status -> additive DTOs, typed conflict and one invalidation event. Gate: safe is the missing-mode default; force requires explicit valid wire value. |
| `client/module_core` shared-union exhaustiveness | Modify `lib/src/capabilities/server_connection/models/sse_event.dart`, `lib/src/services/sse_event_tracker.dart`, `lib/src/cubits/session_list/session_list_cubit.dart`, `lib/src/cubits/session_detail/session_detail_cubit.dart` | Existing exhaustive switches do not know the new system event -> classify it as non-session/no-op so the shared contract PR compiles before mobile management consumes it. Gate: no existing screen refreshes or changes behavior. |
| Bridge settings/CLI | `bridge/app/lib/src/repositories/bridge_settings.dart`, `bridge_settings_repository.dart`; `lib/src/services/bridge_config_service.dart`; `bin/bridge.dart`; `lib/src/bridge/runtime/plugin_registry.dart`, `bridge_cli_options.dart`, `bridge_runtime_runner.dart` | Local policy only -> nullable/empty remote authority and exact `config plugins reset-remote`. Gate: no phone action provisions; reset preserves local policy. |
| Bridge policy and triggers | `bridge/app/lib/src/api/plugin_runtime_api.dart`; `lib/src/repositories/plugin_lifecycle_repository.dart`; `lib/src/services/plugin_lifecycle_service.dart`; new `lib/src/listeners/plugin_catalog_hydration_listener.dart`; modify `lib/src/services/catalog_import_service.dart`, `lib/src/bridge/runtime/bridge_runtime_runner.dart`, `lib/src/bridge/orchestrator.dart` | Runner-only startup trigger -> one replay-latest listener owns startup, hot-enable, and automatic-refresh hydration; explicit/headless imports remain direct. Gate: remove inline `startCatalogImports`; one plugin command cannot stop relay/catalog/peers; failed persistence rolls back eligibility. |
| Bridge routes/SSE | New `bridge/app/lib/src/routing/get_plugin_management_handler.dart`, `post_plugin_lifecycle_command_handler.dart`, `patch_plugin_order_handler.dart`, `patch_plugin_idle_policy_handler.dart`; modify `lib/src/bridge/orchestrator.dart` | Setup read only -> exact management routes and Orchestrator-owned invalidation SSE. Gate: router integration proves 400/404/409/500 mappings and debug server shares the instances. |

### S13-P01 — module-core and mobile management

| Workspace | Exact production files / classes | Before -> after and release gate |
|---|---|---|
| `client/module_core` API/repository/service | `lib/src/api/plugin_api.dart`; `lib/src/repositories/plugin_repository.dart`; new `lib/src/repositories/models/plugin_management_result.dart`, `lib/src/services/plugin_management_service.dart`; modify `lib/src/di/injection.dart`, `lib/sesori_dart_core.dart` | Discovery GET only -> typed management commands, 404/409 mapping and reconnect/SSE convergence. Gate: pure-Dart service never polls and existing list fallback is unchanged. |
| `client/module_core` state | New `lib/src/cubits/plugin_management/plugin_management_cubit.dart`, `plugin_management_state.dart` | No lifecycle state -> service-only cubit with typed confirmation state. Gate: cubit requires typed conflict before exposing force intent. |
| `client/app` thin presentation | New `lib/features/settings/plugins/plugin_settings_section.dart`; modify `lib/features/settings/settings_screen.dart`, `lib/l10n/app_en.arb` | Account/notification settings only -> generic mobile plugin management and apply-all idle selector in the existing settings route. Gate: old bridge shows unsupported without affecting session screens; no plugin-id condition or business rule exists in Flutter. |

Because S10/S12 touch shared wire source and S13 consumes it, generated files are
committed in the same PR as their source. Because S13 changes `module_core`, its
verification includes both mobile and desktop compilation even though desktop
gets no UI/source change.

## Verification Strategy

Tests are added only where they provide meaningful confidence in a security,
concurrency, compatibility, persistence, or user-decision boundary. Do not add
tests for pass-through constructors, getters, generated equality, every enum
case, or duplicated fake-plugin permutations merely to increase counts.

High-value automated coverage:

- Setup inspection cannot provision/start/login and correctly distinguishes a
  real ready/missing/auth-required/unknown outcome for each current descriptor.
- Selection precedence, durable remote authority/reset, explicit empty remote
  selection, stable default and settings downgrade decoding.
- One start for concurrent acquisitions; lease retention; generation fencing;
  failure then retry; safe conflict; force interruption; idle timer cancellation;
  `Never`; and one plugin stopping independently.
- A representative integration route from each materially different category:
  stored-session binding, explicit plugin/project operation, aggregate management
  read, import, and dynamic event delivery. Avoid one test per thin handler when
  a router/service integration proves the boundary.
- Marker-complete hydration does not activate; missing-marker import holds a
  lease; dormant plugins are not enumerated by startup/reconnect activity.
- Old/new DTO and route compatibility, especially dormant routability and old
  bridge management 404.
- Mobile enable/disable/restart conflict/force and unsupported-bridge states,
  using cubit tests for business decisions and only focused widget tests for
  interactions that cubit tests cannot prove.

Per-PR verification runs only owning-package analysis and directly affected
tests. Shared contract changes also run generated-code checks and affected
module analysis. The final stage runs the complete directly affected bridge,
shared, module-core and mobile suites once; it does not duplicate CI’s unrelated
workspace matrix.

Manual release checks focus on behavior automation cannot prove cheaply:

- real OpenCode/Codex/Cursor setup inspection without changing credentials;
- process/RSS observation across start, ten-minute idle stop, wake and restart;
- safe conflict and confirmed force during real active work;
- phone control through a relay disconnect/reconnect; and
- standalone and supervised bridge behavior with zero enabled plugins.

## Risks And Mitigations

| Risk | Mitigation |
|---|---|
| “Logged out” is inferred from a transient failure | Preserve an explicit unknown state; only plugin-owned reliable evidence returns authentication-required. |
| Auto mode downloads every runtime | `inspectSetup` is separate from availability/provisioning and may not mutate. |
| Idle stop races a request or event | Operation leases, generic work state, per-plugin serialization and generation fencing. |
| Aggregate reads wake all plugins | Management snapshots are local; only concrete backend operations acquire. |
| One plugin failure stops the bridge | Zero-plugin operation and independent slots remain release gates. |
| Phone override makes CLI recovery confusing | Preserve local policy separately and provide an explicit local reset. |
| Old clients cannot understand dormancy | Keep dormant enabled plugins transparently routable through existing metadata semantics. |
| Onboarding startup order becomes stale | W02 is merged and the `2acd7b87` runner order is audited; S10 has one explicit zero-plugin gate delta and rechecks later main drift before implementation. |
| Broad lifecycle migration creates a half-cutover | First PR preserves eager behavior; dormancy enables only after the operation inventory is complete. |
| Tests expand without confidence | Require each new test to name the race, compatibility contract, persisted decision, or user interaction it proves. |

## Deferred Follow-Up: Phone Installation And Login

VISION and ROADMAP record a later workstream where the phone can initiate a
plugin-owned backend runtime installation and backend authentication flow. That
future plan depends on this plan’s setup statuses, zero-plugin bridge, dynamic
activation, progress/status API, durable authority and mobile management screen.

The future plan must separately decide:

- which descriptors support managed installation and how Cursor-like external
  installers are handled;
- noninteractive OAuth/device-code/browser flows versus credentials that must
  remain local;
- secret entry, storage, redaction, cancellation and trust posture;
- install/login progress across relay reconnects; and
- how setup readiness is re-inspected after completion.

No implementation detail for those flows is locked here.
