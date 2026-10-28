# Heavy users: smooth session lists at 10,000+ sessions

## Status and scope

- Date: 2026-10-28. Planning base: `origin/main` at `4ed73c331b`.
- Source: a real user with more than 10,000 sessions, almost all Claude Code, sees the apps freeze, worst around
  imports. Two read-only code investigations (bridge and client) ranked every path that grows with the session
  count. The review page `heavy-users-r1` settled D1–D6 with the user on 2026-10-28; D7 followed in chat.
- Status: plan raised. Phase 1 (steps 2–11) and phase 2 (steps 12–17) are both planned in full, at the user's
  request (D7).
- Repositories: this monorepo only. Every PR uses the `[heavy-users]` slug and the step numbering below.
- Product version for compatibility markers: `1.10.2` (`bridge/app/pubspec.yaml`). The compatibility baseline is
  the latest public release, `v1.10.1`; the `v1.10.2` builds are internal prereleases.

## Outcome

- With 10,000+ sessions, nothing in the session list freezes: opening it, pull to refresh, an import, toggling a
  chip, searching, clearing a search, and live activity while sessions run.
- An import that finds nothing new writes nothing, sends a handful of progress events, and makes the apps reload
  nothing.
- Every harness lists its sessions without re-reading every transcript on each import or send.
- After phase 2, the app's work to open the list is the same at 500 sessions as at 50,000. The bridge sends the
  newest page across all projects, more pages arrive as you scroll, and the bridge answers search, chips and chip
  counts. One DAO query computes a page's rows and counts. The visible-project read, the activity lookup and the
  enrichment are separate, and none of them reads every session. Older bridges keep today's full load.

## Decisions

| # | Decision (user, 2026-10-28: D1–D6 on review page `heavy-users-r1`, D7 in chat afterwards) |
|---|---|
| D1 | Phase 1 first, then phase 2 (windowed loading). |
| D2 | Phase 2 shape: newest first across all projects, more pages as you scroll; search, filter chips and their counts answered by the bridge; older bridges keep today's full download. |
| D3 | Big list changes keep per-row animation for rows on screen; off-screen rows enter and leave instantly. No whole-list cross-fade. |
| D4 | Fix all four harness scanners (Claude, Pi, Codex, OpenCode), Claude first. |
| D5 | The reporting user's sessions are almost all Claude Code. |
| D6 | Verify with a synthetic 10,000-session Claude fixture, profiled before and after, plus the user's retest after release. |
| D7 | One plan for all changes, with phase 1 and phase 2 both planned in detail. |

Settled on the page without a question: pull to refresh keeps rescanning every harness (app-simplification
decision); old sessions are never auto-archived or hidden to hide the cost.

## Current behavior (evidence, 2026-10-28)

Paths are relative to the repository root. Timings marked *estimate* were not measured; step 2 measures them.

- **Import progress floods.** The native-projects import (OpenCode only) yields one `enumerating` event per expanded
  parent, about one per session (`bridge/app/lib/src/repositories/catalog_import_repository.dart:256-281`). Nothing
  coalesces them (`bridge/app/lib/src/services/catalog_import_service.dart:147-150`, `orchestrator.dart:1008-1012`,
  `sse/sse_manager.dart:145-154`). Each one rebuilds the client list.
- **Every import rewrites every row.** `_mergeSessionRow` always stamps `projectionUpdatedAt: importStartedAt`
  (`catalog_import_repository.dart:611-650`), so no merged row equals its existing row and all rows are upserted in
  batches (`:554-563`). Projects are stamped the same way (`:607`). `sessionsImported` counts every published
  session (`:552`), and the client reloads whenever it is above zero
  (`client/module_core/lib/src/services/catalog_rescan_service.dart:242-245`).
- **Each import runs one chat-history check per session.** The import publishes every session with a backend
  update time (`:545-547`, `:576`). The listener queues all of them
  (`bridge/app/lib/src/listeners/chat_history_activity_listener.dart:34-51`). Each takes a lock and a read, and most
  sessions have no history row (`services/chat_history_service.dart:478-491`).
- **`/projects` reads every session row** to compute the unseen dot
  (`bridge/app/lib/src/repositories/project_repository.dart:38-89`, `api/database/daos/session_dao.dart:598-608`).
- **One refresh means several full downloads.** `SessionListRefreshService.refresh` starts every import and reloads
  every project's full `/sessions` (`client/module_core/lib/src/services/session_list_refresh_service.dart:28-39`).
  Each harness completion reloads everything again. `/sessions` is sent without `start`/`limit`
  (`client/module_core/lib/src/api/project_api.dart:40-49`), is 5–8 MB at 10,000 sessions (*estimate*), and is
  decoded on the UI isolate (`client/module_core/lib/src/api/client/relay_http_client.dart:41-61`). The client
  already has `postDecodedInBackground` (`:85-106`) but doesn't use it here.
- **Every list update regroups every row.** `AllSessionsState`, `AllSessionsRow`, `SessionListChipCounts` and
  `AllSessionsFailure` have no equality (`client/module_core/lib/src/cubits/all_sessions/all_sessions_state.dart`).
  The list regroups all rows by date in `build`
  (`client/module_app_ui/lib/src/features/session_list/all_sessions_list.dart:294-314`) and creates a
  `DateFormat.yMMMM` per row older than this month (`session_date_label.dart:6-19`).
