# Parallel Plugins - Implementation Plan

> Status: **implementation in progress**.
> [`ARCHITECTURE.md`](ARCHITECTURE.md) owns the durable product direction. This
> document owns the implementation sequence, current pointer, concrete design, rollout, and
> verification. Keep both documents consistent when implementation findings
> change an assumption.

## Current Pointer

- **Last completed stage:** Stage 2 - catalog schema and indexed DAO queries
- **Next up:** Stage 3 - catalog write-through and stable session binding
- **Runtime default:** one selected plugin until Stage 7
- **Catalog projection version:** 1

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

The planning references were rechecked against `main` at `f190b039`.

- `SessionTable.sessionId` is both the client identity and backend handle and is
  globally keyed. `pluginId` is already non-null and is the correct routing
  datum.
- `ProjectsTable` already separates stable `projectId` from live `path` and has
  one shared hidden/name/base-branch row across plugins.
- `DeletedSessionsTable` already keys tombstones by `ownerIdentity`, `pluginId`,
  and backend-shaped `sessionId`.
- `ProjectRepository.getProjects` and
  `SessionRepository.getSessionsForProject` still enumerate the selected
  plugin. Derived enumeration can scan all Codex rollouts or issue ACP calls for
  every known directory.
- `GetSessionsHandler` persists the result of a list request. Child sessions are
  fetched live and are not durable.
- `BridgeRuntime.create`, `RequestRouter`, repositories, and the orchestrator
  receive one plugin. `PluginManager` stores a map but rejects a second running
  plugin and couples stopping one plugin to cancelling the whole bridge session.
- Plugin events contain backend session handles but no source-plugin identity.
  The orchestrator processes one stream through serial `asyncMap` stages.
- `GetSessionStatusesHandler` still calls `BridgePluginApi` directly.
- `PluginProject` does not expose a directory independently from its
  plugin-defined id, although directory is the cross-plugin project merge key.
- `CreateSessionRequest`, project-scoped composer requests, and `Session` do not
  carry the plugin choice needed by clients.
- Codex discovery uses synchronous recursive directory and file reads inside an
  async method, so a large import can block the bridge isolate.
- There is no repeatable percentile benchmark harness. Stage 1 adds it before
  production behavior changes and records the measured baseline in this file.

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
enforced on `(owner_identity, plugin_id, backend_session_id)`.

There is no backend-id fallback after cutover. Every session-addressed request
must resolve a stored binding. A missing row is a 404; an unavailable owning
plugin is a 503. This prevents ambiguous cross-plugin discovery and preserves
the rule that location is never inferred from an unknown durable id.

Projects keep the existing `project_id` and authoritative `path` model. This
work does not introduce project UUIDs. Project metadata remains shared across
plugins: hiding, renaming, and setting a base branch affects the one project
card for that directory.

Every durable project and session row carries `owner_identity = "local"` now.
No teams behavior or user picker is added.

### 3.2 Plugin Boundary

`PluginProject` gains a required `directory`. The bridge merges projects on a
normalized declared directory and no longer assumes a native plugin id is a
path. Plugin-defined project ids and backend session handles remain inside the
plugin/repository boundary.

Source plugin identity is attached by the bridge when it subscribes:

```text
(pluginId, BridgeSseEvent)
```

This is an app-internal record, not a new plugin event type and not a relay
field. Shared events continue to contain Sesori session ids only.

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

Replace the changed `PluginManager` role with `PluginLifecycleService`. It owns
registered/running/stopping state per plugin, idempotent start/stop, status
snapshots, and shutdown of every started instance. It does not construct plugin
hosts or peer services.

`BridgeRuntimeRunner` remains the process startup orchestrator:

1. Resolve and validate the ordered enabled descriptor set before I/O.
2. Authenticate.
3. Probe all descriptors concurrently before taking the startup mutex.
4. If none are available, preserve the current behavior that avoids replacing
   an already healthy resident bridge.
5. Acquire the cross-instance startup mutex once and enforce one live bridge
   once.
6. Construct one host and state directory per startable plugin.
7. Provision plugins sequentially in configured order. Start each plugin as
   soon as its provisioning phase settles; starts may overlap later
   provisioning and each other.
8. Await every start outcome. One failed/degraded plugin does not cancel a
   successful plugin.
9. Build one bridge runtime from the operational plugin map plus lifecycle
   status for unavailable plugins.

The mutex remains held through provisioning and all starts, preserving the
current descriptor contract. Narrowing runtime-install locks is a separate
foundation change only if measured cold-start contention proves it necessary.

