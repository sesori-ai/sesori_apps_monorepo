# Parallel Plugins - Implementation Plan

> Status: **implementation in progress**.
> [`ARCHITECTURE.md`](ARCHITECTURE.md) owns the durable product direction. This
> document owns the implementation sequence, current pointer, concrete design, rollout, and
> verification. Keep both documents consistent when implementation findings
> change an assumption.

## Current Pointer

- **Last completed stage:** Stage 8 - client plugin and model/agent selection
- **Next up:** Stage 9 - performance gate and cleanup
- **Runtime default:** OpenCode remains the one-plugin default; ordered multi-plugin selection is active
- **Catalog projection version:** 1
- **Stage 3A implementation base:** `main` at `1773691d` (audited 2026-07-15)
- **Stage 3B implementation base:** `main` at `7c8b6440` (audited 2026-07-16)
- **Stage 3C implementation base:** `main` at `72ac20f4` (audited 2026-07-16)
- **Stage 4 implementation base:** `main` at `86816cee` (audited 2026-07-16)
- **Stage 5 implementation base:** `main` at `5a76c0c4` (audited 2026-07-17)
- **Stage 6 implementation base:** stacked Stage 5 at `b8d6dd5f` (audited 2026-07-17)
- **Stage 7 implementation base:** stacked Stage 6 at `297fecc3` (audited 2026-07-17)
- **Stage 8 planning base:** stacked Stage 7 at `2482e15d` (audited 2026-07-17)
- **Stage 8 implementation base:** approved Stage 8 plan at `abd24c3e` (audited 2026-07-17)

Resume from the first unchecked row in the status index whose prerequisites are
complete. Before starting that row, reconcile the index against merged PRs on
`main`, read findings from earlier rows, write a PR-level implementation plan,
and run `aristotle-plan-review`. Run `aristotle-impl-review` before opening every
implementation PR. Each PR updates the pointer, its status row, findings, plan
deltas, and risk register in the same diff.

## 1. Goal and Scope

Run the enabled OpenCode, Codex, and Cursor plugins concurrently in one bridge.
The bridge presents one durable project catalog, mixed root-session lists, and a
durable child-task hierarchy. Plugin outages degrade only controls routed to
that plugin; they do not remove catalog data or prevent browsing.

The work includes:

- bridge-owned project, session, and child projections;
- stable Sesori session identities separated from backend handles;
- explicit, observable per-plugin import;
- independent plugin lifecycle, health, event streams, and routing;
- explicit plugin selection for session creation and plugin-scoped composer
  data; and
- client selection of a plugin and that plugin's agents, models, and commands.

The non-goals in `ARCHITECTURE.md` remain binding. In particular, this work does not add
continuous backend sync, cross-plugin session migration, transcript storage,
teams behavior, or offline client caching.

## 2. Re-Audit Findings

The Stage 7 planning references were rechecked against the stacked Stage 6 base
at `297fecc3`. Findings in completed stage sections remain historical evidence;
they do not describe the current list, identity, import, or event paths.

- Stable Sesori session ids, plugin ids, and backend handles are already
  separate and durable. Project/root/detail/child list requests now read the
  catalog only; they neither enumerate a plugin nor persist a list result.
- `GetSessionsHandler` applies bridge-owned pending-title/PR enrichment after
  the DAO-backed read. `GetSessionStatusesHandler` already delegates only to
  `SessionRepository`; neither handler calls a plugin API directly.
- Codex catalog enumeration already crosses its plugin-owned worker-isolate
  boundary. The old main-isolate scan finding is historical Stage 1/5 evidence.
- `RequestRouter` already accepts only an ordered handler list and selects the
  first match. It has no plugin dependency and must remain generic in Stage 7.
- `DebugServer` already receives the orchestrator's exact router. Stage 7 keeps
  that shared router, moves source-aware normalization solely through the
  orchestrator, and gives debug the orchestrator's already-mapped local wire
  stream; it creates no debug-specific plugin routing/listeners.
- Runtime startup still selects one descriptor/config, `PluginManager` still
  owns a start callback and rejects a second active id, and one API is still
  injected through plugin-aware repositories and event composition. Those are
  the current Stage 7 cutover seams.
- One `SessionEventTracker` currently has a global 1,024-entry eviction order,
  so one plugin could evict another plugin's pending events. The binding and
  deletion streams are already global; only raw plugin event streams multiply.
- `CatalogImportService` and `CatalogImportRepository` still own one selected
  plugin operation, while the shared import DTOs are already plugin-attributed.
- The interface has three production descriptor implementors: OpenCode, Codex,
  and Cursor. Their signatures already support parallel composition; Stage 7
  needs documentation corrections, not a contract signature change.

## 3. Locked Design Decisions

### 3.1 Identity

Sessions use three distinct values:

| Value | Meaning |
|---|---|
| `session_id` | Sesori-owned stable identity exposed to clients |
| `plugin_id` | Owning plugin and execution-routing key |
| `backend_session_id` | Opaque handle passed only to that plugin |

The migration preserves every existing `session_id` and backfills
`backend_session_id = session_id`. Existing routes, notifications, drafts, pull
request links, and deep links therefore keep working. After the identity cutover,
newly created or imported bindings receive a random Sesori id; uniqueness is
enforced on `(plugin_id, backend_session_id)`.

Stage 3C makes every root-session path binding-aware while keeping new
production bindings identity-preserving. Stage 4 activates random Sesori ids
together with exhaustive event translation and durable child binding. This
keeps each intermediate release honest: no random root id ships while current
event or child-operation paths can still carry backend handles.

There is no backend-id fallback after cutover. Every session-addressed request
must resolve a stored binding. A missing row is a 404; an unavailable owning
plugin is a 503. This prevents ambiguous cross-plugin discovery and preserves
the rule that location is never inferred from an unknown durable id.

Projects keep the existing `project_id` and authoritative `path` model. This
work does not introduce project UUIDs. Project metadata remains shared across
plugins: hiding, renaming, and setting a base branch affects the one project
card for that directory.

The local catalog does not persist a placeholder owner. A concrete multi-owner
requirement will add ownership through an explicit migration and backfill.

### 3.2 Plugin Boundary

`PluginProject` gains a required `directory`. The bridge merges projects on a
normalized declared directory and no longer assumes a native plugin id is a
path. Plugin-defined project ids and backend session handles remain inside the
plugin/repository boundary.

Source plugin identity is attached by the bridge when it subscribes. Stage 4's
existing captured-input typedef remains:

```text
SourcedBridgeEvent = (pluginId, projectionUpdatedAt, raw BridgeSseEvent)
```

Stage 7 adds the dispatcher-output typedef
`NormalizedSourcedBridgeEvent = ({String pluginId, BridgeSseEvent event})` and
keeps that envelope through `OrchestratorSession._processPluginEvent`. The
orchestrator alone unwraps and maps it to `SesoriSseEvent`; `DebugServer`
receives the orchestrator's already-mapped `Stream<SesoriSseEvent>` local wire
events. Both sourced records are app-internal, not new plugin event types or
relay fields. Shared events continue to contain Sesori session ids only.

The existing sealed `NativeProjectsPluginApi` /
`BridgeDerivedProjectsPluginApi` split remains the capability declaration for
the capabilities current backends actually differ on. No all-true capability
flags are added. A new optional capability is introduced only with a concrete
backend that cannot implement an existing operation; this avoids a speculative
matrix that duplicates the mandatory API contract.

### 3.3 Repository Shape

Keep one repository per domain. Do not create per-plugin repositories followed
by a same-layer aggregate repository.

- `ProjectRepository` owns catalog project queries, project mapping, and
  bridge-owned project mutations. Normal reads do not call plugins.
- `SessionRepository` owns catalog session queries and mapping, binding
  resolution, targeted plugin operations, and exact session projection writes.
- `CatalogImportRepository` owns per-plugin enumeration, maps plugin DTOs into
  import rows, and applies a complete snapshot through DAOs. It does not depend
  on `ProjectRepository` or `SessionRepository`.
- `ProviderRepository`, `AgentRepository`, `QuestionRepository`,
  `PermissionRepository`, `HealthRepository`, and `WorktreeRepository` receive
  the enabled plugin API map where needed. Session-scoped operations first
  resolve the row through `SessionDao`; project-scoped composer operations take
  an explicit/default plugin id and the persisted project path.

Repositories may depend on plugin APIs because `BridgePluginApi` is a Layer 1
data source. Services and handlers never do.

### 3.4 Lifecycle Shape

Replace `PluginManager` with `PluginLifecycleService`. The service is the sole
runtime-state authority: it owns ordered enabled/unavailable metadata, every
returned `BridgePlugin`, status subscriptions, operational API publication, one
internally consistent `PluginCompositionView`, and idempotent concurrent
shutdown. It does not own or invoke availability, provisioning, descriptor
start callbacks, host construction, or process construction.

`BridgeRuntimeRunner` remains the process startup orchestrator:

1. Resolve and validate the ordered enabled descriptor set before I/O.
2. Authenticate.
3. Probe all descriptors concurrently before taking the startup mutex.
4. If none are available, preserve the current behavior that avoids replacing
   an already healthy resident bridge.
5. Acquire the cross-instance startup mutex once and enforce one live bridge
   once.
6. Construct one host and state directory per startable plugin.
7. Provision plugins sequentially in configured order. Invoke each descriptor's
   `start(host)` as soon as its provisioning phase settles, and immediately
   register that future with `PluginLifecycleService`; starts may overlap later
   provisioning and each other.
8. Await every `registerStart` lifecycle-settlement future, not merely the raw
   descriptor futures. One failed/degraded plugin does not cancel a successful
   plugin.
9. Read one `PluginLifecycleService.compositionView` and build one bridge
   runtime from it. If availability justified takeover but every start then
   fails, still compose the catalog/relay runtime with an empty operational map
   and the failed lifecycle metadata.

The mutex remains held through provisioning and all lifecycle start
settlements, preserving the current descriptor contract. Narrowing runtime-
install locks is a separate foundation change only if measured cold-start
contention proves it necessary.

`PluginLifecycleService` is constructed without collaborators. After selection
validation the runner registers the complete known-id set and ordered enabled
display/default metadata once, then calls `registerUnavailable(...)` for a
failed availability probe or
`registerStart(..., startFuture:, ...)` immediately after invoking
`descriptor.start(host)`. `registerStart` returns `Future<void>`; that settlement
future completes only after a returned instance has had its identity validated,
its initial `currentStatus` inspected, its replay-latest status subscription
installed, its API published to or removed from the operational map, and its
ordered metadata published. A thrown start is converted to failed metadata and
also settles only after that publication. Lifecycle retains every returned
instance even when it is terminal or unroutable. Every returned instance whose
current status is nonterminal, including `PluginStarting`, is operational
immediately; `PluginFailed` and `PluginStopped` are not. A later terminal
`PluginFailed` removes only that API from operational publication. Lifecycle
never owns a host, process runner, repository, descriptor start callback, or
bridge-session cancellation.

At runtime, a terminal plugin failure removes that plugin from operational
routing but leaves the bridge, relay, catalog, and other plugins running.
Shutdown first signals start/session/import/debug cancellation and closes trigger
inputs, then immediately early-disposes every returned API concurrently to
unblock arbitrary backend calls. It next drains import, session, listeners,
dispatcher, and debug work; shuts down/closes lifecycle; and only then closes
shared bridge resources. Every phase attempts all work and preserves the first
non-expected error. A `PluginStartAbortedException` is expected only when the
shared shutdown `StartAbortController` has actually been aborted.

### 3.5 Compatibility Default

Enabled plugin order is stable. Repeated `--plugin` flags override persisted
`enabledPlugins`; otherwise settings win; otherwise OpenCode remains the sole
default. Duplicates, unknown ids, and an explicitly empty set fail validation.

Older clients omit `pluginId`. Missing legacy identity defaults to OpenCode,
the only backend those clients could target; it is never substituted with the
first enabled plugin. New clients always send `pluginId`. Runtime identity
remains non-null. Every compatibility-only default carries a code-local
`COMPATIBILITY` marker with its introduction date/version and exact cleanup.

## 4. Catalog Schema

The implementation allocates the next schema version present on `main` when
Stage 2 starts. It never rewrites an already merged migration.

### Projects

Add `projection_updated_at INTEGER NOT NULL` to `ProjectsTable`, backfilled
from `updated_at`.

Rendered name precedence is `display_name ?? basename(path)`. Hydration writes
the first useful plugin-observed name to `display_name` only when it is null;
later hydration never overwrites it, while an explicit Sesori rename writes the
same field. Add an indexed `path` lookup. Do not make it
unique until migration tests prove existing stores cannot contain duplicate
live paths.

### Sessions

Add to `SessionTable`:

- `backend_session_id TEXT NOT NULL`;
- `parent_session_id TEXT NULL` with a self-reference and cascade delete;
- `directory TEXT NOT NULL`;
- `catalog_title TEXT NULL`;
- `updated_at INTEGER NOT NULL`;
- `projection_updated_at INTEGER NOT NULL`.

Keep existing bridge-owned worktree, branch, archive, prompt-default, unseen,
and `title` fields. Existing `title` values are preserved as the bridge-owned
override because the old schema cannot distinguish a rename from an observed
derived-plugin title. Rendered title precedence is `title ?? catalog_title`.

Backfill:

- `backend_session_id = session_id`;
- `parent_session_id = NULL` because existing persisted rows are roots;
- `directory = worktree_path ?? projects_table.path`;
- `updated_at = max(last_activity_at ?? created_at, created_at)`;
- summary columns and `catalog_title` to null; and
- `projection_updated_at = updated_at`.

Add a unique index on `(plugin_id, backend_session_id)` and
indexes supporting root lists, child lists, plugin binding lookup, ordering,
and archive filtering.

### Tombstones and Hydration

Rename the tombstone's backend-shaped `session_id` to `backend_session_id` and
keep its already-shipped `(owner_identity, plugin_id, backend_session_id)`
primary key. Sesori
deletion writes tombstones for every removed backend binding. A later import
cannot resurrect those bindings.

Add `CatalogHydrationsTable`:

| Column | Meaning |
|---|---|
| `plugin_id` | imported plugin |
| `projection_version` | catalog projection contract version |
| `completed_at` | successful atomic publication time |

Its primary key is `(plugin_id, projection_version)`. Only successful
completion is durable. Running, failed, cancelled, percentage, and
"import-required" sentinels remain in memory; absence of the current completion
row is sufficient to require hydration.

## 5. Catalog Data Flows

### Database-Only Reads

```text
request handler
  -> ProjectRepository / SessionRepository
  -> indexed DAO query
  -> repository mapper
  -> shared response
```

`GET /project`, project lookup, root sessions, and session lookup perform no
plugin calls. Root lists filter `parent_session_id IS NULL`; child lists filter
by the parent Sesori id. Until Stage 5 automatic import hydrates children from
released bridges that kept them rowless, a child read for a known root performs
additive plugin discovery before returning the catalog and falls back to
existing durable rows when that refresh is unavailable. Sorting and pagination
happen in SQL, with the Sesori id as the deterministic final tie-breaker.

Filesystem existence checks are not plugin I/O, but per-row synchronous checks
also leave the list critical path. Directory-missing state is refreshed on
open/import/targeted operations rather than statting every project on every
list.

### Sesori-Initiated Mutation

```text
Sesori session id
  -> SessionRepository binding lookup
  -> selected BridgePluginApi + backend session id
  -> plugin operation
  -> exact catalog write
  -> response / committed mutation stream
```

