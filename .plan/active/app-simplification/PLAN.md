# App simplification: one session list, one refresh, one wide layout

## Status and scope

- Date: 2026-10-24. Planning base: `origin/main` at `b85fd311a1`.
- Source: the user's request to make the client simpler. Agreed over two review rounds on 2026-10-24
  (D1–D16 below).
- Status: plan raised.
- Scope: the Flutter client only (`module_core`, `module_app_ui`, `app`, `desktop`, `module_desktop_core`,
  `module_prego`). No bridge, relay, auth or wire changes. Every PR uses the `[app-simplification]` slug and the
  step numbering below.
- Vocabulary: the product keeps **project** for the thing and says **folder** when adding one
  (“Open another folder…”).

## Outcome

- **One list.** The phone opens on a single session list with sessions from every project, grouped by date. There
  is no Projects screen and no Activity section on any surface.
- **One wide layout.** At 700 pt and wider (iPhone landscape, iPad, desktop) the app shows the same sidebar with
  the same list, and a content pane next to it. With no session open, the content pane shows the new-session
  composer.
- **One refresh.** Pulling the list, or pressing Refresh, reloads everything and imports sessions and projects
  from every harness.
- **One picker.** The new-session project picker is searchable and can open another folder.
- **One place to manage projects.** Rename, hide, remove-missing and add live in Settings › Projects.

## Decisions

| # | Decision (user, 2026-10-24) |
|---|---|
| D1 | The home is one list of every active session from every project. There is no “Activity” section; the list is date-grouped (Today, Yesterday, …) as the session list is today. Archived sessions stay out of it. |
| D2 | Status never reorders rows. Sorting stays by last update inside each date group, so rows don't jump. |
| D3 | A row is: status slot (sparkle, amber dot or empty), the harness logo (`PregoBrandLogo` for `session.pluginId`), the title, the time. The meta line is “project · branch · PR”, and the harness name leaves it. While the list is filtered to one project, the project label is hidden. |
| D4 | The screen title is the project switcher (“All projects ▾”). On the phone the computer switcher sits under it. In the sidebar the switcher heads the list, below New session and Search. |
| D5 | The project filter lasts for the app's runtime only, and is not persisted. |
| D6 | Archived sessions keep a separate Archived screen, now across every project. It opens with the list's current filter and its rows show the project. The phone opens it from a header button, and the wide layout from the sidebar footer. |
| D7 | The wide layout starts at 700 pt (the current split breakpoint). |
| D8 | With no session open, the content pane shows the new-session composer. This replaces the desktop home's Needs you / Running / Recent sections and the phone's empty detail panel. |
| D9 | Collapsing hides the sidebar completely, and a toolbar button brings it back. There is no rail, popout or count pill. Below 700 pt the phone layout applies. On touch the sidebar has a fixed width; desktop keeps the resize handle. |
| D10 | The phone and tablet sidebar footer holds the computer switcher, Settings and collapse. Desktop keeps its bridge button, shortcut hints, palette and connection pill. The bundled bridge, bridge controls, shortcut hints, palette, window drag and file-access card are omitted on mobile. |
| D11 | Pulling or pressing Refresh does the reload plus the import across every harness. Automatic reloads never import. |
| D12 | The scan row stays and shows progress, with no Cancel and no Dismiss. When it finishes it fades out and new sessions slide into the list. A failed harness shows a short alert and is logged. |
| D13 | Removed: the deep-pull gesture, the scan menu items, the desktop project page's Refresh/Scan menu, and the per-harness “Scan for sessions” in Settings. A bridge older than v1.7.0 has no `/plugin/management` harness list to import from, so it just reloads. |
| D14 | The new-session picker is searchable: a bottom sheet on the phone that rises with the keyboard, and a popover on tablet and desktop. It is the same component as the title switcher. Its top entry is “Open another folder…”, which opens the existing folder browser and then selects the new project. Search matches known project names and paths only; with no match it shows “No projects match…” and keeps the add entry. Paths show only when names collide. It works with one project or none. |
| D15 | The new-session screen's default project is the filtered project, otherwise the project of the newest session. The phone reads the live project list (`NewSessionProjectsCubit` goes). |
| D16 | Project management moves to a new Settings › Projects page that reuses the project rows: rename, hide, remove-missing and “Open another folder…”. |

Analytics: the home reports screen `sessions`; `AnalyticsScreen.projects` goes. No event is added or removed
otherwise. `projectInventoryLoaded` keeps firing from `ProjectInventoryService`, and `sessionActivityViewed`
belongs to session detail, so neither is affected.

## Current behavior (evidence, 2026-10-24)

