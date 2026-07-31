# Multi-Plugin Release Preparation

## Status

- **Plan slug:** `multi-plugin-release-prep`
- **Status:** Steps 1/6 through 5.B/6 merged; Step 5.C/6 is in progress
- **Plan delivery:** this document and its tracker are Step 1/6
- **Implementation base:** `origin/main` at `6ffc9f39`
- **Approved product direction:** Codex remains project-aware; Cursor and the
  ACP-backed option state use plugin-scoped caching; OpenCode remains
  project-scoped

## Goal

Prepare the first multi-plugin release so that opening New Session and switching
between harnesses serves durable, scope-aware cached options when available. On
cache miss, the aggregate API may start only the selected harness and populate
the cache; explicit Refresh still forces fresh backend discovery.

Complete the release preparation by consolidating the two mobile Harnesses
settings screens into one capability-driven surface with Prego timeout and
force-confirmation sheets.

## Delivery Rules

- This plan keeps six top-level product steps. Step 4 is delivered as the fixed
  six-PR subseries 4.A through 4.F. Every title uses
  `[multi-plugin-release-prep] ... [step <x>/6]`, including the lettered step.
- The Step 4 replacement PRs form a stacked chain and may remain open together
  so every review boundary is visible. Each successor targets its immediate
  predecessor and must merge in letter order; Steps 5 and 6 retain their
  original top-level numbering.
- Internal Dart plugin contracts update every in-repository implementation in
  lockstep. Do not add compatibility shims for internal interfaces.
- Client/bridge transport remains backward and forward compatible. An older
  peer's limitation is explicit rather than represented as an empty successful
  catalog.
- Generated Freezed, JSON, Drift, Injectable, and localization files are always
  regenerated from source and never hand-edited.
- Keep each Step 4 replacement near 1,500 changed lines including generated
  output. The v12 migration verifies the upgraded database against current
  Drift declarations directly rather than committing a 3,000-line generated
  current-schema test helper.

## Current Behavior

### New-session loading

- `GET /plugin` reads `PluginLifecycleService.selectableMetadataSnapshot` and
  does not inspect, acquire, or start a plugin.
- After discovery, `NewSessionCubit` independently requests `/agent`,
  `/provider`, and `/command` for the selected project and plugin.
- Each bridge repository reaches the backend through `PluginRuntime.use`, so a
  dormant plugin starts. Switching plugins or reconnecting can repeat that cost.
- The client has only a provider-only process cache. It is not durable, does not
  cache agents or commands, and can retain provider data indefinitely.
- Cursor catalog discovery can spend its ACP connection budget and a bounded
  catalog-probe budget. Codex agent/provider loading can issue duplicate
  `model/list` calls.

### Actual option scopes

| Plugin | Current option behavior | Durable aggregate scope |
|---|---|---|
| OpenCode | Agents, configured providers/models, and commands are resolved with a project directory. | Project |
| Codex | Collaboration modes and `model/list` are global, but the default model/provider is resolved from project rollout/config evidence and skills are requested with project CWD. | Project |
| Cursor | Modes, models, thought variants, and command tracker state belong to the connected Cursor process/account. A project path is only a catalog-probe seed. | Plugin |
| ACP base | One synthetic agent, current provider/model, and advertised commands belong to the connected ACP process. ACP is the base used by Cursor, not a separately registered release descriptor. | Plugin internally |

Codex intentionally remains project-scoped. Splitting its global model catalog
from project defaults and skills would require component-level persistence,
completeness, retention, and race handling. The small duplicated catalog is the
simpler and more truthful first-release tradeoff.

### Harness settings

- `HarnessesSettingsScreen` provides the overview and
  `HarnessManagementScreen` provides controls through a second nested route.
- Both screens construct `PluginManagementCubit` over the same singleton
  service and duplicate harness-card status presentation.
- Operational rows can remain visible when setup is not ready or a harness is
  disabled, producing facts or actions that are not meaningful in that state.
- Timeout editing and force confirmation still use Material `AlertDialog`
  presentation rather than the established Prego bottom-sheet language.

## Locked Product Decisions

### Aggregate route and refresh semantics

There is one new route:

```http
POST /session/options
POST /session/options?refresh=false
POST /session/options?refresh=true
```

- The body is the existing shared `PluginProjectIdRequest`.
- Missing `refresh` is dynamic: return a valid cache row immediately, or acquire
  only the selected plugin on cache miss and populate the cache.
- Exact `refresh=false` is cache-only and must never acquire or start a dormant
  plugin.
- Exact `refresh=true` is an explicit user refresh and may start only the
  requested plugin. It also passes an internal force-discovery mode so a live
  plugin cannot satisfy user refresh from its own stale catalog tracker.
- Any other parsed value returns HTTP 400. The existing router canonicalizes
  query parameters; this work does not broaden `RequestHandlerBase` solely to
  distinguish duplicate query spellings.
- A successful response is the new shared `SessionOptionsResponse`, containing
  required `Agents`, `ProviderListResponse`, and `CommandListResponse` values.
- Add `@Default(false) bool supportsSessionOptions` to shared
  `PluginListResponse`, with the required dated compatibility comment. A new
  bridge publishes `true`; old bridge payloads and the existing discovery-404
  fallback decode `false`.
