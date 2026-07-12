# Parallel Plugin Support — Implementation Plan

> Status: **planned; implementation blocked on the PR #412 desktop cascade**.
> The code audit for this plan used the complete repository snapshot at PR #412
> head `a94fd7126f695c610925807e2500b1f290f7964c`, not only PR #412's diff.
> Product direction was reconciled with latest `main` before that snapshot was
> inspected. No implementation PR may start until the prerequisite cascade is
> merged, the implementation branch is rebased onto then-current `main`, every
> file/schema reference below is re-verified, and this plan has passed
> `aristotle-plan-review`.

## 1. Outcome

One bridge can run OpenCode, Codex, Cursor, and future plugins concurrently.
The bridge remains one relay endpoint and one E2E trust boundary, while every
plugin has an independent availability, provisioning, start, health, failure,
and stop lifecycle.

The user sees:

- one project card per directory;
- one chronological session list containing sessions from every plugin;
- a plugin badge and All/per-plugin filter on mixed session lists;
- a plugin picker when creating a session, including stopped Beta plugins;
- on-demand start/provisioning when a stopped plugin is selected;
- catalog browsing when a plugin is stopped, unavailable, or failed;
- read-only session metadata plus an explicit Start action when its plugin is
  not running;
- a plugin/settings surface for Start, Stop, Retry, diagnostics, and import;
- a combined diagnostics snapshot covering bridge dependencies, every compiled
  plugin, install/availability, runtime status, authentication checks,
  capabilities, remediation guidance, and import state; and
- explicit per-plugin import of work created directly in a backend.

OpenCode remains the only plugin started by default. Codex and Cursor are shown
as disabled Beta options and start on demand. They remain on demand after use;
selecting one does not add it to the startup list.

## 2. Durable Direction

### 2.1 Catalog ownership

The bridge owns the durable catalog of projects, sessions, and their
relationships. Plugins are execution harnesses and capability providers.

Normal project and session list reads use only Drift. They do not enumerate or
probe plugins and never fall back to plugin enumeration after cutover. A plugin
outage can disable live controls for its sessions, but cannot remove those
sessions from the catalog.

Sesori owns:

- projects and sessions known to Sesori;
- project-to-session and parent-to-child relationships;
- stable public session identity;
- plugin binding and private backend handles;
- project/session names, archive state, deletion intent, worktree attribution,
  prompt defaults, unseen state, and activity timestamps;
- catalog provenance and last-known generic list metadata; and
- durable owner identity, even while it always means the current account.

Plugins own:

- execution and backend runtime state;
- transport/process lifecycle;
- backend capabilities, models, agents, variants, and commands;
- actual current operability of a backend session; and
- transcripts/messages.

### 2.2 Discovery is import, not sync

Unknown external root sessions are not discovered from live events. They enter
the catalog through import:

- one non-blocking automatic hydration per owner, plugin, and catalog
  projection version;
- explicit client-triggered imports after that;
- no periodic/background enumeration;
- no deletion inferred from absence in a later import; and
- no plugin I/O from normal list reads.

Known sessions continue to receive generic metadata/activity updates from live
events. A child may be admitted only when same-plugin ancestry reaches a known
catalog session. It inherits project, owner, plugin, and
`created_with_sesori` from that known lineage.

### 2.3 One session-control surface

All session operations continue through the bridge request API used by people
and future automation. There is no plugin-specific client route and no
automation backdoor. Backend-specific behavior remains behind
`BridgePluginApi`.

## 3. Settled Product Decisions

| Topic | Decision |
|---|---|
| Project identity | One shared project per normalized directory. Hide, name, and base-branch state apply across plugins. |
| Project names | Seed a new project once from the first imported name, otherwise use `p.basename` from `package:path` for a cross-platform folder basename. Later imports never rename it. Sesori rename is authoritative. |
| Session identity | Introduce a Sesori-owned public session id and keep `(plugin_id, backend_session_id)` private to the bridge. Existing public ids are preserved during migration; new sessions use bridge-generated ids. |
| Owner | Store the authenticated JWT `userId` on durable projects, sessions, tombstones, and import runs. Existing rows are backfilled to the account performing migration. |
| Provenance | Add required `created_with_sesori`. Existing rows migrate to `true`; directly created roots are `true`; hydrated roots are `false`; descendants inherit the root's value. It is internal for this release, with a future Sesori-created/imported filter documented. |
| Plugin source on events | Attach `pluginId` in an internal bridge envelope at each plugin-stream subscription. Do not add it to every `BridgeSseEvent` variant. |
| Session wire attribution | Add optional `pluginId` to shared `Session` payloads. Projects remain plugin-agnostic. |
| New-client create routing | New clients always send `pluginId`. The last plugin used by a successful new-session creation becomes `defaultPluginId` for subsequent new-client composers. |
| Legacy create routing | Missing `pluginId` means legacy behavior and resolves to OpenCode only. It never silently selects another plugin. |
| Legacy catalog requests | Project-only agent/provider/command requests without plugin/session context resolve to OpenCode. Legacy clients may browse and operate opaque sessions, but non-OpenCode picker behavior is unsupported until the app updates. |
| Startup defaults | OpenCode starts by default. Codex/Cursor are visible, stopped, and labelled Beta. `enabledPlugins` remains the headless startup list; selecting an on-demand plugin does not mutate it. |
| Runtime controls | Client Start/Stop are immediate and process-local. There is no separate client “Start with bridge” control. |
| Stopping active work | Normal Stop returns a conflict with active-session count. The client confirms and retries with `force: true` to terminate active work. |
| First Beta use | Start/provision and create the requested session immediately; queue first hydration in the background. Hydration never blocks creation. |
| Plugin failure | Probe, provisioning, start, and runtime failures are isolated per plugin. The bridge stays online even if every plugin fails. |
| Startup concurrency | Probe enabled plugins in parallel, provision sequentially, then start independently/in parallel under the one bridge startup ownership window. |
| Open stopped session | Show catalog metadata read-only and an explicit Start action. Do not auto-start merely from navigation. |
| Rename | Persist the Sesori name first, then best-effort propagate to a capable live backend. Backend failure does not roll back the catalog. |
| Delete while offline | Delete locally, retain a tombstone, hide immediately, prevent import resurrection, and retry backend deletion when the plugin next starts. |
| Backend reports not found | Retain the session and mark its backend copy unavailable. Disable live controls; explicit delete or later successful observation can resolve it. |
| Import trigger | Client only (phone first; desktop inherits through shared UI extraction). No new import CLI command. |
| Import scope | Global where supported. Directory-scoped plugins import known catalog folders and accept additional folders selected through the existing filesystem browser. |
| Import atomicity | Collect/validate first, then apply one short non-destructive transaction. A failure/cancellation before commit leaves the previous catalog unchanged. |
| Import lifetime | Bridge-owned job continues across client disconnects until completion or explicit cooperative cancellation. |
| Import concurrency | One import job at a time globally; later requests queue. Duplicate requests for the same plugin return the existing job. |
| Automatic hydration failure | Record one failed automatic attempt and require explicit client retry. Do not retry on every bridge launch. |
| Diagnostics | One combined endpoint. Default reads a cheap cached snapshot; explicit `forceRefresh` runs bounded dependency/plugin/auth probes and refreshes the cache. |
| Diagnostic actions | Report typed state and remediation guidance only. Existing managed provisioning may run during Start, but diagnostics never execute arbitrary install/login commands. |
| Mixed-session UI | Plugin badge plus All/per-plugin filter. No provenance badge/filter in this release. |
| Client sequencing | Ship mobile presentation first. Desktop Phase 4 later moves the enhanced screens into `module_app_ui`, so desktop inherits them without a separate implementation. |
| Performance enforcement | Timing benchmarks are manual only. Automated tests still enforce correctness invariants, especially zero plugin calls on list reads. |
| Migration backup | Rely on required Drift structural/data-integrity tests; do not add an application-managed database backup. |
| `--plugin` | Deprecate now, retain its current single-plugin override temporarily, emit the existing `Console.warning` style guidance, and remove in a later release. Multi-start is configured through `enabledPlugins`. |