`PluginLifecycleService` has no host-building or process dependencies. It is
constructed without collaborators; `BridgeRuntimeRunner` constructs each
`PluginHost`, captures `descriptor.start(host)` in a `PluginStarter`, and calls
`register({id, displayName, isDefault, starter, shutdownBudget})`. The service
stores the metadata it serves plus the already-wired starters, observes returned
plugin status streams, and owns running/stopping state. It never constructs
hosts, process runners, repositories, or peer services.

At runtime, a terminal plugin failure removes that plugin from operational
routing but leaves the bridge, relay, catalog, and other plugins running.
Shutdown first stops request/event consumption, then attempts every plugin
shutdown concurrently, then closes shared bridge resources.

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

Add to `ProjectsTable`:

- `owner_identity TEXT NOT NULL`, backfilled to `local`;
- `catalog_name TEXT NULL`, the first useful plugin-observed name when no
  bridge rename exists; and
- `projection_updated_at INTEGER NOT NULL`, backfilled from `updated_at`.

Rendered name precedence is `display_name ?? catalog_name ?? basename(path)`.
Import never overwrites `display_name`. Once `catalog_name` is non-null, another
plugin import does not replace it; an explicit Sesori rename writes
`display_name`. Add an indexed `(owner_identity, path)` lookup. Do not make it
unique until migration tests prove existing stores cannot contain duplicate
live paths.

### Sessions

Add to `SessionTable`:

- `owner_identity TEXT NOT NULL`;
- `backend_session_id TEXT NOT NULL`;
- `parent_session_id TEXT NULL` with a self-reference and cascade delete;
- `directory TEXT NOT NULL`;
- `catalog_title TEXT NULL`;
- `updated_at INTEGER NOT NULL`;
- nullable `summary_additions`, `summary_deletions`, and `summary_files`; and
- `projection_updated_at INTEGER NOT NULL`.

Keep existing bridge-owned worktree, branch, archive, prompt-default, unseen,
and `title` fields. Existing `title` values are preserved as the bridge-owned
override because the old schema cannot distinguish a rename from an observed
derived-plugin title. Rendered title precedence is `title ?? catalog_title`.

Backfill:

- `owner_identity = "local"`;
- `backend_session_id = session_id`;
- `parent_session_id = NULL` because existing persisted rows are roots;
- `directory = worktree_path ?? projects_table.path`;
- `updated_at = max(last_activity_at ?? created_at, created_at)`;
- summary columns and `catalog_title` to null; and
- `projection_updated_at = updated_at`.

Add a unique index on `(owner_identity, plugin_id, backend_session_id)` and
indexes supporting root lists, child lists, plugin binding lookup, ordering,
and archive filtering.

### Tombstones and Hydration

Rename the tombstone's backend-shaped `session_id` to `backend_session_id` and
keep the `(owner_identity, plugin_id, backend_session_id)` primary key. Sesori
deletion writes tombstones for every removed backend binding. A later import
cannot resurrect those bindings.

Add `CatalogHydrationsTable`:

| Column | Meaning |
|---|---|
| `owner_identity` | current durable owner |
| `plugin_id` | imported plugin |
| `projection_version` | catalog projection contract version |
| `completed_at` | successful atomic publication time |

Its primary key is all three identity/version columns. Only successful
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

`GET /project`, project lookup, root sessions, session lookup, and child lists
perform no plugin calls. Root lists filter `parent_session_id IS NULL`; child
lists filter by the parent Sesori id. Sorting and pagination happen in SQL, with
the Sesori id as the deterministic final tie-breaker.

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

Each plugin stream is normalized independently before streams merge, preserving
per-plugin order without allowing a blocked plugin A event to block plugin B.

```text
plugin.events
  -> PluginEventListener attaches pluginId
  -> SessionEventService
  -> SessionChildTracker records/drains unresolved ancestry
  -> SessionRepository / SessionMutationDispatcher perform exact writes
  -> SessionEventMapper rewrites every session reference to Sesori ids
  -> Orchestrator
  -> BridgeEventMapper -> phones
```

Rules:

- A known root event may update catalog title/time/summary and activity fields.
- An unknown root event is dropped and does not discover a project.
- A child is inserted only when its direct parent binding belongs to the same
  plugin. It inherits project/plugin attribution and stores its own reported
  directory.
