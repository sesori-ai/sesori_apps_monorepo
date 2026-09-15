# Desktop UX — Phase 1 (release-ready cockpit)

## Status

Planned 2026-09-15; execution has started with step 2 (see `TRACKER.md`).
This is phase 1 of the desktop UX work: the changes that
remove the release-blocking UX problems with client-only work. Later phases
are listed at the end as rough intent only and get their own plans when they
start.

The plan starts before `.plan/active/desktop-app/` retires (user decision:
desktop UX is the priority). Distribution (packaging, signing, updates) stays in
the separate `desktop-distribution` plan and does not overlap with this one.

## Goal

Make the desktop app pleasant enough to release: a two-pane cockpit with a
resizable, collapsible sidebar that lists projects and their recent sessions,
settings in a modal, bridge controls in a small popover, connection state that
never shifts layout, autostart on by default, app logs on disk, and an upfront
macOS file-access ask that explains why agents need it.

Everything in phase 1 is client-side. No wire, bridge, or relay changes.

## User Report

- The three-panel split (rail, session list, detail) has fixed edges and no
  drag-to-resize.
- The middle session panel is ugly: a plain Material header, a black
  `FilledButton.icon` "New session", none of the mobile polish.
- The left rail (Bridge / Projects / Settings) makes little sense. Wanted: a
  sidebar with projects and their sessions for quick switching, a small
  settings button at the bottom (settings as a modal that blurs the rest), a
  collapse/expand control at the top, a compact mode with one- or two-letter
  project icons, a few relevant sessions per project with a "+ x more" that
  opens the full list, and Bridge as a pinned bottom control (Codex sidebar as
  the reference: pinned top and bottom items).
- The disconnected/reconnecting banner is a black strip at the top that pushes
  the whole UI down and does not match the app background.
- The Bridge screen is the landing page and is intrusive. Wanted: set it up once
  with autostart and never touch it again.
- App logs do not seem to be written to a file; only the supervised bridge log
  exists.
- macOS folder-access prompts appear as "Sesori would like to access …" while an
  agent works, and block the process until answered. That is unacceptable when
  the user is controlling the session from the phone. Ask for Full Disk Access
  upfront, and explain clearly that it is needed because of the agents.

## Current Behavior And Findings

- `client/desktop/lib/core/widgets/desktop_cockpit_shell.dart` renders a
  Material `NavigationRail` (Bridge, Projects, Settings; extended above
  1120 px) plus `DesktopSupervisionNotice` above the routed child. Labels are
  hard-coded English.
- `client/desktop/lib/core/routing/desktop_router.dart` nests a second
  `ShellRoute` for `/projects/:id/sessions/**` that mounts the shared
  `SessionSplitShell` (`client/module_app_ui/lib/src/widgets/session_split/`)
  with `DesktopSessionListPane` on the left. Split widths are constants
  (`minListPanelWidth` 320, `maxListPanelWidth` 400, ratio 0.38). The shared
  split shell and `SessionSplitScope` are also used by the mobile router for
  tablet/landscape, so they stay; desktop only stops using them.
- The landing route is `/splash` → `DesktopHome` (bridge status rows and
  Start/Stop/Take over/Launch at login/Open logs/Quit buttons).
- `client/desktop/lib/app.dart` (`_DesktopRootEffects`) mounts
  `ConnectionBanner.maybeFor` in a `Column` above the entire cockpit, outside
  any themed scaffold: that is the layout shift and the off-colour background.
  Mobile renders the same banner through the `PregoGlassScaffold` banner slot.
- `ConnectionOverlayCubit` already derives `hidden(connected)`, `reconnecting`
  (after a grace delay) and `bridgeOffline` from `ConnectionService` and the
  registered-bridges latch. It is reusable as is.
- `SessionListCubit` cannot be instantiated once per project for a sidebar:
  its initializer takes the single `ProjectViewingService` list claim (the
  service holds one `_listClaim`; a newer cubit overwrites an older one), it
  refreshes on route changes, projects catalog scans onto its state, and it
  reports failures as a screen state. The sidebar needs a much smaller owner.
- `SessionListService` already owns everything a per-project list needs:
  `listSessions` (fetch, sorted last-updated), `visibleSessions(sessions:,
  filter:, activityBySessionId:, listStateBySessionId:)` (active/archived
  filter and running-first ordering, which is what the main list renders),
  `upsertSession`, `applySessionUpdatedEvent` and `removeSession` (SSE
  patching). `SessionListRequest` accepts `limit`, but the sidebar fetches the
  full list so its top rows match the full list exactly and the "more" count is
  free.
- Bridge autostart: `BridgeControlCubit` defaults `launchAtLoginEnabled` to
  false, and `DesktopStartupOrchestrator.restoreBridgeDesiredState` starts the
  bridge only when the persisted `bridge-desired-state` file says On. A fresh
  install never writes that file until the user toggles the bridge, so nothing
  starts until they find the Bridge screen.
- `client/module_core/lib/src/logging/logging.dart` prints to stdout only.
  The desktop persists only the supervised bridge's stdout/stderr
  (`BridgeProcessLogStorage`: `logs/bridge.log` + `.1`, 5 MB). Mobile has no
  file log either; Crashlytics only sees crashes.