- **Phone navigation.** The `AppRouteDef` paths in `module_core/lib/src/routing/app_routes.dart` are:
  - home: `/projects`;
  - a per-project session list at `/projects/:projectId/sessions`, built by `app_router.dart` inside a
    ShellRoute that provides `SessionListCubitProvider` and `SessionSplitShell` (`module_app_ui/.../session_split/`,
    breakpoint 700);
  - archived sessions, new session, session detail and diffs, all under the project path.

  - Session detail and diffs nest under the per-project ShellRoute, and archived detail nests under archived
    sessions. List taps use `go`.
  - `NotificationOpenDispatcher` replaces the stack with `[projects, sessions(projectId), sessionDetail]`.
  - Other consumers of `AppRouteDef.projects`:
    - `ComputerSwitchDispatcher`, shared with desktop;
    - `SplashCubit`;
    - `DesktopAttentionService`;
    - `closeDeletedSessionRoute`;
    - `analytics_route_listener.dart`;
    - `RouteSource.projectPageVisibility`, which drives `ProjectInventoryService`'s throttled and navigate-back
      refreshes;
    - `SessionListCubit`.
- **Scoped inventories.**
  - `ProjectInventoryService` and `RecentSessionInventoryService` are `@injectable` factories, and the caller owns
    each instance.
  - On the phone the only owner is the Projects screen's `RepositoryProvider`s (`project_list_screen.dart`). On
    desktop it is `DesktopCockpitCubitProvider` (`desktop_cockpit_shell.dart`), which also provides
    `DesktopSidebarRefreshCubit` over `DesktopSidebarRefreshService` (`module_desktop_core`). That service already
    runs `refreshProjects` plus the inventory refresh.
- **Projects screen.**
  - `app/lib/features/project_list/project_list_screen.dart` hosts onboarding, the offline view and the computer
    menu.
  - `module_app_ui/.../project_list/project_list_view.dart` renders an Activity group (`activity_tile.dart`) plus
    project tiles whose `menuEntries` rename, hide and remove.
  - Its pull refresh (`_refreshProjects`) runs `refreshProjects` plus `RecentSessionsCubit.refresh`.
- **Session list.**
  - `SessionListCubit` is scoped to one project: git context, base branch, viewing claim, PR data, and the
    rename/archive/delete/mark-seen actions. `SessionListMode.actions(...)` makes an action-only instance.
  - `SessionListContent` already animates inserts with `PregoAnimatedSliverList`.
  - `session_tile.dart`'s meta line shows the harness name. The leading logo was removed in `d4abad18cc`.
- **All-project data already exists.**
  - `RecentSessionInventoryService` keeps `Map<projectId, RecentSessionsEntry>` for every listed project: one
    `POST /sessions` each, live over SSE, cleared on computer switch.
  - `RecentSessionsLoaded` carries `sourceSessions` (archived rows included), `visibleSessions`, and the per-session
    activity and list-state projections.
  - Date grouping happens in the `SessionListContent` widget, using `session_date_label.dart`'s localized labels.
    Search and chip filtering happen in `SessionListFilteredContent`.
  - `sessionsByRecency` already merges them, and the desktop palette uses it.
  - `ProjectLaunchRowsCubit` resolves launch placeholders per project from the same inventory.
- **Refresh and import.**
  - `CatalogRescanService` has `startAll`, the per-harness `start`, `cancel`, ordered against in-flight starts, and
    `dismiss`. It is surfaced through `ProjectListCubit`, `SessionListCubit` and `PluginManagementCubit`
    (`startCatalogScanFor`, `dismissCatalogScanOutcome`).
  - `catalog_scan_row.dart` (1,108 lines) wraps `PregoDeepRefresh` (`_deepPullFactor` 1.8 in
    `prego_sliver_refresh_control.dart`) and draws Cancel and Dismiss.
  - `desktop_session_list_screen.dart` has a Refresh/Scan menu, and `harness_settings_detail_view.dart` has a
    per-harness scan.
  - `startAll` fans out to the routable harnesses from the `/plugin/management` snapshot.
    - That route shipped in v1.7.0; `/plugin/import` is in v1.5.2.
    - A bridge without the snapshot publishes unsupported and makes no request.
    - A 404 from `/plugin/import` also maps to unsupported.
  - A settled scan clears itself after 4 s. `CatalogRescanFailed` and `CatalogRescanPartlyFailed` carry counts
    only.
- **Viewed project.**
  - `ProjectViewingService` declares one nullable `projectId` to the bridge (`sendProjectView`). Its inputs are
    list, detail and wide-pane claims.
  - Visibility is decided per route. `sessions` shows the list claim; `newSession` and `sessionDiffs` show it only
    while the wide pane is visible.
  - There is one list-claim slot: the last writer wins, and a claim is released by identity. Archived-mode cubits
    never claim.
  - `SessionSplitShell` calls the service for its pane claim directly.
  - The bridge's `ViewedProjectPrRefreshListener` refreshes PRs on an interval for that project. Every
    `POST /sessions` also triggers a debounced background PR refresh, and PR changes reach clients as events.