## 4. Scope and Non-Goals

### In scope

- bridge-owned generic project/session catalog;
- stable Sesori session identity and private backend handles;
- owner/provenance/hierarchy/deletion state;
- one-time hydration and explicit imports;
- static declared plugin capabilities and stability labels;
- combined diagnostics and plugin runtime state;
- independent static-start and on-demand plugin lifecycle;
- dynamic event subscription and per-session command routing;
- additive shared protocol changes;
- mobile plugin selection, diagnostics/control/import, mixed-list badges/filter,
  and stopped-plugin read-only states; and
- additive desktop control-channel plugin status needed before shared UI lands.

### Explicitly out of scope

- cross-plugin live session migration;
- transcript/message persistence;
- continuous mirroring of direct backend usage;
- plugin package installation or third-party dynamic loading;
- multiple simultaneous instances/configurations of the same plugin id;
- arbitrary remote execution of install/login commands;
- teams/multi-user product behavior beyond storing/scoping owner id;
- offline/local-first client caching;
- cost/usage metering;
- a permission-policy framework;
- a provenance filter in this release; and
- automatic idle-stop/wake policy implementation (documented in §15).

Existing persistent per-session agent/model/variant selection is not a new
feature in this workstream. The session-detail composer already sends the
selection with each prompt, the bridge persists it, and SSE updates other
clients. Multi-plugin work only scopes those catalogs and operations to the
session's owning plugin.

## 5. Baseline Audit at PR #412 Head

The implementation baseline is schema v8 and has these important assumptions:

- `BridgeRuntime.create`, `Orchestrator`, `OrchestratorSession`, `DebugServer`,
  `RequestRouter`, and eight repositories hold one `BridgePluginApi`.
- `PluginManager` is id-keyed but explicitly rejects a second running id and
  cancels the whole orchestrator before any plugin stop.
- `PluginSelector` rejects more than one `enabledPlugins` entry and the two-pass
  parser registers options only for the selected plugin.
- `bridge_runtime_runner.dart` treats unavailable/start/terminal plugin failure
  as process-fatal.
- `ControlStatus` and provisioning progress represent one plugin.
- `ProjectRepository.getProjects` and
  `SessionRepository.getSessionsForProject` enumerate the live plugin.
- `sessions_table.session_id` is both the public id and backend handle; it is a
  global primary key even though backend id namespaces can collide.
- `sessions_table.plugin_id` is already required and every reconcile query is
  correctly plugin-scoped.
- `projects_table` is already shared across plugins and separates `project_id`
  from `path`.
- generic list fields (session title/directory/update/summary/parent and stable
  project/session catalog timestamps) are not fully persisted.
- `SessionPersistenceService` and `SessionUnseenRepository` stamp one
  constructor-injected plugin id.
- the orchestrator and debug server subscribe to one plugin event stream.
- `/global/health` probes the single backend and returns 503 when it is down.
- `BridgeDiagnostics` only logs filesystem/Git checks; `GhCliApi` separately
  knows gh installation/auth; `BridgePlugin.describe()` only describes a live
  instance.
- Codex starts a resident `codex app-server` process and WebSocket; Cursor
  starts a resident `agent acp` stdio process. Neither is request-per-process.
- mobile agent/provider/command requests are project-scoped, which is ambiguous
  when one project has sessions owned by several plugins.

The prerequisite cascade and current `main` may advance this shape (including
the Drift schema) before implementation. PR 1 below starts with a mandatory
re-audit and adjusts migration version numbers without changing these logical
decisions.

## 6. Target Data Model

Evolve the existing tables; do not introduce duplicate `catalog_projects` and
`catalog_sessions` tables.

### 6.1 Projects

`projects_table` remains one row per owner + normalized directory. Add:

- `owner_id` (required);
- a stable bridge-owned name using the existing `display_name` column (seed
  only when null);