- An unresolved child waits in a bounded in-memory map keyed by
  `(pluginId, backendParentId)`. Committing a parent drains resolvable
  descendants recursively. Overflow drops the oldest unresolved entry with a
  warning; there is no global enumeration or durable unresolved sentinel. The
  bound is an internal safety limit, not user configuration, and Stage 4 sizes
  it from the largest concurrent out-of-order event fixture. Import does not use
  this map: it validates ancestry inside its complete snapshot.
- Backend deletion does not delete catalog history and does not emit a client
  deletion that would contradict the next catalog read. A targeted operation
  later surfaces typed backend not-found.
- Events whose embedded session references cannot all be translated are
  dropped rather than leaking a backend handle.
- Plugin connected, heartbeat, and disposed events are plugin lifecycle input;
  they do not masquerade as whole-bridge lifecycle events.

`SessionEventService` replaces the narrower
`SessionEventEnrichmentService`. It is a thin Layer 3 orchestrator constructed
with already-built `SessionRepository`, `SessionMutationDispatcher`,
`SessionEventMapper`, `SessionChildTracker`, and `FailureReporter` instances. It
imports no DAO and delegates every projection/child write to
`SessionRepository` or `SessionMutationDispatcher`.

`SessionEventMapper` is a stateless, pure repository-layer mapper with a const
constructor. The service extracts backend references, asks `SessionRepository`
to resolve them in one batch, and gives the mapper the resulting
backend-to-Sesori id map. The mapper owns only the exhaustive event-shape
rewrite and performs no I/O.

`SessionChildTracker` is constructed with only its maximum pending-entry count.
It owns the in-memory pending map, insertion order, eviction invariant, and
recursive drain bookkeeping. It has no service, repository, DAO, or plugin
dependency and returns typed entries for `SessionEventService` to persist.

Each `PluginEventListener` is constructed with one already-started
`BridgePluginApi` and the shared `SessionEventService`. It owns exactly one raw
event subscription, attaches that plugin's id, delegates normalization, and
exposes its normalized output stream. It does not construct the service or any
of its collaborators. `BridgeRuntime` merges listener outputs into one
broadcast stream consumed by the orchestrator and `DebugServer`, so the debug
surface neither subscribes to one raw plugin nor repeats normalization. The
orchestrator remains the only component deciding which normalized events become
phone SSE events.

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
`CatalogImportRepository`. The composition root constructs that repository with
the enabled plugin API map and DAOs. The service receives no plugin API, DAO,
database, host, or configuration pass-through parameter. It owns one in-flight
operation per plugin, cancellation tokens, latest in-memory status, and a
broadcast progress stream.

### Enumeration and Publication

`CatalogImportRepository` receives the requested plugin API and DAOs.

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

Before import ships, Codex rollout enumeration moves behind `Isolate.run` (or
an equivalent worker-isolate boundary) inside the Codex plugin. Backend file
layout and parsing never enter bridge app code.

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
| Plugin metadata | Enabled order, display name, default marker, lifecycle state, and generic action hint |

`SessionRepository.getSessionStatuses` owns concurrent plugin queries and
binding translation through `SessionDao`; `GetSessionStatusesHandler` receives
only that repository and no `BridgePluginApi`. The repository knows the ordered
enabled ids and operational API map, so missing/failed sources can be reported
without a handler-layer plugin dependency.

`GET /plugin` is the client discovery endpoint. `GetPluginsHandler` depends on
`PluginLifecycleService`, whose state machine already owns enabled order,
default selection, display metadata, and lifecycle snapshots; the handler does
not inspect descriptors or plugin APIs. The endpoint lands in Stage 7; Stage 1
adds only its shared DTO contracts. It exposes no backend URLs, process details,
or assistant-specific fields. A failed plugin remains listed and disabled for
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

The source audit established that every list waits for plugin enumeration,
derived lists paginate after global discovery, Codex discovery can block the
bridge isolate, and event enrichment is globally serial. Stage 1A added the
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
| ☐ | 3 | Catalog write-through and stable session binding | Mutation/routing tests; existing IDs preserved |
| ☐ | 4 | Known-event projection and durable child hierarchy | Exhaustive event translation and ancestry tests |
| ☐ | 5 | Explicit import and automatic hydration | Atomicity, cancellation, progress, Codex isolate tests |
| ☐ | 6 | Database-only list cutover | Zero plugin calls; degraded-plugin browsing; budgets |
| ☐ | 7 | Multi-plugin routing, lifecycle, and event streams | Mixed-id routing, independent failure, startup/shutdown |
| ☐ | 8 | Client plugin and model/agent selection | Cubit, API/repository, mobile and desktop tests |
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