- An explicit `refresh=false` cache-only miss, expired row, or invalidated
  project-path row returns HTTP 503 with typed
  `SessionOptionsErrorCode.cacheUnavailable`. A dynamic miss instead performs
  one activating fetch and is never encoded as three successful empty lists.
- Add shared `SessionOptionsErrorResponse` with required forward-safe
  `SessionOptionsErrorCode { cacheUnavailable, projectNotFound,
  refreshFailedRetained, refreshFailedUnavailable, unknown }`. Project absence
  returns 404/project-not-found. Every plugin or runtime capture failure
  normalizes to 502 and one of the two refresh-failure codes; plugin-provided 401
  is never forwarded because relay HTTP reserves 401 for Sesori authentication
  and rewrites that response before a repository can parse its body. The client
  maps the typed code and never infers domain outcome from status alone.
- An activating fetch failure returns `refreshFailedRetained` only while a row
  still passes scope, project-path, and retention validation. Dynamic loading
  returns that concurrently available row as a successful response; explicit
  refresh may preserve the client snapshot while reporting failure. A missing,
  expired, or path-invalidated row is deleted and produces
  `refreshFailedUnavailable`; the app clears any previously rendered options.

### Compatibility matrix

| Client / bridge | Behavior |
|---|---|
| New client / new bridge | An omitted `refresh` query is dynamic: serve a valid cache row, or fetch from exactly the selected harness on cache miss. `refresh=false` remains cache-only and `refresh=true` forces discovery. |
| Old client / new bridge | Existing `/agent`, `/provider`, and `/command` behavior is unchanged and can still start the requested harness. |
| New client / old bridge | Missing/false discovery capability becomes an explicit unsupported state without calling the aggregate route. Create remains available with null agent/model/variant/command. Explicit Refresh explains that legacy live requests may start the harness, then invokes the existing three routes. |

The legacy routes remain unchanged and do not write the new aggregate cache.
Successful session creation provides the automatic cache-seeding path for old
clients without coupling legacy repositories to the new service.

### Cache scope and invalidation

- Add `PluginSessionOptionsScope { plugin, project }` to the inert
  `BridgePluginDescriptor` contract.
- OpenCode and Codex descriptors declare `project`; Cursor declares `plugin`.
- `BridgeRuntimeRunner` carries the declaration into registered metadata and
  `PluginCompositionView`. Bridge core consumes an immutable scope map and never
  branches on plugin IDs.
- A plugin-scoped cache has one durable row for that bridge plugin.
- A project-scoped cache uses stable project ID plus the current resolved path.
  A path mismatch invalidates the old row rather than serving options captured
  for another directory.
- Project deletion cascades project rows. Plugin rows are independent of project
  deletion.
- Retention is 30 days, evaluated with injected `ServerClock`. Timestamps are
  never race tokens.
- Refresh triggers are dynamic aggregate cache miss, explicit aggregate refresh, successful session creation
  while that plugin generation is already active, and a dedicated
  generation-attributed `BridgeSseSessionOptionsChanged` plugin event. There is
  no all-project fanout, polling, or reinterpretation of generic session events.

### Client behavior

- The client performs one aggregate request rather than three requests.
- Plugin discovery carries bridge-level aggregate support. Route absence and
  project absence are never inferred from the same HTTP 404.
- No new persistent or process-wide client cache is added. The durable bridge
  is the cache authority; current cubit state may remain visible during a
  refresh failure.
- `NewSessionOptionsService` owns hidden/subagent filtering, available-model
  validation, default selection, variant derivation, and restored-selection
  revalidation.
- `NewSessionCubit` owns connection/plugin/project/user-intent orchestration,
  request-generation fencing, tracker writes, and state emission only.
- When no cache exists, the bridge automatically fetches from the selected
  harness. A failed fetch surfaces an explicit failure and keeps Create usable
  with backend defaults rather than showing an indefinite loading spinner.

### Harness settings destination

- `HarnessesSettingsScreen` becomes the only Harnesses settings screen.
- Remove `HarnessManagementScreen`, its route, and the overview-to-management
  navigation row.
- Keep one screen-owned `PluginManagementCubit`; do not merge plugin-management
  state with new-session option state.
- Preserve `PluginManagementService`'s authoritative `bridgeId` fencing. A
  bridge-identity change clears retained management presentation before the new
  bridge can receive actions or refreshes; bridge A's snapshot must never replay
  while commands route to bridge B.
- Setup not ready: show setup status/guidance and only capability-supported
  setup or eligibility actions that remain meaningful; hide runtime, work,
  restart, and timeout facts.
- Setup ready but disabled: show disabled status and the supported enable action;
  hide runtime, work, restart, and timeout facts.
- Setup ready and enabled: show only capability-supported operational facts and
  controls. Do not render meaningless `unknown` rows when absence is the honest
  presentation.
- Per-harness timeout choices are `Use bridge default`, `No timeout`, and
  `Custom`. Global timeout choices are `No timeout` and `Custom`.
- `No timeout` maps to canonical integer `0`; custom input must parse to a
  strictly positive integer. The service/cubit constructs the existing typed
  timeout requests.
- Timeout editing uses `showPregoBottomSheet`, `PregoInputField`, grouped radio
  semantics, and Prego buttons. Force confirmation uses a non-dismissible Prego
  sheet with explicit cancel and one destructive confirmation.