- macOS: the app is not sandboxed (ADR A2). Per-folder TCC prompts (Desktop,
  Documents, Downloads, removable/network volumes) are attributed to the
  responsible app, Sesori, when the bridge or an agent CLI touches them, and
  they block the calling process until answered. Full Disk Access (FDA)
  supersedes those prompts. FDA never prompts by itself: it must be granted in
  System Settings → Privacy & Security → Full Disk Access, reachable through
  `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`.
  Whether FDA is granted can be detected by trying to open
  `~/Library/Application Support/com.apple.TCC/TCC.db` for reading (EPERM
  without FDA). Keychain ACL prompts are a code-signing identity matter and
  belong to `desktop-distribution`.
- Desktop persistence pattern to reuse: `DesktopInstanceStorage` (plain files
  under the `desktop-instance` app-support directory) →
  `DesktopInstanceRepository` → service or cubit.
- `WindowHost` exposes `states` (`focused` / `unfocused` / `hidden`), which is
  enough to re-check FDA when the user comes back from System Settings.
- Prego already has the primitives this plan needs: `PregoPopover`,
  `AnchoredFlatPanel`, `PregoAnchorMenu` (right-click already wired on
  `SessionTile` and `ProjectTile` through `onSecondaryTap`),
  `AnchoredSpotlightBackdrop` (Apple-only blur gate), `PregoSwitch`,
  `PregoButtonsSolid`, `PregoButtonsIconGlass`, `PregoTag`, `PregoGlassScaffold`,
  `PregoAvatarUser`.

## Design Decisions

- **D1 — Two panes, not three.** The sidebar (projects + recent sessions) is
  the only navigation surface. The main pane hosts one routed page: home,
  session detail, all sessions of a project, new session, diffs. The desktop
  no longer mounts `SessionSplitShell`; mobile keeps it.
- **D2 — Sidebar data comes from existing cubits plus one small new cubit.**
  `ProjectListCubit` moves up to the cockpit shell (created once per signed-in
  shell). Recent sessions per project come from a new surface-neutral
  `RecentSessionsCubit` in `module_core` that holds one entry per project and
  delegates every fetch, filter, ordering and patch step to the existing
  `SessionListService` methods `SessionListCubit` already uses. The cubit adds
  no list-mutation logic of its own. It takes no project-view claim, so
  viewing semantics (`ProjectViewingService`) stay exactly as today: the
  sessions route and the detail route declare the viewed project, the sidebar
  never does.
- **D3 — "Relevant" sessions are the head of the visible list.** The first
  three rows of `SessionListService.visibleSessions(filter:
  SessionListFilter.active, …)` (running first, then last-updated, archived
  excluded: the exact order the full list renders), plus the currently open
  session as a fourth row when it is not among them. A final row reads "All
  sessions · N" and opens the full list in the main pane. No ranking
  heuristics; the count is free because the full list is already fetched.
- **D4 — Sidebar layout is desktop GUI state (C11).** Width, collapsed flag and
  collapsed project ids live in a `DesktopSidebarCubit` (`module_desktop_core`)
  persisted as one `sidebar-layout` JSON file through
  `DesktopInstanceStorage`/`DesktopInstanceRepository`. Writes happen on drag
  end and on toggles, never per frame. The cubit talks to the repository
  directly (no orchestration to justify a service), as the client checklist
  allows.
- **D5 — Connection state floats, never shifts.** Desktop drops the root
  `ConnectionBanner` mount. A Prego-surfaced pill overlays the top of the main
  pane in a `Stack`, driven by `ConnectionOverlayCubit`, fading in and out. It
  shows `reconnecting`, and `bridgeOffline` only while the supervised bridge is
  wanted On (an intentional Off is reported by the sidebar's Bridge row and the
  home pane, not by a nagging pill). That suppression is owned by the desktop
  pill widget in `client/desktop`, which combines `ConnectionOverlayState` with
  `BridgeControlCubit` state; `ConnectionOverlayCubit` in `module_core` is
  untouched and never learns about desktop supervision. The sidebar Bridge row
  always carries a status dot. Exceptional supervision states (take-over,
  login required, crash give-up) become a compact card in the sidebar bottom
  section instead of a full-width strip.
- **D6 — Bridge controls live in a popover; the Bridge screen goes away.**
  The pinned bottom Bridge row opens a `PregoPopover` with status, On/Off,
  Take over (when applicable), Start at login, Open logs, Bridge settings…,
  and Quit. `DesktopHome` is deleted; `/splash` renders a home pane (empty
  state, bridge recovery, first-run cards).
- **D7 — Settings is a modal, not a route.** A root-navigator dialog with a
  blurred/dimmed backdrop (Prego's existing glass gate decides blur versus
  dim), a left tab column (General, Harnesses, Bridge, Notifications, Account)
  and a content area with a nested `Navigator` for harness detail pages. The
  existing shared settings views mount unchanged; only the desktop wrappers
  change. Every desktop settings `GoRoute` (`settings`, `settingsProfile`,
  `settingsDefaultInput`, `settingsNotifications`, `settingsHarnesses`,
  `settingsHarnessDetail`, i.e. `buildDesktopHarnessSettingsRoute()` and the
  routes around `AppRouteDef.settings`) is removed; both
  `HarnessSettingsPresentation` variants (`modal` from new session and session
  detail, `pushed` from settings) become "open the modal at the Harnesses tab".
  The underlying route stays current while the modal is open, so
  viewed-project and attention suppression continue for the page behind the
  modal (accepted).