- Create selects a plugin, resolves the stored project path, creates the
  backend session, allocates the Sesori id, and persists the binding before
  returning it.
- Rename calls the owning plugin, then persists the bridge title override.
- Archive/unarchive persists bridge-owned state immediately according to the
  existing cleanup contract; backend archive notification remains best-effort.
- Delete calls the owning plugin, then transactionally tombstones backend
  bindings and deletes the root. The self-reference cascades descendants.
- Prompt, command, abort, messages, diffs, questions, permissions, and worktree
  cleanup resolve exactly one stored binding and pass only backend handles to
  the plugin.

`SessionMutationDispatcher` remains the ordered choke point for mutations that
share title/deletion/child invariants. It depends on `SessionRepository` and
publishes committed deletion/mutation streams. `SessionPersistenceService` is
removed when its list-triggered persistence responsibility disappears.

### Known Events and Children

Stage 4 normalizes the one selected plugin stream in source order. Stage 7
constructs one listener per operational plugin and merges those already-
normalized outputs, preserving per-plugin order without allowing a blocked
plugin A event to block plugin B.

```text
plugin.events
  -> PluginEventListener attaches pluginId and receipt order
SessionRepository.bindingCommits
  -> SessionBindingCommitListener
SessionMutationDispatcher.deletedSessions
  -> SessionDeletionListener
all listeners
  -> SessionEventDispatcher orders each plugin and validates shared output
  -> SessionEventService
  -> SessionEventTracker records/drains unresolved roots and ancestry
  -> SessionRepository / SessionMutationDispatcher perform exact writes
  -> SessionEventMapper rewrites every session reference to Sesori ids
  -> SessionEventDispatcher
  -> NormalizedSourcedBridgeEvent(pluginId, normalized BridgeSseEvent)
  -> Orchestrator
  -> BridgeEventMapper -> SesoriSseEvent
  -> phones + shared local wire stream -> DebugServer
```

Rules:

- A known root event may update catalog title/time/summary and activity fields.
- An unknown root event does not discover a project. An unknown
  `session.created` is retained only in the bounded in-memory tracker until an
  exact same-plugin create/list binding commit arrives; all other unknown-root
  events are dropped. A later session-bearing event may share that bound only
  when every missing reference belongs to a same-plugin root/child binding
  already pending in the tracker; it retries after the awaited binding commits.
- A child is inserted only when its direct parent binding belongs to the same
  plugin. It inherits project/plugin attribution and stores its own reported
  directory.
- If a child's first complete event is an update, projection emits a durable
  creation announcement before the translated update so clients can add the
  newly learned child before applying its update.
- An unresolved child waits in a bounded in-memory map keyed by
  `(pluginId, backendParentId)`. Committing a parent drains resolvable
  descendants recursively. Stage 7 partitions capacity and oldest-entry
  eviction by plugin, so one noisy plugin cannot consume another plugin's
  pending allowance. There is still one tracker owner, no global enumeration,
  and no durable unresolved sentinel. The per-plugin bound remains an internal
  safety limit sized from the largest concurrent out-of-order event fixture.
  Import does not use this map: it validates ancestry inside its complete
  snapshot.
- Backend deletion does not delete catalog history and does not emit a client
  deletion that would contradict the next catalog read. A targeted operation
  later surfaces typed backend not-found.
- Events whose embedded session references cannot all be translated are
  dropped rather than leaking a backend handle.
- Plugin connected, heartbeat, and disposed events are plugin lifecycle input;
  they do not masquerade as whole-bridge lifecycle events. A connected event
  retains its source id so only that plugin's project activity is reconciled.

`SessionEventService` replaces the narrower
`SessionEventEnrichmentService`. It is a thin Layer 3 orchestrator constructed
with already-built `SessionRepository`, `SessionMutationDispatcher`,
`SessionEventMapper`, `SessionEventTracker`, and `FailureReporter` instances. It
imports no DAO and delegates every projection/child write to
`SessionRepository` or `SessionMutationDispatcher`.

`SessionEventMapper` is a stateless, pure repository-layer mapper with a const
constructor. The service extracts backend references, asks `SessionRepository`
to resolve them in one batch, and gives the mapper the resulting
backend-to-Sesori id map. The mapper owns only the exhaustive event-shape
rewrite and performs no I/O.

`SessionEventTracker` is constructed with only its maximum pending-entry count
per plugin. It owns typed pending projection and translation entries, the
in-memory root/child maps, same-plugin pending-binding index, per-plugin
insertion order and eviction invariant, and recursive drain bookkeeping. It has
no service, repository, DAO, or plugin dependency and returns typed entries for
`SessionEventService` to persist or retry after a matching binding commit.

Each `PluginEventListener` is constructed with one already-selected raw
`Stream<BridgeSseEvent>`, its explicit descriptor-selected plugin id, and the
shared `SessionEventDispatcher`. It owns exactly one raw event subscription and
captures receipt order synchronously before dispatch. One unfiltered
`SessionBindingCommitListener` owns the repository's one global binding stream,
and one `SessionDeletionListener` owns the one global bridge-deletion stream.
The dispatcher is the single choke point with one ordered tail per plugin: it
delegates projection/translation to `SessionEventService`, validates durable
created events immediately before publication, wraps every output in
`NormalizedSourcedBridgeEvent`, and exposes one sourced normalized broadcast
stream to `OrchestratorSession`. No listener depends on a peer or on
`BridgePluginApi`. In Stage 7 the orchestrator constructs one plugin listener
per operational plugin and the two singleton listeners; the orchestrator is the
only component that unwraps sourced events, performs reconnect behavior, maps
validated normalized events to phone SSE, and publishes the already-mapped
local wire stream consumed by `DebugServer`.

## 6. Import

Import is one complete observation of one plugin, not synchronization.

### Trigger Surfaces

- `POST /plugin/import` starts or joins one import for a requested plugin.
- `DELETE /plugin/import` requests cooperative cancellation.
- `GET /plugin/import` returns the latest status for initial load/reconnect and
  diagnostics; clients subscribe to SSE rather than polling.
- A repeatable headless `--import-plugin <id>` run option requests an explicit
  import after that plugin starts.
- Startup requests one automatic hydration for each operational plugin missing
  the current projection-version completion row.

The equivalent start triggers are `POST /plugin/import`, headless
`--import-plugin`, and startup hydration. All invoke
`CatalogImportService.start({pluginId, trigger})`; duplicate starts join the
existing operation. `DELETE /plugin/import` invokes
`CatalogImportService.cancel({pluginId})`. `GET /plugin/import` reads
`CatalogImportService.latestStatuses` and never starts or cancels work.

`CatalogImportService` is constructed with one already-built
`CatalogImportRepository`. In Stage 5, `Orchestrator` constructs that repository
with the one selected plugin API and DAOs. The service receives no plugin API,
DAO, database, host, or configuration pass-through parameter. It owns one
in-flight operation, its cancellation control, latest in-memory status, and a
broadcast progress stream. Stage 7 replaces this singular selected-plugin
composition when multiple operational plugins become a current requirement.

### Enumeration and Publication

`CatalogImportRepository` receives the selected plugin API and DAOs. Its exposed
plugin id is the only id Stage 5 routes or starts; Stage 7 replaces this singular
dependency when parallel runtime routing lands.

- Native-project plugins enumerate declared projects and their root sessions,
  then recursively enumerate children where the API exposes them.
- Derived-project plugins call `listAllSessions`, normalize directories, and
  build roots/descendants from the returned parent relationships. Targeted
  child reads fill only a known imported ancestry when required.
- Any enumeration error fails the complete snapshot. No partial rows publish.
- Tombstoned backend bindings are skipped.
- Missing rows are retained. Import absence never archives, deletes, or marks a
  session unavailable.

The repository captures `importStartedAt`, enumerates and maps outside a
database transaction, and checks cancellation between bounded backend calls.
It then performs one set-based/batched transaction:

1. Reuse existing entities by `(owner, plugin, backend handle)` and normalized
   project path.
2. Allocate Sesori ids only for new bindings.
3. Update plugin-observed fields only when the row's
   `projection_updated_at <= importStartedAt`.
4. Preserve display names/titles, hidden/archive state, worktree metadata,
   prompt defaults, and unseen state.
5. Insert the successful hydration marker in the same transaction when the
   trigger is automatic.

Cancellation is cooperative and truthful: it can discard work before commit,
but it does not claim to interrupt an arbitrary in-flight backend call. Once
the short publication transaction starts, it completes or rolls back.

Progress uses phases and counts, not invented percentages:

```text
enumerating(projectsSeen, sessionsSeen)
committing(projectsSeen, sessionsSeen)
completed(projectsImported, sessionsImported, completedAt)
cancelled
failed(message)
```

`CatalogImportService` exposes `Stream<CatalogImportProgress>` and never writes
to `Console` or SSE directly. The orchestrator maps that stream to additive
shared SSE events. `CatalogImportConsoleListener` is constructed with the
service progress stream in headless composition, owns that subscription, and
prints coarse user-actionable progress through `Console`.

Stage 5 moved Codex rollout enumeration behind `Isolate.run` inside the Codex
plugin. Backend file layout and parsing never enter bridge app code.

## 7. Parallel Endpoint Semantics

| Surface | Behavior |
|---|---|
| Projects, root sessions, children | Database-only catalog reads |
| Session operations | Route one stored binding to one operational plugin |
| Create session | Explicit plugin, or temporary compatibility default |
| Providers, agents, commands | Explicit/default plugin; never merge backend-local ids |
| Project questions | Query operational plugins concurrently and return only after all succeed until a typed partial-result contract exists |
| Session statuses | Query operational plugins concurrently, translate known bindings, expose unavailable sources separately |
| Active-session summaries | Merge translated summaries by shared project path |
| Bridge health | Catalog/relay health remains bridge-level; plugin reachability is a per-plugin list |
| Plugin metadata | Enabled order, display name, default marker, lifecycle state, and bridge-authored generic action hint only |

`SessionRepository.getSessionStatuses` owns concurrent plugin queries and
binding translation through `SessionDao`; `GetSessionStatusesHandler` receives
only that repository and no `BridgePluginApi`. The repository knows the ordered
enabled ids and operational API map, so missing/failed sources can be reported
without a handler-layer plugin dependency; those constructor values come from
the orchestrator's single `PluginCompositionView`, not independent runtime
getters. Status and health repositories apply a five-second deadline to each
source; a timeout is ordered unavailable/false just like a throw. Project
questions use the same per-source deadline but retain all-or-nothing failure
semantics.

`GET /plugin` is the client discovery endpoint. `GetPluginsHandler` depends on
`PluginLifecycleService`, whose state machine already owns enabled order,
default selection, display metadata, and lifecycle snapshots; the handler does
not inspect descriptors or plugin APIs. The endpoint and its minimal additive
shared DTO contract land together in Stage 7. It exposes no backend URLs,
process details, assistant-specific fields, raw descriptor availability
guidance, or `PluginStatus.userActionHint`. `actionHint` is mapped only from the
bridge lifecycle state to fixed bridge-authored generic text or null. Descriptor
guidance remains Console-only. A failed plugin remains listed and disabled for
new-session selection.

Shared request changes are additive:

- non-null `pluginId` with an OpenCode legacy default on create-session,
  plugin-scoped composer requests, and `Session`;
- a dedicated plugin-scoped request DTO, while project-only requests carry no
  plugin identity; and
- typed plugin list, runtime state, health, import status, and import progress
  DTOs.

## 8. Client Flow

`module_core` adds `PluginApi` (Layer 1) and `PluginRepository` (Layer 2).
`NewSessionCubit` (Layer 4) receives `PluginRepository` and the existing session
repository/service dependencies; it never imports APIs.

```text
NewSessionCubit
  -> PluginRepository.listPlugins
  -> choose server default
  -> SessionRepository list agents/providers/commands(pluginId, projectId)
  -> user changes plugin
  -> reload all three resources for that plugin
  -> create session with pluginId
```

Saved agent/model/variant selection is keyed by project and plugin so backend-
local ids never bleed between selections. Existing-session composer requests
use `Session.pluginId`; missing identity from an old bridge defaults to OpenCode
during the compatibility window.

Presentation remains in product UI. The chooser lives in
`client/app/lib/features/new_session/`, alongside the current mobile new-session
screen. The shared cubit exposes ordered plugin choices and unavailable state
but no widgets. This work does not create or restructure shared/desktop UI;
existing desktop consumers are compiled and tested against the additive
core/shared changes.

## 9. Performance Gates

The historical Stage 1 source audit established that every list then waited for
plugin enumeration, derived lists paginated after global discovery, Codex
discovery could block the bridge isolate, and event enrichment was globally
serial. Stages 4-6 removed those production paths. Stage 1A added the
first repeatable AOT harnesses and recorded the raw pre-change measurements in
`baselines/stage-1a-macos-arm64.json`.

The catalog budgets remain release targets rather than claims about the current
plugin-backed path. The local fakes isolate bridge mapping/persistence overhead
but deliberately exclude backend HTTP/RPC/disk latency. The endpoint-core
scenario includes list-triggered persistence, pending-title application, and
post-persistence enrichment, but excludes optional PR refresh. It measured p95
at 1.728 ms for 500 native projects, 0.943 ms for one derived project from
10,000 sessions, 0.988 ms for a native 100-session page that enumerated 10,000
rows, 7.693 ms for 1,000 native sessions, 1.729 ms for a derived 100-session page
that enumerated 10,000 rows, and 7.756 ms for 1,000 derived sessions.

Codex's real filesystem fixture includes a 4 KiB transcript tail per session.
Across 100 directional, non-gating samples, it measured `listSessions` and
main-isolate delay at p95 35.490/35.501 ms for 1,000 sessions and
350.815/350.830 ms for 10,000. This validates the Stage 5 worker-isolate
requirement and exceeds the future 100 ms maximum scheduling-lag target at
10,000 sessions.

The initial release budgets are:

| Path and fixture | Budget |
|---|---|
| 500-project catalog list | p95 <= 25 ms, p99 <= 50 ms |
| 100-row root-session page from 10,000 rows | p95 <= 15 ms, p99 <= 30 ms |
| 1,000-row unpaginated project | p95 <= 50 ms, p99 <= 100 ms |
| Plugin count 1 -> 8, unchanged catalog | p95 regression < 10%, zero plugin calls |
| Catalog reads during 50,000-session import | p95 <= 50 ms, p99 <= 100 ms |
| Import publication transaction, 10,000 sessions | p95 <= 250 ms |
| Main-isolate scheduling lag during import | p99 <= 25 ms, max <= 100 ms |
| Known event to catalog commit and relay enqueue | p95 <= 250 ms idle, <= 500 ms during import |

Backend enumeration duration is reported by plugin and fixture, not given one
universal network SLO. A 50,000-session import has additional guardrails of
less than 100 MiB peak bridge RSS growth and less than 50 MiB generic catalog
database growth.

The benchmark matrix is 1/3/8 plugins over 1,000/10,000/50,000 sessions and
50/500/2,000 projects. Benchmarks use release-mode AOT executables, a file-backed
database, deterministic fixtures, warmup, at least 2,000 list samples, and JSON
output with commit, schema, OS, CPU, fixture, p50/p95/p99/max, RSS, database
bytes, and query plans. Wall-clock budgets run on fixed hosts; normal CI uses
deterministic zero-call, concurrency, index, and isolate-responsiveness tests.