- Preserve current test keys where practical to keep widget-test churn focused
  on behavior rather than selectors.

## Architecture

### Touched workspaces

- `shared/sesori_shared`: additive plugin-list capability plus aggregate success
  and typed error wire models.
- `bridge/sesori_plugin_interface`: aggregate plugin model, completeness, and
  descriptor cache-scope contract.
- `bridge/sesori_plugin_opencode`: project-scoped aggregate service operation.
- `bridge/sesori_plugin_codex`: typed model-list API/repository and
  project-aware aggregate service operation.
- `bridge/sesori_plugin_acp`: model/provider state tracker and ACP option
  service used by Cursor.
- `bridge/sesori_plugin_cursor`: plugin-scoped aggregate service operation.
- `bridge/app`: runtime capture primitive, scope composition, Drift cache,
  repository/service policy, route, session-creation listener, and lifecycle.
- `client/module_core`: aggregate API/repository result, option-resolution
  service, cubit/state, DI, and compatibility behavior.
- `client/app`: New Session cache/refresh presentation and consolidated mobile
  Harnesses settings UI.
- `client/desktop` and `client/module_desktop_core`: downstream exhaustive
  analysis only; no new UI.

### Plugin option boundary

Add internal `PluginSessionOptions` with required agents, providers, commands,
and `PluginSessionOptionsCompleteness { partial, complete }`. Add the independent
internal enum `PluginSessionOptionsDiscoveryMode { reuse, refresh }` and
sealed `PluginSessionOptionsDiscoveryResult` variants `observed({required
PluginSessionOptions options})` and `failed()`. Add
`BridgePluginApi.getSessionOptions({required String projectId, required
PluginSessionOptionsDiscoveryMode discoveryMode})` returning that result.
Existing individual methods remain because released routes still use them.

Every top-level plugin facade delegates option decisions to Layer-3 service
ownership:

- `OpenCodeService.getSessionOptions` runs the existing service operations
  concurrently and preserves synthetic `compact` behavior.
- Codex first moves raw `model/list` parsing into Freezed DTOs under
  `api/models`, `CodexAppServerApi.listModels`, and `CodexModelRepository`.
  `CodexSessionService` owns model fallback, collaboration-agent/provider
  construction, project default selection, command fallback, completeness, and
  one aggregate call that issues at most one `model/list`.
- Add `AcpSessionConfigurationTracker` as the state owner for process defaults
  and per-session provider/model overrides. `AcpEventMapper` consumes it for
  translation and no longer acts as a tracker. `AcpSessionOptionsService`
  consumes tracker snapshots plus `AcpCommandTracker` to build the process-level
  aggregate. An ACP `available_commands_update` continues producing its existing
  session-refresh event and additionally produces
  `BridgeSseSessionOptionsChanged(sessionID:)`, carrying the backend session
  identity rather than ACP's directory-shaped project value. Durable seeding
  therefore reruns after the authoritative command advertisement without
  treating a path as a stable bridge project ID. The live-notification path and
  the replay deferral path both forward the dedicated event; replay must not
  retain the current `whereType<BridgeSseSessionsUpdated>()`-only filter.
- Expand/replace `CursorCommandService` with
  `CursorSessionOptionsService`, depending on `CursorCatalogService`,
  `CursorCatalogTracker`, `AcpCommandTracker`, and launch directory. One catalog
  ensure produces a coherent command/mode/model snapshot. `reuse` joins/uses the
  existing bounded catalog state for automatic seeding. `refresh` invokes a new
  bounded forced-discovery operation that bypasses complete/exhausted/retried
  short-circuits, joins any forced probe already in flight, retains last-good
  tracker data on failure, and returns the distinct `failed` result rather than
  a successful `partial` observation or a newly timestamped stale snapshot.

An unexpected source error is never swallowed. Plugins that deliberately
degrade to known fallback data return `observed(partial)`; the bridge service
decides whether that observation may replace retained data. A failed forced
discovery returns `failed` and never enters completeness replacement policy.

### Bridge persistence and ownership

Add `session_options_cache` at the next Drift schema version. Each row contains:

- plugin ID, declared scope, and non-empty owner ID;
- nullable project-ID foreign key and nullable captured project path, present
  together only for project scope;
- non-null revision, capture timestamp, and completeness;
- non-null JSON for agents, providers, and commands; and
- primary key `(plugin_id, scope, owner_id)` plus a CHECK enforcing the two
  valid scope shapes. No empty string represents missing project data.

`SessionOptionsCacheKey` is a sealed Layer-2 model under
`bridge/repositories/models`: `plugin(pluginId)` or
`project(pluginId, projectId, projectPath)`. The Layer-3 service constructs it;
the repository does not depend upward on service models.

`SessionOptionsRepository` requires `PluginRuntime`, `ProjectsDao`, `SessionDao`,
and `SessionOptionsCacheDao`. It owns only project/path lookup, backend-session
binding lookup, typed JSON mapping, plugin aggregate capture, raw persistence
calls, and generation-fenced CAS. It contains no expiry, completeness, or
retention policy and no clock.