- bridge-owned `created_at` / `updated_at` projection timestamps as needed by
  the shared `Project` list model; and
- a unique owner/path constraint.

Use `(owner_id, project_id)` as the durable key during the compatibility era;
`project_id` may remain the existing opaque/path value. Session and PR foreign
keys include owner id. Do not introduce a project-id migration without a
concrete need.

### 6.2 Sessions

`sessions_table` stores:

- `owner_id` (required);
- `session_id` (Sesori public id);
- `plugin_id` (required stable plugin id);
- `backend_session_id` (private plugin handle);
- `project_id` and nullable `parent_session_id`;
- `created_with_sesori` (required);
- `directory`, backend-reported title, nullable Sesori title override;
- generic created/updated/archived timestamps and summary counts;
- existing worktree/base-branch/prompt-default/unseen fields;
- nullable `backend_missing_at`; and
- last-observed/import timestamps needed for diagnostics, never for destructive
  absence reconciliation.

Constraints/indexes:

- owner + public session id is unique;
- owner + plugin id + backend session id is unique;
- owner + project id indexes root list reads and sort/pagination;
- parent is a self-FK in the same owner and cascades descendants; and
- root list queries require `parent_session_id IS NULL`.

Migration behavior:

- preserve every existing `session_id` as its public Sesori id;
- copy it into `backend_session_id`;
- backfill `plugin_id` from the existing required value;
- backfill `owner_id` from the authenticated JWT user id;
- backfill `created_with_sesori = true`;
- derive directory from `worktree_path ?? projects.path`;
- derive updated time from last activity, then created time;
- leave parent/title/summary fields safely nullable/defaulted until hydration;
  and
- generate cryptographically random public ids for newly admitted sessions.

### 6.3 Tombstones

Persist session deletion intent keyed by owner + plugin + backend handle, with
public session id and deletion time. Import rejects matching rows. Plugin start
triggers a best-effort retry; typed backend not-found completes the deletion.
Other failures remain visible and retryable.

### 6.4 Import runs

Persist import jobs with owner, job id, plugin id, projection version, trigger
(`automatic`/`explicit`), requested directories, phase/status, counts,
timestamps, and user-facing failure summary. On startup, mark an interrupted
running job failed; never resume it silently.

The automatic-attempt key is owner + plugin + projection version. A failed or
cancelled automatic job consumes that one automatic attempt; future retries are
explicit.

## 7. Target Shared Contracts

All additions are backward-compatible nullable/defaulted Freezed fields. New
clients always send explicit context; missing context follows the OpenCode
legacy rule.

Add generic shared models for:

- `PluginInfo`: id, display name, stability (`stable`/`beta`), capabilities,
  running/lifecycle state, startup-enabled flag, default-for-new-sessions flag,
  availability/auth diagnostic summaries, active-session count, and current
  operation/import state;
- `BridgeDiagnosticsResponse`: bridge version/platform/filesystem state, Git
  and gh checks, plugin list, cache timestamp, and whether a force refresh is
  running;
- typed diagnostic check state/severity/remediation (message, optional docs URL,
  optional safe verification command; never an executable action);
- plugin control requests (`start`, normal/forced `stop`, `retry`);
- import start/cancel/status and progress;
- optional `pluginId` on `Session` and `CreateSessionRequest`;
- plugin/session context on agent/provider/command requests; and
- additive per-plugin control-channel status/provision progress while retaining
  the legacy aggregate fields for older desktop helpers/GUI builds.

Static capabilities live on `BridgePluginDescriptor` and are mapped to shared
wire models by the bridge. Use generic capabilities only (session creation,
agents, providers/models, variants, commands, questions, permissions, child
sessions, import scope). No OpenCode/Codex/Cursor enum or conditional crosses
the plugin boundary.

Extend the plugin diagnostic contract with bounded, read-only typed checks that
can run for stopped plugins. The bridge provides process/environment/config;
each descriptor owns backend-specific install/version/login probes and
remediation text. Live `BridgePlugin.status`/`describe()` remain the source for
running state and endpoint/version details.

## 8. Target Bridge Architecture

### 8.1 Layer 1: plugin runtime and diagnostics APIs

Introduce `PluginRuntimeApi` in `bridge/app/lib/src/bridge/api/`. It is the dumb
execution boundary over registered `BridgePluginDescriptor`/`BridgePlugin`
objects: execute one probe, provision, start, or shutdown operation; retain the
resulting active instance map; expose synchronous lookup and a typed active-set
change stream. It makes no policy decision about which plugins should start,
operation ordering, retries, active-work conflicts, failure severity, or
process exit.

Layer-2 domain repositories may look up a `BridgePluginApi` from this Layer-1
source at call time, exactly as they use other APIs. Runtime changes therefore
do not reconstruct the orchestrator.

Move host checks behind dumb Layer-1 APIs:

- filesystem access;
- Git availability/version;
- gh availability/authentication; and
- descriptor diagnostic execution inputs.

Do not grow legacy `BridgeDiagnostics` into a business-logic container.

### 8.2 Layer 2: repositories

Repositories remain domain-specific and do not depend on peer repositories:

- `PluginRuntimeRepository` is the mandatory Layer-2 boundary over
  `PluginRuntimeApi`. It maps raw probe/provision/start/stop results and exposes
  active-instance/status snapshots to Layer-3 lifecycle policy. It does not
  decide ordering, retry, or stop eligibility.
- `PluginEventTracker` independently depends on `PluginRuntimeApi`, owns the
  subscriptions for the current active set, and emits internal
  `PluginEventEnvelope(pluginId, event)` objects. It is Layer 2 because it
  maintains reactive state derived from Layer-1 runtime/event sources. It does
  not depend on `PluginRuntimeRepository` or any peer repository.
- `ProjectRepository` maps project rows to shared `Project` and performs only
  database/filesystem list reads. Normal methods never access a plugin.
- `SessionRepository` maps session rows, resolves public id to private plugin +
  backend handle, and dispatches session operations through Layer-1
  `PluginRuntimeApi`.