## 10. Stages and PR Status

Stages are strictly ordered. Every row is one reviewable PR and must leave
single-plugin production behavior releasable until Stage 7 enables parallel
selection.

| Status | Stage | Deliverable | Main verification |
|---|---|---|---|
| ☑ | 0 | Execution plan approved | `aristotle-plan-review`; docs consistency |
| ☑ | 1A | Pre-change baseline harness | AOT baseline JSON; app/Codex analysis |
| ☑ | 1B | Additive compatibility contracts | Shared/plugin/client round trips |
| ☑ | 2 | Catalog schema and indexed DAO queries | Drift structural/data migration tests; query plans |
| ☑ | 3A | Correct touched session architecture boundaries | Architecture tests; behavior parity |
| ☑ | 3B | Relocate the database API layer | Rename-only diff; schema/tests unchanged |
| ☑ | 3C | Catalog write-through and stable session binding | Mutation/routing tests; existing IDs preserved |
| ☑ | 4 | Known-event projection and durable child hierarchy | Exhaustive event translation and ancestry tests |
| ☑ | 5 | Explicit import and automatic hydration | Atomicity, cancellation, progress, Codex isolate tests |
| ☑ | 6 | Database-only list cutover | Zero plugin calls; degraded-plugin browsing; budgets |
| ☑ | 7 | Multi-plugin routing, lifecycle, and event streams | Mixed-id routing, independent failure, startup/shutdown |
| ☑ | 8 | Client plugin and model/agent selection | Cubit, API/repository, mobile and desktop tests |
| ☐ | 9 | Performance gate and cleanup | Fixed-host matrix, soak, dead-path removal, docs |

### Stage 1A - Pre-Change Baseline Harness

- Add AOT benchmark executables for current live project/session reads and
  Codex rollout enumeration. Record host, fixture, latency, plugin-row, database,
  memory, and event-loop-delay measurements before production behavior changes.
- Defer `event_projection_benchmark` to Stage 4,
  `import_concurrency_benchmark` to Stage 5, and
  `multi_plugin_startup_benchmark` to Stage 7. Those production seams do not
  exist yet, so a Stage 1 executable would measure invented behavior.
- Keep fixtures and measurement code local to each benchmark. Do not add a
  production benchmark framework, Makefile target, or noisy CI wall-clock gate.

Acceptance: both executables compile AOT, emit valid versioned JSON, and record
the default fixed-host fixtures without changing production behavior.

### Stage 1B - Additive Compatibility Contracts

- Add required `PluginProject.directory` and update all implementations/fakes.
- Add non-null compatibility `pluginId` fields with an OpenCode legacy default
  to `Session`, `CreateSessionRequest`, and a dedicated plugin-scoped project
  request DTO. Keep `ProjectIdRequest` project-only.
- Stamp plugin identity at the existing single-plugin repository/service
  boundary. Carry request `pluginId` through the compatibility contract, but
  assume it identifies the active plugin until multi-plugin routing lands.
- Add compatibility-debt entries and regenerate all affected Freezed code.
- Defer plugin metadata/import DTOs and SSE variants until Stages 5 and 7, when
  their first production consumers land.

Acceptance: one-plugin clients behave unchanged; missing new JSON fields decode;
the bridge always emits plugin identity in new responses; no optional capability
matrix is introduced.

### Stage 2 - Catalog Schema and Indexed DAO Queries

- Export the current schema, allocate the next version, add the fields/tables/
  indexes in section 4, and regenerate Drift artifacts.
- Add dumb DAO queries for project, root, child, binding, tombstone, and
  hydration access.
- Add repository mappers for catalog rows without changing handlers yet.

Acceptance: migration preserves every existing session id and metadata;
backend handle, directory, and timestamps are backfilled; parent/project delete
cascades work; equal backend handles across plugins are legal; query-plan tests
use the intended indexes.

### Stage 3A - Correct Touched Session Architecture Boundaries

Prepare the existing seams that Stage 3B must relocate and Stage 3C must
materially change, without changing session behavior.

- Make `RequestRouter` accept only an ordered handler list. `Orchestrator.create`
  constructs the room-specific `SessionPromptService`, handlers, and router after
  its `SSEManager`, then injects the completed router into `OrchestratorSession`.
  The running session receives no construction-only collaborators.
- Remove the Layer 3 `SessionPromptService -> SSEManager` dependency. The service
  owns a typed broadcast stream of committed prompt-default changes;
  `Orchestrator.create` subscribes, maps those changes to shared SSE events, and
  owns enqueue/subscription/disposal through the running session lifecycle.
- Move shared archive/delete cleanup policy from the routing free function into
  `SessionCleanupService`; route filesystem existence through
  `FilesystemRepository`. `DeleteSessionHandler` consumes cleanup + mutation
  collaborators only; `SessionArchiveService` imports no routing/database types.
  The Layer 5 `Orchestrator.create` factory constructs cleanup/archive/abort
  peers; `BridgeRuntime.create` does not gain another composition role.
- Remove `SessionRepository -> PullRequestRepository` peer dependency by using
  `PullRequestDao`, and map database rows to an expanded repository-owned
  `StoredSession` before services/handlers consume them.
- Move the four existing `SessionPersistenceService` methods behind
  `SessionRepository` with unchanged insert/archive semantics, then remove the
  service. `GetSessionsHandler` may call the repository's existing-behavior
  publication method until Stage 3C folds publication into the list result;
  `SessionArchiveService` delegates placeholder/archive writes to the repository.

Data flow after this PR:

```text
handler -> repository/service -> repository-owned model
repository -> legacy database API (relocated unchanged in Stage 3B)
Orchestrator.create -> handlers -> RequestRouter
SessionPromptService stream -> Orchestrator -> SSEManager
```

Acceptance: behavior tests remain unchanged; routing/services import no database
rows in corrected seams; `RequestRouter` constructs nothing; architecture review
approves the resulting dependency graph; only `Orchestrator` composes layers or
enqueues prompt-default SSE events.

### Stage 3B - Relocate the Database API Layer

With all higher-layer imports removed, consolidate the complete Drift Layer 1
implementation under canonical `bridge/app/lib/src/api/database/`.

- Move `AppDatabase`, every DAO, and every database table from both legacy
  `lib/src/bridge/persistence/` and `lib/src/bridge/api/database/` into the
  canonical subtree, including pull-request and hydration database APIs.
- Update `build.yaml` and every production, test, migration-test, and benchmark
  import. Regenerate generated parts; do not edit them or schema snapshots.
- Leave `persistence/bridge_diagnostics.dart` in place because it is process
  startup diagnostics, not a database API.
- Make no schema, query, model, constructor, or runtime behavior change.

Acceptance: Git detects handwritten/generated database files as moves; only
Layer 2 repositories and composition import the database API; schema remains
v11; migration artifacts are unchanged; all bridge verification passes.

### Stage 3C - Catalog Write-Through and Stable Session Binding

- Make every root-targeted `SessionRepository` operation resolve stored Sesori
  ids and pass only backend handles to the active plugin. Missing bindings
  return 404 without discovery; bindings owned by a non-running plugin return
  503 before plugin or cleanup side effects.
- Validate plugin-scoped agent, provider, command, and create requests before
  project resolution or plugin I/O.
- Consume create/plugin-scoped `pluginId`; never substitute the active plugin.
- Carry `sessionId` and `backendSessionId` independently in every DAO/repository
  write, but keep new production allocation identity-preserving until Stage 4.
  Divergent-id tests prove routing before that cutover.
- Publish complete observed root projections inside `SessionRepository`, map live
  lists/statuses through bindings, and fold the temporary repository publication
  call into the required list result.
- Persist create/open/rename/archive/unarchive/delete write-through before the
  response while preserving bridge-owned fields and failure ordering.
- Keep child lookup plus question/permission routing on the identity-preserving
  path until Stage 4 can land durable child bindings and exhaustive event/child
  translation atomically.

Acceptance: equal backend handles under different plugin ids remain legal;
divergent stored ids route every targeted call with the backend handle; unknown
ids make zero plugin calls; create/list writes commit before response; failed
delete leaves row and tombstone state unchanged; production ids remain unchanged
until Stage 4.

### Stage 4 - Known Events and Durable Children

- Activate random Sesori-id allocation for newly created and newly observed
  bindings only after exhaustive event translation is active. Existing ids stay
  unchanged.
- Add the internal source-plugin envelope, `SessionEventMapper`,
  `SessionEventTracker`, `SessionEventService`, `SessionEventDispatcher`, and
  one-trigger plugin/binding/deletion listeners.
- Persist known-session projection updates, proven child ancestry, recursive
  descendants, and cascade behavior.
- Make `SessionRepository.getChildSessions` return durable children from the
  catalog. Until Stage 5 automatic import, additively discover a known root's
  backend children before that read and retain existing catalog history when
  discovery is unavailable. Make `QuestionRepository` and
  `PermissionRepository` resolve durable root/child bindings and pass only
  backend handles to the owning plugin.
- Hydrate a rowless active root from a native-project activity summary before
  publishing the summary, using the native project API to resolve stable
  identity and live path. Continue omitting unknown derived-project activity,
  whose parent-project attribution cannot be inferred safely.
- Retain permission, question, and other session-bearing follow-up events only
  while all missing references have same-plugin bindings already pending in
  `SessionEventTracker`; drain them in source order after root/child commit.
- Move YOLO approval sequencing into session-scoped
  `PermissionAutoApprovalService`. It owns deduplication, pending-root
  discovery, best-effort legacy-child hydration, translated permission lookup,
  approval, and cancellation; `OrchestratorSession` owns only trigger gating
  and delegation.
- Translate every session-bearing event field from backend to Sesori identity.
- Normalize the selected plugin stream before delivery and remove backend-
  global lifecycle events from bridge-global semantics. Multi-plugin listener
  construction and fan-in remain Stage 7 work.
- Change child responses to catalog identities while retaining temporary
  additive child discovery for released rowless history. Root/project lists
  remain on the old path for one more stage.

Acceptance: no backend handle reaches a shared event, child, question, or
permission payload; unknown roots do not discover projects; bridge-created roots
and out-of-order descendants drain when matching bindings arrive; cross-plugin
parent links fail; backend deletion preserves history; the pending-event bound
retains the largest expected event burst; selected-plugin event order is
preserved.

PR-level implementation plan:

1. Add a repository-layer `SessionEventMapper` that exhaustively extracts and
   rewrites every session-bearing `BridgeSseEvent` field from backend handles to
   Sesori ids. Add a Layer-2 `SessionEventTracker` with a 1,024-entry internal
   bound and, historically for the one-plugin Stage 4 runtime, global insertion-
   order eviction, exact root-binding release, and parent-keyed child drains; it
   stores no durable unresolved sentinel and has no repository, service, DAO, or
   plugin dependency. Stage 7 partitions that existing bound/eviction by plugin.
2. Replace `SessionEventEnrichmentService` with a Layer-3
   `SessionEventService`. It receives a source-plugin event, updates only known
   projections through `SessionRepository`, accepts a new child only under a
   same-plugin durable parent, queues unresolved created roots and descendants
   in `SessionEventTracker`, recursively drains them after binding/ancestry
   commits, asks
   the repository for one batched binding map, delegates the pure rewrite to
   `SessionEventMapper`, and captures title-changing events through the existing
   `SessionMutationDispatcher`. Unknown non-created roots and unrelated
   untranslatable payloads produce no plugin-derived client event; follow-up
   payloads wait only when every missing reference has a same-plugin binding
   already pending in the shared bound. Backend deletion events produce no
   plugin-derived client event; failures are reported and isolated per input
   event.
3. Add one Layer-4 listener per trigger: selected raw plugin events, committed
   root bindings, and committed bridge-owned deletions. Each owns one
   subscription and submits typed input to one Layer-3 `SessionEventDispatcher`,
   which serializes all three sources, delegates to `SessionEventService`,
   validates durable created events, and exposes a broadcast normalized stream.
   The Layer-5 `Orchestrator` constructs the listeners/dispatcher. In the
   shipped Stage 4 one-plugin wiring, `BridgeRuntime.create` also shares that
   normalized stream with local debug and
   receives the selected descriptor id from `BridgeRuntimeRunner`, verifies it
   matches the started API identity, and passes it into `Orchestrator`; the
   plugin listener never depends on the API. The orchestrator retains local reconnect
   decisions for plugin-connected input, while `BridgeEventMapper` stops
   emitting plugin connected/heartbeat/disposed events as bridge-global wire
   lifecycle events. Multi-plugin listener construction, stream fan-in, and
   cross-plugin progress verification remain Stage 7 work. Stage 7 replaces
   debug's normalized input with the orchestrator's already-mapped local wire
   stream as specified in sections 3.2 and 7.
4. Add dumb DAO writes for exact known-session projection updates and durable
   child insertion. Keep ancestry, random-id allocation, tombstone handling,
   and unknown-root decisions above the DAO. Use the existing session-table
   self-reference and delete cascade; no schema or shared-wire change is
   required.
5. Activate secure random Sesori ids in `SessionRepository` for newly created,
   newly listed, and newly event-discovered sessions. Allocate and collision-
   check inside the publication transaction, reuse a binding that won a
   create/event/list race, and preserve every existing id. Remove the temporary
   identity-preserving rowless-child capability and require durable bindings for
   messages, statuses, aborts, questions, and permissions.
6. Switch child responses to `SessionDao.getChildCatalogSessions`. Until Stage 5
   automatic import, additively enumerate children for a known root, persist
   newly discovered bindings, and serve existing durable rows if that refresh
   is unavailable. Update question and permission reads, replies, and
   rejections to translate request and response session references in batches,
   dropping plugin results whose required references are unknown instead of
   exposing backend handles.
7. Add a session-scoped Layer-3 `PermissionAutoApprovalService` constructed by
   `Orchestrator.create`. Move direct and discovered YOLO approval,
   deduplication, legacy-child hydration, translated permission lookup, and
   cancellation into it; leave only trigger gating and delegation in
   `OrchestratorSession`.
8. Add focused DAO/repository/service/listener/mapper tests for stable existing
   ids, random new ids, create/list/event races, exhaustive event variants,
   known and unknown roots, same-plugin ancestry, out-of-order grandchildren,
   input following pending bindings, 1,024-entry retention plus overflow
   eviction, backend deletion history, catalog-backed additive child reads,
   legacy-child YOLO approval, question/permission translation, lifecycle
   suppression, and selected-stream ordering. Add the deferred file-backed AOT
   `event_projection_benchmark` with warmup, percentile, RSS, database-size, and
   fixture metadata matching the Stage 1A report shape.

### Stage 5 - Explicit Import and Automatic Hydration

- Implement `CatalogImportRepository` and `CatalogImportService` with the
  semantics in section 6.
- Add routes, typed status/progress, SSE delivery, headless trigger, startup
  hydration, and console progress.
- Move Codex rollout enumeration off the bridge isolate.
- Keep normal project/root-session reads on the previous path until hydration
  success and shadow comparisons are testable.

Acceptance: failed/cancelled import publishes nothing; re-import is idempotent
and non-destructive; concurrent mutations win over stale snapshots; one marker
is written atomically per plugin/projection version; old catalog reads complete
while enumeration is blocked.

PR-level implementation plan:

1. In `shared/sesori_shared`, add `CatalogImportRequest` in
   `lib/src/models/sesori/catalog_import_request.dart`, the sealed
   `CatalogImportProgress` phases in `catalog_import_progress.dart`, and
   `CatalogImportStatusesResponse` in `catalog_import_statuses_response.dart`.
   Export all three and add `SesoriSseEvent.catalogImportProgress` in
   `sesori_sse_event.dart`. These are the only transport/domain DTOs; the bridge
   does not create duplicate progress models.
2. In `bridge/sesori_plugin_codex`, add
   `SessionRolloutReader.listSessionsInIsolate()` using `Isolate.run` while
   retaining `listSessions()` as the plugin-private synchronous filesystem API.
   Add the Layer-2
   `lib/src/repositories/codex_catalog_repository.dart` with
   `CodexCatalogRepository({required SessionRolloutReader rolloutReader,
   required String launchDirectory})`, `listAllSessions`, and `getSessions`.
   It awaits the isolate API and maps rollout records to `PluginSession`;
   `CodexPlugin.listAllSessions` and `CodexPlugin.getSessions` delegate to that
   repository. Synchronous targeted transcript/metadata helpers remain
   unchanged. Add repository mapping and responsiveness fixtures alongside
   `test/session_rollout_reader_test.dart`.
3. In `bridge/app`, add only dumb exact-row methods
   `ProjectsDao.upsertProjectRows({required List<ProjectDto> rows})` and
   `SessionDao.upsertSessionRows({required List<SessionDto> rows})`. The import
   repository re-reads current rows and decides preservation, stale eligibility,
   ancestry, tombstones, and every final column value before invoking them.
   DAOs batch-insert or update the supplied rows exactly; they do not normalize,
   compare import timestamps, merge display names, allocate ids, inspect
   tombstones, decide ancestry, or open the publication transaction. Schema v11
   and migration artifacts remain unchanged.
4. Add `bridge/app/lib/src/repositories/catalog_import_repository.dart` with
   constructor `CatalogImportRepository({required BridgePluginApi plugin,
   required ProjectsDao projectsDao, required SessionDao sessionDao, required
   CatalogHydrationsDao catalogHydrationsDao})`, `pluginId`,
   `getHydrationCompletion`, and `importCatalog`. Add
   `lib/src/repositories/models/catalog_import_control.dart`; the service owns this
   mutable cooperative control while the repository only reads cancellation,
   explicit-import, and hydration-marker requests at the documented boundaries.
5. `CatalogImportRepository.importCatalog` captures `importStartedAt` and emits
   a `Stream<CatalogImportProgress>`. Native enumeration calls `getProjects`,
   then root and recursive child methods with cancellation checks between each
   call. Derived enumeration builds `knownDirectories` from normalized
   `ProjectsDao.getAllProjects()` paths, the owning project paths and worktree
   paths from `SessionDao.getSessionProjectPaths(pluginId:)`, and
   `launchDirectory`, then calls `listAllSessions` once and validates its parent
   graph. Existing normalized paths and `(pluginId, backendSessionId)` bindings
   are reused; orphan/cyclic imported descendants are omitted, tombstones are
   skipped, and missing observations leave durable rows untouched.
6. The repository alone opens the publication transaction with
   `sessionDao.attachedDatabase.transaction`; composition guarantees that the
   project, session, and hydration DAOs are all accessors from that same
   `AppDatabase`. Inside it, the repository re-reads paths, bindings, and
   tombstones, allocates collision-checked random ids, orders parents before
   descendants, invokes both batched DAO writes, and conditionally calls
   `CatalogHydrationsDao.recordCompletion`. Cancellation is checked immediately
   before the transaction; once publication begins it runs to commit or rollback.
7. Add `bridge/app/lib/src/services/catalog_import_service.dart` with
   constructor `CatalogImportService({required CatalogImportRepository
   repository})`, `start({required String pluginId, required
   CatalogImportTrigger trigger})`, `cancel({required String pluginId})`,
   `latestStatuses`, `progress`, and `dispose`. `start` validates `pluginId`
   synchronously against `repository.pluginId`, records the operation, launches
   it without awaiting enumeration, and returns immediately. `cancel` performs
   the same validation before touching only the in-memory control. A missing id
   throws `CatalogImportPluginNotSelectedException` before plugin or DAO access.
8. Duplicate starts for that selected plugin join the one stored future/control.
   An explicit or headless
   join sets `explicitImportRequested`, so a completed hydration marker cannot
   suppress that operation; an automatic join sets `hydrationMarkerRequested`,
   so the shared operation records the marker even if an explicit trigger won
   the start race. Automatic-only starts map an existing current-version marker
   to completed status without enumeration. The service rebroadcasts repository
   progress, maps thrown failures to one terminal failed status, and owns closing
   the progress stream after cancelling and awaiting all operations.
9. Add `StartCatalogImportHandler`, `CancelCatalogImportHandler`, and
   `GetCatalogImportStatusesHandler` under `bridge/app/lib/src/routing/`. POST
   and DELETE parse
   `CatalogImportRequest`, delegate to the service, map the typed non-selected
   exception to 404, and return `SuccessEmptyResponse`; GET accepts no plugin
   input and returns only `CatalogImportService.latestStatuses`, so it cannot
   query an unselected plugin. Register all three in `Orchestrator.create`.
10. `Orchestrator.create` subscribes to its newly constructed service's
    `progress`, enqueues `SesoriSseEvent.catalogImportProgress`, stores that
    subscription in a dedicated `CompositeSubscription`, and passes the owner to
    `OrchestratorSession`, which cancels it during teardown alongside the prompt
    subscription. No service, repository, handler, or listener accesses
    `SSEManager`.
11. `BridgeRuntime.create` passes the selected plugin and the three already-built
    database accessors into the Layer-5 `Orchestrator`, which constructs the new
    repository and service in `Orchestrator.create`. Change that method to return
    an `OrchestratorComposition` record containing the session and shared import
    service. `BridgeRuntime` constructs neither layer; it stores the returned
    service as a runtime-owned field exposed directly to `BridgeRuntimeRunner`
    and disposes it before closing the database. Add
    `CatalogImportConsoleListener` under `bridge/app/lib/src/listeners/` with
    `start`/`dispose`; the runner constructs and starts it only in standalone
    mode, registers its disposal with `BridgeShutdownCoordinator`, and it renders
    coarse progress from its one subscription through `Console`.
12. Add repeatable `--import-plugin <id>` as an args `addMultiOption`, store its
    ordered values in `BridgeCliOptions.importPluginIds`, and validate every
    value against the selected descriptor in `RunCommand` before authentication,
    plugin probing, or startup-mutex acquisition. Repeated equal ids are retained
    and harmless because `start` joins them. Supervised and standalone modes both
    honor the trigger; supervised mode omits only Console rendering.
13. After `BridgeRuntime.create` has installed both SSE and optional Console
    subscribers, but before starting DebugServer or `OrchestratorSession.run`,
    the runner calls non-blocking `start(automatic)` for the selected plugin and
    then `start(headless)` for each ordered CLI value. Automatic-first ordering
    and the join rules above yield one import and an atomic hydration marker when
    startup and headless triggers overlap; relay startup is not blocked by
    backend enumeration.
14. In `client/module_core`, update the exhaustive shared-event switches in
    `capabilities/server_connection/models/sse_event.dart`,
    `services/sse_event_tracker.dart`,
    `cubits/session_list/session_list_cubit.dart`, and
    `cubits/session_detail/session_detail_cubit.dart` to classify catalog import
    progress as a global, non-session event with no Stage 8 UI behavior. Add the
    focused decoding/classification assertions required by those consumers.
15. Add repository/service/handler/orchestrator/runner tests for native and
    derived enumeration, recursive ancestry, complete `knownDirectories`,
    tombstones, idempotence, stale-write guards, transaction rollback,
    cancellation boundaries, duplicate/overlapping triggers, version markers,
    selected-plugin rejection, route responses, SSE, Console lifecycle, and CLI
    parsing. Add
    `bridge/app/tool/benchmarks/import_concurrency_benchmark.dart` with catalog
    read latency, publication duration, scheduling lag, RSS, database size, and
    Stage-1A fixture metadata. Keep client import APIs/UI and project/root list
    response paths untouched until Stages 8 and 6 respectively.

Stage 5 workspace and file matrix:

| Workspace | Production changes | Verification |
|---|---|---|
| `shared/sesori_shared` | Three new import DTO sources, barrel export, additive `SesoriSseEvent` variant, generated Freezed/JSON parts | DTO/SSE JSON round trips; fatal analysis; full package tests |
| `bridge/sesori_plugin_codex` | `session_rollout_reader.dart`, new `repositories/codex_catalog_repository.dart`, `codex_plugin_impl.dart` | repository mapping and isolate-responsiveness tests; fatal analysis; full package tests |
| `bridge/app` | project/session DAOs; canonical-layer import repository/control/service/listener and three handlers; `Orchestrator`, `BridgeRuntime`, runner, CLI options and `bin/bridge.dart`; benchmark | focused import/route/runtime tests; fatal analysis; full app tests and benchmark AOT compile |
| `client/module_core` | Exhaustive event classification only; no API, repository, cubit state, or UI feature | focused SSE decoding/classification tests; fatal analysis; full module tests; downstream app/desktop analysis |
| `docs/parallel-plugins` | pointer, Stage 5 plan/findings/risk evidence | plan consistency and `git diff --check` |

Client import APIs/UI, plugin-interface contracts, other plugin implementations,
database schema/migrations, normal project/root list behavior, and multi-plugin
runtime activation are explicitly untouched by Stage 5.

### Stage 6 - Database-Only List Cutover

- Switch project, project detail, root-session, session detail, and child list
  handlers to indexed catalog repository methods.
- Remove list-triggered persistence/reconciliation and plugin fallback.
- Remove per-row filesystem checks and `SessionPersistenceService` once no
  caller remains.
- Retain temporary shadow comparison only if it has bounded cost and is disabled
  by default; it must never affect responses.

Acceptance: list routes make zero plugin calls even when all plugin methods
throw or never complete; plugin outage leaves catalog browsing intact; import
absence never deletes rows; list and import-concurrency budgets pass.

PR-level implementation plan:

1. In `bridge/app/lib/src/api/database/database.dart`, add
   `AppDatabase.openFile({required File file})` as the one file-backed executor
   factory used by production and benchmarks. Configure SQLite WAL and a bounded
   read pool there so catalog SELECTs use independent read connections while the
   import writer transaction is open. Keep foreign-key setup, schema v11, and
   every migration unchanged. `AppDatabase.create` delegates to `openFile`, and
   normal `AppDatabase.close` owns shutdown of the writer and reader isolates;
   direct `AppDatabase(QueryExecutor)` construction remains only for injected
   in-memory and migration-test executors. Add a file-backed test proving a
   catalog read observes the last committed snapshot without waiting for a held
   write transaction.
2. Change `ProjectRepository.getProjects` to read
   `ProjectsDao.getCatalogProjects`, batch unseen state once, and map rows with
   the existing `ProjectCatalogMapper` using the stored path/name/activity and
   `directoryMissing: false`. Change `getProject` to map one stored row or throw
   `ProjectNotFoundException`. Remove plugin enumeration, list-time project
   seeding, in-memory list sorting, and per-row filesystem probes from those two
   read methods only. Keep plugin-backed open/rename and
   `listProjectActivityEvidence` as targeted/reconciliation operations; keep
   filesystem probing on targeted open/rename responses.
3. Make `ProjectActivityService.getProjects` call the catalog repository read
   directly instead of queuing behind the serialized mutation/reconciliation
   tail. This prevents an unrelated blocked plugin reconciliation from blocking
   `GET /projects` while preserving serialized open, event, and reconciliation
   writes.
4. Let `SessionDao.getRootCatalogSessions` accept the existing nullable limit
   contract and use SQLite's unbounded limit with the requested offset when the
   client omits a limit. Keep SQL ordering as `updated_at DESC, session_id DESC`
   and keep the existing root/child indexes; add no new schema or query layer.
5. Change public `SessionRepository.getSessionsForProject` to validate the
   stored project and map `SessionDao.getRootCatalogSessions` directly. Change
   `getSessionForProject` to validate project attribution and map that one stored
   row without requiring an operational plugin. Change `getChildSessions` to
   validate only the durable parent row, read direct children from the catalog,
   and delete the pre-Stage-5 additive plugin-discovery compatibility path.
   Change `getProjectPath` to return only the authoritative stored path so PR
   refresh no longer probes a native plugin from the list handler.
6. Preserve Stage 4's rowless native active-summary behavior through a private
   targeted `SessionRepository` observation method. `_hydrateActiveRootBindings`
   continues resolving the native project, then explicitly enumerates that
   project's root sessions, publishes their bindings transactionally, and emits
   binding commits. The public list methods never call this path; derived
   live-list derivation and list-triggered root publication are removed.
7. Keep `GetProjectsHandler`, `GetCurrentProjectHandler`, `GetSessionsHandler`,
   `GetSessionHandler`, and `GetChildSessionsHandler` thin over the changed
   repositories. Pending-title application and optional PR refresh remain local
   committed-mutation/external-git behaviors, but project-path resolution and
   every catalog response make zero `BridgePluginApi` calls. Update stale
   plugin-backed comments. Do not add shadow reads.
8. Add repository/handler/service tests using throwing and never-completing
   plugin fakes. Prove project list/detail, root pagination/detail, and child
   history complete from seeded rows; hidden projects remain excluded from the
   list; SQL tie-break ordering and title/name precedence are preserved; an
   in-flight plugin reconciliation cannot block a project list; unknown durable
   ids retain existing 404 behavior; and targeted native active-root hydration
   still publishes a binding.
9. Update `live_list_baseline.dart` to seed and measure the post-cutover catalog
   paths while asserting zero plugin calls. Move it,
   `import_concurrency_benchmark.dart`, and `event_projection_benchmark.dart` to
   `AppDatabase.openFile` so every file-backed production/benchmark consumer
   shares one executor policy. Record the 500-project, 100-of-10,000,
   1,000-unpaginated, and 50,000-row concurrent-import directional results in
   this plan. Fixed-host gating remains Stage 9.
10. Do not delete `ProjectActivityService.reconcile`, its repository evidence
    path, the now-unreferenced legacy derived-project builder, or the unused
    vanished-session reconciliation APIs in this PR. They are not on a list
    response path, and Stage 9 owns evidence-based dead-path cleanup. The old
    `SessionPersistenceService` mentioned in the stage summary was already
    removed in Stage 3A; Stage 6 removes the remaining list-triggered behavior,
    not a nonexistent class.

Stage 6 changes only `bridge/app` and this plan. Shared/client contracts, plugin
packages, import semantics, targeted session operations, runtime plugin count,
and schema/migration artifacts remain unchanged.

### Stage 7 - Multi-Plugin Routing, Lifecycle, and Events

- Make `--plugin` repeatable and honor ordered `enabledPlugins`.
- Introduce `PluginLifecycleService`, per-plugin hosts/state, independent status,
  one mutex acquisition, sequential provisioning, overlapping starts, and
  all-plugin shutdown.
- Let `Orchestrator` read one `PluginCompositionView` from
  `PluginLifecycleService` and compose plugin-aware repositories/services from
  that sole runtime-state authority. Keep `RequestRouter` generic and let
  `BridgeRuntime` own only the already-composed result/shared instances.
- Keep `DebugServer` on the orchestrator's shared router and already-mapped
  local wire stream; Stage 7 introduces no debug-specific plugin listener,
  mapper, repository aggregation, or routing authority.