- **D8 — Autostart defaults on, silently, once.** When the account is
  authenticated and no `bridge-desired-state` file exists,
  `DesktopStartupOrchestrator` (the existing owner of desired-state restore)
  persists On, starts the bridge, and calls `LaunchAtLogin.enable()`. Because
  the write makes the file exist, this runs once per install and never
  overrides a later user Off. Absent-versus-Off is not representable today
  (storage maps a missing file to `off`), so the persisted read becomes
  nullable end to end. `BridgeControlCubit` gets no new subscription; it only
  re-reads the launch-at-login flag when the popover opens so the silently
  enabled default displays correctly. macOS may show its own "items added to
  run in the background" notice; that is acceptable. The user can disable both
  from the popover or Settings → Bridge.
- **D9 — Ask for Full Disk Access upfront, explain why, never block.** A new
  Layer-0 `FileAccessPermission` capability (`check()` →
  granted/denied/unsupported, `openSystemSettings()`) with an `io` adapter in
  the desktop shell. A `FileAccessCubit` re-checks when the window regains
  focus. On macOS, while denied, the home pane shows a card: "Sesori runs
  coding agents on your behalf. Without Full Disk Access macOS interrupts them
  with folder prompts that stall a session while you are away. Grant it in
  System Settings and restart the bridge if a session was already running."
  Buttons: Open System Settings / Not now (this run only). Settings → Bridge
  always shows the status row. Nothing is persisted; nothing blocks.
- **D10 — App logs go to a rotating file through one sink seam.** `logging.dart`
  in `module_core` gets only the seam: `LogRecord`, `LogSink`, `setLogSink`
  and the default `StdoutLogSink`. `module_core` stays free of `dart:io`; the
  file writers are shell-side implementations, like every other platform
  capability. Desktop: a rotating writer in `module_desktop_core` `api/`
  that reuses the rotation already implemented for `bridge.log` in
  `BridgeProcessLogStorage`, writing `logs/app.log` next to `bridge.log`.
  Mobile: a small `dart:io` sink in `client/app/lib/core/platform/` writing
  `logs/app.log` under the app-support directory (its own file, as the user
  asked). Two ~50-line writers are accepted over a new shared package. The
  `Sink` suffix is used deliberately for this Layer-0 output primitive (it
  mirrors `IOSink`; `setLogSink` mirrors the existing `setLogLevel` global).
  The Bridge popover's Open logs opens the logs folder instead of one file.
  Logs keep the repository's privacy rules: no prompts or transcript content,
  errors and paths retained.
- **D11 — Phase 1 makes no wire or bridge changes.** A bridge-side per-project
  overview route, counts, ranking, restore-last-session and log sharing are
  phase 2+ candidates listed at the end.
- **D12 — macOS title-bar integration is optional and last.** Hide the native
  title bar so the sidebar reaches the top edge with the traffic lights inside
  it (window_manager `TitleBarStyle.hidden` + drag region). If it fights the
  toolkit or breaks window restore, the step ships without it and records why.
  Windows and Linux keep native chrome in phase 1.

## Design

### Cockpit shell

`DesktopCockpitShell(child)` becomes:

```
Row
├── DesktopSidebar (width from DesktopSidebarCubit; 56 px rail when collapsed)
│   ├── header: brand mark, collapse/expand button, "+" add project
│   ├── tree: projects → recent sessions → "All sessions · N"
│   └── bottom: supervision card (only in exceptional states), Bridge row (dot + popover), Settings row
├── DesktopSidebarResizeHandle (drag; resizeLeftRight cursor; double-click resets width)
└── Expanded
    └── Stack [ SessionSplitScope(isSplit: true, child: routed page), DesktopConnectionPill ]
```

- Width bounds: 200–420 px, default 260; auto-collapse below 760 px window
  width, restore when wider (the persisted collapsed flag is the user's, the
  auto state is not written). Minimum window size stays 560 × 480.
- Compact rail rows show a two-letter project avatar (initials of the first two
  words, else first two characters) with a deterministic colour from a small
  Prego palette; a new `PregoAvatarInitials` primitive in `module_prego`.
  Tooltips carry the full name. Session rows collapse into the project avatar
  with an unseen/running dot.
- Selection follows the route: the ShellRoute builder decodes the current
  location with the existing `AppRoute.fromDef` decoders and passes
  `(projectId, sessionId)` to the sidebar.
- All new copy goes through `module_app_ui` l10n (`app_en.arb`); the shell's
  hard-coded rail labels are replaced.

### Sidebar rows

- Project header row: name, unseen dot (`ProjectListState.loaded.unseenByProjectId`),
  running indicator (`activityById`), hover-revealed "+" (new session) and
  chevron. Right-click opens the same `PregoAnchorMenu` actions the shared
  `ProjectTile` builds (rename, hide).