- **Each live event resolves the whole list 2–3 times.** `AllSessionsCubit` listens to the recent inventory, the raw
  project inventory stream and the filter tracker separately
  (`client/module_core/lib/src/cubits/all_sessions/all_sessions_cubit.dart:53-59`). Every ProjectsSummary emits new
  maps without `distinct` (`services/sse_event_tracker.dart:165-187`) and the project inventory re-emits after it
  (`services/project_inventory_service.dart:79-107,221-237`). Search has no debounce (`all_sessions_list.dart:473-479`).
- **Changing many rows at once is quadratic.** `PregoAnimatedSliverList` calls Flutter's `removeItem`/`insertItem`
  once per changed row (`client/module_prego/lib/components/lists/prego_animated_sliver_list.dart:62-95`). Each call
  creates an `AnimationController` and re-sorts Flutter's in-flight lists, even at zero duration.
  `findChildIndexCallback` is an `indexWhere` over all entries (`:132-136`).
- **Row action cubits fetch whole projects.** Each `SessionListCubit`, created per row on its first action and by
  every session detail screen, refetches its project's full `/sessions` on every reconnect, `dataMayBeStale`,
  `catalogChanged` and failed action (`client/module_core/lib/src/cubits/session_list/session_list_cubit.dart:55-66,
  295-299,507-663`).
- **Harness scanners:**
  - Claude re-reads 64 header lines and the last 64 KiB of every transcript on every scan, with no cache
    (`bridge/sesori_plugin_claude/.../claude_transcript_catalog_repository.dart:33-61,157-234`). `getChildSessions`
    runs a full scan per call. `findSessionById`, used by every send, rename, delete and active-session summary, does
    a recursive `listSync` on the main isolate (`claude_plugin_impl.dart:240,284,320,569,752`).
  - Pi reads every transcript in full, byte by byte, on each list, and runs 1–2 more full scans on each send,
    rename and message load (`bridge/sesori_plugin_pi/lib/src/api/pi_session_storage_api.dart:493,780-806`;
    `pi_plugin_impl.dart:577`; `repositories/pi_session_process_repository.dart:203,266,707,886`).
  - Codex lists, stats and reads its index synchronously on the main isolate
    (`bridge/sesori_plugin_codex/.../codex_rollout_api.dart:93-150`, `codex_catalog_repository.dart:20-76,326-344`).
  - OpenCode, while running, imports through one `getChildSessions` HTTP call per session, one after another, made
    by the bridge app (`catalog_import_repository.dart:256-281`). Its read-only database snapshot is used only while
    OpenCode is dormant (`bridge/app/lib/src/runtime/plugin_runtime.dart:573-587`;
    `bridge/sesori_plugin_interface/lib/src/lifecycle/bridge_plugin_descriptor.dart:130-136`).
- **What already works:** only visible rows are built; no session data is stored on the device; the bridge database
  has the right indexes for today's queries; bridge `/sessions` already honours `start`/`limit`, but per project and
  ordered by raw `updated_at` rather than the displayed time.

## Product behavior and feel

- **Chips and project filter** change the list without a freeze. Rows on screen open and close as today; rows that
  enter or leave off screen do so instantly (D3).
- **Search** shows typed text at once. The list narrows 150 ms after the last keystroke (phase 1). In phase 2 the
  loaded rows narrow locally on each keystroke, and the bridge's answer completes the list 250 ms after the last
  one. Rows stay in place until an answer arrives; nothing blanks.
- **Import progress** updates the scan row at most about four times a second, and the list doesn't move during an
  import.
- **Pull to refresh** reloads once. A second reload follows only when an import actually changed something.
- **Paging (phase 2):** the first page shows the newest 200 sessions. A sparkle loader row sits at the end while
  more exist. Scrolling within about 30 rows of the end fetches the next page. New rows insert above the loader
  without moving anything above them. Rows that land off screen appear instantly; rows that land on screen open as
  usual.
- **Chip counts (phase 2)** come from the bridge and update in place, at most about a second after a change.
- **Archived (phase 2)** opens on its first page and pages the same way.
- No sound, no new copy beyond the loader row's accessibility label, and no analytics (no product decision depends
  on it).

## Design

### Phase 1: stop the multipliers

**Bridge import (step 5).**
- Skip a session row whose merge equals its existing row, ignoring `projectionUpdatedAt`:
  `row.copyWith(projectionUpdatedAt: existing.projectionUpdatedAt) == existing`. Do the same for project rows.
  Counters, bindings and backend-activity observation still cover skipped rows.
- `sessionsImported` and `projectsImported` count rows actually written (new or changed). Update the contract
  comment in `shared/sesori_shared/.../catalog_import_progress.dart`. This is a wire-meaning change; see
  Compatibility.
- `ChatHistoryService` filters a batch of backend-activity observations with one read of the sessions that have
  history (`ChatHistoryDao.getStoredSessionIds`), then queues only those. Sessions without history are skipped
  without a lock.
- The native-projects walk yields `enumerating` only when its counts changed and at least 250 ms after its previous
  yield, using a local `Stopwatch` in the generator. The phase transitions that follow (committing, completed,
  cancelled, failed) carry final counts.
