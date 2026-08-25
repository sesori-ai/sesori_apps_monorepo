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
a "Scan complete / No new sessions" row on every connect. The recovery read must
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

**Stage 2 (deep rescan)** fires when the pull passes `1.6 x triggerDistance`.

Both stages commit **on crossing their threshold, while the finger is still
down**, not on release. That is not a choice: `CupertinoSliverRefreshControl`
invokes `onRefresh` the moment the pull reaches `refreshTriggerPullDistance`,
from a post-frame callback, and returns `armed` (`cupertino_ui`
`refresh.dart:504-530`). There is no release-gated commit to hang a second stage
on, so an earlier draft of this plan describing "release to rescan" was
unbuildable. Owner decision 2026-08-24: keep the two-depth gesture and fire on
crossing.

| Pull distance | Caption |
|---|---|
| below `triggerDistance` | none (today's indicator) |
| `triggerDistance` to `1.6 x` | `Keep pulling to scan all harnesses`, quiet and text-only |
| past `1.6 x` | `Scanning for new sessions`, in brand colour with a rotate icon |

The caption cross-fades between the two, keyed on the phase rather than the
text, so passing the threshold reads as one label becoming another and a host
rewording mid-pull cannot look like the stage changed. The fired phase is
visually distinct rather than only differently worded, so the moment of
commitment is legible at a glance.

The catalog import is never awaited: the refresh control settles on the soft
refresh alone. One pull rescans at most once, however far it travels.

Because there is no commit point, a pull past `1.6 x` cannot be taken back by
dragging up. Cancelling is the progress row's job, which is the affordance that
exists for it anyway.

All threshold, caption, and dispatch behavior lives in a single `module_prego`
widget, `PregoSliverRefreshControl`, which wraps `CupertinoSliverRefreshControl`
and tracks the furthest extent this gesture reached plus whether it has already
fired. `PregoGlassScaffold` composes it behind a new optional `deepRefresh`
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
| Starting | indeterminate ring | `Scanning all harnesses` | none | cancel |
| Running | indeterminate ring | `Scanning all harnesses` | the harness currently enumerating and its live session count, e.g. `Codex — 148 sessions` | cancel |
| Succeeded | check | `Scan complete` | `5 new sessions in 2 new projects`, or `No new sessions` | none; the service clears it after 4s |
| Partly failed | warning | `Scan finished` | `1 of 3 harnesses could not be scanned` | dismiss |
| Failed | warning | `Scan failed` | `Check the bridge log for details` | dismiss |
| Unsupported | warning | `Scanning needs a newer bridge` | `Update the bridge to scan from here` | dismiss |
| Cancelled | — | — | — | row removed immediately |

The row is a **tinted card**, not a plain tile: a rounded surface in a subtle
brand tint, visually distinct from the session and project tiles around it. It
reads as status rather than content, so it is never mistaken for a row that can
be opened.

The running subtitle names the harness and its **live** session count rather
than progress across harnesses. A long single-harness scan is exactly when the
user needs reassurance, and a "2 of 3" line goes completely still there while a
climbing count keeps showing movement.

Copy leads with sessions throughout and mentions projects only in the completion
line, and only when there are any. Sessions are what a user notices missing —
#961 was reported as missing sessions — and it keeps the captions short enough
for a 226pt split pane.

The Settings action is labelled `Scan for new sessions`, matching the same
vocabulary.

`Starting` exists because a dispatched request is not yet an enumerating
harness. Between dispatch and the first progress event there is no active
harness name and no session count, so a single running state carrying both
would have to invent them and claim enumeration the client cannot observe.

**No failure text from the bridge is rendered.** `CatalogImportService._run`
catches `Object` and sends `error.toString()` as `CatalogImportFailed.message`,
so that field can carry paths, identifiers, and other local context. It is a
useful bridge log line and an unsafe phone string. The row therefore reports a
bounded failure and points at the log, and `CatalogRescanFailed` carries no free
text at all. Adding a sanitization boundary at the producer would let the row say
more; that is recorded as a follow-up rather than smuggled into this series.

### Refreshing the list after a rescan commits

A committed import does **not** invalidate the client's lists today.
`CatalogImportRepository.backendActivity` feeds only `ChatHistoryActivityListener`
(`orchestrator.dart:524-527`); the `sessionsUpdated` producers are PR sync and
the unseen service, neither of which the import touches. The stage-1 soft refresh
runs on release, before the import commits, so without an explicit refresh the
row would announce new sessions over a list that still lacks them.

`CatalogRescanService` therefore emits `catalogChanged` for every observed
`CatalogImportCompleted`, and `ProjectListCubit` and `SessionListCubit` refresh
from that durable-data signal. This remains a client-side refresh, not a new
bridge event: the service already receives the global progress stream, so a
rescan started from the CLI or another surface refreshes these lists just the
same.

The signal is deliberately tied to `CatalogImportCompleted`, not to closing the
progress row. A cancel closes that row immediately, but the bridge's `DELETE`
only requests cancellation; an atomic publish that already began can still
complete. The terminal completion is the first point at which a list read is
known to see the durable catalog.

With several harnesses enabled the row stays a single row. Its subtitle names
whichever harness is currently enumerating; it does not grow one row per
harness, so the top of the list never reflows as harnesses finish at different
times. The terminal states summarise the whole fan-out rather than reporting
whichever harness happened to finish last.

The success summary is worded from the counts carrier:

- delta known, one or more new: `5 new sessions in 2 new projects`;
- delta known, nothing new: `No new sessions`;
- totals only, which is what an older bridge sends:
  `43 projects, 193 sessions`.

Across an N-harness fan-out the counts are **summed**, not taken from whichever
harness finished last. The carrier is `CatalogRescanDelta` only when every
succeeded harness reported `newItems`; if any one omitted it, the whole row
falls back to `CatalogRescanTotals` summed the same way, because a delta missing
one harness's contribution would understate the result and read as authoritative.
Every harness in a fan-out answers from the same bridge, so in practice the
mixed case arises only if a bridge reports inconsistently; the rule exists so
that case degrades honestly rather than silently.

Cancel issues one `DELETE /plugin/import` per harness still running.

### Non-gesture twin on Settings to Harnesses

Each `_HarnessControlCard`
(`client/app/lib/features/settings/harnesses_settings_screen.dart:384`) gains a
`Rescan` action that imports that one harness. This is required, not optional:
the pull gesture is invisible to screen readers and awkward with a mouse, and
the reporter runs the bridge on a desktop. The user chose this placement over an
app-bar menu item.

The action is offered only for a harness whose `runtimeState.isRoutable` is true,
and it is disabled while that harness already has a rescan in flight.
`isEnabled` is deliberately **not** the predicate: it is true for
`PluginRuntimeState.blocked` and `failed`, neither of which the bridge admits to
`startAllowedPluginIds` (`plugin_runtime.dart:105-108`, which requires
`accessGate == enabled && slot.startAllowed`). Offering a tappable `Rescan` on a
setup-blocked harness would produce a `503` and, under the fan-out's silent-skip
rule, no visible result at all.

The silent `503` skip belongs to `startAll()` only. A **targeted** rescan — the
Settings action, where the user named exactly one harness — surfaces the
rejection on the card instead of skipping it.

## Ownership And Data Flow

```text
                  CatalogRescanService          (client/module_core/lib/src/services)
                    |  startAll() / start(pluginId) / cancel() / dismiss()
                    |
                    +-- PluginManagementService.snapshots   (routable set + display names)
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
       ValueStream<CatalogRescanState> + catalogChanged Stream
                          |
        +-----------------+------------------+
        v                 v                  v
  ProjectListCubit  SessionListCubit  PluginManagementCubit
        |                 |                  |
        |  each exposes the rescan state; the|
        |  lists refresh after durable commits|
        v                 v                  v
  project list      session list +      Settings > Harnesses
                    split-view pane

  Widgets watch their cubit and dispatch intents to it. No widget holds
  the service stream, and no widget calls the service directly.
```

No widget subscribes to `CatalogRescanService`. Each surface's existing cubit
surfaces the rescan state through its own state and exposes the intent methods
the screen dispatches (`startCatalogScan()`, `cancelCatalogScan()`,
`dismissCatalogScan()` on the two list cubits; `startCatalogScanFor(pluginId)`
on `PluginManagementCubit`). The list cubits additionally subscribe to
`catalogChanged`, which is a durable catalog fact rather than row lifecycle.
This keeps the shell's Layer-4 boundary intact and puts the list refresh in the
object that already owns refreshing.

A dedicated `CatalogRescanCubit` was considered and rejected: the two list
surfaces must refresh themselves after a durable commit, which only their own
cubits can do, so a fourth cubit would add an object without removing any wiring.

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
`runtimeState.isRoutable` is true, and issues one `POST /plugin/import` per
harness. A harness the bridge reports as unavailable answers `503` and a harness
it does not know answers `404`; in the fan-out both are skipped silently, because
a harness that cannot import is not an error the user asked about.

`cancel()` issues one `DELETE /plugin/import` per id in
`CatalogRescanRunning.pluginIds`, because the route cancels exactly one plugin
per call.

### A harness joins the rescan on dispatch, not on acknowledgement

`RelayHttpApiClient` can complete a request with `TimeoutException` or
`RelayResponseLostException` (`relay_client.dart:172, 491, 570`) **after** the
POST or DELETE was already delivered. Membership is therefore recorded when the
request is dispatched, not when it is acknowledged:

| Outcome of the start request | Effect on `pluginIds` |
|---|---|
| Accepted | stays |
| `404` or `503` | removed; the harness cannot import |
| Any other explicit rejection | removed and counted as failed |
| Timeout or lost response | **stays**; the import may well be running |

A harness leaves the set on its own terminal SSE event. A start whose response
was lost therefore still renders progress and still reaches a terminal state,
instead of being written off as failed while the bridge imports.

This is deliberately a membership rule rather than a third "uncertain" result
type. The only case the rule does not settle is a lost response for a request
that genuinely never arrived: that harness stays in `pluginIds` with no progress
until the connection resets the state to idle, which is a bounded, self-clearing
outcome and not worth a new result variant across two layers.

### State

```text
sealed CatalogRescanState
  CatalogRescanIdle()
  CatalogRescanStarting({ Set<String> pluginIds })
  CatalogRescanRunning({ String activePluginName, int sessionsSeen,
                         Set<String> pluginIds })
  CatalogRescanSucceeded({ int harnessCount, CatalogRescanCounts counts })
  CatalogRescanPartlyFailed({ int succeededCount, int failedCount })
  CatalogRescanFailed({ int harnessCount })
  CatalogRescanUnsupported()

sealed CatalogRescanCounts
  CatalogRescanDelta({ int newProjects, int newSessions })
  CatalogRescanTotals({ int projects, int sessions })

sealed CatalogRescanStartResult          // returned by start(pluginId)
  CatalogRescanStartAccepted()
  CatalogRescanStartNotImportable()
  CatalogRescanStartUnsupported()
  CatalogRescanStartFailed({ ApiError cause })
```

Separate variants rather than a single state with nullable fields, so a mixed
outcome across N harnesses is representable and a half-populated one is not.
`CatalogRescanPartlyFailed` deliberately carries no counts: the row reports the
failure, and a partial count would invite the reader to trust it as the whole
result.

Neither failure variant carries free text. `CatalogImportFailed.message` is the
bridge's `error.toString()` and is not privacy-bounded, so it is never lifted
into client state where a widget could render it.

`CatalogRescanStartResult` exists so a **targeted** rescan can report back to the
card that asked for it. `PluginManagementCubit` holds the latest result per
plugin id, mirroring the `Map<String, PluginInstallProgress>` it already keeps
for installs, so the rejection lands on the harness the user selected rather than
in the shared aggregate row. The fan-out ignores the result and keeps its silent
skip.

`CatalogRescanStartFailed` retains the repository's `ApiError` as a typed cause,
and the service logs it locally with the original error and stack trace. A
transport, authentication, or decoding failure may never have reached the bridge
at all, so pointing the user at the bridge log would diagnose nothing. Only
bounded presentation text is rendered; the cause exists for the local log, not
for the card.

### The rescan operation

Four review rounds produced rules that composed badly because the service had no
explicit notion of *which run* it was tracking. Everything below follows from one
definition instead.

An **operation** is the set of harness ids the service is currently tracking,
plus whether this client saw the whole thing. It is `owned` when this client
dispatched every member's start, and `observed` when the service learned about it
from `GET /plugin/import` on connect or from an unsolicited progress event.

| Event | Effect on the operation |
|---|---|
| A start is dispatched while idle or terminal | Cancel any pending clear timer, clear the retained progress map, open an `owned` operation containing that harness |
| A start is dispatched while an operation is live | **Join** it: add the harness to the members. The map is not cleared and the run in flight is not disturbed |
| A start joins an `observed` operation | The operation stays `observed`; this client still did not see the rest of it |
| Non-terminal progress arrives for a harness that is not a member, while idle | Open an `observed` operation containing that harness |
| Non-terminal progress arrives for a member | Update the map; publish `CatalogRescanRunning` |
| A terminal event arrives for a member | Record it; the member is settled |
| Every member has settled | See the settlement table below |
| Cancel | `DELETE` for every member id, whether the state is `Starting` or `Running`; close the operation |
| Connection lost, or the active bridge changes | Close the operation, clear the map, cancel the timer |
| Connection established or restored | Seed an `observed` operation from `GET /plugin/import`, keeping only `CatalogImportEnumerating` and `CatalogImportCommitting` and discarding every terminal status |

Settlement:

| Operation | Published state | Then |
|---|---|---|
| `owned`, all members succeeded | `CatalogRescanSucceeded` | cleared to idle after 4s |
| `owned`, some members failed | `CatalogRescanPartlyFailed` | held until dismissed |
| `owned`, all members failed | `CatalogRescanFailed` | held until dismissed |
| `observed` | `CatalogRescanIdle` immediately | no summary is claimed |

Every observed `CatalogImportCompleted` with one or more published project or
session rows announces `catalogChanged`, including a terminal event that arrives
after this client already closed a cancelled row. The automatic hydration
shortcut reports zero rows without catalog publication, so it does not displace
an ordinary list read. Each list cubit records a signalled commit as dirty and
refreshes from a forced fresh snapshot; a second completion while that read is
in flight produces one trailing snapshot. The dirty revision is consumed only
when a snapshot applies, so an older overlapping read cannot overwrite imported
rows. A failed snapshot stays pending until a later ordinary, reconnect, or
staleness read applies; a stale superseded read cannot rearm it. A forced
failure that preempts a full-screen load owns the terminal error, and an
explicit pull follows the newer read's outcome.

An observed run still surfaces imported sessions because it receives the same
global completion event. A run that finishes while disconnected has no live
terminal event to consume; the existing reconnect refresh reads the durable
catalog instead.

Why `observed` claims nothing: after a reconnect the service knows only which
harnesses were still enumerating. A harness that completed or failed while the
connection was down appears in `latestStatuses` as a terminal status that is
discarded, and the client cannot tell whether it belonged to this run, the
previous one, or bridge-startup hydration, because `latestStatuses` carries no
operation identity and no grouping. Publishing a success from that partial
membership would understate the counts and could hide a failed harness behind an
authoritative "Rescan complete".

The 4s clear applies to success only, and is cancelled by any new start or reset.
`CatalogRescanPartlyFailed` and `CatalogRescanFailed` persist until dismissed: a
diagnostic the user did not get to read is worse than a row that outstays its
welcome.

Since a targeted start joins rather than replaces, the Settings cards need no
cross-harness disabling. Each card is disabled only while that harness is itself
a member, and starting a second harness while a first is importing simply widens
the same operation.

This is deliberately the whole **service** model: no generation counters, no
request fences, and no stale-generation tracking inside
`CatalogRescanService`. `PluginManagementService` needs that machinery because
it reconciles mutations against a versioned snapshot token; the list cubits need
small independent guards because they apply asynchronous catalog snapshots.

Because the service owns the operation, two mounted hosts always render the same
row for the same duration, and revisiting a list after a rescan finished shows
nothing rather than replaying a stale success.

## Compatibility

- `CatalogImportCompleted` gains a single **nullable** `newItems` object:
  `CatalogImportNewItems({required int projects, required int sessions})`.
  One optional group rather than two independently nullable ints, so
  "delta known" and "delta absent" are the only two representable cases.
- Every package using `json_serializable` in this repository configures
  `include_if_null: false`, so an older bridge simply omits the key and a newer
  client decodes it as `null`. Nullable is required rather than a zero-valued
  default: defaulting would make an older bridge report `No new sessions` after a
  rescan that in fact imported a hundred sessions.
- A newer bridge talking to an older client is unaffected: the added key is
  ignored by the older decoder.
- No new route, no route signature change, and no change to either existing
  request body.
- **`/plugin/import` does not exist on every supported bridge.** It shipped in
  `v1.6.0` (PR #488), while the owner-approved compatibility baseline is
  `>= v1.4.0`. A `v1.4.x` or `v1.5.x` bridge is a supported peer with no import
  route at all, so the deep pull would otherwise perform its soft refresh and
  silently do nothing.

  `/plugin/management` is **younger still**: its first public tag is `v1.7.0`.
  `PluginRepository.getManagement()` maps a `404` there to
  `PluginManagementLoadResultUnsupported` (`plugin_repository.dart:14-20`), so on
  a `v1.4`-`v1.6` bridge the harness source yields no ids at all and a fan-out
  would send zero requests. `CatalogRescanUnsupported` is therefore published
  directly whenever the management snapshot is unsupported, without waiting for a
  `404` that would never be requested.

  When a snapshot **is** available but **every** harness in a fan-out answers
  `404`, the service publishes `CatalogRescanUnsupported` too and the row says the
  bridge needs updating. A
  targeted start on such a bridge returns `CatalogRescanStartUnsupported` and the
  card says the same. Sniffing the error body to tell a missing route from an
  unknown plugin is deliberately avoided: both mean "this bridge cannot rescan",
  and an all-`404` fan-out is the honest signal for it.
- The `projectionVersion` bump writes new marker rows and leaves the
  `projectionVersion = 1` rows in place. No migration, no backfill, no schema
  change.

## Complexity Budget

New persisted state: **none**.

New wire fields: **one nullable object** on one existing event.

New in-memory mutable parts:

| Part | Owner | Why it must exist |
|---|---|---|
| `Map<String, CatalogImportProgress>` | `CatalogRescanService` | Aggregating several concurrent harness imports into one row requires the latest progress per harness. Cleared only when a start **opens** an operation from idle or terminal, and on every reset to idle. A start that joins a live operation must not clear it |
| `BehaviorSubject<CatalogRescanState>` | `CatalogRescanService` | The published row state, seeded so a late subscriber renders correctly |
| `StreamController<void>` | `CatalogRescanService` | Announces each nonzero `CatalogImportCompleted` as a durable catalog change, even if the progress row was already cancelled and closed |
| `CompositeSubscription` | `CatalogRescanService` | SSE plus connection-status subscriptions, matching `PluginManagementService` |
| `Timer?` | `CatalogRescanService` | The 4s success clear. Owned here, not by the row, so two mounted hosts cannot run disagreeing timers. Never armed for a failure state |
| `bool _disposed` | `CatalogRescanService` | Module convention for `Disposable` services |
| `bool _deepArmed` | `PregoSliverRefreshControl` | The refresh control reports pull distance continuously but fires `onRefresh` once; the threshold state at release must survive that one frame |
| One state subscription and field each | `ProjectListCubit`, `SessionListCubit`, `PluginManagementCubit` | The shell's Layer-4 boundary: widgets render cubit state rather than holding a service stream |
| Durable-change subscription plus request and dirty revisions | `ProjectListCubit`, `SessionListCubit` | Each list cubit owns its post-commit snapshot ordering |
| `bool _recoverySeeded` | `CatalogRescanService` | Marks the live operation `observed` rather than `owned`, so only a fully-seen run reports a terminal summary. Set when an operation opens from the recovery `GET` or from unsolicited progress; cleared when a start opens a new operation and on every reset. A join leaves it untouched, because joining an `observed` run does not make this client the observer of its earlier members |
| `Map<String, CatalogRescanStartResult>` | `PluginManagementCubit` | Per-card targeted-start results, mirroring the `Map<String, PluginInstallProgress>` the cubit already keeps |

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
- **No generation or fence machinery in `CatalogRescanService`.** It only
  publishes durable completion facts. The two list cubits keep their own small
  request and dirty-revision guards because they alone own list snapshots.
- **No third "uncertain" mutation result.** A dispatch-based membership rule
  closes the lost-response hole without a new result variant threaded through
  the API and repository layers.
- **No fourth `CatalogRescanCubit`.** The two list cubits must refresh
  themselves on success, so a dedicated cubit would add an object without
  removing any wiring.
- **No client-side sanitizer for `CatalogImportFailed.message`.** The field is
  simply never lifted into client state. Sanitizing at the consumer would still
  have carried the raw string over the wire.
- **No new bridge event for post-import list invalidation.**
  `CatalogRescanService` converts the existing global completion progress into
  its client-local `catalogChanged` stream, and the list cubits already own their
  silent snapshots.
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
| A post-commit list snapshot fails and no later list trigger arrives | Imported rows stay unseen until a later refresh | Accepted. The dirty completion revision is retained and the next ordinary, reconnect, or staleness snapshot that applies re-arms it; no autonomous retry loop is added for this low-frequency recovery path. |
| A failure row names no cause | The user must open the bridge log to learn why a harness failed | Accepted. `CatalogImportFailed.message` is unbounded `error.toString()`; a vaguer row is the honest trade until a producer-side sanitization boundary exists |
| A lost response for a start that never arrived | That harness stays in `pluginIds` with no progress until the connection resets | Accepted. Bounded and self-clearing; a third result type across two layers is not worth it |
| A rescan interrupted by a disconnect reports no summary | The user sees progress resume and the lists refresh, but no "Rescan complete" line for that run | Accepted deliberately. The alternative is claiming a total the client cannot vouch for; the lists, which are what the user actually came for, are still correct |

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
| Compatibility | One run against a bridge that omits `newItems` | Proves the totals fallback rather than a false `No new sessions` |
| Recovery | One reconnect against a bridge holding terminal statuses | Proves the recovery read discards them instead of announcing a stale success |
| Freshness | One rescan that genuinely imports a new session, observed in the list without a second manual refresh | The whole point of the feature; a committed import raises no list invalidation, so the post-success refresh is the only thing making the new row appear |
| Compatibility | One run against a supported bridge older than `v1.6.0`, which has no `/plugin/import` at all | Proves the gesture reports an unsupported bridge instead of silently doing nothing |
| Recovery | One disconnect mid-rescan, reconnect, and settle | Proves the recovered run refreshes the lists and claims no summary |
| Setup state | One setup-blocked harness on Settings to Harnesses | Proves `Rescan` is not offered as a tappable no-op for a harness the bridge will reject |

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
- A privacy-safe mapping for `CatalogImportFailed.message`. The right fix is a
  bounded failure reason at the producer in `CatalogImportService._run`, keeping
  the original error and stack trace in the local bridge log. Until that exists
  the row reports a bounded failure and names the log; this series does not
  change the producer, and no client code renders the field.

## Delivery Rules

- The series has exactly eight steps.
- Every step updates `TRACKER.md` with its base, actual changed-line count,
  verification, review outcome, and PR link.
- Tests and analysis run only for the packages a step touches. CI owns the full
  matrix.
- `architecture-plan-review` reviewed this plan and rejected the first revision;
  all ten findings were applied directly and are recorded in `TRACKER.md`.
- Run `architecture-implementation-review` on steps 3, 4, 5, and 6. Step 5 is
  included unconditionally: it adds a new shared production component and moves
  which owner drives the split-view pane's scroll, which is an architecture
  boundary regardless of how much of its API is a straight extraction. Steps 2,
  7, and 8 do not qualify.
- Step 8 moves `.plan/active/catalog-rescan/` to
  `.plan/completed/catalog-rescan/` only after the recorded L3 matrix passes.

## Fixed PR Series

| Step | Exact PR title | Changed-line target |
|---|---|---:|
| 1/8 | `🌱 [catalog-rescan] Plan client-triggered catalog rescan [step 1/8]` | 950-1,100 (`PLAN.md`) |
| 2/8 | `🌱 [catalog-rescan] Re-hydrate stale plugin catalogs [step 2/8]` | 20-60 |
| 3/8 | `⚙️ [catalog-rescan] Report new items from a catalog import [step 3/8]` | 350-600 |
| 4/8 | `⚙️ [catalog-rescan] Add the client catalog rescan service [step 4/8]` | 700-1,050 |
| 5/8 | `⚙️ [catalog-rescan] Add a second stage to pull-to-refresh [step 5/8]` | 350-600 |
| 6a/8 | `⚙️ [catalog-rescan] Route scan state through the list cubits [step 6a/8]` | 450-750 |
| 6b/8 | `⚙️ [catalog-rescan] Show the catalog scan in the lists [step 6b/8]` | 500-800 |
| 6c/8 | `🌿 [catalog-rescan] Scan one harness from Settings [step 6c/8]` | 350-600 |
| 7/8 | `🌱 [catalog-rescan] Reconcile catalog rescan regression docs [step 7/8]` | 80-160 |
| 8/8 | `🌱 [catalog-rescan] Verify and retire the catalog rescan plan [step 8/8]` | 60-140 |

Step 5 is `⚙️` rather than `🌿` because it extracts a new shared component and
moves the split-view pane onto it, rather than adding a parameter to one widget.

Step 6 is delivered as three sub-steps rather than one PR, split by layer and
surface so none exceeds the size cap. The denominator stays 8: these are one
step's worth of scope, not three new steps.

- **6a** is `module_core` only — the two list cubits gain the scan state, the
  intent methods, and the refresh on leaving a live operation. Nothing renders,
  so it is reviewable as pure state.
- **6b** is the row widget and the three list hosts, which is where the feature
  first becomes visible.
- **6c** is the Settings action, whose per-harness result and enablement rules
  are independent of the aggregate row.

Step 1's target is measured against `PLAN.md` alone. Both files are new, so the
combined numstat counts every line of `TRACKER.md` too — including its review
records and verification log, which grow with each review round rather than with
scope. Budgeting the combined figure would mean widening the target whenever
review documentation grew, which measures nothing. The delivered scope of step 1
is the plan document; the combined total is recorded in `TRACKER.md` as
information only.

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
  `CatalogRescanIdle` on disconnect and on an active-bridge change; clear the
  retained progress map only when a start opens an operation and on every reset,
  never on a join; arm the 4s clear
  for `CatalogRescanSucceeded` only; record membership on dispatch per the
  table above; select harnesses by `runtimeState.isRoutable`; never lift
  `CatalogImportFailed.message` into state; and expose
  `ValueStream<CatalogRescanState>`, `startAll()`, `start(pluginId)`,
  `cancel()`, and `dismiss()`. `start(pluginId)` returns a typed
  `CatalogRescanStartResult`; publish `CatalogRescanUnsupported` when every
  harness in a fan-out answers `404`; and let a recovery-seeded rescan resolve
  to `CatalogRescanIdle` rather than to a terminal summary.
- Leave `sse_event.dart` and `sse_event_tracker.dart` untouched.
- Run `module_core`'s build runner and commit the regenerated
  `lib/src/di/injection.config.dart`. `@lazySingleton` alone registers nothing:
  analysis still passes because `getIt<CatalogRescanService>()` resolves
  dynamically, so a missing factory would not surface until step 6 fails at
  runtime.
- Tests: aggregation across two concurrent harnesses; all seven states including
  a mixed success/failure fan-out; the older-bridge payload with `newItems`
  omitted; a two-harness success summing both deltas rather than reporting one;
  a two-harness success where one omitted `newItems` falling back to summed
  totals; a reconnect whose `GET` holds only terminal statuses producing no
  row; a reconnect whose `GET` holds an in-flight status producing a running
  row; a disconnect clearing an active rescan; a fan-out where one harness
  answers `503`; cancel issuing one `DELETE` per running harness; a **second
  sequential rescan** proving the previous run's terminal entries do not leak
  into the new aggregate; a failure state surviving well past 4s while a
  success clears; and a start whose response is lost still reaching a terminal
  state from SSE; a fan-out where every harness answers `404` publishing
  `CatalogRescanUnsupported`; a dispatched start publishing `CatalogRescanStarting`
  before any progress arrives; and a recovery-seeded rescan settling to idle with
  no summary while still refreshing; an unsolicited progress event opening an
  observed operation from idle and refreshing the lists when it closes; a
  targeted start joining a live operation instead of clearing it; a cancel while
  `Starting` issuing a `DELETE` per dispatched harness; a second rescan begun
  inside the previous success's 4s window not being reset by the stale timer;
  an unsupported management snapshot publishing `CatalogRescanUnsupported`
  without issuing any request; and a `CatalogRescanStartFailed` retaining its
  `ApiError` cause and logging it locally.

### Verification

- targeted `module_core` service and repository tests
- `dart analyze --fatal-infos` from `client/module_core`
- architecture implementation review

## Step 5/8 - Add A Second Stage To Pull-To-Refresh

### Scope

- Add `PregoSliverRefreshControl` to `module_prego`: wraps
  `CupertinoSliverRefreshControl`, owns the `1.6 x triggerDistance` threshold,
  the caption selection, and the dispatch of both callbacks.
- `PregoGlassScaffold` composes it behind a new optional `deepRefresh`, and
  asserts that `deepRefresh` requires `onRefresh`, matching the existing
  `scrollable`/`onRefresh` assertion.
- `SessionListPanel` replaces its bare `CupertinoSliverRefreshControl` with
  `PregoSliverRefreshControl` **and** takes an optional `deepRefresh` parameter,
  so the pane gets stage 2 without any threshold logic in `client/app`. The
  parameter is introduced here, defaulting to null, and step 6 supplies it.
- Render the caption under the existing indicator only once the pull passes the
  soft trigger, so an ordinary pull is visually unchanged.
- Widget tests covering: an ordinary pull fires only the soft refresh, a pull
  past the deep threshold fires both, a pull abandoned before the trigger fires
  neither, one pull rescans at most once however far it travels, arming does not
  leak between pulls, the control behaves as the bare Cupertino one with no
  second stage supplied, and the fired caption is visually distinct from the
  invitation.

### Verification

- targeted `module_prego` widget tests
- `dart analyze --fatal-infos` from `client/module_prego` and `client/app`
- architecture implementation review

## Step 6/8 - Surface Catalog Rescan In The App

Delivered as 6a, 6b, and 6c. The scope and verification below are the
**aggregate** of all three; the sub-step that owns each part is marked, so a
reviewer of one PR can see what belongs to it.

- **6a** owns the two list cubits' subscription, intents, and post-scan
  refresh, plus its module_core verification.
- **6b** owns the row widget, the three list hosts, and their `app_en.arb`
  resources, plus the widget tests for the row states.
- **6c** owns `PluginManagementCubit`'s subscription and
  `startCatalogScanFor(pluginId)`, the Settings action, its enablement and
  rejection, and its resources.

### Scope

- `ProjectListCubit`, `SessionListCubit`, and `PluginManagementCubit` each
  subscribe to `CatalogRescanService`, surface the rescan state through their
  own state. The two list cubits expose `startCatalogScan()`,
  `cancelCatalogScan()` and `dismissCatalogScan()`; `PluginManagementCubit`
  exposes `startCatalogScanFor(pluginId)`, which is 6c's, because only a
  targeted start needs a per-harness result. The two list cubits additionally
  treat each `catalogChanged` emission as a dirty durable commit and force a
  fresh silent snapshot. Their request generation prevents an older response
  from overwriting that snapshot; a second commit in flight produces one
  trailing read, and a failed read remains dirty for the next ordinary,
  reconnect, or staleness refresh.
- The aggregate rescan row widget in `client/app/lib/core/widgets/`, beside the
  shell's other cross-feature widgets, with its seven presentations. It renders
  the state it is given, owns no timer, and renders no bridge-supplied text.
- Project list, full-screen session list, and split-view pane: supply
  `deepRefresh` from the cubit's `startCatalogScan()`, and render the row as the
  sliver at index 0 in place of the soft-refresh indicator while a rescan is
  running.
- Settings to Harnesses: the per-harness `Rescan` action in
  `_HarnessControlCard`, calling `startCatalogScanFor(pluginId)`, enabled only for a
  harness whose `runtimeState.isRoutable` is true and disabled while that
  harness is itself a member of the live operation; a targeted start joins that
  operation rather than replacing it, so no cross-harness disabling is needed.
  The typed `CatalogRescanStartResult` is held
  per plugin id by `PluginManagementCubit` and rendered on that card, so a
  targeted `503`, `404`, or unsupported-bridge answer lands on the harness the
  user selected instead of the shared row.
- New `app_en.arb` resources for both captions, the seven row states, the delta
  and totals wordings, the `No new sessions` case, the partly-failed wording, the
  bounded failure line naming the bridge log, and the Settings action with its
  semantics label and its rejection message.
- Widget and cubit tests: all seven row states; the totals fallback; cancel;
  dismiss; the Settings action's enablement rules and its targeted rejection;
  that committed imports produce a post-commit list snapshot without an older
  read overwriting it, a second commit gets a trailing snapshot, a failed
  snapshot remains dirty for a later refresh, and no test fixture's
  `CatalogImportFailed.message` reaches a rendered string.

### Verification

- targeted `client/app` widget tests
- `dart analyze --fatal-infos` from `client/app`
- `flutter gen-l10n` output committed
- architecture implementation review

## Step 7/8 - Reconcile Regression Docs

### Scope

- `docs/regression/projects-and-sessions.md`: record the client-triggered
  rescan, the two-stage pull across all three hosts, the aggregate progress row
  and its terminal states, the post-success list refresh, failure rows
  persisting until dismissal, cancellation, new-item reporting with its
  older-bridge fallback, and the recovery read discarding terminal statuses.
- `docs/regression/plugin-setup-and-lifecycle.md`: record the per-harness
  `Rescan` action, its `isRoutable` enablement rule, and its targeted rejection.
- Record the required plugin, platform, compatibility, recovery, freshness, and
  setup-state matrix in both.

### Verification

- `git diff --check`
- documentation only in the diff
- levels and matrix match this plan

## Step 8/8 - Verify And Retire

### Scope

- Run the recorded L3 matrix, including both ownership branches, the two-harness
  mixed-outcome run, the older-bridge compatibility run, the reconnect recovery
  run, the freshness run, and the setup-blocked harness run.
- Record the result, and any explicitly accepted reduction, in `TRACKER.md`.
- Move `.plan/active/catalog-rescan/` to `.plan/completed/catalog-rescan/` once
  that coverage passes.
- Close or update issue #961 with the outcome.

### Verification

- every recorded matrix entry has a pass, a blocked reason, or an accepted
  reduction
- plan and tracker agree
- `git diff --check`