- **Desktop.**
  - `desktop_sidebar.dart` (1,797 lines) has an Activity section (`session_activity_projection.dart`, sticky
    session, `deferredSessions`, a railed popout with a count pill) and a Projects section
    (`RecentSessionsResolvers.rows(idleLimit)`, “show more”). Each group creates an action-mode `SessionListCubit`.
  - `DesktopSidebarLayout` persists `width`, `collapsed`, `collapsedProjectIds`, `deferredSessions`,
    `activitySectionCollapsed` and `projectsSectionCollapsed`.
  - `desktop_home_pane.dart` has the Needs you / Running / Recent sections and `DesktopHomeStart`, which defaults
    to the first listed project, held in widget state.
  - `DesktopSessionListScreen` is the per-project page, and the last view-mode `SessionListCubit` consumer once the
    phone list is gone.
  - The desktop has no archived-sessions route.
  - `showDesktopSettingsModal` re-provides `AuthGateCubit` with `BlocProvider.value`; `DesktopSettingsTab` has
    general, harnesses, bridge, notifications and account.
- **New session.**
  - The phone loads its project list once through `NewSessionProjectsCubit`.
  - `new_session_header.dart`'s `PregoAnchorMenu` lists known projects with no search and no add.
  - `showAddProjectDialog` (`add_project_dialog.dart`) is the folder browser. `discoverProject` awaits
    `refreshProjects` before it returns.

## Product behavior and feel

- **The list never jumps** (D2):
  - New and updated sessions animate into their date group.
  - A refresh's imported sessions slide in as the scan row fades out (D12).
  - Changing the project filter crossfades the list body instead of relaying it out row by row.
- **Wide layout:**
  - The sidebar collapses and expands with a horizontal slide, and the content pane resizes alongside it.
  - Rotating an iPhone between portrait and landscape switches layouts. The open session stays open: it is the
    pushed detail in portrait and the content pane in landscape.
- **Picker.** On the phone the bottom sheet rises with the keyboard, and the search field is focused on open. On
  tablet and desktop the popover anchors to the title.
- **Refresh.** The scan row grows in under the header while it runs. It fades out when done, and a failure alert
  never replaces the row's progress while the scan is still running.
- **No sound** anywhere.

## Ownership and contracts

### `module_core`

- **`SessionListFilterTracker`** (new, `@lazySingleton`, after `NewSessionSelectionTracker`).
  - It holds the runtime project filter as a `ValueStream<String?>`.
  - It resets to `null` when the filtered id leaves `ProjectListService.listedProjects`, and on a computer switch,
    detected with `ConnectionService` plus `TargetBridgeChangeTracker` as `RecentSessionInventoryService` does.
  - It has no other inputs, and only `AllSessionsCubit.selectProject` writes it.
- **`RecentSessionsLoaded`** gains `archivedSessions`, projected by the inventory through
  `SessionListService.visibleSessions(filter: archived)`. Activity and list state already come from the
  inventory's projections, so no cubit re-derives them.
- **`AllSessionsCubit`** (new, `active` or `archived` mode). It reads:
  - the scoped `RecentSessionInventoryService`, for sessions, activity and list state;
  - the scoped `ProjectInventoryService`, for names and the listed projects;
  - the filter tracker.

  It also owns:
  - query and quick-filter inputs (`setQuery`, `setQuickFilter`);
  - `selectProject`, which is the only write to the filter tracker.

  It emits:
  - a flat, ordered row list (session, project, flags), sorted by last update and never by status;
  - chip counts;
  - per-project failures, for retry rows;
  - `defaultProjectId` (D15): the filter, otherwise the project of the newest session, otherwise `null`.

  Date headings stay a `module_app_ui` formatter over that order, as `SessionListContent` does today. That keeps
  one grouping implementation.

  For viewed-project claims, active mode only:
  - It holds the list claim while a filter is set. The claim is marked ready when the filtered entry becomes
    `RecentSessionsLoaded`, and failed when it becomes `RecentSessionsFailed`.
  - It owns the wide-pane claim, which shells report through `setPaneVisible`.
  - “All projects” claims nothing, because the wire carries one project.
  - Archived mode never claims.

  One active-mode instance lives at the signed-in scope, so the narrow home and the wide sidebar share it across
  rotation. The Archived screen creates its own archived-mode instance.
- **Row actions** keep the existing action-mode `SessionListCubit`. It is provided lazily per row (a lazy
  `BlocProvider` builds nothing until a menu is used), as desktop sidebar groups do today.
- **Launch placeholders** keep their owner, `ProjectLaunchRowsCubit`, hosted by the list as the desktop sidebar
  does today. Each project's placeholders sit at the top of Today.