- `/projects` unseen reads only the columns the unseen rule needs, for active root sessions, filtered in SQL. The rule
  itself stays in `SessionUnseenCalculator`.

**App loading (step 6).**
- `CatalogRescanService` announces `catalogChanged` once, when a live rescan operation closes, if any member
  completion wrote rows. A completion outside a live operation (startup hydration) announces at once, as today.
- `ProjectApi.listSessions` and `listProjects` decode through `postDecodedInBackground`.

**List rendering (step 3).**
- `AllSessionsState` and its parts get value equality (freezed, like the other states), so an unchanged resolve
  emits nothing.
- `AllSessionsCubit` coalesces its service triggers into one resolve per burst: merge the three streams and
  `debounceTime(Duration.zero)`. Its direct calls (`selectProject`, `setQuery`, `setQuickFilter`,
  `setHiddenSessionIds`) stay synchronous.
- `SseEventTracker` drops a ProjectsSummary equal to the previous one, and the cubit listens to the project
  inventory through `distinct()`.
- `setQuery` is debounced by 150 ms inside the cubit. A query cleared to empty applies at once. Step 16 removes this
  debounce when the window takes over search.
- The list widget recomputes date headings only when `state.rows` changes or the local day changes, using one cached
  `DateFormat.yMMMM` per locale.

**Prego list (step 4, D3).** `PregoAnimatedSliverList` keeps its public API and consumers. Internally it becomes a
`SliverList` over its own entries:
- an O(n) key diff on update, plus a key→index map that serves `findChildIndexCallback`;
- a row whose index lands inside the visible window gets an enter or exit `AnimationController`, and a leaving row
  stays as a ghost entry until its exit completes;
- off-screen inserts, removals and page appends just change the entries;
- the visible window comes from the sliver's last layout, as today, corrected for index shifts during the update.

Controllers exist only for rows on screen, so the cost of an update is O(n) plus a bounded number of animations.

**Harness scanners (steps 7–10, D4, Claude first).** Each cache lives in the plugin's catalog repository for the
plugin's lifetime. API classes stay stateless.
- **Claude.** `ClaudeTranscriptCatalogRepository` owns a cache keyed by transcript path. Each entry holds
  `(size, mtime)` and the parsed record; a child's key also includes its meta file's stat.
  - The scan isolate receives the cached `(path → size, mtime)` snapshot. It lists and stats every file, parses only
    new or changed files, and returns the current paths with stats plus the new parses. The repository merges them
    and evicts paths that are gone.
  - Nothing sent to the isolate captures `this` (the Codex pattern, `codex_catalog_repository.dart:78-90`).
  - `findSessionById`, `findTranscriptPath` and `getChildSessions` answer from the cache, rescanning once on a miss.
  - The unused repository-level start/limit slicing goes.
- **Pi.** `PiSessionCatalogRepository` owns the same kind of cache, like Codex. A changed file is re-read in full,
  which in practice is only the file in use; `findSessionById` answers from the cache. `PiSessionStorageApi` stays
  stateless: `pi_plugin_impl.dart` resolves a session through the catalog repository and passes it to
  `PiSessionProcessRepository`. That replaces the process repository's four `resolveSession` scans.
- **Codex.** `CodexCatalogRepository` already caches parsed headers (`codex_catalog_repository.dart:78-95`).
  Enumeration (listing, stats, index read, stale header parse) moves into one `Isolate.run`. The synchronous
  `findSessionById`, `findRolloutPath` and `deleteSession` use an id→path index the repository derives from its
  cache, with an async rescan on a miss. Codex is transient, so its cache drops on idle suspension; accepted.
- **OpenCode.** The runtime's dormant-only snapshot path stays unchanged.
  - `NativeProjectsPluginApi`, which only OpenCode implements, gains
    `readCatalogSnapshot({required PluginCatalogCancellationSignal cancellation})`. It returns the existing
    `PluginCatalogSnapshotResult`.
  - OpenCode answers it from the same read-only database reader its descriptor uses, when that reader is eligible
    and safe beside a running OpenCode. Otherwise it answers from one bulk listing that step 10 verifies returns
    every session with its parent id. If neither works, it returns `PluginCatalogSnapshotUnavailable`.
  - `CatalogImportRepository`'s native path imports a returned snapshot instead of walking parents. On Unavailable
    the walk stays, throttled by step 5.

**Row action cubits (step 11).** `SessionListCubit` keeps only the sessions it was given or updated with by
`updateActionSession`. It follows them through session events, and rolls back failed renames and deletes from its
own snapshot. A failed mark read or unread restores the `SessionUnseenTracker` value it held before its optimistic
write. Today a project fetch repairs it (`session_list_cubit.dart:170-201`). The cubit stops fetching project lists.
The fetch, catalog-refresh drain and paused-after-failure machinery are deleted. Before removing them, check every
`state.sessions` consumer.

### Phase 2: stop loading every session

**Shared rules (step 12, `sesori_shared`).** Both sides must apply the same rules, so each gets one owner in
`sesori_shared`:
- **Running.** `ActiveSessionRunningCalculator.isRunning({required ActiveSession session})`:
  `mainAgentRunning || isRetrying || childSessionIds.isNotEmpty`. `AuthDeviceInfoBuilder` is the precedent for a
  rule class in shared.
  - The client applies it once, in `SseEventTracker`, the only place that builds `SessionActivityInfo`. The result
    is stored as `SessionActivityInfo.isRunning`.
  - `SessionActivityCalculator` is deleted. Its consumers read the field: `session_list_service.dart`,
    `project_list_service.dart`, `session_list_resolvers.dart:15`, `recent_sessions_resolvers.dart:12`, and the
    test helpers.
