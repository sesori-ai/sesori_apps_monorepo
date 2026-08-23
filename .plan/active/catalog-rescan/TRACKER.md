# Client-Triggered Catalog Rescan: Tracker

## Current State

- **Plan slug:** `catalog-rescan`
- **Implementation base:** `main` at
  `7b1ebe9bc629d05b5d104e76cd5dbaa1514d65a2`
- **Series state:** Step 1/8 in preparation, plan review applied
- **Current step:** publish the plan
- **Next action:** open the Step 1 PR, then Step 2's `projectionVersion` bump
- **Origin issue:** [#961](https://github.com/sesori-ai/sesori_apps_monorepo/issues/961)
- **External overlap:** [#1008](https://github.com/sesori-ai/sesori_apps_monorepo/issues/1008)
  owns Codex live updates; do not address it here

## Confirmed Evidence

- [x] An automatic import with an existing hydration marker publishes
  `completed(0, 0)` and returns without enumerating or starting the plugin
  (`catalog_import_service.dart:101-118`).
- [x] `CatalogImportRepository.projectionVersion` is still `1` and has never
  been bumped since PR #488, so no release has ever invalidated a marker.
- [x] `--import-plugin` uses the headless trigger, sets
  `explicitImportRequested`, and is the only path that bypasses the marker.
- [x] `POST`, `DELETE`, and `GET /plugin/import` and SSE
  `catalog.import.progress` all exist and work; a search for `plugin/import`
  under `client/` and `shared/` returns nothing.
- [x] `DELETE /plugin/import` is a `BodyRequestHandler<CatalogImportRequest, …>`
  and cancels exactly one plugin per call, so cancel needs a plugin id.
- [x] `GET /plugin/import` returns `CatalogImportService.latestStatuses`, which
  retains terminal statuses indefinitely; combined with the hydration
  short-circuit publishing `completed(0, 0)` at every bridge start, an
  unfiltered recovery read would render a stale success row on every connect.
- [x] The two switch arms holding `SesoriCatalogImportProgress` are a
  `sessionId` extractor (`sse_event.dart:36`) and `SseEventTracker`'s no-op arm
  (`sse_event_tracker.dart:103`). Neither is an event dispatch registry.
  `SesoriPluginInstallProgress` sits in both and is still fully consumed by
  `PluginManagementService._onSseEvent`, which is the precedent to copy.
- [x] `SessionListPanel._buildScrollableContent`
  (`session_list_panel.dart:127-145`) builds its own `CustomScrollView` with a
  bare `CupertinoSliverRefreshControl` and does not use `PregoGlassScaffold`.
- [x] An import acquires its plugin lease with `startIfNeeded: true`
  (`plugin_runtime.dart:406`), so a rescan starts the harness backend.
- [x] `CatalogImportCompleted` carries totals, not deltas; both delta facts are
  already available inside `_publishCatalog`.
- [x] The reporter's v1.8.0 explicit import produces a complete catalog
  (`files=193 ... sessions=193`, `noiseExcluded=0`, `missingCwd=0`), so the
  Codex scan itself is healthy.
- [x] `client/app/lib/core/widgets/` already holds the shell's cross-feature
  widgets, so a widget consumed by two features belongs there.
- [x] `client/desktop` hosts no project or session list, so no desktop shell
  work is required.

## Design Decisions

| Decision | Chosen | Rationale |
|---|---|---|
| Refresh model | Two-stage pull: soft unchanged, deep armed past `1.6 x triggerDistance` | A rescan boots every enabled harness backend, so it must be deliberate |
| Gesture owner | One `module_prego` `PregoSliverRefreshControl` | Three hosts, only two of which use `PregoGlassScaffold`; the pane must not re-implement thresholds in `client/app` |
| Progress presentation | One aggregate row | Fixed height; the top of the list never reflows as harnesses finish at different times |
| Row placement | Ordinary sliver at index 0, scrolls with the list | Non-intrusive; a refresh already scrolls to the top, so it is visible when it matters |
| Row home | `client/app/lib/core/widgets/` | Consumed by two features; must not live inside either |
| Terminal state | Five sealed variants summarising the whole fan-out | One `pluginName` could not describe two harnesses finishing differently |
| Terminal lifetime | Owned by `CatalogRescanService`, not the row | Two mounted hosts would otherwise run disagreeing 4s timers, and a revisit would replay a stale success |
| Completion wording | New items, with a totals fallback | Reporting 193 totals after a no-op rescan would be actively misleading |
| New-count transport | One nullable `CatalogImportNewItems` object | Two independent `int?` fields make `{5, null}` representable and meaningless |
| Recovery read | Seed only from non-terminal statuses | `latestStatuses` retains terminal statuses forever |
| Connection lifetime | Reset to idle on disconnect and bridge change | Makes generation and fence machinery unnecessary at this scale |
| Non-gesture twin | Per-harness action on Settings to Harnesses | Required for screen readers and desktop; user chose it over an app-bar item |
| Fan-out | One `POST` per enabled harness, one `DELETE` per running harness | Both routes address exactly one plugin per call; no wire change |
| Stale markers | Bump `projectionVersion` to `2` | The mechanism already exists for exactly this; ships first, independently |

## Rejected And Deferred

| Option | Status | Reason |
|---|---|---|
| Import on every bridge start | Rejected | Boots every enabled harness backend at every launch, the exact cost the durable marker exists to avoid |
| Bulk `import all` route | Rejected | Needs a capability flag or an older-bridge fallback to buy one fewer round trip |
| `catalogImport` management capability | Rejected | A wire change bought only to avoid skipping two status codes |
| Changing either SSE switch arm | Rejected | Both are correct; the service pattern-matches the event itself, as `PluginManagementService` already does |
| Per-harness progress rows | Rejected | User chose the aggregate row |
| Pinned progress row | Rejected | User chose the scrolling row |
| Authorship tracking of who started a rescan | Rejected | The SSE event is global by design; cross-surface visibility is correct |
| Client polling of `GET /plugin/import` | Rejected | One filtered read on connect and reconnect is sufficient |
| Generation or request-fence machinery | Rejected | Resetting to idle on disconnect removes the need |
| A second `PluginRepository.getManagement()` read | Rejected | `PluginManagementService.snapshots` already maintains, refreshes, and invalidates that data |
| Persisted last-rescan timestamp and a staleness nudge | Deferred | Plausible follow-up; needs a new persisted field and list affordance to serve a problem the deliberate rescan already solves |
| Removing the hydration marker table, DAO, `CatalogEmptyHydrationPolicy`, and `projectionVersion` | Deferred | They all die together only if a future plan moves automatic import off the marker; removing them now would break first-install hydration |
| Analytics for rescans | Rejected | Reliability repair for a reported defect, not a product adoption question |

## Open Questions

- [ ] Does `PregoGlassScaffold` have an existing design catalog scenario, or do
  widget tests alone cover the second stage?

## Delivery Steps

| Done | Step | Exact PR title | Changed-line target | State |
|---|---|---|---:|---|
| [ ] | 1/8 | `🌱 [catalog-rescan] Plan client-triggered catalog rescan [step 1/8]` | 850-1,000 | In preparation |
| [ ] | 2/8 | `🌱 [catalog-rescan] Re-hydrate stale plugin catalogs [step 2/8]` | 20-60 | Not started |
| [ ] | 3/8 | `⚙️ [catalog-rescan] Report new items from a catalog import [step 3/8]` | 350-600 | Not started |
| [ ] | 4/8 | `⚙️ [catalog-rescan] Add the client catalog rescan service [step 4/8]` | 700-1,050 | Not started |
| [ ] | 5/8 | `⚙️ [catalog-rescan] Add a second stage to pull-to-refresh [step 5/8]` | 350-600 | Not started |
| [ ] | 6/8 | `⚙️ [catalog-rescan] Surface catalog rescan in the app [step 6/8]` | 700-1,100 | Not started |
| [ ] | 7/8 | `🌱 [catalog-rescan] Reconcile catalog rescan regression docs [step 7/8]` | 80-160 | Not started |
| [ ] | 8/8 | `🌱 [catalog-rescan] Verify and retire the catalog rescan plan [step 8/8]` | 60-140 | Not started |

## Step 1 Checklist

- [x] Record the root cause with exact file and line evidence.
- [x] Record the approved design and mark it closed to reopening.
- [x] Record the complexity budget, naming every new mutable part and every
  deliberately omitted one.
- [x] Record accepted risks with their impact.
- [x] Record the cleanup assessment outcome.
- [x] Record affected regression documents, the required level, and the matrix.
- [x] Fix the eight-step series with exact titles and complexity emoji.
- [x] Run `architecture-plan-review` through a sub-agent and apply valid
  findings directly.
- [ ] Run `git diff --check` and plan/tracker consistency validation.
- [ ] Commit, push, open the Step 1 PR, and record its URL and change count.

## Step 2 Checklist

- [ ] Bump `projectionVersion` to `2` with a comment recording why.
- [ ] Leave `projectionVersion = 1` rows in place; add no migration.
- [ ] Update only the tests that assert the constant.
- [ ] Confirm re-import stays non-destructive: `hidden`, `displayName`,
  `title`, overrides, archive state, and tombstones survive.
- [ ] Run targeted bridge tests and `dart analyze --fatal-infos`.

## Step 3 Checklist

- [ ] Add `CatalogImportNewItems` and hang it off `CatalogImportCompleted` as
  one nullable field; regenerate.
- [ ] Count both from facts already in `_publishCatalog`; add no query or scan.
- [ ] Count correctly in both `PluginProjectOwnership` branches.
- [ ] Print the delta in `catalog_import_console_listener.dart` when present.
- [ ] Prove a first import, a no-op re-import, a partial re-import, both
  ownership branches, and a decode with the key omitted.
- [ ] Run `architecture-implementation-review`.

## Step 4 Checklist

- [ ] Add the three API methods; give cancel a `pluginId`.
- [ ] Classify `404` and `503` as "cannot import", not as failures.
- [ ] Declare exactly three collaborators: `PluginRepository`,
  `PluginManagementService`, `ConnectionService`.
- [ ] Put `CatalogRescanState` in `services/models/catalog_rescan_state.dart`.
- [ ] Pattern-match `SesoriCatalogImportProgress` in the service; leave
  `sse_event.dart` and `sse_event_tracker.dart` untouched.
- [ ] Filter the recovery read to non-terminal statuses only.
- [ ] Reset to idle on disconnect and on active-bridge change; add no
  generation or fence state.
- [ ] Own the 4s terminal clear in the service.
- [ ] Prove aggregation across two harnesses, all five states including a mixed
  outcome, the older-bridge payload, both reconnect cases, a disconnect, a
  `503` in the fan-out, and cancel fanning out one `DELETE` per running id.
- [ ] Run `architecture-implementation-review`.

## Step 5 Checklist

- [ ] Add `PregoSliverRefreshControl` owning arming, captions, and dispatch.
- [ ] Compose it in `PregoGlassScaffold` behind `onDeepRefresh` and assert it
  requires `onRefresh`.
- [ ] Replace `SessionListPanel`'s bare `CupertinoSliverRefreshControl` with it.
- [ ] Leave an ordinary pull visually unchanged.
- [ ] Prove short pull, long pull, and abandoned long pull, in both the scaffold
  and the pane.

## Step 6 Checklist

- [ ] Build the rescan row in `client/app/lib/core/widgets/` with all five
  presentations and no timer.
- [ ] Wire all three hosts.
- [ ] Add the per-harness Settings action with its enablement rules.
- [ ] Add every `app_en.arb` resource and commit the generated l10n.
- [ ] Prove the five row states, the totals fallback, cancel, dismiss, and the
  Settings action's enablement.
- [ ] Run `architecture-implementation-review`.

## Step 7 Checklist

- [ ] Update `docs/regression/projects-and-sessions.md`.
- [ ] Update `docs/regression/plugin-setup-and-lifecycle.md`.
- [ ] Record the level and the full matrix in both.

## Step 8 Checklist

- [ ] Run the recorded L3 matrix including both ownership branches, the
  two-harness mixed outcome, the older-bridge compatibility run, and the
  reconnect recovery run.
- [ ] Record every entry as passed, blocked, or an explicitly accepted
  reduction.
- [ ] Move the plan directory to `.plan/completed/catalog-rescan/`.
- [ ] Close or update issue #961 with the outcome.

## Plan Review

- **Reviewer:** `architecture-plan-review`
- **Date:** 2026-08-23
- **Reviewed scope:** complete `.plan/active/catalog-rescan/`
- **Verdict:** pre-review gate passed; plan **rejected on substance** with ten
  findings. None challenged a user-locked decision.
- **Findings applied:** all ten, directly, without re-review.

| # | Finding | Correction applied |
|---|---|---|
| 1 | Step 4's "stop routing into the ignore arms" bullet was wrong at both targets | Bullet deleted. Both arms stay; the service pattern-matches the event itself, as `PluginManagementService` already does |
| 2 | The claim that the split-view pane hosts `PregoGlassScaffold` was false | Corrected. Gesture moved into a new `module_prego` `PregoSliverRefreshControl`; the pane is now named in Step 5, not only Step 6 |
| 3 | The recovery read would announce stale terminal statuses on every connect | Recovery read filtered to `CatalogImportEnumerating` and `CatalogImportCommitting` only |
| 4 | `cancelCatalogImport()` had no `pluginId` and could not be implemented | Signature corrected; `cancel()` now fans out one `DELETE` per running harness, recorded in the complexity budget |
| 5 | The management-snapshot collaborator and the state's location were undeclared | Both declared: `PluginManagementService.snapshots`, and `services/models/catalog_rescan_state.dart` |
| 6 | The 4s auto-dismiss timer was owned by the row, not the state owner | Moved to `CatalogRescanService`; the row owns no timer |
| 7 | The terminal state could not represent an N-harness outcome | Replaced with five sealed variants including `CatalogRescanPartlyFailed` |
| 8 | Nothing stated the rescan state's lifetime across disconnect or bridge change | Lifetime table added; resets to idle, no generation or fence machinery |
| 9 | The rescan row widget's home was unnamed while two features consume it | Named `client/app/lib/core/widgets/` |
| 10 | The delta counts were two independently nullable ints on wire and client | Grouped into one nullable `CatalogImportNewItems` and a sealed `CatalogRescanCounts` |

Three findings rested on facts that contradicted the plan's text; each was
independently verified in the tree before the correction was applied.

## Verification Log

- **Step 1 documentation validation:** pending
- **Step 1 changed lines:** pending
- **Step 1 PR:** pending
- **Final disposition:** pending