- **`ProjectViewingService`** route mapping:
  - `home` shows the list claim, as `sessions` does today.
  - `newSession`, `sessionDetail` and `sessionDiffs` show it only while the wide pane is visible.
  - Desktop reports its sidebar as the wide pane while the sidebar is expanded.
- **`SessionListRefreshService`.** `DesktopSidebarRefreshService` moves into `module_core` as this `@injectable`
  service, taking the scoped inventories as factory params.
  - It runs `refreshProjects`, the inventory refresh and `CatalogRescanService.startAll`.
  - It reports whether the reload succeeded.
- **`SessionListRefreshCubit`** replaces `DesktopSidebarRefreshCubit`.
  - It also projects `CatalogRescanService`'s state for the scan row.
  - Every pull and Refresh button calls this cubit, never a service.
- **`CatalogRescanService`** keeps `startAll`, progress, and its 4 s self-clear after settling. It loses
  `start(pluginId)`, `cancel` and `dismiss`.
  - Settled failures name their failed plugin ids, so the UI can show harness names.
  - `unsupported` (a bridge older than v1.7.0) settles silently, so the refresh is only a reload (D13).
- **`RouteSource.projectPageVisibility`** becomes `homeVisibility`, so `ProjectInventoryService`'s two refresh
  triggers keep working.

### `module_app_ui`

- **`SessionScope`** (new). It is the signed-in provider of both inventories, `ProjectListCubit`,
  `SessionListRefreshCubit`, `PendingSessionArchiveCubit` and `SessionLaunchCubit`; from step 7.b it also provides
  the active `AllSessionsCubit`.
  - The phone wraps its signed-in routes with it.
  - `DesktopCockpitCubitProvider` composes it and keeps only the desktop-specific cubits.
  - No route creates its own inventory, so `projectInventoryLoaded` keeps one reporter.
- **`CatalogScanFailureAlerts`** (new listener widget in `SessionScope`) shows the D12 alert, the one alert owner
  on every surface.
- **`AllSessionsList`** is the list component: date headings, rows, retry rows, the scan row, launch placeholders,
  search and chips.
- **`ProjectPicker`** is the switcher in filter mode, led by “All projects”, and the picker in new-session mode, led
  by “Open another folder…”.
- **`SessionSidebarShell`** is the sidebar plus content pane at ≥700 pt, with a footer slot. It reports pane
  visibility to `AllSessionsCubit`.
- Also here: `ProjectsSettingsView` and the updated `SessionTile`.

### `app`

- The route tree.
- The home screen, which hosts onboarding, offline and disconnected, moved from `project_list_screen.dart`.
- The mobile sidebar footer.

### `desktop`

- The cockpit shell puts `AllSessionsList` in its sidebar with the desktop footer extras.
- `DesktopSettingsTab.projects`; the modal re-provides the cockpit's `ProjectListCubit` with `BlocProvider.value`.
- An archived-sessions route.

### Route tree (from step 7.b)

```
/sessions                                  home: phone list; desktop DesktopHomePane
/sessions/new?project=<id>                 new session (project optional)
/sessions/:projectId/:sessionId            session detail
/sessions/:projectId/:sessionId/diffs      diffs
/archived-sessions?project=<id>            Archived list (step 7.a)
/archived-sessions/:projectId/:sessionId   archived detail
/settings/projects                         Settings › Projects (step 4)
```

- `AppRouteDef.projects` becomes `home`. `newSession`, `sessionDetail`, `sessionDiffs`, `archivedSessions` and
  `archivedSessionDetail` are redefined in place.
- Every consumer listed under *Current behavior* moves to `home`, so desktop serves `home` from step 7.b.
- The per-project `sessions` def is renamed `projectSessions` and kept at `/projects/:projectId/sessions` for the
  desktop project page only, until step 11.
- Notifications open `[home, sessionDetail]`. `closeDeletedSessionRoute` returns to `home`.
- With no `project`, new session opens with the picker and nothing selected. It lists the known projects under
  “Open another folder…”, and with an empty inventory it shows only that entry (the zero-project state). The
  `NewSessionCubit` is created once a project is chosen.

## Compatibility

- No wire change. Bridges older than v1.7.0 keep working, because refresh degrades to a reload (D13). The client
  stops calling `DELETE /plugin/import`, but the bridge route stays for released apps.
- `DesktopSidebarLayout` drops four fields. The stored JSON's extra keys are ignored on decode, so no migration is
  needed.
- Routes are in-app only. Notification payloads carry ids, not paths.

## Complexity budget

- **New mutable state:**
  - the tracker's one `String?`;
  - `AllSessionsCubit`'s query, quick filter, derived rows, one optional list claim and one pane claim;
  - the touch sidebar's runtime `collapsed` flag.