- **Search.** The word split and `matchTexts` (`client/module_core/lib/src/utils/title_matcher.dart`) and the
  own-name rule `projectOwnName`/`hostPathBasename` (`client/module_core/lib/src/utils/project_name.dart`) move to
  shared unchanged. Scratch projects keep a null own name. `sesori_shared` gains a `path` dependency, or the
  basename becomes a last-segment rule with the same tests. Client imports switch in the same change.

**Wire contract (step 13).**

```text
POST /sessions/page
SessionPageRequest {
  mode: SessionPageMode            // active | archived
  projectId: String?               // null = every visible project
  query: String?                   // null = no search; never ""
  filter: SessionPageFilter        // all | running | unread (the chip)
  cursor: String?                  // null = first page; opaque
  limit: int                       // 0..1000; 0 = counts only; outside → 400
}
SessionPageResponse {
  items: List<Session>             // root sessions, display order
  nextCursor: String?              // null = no more rows
  counts: SessionPageCounts        // all, running, unread under mode + project + query (not the chip)
}
```

- **Order.** Active: `max(updated_at, coalesce(last_user_message_at, 0))` DESC, then `session_id` DESC. This is the
  time the mapper already sends as `time.updated` (`repositories/mappers/session_catalog_mapper.dart:18,45-48`).
  Archived: `archived_at` DESC, then `session_id` DESC. Keyset pagination: the cursor encodes the last row's sort
  key and id; an invalid cursor is a 400.
- **Scope.** Root sessions of visible projects (`projects_table.hidden = 0`), including the "No project" scratch
  project.
- **Search.**
  - The query splits into words with the shared rule. Every word must match, case-insensitively, either the title
    the mapper sends or the project's own name.
  - Titles match in SQL with `LIKE ... ESCAPE '\'`. Each word is matched literally: `\`, `%` and `_` are escaped,
    with `\` escaped first. Project names are matched in Dart with the shared
    `projectOwnName` over the visible projects, which gives each word's matching project ids.
  - SQLite folds only ASCII case.
- **Running.** Running ids come from `SessionRepository.getProjectActivitySummaries()`, filtered with the shared
  running rule. Every ProjectsSummary broadcast already makes this call (`orchestrator.dart:1954,2008-2011`), so
  each page or counts request costs one more. Accepted: the client debounces both to at most one a second per
  window.
- **Ownership chain.**
  - `GetSessionPageHandler` (`routing/`) validates the request.
  - `SessionRepository.getSessionPage(...)` reads visible projects and their names through its existing
    `ProjectsDao`, gets running ids, and calls the DAO.
  - The handler then calls `SessionViewService.enrichMany` over the items, as `GetSessionsHandler` does, so
    `autoContinuation` is filled.
- **Database layer.** `SessionDao.getSessionPage(...)` is one query in `api/database/`.
  - Inputs are plain values: mode, project ids, each word with its matching project ids, a filter enum, running ids,
    a cursor key and a limit. It returns the rows and the three counts, all from one read transaction.
  - The SQL forms of the unseen rule and of the displayed time live there. Parity tests tie them to
    `SessionUnseenCalculator.isUnseen` and to the mapper's displayed time. The calculator stays pure Dart, and no
    Drift code leaves the database layer.
- The unused `getArchivedCatalogSessions` is replaced by this query.
- No new index or migration. The page query scans the mode's root sessions once to sort them and count them. At
  10,000 roots on the database isolate this is a few milliseconds, and the client does no per-session work.
  Step 13 times it with a 50,000-session fixture. If it exceeds about 50 ms, step 13 adds an expression index on the
  displayed time in the same PR. Counts stay a scan of the filtered set either way.

**Client window (step 14).**

*Layers.* `SessionApi.getSessionPage` posts `/sessions/page` through `postDecodedInBackground`.
`SessionRepository.getSessionPage` returns a sealed `SessionPageResult`:
- `SessionPageLoaded(page)`;
- `SessionPageUnsupported`, built with the existing `_isMissingRoute` (`session_repository.dart:162,187-192`), like
  `SessionPromptIndexUnsupported`;
- `SessionPageFailure(error)`.

*Ownership.* `SessionWindowService` (module_core `services/`) is an `@injectable` factory with
`@factoryParam AllSessionsMode mode` fixed at construction.
- `SessionScope` provides the active window, created through a `createSessionWindow` callback from each shell, like
  its other services.
- The archived route provides its own archived window in a `RepositoryProvider` around its cubit, disposed with the
  route.
- The window's state is one sealed value: loading, loaded (rows, next cursor, counts, load-more status) or failed.

*Key and loading.*
- The key is project, query and chip.
- The window owns the one matching rule. On a key change it immediately emits its current rows narrowed by the
  shared search rule and by the chip, judged with the activity and unseen trackers. The bridge's answer then
  replaces them.
- The bridge request follows the last query change by 250 ms. A cleared query, a project change or a chip change
  requests at once.
- `loadMore` appends the next page (200 rows), deduplicated by id.
- `reload` refetches the loaded range from the start: at least 200 rows, in consecutive pages of up to 1,000. It
  swaps the rows once every page has arrived, so a reader 1,500 rows down keeps their place. It runs on `reload()`
  from `SessionListRefreshService`, on `catalogChanged` and on `dataMayBeStale`. A plain reconnect relies on SSE
  replay, as today.
- A bridge switch, seen through the existing `TargetBridgeChangeTracker`, resets the window.
- A request generation drops answers the user has moved past.
- Each page seeds `SessionUnseenTracker`, which merges seeds instead of replacing a project's map.

*Live updates.*
- `session.created` and `session.updated` (roots only) are upserted when the session matches the key and sorts
  within the loaded range, or when no more pages exist. They are removed when they no longer match.
- `session.deleted` removes.
- A live event that arrives while a load is in flight is re-applied over that load's answer. This is today's
  lifecycle-generation rule, moved from `RecentSessionInventoryService`.
- Running and unread membership changes without a session event, so for those chips an activity or unseen change
  schedules a window reload, debounced by 1 s. For every chip, created, deleted, activity and unseen changes
  schedule a counts-only request (`limit: 0`), debounced by 1 s.

*Older bridges.*
- On `SessionPageUnsupported`, the window switches to complete mode for that connection. It loads every root of
  every visible project through the existing per-project `/sessions` repository call.
- In complete mode it holds all of the mode's rows and answers key changes, chip membership and counts locally, with
  the same matching rule. This is today's `AllSessionsCubit` resolve moved into the window.
- Live updates use the same code as paged mode; with no further pages, every row is in range.
- A reconnect probes `/sessions/page` again.
- Complete mode carries `// COMPATIBILITY 2026-10-28 (v1.10.2): ...`, to be removed when the oldest supported
  bridge serves `/sessions/page`.

