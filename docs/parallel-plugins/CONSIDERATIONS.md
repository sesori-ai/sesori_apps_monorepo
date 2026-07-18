# Parallel Plugin Support - Historical Considerations And Current State

> Status: **historical audit reconciled through completed Stage 9**.
> The durable ownership model is recorded in
> [`ARCHITECTURE.md`](ARCHITECTURE.md), and staged execution remains in
> [`PLAN.md`](PLAN.md). The original pre-scoping audit assumed one running plugin
> and request-time backend lists. Those assumptions are historical, not current
> architecture. Stage 9's controlled fixed-host artifact passed all gates and is
> recorded in `baselines/stage-9-macos-arm64.json`.

## 1. Implemented Outcome

One bridge process can run OpenCode, Codex, and Cursor concurrently. Repeated
`--plugin <id>` flags select plugins in stable order and override persisted
`enabledPlugins`; settings otherwise win, and OpenCode remains the sole fallback
when neither surface selects anything. Duplicates, unknown ids, and an explicit
empty settings list fail validation.

The first enabled plugin is the bridge-authored default for current clients.
That default is not the same concept as `legacyMissingPluginId`: missing identity
from released peers always means OpenCode, regardless of enabled order.

Projects merge into one catalog entity per normalized directory. Root sessions
from different plugins appear together under that project, with each durable
session retaining its plugin binding and opaque backend handle.

Related directional invariants from the root `AGENTS.md` still bind: the
plugin boundary stays sacred (no backend specifics past `BridgePluginApi`),
and there is one session-control surface.

## 2. Current Foundations

- **Separated session identity.** `session_id` is the stable Sesori identity,
  `plugin_id` is the routing key, and `backend_session_id` is opaque outside the
  owning plugin/repository boundary. Existing ids were preserved; new bindings
  receive random Sesori ids.

- **Plugin-agnostic projects table keyed by `path`.** `projects_table` has no
  plugin column, deliberately: projects are cross-plugin entities. The
  mandatory `path` column (today always equal to `project_id`) exists so the
  project identity can stop being a path without a schema change, and so
  cross-plugin merging can join on the directory.
  (`bridge/app/lib/src/api/database/tables/projects_table.dart`)

- **Database-only catalog reads.** Project, root-session, session-detail, and
  child reads query indexed durable rows. They do not call plugins, persist a
  backend list result, or remove rows because a later import omitted them.

- **Non-destructive per-plugin import.** Enumeration and mapping occur outside
  the publication transaction. A complete snapshot publishes atomically for one
  plugin; absence never deletes or archives catalog history. Readers continue to
  observe the last committed catalog while import runs.

- **Sealed plugin capability split.** `BridgePluginApi` is sealed into
  `NativeProjectsPluginApi` (backend owns projects) and
  `BridgeDerivedProjectsPluginApi` (bridge derives them from
  `listAllSessions()` + `launchDirectory`). The split is per-plugin-instance,
  so it composes under parallelism: each plugin in the set is one or the
  other, and per-plugin code keeps switching over the sealed type.

- **Cross-plugin project space.** Import and exact writes merge projects by the
  plugin-declared normalized directory. Hidden, display-name, and base-branch
  metadata remain shared on the one catalog row.

## 3. Implemented Replacements For The Singular Assumptions

1. **Composition and lifecycle.** `PluginLifecycleService` owns one ordered
   composition view. Availability probes are concurrent; provisioning follows
   configured order under one startup mutex while starts may overlap. A failed
   or terminal plugin is removed from operational routing without stopping the
   relay, catalog, or other plugins. Shutdown disposes and drains plugins
   independently.
2. **Repository routing.** Domain repositories receive the ordered enabled ids
   and operational API map where needed. Session operations resolve the stored
   binding; plugin-scoped project operations use an explicit/default plugin id.
   Handlers and services remain plugin-agnostic.
3. **Endpoint semantics.** Catalog lists are database-only. Session status,
   health, project questions, and active summaries aggregate with explicit
   timeout/failure semantics. Agents, providers/models, and commands remain
   plugin-scoped rather than merging backend-local ids.
4. **Sourced events.** The bridge attaches source identity at subscription,
   preserves per-plugin ordering, translates every backend session reference,
   and emits only Sesori identities. One blocked plugin does not block another
   plugin's event stream.