- `QuestionRepository`, `PermissionRepository`, and `WorktreeRepository` each
  resolve the owning row through `SessionDao` and then the active API. They do
  not call `SessionRepository`.
- `AgentRepository`, `ProviderRepository`, and command lookup accept explicit
  plugin/session context; legacy project-only calls resolve OpenCode.
- `HealthRepository` becomes bridge-only and performs no plugin I/O.
- `DiagnosticsRepository` combines Layer-1 host/plugin facts and maps them to
  the shared diagnostics model; it does not own cache/refresh policy.
- `CatalogImportRepository` is the single Layer-2 boundary for plugin
  enumeration plus atomic catalog upsert. It switches over the existing sealed
  native/derived project capability, filters tombstones, preserves Sesori
  overrides, and never deletes because a row was absent.

All plugin DTO -> catalog/shared mappings stay in `repositories/mappers/`.

### 8.3 Layer 3: services

- Replace the forbidden `PluginManager` name and single-plugin behavior with a
  cohesive `PluginLifecycleService`. It depends on
  `PluginRuntimeRepository` (never `PluginRuntimeApi`), owns descriptor/config
  registrations, per-id start/stop in-flight state, active-work stop checks,
  failure isolation, status snapshots, and idempotent Retry. Every trigger uses
  this one service: `startPlugin`, `retryPlugin`, `stopPlugin`,
  `startAllEnabledPlugins`, and `stopAllActivePlugins` all funnel through the
  same private per-plugin probe/provision/start/stop stages. The all-plugin
  methods own parallel probe, sequential provision, parallel start, and bounded
  shutdown ordering. `BridgeRuntime` invokes these methods but never implements
  lifecycle ordering itself.
- `DiagnosticsService` owns cached snapshots, a shared in-flight force refresh,
  refresh timestamps, and lifecycle-driven cheap cache updates. Normal reads
  return immediately.
- `CatalogImportService` owns the one-at-a-time job queue, durable run state,
  progress stream, cancellation, automatic-attempt policy, and calls
  `CatalogImportRepository` for collection/commit.
- `SessionCreationService` accepts explicit plugin id, requires it to be
  running, creates through `SessionRepository`, writes the catalog immediately,
  and updates `defaultPluginId` only after success. A legacy null resolves
  OpenCode and does not alter the new default.
- `SessionCatalogService` owns event admission/update rules, same-plugin child
  ancestry, bounded unresolved-child state, tombstone checks, backend-missing
  state, and generic projection updates. It uses repositories, never plugin
  APIs directly.
- archive/delete/rename/prompt services keep existing ownership but resolve
  through the updated repositories. Rename/delete use the settled offline
  semantics.

The unresolved-child buffer is bounded by count and age, pruned when related
events arrive (no polling timer). Parent arrival and a targeted same-plugin
session update feed the same admission path. An unresolved child is never
invented as a root and never triggers global discovery.

### 8.4 Layer 4+: listeners, handlers, composition

`Orchestrator` consumes the Layer-2 `PluginEventTracker` stream; it never
subscribes to `PluginRuntimeApi` or a plugin API directly. Removing/stopping a
plugin causes the tracker to cancel only that plugin subscription. Orchestrator
passes events through `SessionCatalogService`/enrichment, maps public Sesori
ids, and retains its existing SSE/push decisions.

Add explicit handlers for:

- combined diagnostics (`forceRefresh` false by default);
- plugin Start/Stop/Retry;
- import start/cancel/status; and
- context-aware agent/provider/command requests.

Handlers depend on repositories/services only. Existing session handlers remain
plugin-agnostic and pass public Sesori session ids.

`BridgeRuntime` remains the sole layer composer. It constructs the
`PluginRuntimeApi`, `PluginRuntimeRepository`, `PluginEventTracker`, and
`PluginLifecycleService` as peers, then injects them into consumers. No service
constructs a repository/tracker internally, and no peer shares pass-through
constructor dependencies. It constructs one shared set of domain
repositories/services and one orchestrator, not per-plugin copies of every
repository/service.

`DebugServer` receives and reuses the same router/listener/repository instances;
it never builds a parallel graph.

### 8.5 Startup and shutdown flow

At launch:

1. Authenticate and obtain owner id.
2. Parse namespaced options for every compiled descriptor.
3. Load `enabledPlugins`; null/empty retains the OpenCode default.
4. Resolve predecessor/single-live-bridge ownership once.
5. Call `PluginLifecycleService.startAllEnabledPlugins()`; inside that service,
   probe startup plugins in parallel, record unavailable plugins without
   aborting, provision available plugins sequentially, and start them
   independently/in parallel.
6. Register each successful API/status stream; keep each failure in diagnostics.
7. Start relay/orchestrator even when zero plugins are active.
8. Queue due one-time hydrations without blocking relay or session creation.

At shutdown, cancel the orchestrator once, then call
`PluginLifecycleService.stopAllActivePlugins()` for per-plugin budgets under a
bounded total shutdown window. Dynamic Stop calls the same per-plugin stage and
never cancels the orchestrator.

`PluginFailed` removes only that API/event subscription and updates status. It
does not set the process failure latch. Internal managed-runtime restart policy
remains plugin-owned; terminal failure waits for explicit Retry.

## 9. Request and Event Data Flows

### 9.1 Project/session list

```text
client -> handler -> ProjectRepository/SessionRepository -> Drift -> shared DTO
```

No descriptor/runtime API/plugin access occurs. Pagination/filter/sort happen
in SQL over root rows. Session list sort is global across plugins.

### 9.2 New session with stopped Beta plugin

```text
new-session screen
  -> diagnostics(forceRefresh=false)
  -> user selects Codex
  -> plugin Start handler -> PluginLifecycleService
  -> progress/status stream -> client
  -> plugin-scoped agent/provider/command requests
  -> create(pluginId=codex)
  -> SessionCreationService -> SessionRepository -> Codex API
  -> immediate catalog insert(created_with_sesori=true)
  -> update defaultPluginId=codex
  -> response/SSE with Sesori session id + pluginId
  -> queue first Codex hydration if due
```