- Add plugin-scoped providers/agents/commands, aggregated translated statuses/
  activity, and per-plugin health. Route `GetSessionStatusesHandler` only
  through `SessionRepository.getSessionStatuses`.
- Add `GetPluginsHandler` over `PluginLifecycleService` for enabled order,
  default marker, display metadata, and lifecycle state.
- Start one raw event listener per operational plugin, one unfiltered global
  binding listener, and one global deletion listener over one sourced normalized
  stream.

Acceptance: one unavailable/failed plugin cannot stop another or catalog reads;
same backend id in two plugins routes correctly; plugin-global disposal is not
bridge-global; all selected configs validate before takeover; if takeover was
justified but all starts fail, the relay/catalog runtime still serves with an
empty operational map and failed metadata; sourced reconnects reconcile only
their plugin; raw descriptor/status guidance never reaches shared DTOs; and
standalone and supervised shutdown semantics remain intact.

PR-level implementation plan:

1. Add only the shared response shape that Stage 7 must put on the wire. In
   `shared/sesori_shared/lib/src/models/sesori/plugin_list_response.dart`, add
   `PluginLifecycleState` with only `unavailable`, `ready`, `degraded`, and
   `failed`; startup-only registration/start/stop phases are not observable
   after the endpoint starts serving. Add
   `PluginMetadata({required String id, required String displayName, required
   bool isDefault, required PluginLifecycleState state, required String?
   actionHint})`, and
   `PluginListResponse({plugins})`. Add `PluginHealth({pluginId, healthy})` and
   an additive `@Default(<PluginHealth>[]) plugins` field in
   `health_response.dart`; add additive
   `@Default(<String>[]) unavailablePluginIds` to `SessionStatusResponse` in
   `session_status.dart`. Export the new source from
   `lib/sesori_shared.dart` and generate the corresponding `.freezed.dart` and
   `.g.dart` parts. Put these exact source comments immediately above the two
   defaults:

   ```dart
   // COMPATIBILITY 2026-07-17 (v1.5.1): Bridges before per-plugin health omit plugins. Remove @Default and require plugins once pre-v1.5.1 bridges are unsupported.
   // COMPATIBILITY 2026-07-17 (v1.5.1): Bridges before aggregate plugin statuses omit unavailablePluginIds. Remove @Default and require unavailablePluginIds once pre-v1.5.1 bridges are unsupported.
   ```

   Do not add any other speculative status/health fields. No
   request, SSE, relay, database, or persisted contract changes are required.
2. Correct documentation only in
   `bridge/sesori_plugin_interface/lib/src/lifecycle/bridge_plugin_descriptor.dart`,
   `plugin_availability.dart`, `plugin_status.dart`, and `bridge_plugin.dart`:
   all enabled descriptors contribute options; one unavailable descriptor is
   skipped/listed and is globally fatal only when no enabled descriptor is
   available; and `PluginFailed` is terminal for that plugin, not for the
   bridge. Audit
   `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_plugin_descriptor.dart`,
   `bridge/sesori_plugin_codex/lib/src/runtime/codex_plugin_descriptor.dart`, and
   `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_plugin_descriptor.dart`
   against the corrected text. Change no interface signature or plugin
   implementation.
3. In `bridge/app/lib/src/bridge/runtime/plugin_registry.dart`, make
   `PluginSelector` resolve an ordered descriptor list. Its raw-argument scan
   retains every `--plugin <id>` and `--plugin=<id>` occurrence before `--`.
   Any CLI occurrence overrides settings; otherwise the exact
   `BridgeSettings.enabledPlugins` order wins; only an unset key falls back to
   sole OpenCode. Reject duplicate ids, unknown ids, `--plugin=` and an
   explicitly empty settings list. Continue deferring invalid-settings errors
   to `RunCommand` so help/logout/config remain usable, but never silently turn
   an explicit empty set into OpenCode.
4. In `bridge/app/bin/bridge.dart`, register `plugin` with `addMultiOption` and
   `splitCommas: false`, then construct one `PluginCliOptionsMapper` per selected
   descriptor so all selected namespaced options are accepted in one parse.
   Parse an insertion-ordered `Map<String, PluginConfig>`, run every descriptor's
   `validateConfig` in selected order, and validate every `--import-plugin`
   against the complete selected set before sleep-prevention work,
   authentication, availability I/O, predecessor waiting, or startup-lock/
   takeover work. Emit deprecation notices only after every config is valid.
   Carry the ordered ids/configs through `BridgeCliOptions`, `runBridgeApp`, and
   `BridgeRuntimeRunner.run`; update `BridgeSettings.enabledPlugins` comments
   without changing its persisted JSON shape.
   Keep two defaults explicit and separate. Name the first configured id
   `defaultEnabledPluginId` and mark it `PluginMetadata.isDefault` for
   new-client discovery, but
   `legacyMissingPluginId` remains the OpenCode compatibility value decoded by
   `CreateSessionRequest`, `PluginProjectIdRequest`, and `Session`. Deprecated
   `GET /agent` also uses that OpenCode value. An omitted legacy id therefore
   returns 503 when OpenCode is not operational; it is never rewritten to
   `enabledPluginIds.first`. New clients remain responsible for sending the id
   selected from `GET /plugin` in Stage 8.
5. Replace `bridge/app/lib/src/bridge/runtime/plugin_manager.dart` with the
   canonical Layer-3
   `bridge/app/lib/src/services/plugin_lifecycle_service.dart`.
   `PluginLifecycleService()` has no injected collaborator and no start
   callback type. Add the exact app-internal record
   `typedef PluginCompositionView = ({Set<String> knownPluginIds, List<String>
   enabledPluginIds, String defaultEnabledPluginId, Map<String,
   BridgePluginApi> operationalPlugins});`. The list/set are unmodifiable stable
   selection values and `operationalPlugins` is the service's unmodifiable live
   view. `compositionView` returns all four fields from one synchronous service
   read; no consumer assembles them from independent getters. Its runner-facing
   initialization is `registerSelection({required Set<String> knownPluginIds,
   required List<({String id, String displayName, bool isDefault})>
   enabledPlugins})`, called exactly once before availability I/O so selected
   order never depends on concurrent probe/start completion order. Its outcome
   methods are `registerUnavailable({required String id})` and `Future<void>
   registerStart({required String id, required Future<BridgePlugin> startFuture,
   required Duration shutdownBudget})`. It
   owns ordered metadata, every returned instance and registration-settlement
   future, status subscriptions, the live operational view, and replay-latest
   ordered metadata snapshots. On each returned instance it validates
   `id == plugin.api.id` in this service, not in `BridgeRuntime` or
   `Orchestrator`; an identity mismatch is failed/unroutable but the instance
   remains owned for teardown.
6. Publish every returned nonterminal instance as operational immediately,
   including `PluginStarting`. Map `PluginStarting`/`PluginReady` to wire
   `ready`, `PluginDegraded`/`PluginRestarting`/`PluginStopping` to `degraded`,
   descriptor unavailability to `unavailable`, and terminal `PluginFailed`/
   `PluginStopped` or a thrown start to `failed`. A terminal status removes only
   that API from the live operational map. Never copy
   `PluginUnavailable.message`, `PluginStatus.userActionHint`, failure reasons,
   diagnostics, endpoints, process details, or backend names into
   `PluginMetadata.actionHint`. Use only these bridge-authored mappings from the
   exposed lifecycle state: unavailable -> `Check the bridge console to make
   this plugin available.`; degraded -> `Check the bridge console if this
   plugin needs attention.`; failed -> `Check the bridge console and restart
   the bridge to retry this plugin.`; ready -> null. Descriptor-authored
   availability guidance remains Console-only.
   A `registerStart` settlement handles an ordinary thrown start as failed
   metadata and completes normally so one source cannot cancel its peers. It
   publishes the same failed metadata for `PluginStartAbortedException` but
   rethrows that exception after publication; the runner treats it as expected
   only when the shared shutdown controller is aborted and otherwise preserves
   it. For a returned instance the settlement completes only after identity
   validation, initial `currentStatus` inspection, replay-latest status
   subscription installation, the corresponding operational-map publication/
   removal, and ordered metadata publication have all settled. Install the
   subscription and reconcile
   `currentStatus` idempotently so a transition at registration cannot be
   missed. The runner must not compose from lifecycle before all such futures
   complete.
   `disposeStartedApis()` concurrently calls `api.dispose()` on every returned
   instance, including instances no longer operational; once early disposal has
   begun, any instance returned later is disposed before its registration
   settles. `stopAll` snapshots every returned/in-flight registration, awaits
   lifecycle settlements, launches all available instance shutdowns
   concurrently, attempts all, and preserves the first non-expected error.
   Status subscriptions and the metadata stream close in `dispose` even when a
   stop fails. Replace `test/bridge/runtime/plugin_manager_test.dart`
   with `test/services/plugin_lifecycle_service_test.dart`; delete
   `plugin_failure_latch.dart` and its test. This removes only the old
   bridge-global `PluginFailureLatch` reaction: a terminal plugin failure no
   longer cancels the relay session or determines the process exit code.
7. Refactor `BridgeRuntimeRunner` so all selected
   `BridgePluginDescriptor.checkAvailability` calls start concurrently after
   authentication and all settle before the startup mutex is requested.
   Register the complete static descriptor-id set and ordered selected metadata
   once through `registerSelection` before availability I/O or lifecycle
   outcomes are recorded.
   Preserve selected order when recording results and printing each unavailable
   plugin's descriptor-authored Console guidance. If no descriptor is
   available, return the existing failure outcome before predecessor takeover,
   startup-lock acquisition, or `BridgeInstanceService.enforceSingleLiveBridge`;
   unavailable descriptors are registered with lifecycle for discovery when at
   least one descriptor can start. If at least one descriptor was available,
   takeover remains justified even when every later start fails: continue to
   composition with an empty operational view and ordered failed metadata. The
   runner, not lifecycle, invokes all descriptor methods.
8. Replace `startPluginUnderStartupMutex` with a plural startup operation that
   puts the whole available set inside one logical
   `StartupMutexRepository.withLock` scope (the existing contention retry may
   retry that whole scope, never one plugin). Call
   `BridgeInstanceService.enforceSingleLiveBridge` exactly once after lock
   acquisition. Build one `BridgePluginHostImpl` per available descriptor with
   `pluginStateDirectoryPath(paths:, pluginId:)`: OpenCode keeps its frozen
   `<cacheDirectory>/runtime` directory and reuses the runner's existing
   `RuntimeFileApi` plus one `BridgeHostJsonStore`; each non-OpenCode
   `<installRoot>/plugins/<id>` directory gets exactly one new `RuntimeFileApi`
   and one `BridgeHostJsonStore`. Never construct two `RuntimeFileApi` instances
   for the same state directory. Lifecycle receives no host/process/store input.
9. Under that one mutex, call `_ensurePluginRuntime` sequentially in configured
   order. Immediately after one descriptor's provisioning settles, the runner
   invokes `Future.sync(() => descriptor.start(host))`, passes that future to
   `registerStart`, and proceeds to the next descriptor without awaiting it.
   Collect the `Future<void>` returned by each `registerStart` and await all of
   those lifecycle-settlement futures after the provisioning loop, capturing
   each error so one failure cannot skip later settlements; awaiting raw
   descriptor futures is insufficient because identity/status/map/metadata
   publication may still be pending. After all settle, ignore only a
   `PluginStartAbortedException` paired with the shared controller's aborted
   state and preserve any other settlement error. When the controller is
   aborted, return the existing successful "start aborted as requested" outcome
   after all settlements instead of composing a new runtime. Starts still
   overlap later provisioning and each other. Record an individual ordinary
   thrown or terminal start as failed/unroutable and continue; returned
   nonterminal instances remain operational. Keep the mutex through the
   existing cooperative global-abort result and all lifecycle settlements. A
   single shared
   `StartAbortController` is passed to every host and is triggered by shutdown.
10. Make `Orchestrator` the sole composer of the runtime domain graph. Its
    Stage 7 constructor is `Orchestrator({required BridgeConfig config,
    required RelayClient client, required String legacyMissingPluginId,
    required PluginLifecycleService pluginLifecycleService, required
    AppDatabase database, required http.Client httpClient, required
    ProcessRunner processRunner, required AccessTokenProvider
    accessTokenProvider, required TokenRefresher tokenRefresher, required
    BridgeRegistrationService bridgeRegistrationService, required
    FailureReporter failureReporter, required BridgeRestartService
    restartService, required bool filesystemAccessOk, required
    ControlStatusNotifier? statusNotifier})`. Remove the separate
    `operationalPlugins`, `enabledPluginIds`, and `defaultEnabledPluginId`
    parameters completely. At the start of `create`, read exactly one
    `final pluginComposition = pluginLifecycleService.compositionView` and use
    that view for every repository/service constructor. The lifecycle service
    remains the sole runtime-state authority; the compatibility-only
    `legacyMissingPluginId` is not an enabled/default substitute. Orchestrator
    constructs repositories, services, listeners, handlers, and the router; no
    other class composes across those layers.
11. Remove `BridgeRuntime.create`. `BridgeRuntimeRunner` creates the database,
    calls `Orchestrator(...).create()`, then passes the completed
    `OrchestratorComposition` to `BridgeRuntime({required AppDatabase database,
    required FailureReporter failureReporter, required BridgeRestartService
    restartService, required OrchestratorComposition composition})`.
    Keep the exact record `typedef OrchestratorComposition = ({OrchestratorSession
    session, CatalogImportService catalogImportService, SessionRepository
    sessionRepository, SessionUnseenService sessionUnseenService,
    SessionViewTracker sessionViewTracker});`; these are the composed/shared
    instances that runtime/debug ownership actually reads.
    `BridgeRuntime` stores/disposes those exact instances and constructs no DAO,
    repository, service, handler, listener, or router. `OrchestratorSession`
    receives only collaborators it invokes or disposes: replace its singular
    `PluginEventListener` parameter with required
    `List<PluginEventListener> pluginEventListeners`, retain the one required
    binding listener, deletion listener, and dispatcher, remove its
    `BridgePluginApi`, and pass neither the operational map nor lifecycle
    service. It exposes its exact shared `RequestRouter` plus
    `Stream<SesoriSseEvent> localWireEvents`; the latter contains the already-
    mapped events the orchestrator publishes to phones. Audit every remaining
    private-constructor field for an actual read.
    Remove singular `BridgeConfig.pluginEndpoint` from
    `lib/src/bridge/models/bridge_config.dart` without replacing it with another
    runtime field; after starts settle, `BridgeRuntimeRunner` prints each
    returned instance's `describe()` target in enabled order. Startup output has
    no singular target assumption and session state carries no unused target
    list.
