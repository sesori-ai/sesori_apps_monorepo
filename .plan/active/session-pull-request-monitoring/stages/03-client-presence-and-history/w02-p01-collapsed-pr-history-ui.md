# S03-W02-P01: Render Collapsed PR History and Remove Dead Sync Code

## 0. Metadata

- **ID:** S03-W02-P01
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Worktree:** one dedicated worker worktree for this PR
- **Base branch:** `main`
- **Branch:** `plan/session-pull-request-monitoring/s03-w02-p01-collapsed-pr-history-ui`
- **Wave baseline:** pin the assessed current `main` tip after S03-W01 merges
- **Audited reference:** `e766684e0fdc22256419b7b99691021c9f14732d`
- **Contract-affecting:** Yes — compatibility-only request trigger cleanup debt
  remains after legacy implementation deletion

## 1. Goal and Cohesion

Complete the user-visible feature by keeping the current PR prominent and
placing all prior associated PRs in stable, collapsed mobile history. At the
same final integration barrier, delete the superseded `PrSyncService` facade and
request-era debounce state now that every supported trigger is wired directly
to `PrRefreshDispatcher`. UI, integration proof, compatibility preservation,
and dead-path removal are cohesive as the final cutover/cleanup PR.

## 2. Dependencies and Baseline

- S03-W01-P01 is merged: mobile list/detail presence activates bridge
  scheduling with lifecycle/reconnect safety.
- S02 provides non-null ordered `Session.pullRequestHistory`, change-only SSE,
  direct request/listener dispatcher callers, and immutable archived reads.
- Assess and pin current `main`, focusing on final shared model shape, session
  tile/list keys, localization generation, all `PrSyncService` references, and
  request compatibility markers.
- If any production trigger still relies on behavior owned only by
  `PrSyncService`, route that trigger directly to the existing dispatcher within
  this PR; do not reimplement its old debounce/capability/cache logic.

## 3. Scope

### In Scope

- Keep existing `PrStatusRow` as the immediately visible headline.
- Add focused `PrHistorySection` rendered only for non-empty history.
- Localize the count/header and expand/collapse semantics.
- Collapse history by default and retain expansion by session identity across
  `sessionsUpdated` re-fetches and list reorder/rebuild.
- Render history in bridge-provided descending order without duplicating or
  resorting the headline.
- Style all spacing, typography, color, radius, and affordances with Prego
  tokens; preserve compact/adaptive session-list layout.
- Add mobile widget/accessibility tests for headline/history/archive/no-history,
  text scale, narrow phone, and wide split/adaptive surfaces.
- Add paired fake-source bridge/client integration coverage for project presence
  -> dispatcher/cache -> SSE -> re-fetch -> rendered history.
- Remove `PrSyncService`, its old 30-second debounce/capability/remote-cache/
  active-refresh internals, old composition parameters, and obsolete tests/fakes.
- Preserve or rehome still-valid FK/repository/handler/SSE regression coverage
  under the classes that now own it.
- Retain both `GetSessionsHandler` dispatcher paths and the exact compatibility
  marker on the non-wait path.
- Run the full bridge/shared/mobile/desktop verification matrix.

### Non-Goals

- PR detail screen, browser links, actions, comments, checks detail, or status
  mutation.
- Client-side sorting, deduplication, repository association, or nullable-history
  normalization; S01/S02 make modern history required and authoritative.
- Desktop-only history presentation before shared accessory UI exists.
- Changing headline selection, archive snapshot semantics, adaptive cadence,
  unseen state, push notifications, or request timeout.
- Removing `waitForPrData`, the non-wait old-client fallback, or its marker.
- New schema/shared contract fields or migration.
- Refactoring unrelated session-list visuals or legacy architecture.

## 4. Audited Current Code and Assumptions

- `client/app/lib/features/session_list/session_tile.dart` currently renders the
  optional headline `PrStatusRow` in its subtitle and computes `isThreeLine`
  from update/files/headline/activity rows.
- `SessionListContent` builds tiles by list index without an explicit outer
  session key; stable expansion requires identity-based state, not index state.
- `PrStatusRow` already owns typed state/review/check/merge semantics and
  localized labels; history should reuse it rather than fork status logic.
- Current localization contains PR labels/statuses but no history disclosure
  labels.
- S01's honest `@Default(<PullRequestInfo>[])` means old bridge omission already
  reaches mobile as a non-null empty list. No nullable normalization seam is
  needed in module-core or Flutter.
- S02-W02 permits a thin `PrSyncService` compatibility facade to survive
  temporarily, but all final request, activation, scheduled, branch, and archive
  triggers target `PrRefreshDispatcher` after S02-W04.
- Existing `pr_sync_service_test.dart`, `PrSyncService` fakes, and comments may
  still name deleted ownership; valid behavioral assertions must move rather
  than disappear.

## 5. Design and Ownership

### Expected files

Mobile paths likely changed/added:

- `client/app/lib/features/session_list/session_tile.dart`
- `client/app/lib/features/session_list/session_list_content.dart`
- `client/app/lib/features/session_list/pr_history_section.dart` (new)
- `client/app/lib/l10n/app_en.arb`
- generated localization outputs through the configured workflow
- session-list widget/lifecycle tests and focused history tests/goldens only if
  the repository's current UI workflow already uses them

Bridge cleanup paths likely changed/deleted:

- delete `bridge/app/lib/src/bridge/services/pr_sync_service.dart`
- `bridge/app/lib/src/bridge/orchestrator.dart`
- `bridge/app/lib/src/bridge/routing/get_sessions_handler.dart`
- `bridge/app/lib/src/bridge/routing/request_router.dart`
- corresponding test constructors/fakes/comments
- delete obsolete `pr_sync_service_test.dart`; preserve non-obsolete assertions
  in dispatcher/repository/listener tests
- rename/reframe `pr_sync_fk_regression_test.dart` if its invariant remains
  useful under `PullRequestRepository`

Do not create a presentation service/cubit for expansion. This is local widget
state with one owner and no business/data access responsibility.

### Presentation behavior

`SessionTile` remains responsible for row composition:

1. Existing title/update/files rows remain unchanged.
2. Existing headline `PrStatusRow(session.pullRequest)` remains before history.
3. If history is non-empty, render `PrHistorySection` below the headline (or in
   the same position when no headline exists, for a valid historical-only
   session snapshot).
4. Existing activity/unseen/trailing/menu/swipe behavior remains unchanged.

`PrHistorySection` owns only disclosure state and rendering:

- collapsed by default;
- a localized, count-bearing button/row with an accessible expanded/collapsed
  state and adequate tap target;
- when expanded, one compact `PrStatusRow` per history item in supplied order;
- chevron/directionality semantics that work in RTL even though English is the
  only current locale;
- no navigation/link action and no duplicate PR status mapping.

Use a stable `ValueKey(session.id)` at the tile/list boundary and page-storage
state keyed by session id for the disclosure. A new `Session` instance from SSE
re-fetch with the same id preserves expansion; a different session never
inherits another row's state after reorder. Expansion state remains outside
`SessionListCubit` and the shared model.

When history is empty, do not insert padding, change current compact layout, or
alter semantics. Update `ListTile.isThreeLine`/subtitle layout only as needed for
the genuinely present disclosure while allowing expanded content to size
naturally at supported widths.

### Data flow

```text
bridge branch/PR rendered change
  -> Orchestrator sessionsUpdated(projectId)
  -> SessionListCubit existing coalesced re-fetch
  -> SessionRepository response with headline + non-null ordered history
  -> SessionTile keyed by session id
  -> headline PrStatusRow + collapsed PrHistorySection
```

The client consumes and displays the repository-owned ordering. It does not
infer GitHub/backend meaning from fields and does not mutate unseen state.

### Dead-sync cleanup

- `PrRefreshDispatcher` remains the single refresh pipeline choke point.
- `GetSessionsHandler` depends directly on it for awaited all-state and non-wait
  open requests, including origin-owned single identity follow-up rules already
  established in S02.
- `Orchestrator` listens directly to typed branch and dispatcher completion
  streams; no compatibility facade relays change events.
- Orchestrator/router/debug/test composition injects the same dispatcher instance to
  every caller; no replacement instances are constructed below composition.
- `Orchestrator.compose` removes the facade and injects the same dispatcher into
  router/listeners/SSE/debug paths; lifecycle-only `BridgeRuntime` is unchanged.
- Delete obsolete service-owned capability/remote/debounce/active maps and
  disposal. Do not move them into a new helper—the source repository and
  dispatcher already own the replacement invariants.
- Update timeless comments to name current owners, never this plan/PR.

### Error and lifecycle behavior

- Disclosure has no asynchronous work and survives normal rebuilds only by
  identity state.
- Existing SSE re-fetch failure/staleness re-arm behavior remains unchanged;
  failed refresh does not consume queued staleness.
- Removing the facade must not change dispatcher shutdown, completion stream,
  timer/listener disposal, or handler timeout behavior.
- Recovered handler/listener failures remain logged once at the origin with
  attached error/stack; cleanup must not reintroduce swallowed errors.

## 6. Backward Compatibility

- `Session.pullRequest` remains the headline; old clients ignore the additive
  history key and new clients decode omission from old bridges as empty history.
- Old clients -> new bridge still depend on both `/sessions` request triggers.
  Preserve:
  - `waitForPrData: true` as current explicit pull-to-refresh, all-state, bounded
    to five seconds; and
  - `waitForPrData: false` as fire-and-forget open refresh for clients that do
    not declare project view.
- The non-wait branch retains immediately above it:

```text
// COMPATIBILITY <implementation-date> (v<declared-version>): Clients before project-view declarations rely on non-wait /sessions requests to start PR refresh. Remove this fire-and-forget trigger after the minimum supported client always declares project view; keep the awaited explicit-refresh path.
```

- Re-read implementation date and application-declared version before editing;
  retain the already-correct S02 marker rather than adding a duplicate.
- Removing `PrSyncService` is internal cleanup, not authorization to remove any
  wire/request compatibility behavior.