If Start/provision fails, no session is created and the diagnostics snapshot
contains remediation. Other plugins and catalog reads continue.

### 9.3 Existing session operation

```text
public session id
  -> SessionRepository loads owner-scoped row
  -> plugin_id + backend_session_id
  -> PluginRuntimeApi lookup
  -> prime directory when required
  -> plugin API operation(backend_session_id)
```

Missing/stopped API returns a typed plugin-unavailable result. Typed backend
not-found marks `backend_missing_at`; transport/auth failures do not.

### 9.4 Plugin event

```text
plugin events stream
  -> PluginEventTracker stamps source plugin id
  -> SessionCatalogService resolves (owner, plugin, backend handle)
  -> ignore unknown root OR admit proven child OR update known row
  -> map backend handles to Sesori public ids
  -> BridgeEventMapper
  -> push bookkeeping + SSEManager
```

### 9.5 Import

```text
client start import
  -> CatalogImportService queues durable job
  -> CatalogImportRepository enumerates one plugin
  -> progress stream (scan/validate/commit)
  -> validate owner/project/ancestry/tombstone rules
  -> one short Drift transaction upserts generic projection
  -> completed snapshot + project/session refresh event
```

The previous catalog remains readable throughout. Directory-scoped imports use
catalog-known paths plus client-selected paths. Cancel is cooperative between
enumeration phases; a non-cancellable backend call may finish, but commit is
skipped after cancellation.

## 10. Client Architecture and UX

### 10.1 `module_core`

Add the standard API -> Repository -> Service/Cubit flow:

- Layer 1 diagnostics/plugin-control/import methods over
  `RelayHttpApiClient`;
- Layer 2 repository mapping and context-aware session catalog calls;
- Layer 3 service only where Start-then-load and import orchestration requires
  decisions; and
- Layer 4 pure-Dart cubits for plugin settings/import progress and plugin-aware
  new-session/session-list state.

No cubit calls an API or another cubit. Lifecycle/import updates come from SSE
streams; there is no polling. On reconnect, one diagnostics/import-status fetch
rebuilds snapshots.

### 10.2 Mobile presentation

- New session: plugin selector above plugin-scoped agent/model controls. Show
  all compiled plugins; OpenCode is Stable, Codex/Cursor Beta. Selecting a
  stopped plugin starts it and shows provisioning/start progress.
- Session list: badge each row and provide All/per-plugin filtering. The default
  is All; filter state is presentation-only.
- Session detail: use session id for agent/provider/command context. When the
  plugin is stopped/unavailable/backend-missing, show persisted metadata and a
  Start/Retry/diagnostics action instead of transcript controls.
- Settings: combined diagnostics, force refresh, Start/Stop/Retry, active-work
  force confirmation, import, import cancellation/progress, and directory
  selection for directory-scoped plugins.

### 10.3 Desktop

Before desktop accessory UI exists, extend the control protocol additively so
the shell can represent aggregate + per-plugin status/provisioning. Do not add
plugin business logic to `module_desktop_core` or the desktop shell.

When Desktop Phase 4 moves project/session/new-session/settings UI into
`module_app_ui`, move the already-shipped mobile widgets and use the same
`module_core` cubits. Product-specific bridge-offline actions remain injected
callbacks per the desktop plan.

## 11. Implementation PR Cascade

Size target follows the desktop plan: S <=150 source LOC, M 150–350 source LOC;
generated files and focused tests may make the displayed diff larger. If a PR
cannot stay conceptually reviewable, split it. Never merge adjacent rows merely
to reduce PR count. Every implementation PR runs `aristotle-impl-review` before
opening.

### Foundation A — contracts, identity, and catalog

#### PR A1 — Re-audit + shared/plugin metadata contracts (M)

- Rebase after the PR #412 cascade and re-verify schema/current files.
- Add shared plugin/diagnostic/control/import DTOs and optional
  `Session.pluginId` / `CreateSessionRequest.pluginId`.
- Add static descriptor capabilities/stability and typed diagnostic-check
  contract with default empty checks.
- Pin OpenCode Stable; Codex/Cursor Beta and capability declarations in tests.
- No runtime behavior change.

Verification: shared + every plugin package analyze/test; old JSON fixtures
without new fields still decode.

#### PR A2 — Catalog/identity Drift migration (M)

- Export the then-current schema before edits.
- Add owner, backend handle, hierarchy, generic projection,
  `created_with_sesori`, backend-missing, indexes/FKs, tombstones, and import-run
  storage to existing catalog tables.
- Preserve existing public ids and backfill all existing rows as
  `created_with_sesori=true` owned by the authenticated migration account.
- Add structural and populated data-integrity migration tests, including
  duplicate backend ids across two plugins/owners and parent cascade.
- Do not add a database backup.

Verification: mandatory Drift workflow, codegen, migration tests from every
retained schema, bridge analyze/test.

#### PR A3 — Catalog DAOs and mappers (M)

- Add owner-scoped indexed list/detail queries, public/backend identity lookup,
  root/child queries, projection upserts, tombstones, and import-run DAOs.
- Add repository mappers for project/session catalog rows.
- Keep existing live list path active; expose catalog-read methods only to
  tests.

Verification: DAO/mapping tests for mixed plugins, pagination/sort, overrides,
  owner isolation, provenance, and tombstones.

#### PR A4 — Public Sesori id routing on the existing single plugin (M)

- Rework session operations to resolve public id -> backend handle before every
  plugin call.
- Return public ids from REST/SSE/push paths.
- Keep legacy migrated ids unchanged.
- Add typed unavailable/not-found mapping without introducing multiple active
  plugins yet.

Verification: all session handlers (message, command, abort, rename, archive,
delete, question, permission, child, diff/worktree) use public ids in tests.

#### PR A5 — Single-plugin runtime/repository/event boundaries (M)