- Session rows: title, status (running/awaiting/unseen) from
  `RecentSessionsState`, right-click opens the shared `SessionTile` actions
  (rename, archive, delete…). Left-click navigates to session detail.
- "All sessions · N" row navigates to the project's sessions route.
- Collapsed projects keep their fetched data; expanding a never-fetched project
  calls `RecentSessionsCubit.ensureLoaded(projectId:)`.

### `RecentSessionsCubit` (module_core, Layer 4)

State: `Map<String projectId, RecentSessionsEntry>` where the entry is a sealed
`loading | failed | loaded(sessions, activityBySessionId, unseenBySessionId)`.

- `ensureLoaded(projectId:)` fetches via `SessionListService.listSessions(
  projectId:, waitForPrData: false)` and seeds `SessionUnseenTracker` exactly
  like `SessionListCubit` does (same `sinceTick` guard captured before the
  fetch).
- Rows are derived, not stored: `SessionListService.visibleSessions(sessions:,
  filter: SessionListFilter.active, activityBySessionId:,
  listStateBySessionId:)` at emit time, then the head-plus-open-session rule.
- Subscriptions: `ConnectionService.events` (session created/updated/deleted
  → `SessionListService.upsertSession` / `applySessionUpdatedEvent` /
  `removeSession` on the entry's stored list, the same calls
  `SessionListCubit` makes), `SseEventTracker.sessionActivity`,
  `SessionUnseenTracker.sessionUnseen`, `ConnectionService.dataMayBeStale`
  (refetch every loaded project), `CatalogRescanService.catalogChanged`
  (refetch every loaded project). No ordering, filtering or patching code is
  written in the cubit.
- A failed fetch keeps the entry `failed` with a retry row; it never blocks
  other projects.
- Created through `cubit_composition.dart` like the other cubits.

### Main pane pages

