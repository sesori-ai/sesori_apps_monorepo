# Client-Triggered Catalog Rescan: Tracker

## Current State

- **Plan slug:** `catalog-rescan`
- **Implementation base:** `main` at
  `7b1ebe9bc629d05b5d104e76cd5dbaa1514d65a2`
- **Series state:** Steps 1/8 to 6e/8 merged; Step 6f/8 open
- **Current step:** release the pull and stop it reporting twice
- **Next action:** land 6f, then reconcile projects-and-sessions.md in step 7
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
| Refresh model | Two-stage pull: soft unchanged, deep fires past `1.8 x triggerDistance` | A rescan boots every enabled harness backend, so it must be deliberate. Raised from 1.6 in 6d: too easy to reach by accident |
| Deep-pull commit | On crossing the threshold, not on release | `CupertinoSliverRefreshControl` fires `onRefresh` on crossing and never on release, so release semantics were unbuildable. Owner decision 2026-08-24 |
| Gesture owner | One `module_prego` `PregoSliverRefreshControl` | Three hosts, only two of which use `PregoGlassScaffold`; the pane must not re-implement thresholds in `client/app` |
| Row weight | Tinted card, distinct from the surrounding tiles | Reads as status rather than content, so it is never mistaken for an openable row |
| Row component | Bespoke tinted card, not `PregoInlineAlertsNotifications` | 6b reused the inline alert to avoid building one; it paints `colors.fgPrimary`, so the row was a near-black slab over a light list. An alert interrupts, this reports |
| Post-fire pull | The control renders nothing at all once the threshold is crossed | The row is already on screen reporting the run, so the spinner and caption narrated it twice |
| Row height | Fixed across every state; the detail line is always rendered | The detail arrives one event after the row, and a line appearing under it moved the list a second time |
| Running detail | The harness and its live session count | A "2 of 3" line goes still during a long single-harness scan, which is when reassurance matters most |
| Copy | "Scan" led, sessions first, projects only in the result | Owner decision 2026-08-24: "rescan" named the mechanism, not the outcome |
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
| Operation model | One explicit `owned`/`observed` operation owns membership, settlement, and the refresh | Four rounds of separately-correct lifetime rules composed badly; the seam was that no run was ever named |
| Second start while running | Joins the live operation | Replacing it dropped the first harness from aggregation and cancellation |
| List refresh trigger | Leaving a live operation, not the terminal variants | An observed run publishes no summary and would otherwise never refresh |
| Pre-v1.7.0 bridges | `CatalogRescanUnsupported` straight from an unsupported management snapshot | `/plugin/management` is v1.7.0; without a snapshot the fan-out sends zero requests, so the all-`404` branch never fires |
| Nothing to fan out to | `CatalogRescanNoHarness` for a loading, failed, or absent snapshot and for one naming no routable harness | The caller is a gesture that has already told the user a scan started; a failed snapshot answers this way until reloaded, so a silent return is a persistent dead end |
| Start failures | `CatalogRescanStartFailed` retains the `ApiError` and is logged locally | A transport or decode failure may never reach the bridge, so its log cannot explain it |
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
| Deriving a legacy harness set from `/plugin` discovery | Rejected | Would add a second harness source and a second routability predicate for the single public release (v1.6.0) that has import but not management, on an auto-updating bridge |
| Analytics for rescans | Rejected | Reliability repair for a reported defect, not a product adoption question |

## Open Questions

- [x] Does `PregoGlassScaffold` have an existing design catalog scenario, or do
  widget tests alone cover the second stage? **Answered in step 5:** the design
  catalog has no scaffold scenario, so `PLAN.md`'s "otherwise widget tests" path
  applies. Eight `prego_sliver_refresh_control_test.dart` cases cover the stage,
  including its two caption phases and the fired label's visual distinction. No
  catalog scenario was added, so no manifest regeneration was needed.

## Delivery Steps