## 7. Schema and Generated-Code Work

- No Drift/shared Freezed change and no migration.
- Run configured Flutter localization generation after ARB changes; do not edit
  generated localization files by hand.
- Existing generated shared/Drift/Injectable outputs must remain clean under
  full workspace generation/checks.

## 8. Verification

### Automated tests

Presentation:

- headline remains visible with history collapsed;
- localized history count/header exists only for non-empty history;
- default collapsed semantics, tap/keyboard expansion, collapse, and all rows in
  supplied descending order;
- headline number does not appear in a valid history fixture and is not rendered
  twice;
- no-headline historical-only fixture still exposes history coherently;
- same-id `sessionsUpdated` replacement preserves expansion; row reorder does
  not transfer state; different/new session starts collapsed;
- archived session fixture renders frozen headline/history and remains stable
  across unrelated live updates;
- empty history produces exact pre-feature compact row with no extra spacing or
  disclosure semantics;
- existing review/check/state colors/tooltips, activity row, unseen dot, swipe,
  long-press menu, and adaptive selection still work;
- narrow supported phone widths, wide/split layout, long localized labels/PR
  titles where shown, and supported large text scales have no overflow;
- light/dark and reduced-motion behavior remains valid (no new continuous
  animation).

Bridge cleanup/integration:

- no production/test import, constructor parameter, comment, or file retains
  `PrSyncService` except migration/history prose outside product code;
- every trigger reaches the shared dispatcher; per-project serialization,
  authored identity, truncation, change-only completion, and timer tests remain;
- request false returns without waiting and requests open (or upgraded all for
  unverified cache); request true waits up to five seconds, requests all, and
  re-enriches on success;
- compatibility marker is present once at the non-wait branch with exact cleanup;
- old-client requests still refresh after facade deletion;
- fake filesystem/GitHub integration drives project declaration -> activation
  all-state -> durable cache -> `sessionsUpdated` -> subsequent `/sessions`
  headline/history response;
- client integration feeds that SSE/refetch response into the list cubit/widget
  and observes current plus collapsed history without unseen mutation;
- archive/unarchive integration continues reading immutable snapshot and never
  restarts polling.

### Manual verification

The real-account/device paths are delegated to advisory S03-W03-M01. Automated
tests use deterministic fake Git/GitHub/relay sources and do not require user
credentials.

### Exact commands

```text
# workdir: shared/sesori_shared
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart test

# workdir: bridge
dart pub get
make codegen
make analyze
make test

# workdir: bridge/app
dart analyze --fatal-infos
dart test
make build-host

# workdir: client
dart pub get

# workdir: client/module_core
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart test

# workdir: client/module_auth
dart analyze --fatal-infos
dart test

# workdir: client/module_prego
dart analyze --fatal-infos
flutter test

# workdir: client/app
flutter gen-l10n
dart analyze --fatal-infos
flutter test

# workdir: client/module_desktop_core
dart analyze --fatal-infos
dart test

# workdir: client/desktop
dart analyze --fatal-infos
flutter test
```

### Regression guide

- A no-history session row remains pixel/layout/semantics equivalent to current
  behavior.
- Current PR status indicators and headline prominence do not move behind the
  disclosure.
- SSE refresh remains cache-first and unseen-neutral; explicit pull-to-refresh
  remains the only list load that waits for GitHub.
- Old clients without presence still trigger refresh; new clients with old
  bridges still load empty history safely.
- Branch observation, viewed timers, archive final attempt, terminal unarchive,
  standalone/headless bridge, and desktop compilation remain intact.

## 9. Risks

- Sliver index reuse can transfer expansion between sessions; stable outer keys
  plus session-keyed page storage prevent it.
- Reimplementing PR status rows would split presentation truth; reuse
  `PrStatusRow` and supplied order.
- Final cleanup can delete valid regressions together with old fakes; rehome
  assertions under dispatcher/repository/integration owners before deleting.
- A broad tile redesign would obscure regressions; add only the focused
  disclosure and preserve the empty-history shape.

## 10. Acceptance Criteria

- Current PR remains immediately visible; every supplied history PR is collapsed
  by default, ordered, accessible, and never duplicates the headline.
- Expansion is stable by session identity across SSE replacement/reorder.
- Empty-history, archived, active, unseen, action, narrow, and wide rows pass.
- `PrSyncService` and obsolete debounce internals are gone without losing any
  dispatcher trigger or behavioral test.
- Both request modes, five-second budget, compatibility marker, and old/new
  pairing behavior remain.
- Full bridge/shared/client/mobile/desktop verification passes.

## 11. Definition of Done

- UI/localization, integration tests, dead-code cleanup, and compatibility audit
  are complete.
- Generated localization/code outputs are produced only by configured tools.
- Exact full-workspace command matrix passes.
- `aristotle-impl-review` approves before PR opening.
- PR targets `main`; tracker records baseline/branch/URL/check state.
- The plan can close after merge regardless of advisory manual-check status;
  parallel-plugin work returns first to explicit stale-plan re-review.