- **Removed mutable state:**
  - catalog-scan cancellation (`_pendingStarts`, `_cancelling`, `_cancellingPluginIds`) and dismissal;
  - desktop Activity: sticky session, `deferredSessions`, fold state and popout;
  - per-project fold and limits;
  - the view-mode `SessionListCubit`'s claim, navigate-back refresh, git context and scan projection;
  - the second phone inventory pair;
  - `NewSessionProjectsCubit`.
- **Deliberately not added:**
  - an all-projects bridge endpoint;
  - a multi-project view declaration;
  - a persisted filter or a persisted touch-sidebar state;
  - unhide UI (hide stays one-way, as today);
  - a status-ordered section;
  - a per-harness scan.

## Cleanup

All of it is caused by this change, and each step removes what it obsoletes:

- **Step 2.a:** `DesktopSidebarRefreshService` and its cubit (moved), and `ProjectListCubit`'s and
  `ProjectInventoryService`'s catalog-scan methods and `catalogScan` state.
- **Step 2.b:**
  - the deep-pull gesture (`PregoDeepRefresh`, the deep threshold, the pull caption);
  - the scan menu items;
  - the per-harness scan (`startCatalogScanFor`, `dismissCatalogScanOutcome`, and the Settings row);
  - `CatalogRescanService.start`, `cancel` and `dismiss`;
  - the row's Cancel and Dismiss;
  - `SessionListCubit.cancelCatalogScan` and `dismissCatalogScan`;
  - the client's `cancelCatalogImport` API and repository calls.
- **Step 3:** `NewSessionProjectsCubit`, the plain anchor menu, and the dead `ProjectListCubit.createProject` with
  `ProjectInventoryService.createProject`.
- **Step 7.a:** the per-project Archived screen wiring.
- **Step 7.b:** phone registrations of the per-project list route.
- **Step 8:** whatever 7.b left unreferenced:
  - the Projects screen (`project_list_screen.dart`, `project_list_view.dart`, `activity_tile.dart`);
  - the phone `_SessionListPane`, `SessionListScaffold` and `SessionListPanel`;
  - phone `SessionListCubitProvider` wiring;
  - duplicated label logic, folded into `project_path_labels.dart`.
- **Step 9:** `SessionSplitShell`, `EmptySessionDetailPanel` and `session_split_scope.dart`.
- **Step 10.b:**
  - the activity projection (`session_activity_projection.dart`);
  - `RecentSessionsResolvers.rows` limits and “show more”;
  - the sidebar rail, popout and count pill;
  - section headers and fold state;
  - the four layout fields.
- **Step 11:**
  - `DesktopSessionListScreen`, the `projectSessions` def, and the desktop home sections;
  - the view mode of `SessionListCubit` and `SessionListCubitProvider`;
  - `SessionListFilteredContent` and `SessionListLaunchRowsCubit`;
  - `RecentSessionsCubit`, once the palette reads `AllSessionsCubit`.

## Steps

Series total: 13. Titles are exact. Each implementation step updates the regression documents it touches, and step
12 only reconciles. Further clean splits are pre-approved when a PR would exceed about 1,500 changed lines.

| Step | Title | Est. lines |
|---|---|---|
| 1 | 🌱 [app-simplification] Publish the app-simplification plan [step 1/13] | 500 |
| 2.a | ⚙️ [app-simplification] Share one session scope and make every refresh import [step 2.a/13] | 900 |
| 2.b | 🌿 [app-simplification] Remove scan cancel, dismiss, deep pull and per-harness scan [step 2.b/13] | 1,200 (mostly deletions) |
| 3 | ⚙️ [app-simplification] Make the new-session picker searchable with Open another folder [step 3/13] | 1,000 |
| 4 | ⚙️ [app-simplification] Add Settings › Projects [step 4/13] | 700 |
| 5 | 🌿 [app-simplification] Lead session rows with the harness logo and show the project [step 5/13] | 400 |
| 6 | 🚧 [app-simplification] Add the all-projects session list model [step 6/13] | 1,000 |
| 7.a | ⚙️ [app-simplification] Show archived sessions from every project [step 7.a/13] | 900 |
| 7.b | 🚧 [app-simplification] Make the all-projects list the home [step 7.b/13] | 1,500 |
| 8 | 🌿 [app-simplification] Remove the Projects screen and per-project phone list [step 8/13] | 1,500 (deletions) |
| 9 | 🚧 [app-simplification] Show the sidebar on wide phones and tablets [step 9/13] | 1,200 |
| 10.a | ⚙️ [app-simplification] Put the shared list in the desktop sidebar [step 10.a/13] | 900 |
| 10.b | 🌿 [app-simplification] Remove desktop Activity, the rail and folded sections [step 10.b/13] | 1,300 (deletions) |
| 11 | ⚙️ [app-simplification] Open desktop on the composer and remove the project page [step 11/13] | 1,300 |
| 12 | 🌱 [app-simplification] Reconcile regression documents [step 12/13] | 300 |
| 13 | 🌱 [app-simplification] Run the L3 matrix and retire the plan [step 13/13] | 100 |