| Done | Step | Exact PR title | Changed-line target | State |
|---|---|---|---:|---|
| [x] | 1/8 | `🌱 [catalog-rescan] Plan client-triggered catalog rescan [step 1/8]` | 950-1,100 (`PLAN.md`) | [PR #1064](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1064) merged |
| [x] | 2/8 | `🌱 [catalog-rescan] Re-hydrate stale plugin catalogs [step 2/8]` | 20-60 | [PR #1071](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1071) merged |
| [x] | 3/8 | `⚙️ [catalog-rescan] Report new items from a catalog import [step 3/8]` | 350-600 | [PR #1074](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1074) merged |
| [x] | 4/8 | `⚙️ [catalog-rescan] Add the client catalog rescan service [step 4/8]` | 700-1,050 | [PR #1085](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1085) merged |
| [x] | 5/8 | `⚙️ [catalog-rescan] Add a second stage to pull-to-refresh [step 5/8]` | 350-600 | [PR #1093](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1093) merged |
| [x] | 6a/8 | `⚙️ [catalog-rescan] Route scan state through the list cubits [step 6a/8]` | 450-750 | Merged |
| [x] | 6b/8 | `⚙️ [catalog-rescan] Show the catalog scan in the lists [step 6b/8]` | 500-800 | [PR #1103](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1103) merged |
| [x] | 6c/8 | `🌿 [catalog-rescan] Scan one harness from Settings [step 6c/8]` | 350-600 | [PR #1113](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1113) merged |
| [x] | 6d/8 | `⚙️ [catalog-rescan] Quieten the scan row and its pull [step 6d/8]` | 400-700 | [PR #1114](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1114) merged |
| [ ] | 6e/8 | `🌿 [catalog-rescan] Report a Settings scan's outcome [step 6e/8]` | 350-600 | Open |
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

- [x] Bump `projectionVersion` to `2` with a comment recording why.
- [x] Leave `projectionVersion = 1` rows in place; add no migration.
- [x] Update only the tests that assert the constant. No test asserts it: the
  literal `1` in `catalog_queries_test.dart` is an arbitrary DAO-level value
  proving exact-match retrieval, not the production constant, so it stays.
- [x] Confirm re-import stays non-destructive: `hidden`, `displayName`,
  `title`, overrides, archive state, and tombstones survive.
- [x] Run targeted bridge tests and `dart analyze --fatal-infos`.

## Step 3 Checklist

- [x] Add `CatalogImportNewItems` and hang it off `CatalogImportCompleted` as
  one nullable field; regenerate.
- [x] Count both from facts already in `_publishCatalog`; add no query or scan.
- [x] Count correctly in both `PluginProjectOwnership` branches.
- [x] Print the delta in `catalog_import_console_listener.dart` when present.
- [x] Prove a first import, a no-op re-import, a partial re-import, both
  ownership branches, and a decode with the key omitted.
- [x] Run `architecture-implementation-review`.

## Step 4 Checklist

- [x] Add the three API methods; give cancel a `pluginId`.
- [x] Classify `404` and `503` as "cannot import", not as failures.
- [x] Declare exactly three collaborators: `PluginRepository`,
  `PluginManagementService`, `ConnectionService`.
- [x] Put `CatalogRescanState` in `services/models/catalog_rescan_state.dart`.
- [x] Pattern-match `SesoriCatalogImportProgress` in the service; leave
  `sse_event.dart` and `sse_event_tracker.dart` untouched.
- [x] Filter the recovery read to non-terminal statuses only.
- [x] Reset to idle on disconnect and on active-bridge change; add no
  generation or fence state.
- [x] Implement the `owned`/`observed` operation model: a second start joins the
  live operation, unsolicited progress opens an observed one, cancel fans out
  over live members whether `Starting` or `Running`, and the map is cleared only
  when leaving idle or terminal.
- [x] Arm the 4s clear for `CatalogRescanSucceeded` only, and cancel it on every
  start and reset.
- [x] Publish `CatalogRescanUnsupported` from an unsupported management snapshot
  without issuing any request.
- [x] Retain the `ApiError` in `CatalogRescanStartFailed` and log it locally.
- [x] Run the `module_core` build runner and commit `injection.config.dart`.
- [x] Record membership on dispatch; keep a harness on timeout or lost response.
- [x] Select harnesses by `runtimeState.isRoutable`.
- [x] Never lift `CatalogImportFailed.message` into client state.
- [x] Prove aggregation across two harnesses, all seven states including a mixed
  outcome, the older-bridge payload, both reconnect cases, a disconnect, a
  `503` in the fan-out, cancel fanning out one `DELETE` per running id, a
  second sequential rescan not inheriting the previous aggregate, a failure
  surviving past 4s while a success clears, a lost start response still reaching
  a terminal state from SSE, an unsolicited progress event opening an observed
  operation and refreshing on close, a targeted start joining a live operation,
  a cancel while `Starting`, a second rescan begun inside the previous success's
  4s window, an unsupported management snapshot, and a retained `ApiError`.
- [ ] Run `architecture-implementation-review`.

## Step 5 Checklist

- [x] Add `PregoSliverRefreshControl` owning thresholds, captions, and dispatch.
- [x] Compose it in `PregoGlassScaffold` behind `deepRefresh` and assert it
  requires `onRefresh`.
- [x] Replace `SessionListPanel`'s bare `CupertinoSliverRefreshControl` with it
  and give the pane an optional `deepRefresh` parameter, so step 6 has somewhere
  to wire the cubit intent.
- [x] Leave an ordinary pull visually unchanged.
- [x] Prove short pull, long pull, abandoned pull, once-per-pull, no-second-stage,
  caption order, and the fired label's visual distinction.
- [ ] Run `architecture-implementation-review`.

## Step 6 Checklist

- [ ] Give all three cubits a rescan subscription, state, and intent methods.
- [ ] Refresh both lists whenever the service leaves a live operation, not only
  on the terminal summary variants.
- [ ] Wire the pane's `deepRefresh` parameter to the cubit.
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

- [ ] Update `docs/regression/projects-and-sessions.md`. Step 3 already recorded
  the totals-versus-delta contract and its absent-delta fallback, so step 7 adds
  the client-facing rescan behavior on top rather than restating it.
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
| Clear retained progress between rescans | The progress map is cleared when a start opens an operation and on every reset to idle; round four scoped this to opening starts only, since a join must not clear it. Sequential-rescan coverage added |
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

### Fourth round on #1064

`chatgpt-codex-connector` raised nine findings; all nine applied. Four of them —
adopting cross-surface rescans, cancelling while `Starting`, a second start
clearing the live run, and a stale success timer resetting a new run — all landed
on the same seam: the service had accumulated lifetime rules across three rounds
without ever naming *which run* it tracked. Rather than add four more rules, the
`Lifetimes owned by the service` section was replaced with an explicit
`owned`/`observed` operation model, which resolves all four plus the recovered-run
refresh gap as consequences of one definition.

| Finding | Correction applied |
|---|---|
| Adopt rescans started by other connected surfaces | Unsolicited non-terminal progress opens an `observed` operation from idle. The plan had already promised cross-surface refresh while the rules made it impossible |
| Cancel harnesses while the rescan is still starting | Cancel fans out over the members of the live operation, whether the published state is `Starting` or `Running` |
| Preserve an active run when another harness starts | A targeted start **joins** the live operation instead of opening a new one; the map is cleared only when leaving idle or terminal |
| Refresh lists when a recovered rescan settles | The refresh is keyed on leaving a live operation, not on the terminal variants, so an `observed` run still surfaces its sessions |
| Cancel the prior success timer before a new rescan | Every start and reset cancels the pending clear timer |
| Handle older bridges without management snapshots | Verified: `/plugin/management` first shipped in `v1.7.0` and a `404` maps to `PluginManagementLoadResultUnsupported`, so the fan-out would have sent zero requests and the all-`404` branch never fired. `CatalogRescanUnsupported` is now published directly from an unsupported snapshot |
| Retain client request failures in the typed result | `CatalogRescanStartFailed` carries the `ApiError` cause and the service logs it locally; rendering stays bounded |
| Regenerate injectable registration for the new service | Verified `client/module_core/lib/src/di/injection.config.dart` exists. Step 4 now runs the build runner and commits its output |
| Add pane callback plumbing before testing the deep pull | Step 5 introduces the pane's optional `onDeepRefresh` parameter so its own test is implementable; step 6 wires it to the cubit |

### Step 4 implementation review on `catalog-rescan-service`

`architecture-implementation-review` rejected the first pass. Both findings were
A2 state-ownership violations where the code diverged from the operation model
the plan had already approved, not disagreements with the model itself. Layering,
the three declared collaborators, the Layer-3 composition with
`PluginManagementService`, and the regenerated DI were all cleared.

| Finding | Correction applied |
|---|---|
| The all-`404` close acted on dispatch-scoped results and could tear down members it never dispatched | Both terminal branches now require `_members.isEmpty`. A `404` or `503` already removes its own harness, so an empty member set is exactly "nothing else is live"; a joining start that is rejected returns its result and leaves the run alone |
| Both unsupported-snapshot paths published over a live operation, leaving a non-live state while members were still tracked — so `dismiss()` cleared them without announcing the close and the lists never refreshed | Those publishes are gated on an empty operation, and liveness now reads `_members`, not the published state. Reachable on a v1.6.x bridge, which has `/plugin/import` but not `/plugin/management` |

A second pass also rejected, with two further A2 findings — both in `_start`'s
post-`await` continuation, both applied with regression coverage:

| Finding | Correction applied |
|---|---|
| `_members.isEmpty` alone is also true when the operation closed *during* the await, so a start whose response resolved late could erase a failure row that must persist and fire a duplicate refresh. Reachable by a relay timeout, or by tapping cancel before the POST returns | The guard is now `_members.isEmpty && _state.value.isLive`; `_openOrJoin` always publishes a live state before dispatch and an unsupported answer is never published over a live operation, so this is true exactly when the dispatch's own operation is still open |
| The bridge-wide `CatalogRescanUnsupported` claim was inferred from a dispatch that need not cover every harness, so one targeted `404` — which the bridge also returns for a *deselected* plugin — told every surface the bridge cannot rescan at all | `_start` takes `coversEveryHarness`, true only from `startAll()`. A targeted rejection is reported solely through its returned result, per `PLAN.md` |

Both of its non-blocking observations were applied too: an active-bridge change
now announces its close like a disconnect does, and the `NonSuccessCodeError`
sniff moved out of the service into a `CatalogImportMutationUncertain` variant,
matching the two sibling mappers that already own transport classification in
the repository. The exhaustive-switch error that fix produced is what proved the
service had been reasoning about transport shapes at all.

The first reviewer also noted two quality points outside its verdict. The row keeping
the name of a harness that had just finished was a real wrong label and is
fixed. The missing value equality on state variants is left alone: `Set<String>`
has no value equality either, so honest `==` would mean a set comparator for a
duplicate-emission nicety.

## Verification Log

- **Step 1 documentation validation:** `git diff --check` passed; step tokens
  and exact PR titles diffed clean between `PLAN.md` and `TRACKER.md`; plan
  files only in the diff
- **Step 1 changed lines:** `PLAN.md` is the budgeted scope and is measured
  against the 950-1,100 target. The combined numstat for both new files is
  recorded below as information only and is deliberately not a budget check
- **Step 1 review:** `architecture-plan-review` rejected the first revision;
  all ten findings applied directly, recorded above
- **Step 1 combined numstat (information only):** `PLAN.md` 988 + `TRACKER.md` 369 = 1,357 insertions, 0 deletions
- **Step 1 PR:** [#1064](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1064)
  merged
- **Step 2 base:** `main` at `116f8fb2c`
- **Step 2 verification:** 33 targeted tests passed —
  `catalog_import_repository_test.dart` (16),
  `catalog_import_service_test.dart` (9),
  `catalog_import_handlers_test.dart` (3),
  `catalog_queries_test.dart` (3), `catalog_import_startup_test.dart` (2);
  `dart analyze --fatal-infos` from `bridge/app` reported no issues
- **Step 2 review:** not architecture-bearing; a constant's value changes no
  boundary, contract, or ownership
- **Step 2 PR:** [#1071](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1071)
  merged
- **Step 3 base:** `main` at `db22f602a`
- **Step 3 changed lines:** 451 of delivered code against merge-base
  `db22f602a5457bd94d4c6d8545fad3ce91f0e58b`, inside the 350-600 target:
  70 production (`catalog_import_console_listener.dart` 26,
  `catalog_import_repository.dart` 14, `catalog_import_service.dart` 4,
  `catalog_import_progress.dart` 26), 216 tests, 165 generated
  (`catalog_import_progress.freezed.dart` 146, `.g.dart` 19).
  `.plan/` and `docs/regression/` are excluded on purpose. Counting them makes
  the figure self-inclusive — the commit that writes this entry changes the
  number it records — which is what forced two corrections on step 1 and one
  here. Excluding them makes the budget measure the delivered change and stay
  stable no matter how much review documentation accrues
- **Step 3 verification:** `dart analyze --fatal-infos` clean on `bridge/app`,
  `shared/sesori_shared`, and `client/module_core`; `shared` full suite 361
  tests passed; bridge catalog suites 41 tests passed
  (`catalog_import_repository_test.dart` 20,
  `catalog_import_service_test.dart` 9,
  `catalog_import_console_listener_test.dart` 4,
  `catalog_import_handlers_test.dart` 3, `catalog_queries_test.dart` 3,
  `catalog_import_startup_test.dart` 2)
- **Step 3 review:** `architecture-implementation-review` **approved** with zero
  findings. It independently confirmed the counting is correct in both
  `PluginProjectOwnership` branches (they converge on one publication loop, so
  neither bypasses the counters), that both counters are bounded by their totals,
  that tombstoned sessions cannot inflate the delta, and that the wire contract
  degrades correctly in both directions. It noted separately, outside review
  scope, that `docs/regression/projects-and-sessions.md` was untouched at the
  time it ran, and judged deferring it to step 7 reasonable because nothing here
  is client-visible. That judgement was wrong and has since been corrected: the
  headless completion line **is** user-visible, so this step now records the
  totals-versus-delta contract and its absent-delta fallback in that document
  and in its L2 Routine entry. Step 7 builds on that rather than restating it
- **Step 3 PR:** pending
- **Step 4 base:** `main` at `669fd0cd0`
- **Step 4 changed lines:** 1,271 of delivered code against merge-base
  `669fd0cd045e5ea8a6740e4f944d0634b0d11939`, over the 700-1,050 target. The
  overage is test weight: 620 of it is `catalog_rescan_service_test.dart`, which
  the operation model needs because every rule it encodes — join, dispatch-time
  membership, observed settlement, the success-only timer — is only observable
  through a scenario. Production is 653 across six files, inside the estimate.
  `.plan/` is excluded so the figure cannot count itself
- **Step 4 verification:** `dart analyze --fatal-infos` clean on
  `client/module_core`; full module suite 1,333 tests passed, including 28 new
  `catalog_rescan_service_test.dart` cases
- **Step 4 review:** `architecture-implementation-review` **rejected** the first
  pass with two blocking A2 findings, both divergences from the approved
  operation model, both applied with regression coverage
- **Step 4 PR:** [#1085](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1085)
  merged
- **Step 5 base:** `main` at `bafa7cd02`
- **Step 5 changed lines:** 427 of delivered code, inside the 350-600 target;
  `.plan/` excluded so the figure cannot count itself
- **Step 5 verification:** `dart analyze --fatal-infos` clean on
  `client/module_prego` and `client/app`; full `module_prego` suite 227 tests
  passed, including 8 new `prego_sliver_refresh_control_test.dart` cases
- **Step 5 review:** `architecture-implementation-review` **approved** with zero
  findings. It confirmed the boundary tightened rather than widened — both hosts
  lost their `cupertino_ui` imports, and `decorate` hands back only the built
  indicator so no host can re-derive gesture state — and that the fire-on-
  crossing correction is architecturally sound. Both of its non-blocking
  observations were applied: `PLAN.md`'s Step 5 scope section still described the
  unbuildable release semantics and would have misdirected step 6, and the new
  design-system file's doc comments carried product vocabulary
- **Step 5 PR:** [#1093](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1093)
  merged
- **Step 6a base:** `main` at `0969f00d6`
- **Step 6a changed lines:** 346 of delivered code, under the 450-750 estimate
  because the cubits reuse their existing refresh rather than adding one
- **Step 6a verification:** `dart analyze --fatal-infos` clean on
  `client/module_core` and `client/app`; module_core 1,349 tests passed
  (6 new cubit cases); app 854 tests passed
- **Step 6a review:** `architecture-implementation-review` **rejected** the first
  pass with three findings, all applied. Two were one real bug: both cubits
  rebuilt their loaded state without `catalogScan`, so it reverted to idle —
  and on the project list the erasing rebuild was the very refresh the scan's
  own `settled` listener fires, which would have wiped the terminal row it was
  fired for. On the session list any session event during a scan reset the
  running row. Fixed by re-deriving from the owner in both paths, the way the
  sibling activity and unseen fields already do. The third: the shared
  `FakeCatalogRescanService` declared the interface without implementing
  `start(pluginId:)` and hid the gap behind `noSuchMethod`, which would have
  turned any future interface addition into a runtime throw in every consumer
  instead of a compile error. Both regression tests were confirmed to fail
  without the fix
- **Step 6a PR:** [#1099](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1099)
  merged
- **Step 6b base:** `main` at `1f12f5cee1`
- **Step 6b changed lines:** 862 of delivered code against a 500-800 estimate,
  of which 207 are generated `app_localizations*.dart`; the hand-written figure
  is 655
- **Step 6b design-system reuse:** the row maps onto
  `PregoInlineAlertsNotifications` rather than adding a bespoke card, so all
  seven presentations are a `switch` returning a record. `AnimatedSize` around
  the row was tried and removed: inside a `SliverToBoxAdapter` it never grew
  past zero height, so the row appears and clears without a size transition
- **Step 6b accessibility choice:** the alert's `onClose` renders an icon-only
  button with no semantic label, so cancel and dismiss both use the labelled
  `secondaryAction` instead. Adding `semanticLabel` to
  `PregoButtonsSolid.iconOnly` would have required copy for all 11 existing
  icon-only call sites across unrelated features and was left out of scope
- **Step 6b dropped guard:** the planned suppression of the soft-refresh
  `LinearProgressIndicator` while a scan runs was removed. On both lists
  `isRefreshing` is raised only by the stale-reconnect path — the pull reports
  through a toast and the scan's own post-settle refresh is silent — so the
  overlap needs a reconnect to land mid-scan and costs one redundant bar
- **Step 6b verification:** `flutter analyze` clean on `client/app` lib and
  test; app 872 tests passed (18 new: 12 row presentations, 6 project-list
  wiring including the two-stage pull)
- **Step 6b review:** `architecture-implementation-review` **approved** with no
  findings. It confirmed the row holds no business logic, that
  `CatalogImportFailed.message` cannot reach it because `CatalogRescanFailed`
  carries only `harnessCount`, that no backend identifier escapes into
  `client/` (`activePluginName` is the management snapshot's display string,
  and `Codex` appears only as an ARB example), and that
  `PregoGlassScaffold`'s `deepRefresh == null || onRefresh != null` assertion
  holds on every host path. It also noted that removing `SessionListPanel`'s
  unused injected `deepRefresh` parameter retires step 5's speculative seam in
  lockstep with its only call site
- **Carried to step 7/8:** `CatalogRescanDelta.isEmpty`
  (`catalog_rescan_state.dart:20`) has had no consumer since step 4 shipped it.
  Delete it unless 6c adopts it
- **Step 6b review comments:** three of four bot findings were valid and fixed
  in `e30a20bb7d`. `startAll()` returned silently for a loading, failed, or
  absent management snapshot and for a snapshot naming no routable harness, so
  a deep pull said a scan had started and then showed nothing — a persistent
  dead end, not a transient one, because a failed snapshot answers that way
  until it is reloaded. Added `CatalogRescanNoHarness`, published under the same
  `_members.isEmpty` guard `unsupported` uses. The row's live region also
  covered the running state, whose `sessionsSeen` changes per enumerated
  session, so a screen reader would have been interrupted once per session
  across a whole scan; it is now scoped to phase and terminal transitions. And a
  counts clause is dropped at zero rather than joined, so a scan finding only a
  new project no longer read `No new sessions in 2 new projects`
- **Step 6b declined finding:** codex asked for
  `docs/regression/projects-and-sessions.md` in this PR, citing the AGENTS.md
  rule. Declined and left unresolved: step 7 owns that reconciliation for
  behaviour 6b and 6c both contribute to, and writing it now means rewriting it
  twice. The staleness window between 6b and step 7 is real rather than
  theoretical, because 6b is what makes scanning user-reachable
- **Step 6b PR:** [#1103](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1103)
  open
- **Step 6c base:** `main` at `d8459ae9cf`
- **Step 6c changed lines:** 451 of delivered code, within the 350-600 estimate
- **Step 6c field ownership:** `scanningPluginIds` is re-read from
  `CatalogRescanService` on every snapshot rebuild, the way `installs` is, so a
  scan a list's pull started still closes the Settings action and reopening the
  screen mid-scan does not hide it. `scanRejections` is carried forward from the
  previous ready state, the way `action` and `authentication` are, because
  nothing outside the cubit holds a rejection the user has not read. The
  regression test for the rebuild was confirmed to fail without both
- **Step 6c dropped intent:** `dismissCatalogScanRejection` was written and then
  removed before commit — it had no caller, since a rejection clears on the next
  attempt on that harness or on leaving the screen, which rebuilds the cubit
- **Step 6c verification:** `flutter analyze lib test` clean on `client/app`;
  `dart analyze --fatal-infos lib test` clean on `client/module_core`; app 890
  tests passed, module_core 1,373 passed (13 new: 6 cubit, 7 widget)
- **Step 6c review:** `architecture-implementation-review` **approved** with no
  architectural findings. It confirmed both writers of `scanningPluginIds` funnel
  through one getter so the stream and rebuild paths cannot diverge, that
  `isRoutable` is the shared model's own getter rather than an eligibility rule
  re-implemented in the shell, and that `CatalogRescanStartFailed.cause` never
  reaches a rendered string. It also caught a real documentation defect this
  commit introduced: inserting `startCatalogScanFor` between `install()`'s doc
  comment and `install()` orphaned that comment. Fixed
- **Step 6c PR:** [#1113](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1113)
  open
- **Step 6c review comments:** both bot findings valid, fixed in `7a4e024ea4`.
  The failed-start line said "Check the bridge log", which contradicts this
  plan's own reason for retaining the `ApiError`: the request may never have
  reached the bridge. Now neutral, because the app has no user-facing log
  viewer either. The lists' failed row still names the bridge log and is
  correct — that one comes from a bridge-side `CatalogImportFailed` event
- **Step 6c doc reversal:** codex asked again for the regression document in the
  same PR, and this time it was right where it was not on 6b. 6c is the last
  implementation step, so nothing written now would be rewritten in step 7.
  `plugin-setup-and-lifecycle.md` was reconciled here, leaving step 7 with
  `projects-and-sessions.md` only
- **Upstream change during 6c:** PR #1106 fixed the catalog refresh ordering
  seam this plan had recorded as an accepted residue, renaming the service's
  `settled` to `catalogChanged` and already updating part of
  `docs/regression/projects-and-sessions.md`. Step 7's scope is therefore
  smaller than the plan text describes and must be re-derived from the file
- **Step 6c declined finding:** a third bot round asked for a connection-epoch
  fence on `startCatalogScanFor`, so a POST pending across a disconnect could
  not overwrite a later retry's rejection. Declined: it needs a disconnect,
  reconnect and retry inside one pending request, and the worst outcome is one
  stale line until the next tap or until Settings is left. Same call the plan
  already recorded for the recovery read
- **Step 6d base:** `main` at `2c3ef6d` (merged forward to pick up 6c)
- **Step 6d origin:** owner feedback from a running build, eight points. Not a
  planned step — the feature worked and looked wrong
- **Step 6d component reversal:** 6b chose `PregoInlineAlertsNotifications` to
  avoid a bespoke card. Wrong component: it paints `colors.fgPrimary`, the
  contrast-inverted foreground, so the row was a near-black slab over a light
  list. Replaced with a tinted card in each state's own colour family. The
  instinct to reuse was right; the component is an interrupt surface and this is
  ambient status
- **Step 6d animation root cause:** starting an `AnimationController` from
  `build` races its own frame, which inside a `SliverToBoxAdapter` leaves the
  row pinned at zero height. This is also why 6b's `AnimatedSize` attempt never
  grew and was removed as unworkable. Driven from `didUpdateWidget` now, and the
  tests pump the extra frame a controller needs before its first tick carries
  elapsed time
- **Step 6d residues:** the overscroll still holds its extent while the finger
  is down, which is scroll physics rather than something the control can cancel
  mid-gesture; the area it holds is simply empty. The toast suppression reads
  the scan state at report time rather than threading a flag through the
  gesture, so a fetch that resolved before the pull crossed 1.8x would still
  raise one toast
- **Step 6d review comments:** three bot findings. Two were defects the polish
  itself introduced and are fixed in `7a75b73be1`: `SizeTransition` only changes
  layout, so the retained card kept its labels and its live action button
  mounted at zero height where a keyboard could still reach them; and the reveal
  ignored the OS reduced-motion preference that the router transitions, the
  message list, the image viewer and `PregoActivityIndicator` all honour through
  `context.isReducedMotion`. Both regression tests were confirmed to fail
  without their fix — the reduced-motion one only after being rewritten, because
  the first version asserted `greaterThan(0)` and `easeOutCubic` is already at
  ~17% one frame in
- **Step 6d toast narrowing:** the third finding was half right and the half it
  got right was a regression: suppressing the refresh toast whenever a scan was
  live also hid *failed* pulls. Now only a success is suppressed. Declined
  tying suppression to the gesture that fired, which needs a flag threaded
  through two stateless session hosts to restore a success confirmation for a
  shallow pull taken during someone else's scan, where a progress row is already
  on screen
- **Step 6e origin:** owner question — does a Settings-started scan indicate
  success? It does not, and the gap is one this plan created. The aggregate row
  is hosted only by the three lists, and `_successVisibleFor` clears a success
  after four seconds, so the outcome of a Settings-started scan was published
  where its user could never reach it. Only start-time rejections showed there;
  a scan that started fine and then failed was equally silent
- **Step 6e approach:** owner chose a popup on completion over hosting the
  aggregate row on Settings or reporting inline on the card
- **Step 6e ownership:** the cubit claims the run at dispatch, before the start
  request resolves, because the run can reach a terminal state while that
  request is still awaiting its own response. A start the bridge refuses drops
  the claim, since the card already reports it; so does a run that ends without
  a terminal state, so a dropped claim cannot attach itself to the next run
- **Step 6e wording reuse:** `catalogScanCountsLine` was lifted out of
  `CatalogScanRow` so the row and the popup cannot describe one scan two ways
- **Step 6e verification:** `flutter analyze lib test` clean on `client/app`;
  `dart analyze --fatal-infos lib test` clean on `client/module_core`; app 897
  tests passed, module_core 1,381 passed (9 new: 6 cubit, 3 widget). The popup
  test was confirmed to fail with the presenter call removed
- **Step 6e review:** `architecture-implementation-review` **approved** with no
  architectural findings. It confirmed `CatalogRescanOutcome` narrows the
  service's eight states to the three a started scan can reach, so
  `scanOutcome: running` is unrepresentable; that `scanOutcome` is carried
  across a snapshot rebuild the way 6a's review required; that Freezed's
  `copyWith(scanOutcome: null)` genuinely clears rather than no-ops, so the
  popup cannot re-fire; and that `catalogScanCountsLine` belongs in
  `core/widgets/` beside its two consumers, since it takes `AppLocalizations`
  and could not move to module_core
- **Step 6e claim leak:** the review traced one path where `_reportsScanOutcome`
  survived its run — on a disconnect `PluginManagementService` emits `loading`
  before `CatalogRescanService` emits `idle`, so the drop sat behind the
  readiness check and never ran. It judged the leak unreachable today and did
  not require a fix, but a regression test reproduced it directly: the claim
  attached to the next run's outcome. Closed by dropping the claim before the
  readiness check
- **Step 6e review comments:** three bot findings, all valid, fixed in
  `2674825bf9`. Two were the same seam — the single `_reportsScanOutcome` flag.
  A second card being refused cleared the only claim while the first harness was
  still running, so that run ended in the silence this step exists to remove;
  and a definite `CatalogImportMutationFailure` settles the operation *before*
  `start()` returns, so membership could not tell a refusal from a run that had
  already finished and been announced, producing both a finished-scan
  announcement and a could-not-start line for one attempt. Replaced with
  `Set<String> _scanClaims`: a refusal removes one harness, an announcement
  spends the set. Both tests confirmed to fail against the old behaviour
- **Step 6e accessibility gap:** the popup is silent to a screen reader — the
  only `Semantics` in `prego_popup_alerts_notifications.dart` is its close
  button — which undercut the step, since a screen-reader user is who this
  surface is for. The outcome is now also sent through
  `SemanticsService.sendAnnouncement`. Declined adding a live region to the
  shared popup component: that fixes every popup in the app and is a
  design-system change with its own call sites, not part of this step. Worth
  doing separately
- **Step 6e PR:** [#1118](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1118)
  open
- **Step 6f origin:** two owner reports from a running build, one root cause.
  The pull's own read reaches the same bridge the scan just put to work, so it
  resolves only when the scan does. That held the list open (below), and it also
  defeated 6d's toast suppression: the guard asked whether a scan was *live* at
  toast time, and by then the row already read "Scan complete", so every deep
  pull confirmed itself on top of the row reporting the same run. The guard now
  asks whether the row is showing anything at all. Failures are still never
  suppressed
- **Step 6f seam fix:** three rounds of findings landed on the same seam — the
  toast guard reading presentation state at completion rather than identifying
  the gesture. The row-based guard failed in both directions: it missed a deep
  pull whose read outlived the row's own four-second clear, and it suppressed an
  ordinary pull taken while an unrelated scan was still reported. Both cubits
  now count the scans they start, and a pull compares that count either side of
  its own refresh. Both cases have tests, each confirmed to fail against the
  row-based guard
- **Step 6f copy:** "Keep pulling to scan all harnesses" named the mechanism
  rather than the outcome. Now "Keep pulling to find new sessions"
- **Step 6f held pull:** after release the list stayed pushed down until the
  scan finished. 6d made the held area empty
  but left the extent: `CupertinoSliverRefreshControl` holds the pull open for
  exactly as long as `onRefresh` runs, and that refresh reaches the same bridge
  the scan just put to work, so it resolved only when the scan did. The control
  now stops waiting the moment the second stage fires; the refresh still runs.
  Test confirmed the list was held 60px down without the fix and 0 with it
- **Final disposition:** pending