- `/splash` → `DesktopHomePane`: connected empty state ("Pick a session or
  press ⌘N", "Add a project" when the inventory is empty), the existing
  `DesktopBridgeRecoveryView` (moved out of the deleted project-list screen)
  for disconnected states, and the macOS file-access card.
- `/projects/:id/sessions` → the shared `SessionListScaffold` (mobile styling,
  Prego glass scaffold, FAB) with no back button; this is the "All sessions"
  page. The desktop `projects` route and `DesktopProjectListScreen` are removed.
- Session detail, new session and diffs routes become direct children of the
  top ShellRoute. Detail keeps no back arrow (the split scope already hides it).
  New session and diffs keep their existing "back" callbacks pointed at the
  project's sessions page.
- ⌘N creates a session in the project of the current route; with no project
  context it is a no-op.

### Bridge popover

`PregoPopover` anchored to the Bridge row: status header (process state and
relay link), `PregoSwitch` Bridge On/Off, Take over (only when
`BridgeControlState.canTakeOver`), `PregoSwitch` Start at login, Open logs,
Bridge settings… (Settings modal, Bridge tab), Quit Sesori. Every action calls
the existing `BridgeControlCubit` methods; `activity.locksCommands` disables
the controls exactly as today.

### Settings modal

`showDesktopSettingsModal(context:, initialTab:)` on the root navigator. Tabs:

| Tab | Content (existing views) |
|---|---|
| General | default input, account-neutral preferences currently in `DesktopSettingsScreen` |
| Harnesses | harness list + detail pushed inside the modal's nested `Navigator` |
| Bridge | shared `BridgeSettingsSection` (YOLO, warm-up, PR interval) + desktop rows: Bridge On/Off, Start at login, Take over, Open logs, File access status |
| Notifications | `DesktopAttentionPreferenceSection` |
| Account | profile + sign out (closes the modal; `AuthGate` shows login) |

Escape and click-outside close it. Because the nested `Navigator` makes
`DesktopEscapeDismissal` see a page route rather than a popup, the modal owns
its own Escape binding (a closer shortcut wins). There is no desktop
onboarding flow that needs a full-pane settings route; every entry point opens
the modal.

### First-run defaults (D8) and file access (D9)

- Persisted contract change: `DesktopInstanceStorage.readBridgeDesiredState`
  and `DesktopInstanceRepository.readBridgeDesiredState` return
  `BridgeProcessDesiredState?` (null = no file). Every current caller applies
  the `off` default itself, including `readBridgeDesiredStateForRestore` and
  `DesktopStartupOrchestrator.restoreBridgeDesiredState`, so restore behaviour
  is unchanged.
- `DesktopStartupOrchestrator.applyFirstRunBridgeDefaults()` (new method on
  the existing orchestration owner, gaining `AuthSession` and `LaunchAtLogin`
  dependencies) is called from `main.dart` next to `restoreBridgeDesiredState`.
  It checks `authSession.currentState is AuthAuthenticated` immediately and
  subscribes to `authStateStream` for later sign-ins, mirroring
  `DesktopAttentionService`. When authenticated and the persisted state is
  null it writes On through `DesktopInstanceService`, calls
  `LaunchAtLogin.enable()`, and starts the bridge through
  `BridgeProcessService`. The write makes every later check a no-op; a
  duplicate concurrent trigger is harmless because enable and start are
  idempotent. Errors are logged and never surface as a screen state.
- `BridgeControlCubit` keeps its shape; the Bridge popover calls its existing
  launch-at-login read when it opens so the switch shows the enabled default.
- `FileAccessPermission` in `module_desktop_core/foundation/platform/`;
  `IoFileAccessPermission` in `client/desktop/lib/core/platform/` (macOS
  probe; Windows/Linux → unsupported; settings deep link through the existing
  `UrlLauncher`). `FileAccessCubit` (`module_desktop_core/cubits/`) holds
  `status` and a per-run `dismissed` flag and re-checks on
  `WindowHost.states == focused`.

### Log files (D10)

- `module_core` `logging.dart`: `abstract interface class LogSink { void
  write(LogRecord) }`, `setLogSink(LogSink)`, default `StdoutLogSink`.
  `LogRecord` carries level, timestamp, message, optional error and stack
  trace. No `dart:io` enters `module_core`.
- Desktop writer: `module_desktop_core/lib/src/api/app_log_storage.dart`
  (Layer 1, beside `bridge_process_log_storage.dart`), sharing one extracted
  rotation helper with the bridge log (5 MB threshold, one backup, owner-only
  file mode on POSIX). It appends one line per record and swallows its own
  I/O failures after one stderr notice (a logger must not throw into callers).
- Mobile writer: `client/app/lib/core/platform/io_app_log_sink.dart`, the same
  behaviour in ~50 lines, rooted at `path_provider`'s application-support
  directory.
- Desktop `main.dart` installs the sink after DI resolves the
  application-support directory; mobile `main.dart` installs its own. Level
  follows the existing `logLevel` (release builds: info and above).
- `BridgeControlCubit.openLogs` opens the directory URI.

## Failure Semantics

- Sidebar persistence read failure → defaults (260 px, expanded, nothing
  collapsed) and a warning log. Write failure → warning log; the in-memory
  layout still applies for the session.
- `RecentSessionsCubit` fetch failure → that project's entry is `failed`; a
  retry row re-runs `ensureLoaded`. Reconnect (`dataMayBeStale`) refetches
  every loaded project.
- First-run defaults: a failed `LaunchAtLogin.enable()` leaves the bridge On
  and logs a warning; the popover shows the real launch-at-login state. If the
  bridge cannot start (login required, contention), the existing process
  states and supervision card apply.
- FDA probe errors other than EPERM → `unsupported` (no card, status row reads
  "Unknown"). The card never blocks anything.
- Log sink failures never reach callers; logging falls back to stdout.

## Compatibility

- No wire, bridge, relay, database or auth changes. Mobile behaviour is
  unchanged except for the added log file. Shared widgets touched
  (`SessionListService` comparator visibility, `logging.dart` sink seam) keep
  their current defaults.
- The `sidebar-layout` file is new; an absent file means defaults. No
  migration of `window-bounds` or `bridge-desired-state`.
- Internal desktop builds only exist so far; deleting `DesktopHome`, the
  desktop `projects` route and the desktop settings routes needs no
  compatibility path.

## Non-Goals (phase 1)

- Bridge-side session overview or counts, ranking beyond list order, search,
  pinning, restoring the last open session, multi-bridge sidebar sections.
- Diagnostics bundles or sharing logs from the app.
- Windows/Linux custom window chrome.
- Keychain prompt avoidance (signing identity; `desktop-distribution`).
- Drag-and-drop or paste attachments in the composer.

## Complexity Budget

New persistent state:

- `desktop-instance/sidebar-layout` (one JSON file: width, collapsed,
  collapsedProjectIds).
- `logs/app.log` + `logs/app.log.1` per app (desktop and mobile).

New in-memory mutable parts:

- `DesktopSidebarCubit` state (three fields) and its write future.
- `RecentSessionsCubit` map plus five stream subscriptions (all mutation
  delegated to `SessionListService`).
- `FileAccessCubit` status + per-run dismissed flag, one subscription.
- `DesktopStartupOrchestrator`: one added auth subscription.
- One global `LogSink` and each file writer's open file handle.

Deliberately not added: per-project refetch debounce timers (patching replaces
them), a "last open session" record, a settings deep-link route scheme, a
bridge overview endpoint, persistence for the FDA dismissal, per-folder usage
descriptions in `Info.plist`, a keychain warm-up, a sidebar search index.

## Cleanup Assessment

Included in the feature PRs (directly caused, small):

- Delete `DesktopHome`, `DesktopProjectListScreen` (its recovery view moves to
  the home pane), the split-pane composition in
  `desktop_session_list_screen.dart` and its back-button wiring,
  `DesktopCockpitDestination`, the `NavigationRail`, `DesktopSupervisionNotice`
  (replaced by the sidebar card), the nested sessions `ShellRoute`, the desktop
  `projects` and settings `GoRoute`s with `isDesktopSettingsPath`/`_openSettings`,
  and the root `ConnectionBanner` `Column` mount in `app.dart`.
- Delete desktop tests that only exercised the removed compositions.

Kept: `DesktopSessionListCubitProvider` and `DesktopSessionListScreen` (they
already provide the project-scoped `SessionListCubit` and render the shared
`SessionListScaffold`, which is the all-sessions page); `SessionSplitShell`,
`SessionSplitScope`, `EmptySessionDetailPanel`, `SessionListPanel` and the
split breakpoints, because the mobile router consumes all of them for wide
layouts.

Deferred: none. No obsolete wire or database artifacts result from this plan.

## Delivery Plan

Series slug `desktop-ux`: 12 logical steps, 13 PRs. Step 2 is split into
`2.a` (functional frame, PR ordinal 2) and `2.b` (visual/motion follow-up,
PR ordinal 3); original steps 3–12 have PR ordinals 4–13. Changed-line targets
count additions plus deletions against the merge base.

On 2026-09-15 the user explicitly requested keeping additional styling out of
PR #1488 and delivering it as a follow-up within step 2. Step 2.b includes a
clear New project action, simplified header, separated pinned footer, smooth
expand/collapse with reduced-motion support, and existing running/unread
project signals in both widths. It adds no backend requests or state ownership.
Recent-session rows remain step 3. See `steps/step-02b.md`.

| Step | PR title | Target | Scope |
|---|---|---|---|
| 1 | `🌱 [desktop-ux] Plan the desktop cockpit UX overhaul [step 1/13]` | ≤ 900 | This plan, tracker, cross-references in `desktop-app/TRACKER.md` and `docs/ROADMAP.md`. |
| 2.a | `⚙️ [desktop-ux] Add the resizable collapsible sidebar frame [step 2/13]` | ≤ 1,400 | `DesktopSidebarCubit` + `sidebar-layout` storage/repository methods; `DesktopSidebar` frame (header, resize handle, compact rail, bottom Settings/Bridge rows navigating to today's routes); `ProjectListCubit` hoisted to the shell; project rows with `PregoAvatarInitials`; replace the `NavigationRail`. Main pane untouched. |
| 2.b | `🌿 [desktop-ux] Polish sidebar styling, motion, and activity signals [step 3/13]` | ≤ 900 | Presentation-only follow-up: clear header/actions/footer, Prego typography and surfaces, running/unread project indicators from `ProjectListCubit`, animated expand/collapse with reduced motion and immediate drag resizing. |
| 3 | `⚙️ [desktop-ux] Show recent sessions per project in the sidebar [step 4/13]` | ≤ 1,200 | `RecentSessionsCubit` + composition factory, delegating to `SessionListService.visibleSessions`/`upsertSession`/`applySessionUpdatedEvent`/`removeSession`; session rows, "All sessions · N", per-project "+", collapsed project ids, right-click menus reusing tile action builders, hover states, selection from the route. |
| 4 | `⚙️ [desktop-ux] Route the main pane through the sidebar [step 5/13]` | ≤ 1,400 | Flatten the desktop router; `DesktopHomePane` (recovery view moved in, connected empty state) served at the desktop `projects` path in place of `DesktopProjectListScreen` (sidebar brand mark navigates there); all-sessions route keeps `DesktopSessionListCubitProvider` + the shared `SessionListScaffold`, minus the back button and the split-pane composition; delete the nested `ShellRoute`; `SessionSplitScope(isSplit: true)` from the shell; ⌘N plumbing point. `/splash` still renders `DesktopHome` until step 6. |
| 5 | `🌿 [desktop-ux] Overlay connection state without layout shift [step 6/13]` | ≤ 700 | Remove the root banner mount; `DesktopConnectionPill` overlay in `client/desktop` (Prego surface, fade; combines overlay state with `BridgeControlCubit` state); Bridge row status dot; supervision states as the sidebar bottom card; delete `DesktopSupervisionNotice`. |
| 6 | `⚙️ [desktop-ux] Move bridge controls into a sidebar popover [step 7/13]` | ≤ 900 | Bridge popover (`PregoPopover`) with status, On/Off, Take over, Start at login (re-read on open), Open logs, Bridge settings…, Quit; delete `DesktopHome`; `/splash` renders `DesktopHomePane` and the desktop `projects` route is removed. |
| 7 | `⚙️ [desktop-ux] Present settings as a modal [step 8/13]` | ≤ 1,300 | `showDesktopSettingsModal` with blurred/dimmed backdrop, tab column, nested `Navigator`; Bridge tab (shared section + desktop rows); remove every desktop settings `GoRoute` incl. `buildDesktopHarnessSettingsRoute()` and the path helpers; rewire every settings/harness-settings callback for both `HarnessSettingsPresentation` variants; ⌘, shortcut; modal-owned Escape. |
| 8 | `🚧 [desktop-ux] Default bridge autostart and ask for macOS file access [step 9/13]` | ≤ 1,000 | Nullable `readBridgeDesiredState` through storage/repository with `off` applied by callers; `DesktopStartupOrchestrator.applyFirstRunBridgeDefaults()` (auth-driven) called from `main.dart`; `FileAccessPermission` capability + `IoFileAccessPermission`; `FileAccessCubit`; home-pane card with the agent explanation; Settings → Bridge status row; focus re-check. |
| 9 | `🌿 [desktop-ux] Write app logs to rotating files [step 10/13]` | ≤ 700 | `LogSink`/`LogRecord`/`setLogSink`/`StdoutLogSink` in `module_core`; desktop writer in `module_desktop_core` `api/` sharing the bridge-log rotation helper; mobile writer in `client/app/lib/core/platform/`; installation in both `main.dart`s; Open logs opens the folder. |
| 10 | `🌿 [desktop-ux] Add keyboard shortcuts and macOS title-bar integration [step 11/13]` | ≤ 600 | ⌘N, ⌘, , ⌘B (toggle sidebar) via `CallbackShortcuts` at the cockpit root; tooltips with shortcut hints; macOS hidden title bar + drag region behind a single switch in `FlutterWindowHost.initialize` (D12 kill switch). |
| 11 | `🌿 [desktop-ux] Reconcile regression documentation [step 12/13]` | ≤ 600 | New `docs/regression/desktop-cockpit-shell.md`; updates listed below. |
| 12 | `🌿 [desktop-ux] Run coverage and retire the plan [step 13/13]` | ≤ 300 | Run the recorded matrix, record results, note the phase-2 handoff, move the plan to `.plan/completed/desktop-ux/`. |

Steps 5, 8, 9 and 10 are independent of each other and may be reordered if a
review stalls, provided titles and totals stay in sync. Step 8 must land after
step 6 (its Settings rows and popover switch), step 7 after step 6 (Bridge
settings… target).

Every implementation step keeps the app building and the existing desktop and
mobile test suites green. Steps 2, 3, 4 and 7 are architecture-bearing (new
classes, DI ownership, route ownership) and get the implementation review;
steps 2.b, 5, 6, 9, 10 do not unless review evidence changes that.

## Per-Step Verification

- **Step 2.a:** `dart test` in `module_desktop_core` (cubit: defaults, clamp,
  persist on drag end/toggle, read failure → defaults); `flutter test` in
  `client/desktop` (drag changes width, collapse renders the 56 px rail,
  auto-collapse below 760 px); manual macOS run for the resize feel.
- **Step 2.b:** focused desktop widget tests for intermediate animation frames,
  reduced motion, immediate drag resizing, and live running/unread signals;
  desktop analyzer; visual review in expanded/compact and light/dark modes.
  Preserve the existing standalone bridge and do not relaunch the GUI during
  the current QA pass; distinguish render previews from native verification.
- **Step 3:** `dart test` in `module_core` (fetch, patch on created/updated/
  deleted, re-sort, unseen seeding, `dataMayBeStale` refetch, failed entry
  retry); widget tests for the head-plus-open-session rule and the "All
  sessions · N" row; manual run with a live bridge: a running session moves to
  the top, right-click actions match the main list.
- **Step 4:** router tests (`buildDesktopRoutes` paths, sessions page has no
  back button, home pane recovery states); manual run: open session from the
  sidebar, all-sessions page, new session, diffs, back callbacks; mobile
  `flutter test` in `client/app` stays green (split shell untouched).
- **Step 5:** widget tests driving `ConnectionOverlayCubit` states → pill
  visibility, no size change of the routed child (golden or size assertion);
  manual: kill the relay link, watch the pill fade in after the grace period
  and out on reconnect; turn the bridge Off, confirm no pill.
- **Step 6:** widget tests for the popover actions calling the cubit; manual
  macOS: On/Off, Take over path with a second bridge, Start at login toggle,
  Open logs, Quit.
- **Step 7:** widget tests for tab switching, nested harness detail push/pop,
  Escape and click-outside; manual: every former settings entry point (new
  session "manage harnesses", sidebar row, ⌘,) opens the right tab; sign out
  from the Account tab.
- **Step 8:** `dart test` in `module_desktop_core` for the nullable read
  (missing file → null; existing callers still default to Off), the
  orchestrator rule (authenticated + null → On + enable + start; present Off →
  untouched; signed out → nothing; enable failure → warning, bridge still On)
  and `FileAccessCubit` (focus re-check, dismiss for the run); manual macOS on
  a fresh install: sign in, bridge starts, login item appears in System
  Settings, popover switch shows it on; deny/grant FDA and watch the card and
  status row; Windows/Linux smoke: no card, status row reads unsupported.
- **Step 9:** `dart test` for the desktop writer and `flutter test` for the
  mobile writer (rotation at the threshold, owner-only mode, failure
  fallback); manual: `app.log` appears beside `bridge.log` on desktop and
  under app support on iOS; Open logs opens the folder.
- **Step 10:** widget tests for the three shortcuts; manual macOS: hidden
  title bar drag, traffic lights, window restore after relaunch; if the title
  bar is cut, the PR body says so and why.
- **Step 11:** docs validation only.
- **Step 12:** the matrix below, results recorded in `steps/step-12.md`.

## Regression Documentation And Final Matrix

Affected feature documents:

- New: `docs/regression/desktop-cockpit-shell.md` (sidebar, resize/collapse
  persistence, recent-session rows, main-pane routing, connection pill,
  supervision card, bridge popover, settings modal, shortcuts, title bar).
- Update: `desktop-bridge-supervision.md` (first-run defaults, launch-at-login
  default, popover controls, logs folder, file-access status),
  `projects-and-sessions.md` (desktop sidebar tree and all-sessions page),
  `bridge-connectivity.md` (desktop pill), `session-creation-and-options.md`
  (desktop entry points: sidebar "+", ⌘N), `account-and-onboarding.md`
  (post-sign-in defaults, file-access card), `notifications.md` (desktop
  attention preference now in the settings modal).

Highest coverage level: **L3 client end to end** on macOS desktop against a
live supervised bridge, plus **Packaged/external** checks for launch-at-login
registration and Full Disk Access (they need a real macOS login item and
System Settings). Mobile: **L2** automated for the shared touches plus one iOS
smoke for the log file and the unchanged banner.

| Platform | Level | Boundary | Scope |
|---|---|---|---|
| macOS desktop | L3 + packaged | Client end to end, live supervised bridge | Full checklist: sidebar, routing, pill, popover, modal, first-run, FDA, logs, shortcuts, title bar |
| iOS | L2 + smoke | Automated + device | `client/app` suites; log file exists; banner unchanged |
| Android | L2 | Automated | `client/app` suites |
| Windows, Linux | smoke | Client end to end | Build, sidebar resize/collapse, popover, modal, logs folder, no FDA card |

Accepted reduction: Windows and Linux run a smoke pass rather than the full L3
checklist, carrying over the reduction the user accepted for `desktop-app`.
The user accepted this on 2026-09-15 when approving the plan; step 12 may
retire the plan under this matrix.

## Risks And Accepted Limits

- Fetching every expanded project's full session list at sign-in costs one
  request per project. Accepted for phase 1; a bridge overview route is the
  phase-2 fix if it shows.
- The sidebar declares no viewed project, so notification suppression while
  only the sidebar is in use equals today's behaviour on the home route.
  While the settings modal is open, the page behind it stays "viewed".
- FDA detection is a heuristic probe on a system file; a false "denied" shows a
  dismissible card, a false "granted" hides it. Both self-correct on the next
  focus re-check. Granting FDA may require restarting the bridge for a running
  agent; the card says so.
- Silent launch-at-login registration triggers macOS's own background-items
  notice; the user accepted that.
- Keychain prompts remain until the signing identity is stable
  (`desktop-distribution`).
- Hidden title bar (D12) may be dropped without replanning.
- Multiple `SessionListCubit`-style behaviours (catalog scan projection,
  route-return refresh) are intentionally absent from the sidebar.

## Plan Review

`architecture-plan-review` ran on 2026-09-15 through a sub-agent: accept with
changes. Applied without re-review: ordering and patching now delegate to the
existing `SessionListService` methods instead of a new comparator (D2, D3,
step 3); the persisted desired-state read becomes nullable and the first-run
default moves from `BridgeControlCubit` to `DesktopStartupOrchestrator` with an
`AuthAuthenticated` check (D8, step 8); the rotating file writers move out of
`module_core` into `module_desktop_core` and the mobile shell, leaving only
the sink seam in `module_core` (D10, step 9); the desktop pill owns the
"wanted On" suppression (D5); every desktop settings route is removed, no
onboarding exception (D7); `DesktopSessionListCubitProvider`,
`SessionListPanel` and `EmptySessionDetailPanel` are kept (cleanup); the home
pane is hosted at the `projects` path between steps 4 and 6 (steps 4, 6).

## Relation To Other Plans

- `desktop-app`: MT Gate C stays pending. Its shell and navigation checks
  (sections C2/C5 of `MT_GATE_C.md`) are superseded by this plan's step-12
  checklist; its harness, attention, mobile-regression and release-safety
  sections are unaffected and can run on any build after step 7. Steps 21–22 of
  `desktop-app` proceed independently.
- `desktop-distribution`: parallel; owns signing, keychain identity, packaging
  and updates. Nothing here depends on it.

## Later Phases (rough intent only; planned when they start)

- **Phase 2 — data and depth:** bridge-side per-project overview route (one
  call for all projects, counts, activity) replacing per-project fetches;
  shared list instances between sidebar and main pane; restore the last open
  session on launch; pinned/recent sections; sidebar search.
- **Phase 3 — diagnostics and polish:** share/export a diagnostics bundle from
  Settings; drag-and-drop and paste attachments in the composer; multi-window
  or detachable sessions if wanted; Windows/Linux custom chrome.
- **Phase 4 — multi-bridge cockpit:** sidebar sections per registered bridge,
  bridge switching, remote-bridge supervision affordances.

## Expected Result

After step 12 the desktop app opens on a two-pane cockpit: a resizable sidebar
listing projects and their recent sessions with a pinned Bridge control and a
Settings button at the bottom, a themed connection pill that never moves the
layout, settings in a blurred modal, no Bridge landing screen, bridge and
launch-at-login on by default after the first sign-in, a clear upfront request
for macOS Full Disk Access that explains the agent reason, and `app.log` next
to `bridge.log`. Mobile behaviour is unchanged apart from its own `app.log`.