Dependencies:

- **2.a and 5** are independent; 2.b follows 2.a.
- **3 follows 2.a** (`SessionScope`), 4 follows 3, and 6 follows 2.a and 5.
- **7.a follows 6**; 7.b follows 3, 4 and 7.a; 8 follows 7.b.
- **9 follows 8**; 10.a follows 9; 10.b follows 10.a; 11 follows 10.b.
- **12 follows every implementation step**, and 13 comes last.

Step 7.b is not split further. The route tree and the phone home must switch together, because the per-project
pages cannot sit inside the new tree. A route-only step would change every path twice.

### Step 1 — Publish the plan (🌱)

This document and `TRACKER.md`. Verification: Markdown only.

### Step 2.a — One scope, one refresh (⚙️)

- **Scope.**
  - Add `SessionScope` in `module_app_ui`, `SessionListRefreshService` in `module_core` (moved from
    `module_desktop_core`, now adding `startAll`) and `SessionListRefreshCubit`.
  - The phone wraps its signed-in routes in `SessionScope` through an outer signed-in ShellRoute (splash and login
    stay outside), and the Projects screen drops its own providers. `PendingSessionArchiveCubit` and
    `SessionLaunchCubit` move from above the router into the scope, so they end with sign-out.
  - `DesktopCockpitCubitProvider` composes `SessionScope`.
- **Refresh.**
  - The Projects pull and the desktop sidebar refresh call `SessionListRefreshCubit.refresh`.
  - The per-project session lists' pulls (phone list, split pane, Archived) and the desktop project page's Refresh,
    which reloads that page's own per-project list, call a new `SessionListCubit.refreshAndImport`, which does its
    own reload plus `startAll`. Those lists are gone in step 8.
    - This is a deliberate transitional exception. That list's rows come from its own cubit, not from the
      inventories the refresh cubit reloads.
    - Both entry points start the same `CatalogRescanService` operation, so import state keeps one owner.
  - The scan rows read the refresh cubit's scan state. `CatalogScanFailureAlerts` shows the D12 alert from
    failed plugin ids, and the service logs each failure.
  - Remove the `ProjectListCubit` and `ProjectInventoryService` scan methods and `catalogScan` state.
- **Verification:**
  - Unit tests: the refresh service and cubit (success, reload failure, unsupported is silent, failed ids).
  - Widget tests: a pull calls the cubit, and the alert shows.
  - Analyze `module_core`, `module_app_ui`, `app`, `desktop` and `module_desktop_core`.
  - Headless iOS simulator: a pull on a live dev bridge shows progress, then imported sessions.
- **Regression docs:** `projects-and-sessions.md`, `desktop-cockpit-shell.md` and `plugin-setup-and-lifecycle.md`.

### Step 2.b — Remove scan controls (🌿)

- **Remove** everything listed under *Cleanup* for 2.b.
- **Row.** The scan row fades out with a size transition when the service self-clears.
- **Verification:**
  - Service tests trimmed to `startAll`, settle and self-clear.
  - A widget test for the fade.
  - Analyze the touched packages.
- **Regression docs:** `plugin-setup-and-lifecycle.md` and `projects-and-sessions.md`.

### Step 3 — Searchable picker with Open another folder (⚙️)

- **`ProjectPicker`.**
  - Both modes (D14), backed by `ProjectListCubit` from `SessionScope`.
  - A bottom sheet on the phone, lifted by `viewInsets`, and a popover on wide layouts and desktop.
  - Paths shown only on name collisions, via `project_path_labels.dart`.
- **Open another folder.** “Open another folder…” calls `showAddProjectDialog`, and its `onProjectAdded` selects
  the new project.
- **Phone wiring.** The phone new-session screen uses the live list; remove `NewSessionProjectsCubit` and the dead
  `createProject` pair.
  - The phone header hides only while the composer holds the keyboard. Hiding it for any keyboard would unmount
    the picker's trigger under its own sheet, jumping the page behind it and leaving the folder browser no
    context to open from.
- **Desktop wiring.** The desktop new-session page and the home composer use the same picker in popover form; the
  project page, which names its own project, shows no picker until step 11 removes it.
- **Verification:**
  - Widget tests: search narrows, a no-match keeps the add entry, collisions show paths, zero and one project.
  - Simulator: the portrait sheet with the keyboard, and the iPad popover.
  - macOS: the popover and the folder browser.
- **Regression docs:** `session-creation-and-options.md`.

### Step 4 — Settings › Projects (⚙️)

- **Page.**
  - `ProjectsSettingsView` reuses `ProjectTile`'s `menuEntries` (rename, hide, remove-missing) and adds “Open
    another folder…”.
  - Offline, it dims like the other bridge rows.