*Search for the palette.* `search({required String query, required int limit})` asks the bridge in paged mode and
matches loaded rows in complete mode.

**Palette search (step 15).** A new `SessionSearchCubit` (module_core `cubits/session_search/`) reads the scope's
active window.
- It shows matches among loaded rows at once, then the window's `search` result 200 ms after the last keystroke
  (20 results).
- It drops stale answers.
- The palette widget in `client/desktop` only renders the cubit's state and keeps no search logic.

**Session list on the window (step 16).**
- `AllSessionsCubit` combines the window, the project inventory and the activity and unseen trackers into rows, and
  drops hidden ids (pending-archive Undo and launch holds). It keeps no matching rule and no query debounce.
- Chip counts are the window's counts as they are. A row hidden for an archive Undo stays counted until the archive
  commits and the counts refresh (accepted below).
- `defaultProjectId` is the first row's project when the key is active, unfiltered and unsearched; otherwise it keeps
  its last value.
- The client's update-order tie-break becomes `session_id` DESC to match the bridge.
- `AllSessionsList` adds the loader row and calls `loadMore` within about 30 rows of the end.
- `SessionListRefreshService` takes the active window and calls `reload()` instead of refreshing
  `RecentSessionInventoryService`.
- `everyProjectRows` goes.

**Launch rows on the window (step 17).**
- `ProjectLaunchRowsCubit` reads the scope's active window. When the window is loaded with no query and chip All,
  its rows grouped by project feed `resolveProjectLaunchRows` as loaded entries.
- Rows appended by `loadMore` count as already shown, so they never satisfy or hold a launch.
- While the window is loading or failed, or a query or another chip is set, launches latch through the existing
  `latchLaunchSessions`. They resolve once the key returns to unfiltered. A session launched during a search
  therefore keeps its launching row until the search clears; accepted.
- `RecentSessionInventoryService`, its tests and its scope and shell wiring are deleted, along with the unused
  `ProjectRepository.findSessionContext`.

## Compatibility

- **Step 5 (`sessionsImported`/`projectsImported` now count written rows).**
  - Released apps (v1.10.1) with a new bridge reload only when something changed. They show counts from `newItems`,
    which every new bridge sends, so nothing visible changes.
  - New apps with an older bridge keep today's behavior: totals are still above zero, so they still reload.
  - No retained field and no marker.
- **Phase 2.**
  - Older apps never call `/sessions/page`, and `/sessions` stays.
  - New apps fall back to complete mode on a `no handler found` 404. The v1.10.1 router sends that body (checked
    during review).
  - The baseline is the public bridge `v1.10.1`.
- **Not transport:** every plugin and module contract updates in lockstep, without shims. This includes the new
  `NativeProjectsPluginApi.readCatalogSnapshot` and the shared rules.

## Complexity budget

| New mutable part | Why |
|---|---|
| Claude and Pi catalog-repository caches (path → stat, record) and their derived id → path index; Codex's derived index | The root fix for repeated full scans; lost on restart, rebuilt by one scan. |
| Prego list entries, key → index map, per-on-screen-row controllers, leaving ghosts | D3; bounded by visible rows. |
| `SessionWindowService` per mode: state subject, request generation, in-flight event buffer, complete-mode flag per connection, two debounced invalidation streams | The window's single owner. |
| `SessionSearchCubit` state and request generation | Palette search belongs in a cubit. |
| Import-walk `Stopwatch` (local to one generator run) | Throttle without service state. |