- Add Layer-1 `PluginRuntimeApi`, Layer-2 `PluginRuntimeRepository`, and
  Layer-2 `PluginEventTracker`, wired to the existing one running plugin.
- Move raw descriptor/plugin execution behind `PluginRuntimeApi`; keep all
  startup policy behavior unchanged.
- Make Orchestrator and DebugServer consume the tracker stream rather than
  subscribing to the plugin API directly.
- Construct API, repository, and tracker as peers in `BridgeRuntime`.

Verification: byte-identical single-plugin startup/events; no Layer-3/4 direct
dependency on `PluginRuntimeApi`; tracker teardown/re-subscription tests.

#### PR A6 — Event envelope + catalog admission/hierarchy (M)

- Add internal `PluginEventEnvelope` output to `PluginEventTracker`.
- Add event-driven known-session projection updates, unknown-root rejection,
  same-plugin child admission, inherited provenance, bounded unresolved-child
  state, and public-id mapping.
- Update unseen/push/project-summary paths without changing client behavior.

Verification: known/unknown root, in-order/out-of-order/nested child,
cross-plugin ancestry rejection, event replay, and teardown tests.

#### PR A7 — Catalog-authoritative mutation semantics (M)

- Write project/session names and create/archive/delete intent to the catalog
  before best-effort backend propagation.
- Add backend title vs Sesori title override behavior.
- Add offline delete tombstones/retry metadata and backend-missing state.
- Ensure successful direct creation writes `created_with_sesori=true` before
  response; descendants inherit it.

Verification: plugin failure never rolls back local rename/archive/delete;
tombstoned rows cannot be reinserted by projection upsert.

#### PR A8 — Import repository/service and explicit job model (M)

- Add one-at-a-time durable import queue, progress/cancel/status streams, atomic
  non-destructive commit, known-folder + selected-folder inputs, and automatic
  attempt tracking.
- Keep list reads on the legacy live path through the hydration checkpoint.
- Run Codex heavy enumeration outside the bridge request/event isolate (the
  plugin owns its backend-specific implementation).

Verification: cancellation/disconnect, partial scan failure, plugin outage,
duplicate request, tombstone, override preservation, child ancestry, and
read-during-import tests.

#### PR A9 — One-time automatic hydration, legacy reads retained (S-M)

- Queue non-blocking automatic hydration for OpenCode at migration and for an
  on-demand plugin after its first successful start.
- Persist completion/failure/attempt status and surface it through test/debug
  snapshots.
- Keep the legacy live list path active. Do not cut over or remove fallback in
  this PR.

Verification: populated legacy databases complete hydration; delayed/failed
hydration leaves current list behavior and stored rows unchanged.

### MT-A1 — User checkpoint: hydration parity before cutover

Pause on a real copy of current OpenCode data while list reads still use the
legacy path:

1. Run automatic hydration and compare catalog-read test/debug output with the
   live project/session lists.
2. Verify names, worktrees, archive/unseen/defaults/PR links and pagination.
3. Fail/cancel hydration and verify the previous catalog remains intact.
4. Record manual list/import responsiveness baselines.

Do not open A10 until the user marks MT-A1 passed.

#### PR A10 — DB-only read cutover (S-M)

- Switch normal project/session/root-child list reads to catalog queries only.
- Remove read-triggered persistence/reconciliation and all plugin fallback.
- Keep explicit import as the only unknown-root discovery path.

Verification: tests use throwing plugin fakes and prove catalog lists still
succeed with zero plugin calls.

### MT-A — User checkpoint: single-plugin catalog cutover

Pause before runtime pluralization. The user manually verifies on a real copy of
their current OpenCode data:

1. Existing projects/sessions survive migration with names, worktrees, archive,
   unseen state, prompt defaults, PR links, and routes intact.
2. Create, prompt, model switch, rename, archive/unarchive, delete, restart, and
   notifications behave as before.
3. Direct OpenCode work does not appear until Import; known session events do.
4. Failed/cancelled import preserves the previous list.
5. Manual p50/p95/p99 list measurements and bridge responsiveness during a large
   import are recorded in this plan's Findings log.

Do not start B1 until the user marks MT-A passed.

### Foundation B — independent runtime and routing

#### PR B1 — Runtime API repository rewiring, still one plugin (M)

- Rewire session/question/permission/provider/agent/worktree repositories to
  resolve at call time through Layer-1 `PluginRuntimeApi` with explicit
  owner/plugin/session context. They do not depend on
  `PluginRuntimeRepository` or another peer repository.
- Replace constructor-injected plugin id in persistence/unseen paths.
- Keep runtime starting exactly one plugin.

Verification: one-plugin behavior unchanged; stopped/missing API returns typed
unavailable; legacy context resolves OpenCode.

#### PR B2 — Lifecycle service refactor and `PluginManager` rename (M)

- Introduce `PluginLifecycleService` with idempotent per-id start/stop/retry,
  active-work conflict, force stop, independent failure, full status snapshots,
  and all-plugin start/stop methods. It depends on
  `PluginRuntimeRepository`, never `PluginRuntimeApi`.
- Remove whole-orchestrator cancellation from dynamic plugin stop.
- Preserve existing one-plugin startup path while tests cover two fake plugins.

Verification: concurrent starts, failed probe/provision/start, stop-during-start,
duplicate callers, forced active stop, terminal runtime failure, bounded
shutdown.

#### PR B3 — All-descriptor CLI/config composition + `--plugin` deprecation (S-M)

- Register namespaced options for every compiled descriptor so an on-demand
  plugin has parsed config.
- Allow multi-entry `enabledPlugins`; validate unknown/duplicate ids together.
- Keep null/empty -> OpenCode startup.
- Keep `--plugin` as a temporary single-plugin startup override, detect its use,
  and feed an actionable warning through the existing deprecation warning list
  and `Console.warning`.
- Remove the selected-descriptor two-pass parser dependency where possible.

Verification: help/version/logout stay side-effect free; old flag works with
warning; multi-start config validates all plugin options.

#### PR B4 — Multi-plugin startup/shutdown and failure isolation (M)

