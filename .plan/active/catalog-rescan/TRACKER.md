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
| Terminal state | Sealed variants summarising the whole fan-out | One `pluginName` could not describe two harnesses finishing differently |
| Terminal lifetime | Owned by `CatalogRescanService`, not the row | Two mounted hosts would otherwise run disagreeing 4s timers, and a revisit would replay a stale success |
| Auto-clear scope | Success only; failures persist until dismissed | A diagnostic the user did not get to read is worse than a row that outstays its welcome |
| Post-success refresh | Both list cubits run their existing silent refresh | A committed import raises no list invalidation, so the row would otherwise announce new sessions over a stale list |
| Failure text | Never lifted into client state | `CatalogImportFailed.message` is the bridge's unbounded `error.toString()` |
| State routing | Through `ProjectListCubit`, `SessionListCubit`, `PluginManagementCubit` | Keeps the shell's Layer-4 boundary and puts the refresh in the object that already owns refreshing |
| Fan-out membership | Recorded on dispatch, not acknowledgement | `RelayResponseLostException` and timeouts can fire after the request landed |
| Harness predicate | `runtimeState.isRoutable` | `isEnabled` is true for `blocked` and `failed`, which the bridge rejects with `503` |
| Counts reduction | Summed across harnesses; delta only if every harness reported one | A delta missing a harness's contribution would understate the result while reading as authoritative |
| Dispatched-but-silent phase | Its own `CatalogRescanStarting` variant | A single running state carrying `activePluginName` and `sessionsSeen` would have to invent both before the first progress event |
| Older bridges | `CatalogRescanUnsupported` when every harness answers `404` | `/plugin/import` shipped in v1.6.0 but the baseline is `>= v1.4.0`, so supported peers exist with no route |
| Recovered rescans | Resolve to idle, never to a terminal summary | `latestStatuses` has no operation identity, so a recovered run cannot honestly claim a total |
| Targeted rejections | Typed `CatalogRescanStartResult` held per plugin id by `PluginManagementCubit` | The aggregate row cannot say which card was rejected |
| Completion wording | New items, with a totals fallback | Reporting 193 totals after a no-op rescan would be actively misleading |
| New-count transport | One nullable `CatalogImportNewItems` object | Two independent `int?` fields make `{5, null}` representable and meaningless |
| Recovery read | Seed only from non-terminal statuses | `latestStatuses` retains terminal statuses forever |
| Connection lifetime | Reset to idle on disconnect and bridge change | Makes generation and fence machinery unnecessary at this scale |
| Non-gesture twin | Per-harness action on Settings to Harnesses | Required for screen readers and desktop; user chose it over an app-bar item |
| Fan-out | One `POST` per routable harness, one `DELETE` per running harness | Both routes address exactly one plugin per call; no wire change |
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
| Authorship tracking of who started a rescan | Rejected | The SSE event is global by design; cross-surface visibility is correct. `_recoverySeeded` is not authorship: it records whether *this* client observed the run from its start, which is what licenses claiming a total |
| Client polling of `GET /plugin/import` | Rejected | One filtered read on connect and reconnect is sufficient |
| Generation or request-fence machinery | Rejected | Resetting to idle on disconnect removes the need |
| A second `PluginRepository.getManagement()` read | Rejected | `PluginManagementService.snapshots` already maintains, refreshes, and invalidates that data |
| Persisted last-rescan timestamp and a staleness nudge | Deferred | Plausible follow-up; needs a new persisted field and list affordance to serve a problem the deliberate rescan already solves |
| Removing the hydration marker table, DAO, `CatalogEmptyHydrationPolicy`, and `projectionVersion` | Deferred | They all die together only if a future plan moves automatic import off the marker; removing them now would break first-install hydration |
| A third "uncertain" mutation result | Rejected | A dispatch-based membership rule closes the lost-response hole without threading a variant through two layers |
| A dedicated `CatalogRescanCubit` | Rejected | The two list cubits must refresh themselves on success, so a fourth cubit adds an object without removing wiring |
| A new bridge event for post-import list invalidation | Rejected | The list cubits already own a silent refresh and already see the global progress stream |
| A client-side sanitizer for `CatalogImportFailed.message` | Rejected | Sanitizing at the consumer still carries the raw string over the wire; the field is simply not lifted into state |
| A privacy-safe failure reason at the producer | Deferred | The right fix is a bounded reason in `CatalogImportService._run` with the original error kept in the bridge log; out of scope for this series |
| Preserving discarded terminal statuses across a reconnect | Rejected | `latestStatuses` carries no operation identity or grouping, so "belonging to the recovered operation" is not determinable; recovered runs claim no summary instead |
| Sniffing the error body to tell a missing route from an unknown plugin | Rejected | Both mean "this bridge cannot rescan"; an all-`404` fan-out is the honest signal |
| Analytics for rescans | Rejected | Reliability repair for a reported defect, not a product adoption question |