Deliberately not added:
- FTS, an expression index or migration, or a persisted scanner cache.
- A cached activity summary on the bridge (each page request calls the plugins).
- Client-side count arithmetic, a new SSE event, or a capability flag on `HealthResponse` (the 404 probe already
  exists).
- Auto-archiving, or a whole-list cross-fade.

## Cleanup

- Step 7 removes Claude's unused repository-level paging.
- Step 8 removes the Pi process repository's `resolveSession` scans.
- Step 11 removes `SessionListCubit`'s project fetch, catalog-refresh drain and failure-pause state.
- Step 12 deletes `SessionActivityCalculator` and the client copies of the search and own-name rules.
- Step 13 replaces the unused `getArchivedCatalogSessions`.
- Step 16 removes the cubit's query debounce and resolve, and `everyProjectRows`.
- Step 17 deletes `RecentSessionInventoryService` and `ProjectRepository.findSessionContext`.
- Deferred until the oldest supported bridge serves `/sessions/page`: the window's complete mode.

## Steps

Dependencies:
- Step 2 comes first so later steps can measure against its baseline.
- Steps 3–11 are independent of each other; step 6's single reload depends on step 5 for its full effect.
- Step 13 depends on step 12, and step 14 on step 13. Steps 15–17 depend on step 14, and steps 16–17 also on step 4.

| Step | Exact PR title | Est. lines | Outcome |
|---|---|---:|---|
| 1/19 | `🌱 [heavy-users] Plan smooth session lists for 10,000+ sessions [step 1/19]` | 600–750 | This plan and tracker |
| 2/19 | `🌿 [heavy-users] Add a 10,000-session Claude fixture and baseline [step 2/19]` | 200–350 | Generator, run notes, baseline numbers |
| 3/19 | `⚙️ [heavy-users] Rebuild the session list only when it changes [step 3/19]` | 350–550 | Equality, coalesced resolve, debounce, memoized headings |
| 4/19 | `🚧 [heavy-users] Animate only on-screen rows in Prego lists [step 4/19]` | 450–750 | D3 list internals |
| 5/19 | `⚙️ [heavy-users] Write only changed rows on catalog import [step 5/19]` | 400–650 | Skip unchanged rows, honest counts, history filter, throttle, narrow unseen read |
| 6/19 | `🌿 [heavy-users] Reload sessions once per import and decode off the UI thread [step 6/19]` | 150–300 | One reload, background decode |
| 7/19 | `⚙️ [heavy-users] Cache Claude transcript metadata between scans [step 7/19]` | 400–600 | Claude cache and index |
| 8/19 | `⚙️ [heavy-users] Cache Pi session metadata between scans [step 8/19]` | 350–600 | Pi cache; process repository resolves through it |
| 9/19 | `⚙️ [heavy-users] Move Codex session enumeration off the main isolate [step 9/19]` | 300–500 | Codex isolate and index |
| 10/19 | `⚙️ [heavy-users] Import OpenCode sessions without a call per session [step 10/19]` | 300–550 | Live catalog snapshot on the native API |
| 11/19 | `⚙️ [heavy-users] Keep row action cubits to their own session [step 11/19]` | 300–500 (net deletion) | No project fetch from actions |
| 12/19 | `🌿 [heavy-users] Share the running and search rules between bridge and app [step 12/19]` | 300–500 | Shared rules; client calculator gone |
| 13/19 | `🚧 [heavy-users] Serve session pages across projects from the bridge [step 13/19]` | 900–1,300 | Route, models, order, search, filters, counts |
| 14/19 | `🚧 [heavy-users] Load sessions in pages on the client [step 14/19]` | 1,000–1,400 | API, repository result, window service with complete mode |
| 15/19 | `🌿 [heavy-users] Search sessions through the bridge in the command palette [step 15/19]` | 250–400 | `SessionSearchCubit`; palette renders it |
| 16/19 | `🚧 [heavy-users] Show the session list from pages [step 16/19]` | 800–1,200 | List, chips, archived and refresh on the window |
| 17/19 | `⚙️ [heavy-users] Resolve launches from the window and remove the session inventory [step 17/19]` | 1,000–1,400 (mostly deletion) | Launch rows on the window; inventory deleted |
| 18/19 | `🌱 [heavy-users] Reconcile regression documents [step 18/19]` | 150–350 | Feature docs |
| 19/19 | `🌱 [heavy-users] Run the L3 matrix and retire the plan [step 19/19]` | 50–150 | Matrix results, retirement |

### Step 2 — Fixture and baseline (🌿)

- `bridge/app/tool/benchmarks/claude_session_fixture.dart` writes N root transcripts (default 10,000) under
  `<out>/projects/<encoded-path>/<uuid>.jsonl`.
  - Projects: 40 by default, skewed so one holds 40%.
  - About 20% of roots get 1–3 subagent children, each with a meta file.
  - Titles: a mix of custom titles and prompt-derived ones.
  - Each file's mtime is spread over a year.
  - Each file holds the minimal valid lines the Claude scanner accepts, plus a few hundred KB of filler in some files
    so the tail reads are realistic.
