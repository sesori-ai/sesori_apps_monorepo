# Desktop UX — Phase 1 (release-ready cockpit)

## Status

Planned 2026-09-15; sidebar, main-pane and connection presentation are complete
through logical step 6 (see `TRACKER.md` and its linked verification evidence).
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

## Initial Behavior And Findings

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
  shows `reconnecting` and actionable `connectionLost`; `bridgeOffline` appears
  only while the supervised bridge is wanted On. Off, including its cold-start/
  default value before any user action, is reported by the sidebar/home. Relay
  recovery remains available to clients using another bridge. That suppression is owned by the desktop
  pill widget in `client/desktop`, which combines `ConnectionOverlayState` with
  `BridgeControlCubit` state; `ConnectionOverlayCubit` in `module_core` is
  untouched and never learns about desktop supervision. The sidebar Bridge row
  always carries a status dot. Exceptional supervision states (take-over,
  login required, crash give-up) become a compact card in the sidebar bottom
  section instead of a full-width strip.
- **D6 — Bridge controls live in a popover; the Bridge screen goes away.**
  The pinned bottom Bridge row opens a `PregoPopover` with local process status,
  one clear Start/Stop/Retry/Take Over action, and secondary logs/configuration.
  A displaced running helper also retains Stop without requiring takeover.
  App Quit and launch-at-login do not belong in this local-bridge control.
  `DesktopHome` is deleted; `/splash` redirects to the canonical `/projects` home
  pane (empty state, bridge recovery, first-run cards). Between steps 6 and 7, Bridge
  settings… opens the existing Settings route; step 7 targets the modal's Bridge tab.