12. Convert the direct single-plugin fields in `SessionRepository`,
    `ProjectRepository`, `SessionUnseenRepository`, `AgentRepository`,
    `ProviderRepository`, `QuestionRepository`, `PermissionRepository`,
    `WorktreeRepository`, and `HealthRepository` to the shared live operational
    map only where those repositories perform plugin I/O. Pass enabled order,
    configured default, or legacy OpenCode id only to repositories that consume
    that value; do not thread lifecycle or the map through handlers/services
    with no plugin selection. Keep
    `RequestRouter({required List<RequestHandlerBase> handlers})` unchanged: it
    receives ordered handlers only and never a plugin map.
    Keep `ProjectRepository.getProjects/getProject` and
    `SessionRepository` project/root/detail/child catalog methods exactly DAO-
    backed: they must not inspect, call, or await the map. Preserve the current
    project-only open/rename behavior against the configured new-client default
    API and return 503 if that API is unavailable; do not fall through to a
    different operational plugin.
    In this stage, delete the unused
    `SessionUnseenRepository.ensureRootSessionActivity` method from
    `bridge/app/lib/src/bridge/repositories/session_unseen_repository.dart`
    rather than generalizing its native/derived plugin branching. The
    `297fecc3` call audit finds no production or test invocation: only the
    declaration and its class/field doc links exist. Remove those links and the
    method-only `ProjectsDao`/`AppDatabase`/capability/`Log` dependencies, and
    update constructor fixtures in
    `test/bridge/services/session_unseen_service_test.dart`,
    `test/bridge/orchestrator_emit_bridge_event_test.dart`,
    `test/bridge/orchestrator_registration_test.dart`,
    `test/bridge/orchestrator_error_recovery_test.dart`,
    `test/bridge/orchestrator_token_reauth_test.dart`, and
    `test/bridge/routing/routing_test_helpers.dart`. Retain
    `SessionUnseenService.reconcileVanishedSessions` and
    `SessionUnseenRepository.deleteSessionsNotIn` for Stage 9; make only their
    source plugin id explicit as needed to remove the singular API constructor
    dependency. The Stage 7 audit command is
    `rg "ensureRootSessionActivity" bridge/app/lib bridge/app/test`; it must
    return no matches. Do not delete or otherwise broaden cleanup of any other
    Stage 9 dead path.
13. In `SessionRepository`, make one lookup helper resolve an explicit request
    id and another resolve `SessionDao`'s persisted `pluginId`; both return 503
    before plugin, git-cleanup, or mutation side effects when the API is absent.
    Route create/commands by the request id and route rename, delete, archive,
    prompt, command dispatch, abort, messages, and derived-directory priming by
    the stored binding. Key tombstone caches, binding lookups, binding commits,
    status translation, and active-summary
    translation by `(pluginId, backendSessionId)`, not backend id alone. Pass a
    stored session's plugin id through `SessionLifecycleService` ->
    `WorktreeService` -> `WorktreeRepository.removeWorktree` for best-effort
    `deleteWorkspace`. Apply the same binding-first rule in
    `QuestionRepository` and `PermissionRepository`; the nullable legacy
    `rejectQuestion` path uses OpenCode, never the first enabled id.
14. Make `AgentRepository`, `ProviderRepository`, and
    `SessionRepository.getCommands` select the exact `PluginProjectIdRequest`
    id before resolving the persisted project path or doing plugin I/O.
    `SessionCreationService` retains its current early
    `ensurePluginAvailable` ordering before metadata/git work. An unknown,
    disabled, or enabled-but-unavailable requested plugin returns 503 on these
    execution routes; project 404 remains distinct.
    Provider/model/agent/command ids are never merged across plugins.
15. Implement aggregate semantics and finite per-source deadlines in the owning
    repositories, not handlers. Add required `Duration aggregateSourceDeadline`
    constructor parameters to `SessionRepository`, `ProjectRepository`,
    `HealthRepository`, and `QuestionRepository`; `Orchestrator` passes the same
    `Duration(seconds: 5)` to all four, and each repository applies it around
    each aggregate-source plugin call before awaiting the calls concurrently.
    `SessionRepository.getSessionStatuses` concurrently queries every
    operational API, translates with same-plugin DAO bindings, merges successful
    Sesori-id statuses, drops unknown backend handles, and reports every enabled
    non-operational, throwing, or timed-out source once in ordered
    `unavailablePluginIds`; `GetSessionStatusesHandler` continues to depend only
    on that repository. Active summaries are translated per plugin, merged by
    normalized durable project path, and isolate a throwing source by logging
    its plugin id and omitting only that source.
    `QuestionRepository.getProjectQuestions`
    validates the project once, concurrently queries every operational plugin,
    translates each result under that plugin id, and applies the same five-second
    deadline per source. It remains all-or-nothing: any throw or timeout fails
    the whole request because no partial-question contract exists; an empty
    operational map returns 503 rather than a misleading empty result.
    `HealthRepository` concurrently probes operational APIs and emits `healthy:
    false` for enabled unavailable/throwing/timed-out plugins in enabled order.
    Top-level `HealthResponse.healthy` remains bridge-level, so
    `HealthCheckHandler` no longer maps one backend outage to a bridge-global
    503.
    Define `ProjectActivityService.reconcile({required String? pluginId})`
    exactly: `pluginId: null` is the startup aggregate and snapshots every
    currently operational id from `ProjectRepository.operationalPluginIds`; a
    non-null id is a sourced reconnect and reconciles only that plugin.
    `OrchestratorSession.run` calls `reconcile(pluginId: null)` before its
    startup project summary. Change
    `ProjectRepository.listProjectActivityEvidence` to
    `Future<List<ProjectActivityEvidence>>
    listProjectActivityEvidence({required String pluginId})`; it resolves one API
    from the shared live map, applies the source deadline, and returns only that
    source's evidence. Add `pluginId` to
    `ProjectActivityEvidence` in
    `lib/src/bridge/repositories/models/project_activity_evidence.dart` and key
    every derived-session/tombstone lookup by that same id. Native evidence maps
    each declared normalized `PluginProject.directory` back to the durable
    catalog project id; it never uses a backend-native project id as a shared
    aggregation key. Remove the stale-snapshot
    `ProjectActivityReconciliationData` wrapper; add
    `getActivities({required Set<String> projectIds})` for the service to batch-
    read current stored values immediately before each successful source's
    serialized merge/write. Startup launches all source reads concurrently;
    each throw/timeout is logged and omitted independently, while each successful
    source publishes independently. Thus one source cannot prevent another
    source's publication. `getProjects` remains a direct catalog repository call
    outside that write tail, so failed, timed-out, or in-flight reconciliation
    never blocks catalog reads.
16. Generalize the existing import domain without per-plugin repository peers.
    Use `CatalogImportRepository({required Map<String, BridgePluginApi>
    operationalPlugins, required ProjectsDao projectsDao, required SessionDao
    sessionDao, required CatalogHydrationsDao catalogHydrationsDao})`, with
    `getHydrationCompletion({required String pluginId})` and
    `importCatalog({required String pluginId, required CatalogImportControl
    control})`; each operation resolves one API once and keeps all enumeration/
    publication keys scoped to that id. Use
    `CatalogImportService({required CatalogImportRepository repository, required
    Set<String> knownPluginIds, required List<String> enabledPluginIds, required
    Map<String, CatalogEmptyHydrationPolicy> emptyHydrationPolicies})`. In
    `Orchestrator`, source the known/enabled/map inputs from its one
    `pluginComposition` view and build the exact policy map from operational API
    capability:
    `NativeProjectsPluginApi` maps to `complete` and
    `BridgeDerivedProjectsPluginApi` maps to `retry`. The service contains no
    OpenCode/Codex/Cursor ids or other backend strings.
17. `CatalogImportService` owns controls, operations, latest statuses, and
    policies keyed by plugin while exposing the existing one broadcast progress
    stream. Duplicate same-plugin starts join, different plugins import
    independently, and dispose cancels/awaits every operation. Validate before
    mutation with distinct typed failures:
    `CatalogImportPluginUnknownException` for an id outside `knownPluginIds`
    maps to HTTP 404 `plugin not found`;
    `CatalogImportPluginNotEnabledException` for a known id outside
    `enabledPluginIds` keeps the current HTTP 404 `plugin not selected`; and
    `CatalogImportPluginUnavailableException` for an enabled id absent from the
    operational repository map maps to HTTP 503 `plugin unavailable`.
    Automatic hydration starts once for each operational id in enabled order
    after SSE/Console subscribers exist; ordered `--import-plugin` triggers then
    join or start their selected ids. One plugin's failed/cancelled import
    publishes its typed terminal progress and does not cancel another pipeline.
18. Keep one shared `SessionEventService`, one
    `SessionEventTracker({required int maxPendingEntriesPerPlugin})`, and one
    `SessionEventDispatcher`, but change the dispatcher's single `_tail` to
    per-plugin ordered tails keyed by source/commit/deleted-session plugin id.
    Replace the tracker's global insertion list with per-plugin insertion lists
    and evict only the oldest entry for the plugin exceeding its 1,024-entry
    allowance; root/child/translation indexes remain keyed by plugin and there
    is no tracker per plugin.
    This preserves source order and mutation invariants within one plugin while
    allowing plugin B to progress when plugin A normalization blocks. In
    `Orchestrator.create`, construct one `PluginEventListener` per operational
    API, exactly one unfiltered `SessionBindingCommitListener({required
    Stream<SessionBindingsCommitted> source, required SessionEventDispatcher
    dispatcher})` over `SessionRepository.bindingCommits`, and exactly one
    `SessionDeletionListener` over
    `SessionMutationDispatcher.deletedSessions`. Keep the existing input
    `SourcedBridgeEvent` in `session_event_service.dart`, and add exactly
    `typedef NormalizedSourcedBridgeEvent = ({String pluginId, BridgeSseEvent
    event});` beside `SessionEventDispatcher`. Its `events` getter becomes
    `Stream<NormalizedSourcedBridgeEvent>`. Plugin normalization output uses the
    captured source id, binding output uses `commit.pluginId`, and deletion
    output uses `session.pluginId`; source attribution is never inferred from an
    event payload. Start all listeners from that one sourced normalized
    broadcast stream and cancel/await all listeners before awaiting dispatcher
    tails and closing its stream. A source error/closure is reported but never
    closes another plugin's input or the shared phone SSE pipeline.
19. Add the canonical `bridge/app/lib/src/routing/get_plugins_handler.dart` with
    `GetPluginsHandler({required PluginLifecycleService lifecycleService})` for
    `GET /plugin`. It receives only that Layer-3 service and returns
    `PluginListResponse` from its ordered snapshots; it never inspects
    descriptors, hosts, diagnostics, or APIs, and exposes no endpoint, process,
    assistant-specific detail, descriptor guidance, status user-action text, or
    failure reason. It returns only lifecycle's fixed generic `actionHint`
    mapping from item 6.
    Register it in the one `RequestRouter` built by `Orchestrator.create`.
    `RequestRouter` remains an ordered-handler iterator with no plugin map.
    `OrchestratorSession` consumes
    `Stream<NormalizedSourcedBridgeEvent>`; `_processPluginEvent` reads
    `pluginId` before unwrapping, calls
    `ProjectActivityService.reconcile(pluginId: pluginId)` for
    `BridgeSseServerConnected`, and alone maps/enriches the event to
    `SesoriSseEvent`. Route every phone enqueue through one orchestrator-owned
    publisher that also exposes `Stream<SesoriSseEvent> localWireEvents`.
    `BridgeRuntime` passes that already-mapped stream and the exact shared router
    to `DebugServer`. Change `DebugServer` to accept the shared-event stream,
    remove its `BridgeEventMapper` and `SessionRepository`, and retain only JSON
    local fan-out plus routing through the injected router. It constructs no
    plugin listener, normalizer, mapper, repository aggregator, router, or
    plugin API.
20. Update `ControlStatusNotifier` in
    `bridge/app/lib/src/control/control_status_notifier.dart` to observe the
    lifecycle metadata snapshot stream instead of one `BridgePlugin.status`;
    its constructor receives only that consumed stream, relay connection state,
    registration stream, and control client, never the lifecycle service or
    operational map. The runner keeps composing this optional supervised-shell
    listener because it owns the control channel; `Orchestrator` passes it only
    to `OrchestratorSession`, which consumes project summaries, and does not
    thread lifecycle/map state with it. Preserve the existing singular
    control-wire field by deriving bridge plugin health:
    all enabled plugins wire-ready is healthy; any degraded/unavailable/failed
    enabled plugin with at least one operational plugin is degraded; no
    operational plugin is unavailable. Startup phases are settled before this
    notifier is composed and need no new control state. Do not
    change `ControlMessage`, supervised sentinel values, or standalone output
    ownership.
21. Register the full ordered shutdown with `BridgeShutdownCoordinator` before
    any provisioning/start can begin and keep nullable lifecycle/runtime/debug
    references in those already-registered closures. Split signal/acceptance
    closure from drain so the exact sequence is:
    (a) synchronously call the shared `StartAbortController.abort()`, mark
    `CatalogImportService` disposing and cancel every control, complete
    `OrchestratorSession`'s shutdown/request-race signal and close relay input,
    dispose the Console import progress listener, and make `DebugServer` close
    its `HttpServer` plus signal in-flight route races; no debug/import/relay
    request can start after this phase;
    (b) immediately invoke lifecycle `disposeStartedApis()`, which launches
    `api.dispose()` concurrently for every returned terminal, identity-
    mismatched, failed, operational, or otherwise unrouted instance and catches
    late returns as specified in item 6, before waiting for arbitrary backend
    work;
    (c) await the early-disposal batch and all already-signalled import
    operations, the stored session `run` future, plugin/binding/deletion
    listeners, dispatcher tails, prompt/import/local-wire subscriptions and
    streams, and in-flight debug requests/SSE clients; attempt all drains even
    if API disposal or another drain fails;
    (d) call lifecycle `dispose()`, whose `stopAll` concurrently shuts down every
    returned instance and whose `finally` closes status subscriptions and
    metadata streams; and only then
    (e) run shared runtime/database/control/token/update/HTTP cleanup.
    `OrchestratorSession` no longer owns plugin API disposal. Give
    `CatalogImportService`, `OrchestratorSession`, and `DebugServer` idempotent
    begin-shutdown/drain behavior rather than awaiting any of them before phase
    (b).
22. In every shutdown owner, isolate each step, attempt all steps, and retain
    the first non-expected error/stack for rethrow after cleanup. Update
    `BridgeShutdownCoordinator` so errors in a later phase cannot replace an
    earlier error and one synchronously/asynchronously throwing action cannot
    skip another action in that or later phases. A
    `PluginStartAbortedException` is expected successful shutdown settlement
    only when the shared `StartAbortController.isAborted` is true; exclude that
    exact case from first-error capture in runner provisioning/start settlement,
    lifecycle `stopAll`, and coordinator shutdown. The same exception before
    that controller is aborted, and every unrelated error, remains reportable
    and eligible as the first failure. Lifecycle must cancel every status
    subscription and close its snapshot stream in `finally` even when `stopAll`
    fails; session listener/dispatcher/local-wire streams likewise close after
    their tails settle. Keep
    `SupervisedExitCode` values `86/87/88/0/1`, contention/auth/restart sentinel
    precedence, signal behavior, standalone exit behavior, and shutdown-error
    preservation unchanged. The stop-all ordered budget is one concurrent
    plugin budget, not the sum of plugin counts.
23. Add
    `bridge/app/tool/benchmarks/multi_plugin_startup_benchmark.dart`. Compile and
    run it AOT with deterministic fake descriptors for 1, 3, and 8 plugins,
    sequential fixed provisioning gates, and independently blocked starts. Emit
    versioned JSON with commit/OS/CPU, warmup/sample counts, selected count,
    total startup p50/p95/p99/max, first-operational latency, per-plugin start
    latency, maximum concurrent starts, mutex-acquisition count, singleton-
    enforcement count, and state-directory identities. The harness asserts one
    mutex/enforcement, unique state paths, configured provisioning order,
    immediate post-provision launch, overlapping starts, and every lifecycle
    settlement awaited before composition. Record directional results in Stage
    7 findings; fixed-host gating remains Stage 9.