5. **Creation and composer routing.** Current clients discover ordered plugin
   metadata, choose a routable plugin, load that plugin's composer resources,
   and send its id when creating a session. Existing-session composer requests
   use `Session.pluginId`. Saved agent/model/variant choices are keyed by project
   and plugin.
6. **Import.** `POST`, `DELETE`, and `GET /plugin/import` start, cancel, and
   report per-plugin operations. Progress is plugin-attributed SSE, duplicate
   starts join that plugin's operation, and failures do not cancel imports for
   other plugins. Repeated headless `--import-plugin <id>` starts selected
   imports after startup.

## 4. Contract Boundaries That Remain

- **`PluginProject.directory` is required.** Cross-plugin merging uses the
  declared normalized directory and never assumes a backend project id is a
  path.

- **Do not let backend-specific state leak into shared wire models.** Clients
  see one project space and mixed session lists. Generic `pluginId` crosses the
  wire where attribution or choice is required; backend-local ids and behavior
  remain behind `BridgePluginApi`.

## 5. Known Seams And Risks

- **Catalog freshness is deliberately explicit.** Direct harness work is not
  continuously synchronized. Import and known-session events refresh durable
  projections; import absence is not deletion.

- **Operational state is not catalog existence.** A failed plugin remains in
  ordered metadata and its sessions remain browsable, but controls routed to it
  are unavailable until it is operational again.

- **Project metadata is intentionally shared.** Hidden/display-name/base-branch
  values live once per project row, so changing them applies to every plugin in
  that directory.

- **Worktrees are bridge-owned and plugin-scoped today.** Worktree naming
  uses a per-project counter with no plugin dimension; two plugins creating
  worktrees in one repo share the counter (fine) but cleanup flows
  (`deleteWorkspace`) go to the owning plugin — session `plugin_id` again.

## 6. Parallel-Plugin Compatibility Debt

Generated Freezed copies repeat some comments below; the source markers are the
debt authorities. Every listed marker is retained. The version in a marker
records introduction context, not an established support cutoff.

| Source marker(s) | Rationale | Exact future removal criterion | Release uncertainty |
|---|---|---|---|
| `plugin_identity.dart`; plugin defaults in `session.dart`, `create_session_request.dart`, and `plugin_project_id_request.dart` | Released peers omit `pluginId` and could only mean OpenCode. | After the minimum supported bridge and every supported client always send `pluginId`, remove all three defaults plus `legacyMissingPluginId` and its export, then require the field in round trips. | Marked v1.5.0; no minimum-supported bridge/client release or date is set. |
| `health_response.dart` (`plugins`) | Bridges before per-plugin health omit the list. | After all supported bridges send `plugins`, remove `@Default`, require the field, and update compatibility round trips. | Marked v1.5.1; the new stable release boundary and support window are not yet established. |
| `session_status.dart` (`unavailablePluginIds`) | Bridges before aggregate per-plugin status omit unavailable sources. | After all supported bridges send `unavailablePluginIds`, remove `@Default`, require the field, and update compatibility round trips. | Marked v1.5.1; the new stable release boundary and support window are not yet established. |
| `bridge/sesori_plugin_codex/lib/src/codex_config_reader.dart` | Durable old Codex rollouts can omit `turn_context` model metadata, so config remains the fallback. | Remove the config fallback only when the product explicitly stops supporting every rollout that can omit `turn_context`, then remove its fallback tests. | Marked v1.1.2; rollout history has no defined retention/support cutoff. |
| `PluginStateStorage.legacySharedRuntime` on the OpenCode and Codex descriptors | Released installs stored managed binaries, ownership records, and start intent beneath the shared runtime root. Moving either descriptor would strand offline binaries and crash-recovery state. | Move a descriptor to isolated storage only after an atomic migration for its runtime subdirectory and ownership/intent files has shipped, and the minimum supported bridge is newer than that migration. | Both storage layouts predate parallel startup; no migration release or minimum-supported bridge is scheduled. |

## 7. Explicitly Out Of Scope

- Cross-plugin live session migration (dropped per root `AGENTS.md`).
- A master agent across sessions (later roadmap; same session-control
  surface, so parallelism should not special-case it).
- Additional mixed-list badging or filtering beyond current plugin selection.