Add `PluginRuntime.useWithGeneration`, mechanically mirroring `use` while
returning the acquired generation. Activating capture uses it; active-only
capture uses `useIfActive`. Both observations later commit through
`commitCurrentGeneration`, so backend replacement cannot publish an obsolete
snapshot. Runtime activation and plugin discovery freshness remain independent
enums rather than one overloaded boolean.

`SessionOptionsService` requires the repository, immutable descriptor scope map,
`ServerClock`, and retention duration. It owns key resolution, dynamic/cache-only read,
path/expiry invalidation, per-key refresh coalescing, capture-mode choice,
completeness comparison, last-good retention, CAS retry policy, and recovered
failure observability.

Before any refresh, the service classifies and, when needed, deletes the stored
row. Only a row that still matches scope/project path and remains inside
retention is eligible for last-good replay. A repository/plugin `failed` result
with that valid row becomes refresh-failed-retained; the same failure after
absence or invalidation becomes refresh-failed-unavailable. Invalid data is
never resurrected by a failed capture. Every project-scoped invalidation
re-resolves the authoritative path immediately before its revision-fenced delete
so a stale reader cannot delete a same-revision row published for a moved path.

The service permits only these production combinations:

```text
dynamic load            -> valid cache, otherwise may activate + PluginSessionOptionsDiscoveryMode.reuse
explicit refresh        -> may activate + PluginSessionOptionsDiscoveryMode.refresh
session-created trigger -> active only  + PluginSessionOptionsDiscoveryMode.reuse
options-changed trigger -> active only  + PluginSessionOptionsDiscoveryMode.reuse
cache-only read         -> no plugin capture
```

`loadDynamic` resolves the cache key/project path once, returns a valid row
immediately, and otherwise enters the existing per-key coordinator with reuse
intent, `mayActivate`, `PluginSessionOptionsDiscoveryMode.reuse`, no expected
generation, and `automatic: false` so HTTP callers receive typed retained or
unavailable failures rather than trigger-only no-op semantics. Project absence
returns directly. Expired/path-invalid rows are deleted before capture. If a
concurrent operation publishes a valid row while the dynamic capture fails,
`loadDynamic` re-reads and returns that row as `available`; otherwise the
existing retained/unavailable 502 mapping applies.

Coalescing is intent-aware per cache key:

- reuse joins an in-flight reuse or forced refresh;
- dynamic cache miss uses reuse intent with non-automatic HTTP failure outcomes;
- explicit refresh joins an in-flight forced refresh;
- explicit refresh arriving during reuse queues exactly one forced operation
  after reuse and awaits that forced result; and
- additional explicit refreshes join the same forced tail.

Therefore a user Refresh can never complete from the automatic reuse future
without executing forced discovery.

Completeness replacement is exact:

```text
complete -> may replace complete or partial
partial  -> may seed an empty cache
partial  -> never replaces retained partial or complete
```

The service reads the expected revision, captures, applies policy, and asks the
repository to commit. On a CAS conflict it re-reads and reapplies policy to the
same observation, retries once when replacement is still valid, and otherwise
returns the newest retained row. A second conflict retains the newest row and is
logged; policy never moves into the DAO or repository.

`PostSessionOptionsHandler` is the HTTP consumer. Expected cache/project/refresh
outcomes are mapped to the shared typed error body before the generic request
handler can collapse them to status plus plain text.

`SessionOptionsCreationRefreshListener` consumes `SessionBindingsCommitted`,
handles only `sessionCreation`, and invokes active-only refresh for that event's
project and plugin. Extend the existing event with required project ID; both
publication sites already know it.

`SessionOptionsChangedRefreshListener` independently consumes
generation-attributed runtime events, accepts only current-generation
`BridgeSseSessionOptionsChanged(sessionID:)`, and calls
`SessionOptionsService.refreshActiveOnlyForBackendSession`. The service asks its
repository to resolve backend session plus plugin ID through `SessionDao` to the
stable stored project ID before refreshing. If no binding exists yet, it does
not infer identity from the ACP directory; the later session-creation commit is
the seed trigger. The session-event pipeline
explicitly consumes this internal event without mapping it to client SSE;
Orchestrator remains the only client-SSE decision owner. Each listener owns one
trigger subscription and its disposal.

### Step 4 concrete implementation map

The current codebase maps the Step 4 boundary to these source changes:

- In `shared/sesori_shared`, add `session_options_response.dart` and
  `session_options_error_response.dart` beside the existing Sesori response
  models, export both from `sesori_shared.dart`, and extend
  `plugin_list_response.dart` with the dated `supportsSessionOptions` default.
  The error DTO applies `unknownEnumValue: SessionOptionsErrorCode.unknown` at
  JSON decoding; tests live under `test/models/` and cover round trips plus
  omitted and unknown compatibility values.
- In `bridge/app/lib/src/api/database`, add
  `tables/session_options_cache_table.dart` and
  `daos/session_options_cache_dao.dart`, then register both in `database.dart`.
  Version 12 creates only the new table. The nullable project foreign key
  targets `projects_table.project_id` with cascade deletion; the table-level CHECK
  enforces plugin rows with null project fields and project rows with matching
  non-null owner/project identity and a non-empty captured path. Generate the
  Drift database, DAO, row, schema-v12 JSON snapshot, and migration-step
  sources. Extend `test/drift/default/migration_test.dart` for v11-to-v12
  structure, constraints, cascade deletion, and plugin-row survival. Open a v11
  fixture through `AppDatabase` and call `validateDatabaseSchema()` against the
  current declarations; do not generate or commit `schema_v12.dart` merely to
  duplicate the entire current database in this review series.