## Open Questions

- [ ] Does `PregoGlassScaffold` have an existing design catalog scenario, or do
  widget tests alone cover the second stage?

## Delivery Steps

| Done | Step | Exact PR title | Changed-line target | State |
|---|---|---|---:|---|
| [ ] | 1/8 | `🌱 [catalog-rescan] Plan client-triggered catalog rescan [step 1/8]` | 1,050-1,250 | In preparation |
| [ ] | 2/8 | `🌱 [catalog-rescan] Re-hydrate stale plugin catalogs [step 2/8]` | 20-60 | Not started |
| [ ] | 3/8 | `⚙️ [catalog-rescan] Report new items from a catalog import [step 3/8]` | 350-600 | Not started |
| [ ] | 4/8 | `⚙️ [catalog-rescan] Add the client catalog rescan service [step 4/8]` | 700-1,050 | Not started |
| [ ] | 5/8 | `⚙️ [catalog-rescan] Add a second stage to pull-to-refresh [step 5/8]` | 350-600 | Not started |
| [ ] | 6/8 | `⚙️ [catalog-rescan] Surface catalog rescan in the app [step 6/8]` | 950-1,400 | Not started |
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
- [x] Run `git diff --check` and plan/tracker consistency validation.
- [x] Commit, push, open the Step 1 PR, and record its URL and change count.

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
- [ ] Clear the retained progress map on every rescan start and every reset.
- [ ] Arm the 4s clear for `CatalogRescanSucceeded` only.
- [ ] Record membership on dispatch; keep a harness on timeout or lost response.
- [ ] Select harnesses by `runtimeState.isRoutable`.
- [ ] Never lift `CatalogImportFailed.message` into client state.
- [ ] Prove aggregation across two harnesses, all seven states including a mixed
  outcome, the older-bridge payload, both reconnect cases, a disconnect, a
  `503` in the fan-out, cancel fanning out one `DELETE` per running id, a
  second sequential rescan not inheriting the previous aggregate, a failure
  surviving past 4s while a success clears, and a lost start response still
  reaching a terminal state from SSE.
- [ ] Run `architecture-implementation-review`.

## Step 5 Checklist

- [ ] Add `PregoSliverRefreshControl` owning arming, captions, and dispatch.
- [ ] Compose it in `PregoGlassScaffold` behind `onDeepRefresh` and assert it
  requires `onRefresh`.
- [ ] Replace `SessionListPanel`'s bare `CupertinoSliverRefreshControl` with it.
- [ ] Leave an ordinary pull visually unchanged.
- [ ] Prove short pull, long pull, and abandoned long pull, in both the scaffold
  and the pane.
- [ ] Run `architecture-implementation-review`.

## Step 6 Checklist

- [ ] Give all three cubits a rescan subscription, state, and intent methods.
- [ ] Refresh both lists on `CatalogRescanSucceeded` and
  `CatalogRescanPartlyFailed`.
- [ ] Build the rescan row in `client/app/lib/core/widgets/` with all seven
  presentations, no timer, and no bridge-supplied text.
- [ ] Wire all three hosts through their cubits; no widget touches the service.
- [ ] Add the per-harness Settings action with `isRoutable` enablement and a
  surfaced targeted rejection.
- [ ] Add every `app_en.arb` resource and commit the generated l10n.
- [ ] Prove the seven row states, the totals fallback, cancel, dismiss, the
  Settings action's enablement and rejection, exactly one list refresh per
  cubit on terminal success, and that no fixture message reaches a rendered
  string.
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
| 7 | The terminal state could not represent an N-harness outcome | Replaced with sealed variants including `CatalogRescanPartlyFailed`; round three extended the set to seven |
| 8 | Nothing stated the rescan state's lifetime across disconnect or bridge change | Lifetime table added; resets to idle, no generation or fence machinery |
| 9 | The rescan row widget's home was unnamed while two features consume it | Named `client/app/lib/core/widgets/` |
| 10 | The delta counts were two independently nullable ints on wire and client | Grouped into one nullable `CatalogImportNewItems` and a sealed `CatalogRescanCounts` |

Three findings rested on facts that contradicted the plan's text; each was
independently verified in the tree before the correction was applied.

## PR Review

### cubic-dev-ai on #1064

One P3 finding on the recorded step-1 changed-line count. Valid: the figure was
captured before the verification-log commit added its own lines. Recomputed from
the merge-base and marked informational, since it counts itself. Applied in
`006ae510a`; thread resolved.

### chatgpt-codex-connector on #1064