Acceptance: migration preserves every existing session id and metadata; owner,
backend handle, directory, and timestamps are backfilled; parent/project delete
cascades work; equal backend handles across plugins are legal; query-plan tests
use the intended indexes.

### Stage 3 - Catalog Write-Through and Stable Session Binding

- Teach `SessionRepository` to resolve Sesori ids to backend bindings and route
  every targeted operation through the selected plugin API.
- Start consuming request `pluginId` to select the owning plugin. Until this
  stage, the single-plugin bridge deliberately carries but does not validate or
  route on that field.
- Allocate independent Sesori ids for newly created sessions while preserving
  migrated ids.
- Write complete project/session projections on create/open/rename/archive/
  unarchive/delete and return the catalog mapping.
- Expand `SessionMutationDispatcher` and remove persistence decisions from
  handlers/services that bypass repositories.
- Keep current live list enumeration temporarily, but map observed backend
  sessions through bindings so client ids are already stable.

Acceptance: two plugin ids may own the same backend id without collision; every
targeted call receives the backend handle; unknown ids never discover; create is
durable before response; failed delete leaves catalog state intact.

### Stage 4 - Known Events and Durable Children

- Add the internal source-plugin envelope, `SessionEventMapper`,
  `SessionChildTracker`, `SessionEventService`, and per-plugin
  `PluginEventListener`.
- Persist known-session projection updates, proven child ancestry, recursive
  descendants, and cascade behavior.
- Translate every session-bearing event field from backend to Sesori identity.
- Normalize each plugin stream before merge and remove backend-global lifecycle
  events from bridge-global semantics.
- Change child reads to the catalog while root/project lists remain on the old
  path for one more stage.

Acceptance: unknown roots are ignored; cross-plugin parent links fail; out-of-
order descendants drain when ancestry arrives; backend deletion preserves
history; the pending-child bound retains the largest expected event burst;
blocked plugin A normalization does not block plugin B.

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

### Stage 7 - Multi-Plugin Routing, Lifecycle, and Events

- Make `--plugin` repeatable and honor ordered `enabledPlugins`.
- Introduce `PluginLifecycleService`, per-plugin hosts/state, independent status,
  one mutex acquisition, sequential provisioning, overlapping starts, and
  all-plugin shutdown.
- Change `BridgeRuntime.create`, repositories, router, and orchestrator to the
  operational plugin map plus compatibility default.
- Inject the shared normalized multi-plugin event stream and shared router into
  `DebugServer`; remove its direct single-plugin dependency.
- Add plugin-scoped providers/agents/commands, aggregated translated statuses/
  activity, and per-plugin health. Route `GetSessionStatusesHandler` only
  through `SessionRepository.getSessionStatuses`.
- Add `GetPluginsHandler` over `PluginLifecycleService` for enabled order,
  default marker, display metadata, and lifecycle state.
- Start one event listener/normalization stream per plugin.

Acceptance: one unavailable/failed plugin cannot stop another or catalog reads;
same backend id in two plugins routes correctly; plugin-global disposal is not
bridge-global; all selected configs validate before takeover; standalone and
supervised shutdown semantics remain intact.

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

### Stage 9 - Performance Gate and Cleanup

- Run the fixed-host matrix and large-history import/event soak tests.
- Remove dead live-list derivation, reconciliation, compatibility branches whose
  removal date has arrived, and temporary shadow instrumentation.
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
| Session id collisions across plugins | Separate Sesori/backend identity and unique binding index (2-3) |
| Migration loses routes or metadata | Preserve old ids and exhaustive migration fixtures (2) |
| Import overwrites a newer event/rename | `projection_updated_at` guard and bridge-owned override fields (3-5) |
| Partial or destructive import | enumerate before one transaction; never delete absence (5) |
| Codex scan blocks relay/event isolate | plugin-owned worker isolate and responsiveness test (5) |
| Long publication blocks reads | bounded set-based transaction and concurrent-read benchmark (5-6) |
| Unknown events discover external roots | binding lookup and proven-parent-only insertion (4) |
| Out-of-order children grow memory | bounded pending map, drain on binding, warning on eviction (4) |
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
- **Stage 0:** Current code was re-audited at `f190b039`; catalog identity,
  schema, import, event, lifecycle, compatibility, rollout, performance, and PR
  boundaries were made concrete. `aristotle-plan-review` approved the execution
  plan. Implementation has not started.