- Put the sealed `SessionOptionsCacheKey` in
  `bridge/repositories/models/session_options_cache_key.dart`. Add
  `SessionOptionsRepository` beside the existing Layer-2 repositories and keep
  the DAO mechanical: exact-key read/delete plus expected-revision insert or
  update. The repository resolves project rows and backend-session bindings,
  maps the three shared DTOs to and from their JSON columns, captures plugin
  aggregates, and wraps persistence in runtime generation fencing.
- Add `PluginRuntime.useWithGeneration<T>` beside `use` and `useIfActive`. It
  uses the same activating acquisition and authentication handling as `use`,
  accepts the same API-only body, and returns `({T value, int generation})`
  without entering a durable commit; the repository later calls
  `commitCurrentGeneration` around the short CAS.
  Runtime tests extend the existing `plugin_runtime_test.dart` suite rather than
  creating a second runtime harness.
- Add `SessionOptionsService` under `bridge/services/`. Its public operations
  are dynamic load, cache-only load, explicit refresh, active-only refresh for a known
  project, and active-only refresh resolved from plugin/backend-session
  identity. Internal sealed outcomes distinguish available, cache unavailable,
  project not found, retained refresh failure, unavailable refresh failure, and
  automatic no-op. The per-key coordinator stores at most one running future
  and one shared forced tail; completed entries are removed so this is not a
  durable registry.
- Extend `RegisteredPluginMetadata` and `PluginCompositionView` in
  `services/plugin_lifecycle_service.dart` with the descriptor-declared options
  scope. `bridge_runtime_runner.dart` copies `descriptor.sessionOptionsScope`
  during registration, and `Orchestrator.create()` passes the resulting
  immutable map to `SessionOptionsService`; no downstream code imports concrete
  plugin descriptors or checks plugin IDs.
- Add `PostSessionOptionsHandler` beside the bridge handlers. It extends
  `RequestHandlerBase`, rather than `BodyRequestHandler`, so expected typed
  failures can return JSON bodies before generic plain-text normalization. It
  reuses `PluginProjectIdRequest.fromJson`, accepts only missing, exact `false`,
  or exact `true` refresh values from the router's canonical query map, and
  dispatches them to dynamic load, cache-only load, and explicit refresh,
  respectively. It maps every service outcome to the locked
  200/400/404/502/503 contract.
