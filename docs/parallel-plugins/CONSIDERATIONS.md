# Parallel Plugin Support — Pre-Scoping Considerations

> Status: **direction captured; execution planned; implementation not started**.
> The durable
> ownership and catalog direction is recorded in
> [`ARCHITECTURE.md`](ARCHITECTURE.md). This document remains the pre-scoping
> code audit gathered while building
> bridge-derived project tracking (PR #360). Its live-aggregation assumptions
> are superseded by the bridge-owned catalog decision, but its inventory of
> current seams remains useful. Before implementation, read both documents and
> re-verify every code reference. The current re-audit, concrete decisions, and
> staged execution are tracked in [`PLAN.md`](PLAN.md).

## 1. Target

Today the bridge runs **exactly one plugin per process**, selected at startup
(`--plugin opencode` / `--plugin codex`). The target is multiple plugins
running **in parallel in one bridge**: codex, opencode, and future backends
live at the same time, their sessions appearing together — one project card
per directory with sessions from every plugin under it.

Related directional invariants from the root `AGENTS.md` still bind: the
plugin boundary stays sacred (no backend specifics past `BridgePluginApi`),
and there is one session-control surface.

## 2. Foundations already in place

These decisions were made single-plugin but were shaped for this future.
They should be treated as settled unless planning finds a hard reason not to.

- **`sessions.plugin_id` (NOT NULL, no defaults).** Every session row is
  stamped with its owning plugin at insert; the v7→v8 migration backfilled
  history to `opencode`. Under parallel plugins this is the routing datum:
  it answers *which plugin* owns a session (prompt/abort/question routing for
  mixed lists) and keys every per-plugin query. Do not weaken it back to a
  default. (`bridge/app/lib/src/api/database/tables/session_table.dart`)

- **Plugin-agnostic projects table keyed by `path`.** `projects_table` has no
  plugin column, deliberately: projects are cross-plugin entities. The
  mandatory `path` column (today always equal to `project_id`) exists so the
  project identity can stop being a path without a schema change, and so
  cross-plugin merging can join on the directory.
  (`bridge/app/lib/src/api/database/tables/projects_table.dart`)

- **DB rows as session→project attribution.** `SessionDao.getSessionProjectPaths`
  (sessions⋈projects join, filtered by `plugin_id`) is how derived plugins
  scope sessions to projects; the row the bridge wrote at creation is
  authoritative, worktree sessions fold to their parent through it. The DB is
  the natural cross-plugin merge point, so this only gets more central.

- **Plugin-scoped reconciliation.** `deleteSessionsForProjectNotIn` filters by
  `plugin_id`: a plugin's authoritative session list can only reconcile away
  *that plugin's* rows. Under parallel plugins this is mandatory, not
  defensive — opencode's list must never delete codex rows in the same
  project. Any new reconcile/cleanup path must follow the same rule.

- **Sealed plugin capability split.** `BridgePluginApi` is sealed into
  `NativeProjectsPluginApi` (backend owns projects) and
  `BridgeDerivedProjectsPluginApi` (bridge derives them from
  `listAllSessions()` + `launchDirectory`). The split is per-plugin-instance,
  so it composes under parallelism: each plugin in the set is one or the
  other, and per-plugin code keeps switching over the sealed type.

- **Derived merging already keys by normalized directory.**
  `DerivedProjectBuilder` groups by normalized path, and opencode project ids
  are paths, so two plugins operating in the same repo collide on the same
  key — which is exactly the merge point a unified project card needs.

- **Cross-plugin project listing is intended behavior.** A derived plugin
  already lists every stored project row (e.g. folders recorded during
  opencode use surface under codex until hidden). This looked like a UX
  oddity single-plugin; it is the end state arriving early — one shared
  project space.

## 3. Single-plugin assumptions that must change

An inventory of the places that assume "the plugin", roughly ordered by how
much design they need. This is the core of the future scoping work.

1. **Composition wiring.** `BridgeRuntime.create` takes one `plugin`;
   `bridge_runtime_runner` starts one descriptor under the startup mutex and
   binds one plugin session; `PluginManager`/registry select one descriptor.
   Parallel plugins need a plugin *set* with per-plugin lifecycle
   (start/degrade/stop independently — one backend failing must not take the
   bridge down), and DI that constructs per-plugin object graphs.

2. **Repositories hold exactly one `BridgePluginApi`.**
   `SessionRepository`, `ProjectRepository`, `QuestionRepository`,
   `PermissionRepository`, `ProviderRepository`, `AgentRepository`,
   `HealthRepository`, `WorktreeRepository` each take one plugin. The main
   design fork to resolve at planning time:
   - *(a) per-plugin repository instances* + an aggregation layer above, or
   - *(b) repositories take the plugin collection* and aggregate internally.
   Layer rules apply either way (aggregation is still Layer 2/3; handlers stay
   plugin-agnostic). The session-level routing primitive already exists:
   resolve a session's `plugin_id` from its stored row, then dispatch to that
   plugin's API.

3. **Aggregation semantics per endpoint.** `/project` becomes a union of
   native project lists + derived derivations, merged by directory into one
   card (union times, one hidden flag, one rename). `/sessions` for a project
   becomes a per-plugin union sorted by time. Health, session statuses,
   active-session summaries, providers, agents, and commands all need a
   merge-or-namespace decision (e.g. are agents/models per-plugin namespaced
   in the picker?).

4. **Events carry no plugin identity.** The orchestrator subscribes to one
   `plugin.events` stream. With several streams merged, downstream consumers
   (unseen service placeholders, session enrichment, push listeners) must
   know the source plugin — e.g. to stamp the right `plugin_id` on a
   placeholder row. Expect this to be the first `sesori_plugin_interface`
   contract change of the workstream (either a `pluginId` on `BridgeSseEvent`
   or a bridge-side envelope added at subscription time). The
   `SessionUnseenRepository`'s constructor-injected single `pluginId` is a
   direct casualty of this.

5. **Session-create routing.** `CreateSessionRequest` reaches one plugin
   today. With several capable backends, creating a session needs an explicit
   plugin choice (client-supplied), which touches the shared request model —
   a relay-protocol change, so it must be backwards compatible (missing field
   = the only/default plugin).

6. **Startup/provisioning serialization.** `ensureRuntime` runs under the
   cross-instance startup mutex per plugin; several managed runtimes
   provisioning at once need an ordering/parallelism decision (probably
   sequential provisioning, parallel `start`).

7. **Per-plugin CLI/config.** Options are already namespaced
   (`--codex-*`, `--opencode-*`) which composes; the `--plugin` selector
   becomes multi-valued (`enabledPlugins` bridge setting already hints at
   this).

## 4. Contract doors to keep open (cheap now, expensive later)

- **`PluginProject` may need an explicit directory.** Cross-plugin project
  merging relies on the directory. For derived plugins it is inherent; for
  natives it works because opencode ids *are* paths. If a native backend ever
  ships non-path project ids, `PluginProject` needs a `directory` field so
  the merge keeps working. Cheap to add when needed — this note exists so the
  reason isn't rediscovered from scratch.

- **Do not let per-plugin state leak into shared wire models.** The phone
  should see one project space and mixed session lists; `plugin_id` on the
  wire is only needed where the client must choose (session creation,
  possibly a badge). Keep the relay protocol additive.

## 5. Known seams and risks

- **Two async sources of derived truth.** Derived plugins are read through
  both the backend's enumeration (codex: rollout files on disk) and the
  bridge's rows, and these transiently disagree (rollout-flush window,
  placeholder races). Single-plugin, this produced a series of point patches:
  `DerivedSessionBuilder.buildSessionIds` unioning stored-row attributions,
  merging the plugin's own project-scoped questions, guarded
  orphaned-placeholder cleanup in `insertStoredSession`. Parallel plugins
  multiply the writers on these tables. If this seam keeps producing bugs,
  prefer promoting the bridge's rows to the *single* source of truth (plugin
  enumeration demoted to hydration/discovery) over adding a fourth
  reconciliation special case.

- **Unseen subsystem is single-plugin in shape.** Placeholder stamping,
  view-tracking, and project aggregates assume one event source and one
  `pluginId`. It composes only after events carry plugin identity (§3.4).

- **Project metadata contention.** Hidden/rename/base-branch live once per
  project row and become genuinely shared across plugins — hiding a project
  hides it for every backend. That is probably the desired semantics, but it
  should be an explicit product decision at scoping time.

- **Worktrees are bridge-owned and plugin-scoped today.** Worktree naming
  uses a per-project counter with no plugin dimension; two plugins creating
  worktrees in one repo share the counter (fine) but cleanup flows
  (`deleteWorkspace`) go to the owning plugin — session `plugin_id` again.

## 6. Explicitly out of scope for this document

- Cross-plugin live session migration (dropped per root `AGENTS.md`).
- A master agent across sessions (later roadmap; same session-control
  surface, so parallelism should not special-case it).
- Client-side UX for mixed lists (badging, filtering) — client workstream,
  driven by the same wire models.
