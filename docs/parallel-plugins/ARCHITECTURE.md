# Bridge-Owned Project and Session Catalog Architecture

> Status: **direction approved; Stages 0-9 implemented**.
> This document records durable product and architecture decisions for parallel
> plugin support. It is intentionally not an execution plan. The concrete data
> flow, migration, rollout, verification, and staged PR sequence live in
> [`PLAN.md`](PLAN.md). The controlled Stage 9 fixed-host matrix and soak results
> are recorded in `baselines/stage-9-macos-arm64.json`; all release gates passed.

## 1. Decision

Sesori is the primary surface for managing AI-assisted work. The bridge owns the
durable catalog of projects, sessions, and their relationships. Plugins are
execution harnesses and capability providers; they are not the normal source for
project and session list reads.

Normal project and session list requests read only from the bridge-owned catalog.
They never enumerate enabled plugins. This is both the ownership model and the
performance model for parallel plugins.

The catalog is authoritative for what Sesori knows and presents. A plugin remains
authoritative for whether its backend can execute or resume an operation right
now.

## 2. Why This Direction

### Product ownership

Sesori should offer one stable meaning for a project, session, and child task
regardless of the harness executing it. Names, archive state, worktree
attribution, unseen state, and parent-child relationships should not be rebuilt
from several backend-specific views whenever a client opens a screen.

This follows the product direction in `docs/VISION.md`: the bridge is the system
of record, the plugin boundary remains sacred, and humans and future automation
use the same session-control surface.

### Parallel-plugin behavior

Live aggregation would make every list request wait on all relevant plugins. Its
latency and failure behavior would be controlled by the slowest backend. It would
also multiply known costs such as OpenCode HTTP reads, Codex rollout scans, and
ACP directory-scoped RPC enumeration.

A bridge-owned catalog performs that merging when data enters Sesori. Reads then
depend on indexed local data and result size, not on plugin count, plugin health,
or backend enumeration strategy. A plugin outage may degrade controls for its
sessions, but it must not erase those sessions from the user's catalog.

### Durable product capabilities

A durable catalog and task graph provide the stable base needed for notifications,
cross-session visibility, opt-in automation, and a future master agent. Those
features should reason about Sesori entities, not repeatedly reconstruct state
from heterogeneous harnesses.

Performance is an important consequence, but not the sole justification. Exact
gains must be measured against the code and backend versions that exist when the
work starts.

## 3. Ownership Boundary

Sesori owns the durable catalog representation of:

- projects and sessions known to Sesori;
- project-to-session and parent-to-child relationships;
- plugin binding and backend-handle attribution;
- bridge-owned names and archive or deletion intent;
- worktree, base-branch, and prompt-default metadata;
- unseen and activity state;
- catalog provenance and last-known lifecycle/list metadata.

Plugins own:

- agent execution and backend runtime state;
- transport and process lifecycle;
- backend capabilities, models, agents, variants, and commands;
- actual current operability of a backend session; and
- transcript and message retrieval until Sesori separately chooses to own that
  data.

Persisting a last-known session does not prove that the backend can still open
it. Conversely, a temporarily unavailable plugin does not invalidate the durable
Sesori entity.

## 4. Catalog Update Semantics

### Sesori-initiated work

Project and session changes initiated through Sesori write through to the catalog
immediately. This includes creating, opening, renaming, archiving, deleting, and
updating bridge-owned control metadata.

A session created through Sesori must appear in Sesori immediately; it must not
wait for a later backend enumeration.

### Events for known sessions

Plugin events may update list metadata and lifecycle state for sessions already
known to Sesori. The bridge does not need to prove that each event was caused by
a Sesori request. Once a session is part of the catalog, live events for it may
keep the last-known projection current.

Events must not generally discover unrelated external root sessions or projects.
Using a harness directly remains outside Sesori's continuously managed catalog
until the user imports that work.

### Child sessions and tasks

Child sessions are the deliberate exception to the unknown-session rule. A child
spawned from a known session is causally part of Sesori-managed work, even when
the harness creates it autonomously.

An event may discover and persist a child only when its parent or ancestor can be
resolved to a known Sesori session from the same plugin. The child inherits its
project and plugin attribution from that proven ancestry. The bridge must not
invent a location or project from an unknown durable identifier.

Nested children form a durable task hierarchy. Root session lists exclude child
rows, while task-oriented views may read the hierarchy from the catalog. Child
sessions remain as task history after completion or backend-side deletion.
Deleting a parent through Sesori removes its descendants with it.

Out-of-order child events require explicit ancestry handling. An unresolved child
may wait for its parent or use a targeted lookup under a known root; it must not
trigger global plugin discovery.

## 5. External Harness Activity

The discovery operation is an **import**, not a sync. "Sync" would imply ongoing
or bidirectional convergence that Sesori does not promise.

- Explicit per-plugin import is the general discovery path for projects and root
  sessions created directly in a harness.
- Re-import refreshes the last-known projection of imported entities.
- Known imported sessions then behave like other known catalog sessions, including
  receiving metadata updates from live events.
- Sesori does not run periodic or background plugin enumeration after migration.
- Import is non-destructive by default.

If a session is absent from a later import, the only valid conclusion is that it
was not observed in that import. Absence does not mean deleted or unavailable.
The catalog retains the entity.

Actual inability to use a session is learned when a targeted operation returns a
typed not-found or equivalent domain result. A transient transport or plugin
failure must not become durable evidence that the session no longer exists.

## 6. Identity

The implemented session model separates a Sesori-owned session id, the owning
plugin id, and the opaque backend session handle. Existing session ids were
preserved during migration and backfilled as their backend handles. New created,
imported, and event-discovered bindings receive random Sesori ids, with
uniqueness enforced for each `(plugin_id, backend_session_id)` pair. Session
controls resolve the durable binding and pass only the backend handle to the
owning operational plugin.