- Make the runner call `startAllEnabledPlugins()` and
  `stopAllActivePlugins()` only; ordering remains owned by
  `PluginLifecycleService`.
- Probe in parallel, provision sequentially, start independently/in parallel.
- Continue when any/all plugin stages fail.
- Start relay/orchestrator with zero active plugins.
- Stop all plugins with per-plugin and total budgets.
- Replace process-fatal plugin failure latch behavior.

Verification: controlled timing/failure tests prove one slow/failing plugin does
not block or stop healthy siblings.

#### PR B5 — Dynamic event tracker + per-plugin control status (M)

- Make `PluginEventTracker` track `PluginRuntimeApi` active-set changes
  dynamically while Orchestrator continues to consume only the tracker.
- Merge events without losing per-plugin ordering/source identity.
- Extend control status/provisioning additively with per-plugin data while
  retaining aggregate legacy fields.
- Update debug server to share the same listener/router instances.

Verification: interleaved streams, stop/restart subscription replacement,
late events, debug SSE, desktop old/new control DTO compatibility.

#### PR B6 — Combined diagnostics cache/refresh (M)

- Add Layer-1 host checks, descriptor install/version/login diagnostics,
  `DiagnosticsRepository`, and `DiagnosticsService` cache/in-flight refresh.
- `/global/health` becomes cheap bridge health with no plugin probe.
- Add combined diagnostics handler with explicit force refresh.
- Lifecycle/import changes update cheap cached fields and emit push updates.

Verification: Git/gh/filesystem and stopped/running/failed plugin snapshots;
force refresh deduplication/timeouts; no arbitrary commands.

#### PR B7 — Plugin control + import handlers (S-M)

- Add Start/Stop/Retry and import start/cancel/status handlers.
- Normal Stop returns active count conflict; forced Stop terminates work.
- Start is ephemeral and does not mutate `enabledPlugins`.
- Import requires a live plugin and continues across client disconnect.

Verification: request/response status mapping, restart after terminal failure,
import queue, and E2E debug-server requests.

#### PR B8 — Multi-plugin session creation and scoped catalogs (M)

- Route explicit new-client `pluginId`; null routes OpenCode only.
- Start is performed by selection/control before create; create returns typed
  unavailable if that invariant races.
- Update `defaultPluginId` only after successful explicit creation.
- Scope agent/provider/command catalogs by plugin or public session id; keep
  project-only legacy path on OpenCode.
- Queue first hydration after first successful on-demand start without blocking
  creation.

Verification: OpenCode legacy matrix, stopped Beta start/create, failed create
does not change default, same project with colliding backend session ids.

### MT-B — User checkpoint: bridge parallelism

Pause before client UI:

1. Configure OpenCode + Codex in `enabledPlugins`; both start and serve sessions.
2. Provision one missing runtime while another plugin remains usable.
3. Kill/fail one backend; the bridge, relay, catalog, and sibling plugin remain
   usable.
4. Start/stop/retry Codex and Cursor through debug API; normal stop blocks active
   work and force stop succeeds after confirmation-equivalent retry.
5. Create OpenCode and Codex sessions in the same directory; one project and a
   globally sorted mixed list result.
6. Restart: OpenCode starts by default; on-demand Beta plugins stay stopped.
7. Run combined diagnostics cached/forced; verify install/auth/remediation and
   Git/gh/filesystem checks.
8. Record manual multi-plugin list/import/responsiveness timings.

Do not start C1 until the user marks MT-B passed.

### Foundation C — mobile UX

#### PR C1 — `module_core` diagnostics/control/import data flow (M)

- Add APIs, repositories, services where orchestration is real, plugin/import
  cubits, DI, and SSE status/progress handling.
- Force refresh is explicit; ordinary views use cached diagnostics.
- Reconnect performs one snapshot fetch, never polling.

Verification: pure-Dart repository/cubit tests for start/stop conflict/retry,
force refresh, import persistence/cancel/reconnect, and old-bridge 404 fallback.

#### PR C2 — Plugin-aware new-session core + mobile picker (M)

- Add selected/default plugin state to `NewSessionCubit`.
- Always send explicit plugin id from new clients.
- Selecting stopped Beta performs Start and displays provisioning/status before
  plugin-scoped agent/provider/command loading.
- Successful create updates the next diagnostics/default snapshot.

Verification: OpenCode default, last-used default, Beta labels, stopped start,
failed provisioning, only-one-plugin layout, old bridge fallback.

#### PR C3 — Mixed session badge/filter + context-aware detail (M)

- Show plugin badges and All/per-plugin filter.
- Load detail catalogs by public session id.
- Show read-only catalog state with Start/Retry when stopped/unavailable/missing.
- Do not expose `created_with_sesori` yet.

Verification: mixed/colliding raw ids, filter behavior, stopped navigation,
Start recovery, existing model/agent/variant persistence.

#### PR C4 — Mobile plugin settings/diagnostics/import screen (M)

- Render combined cached/forced diagnostics and remediation guidance.
- Add ephemeral Start/Stop/Retry with force confirmation.
- Add explicit import, progress, cancellation, known-folder defaults, and extra
  folder picker for directory-scoped plugins.
- Keep all business state in `module_core` cubits.

Verification: widget tests plus manual background/disconnect/reconnect behavior.

### MT-C — User checkpoint: end-to-end mobile

1. Upgrade the app and connect to single-OpenCode bridge; current behavior is
   unchanged.
2. Confirm Codex/Cursor appear stopped and Beta in new-session/settings UI.
3. Select Codex, observe start/provision progress, create immediately, and see
   hydration continue separately.
4. Confirm last successful plugin is preselected next time but remains stopped
   after bridge restart until selected.
5. Verify mixed badges/filter, plugin-scoped model/agent/commands, notifications,
   questions, permissions, children, archive/delete, and offline read-only state.
6. Force-stop active work only after confirmation.
7. Import global and directory-scoped histories; cancel/reconnect; confirm direct
   external roots require import and tombstoned sessions do not return.