- Run notes at the top of the file:
  - log in once with `CLAUDE_CONFIG_DIR=<out> claude auth login` (dev account; setup refuses imports while logged
    out);
  - start a local bridge on a separate `--data-dir` with `CLAUDE_CONFIG_DIR=<out>`, per the `sesori-local-testing`
    skill.
- Baseline, recorded in `TRACKER.md`:
  - **Bridge:** Claude first-import and rescan time; rows written per rescan; progress events per import; `/sessions`
    bytes for the largest project and in total.
  - **Desktop:** a macOS profile build, timed with DevTools: worst frame and total UI-thread time for cold list
    open, pull to refresh until idle, Running on/off, typing a five-letter search, and clearing it.
  - **Phone:** the headless iOS simulator (debug), recording freeze durations for the same actions.

### Step 3 — List rendering (⚙️)

Scope as in Design → List rendering.
- Tests:
  - resolve and emit counts per burst;
  - an unchanged resolve emits nothing;
  - a duplicate ProjectsSummary is dropped;
  - debounce timing, with an empty query applying at once;
  - headings recompute only on a rows or day change.
- Analyze `module_core` and `module_app_ui`.
- Re-measure the step 2 list actions.

### Step 4 — Prego list (🚧)

Scope as in Design → Prego list.
- Tests:
  - existing `prego_animated_sliver_list_test.dart` and `prego_animated_list_test.dart` pass unchanged;
  - swapping 10,000 rows for 5 creates controllers only for on-screen rows and completes in one frame;
  - a row re-entering while leaving gets a fresh key;
  - an append below the viewport doesn't animate;
  - semantics, focus and taps exclude leaving rows.
- Settings lists (computers, projects, harnesses) keep their motion.
- Record before/after strips in the PR (fixture data).

### Step 5 — Bridge import (⚙️)

Scope as in Design → Bridge import.
- Tests:
  - a second import of the same catalog writes 0 session and project rows and reports 0 imported;
  - a changed title writes one row;
  - a skipped row keeps its stamp, and a later live write still applies;
  - history checks run only for sessions with history;
  - the walk yields at most one event per 250 ms;
  - `/projects` unseen equals the previous result over a fixture with archived and child rows.
- Analyze `bridge/app` and `sesori_shared`.

### Step 6 — App loading (🌿)

Scope as in Design → App loading.
- Tests:
  - a three-harness rescan announces once at close, and only if a completion wrote rows;
  - startup hydration still announces at once;
  - `/sessions` decodes through the background path.

### Step 7 — Claude scanner (⚙️, first per D4)

Scope as in Design → Harness scanners.
- Tests:
  - an unchanged second scan parses 0 files;
  - a modified file re-parses;
  - a deleted file is evicted;
  - a child re-parses when its meta file changes;
  - `findSessionById` on a hit doesn't list directories;
  - a miss rescans once.
- Measure the fixture rescan time against the baseline.

### Step 8 — Pi scanner (⚙️)

Same shape as step 7, with the cache in `PiSessionCatalogRepository`.
- Tests:
  - an unchanged scan reads 0 bytes of transcripts;
  - a rename (appended `session_info`) re-reads only that file;
  - send and rename don't scan;
  - the process repository receives resolved sessions.

### Step 9 — Codex enumeration (⚙️)

Scope as in Design → Harness scanners.
- Tests: enumeration does no synchronous file I/O on the main isolate; an index hit answers `findRolloutPath` without
  listing; a miss rescans asynchronously.

### Step 10 — OpenCode import (⚙️)

Scope as in Design → Harness scanners.
- First, against a real OpenCode, verify:
  - the read-only reader opens safely beside a running OpenCode (WAL, without `immutable`);
  - which bulk listing, if any, returns every session with its parent id (v2 cursor pages; v1 `GET /session` without
    `roots`, checking its documented 100-row ceiling).
- Tests:
  - the native path imports a live snapshot without per-parent calls;
  - Unavailable falls back to the walk;
  - cancellation stops the snapshot.
- Record any case that still walks in `docs/regression/projects-and-sessions.md` and, if a harness gap remains,
  `docs/HARNESS_CAPABILITIES.md`.

### Step 11 — Row action cubits (⚙️)

Scope as in Design → Row action cubits.
- Tests:
  - rename and delete success, failure rollback and event updates still work;
  - a failed mark read or unread restores the tracker's previous value;
  - reconnect, `catalogChanged` and `dataMayBeStale` make no requests.
- Check the session detail and row action flows on the iOS simulator.

### Step 12 — Shared rules (🌿)

As in Design → Shared rules.
- Tests: the running rule's cases; moved matcher and own-name tests pass unchanged in `sesori_shared`.
- Analyze `sesori_shared`, `module_core` and the client test helpers' packages.

### Step 13 — Bridge session pages (🚧)

