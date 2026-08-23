# Client-Triggered Catalog Rescan

## Status

- **Plan slug:** `catalog-rescan`
- **Status:** Active - Step 1/8 plan publication
- **Plan date:** 2026-08-23
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Current implementation base:** `main` at
  `7b1ebe9bc629d05b5d104e76cd5dbaa1514d65a2`
- **Current branch:** `fix-missing-imports-logs`
- **Origin issue:** [#961](https://github.com/sesori-ai/sesori_apps_monorepo/issues/961)
- **Related:** [#1008](https://github.com/sesori-ai/sesori_apps_monorepo/issues/1008)
  owns Codex live updates and is not addressed here
- **Delivery:** eight PRs, slug `catalog-rescan`

## Goal

Give the user a way to re-import harness catalogs from the app, so projects and
sessions created while the bridge was down become visible without running a CLI
flag by hand.

## User Report And Root Cause

Issue #961 reports Codex projects and sessions missing from the app. Fresh logs
from bridge v1.8.0 show the exact mechanism.

A normal start prints:

```text
Imported codex catalog: 0 project(s), 0 session(s).
Imported opencode catalog: 0 project(s), 0 session(s).
```

There is no preceding `Importing codex catalog...` line and no
`Starting plugin "codex"` line. That is the short-circuit in
`CatalogImportService._run`
(`bridge/app/lib/src/services/catalog_import_service.dart:101-118`): an
automatic import whose durable hydration marker already exists publishes
`completed(0, 0)` and returns without enumerating anything or starting the
plugin.

The marker is keyed on `(pluginId, projectionVersion)`
(`bridge/app/lib/src/api/database/tables/catalog_hydrations_table.dart`).
`CatalogImportRepository.projectionVersion`
(`bridge/app/lib/src/repositories/catalog_import_repository.dart:34`) is still
`1` and has never been bumped since it was introduced in
[#488](https://github.com/sesori-ai/sesori_apps_monorepo/pull/488).

Consequences:

1. An install that hydrated a partial catalog under an older bridge keeps that
   partial catalog across every subsequent release.
2. Nothing re-imports afterwards except `sesori-bridge --import-plugin <id>`,
   whose headless trigger sets `explicitImportRequested` and bypasses the marker
   check.

The reporter's explicit run does produce a correct catalog, so the Codex scan
itself is healthy on v1.8.0:

```text
[CodexCatalogRepository][codex] rollout catalog scan: files=193,
  recognizedRollouts=193, indexEntries=45, unreadableOrMissingMetadata=0,
  mismatchedMetadata=0, records=193
[CodexCatalogRepository][codex] catalog discovery: records=193,
  knownDirectories=49, noiseExcluded=0, missingCwd=0,
  projectDirectories=43, sessions=193
```

The gap is the absence of any in-app path to that same import.

## Confirmed Findings

### The bridge side is already complete and entirely unused

| Capability | Location | Shape | State |
|---|---|---|---|
| Start an import | `POST /plugin/import` in `routing/start_catalog_import_handler.dart` | `BodyRequestHandler<CatalogImportRequest, …>`; body carries `pluginId` | Works; zero client callers |
| Cancel an import | `DELETE /plugin/import` in `routing/cancel_catalog_import_handler.dart` | `BodyRequestHandler<CatalogImportRequest, …>`; **also requires `pluginId`** and cancels exactly one plugin | Works; unused |
| Read latest status per plugin | `GET /plugin/import` in `routing/get_catalog_import_statuses_handler.dart` | Returns `CatalogImportService.latestStatuses` | Works; unused |
| Stream progress | SSE `catalog.import.progress` (`sesori_sse_event.dart:51`) | Global, not session-scoped | Emitted; unused |

A repository-wide search for `plugin/import` under `client/` and `shared/`
returns nothing.

### `latestStatuses` retains terminal statuses forever

`CatalogImportService.latestStatuses` returns the last published status per
eligible plugin, with no recency or terminality filter. Because the hydration
short-circuit publishes `completed(0, 0)` for every already-hydrated plugin at
every bridge start, a naive recovery read of `GET /plugin/import` would render
a "Rescan complete / Nothing new" row on every connect. The recovery read must
therefore seed only from non-terminal statuses.

### The two "ignore arms" are not an event dispatch registry

`SesoriCatalogImportProgress` appears in two switch arms today, and **both must
be left exactly as they are**:

- `sse_event.dart:36` is inside `SseEvent._extractSessionId`, which answers
  "which session does this event belong to". A catalog import has no session, so
  removing the arm would either make the switch non-exhaustive or fabricate a
  session binding.
- `sse_event_tracker.dart:103` is the no-op arm of `SseEventTracker._handleEvent`,
  a service that owns project and session activity derivation only.

`SesoriPluginInstallProgress` sits in both arms today and is nonetheless fully
consumed, because `PluginManagementService._onSseEvent` subscribes to
`ConnectionService.events` and pattern-matches it directly. That is the exact
precedent this work copies.

### An import starts the harness backend

`CatalogImportRepository.importCatalog` reaches the plugin through
`PluginRuntime.useStream`, which acquires its lease with `startIfNeeded: true`
(`bridge/app/lib/src/runtime/plugin_runtime.dart:406`). The reporter's log
confirms it:

```text
[CodexPluginDescriptor][codex] app-server started on ws://127.0.0.1:61625
```

A rescan therefore costs a backend start per harness. That is the reason the
deep rescan is a deliberate second-stage action rather than the default refresh.

### Completion counts are totals, not deltas

`CatalogImportCompleted.projectsImported` and `sessionsImported`
(`shared/sesori_shared/lib/src/models/sesori/catalog_import_progress.dart:22-28`)
are the number of rows published, not the number that were new. Reporting them
verbatim after a rescan that changed nothing would tell the user that 193
sessions just arrived.

Both delta facts are already computed inside
`CatalogImportRepository._publishCatalog`:

- a session is new when `currentBindings[session.id]` is `null`
  (`catalog_import_repository.dart:431`);
- a project is new when `_projectCatalogIdentityCalculator.calculate` returns
  `null` for it (`catalog_import_repository.dart:395`).

No new enumeration, query, or persisted state is required to count them.

### The three refresh hosts do not share one scaffold

Two hosts drive `PregoGlassScaffold.onRefresh`: the project list
(`project_list_screen.dart:179`) and the full-screen session list
(`session_list_scaffold.dart`). The third does not.
`SessionListPanel._buildScrollableContent`
(`client/app/lib/features/session_list/session_list_panel.dart:127-145`) builds
its own `CustomScrollView` with a bare `CupertinoSliverRefreshControl` and never
touches the scaffold.

The deep-pull behavior therefore cannot live in `PregoGlassScaffold`, or the
split-view pane would have to re-implement the threshold and caption logic in
`client/app`. It lives in one `module_prego` refresh-control widget that the
scaffold composes and the pane uses directly.

### The client already has every other pattern this needs

- `PluginManagementService`
  (`client/module_core/lib/src/services/plugin_management_service.dart`) folds
  `SesoriPluginInstallProgress` into a
  `BehaviorSubject<Map<String, PluginInstallProgress>>` that
  `PluginManagementCubit` renders. The rescan service mirrors it.
- The existing refresh builder already receives `refreshState`, `pulledExtent`,
  and `triggerDistance`
  (`client/module_prego/lib/components/navigation/prego_glass_scaffold.dart:356`).
- The top-of-list slot the progress row occupies already exists: a
  `LinearProgressIndicator` sliver at `project_list_screen.dart:302` and at
  `session_list_panel.dart:137`.
- Harness enablement is already known to the client through
  `PluginManagementMetadata.runtimeState.isEnabled`
  (`shared/sesori_shared/lib/src/models/sesori/plugin_management.dart:20`).
- `client/app/lib/core/widgets/` already holds the shell's cross-feature widgets
  (`connection_banner.dart`, `session_split/`), which is where a widget consumed
  by two features belongs.

## Approved Design

These were decided by the user during planning. Do not reopen them.

### Two-stage pull-to-refresh

**Stage 1 (soft) is unchanged.** Pull to the normal trigger distance. Refetches
projects or sessions from the bridge's committed catalog. Awaited, spinner in
the refresh control, near-instant. This remains the default and the only
behavior most pulls produce.

**Stage 2 (deep rescan)** arms when the pull passes `1.6 x triggerDistance`.
The refresh control's caption follows the pull:

| Pull distance | Caption |
|---|---|
| below `triggerDistance` | none (today's indicator) |
| `triggerDistance` to `1.6 x` | `Keep pulling to rescan harnesses` |
| past `1.6 x` | `Release to rescan harnesses` |

Release runs the soft refresh exactly as today **and** additionally triggers the
catalog import. The import is never awaited: the refresh control settles on the
soft refresh alone.

All three arming, caption, and release-dispatch behavior lives in a single
`module_prego` widget, `PregoSliverRefreshControl`, which wraps
`CupertinoSliverRefreshControl` and owns the one mutable `bool` recording
whether the deep threshold was crossed at the moment of release.
`PregoGlassScaffold` composes it behind a new optional `onDeepRefresh`
parameter; `SessionListPanel` uses it directly in place of its bare
`CupertinoSliverRefreshControl`. No pull-threshold logic is written in
`client/app`.

All three hosts get stage 2: the project list, the full-screen session list,
and the wide split-view session pane.

### One aggregate progress row

A single sliver at index 0 of the list, taking over the slot the soft-refresh
`LinearProgressIndicator` uses today. It scrolls with the list as an ordinary
entry. It is not pinned, not a banner, not a toast, not a dialog.

| State | Leading | Title | Subtitle | Trailing |
|---|---|---|---|---|
| Running | indeterminate ring | `Rescanning harnesses` | harness currently enumerating plus its running session count | cancel |
| Succeeded | check | `Rescan complete` | new-item summary | none; the service clears it after 4s |
| Partly failed | warning | `Rescan finished` | `1 of 3 harnesses failed` plus the sanitized message | dismiss |
| Failed | warning | `Rescan failed` | sanitized `CatalogImportFailed.message` | dismiss |
| Cancelled | — | — | — | row removed immediately |

With several harnesses enabled the row stays a single row. Its subtitle names
whichever harness is currently enumerating; it does not grow one row per
harness, so the top of the list never reflows as harnesses finish at different
times. The terminal states summarise the whole fan-out rather than reporting
whichever harness happened to finish last.

The success summary is worded from the counts carrier:

- delta known, one or more new: `5 new sessions in 2 new projects`;
- delta known, nothing new: `Nothing new`;
- totals only, which is what an older bridge sends:
  `43 projects, 193 sessions`.

Cancel issues one `DELETE /plugin/import` per harness still running.

### Non-gesture twin on Settings to Harnesses

Each `_HarnessControlCard`
(`client/app/lib/features/settings/harnesses_settings_screen.dart:384`) gains a
`Rescan` action that imports that one harness. This is required, not optional:
the pull gesture is invisible to screen readers and awkward with a mouse, and
the reporter runs the bridge on a desktop. The user chose this placement over an
app-bar menu item.

The action is offered only for a harness whose `runtimeState.isEnabled` is true,
and it is disabled while that harness already has a rescan in flight.

## Ownership And Data Flow

```text
pull past 1.6x   ->  ProjectListCubit / SessionListCubit
Settings Rescan  ->  PluginManagementCubit
                          |
                          v
                  CatalogRescanService          (client/module_core/lib/src/services)
                    |  startAll() / start(pluginId) / cancel()
                    |
                    +-- PluginManagementService.snapshots   (enabled set + display names)
                    |
                    +-- PluginRepository                    (client/module_core/lib/src/repositories)
                    |        v
                    |     PluginApi                         (client/module_core/lib/src/api)
                    |        v
                    |     POST / DELETE / GET /plugin/import
                    |
                    +-- ConnectionService.events            (SSE + connection status)
                          |
                          v
                  ValueStream<CatalogRescanState>
                          v
        rescan row in client/app/lib/core/widgets/, hosted by
        the project list, the session list, and the split-view pane
```

`CatalogRescanService` is a `@lazySingleton` in `module_core`, resolved with
`getIt<CatalogRescanService>()` per the app shell's DI convention. Its declared
collaborators are exactly `PluginRepository`, `PluginManagementService`, and
`ConnectionService`.

`PluginManagementService.snapshots` is the source for both the enabled-harness
set and the display names the row shows. It is a Layer-3 to Layer-3 composition,
which the module permits, and it is preferred over a second
`PluginRepository.getManagement()` read because the snapshot is already
maintained, already refreshed on reconnect, and already invalidated by
`plugin.management.changed`. A second read would duplicate that lifecycle.

`CatalogRescanState` and its counts carrier live in
`client/module_core/lib/src/services/models/catalog_rescan_state.dart`.

`startAll()` reads the current management snapshot, keeps every harness whose
`runtimeState.isEnabled` is true, and issues one `POST /plugin/import` per
harness. A harness the bridge reports as unavailable answers `503` and a harness
it does not know answers `404`; both are skipped silently, because a harness
that cannot import is not an error the user asked about. Any other failure
surfaces on the row.

`cancel()` issues one `DELETE /plugin/import` per id in
`CatalogRescanRunning.pluginIds`, because the route cancels exactly one plugin
per call.

### State

```text
sealed CatalogRescanState
  CatalogRescanIdle()
  CatalogRescanRunning({ String activePluginName, int sessionsSeen,
                         Set<String> pluginIds })
  CatalogRescanSucceeded({ int harnessCount, CatalogRescanCounts counts })
  CatalogRescanPartlyFailed({ int succeededCount, int failedCount,
                              String message })
  CatalogRescanFailed({ int harnessCount, String message })

sealed CatalogRescanCounts
  CatalogRescanDelta({ int newProjects, int newSessions })
  CatalogRescanTotals({ int projects, int sessions })
```

Five variants rather than a single terminal state with nullable fields, so a
mixed outcome across N harnesses is representable and a half-populated one is
not. `CatalogRescanPartlyFailed` deliberately carries no counts: the row reports
the failure, and a partial count would invite the reader to trust it as the
whole result.

### Lifetimes owned by the service

The service owns every transition out of a terminal state. The row widget
renders whatever it is given and owns no timer.

| Trigger | Transition |
|---|---|
| 4s after a terminal state | to `CatalogRescanIdle` |
| Dismiss tapped on a failure | to `CatalogRescanIdle` |
| Cancel confirmed | to `CatalogRescanIdle` |
| Connection lost, or the active bridge changes | to `CatalogRescanIdle` |
| Connection established or restored | seed from `GET /plugin/import`, keeping only `CatalogImportEnumerating` and `CatalogImportCommitting`; discard every terminal status |

Terminal outcomes are adopted only from the SSE stream, and only for a rescan
this service already knows is running. This is deliberately the whole lifetime
rule: no generation counters, no request fences, and no stale-generation
tracking. `PluginManagementService` needs that machinery because it reconciles
mutations against a versioned snapshot token; a progress stream that resets to
idle on disconnect does not.

Because the service owns the terminal lifetime, two mounted hosts always render
the same row for the same duration, and revisiting a list after a rescan
finished shows nothing rather than replaying a stale success.

## Compatibility

- `CatalogImportCompleted` gains a single **nullable** `newItems` object:
  `CatalogImportNewItems({required int projects, required int sessions})`.
  One optional group rather than two independently nullable ints, so
  "delta known" and "delta absent" are the only two representable cases.
- Every package using `json_serializable` in this repository configures
  `include_if_null: false`, so an older bridge simply omits the key and a newer
  client decodes it as `null`. Nullable is required rather than a zero-valued
  default: defaulting would make an older bridge report `Nothing new` after a
  rescan that in fact imported a hundred sessions.
- A newer bridge talking to an older client is unaffected: the added key is
  ignored by the older decoder.
- No new route, no route signature change, and no change to either existing
  request body. Fanning out one request per harness keeps the client working
  against every published bridge.
- The `projectionVersion` bump writes new marker rows and leaves the
  `projectionVersion = 1` rows in place. No migration, no backfill, no schema
  change.

## Complexity Budget

New persisted state: **none**.

New wire fields: **one nullable object** on one existing event.

New in-memory mutable parts:

| Part | Owner | Why it must exist |
|---|---|---|
| `Map<String, CatalogImportProgress>` | `CatalogRescanService` | Aggregating several concurrent harness imports into one row requires the latest progress per harness |
| `BehaviorSubject<CatalogRescanState>` | `CatalogRescanService` | The published stream, seeded so a late subscriber renders correctly |
| `CompositeSubscription` | `CatalogRescanService` | SSE plus connection-status subscriptions, matching `PluginManagementService` |
| `Timer?` | `CatalogRescanService` | The 4s terminal-state clear. Owned here, not by the row, so two mounted hosts cannot run disagreeing timers |
| `bool _disposed` | `CatalogRescanService` | Module convention for `Disposable` services |
| `bool _deepArmed` | `PregoSliverRefreshControl` | The refresh control reports pull distance continuously but fires `onRefresh` once; the threshold state at release must survive that one frame |

Two fan-outs are recorded rather than hidden: `startAll()` issues one `POST` per
enabled harness, and `cancel()` issues one `DELETE` per running harness. Both
are required by routes that address exactly one plugin per call, and neither
adds retained state beyond `CatalogRescanRunning.pluginIds`.

Deliberately **not** added:

- **No authorship tracking.** `catalog.import.progress` is a global SSE event by
  design. A rescan started from the CLI or another surface showing on this phone
  is correct behavior, not a leak, so the service does not record which surface
  started what.
- **No `catalogImport` management capability.** Adding a declared capability
  would be a wire change bought only to avoid skipping two status codes.
- **No bulk `import all` route.** It would need a capability flag or a fallback
  path for older bridges to buy one fewer round trip.
- **No polling.** `GET /plugin/import` is read once when the service connects or
  reconnects. There is no timer and no repeated read.
- **No generation or fence machinery.** Resetting to idle on disconnect makes it
  unnecessary at this scale.
- **No changes to the two SSE switch arms.** Both are correct as they stand;
  the service pattern-matches the event itself.
- **No persisted last-rescan timestamp.** A `Last scanned 6 days ago - Rescan`
  nudge is a plausible follow-up and is explicitly out of scope.
- **No change to the once-per-install automatic hydration.** Importing on every
  bridge start would boot every enabled harness backend at every launch, which is
  the exact cost the durable marker was built to avoid.

## Accepted Risks

| Risk | Impact | Decision |
|---|---|---|
| `projectionVersion = 1` rows stay in `catalog_hydrations_table` after the bump | Three dead rows, invisible to the user | Accepted. No cleanup migration; cosmetic residue does not justify schema work |
| A deep rescan boots every enabled harness backend | CPU and fan cost on the user's machine | Accepted and intended. It is gated behind a deliberate extra pull and an explicit Settings action, never a plain refresh |
| An older bridge omits `newItems` | Success row shows totals instead of a delta | Accepted. Honest degradation, and the absent group makes the difference explicit rather than silently wrong |
| A rescan in flight when the connection drops | The row disappears and does not return | Accepted. The bridge continues and commits the import; the next connect seeds only non-terminal statuses, so a rescan that finished meanwhile is simply not announced |
| Two surfaces trigger a rescan for the same harness at once | The bridge coalesces it: `CatalogImportService.start` finds the active control and applies the trigger to it | No client-side guard needed; existing bridge behavior is correct |
| A cancel `DELETE` races a harness that just completed | The bridge answers on the already-settled plugin and the SSE terminal event wins | Accepted; no client-side ordering guard |

## Cleanup Assessment

Inspected for obsolescence: the soft-refresh `LinearProgressIndicator` sliver in
both hosts, the totals fields on `CatalogImportCompleted`, the hydration marker
table, the `--import-plugin` CLI flag, the two SSE switch arms, and
`SessionListPanel`'s bare `CupertinoSliverRefreshControl`.

Outcome: **one small removal is directly caused, the rest are retained.**

- `SessionListPanel`'s bare `CupertinoSliverRefreshControl` is replaced by
  `PregoSliverRefreshControl` in Step 5. That is a direct, in-PR replacement.
- The soft-refresh indicator still serves stage 1 and is only superseded while a
  rescan is running.
- The totals fields remain the honest fallback for an older bridge.
- The hydration marker still governs first-install hydration, which this plan
  deliberately does not change.
- `--import-plugin` remains the headless and support path.
- Both SSE switch arms are correct and stay.

One item is deferred rather than found-and-skipped: if a future plan does move
automatic import off the durable marker, the marker table, its DAO,
`CatalogEmptyHydrationPolicy`, and `projectionVersion` all become dead together
and should be removed in one coherent PR at that time.

## Regression Coverage

Affected feature documents:

- `docs/regression/projects-and-sessions.md` - owns the import contract. Its
  existing line, "Import is explicit, per plugin, atomic, non-destructive,
  cancellable, and attributes progress", stays true and gains the
  client-triggered rescan and the new-item reporting.
- `docs/regression/plugin-setup-and-lifecycle.md` - owns the harness management
  surface, which gains the per-harness `Rescan` action.

Highest level needed: **L3 Release**. The delivered behavior ends at rendering
in the client, so the authoritative boundary is client end to end; no lower
boundary observes the gesture, the row, or the wording.

Required matrix:

| Dimension | Scope | Reason |
|---|---|---|
| Boundary | Client end to end, plus automated for the delta counting | The count itself is deterministic repository behavior with an owning suite; the gesture, row, and wording are not |
| Plugin | Representative for the gesture, row, cancel, and fan-out | The bridge owns import after a normalized plugin boundary |
| Plugin | One native-ownership and one bridge-derived harness for the new-item counts | `_publishCatalog` counts projects differently per `PluginProjectOwnership` branch, so one branch cannot prove the other |
| Plugin | Two enabled harnesses at once for the aggregate terminal states | A single-harness run cannot prove `CatalogRescanPartlyFailed` |
| Platform | One mobile platform plus the wide split-view layout | The pane hosts stage 2 through a different scroll owner than the two scaffold hosts |
| Compatibility | One run against a bridge that omits `newItems` | Proves the totals fallback rather than a false `Nothing new` |
| Recovery | One reconnect against a bridge holding terminal statuses | Proves the recovery read discards them instead of announcing a stale success |

Any reduction to this matrix requires explicit user acceptance recorded here
before the plan is retired.

## Non-Goals

- Codex live updates for sessions advancing in an external CLI process; that is
  [#1008](https://github.com/sesori-ai/sesori_apps_monorepo/issues/1008).
- Changing when automatic hydration runs, or removing the durable marker.
- A bulk import route, an import capability flag, or any other new wire route.
- A persisted last-rescan timestamp or a staleness nudge in the list.
- Per-harness progress rows.
- Analytics. This is a reliability repair for a reported defect, not a product
  adoption question.
- Any change to `client/desktop`, which hosts no project or session list.

## Delivery Rules

- The series has exactly eight steps.
- Every step updates `TRACKER.md` with its base, actual changed-line count,
  verification, review outcome, and PR link.
- Tests and analysis run only for the packages a step touches. CI owns the full
  matrix.
- `architecture-plan-review` reviewed this plan and rejected the first revision;
  all ten findings were applied directly and are recorded in `TRACKER.md`.
- Run `architecture-implementation-review` on steps 3, 4, and 6, which are the
  architecture-bearing ones. Steps 2, 7, and 8 do not qualify. Step 5 qualifies
  only because it introduces a new shared `module_prego` component and changes
  which owner drives the pane's scroll; review it if that component's API is not
  a straight extraction.
- Step 8 moves `.plan/active/catalog-rescan/` to
  `.plan/completed/catalog-rescan/` only after the recorded L3 matrix passes.

## Fixed PR Series

| Step | Exact PR title | Changed-line target |
|---|---|---:|
| 1/8 | `🌱 [catalog-rescan] Plan client-triggered catalog rescan [step 1/8]` | 850-1,000 |
| 2/8 | `🌱 [catalog-rescan] Re-hydrate stale plugin catalogs [step 2/8]` | 20-60 |
| 3/8 | `⚙️ [catalog-rescan] Report new items from a catalog import [step 3/8]` | 350-600 |
| 4/8 | `⚙️ [catalog-rescan] Add the client catalog rescan service [step 4/8]` | 700-1,050 |
| 5/8 | `⚙️ [catalog-rescan] Add a second stage to pull-to-refresh [step 5/8]` | 350-600 |
| 6/8 | `⚙️ [catalog-rescan] Surface catalog rescan in the app [step 6/8]` | 700-1,100 |
| 7/8 | `🌱 [catalog-rescan] Reconcile catalog rescan regression docs [step 7/8]` | 80-160 |
| 8/8 | `🌱 [catalog-rescan] Verify and retire the catalog rescan plan [step 8/8]` | 60-140 |

Step 5 is `⚙️` rather than `🌿` because it extracts a new shared component and
moves the split-view pane onto it, rather than adding a parameter to one widget.

## Step 1/8 - Publish The Plan

### Scope

- Add this `PLAN.md` and `TRACKER.md`.
- Record the root cause, the approved design, the complexity budget, the
  accepted risks, and the fixed series.
- Run architecture plan review and apply valid findings directly.

### Verification

- `git diff --check`
- plan files only in the diff
- plan and tracker agree on titles and step total

## Step 2/8 - Re-Hydrate Stale Plugin Catalogs

Ships first and independently because it repairs the reported cohort
immediately, ahead of any UI work.

### Scope

- Bump `CatalogImportRepository.projectionVersion` from `1` to `2` with a
  comment recording why: every marker written before v1.8.0 can describe a
  catalog produced by superseded discovery, and the marker is the only thing
  preventing a correction.
- Leave `projectionVersion = 1` rows in place. No migration, no cleanup.
- Adjust only the tests that assert the constant.

### Expected result

Each enabled harness re-hydrates once on the next bridge start. Re-import is
non-destructive: `_mergeProjectRow` and `_mergeSessionRow` preserve `hidden`,
`displayName`, `title`, overrides, and archive state, and
`getTombstonedSessionIds` keeps deleted sessions deleted.

### Verification

- targeted `catalog_import_repository` and `catalog_import_service` tests
- `dart analyze --fatal-infos` from `bridge/app`

## Step 3/8 - Report New Items From A Catalog Import

### Scope

- Add `CatalogImportNewItems({required int projects, required int sessions})`
  to `shared/sesori_shared`, add it as a nullable field on
  `CatalogImportCompleted`, and regenerate
  `catalog_import_progress.freezed.dart` and `.g.dart`.
- Count both in `CatalogImportRepository._publishCatalog` from facts already in
  hand: `currentBindings[session.id] == null` for a session, and a `null`
  result from `_projectCatalogIdentityCalculator.calculate` for a project.
  Count correctly in both `PluginProjectOwnership` branches.
- Carry the value through `CatalogImportService` untouched.
- Extend `listeners/catalog_import_console_listener.dart` so a headless import
  prints the delta when it is present.
- Add repository tests covering: a first import where everything is new; a
  re-import where nothing is new; a re-import where some are new; both
  ownership branches; and a decode of a payload with the key omitted.

### Verification

- targeted `catalog_import_repository` tests
- `dart analyze --fatal-infos` from `bridge/app` and `shared/sesori_shared`
- shared model round-trip tests
- architecture implementation review

## Step 4/8 - Add The Client Catalog Rescan Service

### Scope

- `PluginApi`: `startCatalogImport({required String pluginId})`,
  `cancelCatalogImport({required String pluginId})`, and
  `getCatalogImportStatuses()`. Cancel takes a plugin id because
  `DELETE /plugin/import` is a body handler that cancels exactly one plugin.
- `PluginRepository`: map those to typed results, classifying `404` and `503`
  as "this harness cannot import" rather than as failures.
- `CatalogRescanState` and `CatalogRescanCounts` in
  `client/module_core/lib/src/services/models/catalog_rescan_state.dart`.
- `CatalogRescanService` as a `@lazySingleton`, collaborators
  `PluginRepository`, `PluginManagementService`, and `ConnectionService`:
  pattern-match `SesoriCatalogImportProgress` off `ConnectionService.events`
  exactly as `PluginManagementService._onSseEvent` does; read
  `GET /plugin/import` once on connect and reconnect, keeping only
  `CatalogImportEnumerating` and `CatalogImportCommitting`; reset to
  `CatalogRescanIdle` on disconnect and on an active-bridge change; own the 4s
  terminal clear; and expose `ValueStream<CatalogRescanState>`, `startAll()`,
  `start(pluginId)`, `cancel()`, and `dismiss()`.
- Leave `sse_event.dart` and `sse_event_tracker.dart` untouched.
- Tests: aggregation across two concurrent harnesses; all five states including
  a mixed success/failure fan-out; the older-bridge payload with `newItems`
  omitted; a reconnect whose `GET` holds only terminal statuses producing no
  row; a reconnect whose `GET` holds an in-flight status producing a running
  row; a disconnect clearing an active rescan; a fan-out where one harness
  answers `503`; and cancel issuing one `DELETE` per running harness.

### Verification

- targeted `module_core` service and repository tests
- `dart analyze --fatal-infos` from `client/module_core`
- architecture implementation review

## Step 5/8 - Add A Second Stage To Pull-To-Refresh

### Scope

- Add `PregoSliverRefreshControl` to `module_prego`: wraps
  `CupertinoSliverRefreshControl`, owns the `1.6 x triggerDistance` arming, the
  caption selection, and the release dispatch of both callbacks.
- `PregoGlassScaffold` composes it behind a new optional `onDeepRefresh`, and
  asserts that `onDeepRefresh` requires `onRefresh`, matching the existing
  `scrollable`/`onRefresh` assertion.
- `SessionListPanel._buildScrollableContent` replaces its bare
  `CupertinoSliverRefreshControl` with `PregoSliverRefreshControl`, so the pane
  gets stage 2 without any threshold logic in `client/app`.
- Render the caption under the existing indicator only once the pull passes the
  soft trigger, so an ordinary pull is visually unchanged.
- Add a design catalog scenario if the scaffold has one; otherwise widget tests
  covering: a short pull fires only the soft refresh, a long pull fires both,
  and a long pull abandoned before release fires neither. Prove all three in
  the pane as well as in the scaffold.

### Verification

- targeted `module_prego` and `client/app` session-pane widget tests
- `dart analyze --fatal-infos` from `client/module_prego` and `client/app`
- `dart run tool/generate_manifest.dart --check` from `client/design_catalog`
  if a scenario was added

## Step 6/8 - Surface Catalog Rescan In The App

### Scope

- The aggregate rescan row widget in `client/app/lib/core/widgets/`, beside the
  shell's other cross-feature widgets, with its five presentations. It renders
  the state it is given and owns no timer.
- Project list, full-screen session list, and split-view pane: wire
  `onDeepRefresh` to `CatalogRescanService.startAll()`, and render the row as
  the sliver at index 0 in place of the soft-refresh indicator while a rescan is
  running.
- Settings to Harnesses: the per-harness `Rescan` action in
  `_HarnessControlCard`, calling `start(pluginId)`, enabled only for an enabled
  harness and disabled while that harness is already rescanning.
- New `app_en.arb` resources for both captions, the five row states, the delta
  and totals wordings, the `Nothing new` case, the partly-failed wording, and
  the Settings action with its semantics label.
- Widget tests: all five row states; the totals fallback; cancel; dismiss; and
  the Settings action's enablement rules.

### Verification

- targeted `client/app` widget tests
- `dart analyze --fatal-infos` from `client/app`
- `flutter gen-l10n` output committed
- architecture implementation review

## Step 7/8 - Reconcile Regression Docs

### Scope

- `docs/regression/projects-and-sessions.md`: record the client-triggered
  rescan, the two-stage pull across all three hosts, the aggregate progress row
  and its terminal states, cancellation, new-item reporting with its
  older-bridge fallback, and the recovery read discarding terminal statuses.
- `docs/regression/plugin-setup-and-lifecycle.md`: record the per-harness
  `Rescan` action and its enablement rules.
- Record the required plugin, platform, compatibility, and recovery matrix in
  both.

### Verification

- `git diff --check`
- documentation only in the diff
- levels and matrix match this plan

## Step 8/8 - Verify And Retire

### Scope

- Run the recorded L3 matrix, including both ownership branches, the two-harness
  mixed-outcome run, the older-bridge compatibility run, and the reconnect
  recovery run.
- Record the result, and any explicitly accepted reduction, in `TRACKER.md`.
- Move `.plan/active/catalog-rescan/` to `.plan/completed/catalog-rescan/` once
  that coverage passes.
- Close or update issue #961 with the outcome.

### Verification

- every recorded matrix entry has a pass, a blocked reason, or an accepted
  reduction
- plan and tracker agree
- `git diff --check`