- **D7 — Settings is a modal, not a route.** A root-navigator dialog with a
  blurred/dimmed backdrop (Prego's existing glass gate decides blur versus
  dim), a left tab column (General, Harnesses, Bridge, Notifications, Account)
  and a content area with a nested `Navigator` for harness detail pages. Existing
  shared settings sections are reused by purpose, rather than mounting a whole
  mobile settings page inside a tab and duplicating links or account UI. Every desktop settings `GoRoute` (`settings`, `settingsProfile`,
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
  nullable end to end. `BridgeControlCubit` gets no new subscription; Settings
  re-reads native launch-at-login when its app-startup preferences open so the
  silently enabled default displays correctly. macOS may show its own "items added to
  run in the background" notice; that is acceptable. The user can disable both
  using local bridge controls and Settings → General → Launch Sesori at login.
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

### Control-content audit (user correction, 2026-09-15)

Review purpose, labels, grouping and visual hierarchy before accepting each
remaining surface—not merely whether every planned option was implemented.
Remove irrelevant actions and reuse shared behavior without copying mobile-only
navigation or repeated settings links. Inspect the actual rendered result.

| Content | Decision and rationale |
|---|---|
| Local bridge status | Keep in Bridge popover. Separate the entity heading from its status; do not mix in client connection state, which may describe a different bridge and contradict a local Off label. |
| Start / Stop / Retry | One prominent action matching the actual process state. A stopped crash needs Retry, not Stop just because desired intent remained On. Use explicit command intents, not a potentially opposite toggle. |
| Take Over | Replace meaningless Start during local contention. For a running helper displaced from the relay, retain Stop as a quieter alternative to reclaiming ownership. |
| Bridge logs / configuration | Keep as secondary troubleshooting/configuration actions, visually below the primary control. Configuration opens the Bridge tab once step 7 lands. |
| Quit Sesori | App-scoped: belongs to application/tray controls and safe native window-close behavior, not a bridge popover or bridge settings section. |
| Launch Sesori at login | App-startup preference in Settings → General. The precise label describes what the OS launches. Native registration remains accessible through the tray during the step-6/7 transition. |
| Settings tabs | General: appearance/input/app startup; Harnesses: runtime management; Bridge: distinguish connected-bridge configuration from this computer's supervision; Notifications: desktop attention; Account: identity/sign-out. Avoid duplicating these destinations inside General. |
| First-run/FDA cards | Explain the agent benefit, scope and consequence. Offer one clear next action plus a quiet dismissal; never imply that access is mandatory or grant it automatically. |
| Shortcuts and final content pass | Hints must match real bindings. Step 11 audits labels, grouping, conditional availability and redundant options across the completed cockpit—not just documentation. |

### Cockpit shell

`DesktopCockpitShell(child)` becomes:

```
Row
├── DesktopSidebar (width from DesktopSidebarCubit; 56 px rail when collapsed)
│   ├── header: Projects overview, collapse/expand button, labeled New project
│   ├── tree: projects → recent sessions → "All sessions · N"
│   └── bottom: supervision card (only in exceptional states), Bridge row (dot + popover), Settings row
├── DesktopSidebarResizeHandle (drag; resizeLeftRight cursor; double-click resets width)
└── Expanded
    └── Stack [ routed page, DesktopConnectionPill ]
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
  `RecentSessionsLoaded` via its resolver extension, right-click opens the shared `SessionTile` actions
  (rename, archive, delete…). Left-click navigates to session detail.
- "All sessions · N" row navigates to the project's sessions route.
- Collapsed projects keep their fetched data; expanding a never-fetched project
  calls `RecentSessionsCubit.ensureLoaded(projectId:)`.

### `RecentSessionsCubit` (module_core, Layer 4)

State: `Map<String projectId, RecentSessionsEntry>` where the entry is a sealed
`loading | failed | loaded(sourceSessions, visibleSessions, activityBySessionId, listStateBySessionId)`.
The state is data-only; `RecentSessionsResolvers` derives the head-plus-open rows
and status presentation, following the existing session-list resolver boundary.

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
  (refetch every requested project), `CatalogRescanService.catalogChanged`
  (refetch every requested project, including failed/in-flight reads). No ordering, filtering or patching code is
  written in the cubit.
- A failed fetch keeps the entry `failed` with a retry row; it never blocks
  other projects. Retry reads through `SessionListService`; transport recovery
  remains outside this cubit.
- Shared session menus use a lazy per-project `SessionListMode.actions` scope,
  seeded from the recent inventory, with no initial read, project-view claim,
  or route-navigation refresh. Normal pages use `SessionListMode.view`;
  existing mutation/refresh behavior remains shared. Each menu synchronizes its
  named session from the current recent inventory without replacing other rows.
- Created directly in `DesktopCockpitCubitProvider`, resolving service dependencies
  inside `BlocProvider(create:)`.

### Main pane pages

- `/splash` → `/projects` → `DesktopHomePane`: connected empty state ("Pick a session or
  press ⌘N", "Add a project" when the inventory is empty), the existing
  `DesktopBridgeRecoveryView` (moved out of the deleted project-list screen)
  for disconnected states, and the macOS file-access card.
- `/projects/:id/sessions` → the shared `SessionListScaffold` (mobile styling,
  Prego glass scaffold, FAB) with no back button; this is the "All sessions"
  page. The canonical `projects` home stays; only `DesktopProjectListScreen` is removed.
- Session detail, new session and diffs routes become direct children of the
  top ShellRoute. Direct/sidebar-opened detail has no back arrow; pushed
  details retain Back to their opener. Desktop passes this explicitly through
  the nullable detail callback. New session and diffs retain Back to the opener
  when pushed, otherwise to the project's sessions page.
- ⌘N creates a session in the project of the current route; with no project
  context it is a no-op.

### Bridge popover

`PregoPopover` anchored to Bridge: Local bridge heading, process-status detail,
one prominent Start/Stop/Retry/Take Over action and quieter logs/configuration.
A running displaced helper retains Stop alongside Take Over. Explicit intents
use the existing serialized command owner; `activity.locksCommands` disables
mutations, not diagnostics. App preferences and Quit stay outside.

### Settings modal

`showDesktopSettingsModal(context:, initialTab:)` on the root navigator. Tabs:

| Tab | Content (existing views) |
|---|---|
| General | appearance, default input, Launch Sesori at login and account-neutral app preferences |
| Harnesses | harness list + detail pushed inside the modal's nested `Navigator` |
| Bridge | connected-bridge `BridgeSettingsSection` (YOLO, warm-up, PR interval), clearly separated local supervision, logs and File access status; no app Quit or launch-at-login |
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
- Settings exposes the existing native launch-at-login read through
  `BridgeControlCubit` when General opens; no new subscription or preference copy.
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
  and logs a warning; General preferences show the real launch-at-login state. If the
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
  desktop settings routes needs no
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
  settings `GoRoute`s with `isDesktopSettingsPath`/`_openSettings`,
  and the root `ConnectionBanner` `Column` mount in `app.dart`.
- Delete desktop tests that only exercised the removed compositions.
- Step 6 removes the dashboard-only recent-log snapshot field, buffer and
  stream. Bounded pipe draining, queued rotating persistence, and crash
  exit/count diagnostics remain; Open Logs is the diagnostic surface.

Kept: `DesktopSessionListCubitProvider` and `DesktopSessionListScreen` (they
already provide the project-scoped `SessionListCubit` and render the shared
`SessionListScaffold`, which is the all-sessions page); `SessionSplitShell`,
`SessionSplitScope`, `EmptySessionDetailPanel`, `SessionListPanel` and the
split breakpoints, because the mobile router consumes all of them for wide
layouts.

Deferred: none. No obsolete wire or database artifacts result from this plan.

## Delivery Plan

Series slug `desktop-ux`: 12 logical steps, 15 PRs. Step 2 is split into
`2.a` (functional frame, PR ordinal 2) and `2.b` (visual/motion follow-up,
PR ordinal 3). Original steps 3–6 have ordinals 4–7; step 7 is split into
`7.a` (shared composition/preference commands, ordinal 8), `7.b` (overlay
navigation, ordinal 9) and `7.c` (modal, ordinal 10). Original steps 8–12
have ordinals 11–15. Changed-line targets
count additions plus deletions against the merge base.

On 2026-09-15 the user explicitly requested keeping additional styling out of
PR #1488 and delivering it as a follow-up within step 2. Step 2.b includes a
clear New project action, simplified header, separated pinned footer, smooth
expand/collapse with reduced-motion support, and existing running/unread
project signals in both widths. It adds no backend requests or state ownership.
Indicators must retain Prego's native macOS rendering for CPU/battery efficiency;
Flutter drawing is not a substitute for native verification. Existing iOS callers
remain unchanged. Recent-session rows remain step 3. See `steps/step-02b.md`.

| Step | PR title | Target | Scope |
|---|---|---|---|
| 1 | `🌱 [desktop-ux] Plan the desktop cockpit UX overhaul [step 1/15]` | ≤ 900 | This plan, tracker, cross-references in `desktop-app/TRACKER.md` and `docs/ROADMAP.md`. |
| 2.a | `⚙️ [desktop-ux] Add the resizable collapsible sidebar frame [step 2/15]` | ≤ 1,400 | `DesktopSidebarCubit` + `sidebar-layout` storage/repository methods; `DesktopSidebar` frame (header, resize handle, compact rail, bottom Settings/Bridge rows navigating to today's routes); `ProjectListCubit` hoisted to the shell; project rows with `PregoAvatarInitials`; replace the `NavigationRail`. Main pane untouched. |
| 2.b | `🌿 [desktop-ux] Polish sidebar styling, motion, and activity signals [step 3/15]` | ≤ 900 | Presentation-only follow-up: clear header/actions/footer, Prego typography and surfaces, running/unread project indicators from `ProjectListCubit`, animated expand/collapse with reduced motion and immediate drag resizing. |
| 3 | `⚙️ [desktop-ux] Show recent sessions per project in the sidebar [step 4/15]` | ≤ 1,200 | `RecentSessionsCubit` + provider composition, delegating to `SessionListService.visibleSessions`/`upsertSession`/`applySessionUpdatedEvent`/`removeSession`; session rows, "All sessions · N", per-project "+", collapsed project ids, right-click menus reusing tile action builders, hover states, selection from the route. |
| 4 | `⚙️ [desktop-ux] Route the main pane through the sidebar [step 5/15]` | ≤ 1,400 | Flatten the desktop router; `DesktopHomePane` (recovery view moved in, connected empty state) served at the desktop `projects` path in place of `DesktopProjectListScreen` (sidebar Projects header navigates there); all-sessions route keeps `DesktopSessionListCubitProvider` + the shared `SessionListScaffold`, minus the back button and the split-pane composition; delete the nested `ShellRoute`; explicit nullable detail Back callback based on the owning page's poppability; route-selected project/New session callbacks retained for step 10. `/splash` still renders `DesktopHome` until step 6. |
| 5 | `🌿 [desktop-ux] Overlay connection state without layout shift [step 6/15]` | ≤ 700 | Remove the root banner mount; `DesktopConnectionPill` overlay in `client/desktop` (Prego surface, fade; combines overlay state with `BridgeControlCubit` state); Bridge row status dot; supervision states as the sidebar bottom card; delete `DesktopSupervisionNotice`. |
| 6 | `⚙️ [desktop-ux] Move bridge controls into a sidebar popover [step 7/15]` | ≤ 1,500 | Bridge popover (`PregoPopover`) with local status, contextual Start/Stop/Retry/Take Over, secondary logs/configuration and no app-scoped options; delete `DesktopHome`; `/splash` redirects to the canonical `/projects` home pane, preserving notification stacks and inventory return-refresh. |
| 7.a | `🌿 [desktop-ux] Prepare shared settings composition [step 8/15]` | ≤ 500 | Reusable app-information/support/legal sections and picker exports, connected-bridge title input and desktop copy; native preference refresh/explicit-set methods on the existing control owner, with fake-backed tests. No changed settings navigation or visible controls yet. |
| 7.b | `🚧 [desktop-ux] Preserve session focus across root overlays [step 9/15]` | ≤ 700 | Containing-route visibility for the existing session activity owner; root-popup dismissal through both existing route adapters, ordered before desktop notification same-session detection/replacement. No new state owner, persisted fields or Settings presentation. |
| 7.c | `⚙️ [desktop-ux] Present settings as a modal [step 10/15]` | ≤ 1,750 | `showDesktopSettingsModal` with blurred/dimmed backdrop, tab column, nested `Navigator`; Bridge tab (shared section + desktop rows); remove every desktop settings `GoRoute` incl. `buildDesktopHarnessSettingsRoute()` and the path helpers; rewire every settings/harness-settings callback for both `HarnessSettingsPresentation` variants; ⌘, shortcut; modal-owned Escape. |
| 8 | `🚧 [desktop-ux] Default bridge autostart and ask for macOS file access [step 11/15]` | ≤ 1,000 | Nullable `readBridgeDesiredState` through storage/repository with `off` applied by callers; `DesktopStartupOrchestrator.applyFirstRunBridgeDefaults()` (auth-driven) called from `main.dart`; `FileAccessPermission` capability + `IoFileAccessPermission`; `FileAccessCubit`; home-pane card with the agent explanation; Settings → Bridge status row; focus re-check. |
| 9 | `🌿 [desktop-ux] Write app logs to rotating files [step 12/15]` | ≤ 700 | `LogSink`/`LogRecord`/`setLogSink`/`StdoutLogSink` in `module_core`; desktop writer in `module_desktop_core` `api/` sharing the bridge-log rotation helper; mobile writer in `client/app/lib/core/platform/`; installation in both `main.dart`s; Open logs opens the folder. |
| 10 | `🌿 [desktop-ux] Add keyboard shortcuts and macOS title-bar integration [step 13/15]` | ≤ 600 | ⌘N, ⌘, , ⌘B (toggle sidebar) via `CallbackShortcuts` at the cockpit root; tooltips with shortcut hints; macOS hidden title bar + drag region behind a single switch in `FlutterWindowHost.initialize` (D12 kill switch). |
| 11 | `🌿 [desktop-ux] Audit controls and reconcile regression documentation [step 14/15]` | ≤ 600 | Final control-content audit (labels, grouping, scope, redundancy and state-specific actions) plus regression reconciliation listed below. |
| 12 | `🌿 [desktop-ux] Run coverage and retire the plan [step 15/15]` | ≤ 300 | Run the recorded matrix, record results, note the phase-2 handoff, move the plan to `.plan/completed/desktop-ux/`. |

Step 7's integrated snapshot `5c1cd88` measured 1,670 changed lines (56 generated).
Shared composition, copy and native preference commands landed separately in 7.a.
The modal reached 1,725 lines at `8d9faed`, including 656 lines of settings-test
replacement and 80 lines retiring an obsolete route test. Its bounded exception
keeps route retirement and modal composition atomic, without interim routes/shims.
Review then identified ordinary root-popup flows: a covered nested session stays
viewed, and notification activation leaves the popup over its destination.
Those independently useful fixes are extracted into 7.b rather than expanding
#1501's review loop. Its published branch/history are preserved; close it while
7.b lands, merge main forward (no rewrite), then reopen it as 7.c with the
large-text rail and evidence corrections. Native qualification is not waived.

Step 7.b adds no persistent or mutable business state: an immutable containing-route
boolean feeds the existing activity owner, and immutable adapter callbacks reuse
the existing readiness/navigation queues. No new subscriptions, observers, timers,
registries, caches or coordinator. Mobile implements the internal route contract
in lockstep; its notification policy and all backend contracts remain unchanged.

Step 6's target grew from 900 to 1,500 after the complete dashboard/test
retirement, causal snapshot cleanup and user-requested content audit. More than
half of the measured diff is deletion; one coherent slice avoids an interim
dead-state API or logging redesign and stays within the repository soft cap.

Step 4's render verification also corrected the existing Prego font-family
constant to match the bundled package name and removed redundant sidebar font
overrides. This small shared typography fix adds no state or renderer changes;
mobile route/shared UI/font tests cover its consumers. See `steps/step-04.md`.

Steps 5, 8, 9 and 10 are independent of each other and may be reordered if a
review stalls, provided titles and totals stay in sync. Step 8 must land after
step 7.c (General startup preferences and Bridge/FDA settings). Step 7.a follows
step 6; step 7.b follows 7.a; step 7.c follows 7.b and replaces the existing
Bridge settings… target.

Every implementation step keeps the app building and the existing desktop and
mobile test suites green. Steps 2.a, 3, 4, 5, 6 and 7 are architecture-bearing (new classes,
composition or route ownership) and receive implementation review. Reassess
later slices against the repository's actual-change rule.

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
  macOS: Start/Stop, crash Retry, Take Over versus Stop after displacement,
  logs/configuration, and compact presentation. Preserve existing bridges.
- **Step 7.a:** focused pure-Dart native preference tests and desktop-core
  analysis; shared settings consumer tests and shared-UI analysis. Verify the
  route-era desktop settings still builds independently; no production-wired
  smoke, native registration mutation or GUI/bridge launch locally.
- **Step 7.b:** focused activity-owner, route-adapter and desktop attention tests;
  real root popups above inert nested pages; same-session element/Back retention,
  different-session replacement, no-popup and readiness/failure ordering. Analyze
  the five affected client packages. No production DI, app/helper launch or native
  account/preference mutation. Existing root-popover flows make this independently valid.
- **Step 7.c:** widget tests for tab switching, nested harness detail push/pop,
  Escape and click-outside; manual: every former settings entry point (new
  session "manage harnesses", sidebar row, ⌘,) opens the right tab; launch-at-login is under General, scopes are clear
  in Bridge, and sign-out belongs to Account.
- **Step 8:** `dart test` in `module_desktop_core` for the nullable read
  (missing file → null; existing callers still default to Off), the
  orchestrator rule (authenticated + null → On + enable + start; present Off →
  untouched; signed out → nothing; enable failure → warning, bridge still On)
  and `FileAccessCubit` (focus re-check, dismiss for the run); manual macOS on
  a fresh install: sign in, bridge starts, login item appears in System
  Settings, General's startup preference shows it on; deny/grant FDA and watch the card and
  status row; Windows/Linux smoke: no card, status row reads unsupported.
- **Step 9:** `dart test` for the desktop writer and `flutter test` for the
  mobile writer (rotation at the threshold, owner-only mode, failure
  fallback); manual: `app.log` appears beside `bridge.log` on desktop and
  under app support on iOS; Open logs opens the folder.
- **Step 10:** widget tests for the three shortcuts; manual macOS: hidden
  title bar drag, traffic lights, window restore after relaunch; if the title
  bar is cut, the PR body says so and why.
- **Step 11:** audit completed control contents against the table above; inspect
  relevant renders, fix small presentation issues, and validate docs. Native or
  user-dependent checks remain in the final testing handoff.
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
pane uses the `projects` path (kept permanently after the step-6 route audit).

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