Wire models, handler, repository and DAO query, as in Design → Wire contract.
- Tests:
  - order and tie-break;
  - keyset paging across inserts;
  - active and archived;
  - project filter and hidden projects;
  - scratch project;
  - search words over titles and project names, with `\`, `%` and `_` matched literally;
  - running from summaries;
  - unseen and displayed-time parity with the Dart rules;
  - counts;
  - `limit: 0`, and limits outside 0..1000 → 400;
  - invalid cursor → 400;
  - items are enriched;
  - JSON omits nulls.
- Time a page query over the fixture at 10,000 and 50,000 sessions, and record both in the tracker.
- Run `architecture-implementation-review`.

### Step 14 — Client window (🚧)

As in Design → Client window. Wired into `SessionScope` and both shells, but not yet consumed by the list.
- Tests:
  - first page, `loadMore` and dedup;
  - a reload with 1,500 rows loaded refetches all of them in two requests and swaps once;
  - local narrowing on a key change, then the answer;
  - query debounce, with an immediate request for other key changes;
  - generation drops stale answers;
  - live upserts in and out of range and of the filter;
  - in-flight events re-applied over an answer;
  - the chip-membership reload and counts refresh debounce;
  - Unsupported switches to complete mode, which answers keys and counts locally, and a reconnect re-probes;
  - a bridge switch resets;
  - unseen seeds merge.
- Run `architecture-implementation-review`.

### Step 15 — Palette search (🌿)

As in Design → Palette search.
- Tests: local matches show at once, then bridge results; stale answers are dropped; complete mode matches locally.

### Step 16 — List on pages (🚧)

As in Design → Session list on the window.
- Tests:
  - paging trigger and loader row;
  - hidden rows dropped;
  - `defaultProjectId`;
  - tie-break order;
  - pull to refresh reloads the window once;
  - the archived view pages with its own window;
  - complete mode still lists everything.
- iOS simulator and macOS checks against the fixture.
- Run `architecture-implementation-review`.

### Step 17 — Launch rows and inventory removal (⚙️)

As in Design → Launch rows on the window.
- Tests:
  - a launch resolves from the first page;
  - appended rows never satisfy or hold a launch;
  - a launch latches while searching and resolves after the search clears;
  - existing `session_launch_resolvers` tests pass.
- Check a launch on the iOS simulator.

### Step 18 — Regression documents (🌱)

Update:
- `docs/regression/projects-and-sessions.md`: import cost and progress, the list window, paging, search, chips and
  counts, the compatibility fallback, and any OpenCode case that still walks;
- `docs/regression/session-archiving-and-deletion.md`: the archived view pages;
- `docs/regression/desktop-cockpit-shell.md`: palette search through the bridge.

### Step 19 — L3 matrix and retirement (🌱)

Run the matrix below, record the results in `TRACKER.md`, and move the plan to `.plan/completed/heavy-users/`.

## Verification and regression matrix

Highest level: **L3** for `projects-and-sessions`, plus the named compatibility cells.

| Boundary | Plugins / platform | Check |
|---|---|---|
| Live plugin + headless bridge | Claude (10,000 fixture) | Rescan twice: the second writes 0 rows, sends ≤10 progress events, and finishes well under the baseline. A send to an old session causes no directory listing. |
| Live plugin | Pi, Codex, OpenCode (running and dormant) | Import lists the right sessions; a second import writes 0 rows; a send works. |
| Headless bridge | Claude fixture | `/sessions/page`: order, cursor paging, project filter, search, Running, Unread, counts, archived. |
| Client end to end | Headless iOS simulator (phone), macOS desktop | With the fixture: open the list, scroll through three pages, search and clear, toggle Running and Unread, check counts, open a session from page 3, rename and archive from a row, launch a session, open Archived and page it, pull to refresh, search from the palette. No freeze; macOS profile timings recorded against the baseline. |
| Compatibility | New app ↔ bridge v1.10.1 | Complete mode: the full list, search, chips, counts, archived view and palette search work. |
| Compatibility | App v1.10.1 ↔ new bridge | The list loads; a refresh that changes nothing reloads once. |
| External, non-blocking | The reporting user's machine, after release | Retest; the result is recorded in the tracker when it arrives (D6). |

Platform scope: no platform-specific code changes. Windows and Linux desktop and Android are not run; the shared
Flutter code is exercised on iOS and macOS.

## Risks and accepted behavior

- **An old running session sits at its date in the All view.** A session running only through child tasks or
  retries, with no recent user message, appears where its date puts it instead of at the top. The Running chip still
  lists it. Accepted (low impact, matches the bridge's honest order).
- **Search folds only ASCII case on the bridge.** For non-ASCII titles, bridge search is case-sensitive, so a local
  match can drop out when the answer arrives. Accepted.
- **Counts can lag up to about a second** after live changes. During an archive's Undo window, the archived row is
  still counted. Accepted.
- **A launch made during a search** keeps its launching row until the search clears. Accepted.
- **Each page request asks every active plugin for activity.** This is bounded by the 1 s debounce; a cached summary
  is the upgrade if it shows in profiles.
- **A skipped import row keeps an older `projectionUpdatedAt`.** Only the import reads this value, to yield to live
  writes made after it started (`catalog_import_repository.dart:593`). Live writes are not gated by it, and imports
  are single-flight per plugin (`catalog_import_service.dart:39`), so keeping the older value changes no outcome.
  Tested.
- **Scanner caches cost memory and are lost on restart.** They hold roughly a few MB at 10,000 sessions and are
  rebuilt by one scan. Codex's is also lost on idle suspension.
- **A same-size, same-mtime rewrite isn't noticed** by the Pi and Claude caches. Not a plausible flow.
- **Evidence level.** The rankings come from code reading; the timings are estimates until step 2. If step 2 shows a
  cause is negligible, its step may shrink or be dropped, with the decision recorded in the tracker.

## Open questions

None.