Eight findings, all assessed valid and applied. Three rested on facts verified
in the tree first: `startAllowedPluginIds` requires
`accessGate == enabled && slot.startAllowed` (`plugin_runtime.dart:105-108`);
`RelayResponseLostException` is real and fires after dispatch
(`relay_client.dart:172, 491, 570`); and `catalogImportRepository.backendActivity`
feeds only `ChatHistoryActivityListener` (`orchestrator.dart:524-527`), so a
committed import raises no list invalidation.

| Finding | Correction applied |
|---|---|
| Refresh catalogs after a rescan commits | Both list cubits run their existing silent refresh on a terminal success. Without it the row announced new sessions over a stale list — the feature's whole purpose |
| Sanitize import failures before rendering them | Neither failure variant carries free text; the row reports a bounded failure and names the bridge log. A producer-side sanitization boundary is recorded as a named follow-up |
| Keep failure states visible until dismissal | The 4s clear now applies to `CatalogRescanSucceeded` only; this also removed a contradiction between the plan's own presentation and lifetime tables |
| Clear retained progress between rescans | The progress map is cleared on every rescan start and every reset to idle; sequential-rescan coverage added |
| Require architecture review for Step 5 | Step 5 now listed unconditionally alongside 3, 4, and 6 |
| Model lost mutation responses as uncertain | **Partially applied.** Membership is recorded on dispatch and a harness survives a timeout or lost response, which closes the hole. The proposed third "uncertain" result type was declined as machinery across two layers for a bounded, self-clearing case; the residue is recorded as an accepted risk |
| Route rescan actions and state through cubits | All three cubits gain a subscription, state, and intent methods; no widget holds the service stream. A dedicated fourth cubit was considered and rejected in the plan |
| Do not enable Rescan for blocked harnesses | Enablement moved to `runtimeState.isRoutable`, and a targeted rejection is surfaced on the card. The silent `503` skip is now scoped to the fan-out only |

### Second round on #1064

`cubic-dev-ai` raised two more findings, both applied.

| Finding | Correction applied |
|---|---|
| The N-harness counts reduction was never defined | Counts are summed across every succeeded harness; the carrier is a delta only when every succeeded harness reported one, otherwise summed totals. Applied in `8ed1dce81` with two step-4 tests |
| The PR description still quoted the superseded changed-line total | Description updated to the recomputed figure with its per-file split |

Two replies in the first codex round were posted to each other's threads. Both
underlying fixes had landed correctly in the plan; only the routing was wrong.
Corrected replies were posted on both threads, the fully-addressed one was
resolved, and the partially-addressed one was re-opened.

### Third round on #1064

`chatgpt-codex-connector` raised four more findings; three applied in full, one
in part. The one repeat on the still-open lost-response thread was the original
comment resurfacing on an unresolved thread, not a follow-up, so it was not
answered twice.

| Finding | Correction applied |
|---|---|
| Represent the dispatched-before-progress phase | Added `CatalogRescanStarting({pluginIds})`. A single running state would have had to invent `activePluginName` and `sessionsSeen` before any progress arrived, and claim enumeration the client cannot observe |
| Surface unsupported catalog-import routes | Verified: `/plugin/import` shipped in `v1.6.0` while the approved baseline is `>= v1.4.0`, so supported peers genuinely lack it. Added `CatalogRescanUnsupported`, published when every harness in a fan-out answers `404`, plus `CatalogRescanStartUnsupported` for a targeted start. Corrected the false "works against every published bridge" claim |
| Model targeted rejections per harness | Added the typed `CatalogRescanStartResult`, held per plugin id by `PluginManagementCubit` exactly as it already holds `PluginInstallProgress`, so a rejection renders on the card the user selected |
| Preserve missed terminal outcomes during recovery | **Partially applied.** Fixed the harmful half: a recovery-seeded rescan resolves to idle and never publishes a summary, so it can no longer report an authoritative success that hides a failed harness. Declined the proposed fix itself as not implementable — `latestStatuses` carries no operation identity or grouping, so a discarded terminal status cannot be attributed to the recovered run rather than the previous one or bridge-startup hydration. The residue, a run interrupted by a disconnect reporting no summary while its lists still refresh correctly, is recorded as an accepted risk |

## Verification Log

- **Step 1 documentation validation:** `git diff --check` passed; step tokens
  and exact PR titles diffed clean between `PLAN.md` and `TRACKER.md`; plan
  files only in the diff
- **Step 1 changed lines:** 1,248 documentation-only insertions, 0 deletions, from
  `git diff --numstat <merge-base>...HEAD` (informational only; the figure counts
  these verification-log lines, so it cannot independently validate the target)
- **Step 1 review:** `architecture-plan-review` rejected the first revision;
  all ten findings applied directly, recorded above
- **Step 1 PR:** [#1064](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1064)
  open
- **Final disposition:** pending