- **Routes.**
  - Phone: route `settingsProjects("/settings/projects")`.
  - Desktop: `DesktopSettingsTab.projects`, with the cockpit's `ProjectListCubit` re-provided by value.
- **Verification:**
  - Widget tests: rows, menu actions and the offline state.
  - A simulator screenshot and a macOS screenshot.
- **Regression docs:** `projects-and-sessions.md` and `desktop-cockpit-shell.md`.

### Step 5 — Row logo and project label (🌿)

- **Row.** `SessionTile` adds `PregoBrandLogo` before the title.
- **Project label.**
  - A nullable `projectLabel` input leads the meta line, and `null` hides it.
  - The per-project lists pass `null`.
  - The harness name leaves the meta line; launch placeholders keep showing it.
- **Verification:** widget layout tests for long titles and a missing label, plus a simulator screenshot.
- **Regression docs:** `projects-and-sessions.md`.

### Step 6 — All-projects list model (🚧)

- **New:** `SessionListFilterTracker`, the inventory's `archivedSessions`, and `AllSessionsCubit`, as in
  *Ownership*. The cubit is not wired to any screen yet.
- **Verification.** Unit tests:
  - the merge order;
  - a status change never moves a row;
  - query and chips, with counts;
  - the filter, and its reset on a computer switch and on project removal;
  - archived ordering;
  - `defaultProjectId`;
  - the claim taken, made ready, failed and released;
  - pane visibility;
  - a failed project entry.
- **Regression docs:** none until it is visible.

### Step 7.a — Archived across projects (⚙️)

- **Screen.** Add `AllSessionsList`. The Archived screen becomes an archived-mode `AllSessionsCubit` at
  `/archived-sessions` with archived detail under it. Rows show the project.
- **Entry.** The per-project list's Archived button opens it filtered to that project (D6).
- **Verification:**
  - Widget and router tests: archived across projects, filtered entry, restore, and archived detail.
  - A simulator check.
- **Regression docs:** `session-archiving-and-deletion.md`.

### Step 7.b — The all-projects home (🚧)

- **Routes.** Install the route tree above. Every `projects` consumer moves to `home`, `homeVisibility` replaces
  `projectPageVisibility`, and `ProjectViewingService` gets its new mapping.
- **Phone home.**
  - `AllSessionsList` with the title `ProjectPicker` (filter mode) and the computer switcher under it.
  - Header buttons for new session, Archived and Settings.
  - The onboarding, offline and disconnected states.
  - At ≥700 pt the new routes sit in a ShellRoute that still uses `SessionSplitShell`, with `AllSessionsList` as its
    list, until step 9.
- **New session.**
  - New session passes `defaultProjectId`.
  - Without a default, the picker opens with nothing selected and lists the known projects. Only an empty
    inventory shows the zero-project state (just “Open another folder…”).
  - Session detail creates its own action-mode `SessionListCubit`.
- **Desktop.**
  - Desktop serves `home` with `DesktopHomePane`, and its new-session and detail routes move to the new paths.
  - The project page stays at `projectSessions`.
  - Accepted until step 11: a detail opened from the desktop project page goes back to `home`.
- **Analytics:** `home` maps to `sessions`.
- **Verification:**
  - Widget and router tests:
    - home, filter and Archived;
    - the new-session default and the zero-project state;
    - the notification stack;
    - the analytics mapping;
    - `homeVisibility` refreshes;
    - claim visibility per route.
  - Simulator:
    - cold start, onboarding with no projects, and offline;
    - a filter round trip, a notification open, and a computer switch that resets the filter.
  - macOS smoke run of the moved routes.
- **Regression docs:** `projects-and-sessions.md`, `navigation-transitions.md`, `account-and-onboarding.md`,
  `multi-computer.md`, `analytics.md` and `session-creation-and-options.md`.

### Step 8 — Remove the Projects screen (🌿)

- **Delete** what 7.b left unreferenced (see *Cleanup*), with its tests and l10n strings.
- **Verification:** analyze, the phone test suite, and a simulator smoke run.

### Step 9 — Wide phone and tablet sidebar (🚧)

- **Shell.**
  - `SessionSidebarShell` replaces `SessionSplitShell`. The sidebar holds `AllSessionsList` and the mobile footer
    (computer switcher, Settings, collapse).
  - The content pane shows the composer with `defaultProjectId` when no session is open.
  - It has a restore toolbar button, a runtime-only collapsed flag and a fixed touch width.
  - It reports pane visibility to `AllSessionsCubit`.
- **Delete** the split-shell files.
- **Verification:**
  - Widget tests: the breakpoint, collapse, the empty pane showing the composer, selection, and pane visibility.
  - Simulator:
    - iPhone landscape, and portrait rotation with a session open;
    - both iPad orientations;
    - collapse and restore motion.
- **Regression docs:** `navigation-transitions.md` and `projects-and-sessions.md`.