24. Add focused shared contract round trips in
    `shared/sesori_shared/test/models/plugin_runtime_contract_test.dart`. In
    `bridge/app`, extend `plugin_registry_test.dart`,
    `bridge_cli_options_test.dart`, `bridge_cli_dispatch_test.dart`, and
    `run_command_catalog_import_test.dart` for ordered repeatable selection,
    precedence, duplicate/unknown/empty rejection, all-config validation before
    any startup spy, and OpenCode-not-first compatibility. Add lifecycle/runner
    tests for concurrent probes, no mutex/takeover when none are available, one
    mutex/enforcement, state-directory isolation, sequential provision plus
    overlapping starts, and a `registerStart` future that remains pending until
    identity validation, current-status inspection, status subscription,
    operational publication/removal, and metadata publication are observable.
    Cover immediate `PluginStarting` routing, identity mismatch,
    failed/unavailable isolation, raw descriptor/status-hint sentinel strings
    never appearing in DTOs, one consistent `PluginCompositionView`, no
    Orchestrator duplicate-state parameters, all starts failing after justified
    takeover while empty-map relay/catalog composition proceeds, aborting an
    in-flight start, early disposal of every returned/late-returned API,
    concurrent stop-all, subscription closure on stop error, shutdown-caused
    `PluginStartAbortedException` settling successfully, the same exception
    without controller abort remaining an error, and every lifecycle settlement
    awaited before composition.
25. Extend repository/handler/event/import/runtime tests for equal backend ids
    under two plugin ids, binding-routed operations, explicit composer routing,
    unavailable 503 before side effects, ordered status/health metadata,
    per-source status/health timeout fallback, all-or-nothing question timeout,
    and merged activity. In `project_activity_service_test.dart`, prove startup
    calls every operational source independently, a throw/timeout in one source
    does not block another source's merge, `reconcile(pluginId: ...)` calls only
    that source, and a blocked reconciliation does not block `getProjects`.
    Cover independent imports and import unknown/disabled/unavailable route
    distinctions. In `session_event_dispatcher_test.dart`,
    `plugin_event_listener_test.dart`, orchestrator event tests, and
    `debug_server_test.dart`, prove plugin/binding/deletion outputs retain the
    `NormalizedSourcedBridgeEvent` id, a connected event reconciles only its
    source, one global binding/deletion listener remains, per-plugin tracker
    eviction/order permits cross-plugin progress, and DebugServer receives the
    same already-mapped local wire event/router without a second mapper or
    plugin listener/router. Cover `GET /plugin` and full phased shutdown:
    triggers close first, all returned APIs are disposed concurrently before
    blocked import/request/event/debug drains, every phase is attempted, and the
    first non-expected error is preserved.
    Keep and strengthen
    `catalog_read_handlers_test.dart` plus `live_list_baseline.dart` with 1/3/8
    throwing or never-completing plugin maps to prove project/root/detail/child
    reads make zero plugin calls. No timing assertion substitutes for completer-
    based concurrency tests.
26. Verify the documentation-only `bridge/sesori_plugin_interface` changes with
    `dart analyze --fatal-infos` and `dart test`. Regenerate and verify
    `shared/sesori_shared` with
    `dart run build_runner build --delete-conflicting-outputs`,
    `dart analyze --fatal-infos`, and `dart test`. Verify `bridge/app` with
    `dart analyze --fatal-infos`, `dart test`, a host build, AOT compilation of
    `multi_plugin_startup_benchmark.dart`, and one directional 1/3/8 benchmark
    run; analyze the unchanged client workspace against the additive shared
    constructors. Run the no-match call audit from item 12, then run
    `git diff --check` and `aristotle-impl-review`. In the same
    implementation PR, mark Stage 7 complete, advance Current Pointer to Stage
    8, record the implementation base/results/findings and any real plan/risk
    delta. Do not claim completion before those evidence updates land.

Stage 7 workspace and file matrix:

| Workspace | Production changes | Verification |
|---|---|---|
| `shared/sesori_shared` | New plugin-list source/export/generated parts; additive health and status fields/generated parts | old/new JSON round trips; fatal analysis; full package tests |
| `bridge/sesori_plugin_interface` | Documentation-only corrections for multi-descriptor options and per-plugin unavailable/failed semantics; no signature change | audit OpenCode/Codex/Cursor descriptor implementors; fatal analysis; full package tests |
| `bridge/app` | CLI selection/config, lifecycle/runner/host composition, runtime/repository routing, import/event fan-in, discovery/health handlers, control status, shutdown wiring, benchmark | focused plus full app tests; fatal analysis; host build; benchmark AOT/run |
| `docs/parallel-plugins` | pointer, Stage 7 findings/results, plan/risk deltas | plan consistency; `git diff --check` |

Stage 7 does not change plugin implementations, `sesori_plugin_interface`
signatures/behavior, database schema/migrations, relay/auth contracts, or client
API/repository/cubit/UI code. Its interface edits are documentation only. Stage
8 exclusively owns client discovery consumption, chooser state, plugin-scoped
saved selections, and mobile/desktop presentation. Stage 9 exclusively owns
fixed-host performance gating, soak runs, remaining compatibility/dead-path
cleanup (including the other retained reconciliation helpers), broad
architecture documentation, and evidence-based budget changes. Stage 7's
explicit removal of the already-unused `ensureRootSessionActivity` is the only
cleanup exception.

### Stage 8 - Client Plugin and Model/Agent Selection

- Add `PluginApi`, `PluginRepository`, DI, and `NewSessionCubit` plugin state.
- Scope provider/agent/command loads and saved choices by plugin.
- Send plugin id for creation and render unavailable plugins generically.
- Use stored session plugin identity for existing-session composer operations.
- Add the chooser to the existing mobile new-session feature under
  `client/app/lib/features/new_session/` and validate desktop consumers of the
  additive core/shared models.

Acceptance: switching plugins cannot retain backend-local selections; new
clients always send a plugin id; old bridge/session payloads use only the
documented compatibility fallback; module dependency direction is unchanged.

PR-level implementation plan:

1. Keep Stage 8 client-only. Add no bridge, shared-contract, database,
   `module_desktop_core`, desktop presentation, or shared design-system change.
   The Stage 7 `PluginListResponse`, `PluginMetadata`, and
   `PluginLifecycleState` contract is sufficient. Preserve the dependency path
   `RelayHttpApiClient -> PluginApi -> PluginRepository -> NewSessionCubit ->
   mobile UI`; the cubit never imports an API and no product shell performs
   business or transport work.
2. Add `client/module_core/lib/src/api/plugin_api.dart` as the Layer-1
   `@lazySingleton` boundary with exactly
   `Future<ApiResponse<PluginListResponse>> listPlugins()`, implemented as
   `GET /plugin` through the existing `RelayHttpApiClient`. Add
   `client/module_core/lib/src/repositories/plugin_repository.dart` as the
   Layer-2 `@lazySingleton` with the same operation. Return the shared DTO
   directly because it is already backend-neutral and no meaningful mapping
   exists. Export only `PluginRepository` to shell consumers and regenerate
   core DI; do not hand-edit `injection.config.dart`.
3. Treat plugin discovery failure as an explicit unavailable composer, not as
   permission to invent a plugin. In particular, a 404 from a pre-Stage-7
   bridge remains the returned API failure: do not synthesize an OpenCode
   `PluginMetadata`, display name, lifecycle state, or client-owned default.
   The documented legacy fallback remains only at additive wire-decoding
   boundaries where an old `Session` or request omitted `pluginId`; synchronized
   app/bridge releases provide discovery for the new-session chooser.
4. Extend every non-created variant in
   `client/module_core/lib/src/cubits/new_session/new_session_state.dart` with
   required ordered `List<PluginMetadata> availablePlugins`, required
   `PluginMetadata? selectedPlugin`, and required
   `bool isComposerDataLoading`; keep `NewSessionCreated` minimal. Initial state
   has an empty plugin/resource set, no selection, and loading true. Preserve
   bridge order without sorting and select the unique server-authored
   `isDefault` item, regardless of its list index or lifecycle state. A
   `ready` or `degraded` plugin is selectable/routable; `unavailable` or
   `failed` remains visible but cannot load resources or create a session.
   Never silently replace an unavailable default with the first operational
   item, because that would establish a second default authority.
   `NewSessionError` remains the explicit failure variant for both discovery and
   creation: a discovery failure carries its mapped `RemoteFailureReason`, empty
   plugin/resource lists, null selection, and `isComposerDataLoading: false`.
5. Inject `PluginRepository` into `NewSessionCubit`. Initialization first
   discovers plugins, publishes the complete ordered list/default selection,
   and only then loads agents, providers, and commands concurrently with the
   selected plugin id and project id. A discovery error, absent default, or
   unavailable/failed default performs zero composer-resource calls and cannot
   create. Before applying either discovery success or failure after the await,
   return when the cubit is closed and reject any completion whose captured
   load generation is no longer current. Initialization launches one discovery
   operation; Stage 8 adds no retry or concurrent rediscovery path, so the
   generation guard also keeps a future retry from making stale completion
   semantics implicit. On repository failure, emit the exact discovery-error
   state from item 4 and set loading false. Continue logging each independently recovered composer-resource
   error and degrading only that picker to empty; plugin discovery itself is
   not silently recovered.
6. Add `selectPlugin({required String pluginId})` to `NewSessionCubit`. Reject
   unknown, unavailable, failed, sending, and created transitions. For a valid
   switch, increment one monotonically increasing load generation, select the
   plugin immediately, clear agents/providers/commands, agent/model/variant,
   and staged command synchronously, and set composer loading true before
   starting the three requests. Apply results only when both plugin id and
   generation still match, covering A -> B and A -> B -> A late completions
   without cancellation machinery. Keep the chooser usable while the selected
   plugin's composer data reloads.
7. Change `NewSessionSelectionTracker` from a project-only map to the exact key
   `({String projectId, String pluginId})`. Require both values on `read`,
   `write`, and `clear`; retain only explicit agent and
   `AgentModel(providerID, modelID, variant)` choices in memory for the current
   app run. Restore a choice only after the selected plugin's fresh data has
   settled and validate every id/variant as today. Snapshot and clear only the
   matching project-plugin entry after successful creation so a late success
   cannot erase a newer or different-plugin choice. Keep unsent prompt text's
   existing project-only draft key: text is not a backend-local identifier.
8. Gate `createSession` on a selected ready/degraded plugin and completed
   composer load, snapshot that plugin plus the scoped saved selection, and
   always send `selectedPlugin.id` through the existing `SessionService` ->
   `SessionRepository` -> `SessionApi` flow. Preserve current blank-prompt,
   command, worktree, background completion, retry, and navigation behavior.
   Do not change session-id-scoped prompt/abort/question/permission requests;
   the bridge's durable session binding remains their routing authority.
9. Add required `pluginId` to `ProjectSessionContext` and populate it from the
   matched catalog `Session` in `ProjectRepository.findSessionContext`.
   `SessionDetailLoadService` resolves composer identity as
   `session?.pluginId ?? fallbackContext?.pluginId`; if neither detail nor
   catalog context recovers the session, return empty agents/providers/commands
   without issuing plugin-scoped calls. Remove its direct
   `legacyMissingPluginId` substitution. Old session JSON still decodes missing
   identity to OpenCode in the shared `Session.fromJson` boundary, so released
   payload compatibility remains concrete and centralized.
10. Add a product-owned `new_session_plugin_chooser.dart` under
    `client/app/lib/features/new_session/` and wire it above the worktree toggle
    in `NewSessionScreen`. Render bridge order and `displayName`, identify the
    current selection, disable unavailable/failed rows, keep degraded rows
    selectable, and display bridge-authored `actionHint` generically without id,
    name, or payload-shape checks. Keep the chooser interactive during composer
    reload while disabling the prompt/model/agent/command composer until a
    routable selection is fully loaded. For discovery failure, render the
    existing localized `RemoteFailureReason` error presentation with no chooser,
    leave the composer visible but disabled, and provide no creation path; do
    not turn an empty plugin list into an empty-but-usable composer. Reuse Prego tokens and existing menu or
    modal primitives; do not broaden `module_prego` solely to add disabled menu
    behavior.
11. Add only localized shell-owned labels/status copy in `app_en.arb` and run
    Flutter localization generation. Dynamic `displayName` and `actionHint`
    remain contract content and are not translated or reinterpreted. Do not add
    desktop UI: the current desktop shell has no new-session surface. Validate
    desktop and desktop-core downstream against regenerated core DI/exports.
12. Add focused API/repository tests for `GET /plugin`, DTO parsing, preserved
    order, and surfaced discovery errors. Add cubit/tracker tests proving a
    non-first server default, ready/degraded selection, unavailable/failed
    blocking, explicit plugin ids on all resource/create calls, synchronous
    reset, project-plugin restoration, matching-snapshot clear, and A-B/A-B-A
    stale-response rejection. Add project/session-detail tests for direct and
    catalog-fallback identity and zero plugin calls when identity is unknown.
    Add mobile widget tests for ordered generic presentation, disabled and
    degraded choices, loading/creation gates, stale visual-state removal, and
    preservation of the existing send/background/navigation behavior.
13. Regenerate only owned artifacts: core Injectable/Freezed outputs and mobile
    localization outputs. Run focused tests, then full fatal analysis and tests
    for `module_core` and `app`; run downstream fatal analysis/tests for
    `module_desktop_core` and `desktop`; run the shared old-session compatibility
    round trip, `git diff --check`, and `aristotle-impl-review`.
14. In the same PR, mark Stage 8 complete, advance Current Pointer to Stage 9,
    record the implementation base/results/findings and any real plan/risk
    delta. Stage 9 retains fixed-host performance, soak, compatibility cleanup,
    and broad architecture-documentation ownership.

Stage 8 workspace and file matrix:

| Workspace | Production changes | Verification |
|---|---|---|
| `client/module_core` | Plugin API/repository/DI; plugin-aware new-session state, selection, creation, and existing-session fallback identity | codegen; focused/full pure-Dart tests; fatal analysis |
| `client/app` | Mobile chooser, composer gating, localized presentation | localization generation; focused/full Flutter tests; fatal analysis |
| `client/module_desktop_core`, `client/desktop` | No planned source changes; downstream consumers only | full package tests and fatal analysis |
| `docs/parallel-plugins` | Stage pointer, findings/results, plan/risk deltas | plan consistency; `git diff --check` |

Stage 8 does not persist the selected plugin, add a client-side plugin registry,
change prompt draft identity, alter bridge/session wire contracts, or duplicate
plugin-specific presentation knowledge. Enabled/default/runtime metadata remains
bridge-authored; backend-local provider/model/agent/command identities exist
only under the selected or stored plugin identity.

### Stage 9 - Performance Gate and Cleanup

- Run the fixed-host matrix and large-history import/event soak tests.
- Remove remaining dead live-list derivation, reconciliation, compatibility
  branches whose removal date has arrived, and temporary shadow instrumentation.
- Record final schema/query plans, performance results, operational import
  guidance, and any evidence-based budget revisions.
- Update `ARCHITECTURE.md`, `CONSIDERATIONS.md`, `ROADMAP.md`, and compatibility debt to
  reflect shipped behavior.

Acceptance: all future-execution principles in `ARCHITECTURE.md` are demonstrated by
tests/results; bridge, shared, client, mobile, and desktop verification is green.