8. Run an older app: missing plugin context uses OpenCode; OpenCode operations
   remain compatible.
9. Record final manual p50/p95/p99 and import responsiveness results.

### Foundation D — desktop inheritance and cleanup

#### PR D1 — Phase-4 shared UI extraction integration (S-M, dependency-gated)

When desktop Phase 4 reaches the affected screens, move the plugin-enhanced
mobile screens into `module_app_ui` with the rest of project/session/settings
UI. Desktop consumes the same `module_core` cubits and widgets. No duplicate
desktop plugin service/repository/cubit is allowed.

#### PR D2 — Documentation/status and deprecation follow-up (S)

- Mark shipped PRs/manual gates.
- Update `CONSIDERATIONS.md`, roadmap status, API/CLI help, diagnostics/import
  operator docs, and the future idle lifecycle/provenance-filter follow-ups.
- Do not remove `--plugin`; removal requires a separately announced release.

## 12. Verification Matrix

Every bridge PR: `dart pub get`, touched-module `dart analyze --fatal-infos`,
`make test`, and codegen cleanliness. Every shared change validates all plugin
implementors plus bridge, mobile, and desktop consumers. Every client PR runs
`dart test` for pure modules and `flutter test` for affected shells.

Required automated correctness coverage:

- owner isolation and migration integrity;
- duplicate backend handles across plugins;
- public/backend id translation on every operation/event;
- zero plugin invocation from normal project/session/child list reads;
- no cross-plugin deletion/reconcile/import contamination;
- unknown roots ignored, proven descendants persisted, parent cascade;
- imports atomic/non-destructive/cancellable and tombstone-aware;
- failed plugin stages isolated from bridge/siblings;
- dynamic event subscription teardown/restart;
- active-work stop conflict + force;
- legacy null/project-only context -> OpenCode;
- additive old/new shared/control DTO decoding; and
- mobile no-polling stream/reconnect behavior.

Manual-only performance records at MT-A/MT-B/MT-C:

- project list and first-page session list p50/p95/p99;
- large import duration and cancellation latency;
- database size/index behavior for realistic history;
- bridge request/event responsiveness during Codex scan and concurrent plugin
  activity; and
- startup timing with several healthy, unavailable, provisioning, and failed
  plugins.

## 13. Rollout and Compatibility

- Multi-plugin remains opt-in because fresh startup still runs only OpenCode.
- Schema lands before behavioral cutover; live reads remain until hydration and
  write-through are tested.
- DB-only reads never regain a plugin fallback.
- Protocol fields are additive and nullable/defaulted.
- New clients always identify plugins; absent context follows the explicit
  OpenCode legacy rule.
- New client against old bridge treats missing diagnostics/control routes as
  single-OpenCode mode and hides unsupported controls.
- Old client against new bridge keeps OpenCode creation/catalog semantics and
  can use opaque public ids for ordinary session operations.
- Control protocol keeps legacy aggregate plugin state while adding per-plugin
  snapshots.
- Plugin failure never changes process exit semantics; only bridge-level fatal
  failures/restart/contention/auth sentinels exit the helper.

## 14. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Cross-plugin id collision | Public Sesori ids plus unique owner/plugin/backend binding; migration tests with deliberate collisions. |
| Cross-plugin row deletion | No absence-based import deletion; every tombstone/retry query owner+plugin scoped. |
| Catalog/live projection races | Catalog is authoritative; event/import upserts preserve Sesori-owned fields and use unique backend binding. |
| Main-isolate blocking | Backend-specific heavy discovery stays in plugin and runs off the request/event isolate; imports serialize globally. |
| One plugin stalls startup | Parallel bounded probes, sequential provision, independent start/failure state. |
| Dynamic stop breaks bridge | Active-work conflict, forced explicit retry, API/event removal only for that plugin. |
| Settings races | Serialize/atomically write `defaultPluginId`; lifecycle Start/Stop does not mutate startup settings. |
| Old client ambiguity | Missing context always means OpenCode; no heuristic/default-plugin routing. |
| Duplicate catalog tables drift | Evolve existing project/session tables; no parallel catalog row model. |
| Import resurrection after delete | Durable owner/plugin/backend tombstone checked before every import/event admission. |
| Account switch leaks catalog | Owner-scoped keys/queries; new owner gets its own hydration attempts. |
| Diagnostics becomes a command runner | Typed read-only checks/remediation only; Start is the only provisioning action. |

## 15. Deferred Automatic Idle Lifecycle

The long-term desired behavior is demand-start plus delayed idle-stop. This plan
deliberately implements the start seam now and defers only the idle policy.

Future behavior to preserve:

- selecting a plugin for a new session, sending a message/command, explicit
  Start, or import can wake the owning plugin;
- catalog browsing, filtering, and diagnostics cache reads do not wake it;
- an active run, in-flight request, import, provisioning/start/stop operation,
  pending question/permission, or recent plugin event prevents idle-stop;
- after a configurable quiet delay, a one-shot rescheduled timer requests
  normal stop (this is scheduling, not polling);
- activity arriving during stop either cancels before teardown or queues one
  start after stop settles;
- manual Stop retains the active-work conflict/force semantics and is not
  immediately undone by background policy;
- startup preferences remain separate from runtime idleness; and
- the same `PluginLifecycleService` is the only start/stop path.

Do not pre-build an idle tracker, lease abstraction, policy framework, or timer
in this workstream. The current lifecycle API and event/status streams must only
avoid foreclosing this follow-up.

Also deferred: expose `created_with_sesori` in the client as a
Sesori-created/imported filter. The required data is captured now so that later
UI needs no migration.

## 16. Findings Log

Record implementation discoveries, accepted plan deltas, manual checkpoint
results, and benchmark measurements here. Source comments must not reference
this plan/PR numbering.

| Date | PR/Gate | Finding or result | Plan impact |
|---|---|---|---|
| TBD | Re-audit | Rebase/current-schema audit after PR #412 cascade | Update file/version references only; architecture changes require plan review. |