### Step 10.a — Desktop sidebar on the shared list (⚙️)

- **Sidebar body.** `AllSessionsList` under New session and Search, which still opens the palette.
- **Footer.** It keeps the desktop extras and adds Archived, which opens a new desktop archived route.
- **Pane visibility.** The cockpit reports the expanded sidebar as the wide pane.
- **Collapse** hides the sidebar fully (D9), while resize stays.
- **Palette.** Its project entries call `AllSessionsCubit.selectProject`.
- **Verification:**
  - Desktop widget tests.
  - macOS: list, filter, collapse and restore, resize, Archived, and the palette filter.
- **Regression docs:** `desktop-cockpit-shell.md`.

### Step 10.b — Remove desktop Activity and the rail (🌿)

- **Delete** everything listed under *Cleanup* for 10.b.
- **Verification:**
  - `dart test` for `module_desktop_core`.
  - Desktop widget tests.
  - A macOS smoke run.
- **Regression docs:** `desktop-cockpit-shell.md`.

### Step 11 — Desktop composer home; remove the project page (⚙️)

- **Home.** `DesktopHomePane` shows only `DesktopHomeStart`, defaulting to `defaultProjectId` and including the
  zero-project state.
- **Delete** everything listed under *Cleanup* for 11. The palette reads `AllSessionsCubit`.
- **Verification:**
  - Desktop router and palette tests.
  - macOS: launch on the composer, and new session from the sidebar.
- **Regression docs:** `desktop-cockpit-shell.md` and `session-creation-and-options.md`.

### Step 12 — Reconcile regression documents (🌱)

Reconcile `projects-and-sessions.md`, `desktop-cockpit-shell.md`, `session-creation-and-options.md`,
`navigation-transitions.md`, `plugin-setup-and-lifecycle.md`, `account-and-onboarding.md`, `multi-computer.md`,
`analytics.md`, `bridge-connectivity.md`, `session-archiving-and-deletion.md` and `quota-auto-continuation.md`.
Each must describe the shipped behavior, with no tombstones for removed screens.

### Step 13 — Run the L3 matrix and retire (🌱)

Run the matrix below, record the results in `TRACKER.md`, and move the plan to
`.plan/completed/app-simplification/`.

## Verification and regression matrix

- **Highest level: L3 Release.** This replaces the main navigation and the refresh path on every surface.
- **Headless iOS simulator** (slot device `sesori-dev-{x}`, live dev bridge):
  - **iPhone portrait:**
    - cold start on the merged list;
    - date groups, with a status change never moving a row;
    - a filter round trip;
    - Archived across projects;
    - new session with the default project, with “Open another folder…”, and with no projects;
    - a pull refresh imports, the row fades out, and new rows slide in;
    - a notification opens over the list;
    - onboarding;
    - offline;
    - a computer switch resets the filter;
    - Settings › Projects rename and hide.
  - **iPhone landscape:** the sidebar with the composer pane, opening a session, collapse and restore, and rotation
    with a session open.
  - **iPad portrait and landscape:** the same sidebar checks, plus the picker popover.
- **macOS desktop** (steps 3, 4, 10.a, 10.b, 11):
  - the sidebar list and filter;
  - collapse and resize;
  - launch on the composer;
  - the palette filter;
  - Archived from the footer;
  - the folder picker;
  - Settings › Projects.
- **Plugins.** Refresh across every harness installed on the test machine. A failing harness, and a bridge older than
  v1.7.0, show the documented degradation. No plugin behavior changes.
- **Platforms.** Android, Windows and Linux are covered by shared widget and unit tests. Nothing here is
  platform-specific beyond the macOS desktop shell.
- **Reductions.** Any reduction needs explicit user acceptance recorded here before retirement. None has been
  accepted.

## Risks and accepted behavior

- **Many projects, many requests.** The merged list issues one `POST /sessions` per listed project, as the desktop
  sidebar already does. Accepted until it is observed to be slow; an all-projects endpoint would be a later bridge
  change.
- **“All projects” has no viewed project.** PR badges then refresh on every list fetch and on pull, but not on the
  bridge's viewed-project interval. They update on the next fetch.
- **A filter resets on restart** (D5), on a computer switch, and when its project leaves the list.
- **Hidden projects stay hidden.** Their sessions are absent from the merged list, as from Projects today.
- **Rotation on iPhone switches layouts.** The open session is kept. A half-typed new-session draft follows the
  composer's existing draft behavior.
- **Transitional desktop back stack.** Between steps 7.b and 11, a session opened from the desktop project page
  goes back to `home`.

## Later phases (rough intent only)

- Revisit an all-projects session endpoint if per-project fan-out proves slow for users with many projects.
- Consider persisting the filter or the touch sidebar state if users ask for it.

## Open questions

None. D1–D16 stand until the user overrides them.