## 11. Verification Matrix

Every affected stage runs generated-code checks, fatal-info analysis, and tests
for each changed workspace. In addition:

- Migration tests use `SchemaVerifier.migrateAndValidate`, old-version fixture
  inserts, post-migration value assertions, and foreign-key checks.
- Repository tests assert mapping precedence, SQL pagination/order, binding
  uniqueness, typed 404/503 behavior, and no same-layer dependencies.
- Mutation tests cover create/event races, rename/import races, archive behavior,
  tombstones, parent cascade, and plugin failures.
- Event tests table-drive every `BridgeSseEvent` variant containing a session
  reference and prove no backend handle or plugin id reaches shared events.
- Child-event tests include an out-of-order burst at the configured tracker
  bound and an explicit overflow case that verifies warning/eviction semantics.
- Import tests cover first hydration, version bump, explicit re-import,
  duplicate triggers, cancellation boundaries, failure, non-destructive
  absence, stale-write guards, and progress terminality.
- Runtime tests gate availability/provision/start independently and prove start
  overlap, failure isolation, state-directory isolation, and complete shutdown.
- Client tests cover old/new JSON, default selection, plugin switching, scoped
  saved choices, unavailable state, and create payloads.
- Integration tests keep fake plugins that count and optionally never complete
  every API method; catalog list requests must neither call nor await them.

## 12. Rollout

Stages 1-6 ship with one selected plugin and preserve current CLI defaults.
Schema and write-through changes are additive before read cutover. Automatic
hydration must succeed or clearly report import-required; list reads never fall
back to plugins after Stage 6.

Stage 7 is the only runtime enablement point. Persisted `enabledPlugins` with
multiple entries becomes active then. A single entry follows the same new code
path, so all routing/lifecycle behavior is exercised before users add a second
plugin.

No feature flag is persisted in catalog rows. Rollback before identity cutover
may use the previous binary against the additive schema. After new random Sesori
ids exist, rollback requires a binary that understands `backend_session_id`;
release notes must identify that minimum rollback version.

## 13. Risk Register

| Risk | Mitigation / owning stage |
|---|---|
| Session id collisions across plugins | Separate Sesori/backend identity and unique binding index (2-3C); activate random production ids with event translation (4) |
| Migration loses routes or metadata | Preserve old ids and exhaustive migration fixtures (2) |
| Import overwrites a newer event/rename | `projection_updated_at` guard and bridge-owned override fields (3-5) |
| Partial or destructive import | enumerate before one transaction; never delete absence (5) |
| Codex scan blocks relay/event isolate | plugin-owned worker isolate and responsiveness test (5) |
| Long publication blocks reads | bounded chunked transaction (5); file-backed WAL/read pool and held-writer/concurrent-import read evidence (6) |
| Unknown events discover external roots | binding lookup and proven-parent-only insertion (4) |
| Out-of-order children grow memory or cross-evict | one tracker with bounded per-plugin pending partitions, drain on binding, warning on same-plugin eviction (4, 7) |
| One event stream blocks another | normalize before stream merge; per-plugin ordering tests (4, 7) |
| Backend ids leak to clients | exhaustive event/request mapping tests (3-4) |
| Provider/model ids cross-route | explicit plugin scope and project+plugin saved keys (7-8) |
| One plugin failure exits bridge | independent lifecycle status and operational map (7) |
| Cold provisioning serializes all readiness | sequential provisioning with starts launched immediately after each plugin's provision phase; measure before changing lock contracts (7, 9) |
| Older clients create on the wrong plugin | stable documented default plus compatibility debt/removal date (1, 8) |
| Plan drifts from implementation | same-PR pointer, findings, delta, and risk updates (all) |

## 14. Findings and Plan Deltas

Record implementation discoveries here, newest first. A delta names the
affected locked decision and updates the owning section in the same PR.

- **Stage 8:** Implemented from the approved Stage 8
  plan at `abd24c3e`. `module_core` now discovers ordered bridge-authored plugin
  metadata through `PluginApi`/`PluginRepository`, selects only the unique
  server default, treats ready/degraded plugins as routable, and keeps
  unavailable/failed plugins visible but blocked. New-session resource loads,
  saved agent/model/variant choices, and creation are explicitly plugin-scoped;
  synchronous resets plus one generation guard reject A-B and A-B-A stale
  completions. Discovery failures expose their mapped reason without synthetic
  OpenCode metadata. Existing-session composer loads use detail identity first,
  catalog identity second, and make no plugin-scoped calls when neither exists.
  Mobile owns the generic ordered chooser, bridge action-hint rendering, and
  composer gates; no desktop, `module_desktop_core`, `module_prego`, bridge, or
  shared production source changed. Core Injectable/Freezed and mobile
  localization generation completed. Fatal analysis and full tests passed for
  `module_core` (548), mobile (659), `module_desktop_core` (52), and desktop
  (15); the shared legacy-plugin compatibility test passed (8), and
  `git diff --check` was clean. Full mobile verification exposed one shared
  adaptive-router test harness that also constructs `NewSessionScreen`; adding
  its required plugin repository fixture resolved all six downstream failures.
  No locked design or risk-register delta was required. The environment exposes
  Stage 7's reviewed lifecycle-decoder follow-up was then merged forward;
  combined-base fatal analysis passed for core/mobile, and focused core/mobile
  discovery, selection, routing, and widget tests passed. Aristotle implementation
  review `ses_08f1d58bfffeOQfHeu6yR5XkGH` approved the final architecture.
- **Stage 7:** Implemented from stacked Stage 6 base `297fecc3`. Ordered
  repeatable selection now starts available plugins under one takeover/mutex,
  provisions in configured order while overlapping starts, and composes one
  lifecycle-owned live operational view. Repositories route execution by
  explicit or persisted plugin identity; aggregate status, health, activity,
  imports, and sourced events isolate plugins; `GET /plugin` exposes only
  bridge-authored lifecycle metadata; catalog reads remain database-only; and
  phased shutdown immediately disposes returned APIs while independently
  draining import/session/debug work and preserving the first failure. Shared
  generation was stable; fatal analysis passed for shared, plugin interface,
  bridge app, all OpenCode/Codex/Cursor descriptor implementors, and all six
  client modules. Full tests passed for shared (316), plugin interface (145),
  and bridge app (1,967); the host binary and benchmark compiled AOT; the
  `ensureRootSessionActivity` audit and `git diff --check` returned no matches/
  errors. On the directional macOS arm64 working-tree fixture (3 warmups, 20
  samples), total-startup p95 was 7.959/13.079/26.024 ms for 1/3/8 plugins and
  first-operational p95 was 7.943/7.843/7.776 ms. Multi-plugin runs reached two
  concurrent starts while every run retained one mutex acquisition, one
  singleton enforcement, configured provisioning order, and unique state
  directories. Aristotle implementation review
  `ses_08fb288c7ffeAAA2ajnLeWmeK5` approved the final architecture. The review
  exposed test-only production factories, grouped shutdown actions, and
  duplicate wire-publication paths; all were removed without changing a locked
  decision. Host verification also exposed the app Makefile's stale standalone
  Dart lookup, which now resolves the workspace-pinned Flutter SDK like the
  bridge Makefile. No plan or risk delta was required.
  Final pre-PR review `ses_08f6f612fffeF3DVktms317gbE` removed a callback
  wrapper around `StartAbortSignal` and an OpenCode-id branch from runtime-file
  selection; the coordinator now reads the signal directly and the runner
  reuses file APIs generically by resolved state-directory identity. The
  corrected architecture was approved, with focused runtime tests and fatal
  analysis passing.
- **Stage 7 planning:** The stacked Stage 6 code at `297fecc3` still selects and
  validates one descriptor/config, probes and starts it under a per-start mutex
  helper, binds production ownership to `PluginManager` plus a bridge-global
  `PluginFailureLatch`, and constructor-injects one API through runtime,
  repositories, import, events, health, and supervised status. The current
  catalog list handlers are DAO-backed, status routing is repository-owned,
  Codex import is isolate-backed, `RequestRouter` is already generic, and Stage
  4 already gives `DebugServer` the orchestrator's router and normalized stream;
  Stage 7 retains the router but moves debug to the orchestrator's mapped local
  wire stream so source identity survives normalization without duplicate
  mapping. Stage 7 therefore broadens existing composition rather than
  rebuilding those seams. Aristotle plan review
  `ses_0905a3941ffeqKbiIw4bPEgb0e` also fixed
  startup ownership in the runner, lifecycle registration/id validation,
  per-plugin tracker eviction, singleton global listeners, finite aggregate
  deadlines, host-store isolation, exact import policy/routing, minimal wire
  states, and complete first-error-preserving shutdown. The second Stage 7
  Aristotle review made lifecycle registration itself awaitable through map and
  metadata settlement, removed duplicate Orchestrator state authorities, kept a
  source envelope through reconnect processing, defined per-plugin activity
  reconciliation, selected the already-unused
  `ensureRootSessionActivity` for Stage 7 removal, reordered shutdown around
  immediate API disposal, classified only controller-caused start abort as
  expected, retained empty-map composition after all starts fail, and prohibited
  raw descriptor/status guidance on shared DTOs. `/plugin`, per-plugin health,
  and unavailable status sources require additive shared DTO fields;
  plugin-interface edits are documentation-only, and plugin implementations,
  client layers, schema, and migrations remain unchanged.
- **Stage 6:** Project, project-detail, root-session, session-detail, child,
  and project-path reads now map only durable catalog rows and never require an
  operational plugin. Project lists batch unseen state once and leave directory
  probing to targeted open/rename paths; session pagination and tie-breaking run
  in SQL, and the temporary child/root live-list publication paths are gone.
  Native rowless active summaries retain one private targeted enumeration that
  commits bindings and publishes binding commits. Production and all three
  file-backed benchmarks now share `AppDatabase.openFile`, with WAL and a
  bounded four-reader pool; a held-writer test proves readers observe the last
  committed snapshot without waiting. On the directional macOS arm64 M4 Pro AOT
  fixture (2,000 samples), p95/p99 were 0.989/1.071 ms for 500 projects,
  0.944/0.998 ms for 100 roots from 10,000, and 7.949/8.226 ms for 1,000
  unpaginated roots, with zero plugin calls. A 10,000-root import published in
  139.379 ms while a concurrent catalog read completed in 1.216 ms. During the
  50,000-root fixture, the read completed in 1.147 ms before the 701.255 ms
  publication finished; scheduling lag was 7.853/20.270 ms p99/max, RSS growth
  was 78,004,224 bytes, and the database was 35,700,736 bytes. These are local
  directional results; Stage 9 still owns fixed-host gating. Schema v11 and all
  migration/generated artifacts are unchanged.
- **Stage 5:** The selected plugin now has explicit HTTP/headless import and one
  automatic projection-v1 hydration. `CatalogImportService` owns one joinable,
  cancellable operation while `CatalogImportRepository` enumerates outside the
  database, validates complete ancestry, and publishes exact project/session
  rows plus the automatic marker in one transaction without deleting absence or
  overwriting newer projections. Codex catalog enumeration now crosses a
  plugin-owned worker-isolate repository. Shared progress DTOs/SSE are additive;
  current clients classify them as global events without adding the Stage 8 UI.
  On the directional macOS arm64 AOT fixture, first hydration of 10,000 roots
  published in 132.194 ms with 4.133 ms p99 scheduling lag. The 50,000-root
  guardrail used 75,317,248 bytes of additional RSS and 35,680,256 database
  bytes, with 6.429/21.022 ms p99/max scheduling lag. A catalog read while
  enumeration was blocked completed in 0.982 ms; a read queued on the same
  connection during the 50,000-row publication waited 660.598 ms, so Stage 6
  retains ownership of the <=50 ms concurrent-read gate. These local results are
  directional; Stage 9 still owns the fixed-host matrix. Schema v11 is unchanged.
- **Stage 4:** Newly created, listed, and event-discovered bindings now receive
  random Sesori ids while every backend session reference is translated at the
  plugin boundary. Known events update durable projections through one ordered
  dispatcher; same-plugin ancestry admits durable children and bounded pending
  state drains out-of-order roots, descendants, and dependent input in source
  order. Child, question, permission, activity, and YOLO paths resolve durable
  bindings, while backend deletion preserves catalog history. Child reads keep
  one temporary additive discovery path until automatic import and the Stage 6
  database-only cutover remove released rowless-history compatibility. Stage 4
  merged as PR #481 at `a0b031af`; schema v11 is unchanged.
- **Stage 3C:** Root session lists now publish complete observed projections
  transactionally before returning, preserve stable ids for existing backend
  bindings, and reject stale snapshots from overwriting bridge-owned title,
  archive, worktree, and prompt state. Every root-targeted plugin operation
  resolves the stored backend handle first; missing bindings return 404 and a
  non-running stored/requested plugin returns 503 before plugin or local cleanup
  side effects. Create, project open/rename, archive/unarchive, delete, status,
  and message responses write through or map back to stable ids while new
  production bindings remain identity-preserving. Schema v11 is unchanged.
  The implementation audit found that moving only root lookup into
  `QuestionRepository`, `PermissionRepository`, or `getChildSessions` would
  still expose untranslated child/event handles, so all child-facing routing
  moved to Stage 4 with durable child binding and exhaustive event translation.
- **Stage 3B:** The complete Drift Layer 1 implementation now lives under
  `bridge/app/lib/src/api/database/`; startup-only bridge diagnostics remain in
  `bridge/persistence/`. Schema v11, migration artifacts, queries, models, and
  runtime behavior are unchanged. No plan decision or risk-register delta was
  required.
- **Stage 3A:** `RequestRouter` now routes an injected handler list while
  `Orchestrator` owns room-specific composition and prompt-default SSE delivery.
  Archive/delete cleanup has one service owner, filesystem probes stay behind
  `FilesystemRepository`, services/handlers consume repository-owned session
  models, and the obsolete persistence service/repository-peer dependency are
  gone. The full change preserves current request and persistence behavior.
- **Stage 3 planning:** The first combined Stage 3 draft touched 97 tracked
  paths before its final composition work and was not reviewable. It was
  discarded from the delivery branch and preserved only as a local recovery
  stash. Stage 3 is split into behavior-neutral boundary correction (3A),
  mechanical relocation of the now-contained database API (3B), and binding/
  write-through behavior (3C). The audit also found that random root ids must
  activate with Stage 4 event and child translation rather than leaving an
  intermediate backend-id leak.
- **Stage 1B:** `PluginProject.directory` now declares the native plugin's live
  directory independently from its backend id. Shared session/create/composer
  contracts carry nullable plugin identity for older-peer compatibility. The
  single-plugin bridge stamps every outgoing session and rejects a mismatched
  requested plugin before plugin I/O; no plugin map or selection UI was added.
  Plugin metadata/import DTOs remain deferred to their first consumers in
  Stages 5 and 7.
- **Stage 1A:** The approved five-executable baseline scope included three paths
  that do not exist yet: event projection, import publication, and multi-plugin
  startup. Stage 1 was split into cohesive 1A benchmark and 1B contract PRs.
  Live-list and Codex AOT harnesses now record the honest current baseline; the
  remaining executables moved to their owning implementation stages.
- **Stage 0 (historical):** Code was re-audited at `f190b039`; catalog identity,
  schema, import, event, lifecycle, compatibility, rollout, performance, and PR
  boundaries were made concrete. `aristotle-plan-review` approved the execution
  plan. Implementation had not started at that point.