Released peers that omit plugin identity decode to OpenCode because OpenCode was
the only backend those peers could target. That legacy identity is distinct from
the bridge's enabled order and default marker: it must never mean "first enabled
plugin." Current clients send the selected plugin for creation and use the
stored session plugin for existing-session operations.

Projects remain one cross-plugin entity per directory with shared hide, name,
and base-branch metadata. The existing separation between project identity and
live path leaves open the option of stronger Sesori-owned identity later.

The local catalog has one owner and does not persist a placeholder owner field.
If a concrete multi-owner requirement arrives, ownership is added with an
explicit migration and backfill based on that requirement's actual identity
model.

The catalog remains per-bridge. It does not collapse or replace the separate
multi-bridge addressing axis.

## 7. Performance Direction And Current Gate

Indexed catalog reads replace plugin enumeration in normal project and session
list paths. List cost should depend primarily on the returned page or project set,
not on the slowest enabled plugin.

An explicit import still pays the backend's enumeration cost, but it is outside
the normal read path. Enumeration occurs before the short atomic publication
transaction. File-backed catalog readers use WAL and a bounded reader pool, so
reads during enumeration or publication observe the last committed catalog
rather than an uncommitted partial import. A failed or cancelled pre-commit
import leaves the previous catalog intact.

Codex rollout enumeration used by import runs in a plugin-owned worker isolate.
Known-event projection and per-plugin event ordering remain independent while an
import is active.

Stage 9 benchmark tooling and the controlled fixed-host run exercise:

- project and session list p50, p95, and p99 latency;
- import duration for realistic backend histories;
- database size and indexed query behavior;
- concurrent import, event, and client-read behavior; and
- bridge responsiveness while a large import is running.

The controlled fixed-host matrix and soak passed every release budget. The raw
measurements, query plans, host metadata, and evaluated gates are retained in
`baselines/stage-9-macos-arm64.json`.

## 8. Implemented Migration And Cutover

Schema v11 contains the generic project, root-session, and child-session
projection needed for catalog reads, stable plugin/backend bindings, projection
timestamps, tombstones, and per-plugin projection-v1 hydration completion. It
does not store backend-specific transcripts.

Startup requests one automatic import for each operational plugin that lacks the
current projection-version completion. Subsequent imports are explicit and
per-plugin.

After the Stage 6 cutover, project, root-session, session-detail, and child reads
do not fall back to plugin enumeration. If automatic import fails, the bridge
preserves known rows, reports per-plugin failure/progress, and keeps those reads
database-only.

`POST /plugin/import`, `DELETE /plugin/import`, and `GET /plugin/import` start,
cancel, and report per-plugin operations. Progress is also emitted as
plugin-attributed SSE. Repeated `--import-plugin <id>` flags provide the same
start trigger for headless operation. Import absence is non-destructive.

## 9. Parallel Runtime And Client Behavior

This decision replaces the earlier assumption that project and session list
endpoints should aggregate every live plugin on every request.

The implemented runtime:

- resolves repeated `--plugin <id>` flags in order, otherwise ordered persisted
  `enabledPlugins`, otherwise the sole OpenCode default;
- marks the first enabled plugin as the current default while keeping the fixed
  OpenCode legacy identity separate;
- starts, monitors, degrades, and stops plugins independently;
- routes session controls through each stored plugin binding;
- exposes ordered lifecycle metadata and supports explicit plugin choice at
  session creation; and
- preserves one shared project space across plugins.

The difference is that mixed project and session lists are assembled from the
bridge catalog rather than live fan-out. Plugin failure degrades execution for
its bound sessions without removing their durable records.

The client discovers the bridge-authored ordered plugin list, selects its
default when routable, lets the user choose another routable plugin, and reloads
agents, providers/models, and commands for that plugin. Saved agent/model/
variant choices are scoped by project and plugin. Existing-session composer
resources use the session's stored plugin identity.

## 10. Tradeoffs

This direction deliberately makes direct harness usage a secondary workflow.
Users who alternate between Sesori and a harness's native interface should not
expect immediate catalog convergence. External work appears after import, and
imported metadata may be stale until another import or a live event for a known
session updates it.

In return, Sesori gains stable ownership, predictable reads, clearer failure
semantics, and a durable base for orchestration. This tradeoff is appropriate
only because the product intends Sesori to become the primary interaction
surface.

## 11. Non-Goals

- Continuous mirroring of direct harness usage.
- Treating absence from import as deletion or unavailability.
- Owning full message transcripts in this workstream.
- Cross-plugin live session migration.
- Offline or local-first caching in the client.
- A permission-policy framework, teams implementation, or cost metering.
- Detailed schema, classes, endpoints, PR sequencing, or compatibility code in
  this direction document.

## 12. Implemented Acceptance Principles

The production behavior now satisfies these architecture principles:

- project and session list requests perform no plugin I/O;
- Sesori-initiated mutations appear in the catalog immediately;
- known-session events update known records without discovering unrelated roots;
- children of known sessions are persisted as a durable hierarchy and cascade
  with parent deletion;
- external projects and root sessions appear only after import;
- import is explicit after one migration hydration, observable, non-destructive
  by default, and does not block reads of the previous catalog;
- plugin outages preserve catalog browsing and clearly degrade controls; and
- no backend-specific field or behavior leaks past `BridgePluginApi`.

## 13. Stage 9 Completion Evidence

The clean `ac56f05b` production/tooling commit was measured on the
human-designated fixed host under the controlled protocol in `PLAN.md`. The raw
versioned JSON matrix/soak artifact is retained, its measured results passed all
release gates, and no budget revision or compatibility-marker removal was
needed.