- Add `projectId` to `SessionBindingsCommitted`; both current publication sites
  already have the stable value (`createSession`'s requested project and
  `_persistNativeRootSessions`' resolved project). Existing session-event
  dispatch remains unchanged apart from carrying the extra field.
- Add `SessionOptionsCreationRefreshListener` and
  `SessionOptionsChangedRefreshListener` under `lib/src/listeners/`. They
  independently subscribe to `SessionRepository.bindingCommits` and
  `PluginRuntime.backendEvents`. The options-change listener filters the raw
  generation-attributed event and checks `isCurrentGeneration` before service
  dispatch; it does not consume normalized client SSE. Wire both in
  `Orchestrator.create()`, start them with the existing source listeners, retain
  them on `OrchestratorSession`, and dispose them in the failure-isolated
  teardown batch.
- Update `GetPluginsHandler` to publish `supportsSessionOptions: true`, register
  the aggregate handler in the one shared `RequestRouter`, and pass the same
  router/service instances to relay and debug flows through the existing
  Orchestrator composition. The client discovery-404 fallback needs no Step 4
  logic change because the shared DTO default decodes and constructs it as
  false; add/adjust its focused compatibility assertion if compilation does not
  already prove that path.

Implement in dependency order: shared wire contracts, Drift persistence,
runtime/repository capture, service policy, handler/capability, then listeners
and Orchestrator lifecycle. Generate only after source models and schema settle,
then run focused tests after each boundary before the final owning-package
verification.

### Client layers

`SessionApi` adds the aggregate POST and names its request intent
`forceRefresh`: false omits the query for dynamic loading, while true sends
`refresh=true`. `SessionRepository` and `NewSessionOptionsLoadMode` use the same
dynamic/forced terminology. `PluginRepository`
maps the additive `supportsSessionOptions` discovery fact, defaulting false for
older bridges, and `NewSessionPluginDiscovery` carries that bridge-level fact to
the composer. `SessionRepository` removes its provider-only cache, maps aggregate
200 to supported and parses every non-success
`SessionOptionsErrorResponse`: cache-unavailable, project-not-found,
refresh-failed-retained, and refresh-failed-unavailable map to distinct
repository variants regardless of HTTP status; unknown/malformed bodies map to
ordinary failure. It retains the three legacy methods solely for explicit
old-bridge refresh. `NewSessionOptionsService` receives the discovery capability:
false returns unsupported without an aggregate call; true permits the aggregate
call and never converts its typed project failure into legacy fallback.

No aggregate-route 404 triggers legacy fallback. Old bridges are selected by
the additive discovery capability (including its missing-field default and the
plugin-discovery 404 compatibility snapshot). Old apps continue using the
unchanged live POST `/agent`, `/provider`, and `/command` handlers on new
bridges. Those POST routes are not deprecated because current Session Detail
still consumes them; only the already-deprecated parameterless GET `/agent`
route is legacy-only.

`NewSessionOptionsService({required SessionRepository sessionRepository,
required DefaultModelSelector defaultModelSelector})` owns:

- capability-gated aggregate load and explicit old-bridge fallback;
- visible-agent filtering (`!hidden` and not subagent);
- selectable-model validation (`isAvailable`);
- default agent/model precedence while preserving backend order;
- model-specific variants in source order, excluding exact sentinel `none`;
- restored agent/model/variant and staged-command revalidation; and
- typed unsupported, unavailable, failure, retained-refresh-failure, and
  refresh-failure-that-clears-options results.

`NewSessionCubit` receives the service and emits a composed sealed options-load
state instead of coordinating loading booleans and empty-list sentinels. Explicit
user selections alone are written to `NewSessionSelectionTracker`; computed
defaults are not persisted as intent. Existing connection and plugin-switch
generation fencing remains in the cubit.

The mobile screen renders dynamically loaded or cached options, old-bridge
guidance, and retained-data refresh errors. An unavailable dynamic load uses
load-specific state and guidance, while an unavailable forced refresh retains
explicit Refresh guidance. Backend plugin IDs, model names, agent names,
commands, paths, and project identity never enter analytics or backend-neutral
UI decisions.

## Delivery Sequence

| Step | Branch | Exact PR title | Estimate | Review boundary |
|---|---|---|---:|---|
| 1/6 | `multi-plugin-release-prep` | `[multi-plugin-release-prep] docs: plan multi-plugin release preparation [step 1/6]` | 350-550 | Final durable plan and tracker only. |
| 2/6 | `multi-plugin-release-prep-codex-options` | `[multi-plugin-release-prep] refactor(codex): type session option discovery [step 2/6]` | 800-1,150 | Typed `model/list` API/repository, service-owned agent/provider/default/fallback behavior, and facade delegation without changing wire routes. |
| 3/6 | `multi-plugin-release-prep-plugin-options` | `[multi-plugin-release-prep] feat(bridge): aggregate scoped plugin options [step 3/6]` | 950-1,350 | Internal aggregate/completeness/scope contract; OpenCode, Codex, ACP, and Cursor service ownership; ACP configuration tracker and authoritative options-change event. |
| 4.A/6 | `multi-plugin-release-prep-bridge-contracts` | `[multi-plugin-release-prep] feat(bridge): add session option wire contracts [step 4.A/6]` | 900-1,250 | Shared success/error/capability contracts, descriptor-scope composition, and activating generation capture. |
| 4.B/6 | `multi-plugin-release-prep-cache-schema` | `[multi-plugin-release-prep] feat(bridge): persist scoped session option rows [step 4.B/6]` | 1,450-1,650 | Drift v12 table, standalone DAO, generated runtime database, migration steps, and current-schema smoke coverage. |
| 4.C/6 | `multi-plugin-release-prep-cache-verification` | `[multi-plugin-release-prep] test(bridge): verify session option cache migration [step 4.C/6]` | 1,300-1,550 | v12 JSON snapshot, v11 upgrade/schema validation, CHECK/FK behavior, and DAO CAS tests without a generated full-schema Dart fixture. |
| 4.D/6 | `multi-plugin-release-prep-cache-repository` | `[multi-plugin-release-prep] feat(bridge): capture scoped session options [step 4.D/6]` | 800-1,050 | Cache key, typed JSON mapping, project/binding lookup, plugin capture, and generation-fenced CAS repository. |
| 4.E/6 | `multi-plugin-release-prep-cache-service` | `[multi-plugin-release-prep] feat(bridge): apply session option cache policy [step 4.E/6]` | 1,100-1,300 | Retention/path validation, completeness replacement, failure retention, CAS retry, and intent-aware coalescing service. |
| 4.F/6 | `multi-plugin-release-prep-cache-route` | `[multi-plugin-release-prep] feat(bridge): expose cached session options [step 4.F/6]` | 850-1,150 | Aggregate route/capability, stable binding attribution, automatic refresh listeners, and Orchestrator lifecycle wiring. |
| 5.A/6 | `multi-plugin-release-prep-client-options` | `[multi-plugin-release-prep] feat(client): add cached session option layers [step 5.A/6]` | 1,350-1,750 | Aggregate API/repository mapping, provider-cache removal, repository-owned catalogs, and service-owned option policy including explicit old-bridge fallback. |
| 5.B/6 | `multi-plugin-release-prep-client-options-ui` | `[multi-plugin-release-prep] feat(client): use cached session options [step 5.B/6]` | 1,650-2,150 | Repository-mapped plugin source, independent selection intent, composed cubit state, generation fencing, and New Session mobile UI. |
| 5.C/6 | `multi-plugin-release-prep-dynamic-options` | `[multi-plugin-release-prep] feat(bridge): dynamically load missing session options [step 5.C/6]` | 180-320 | Tri-state aggregate query semantics, dynamic cache-miss fetch, client terminology, and compatibility verification without changing legacy routes. |
| 6/6 | `multi-plugin-release-prep-harness-settings` | `[multi-plugin-release-prep] refactor(app): consolidate Harness settings [step 6/6]` | 850-1,200 | One Harnesses screen/cubit, capability/setup-aware visibility, route removal, and Prego timeout/force sheets. |

## Per-Step Verification

### Step 1/6

- Validate plan/tracker consistency, fixed titles/totals, and Markdown with
  `git diff --check`.
- No Dart or Flutter suites for the documentation-only PR.

### Step 2/6

- Codex typed model-list decoding, hidden filtering, display fallback, reasoning
  effort order, project default precedence, configured fallback, command
  fallback, and exactly-one-`model/list` tests.
- Codex package tests and `dart analyze --fatal-infos`.
- Aristotle implementation review because API/repository/service ownership moves.

### Step 3/6

- Plugin-interface contract and descriptor-scope tests; every implementation
  updated in lockstep.
- Aggregate tests in OpenCode, Codex, ACP, and Cursor. Cursor proves one catalog
  ensure and plugin-global output; ACP proves mapper/tracker separation and an
  authoritative command advertisement emits the dedicated options-change event
  with backend session identity through both live and replay deferral paths.
- Cursor tests prove `reuse` honors existing bounded discovery while `refresh`
  forces one joined bounded probe despite complete/exhausted/retried tracker
  state. Forced-probe failure returns the distinct failed result, never
  `observed(partial)` or retained data labeled as newly discovered.
- Focused package tests and fatal analysis for every touched plugin package.
- Aristotle implementation review for shared plugin boundaries and state ownership.

### Step 4.A/6

- Shared success/error JSON round trips, unknown error fallback, and
  omitted/false/true discovery capability compatibility.
- Runtime tests for activating generation capture and immutable descriptor scope
  composition. Run shared and bridge-app focused suites plus fatal analysis.

### Step 4.B/6

- Current-schema table/DAO smoke coverage and generated Drift runtime output.
- Bridge-app focused persistence tests and fatal analysis.

### Step 4.C/6

- Open a generated v11 fixture through `AppDatabase`, migrate it, and use
  `validateDatabaseSchema()` against current declarations.
- Verify the CHECK constraint, FK cascade, plugin-row survival, exact-key DAO
  reads/deletes, and revision CAS. Run focused migration/persistence suites and
  fatal analysis.

### Step 4.D/6

- Repository tests cover project/binding resolution, typed JSON round trips,
  activating versus active-only capture, and generation-fenced commits.
- Run focused repository/runtime tests, fatal analysis, and Aristotle review.

### Step 4.E/6

- Service tests cover cache-only no-start, path/expiry invalidation, retained
  versus unavailable failure, completeness, CAS conflicts, stale generation,
  and one queued forced tail.
- Run focused service/repository tests, fatal analysis, and Aristotle review.

### Step 4.F/6

- Handler tests cover missing/false/true/invalid refresh and every typed status.
- Listener tests cover creation, current/stale options-change events, generic
  events, moved projects, pre-binding skips, and disposal.
- Run handler/listener/Orchestrator suites, full bridge-app tests, fatal analysis,
  and Aristotle review.

### Step 5.A/6

- API path/body/query and response parsing tests.
- Repository mapping covers supported and every typed error code independently
  of HTTP status, including normalized plugin-auth failure without
  `ApiError.notAuthenticated`, with no provider-only cache remaining.
- Service tests for filtering, default precedence, unavailable models, variant
  preservation/drop, command revalidation, cache miss, retained refresh failure,
  and explicit old-bridge fallback.
- Run module-core fatal analysis and Aristotle implementation review for the new
  API/repository/service ownership.

### Step 5.B/6

- Plugin repository/service tests prove capability-to-source mapping and old
  discovery fallback without exposing the wire response above Layer 2.
- Service/cubit tests prove discovery source false returns unsupported without
  an aggregate call.
- Cubit tests preserve reconnect, bridge/plugin switch, stale-completion fencing,
  user selection tracking, and default-backed session creation.
- Mobile tests cover Refresh, unsupported guidance, cache-miss creation, and
  retained options after valid-cache refresh failure, plus immediate option
  clearing after expired/path-invalid cache refresh failure. Run
  module-core/mobile/desktop fatal analysis and Aristotle implementation review.

### Step 5.C/6

- Handler/service tests prove omitted `refresh` serves valid cache data and
  fetches only on cache miss, `refresh=false` remains cache-only, and
  `refresh=true` remains forced discovery.
- Compatibility tests prove new-client/old-bridge capability fallback still
  uses the legacy routes only after explicit Refresh, while old clients keep
  using the unchanged live legacy handlers on new bridges.
- Client API/repository terminology distinguishes dynamic load from forced
  refresh without adding a transport field or changing old-peer parsing.
- Run bridge-app and module-core focused tests plus fatal analysis in bridge-app,
  module-core, mobile, and desktop.

### Step 6/6

- Route tests prove the management sub-route is removed and Harnesses navigation
  remains intact.
- Widget tests cover setup-not-ready, disabled, enabled, capability-limited,
  loading/unsupported/failure, action/refresh error, and close navigation.
- Existing service/cubit tests continue proving an authoritative `bridgeId`
  change clears retained management state before actions target the new bridge.
- Timeout tests cover inheritance, no-timeout `0`, strictly positive custom
  values, invalid/negative input, and clear override.
- Force cancel/confirm sends zero/one force requests and uses Prego sheets rather
  than `AlertDialog`.
- Localization generation, focused mobile tests, and module-core/mobile/desktop
  fatal analysis. This localized UI refactor does not require Aristotle unless
  implementation changes routes, state ownership, or another architecture seam
  beyond this plan.

## Analytics Decision

Do not add a product analytics event in this series. A Refresh tap is an
implementation/recovery action rather than an approved activation or retention
metric, and reporting plugin/model/agent/command identity is forbidden. Existing
session-creation outcomes remain the authoritative product signal. Reconsider
only if a concrete product decision requires bounded cache-availability or
refresh-outcome reporting after the active user-analytics foundation lands.

## Risks And Mitigations

| Risk | Treatment |
|---|---|
| A valid cache unexpectedly starts a dormant plugin | Dynamic load returns a valid row before runtime acquisition; explicit `refresh=false` remains covered by a no-start test. |
| Concurrent cache fill is hidden behind dynamic fetch failure | Dynamic load re-reads a retained valid row after a failed coalesced capture and returns it as available. |
| Project options served for a moved directory | Store captured path and invalidate on mismatch. |
| Refresh failure leaves expired/path-invalid options visible | Validate and delete before capture; unavailable failure clears client options, while retained failure is reserved for a still-valid row. |
| Old generation overwrites current data | Capture runtime generation and fence every CAS commit with `commitCurrentGeneration`. |
| A partial refresh regresses a different option source | Partial observations seed only an empty cache and never replace retained partial or complete data; only a complete aggregate advances an existing row. |
| Late concurrent refresh downgrades data | Service-owned completeness comparison plus expected-revision CAS and one policy retry. |
| Codex duplicates its global model catalog per project | Accept the small duplication to preserve project defaults and skills without mixed-scope component caches. |
| Cursor cache multiplies by project | Descriptor-declared plugin scope produces one durable Cursor row. |
| Explicit Cursor refresh reuses a complete/exhausted tracker | Internal discovery mode requires one bounded forced probe for user refresh; automatic captures retain bounded reuse semantics. |
| Forced-probe failure is confused with successful partial fallback | The plugin returns a distinct failed discovery result; only successful known fallback is `observed(partial)`. |
| Explicit refresh joins an in-flight automatic reuse | Intent-aware coalescing queues one forced tail and makes every overlapping explicit caller await it. |
| Cursor session creation seeds before ACP commands arrive | The authoritative `available_commands_update` emits a dedicated generation-attributed options-change event and a separate listener refreshes the plugin-scoped row. |
| ACP replay mutates commands without refreshing the cache | Replay deferral forwards the same dedicated options-change event as the live notification path. |
| ACP event path is mistaken for stable project identity | The event carries backend session ID; the service resolves its persisted binding and never treats ACP's directory value as project ID. |
| ACP option code depends on mutable mapper state | Move provider/model state into `AcpSessionConfigurationTracker`; mapper and service consume the tracker. |
| New client confuses old-route 404 with project-not-found 404 | Additive discovery capability identifies old bridges before any aggregate call; the typed error body identifies project failure on a capable bridge. |
| Plugin statuses collide with cache/project/Sesori-auth statuses | Plugin/runtime capture failures normalize to 502 with retained/unavailable refresh-failure codes, preserving the typed body and reserving 401 for Sesori authentication. Unknown or malformed errors fail explicitly. |
| Settings consolidation changes capability enforcement | Keep existing service/cubit command paths; only one thin screen consumes declared capabilities. |
| Generated migration/model output obscures logic | Keep every Step 4 sub-PR near 1,500 total changed lines and separate runtime generation from migration verification. |

## Review Record

- The initial architecture review rejected facade-owned aggregation,
  repository-owned retention policy, cubit-owned option transformations,
  callback clocks, and Codex raw transport parsing. This plan moves each concern
  to the service/repository/API boundary described above.
- After the user selected query-driven refresh and scope-aware caching, the
  specificity review was expanded with complete workspaces, files, constructors,
  status mapping, runtime flow, trigger ownership, and compatibility behavior.
- The resulting architecture review found two ownership violations. Both are
  applied here without another approval-only review, as required by repository
  workflow: `SessionOptionsCacheKey` lives in Layer 2 rather than service models,
  and ACP provider/model state moves from `AcpEventMapper` into
  `AcpSessionConfigurationTracker`.
- This document does not claim that the corrected version was reviewer-approved.
  Each architecture-bearing implementation PR still receives implementation
  review against its concrete Git diff.
- After the user froze oversized PR #620, the revised 4.A-through-4.F stack and
  lightweight current-schema migration validation received a fresh architecture
  plan review. The reviewer approved the dependency order, ownership, PR
  boundaries, and verification strategy with no findings.

## Completion

The plan completes after all six PRs merge, New Session switching reads durable
scope-correct options and dynamically starts only the selected harness on cache
miss, explicit cache-only and forced-refresh semantics plus old-bridge
degradation are verified, both cache scopes survive restart, and the single
Harnesses settings page passes capability/setup-aware mobile verification.
