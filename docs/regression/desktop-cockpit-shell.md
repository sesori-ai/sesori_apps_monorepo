# Desktop Cockpit Shell

## Capability

Desktop project navigation in a resizable sidebar, with a compact initials rail
and desktop-owned layout preferences. The sidebar and home pane share one
signed-in project inventory; one shared recent-session cache feeds the tree.
The main pane hosts one full-width routed page.

## Required Behavior

- Expanded width defaults to 260 logical pixels and clamps to 200–420. Dragging
  uses the starting width plus global pointer displacement, preserving overshoot
  when reversing beyond either bound. Changes are immediate; an admitted drag
  saves once on completion/cancellation, and double-click reset saves once.
  Idle gesture cancellation does not write; explicit sidebar/project collapse toggles do.
- Expanded project controls have a 16-pixel directional scrollbar gutter.
  Trailing expand/collapse buttons remain clickable while the scrollbar is visible;
  thumb dragging still scrolls. The gutter shrinks with expansion to zero in the compact rail.
- Collapse uses a 56-pixel rail with deterministic two-grapheme project avatars
  and full-name tooltips. Expanding restores the user's width. Width and label
  transitions animate together; reduced motion disables the transition without
  delaying drag feedback.
- Windows narrower than 760 pixels temporarily collapse the sidebar without
  changing saved preferences. Widening restores the user's expanded/collapsed
  choice. The native minimum window remains 560 × 480.
- Project shortcuts open the existing sessions route. The labeled New project button uses the shared folder
  dialog and project-list cubit; the adjacent collapse control owns sidebar presentation. The compact Projects
  shortcut opens home, including empty/recovery states when the window is too narrow to expand.
  The separated footer groups This computer with refresh and Settings icon controls. Icon/status hints and
  truncated-label hints remain useful, while fully visible labels need no duplicate tooltip.
- Explicit sidebar refresh runs through Layer-3 `DesktopSidebarRefreshService` over the same scoped project and recent
  inventory services. It awaits the project phase before refreshing admitted recent entries, joining initial reads
  already in flight. An ordinary project failure still allows retained recent entries to update; either phase failing
  produces failure feedback. Useful rows stay visible. Busy controls cannot dispatch duplicate intent, and busy/idle
  refresh plus Settings expose accessible names and keyboard actions.
  A superseded caller follows the current owning read after every completion, including an already-completed successor
  followed by a newer owner. Completed failures stay observable despite retained rows. During the recent-session phase,
  removal or disposal retires pending receipts without waiting for obsolete I/O; late successes/errors cannot restore
  entries, reseed unseen state or complete a receipt twice. A batch does not wait for future catalog activity or a
  globally quiet inventory.
- Running projects show the shared rotating outline sparkle; unread projects
  show its static filled state. On macOS, preserve Prego's native platform-view
  path so spinning does not schedule recurring Flutter frames. Verify its
  scrolling, clipping, and collapse/expand hierarchy natively. Compact avatars
  retain the indicator. Tooltips
  and accessibility descriptions include running counts and unread status;
  live state updates also clear stale unread marks.
- Recent-session rows remain non-archived even when pinning the selected session.
  A live archive update removes that row without a refetch or navigation change;
  selected non-archived sessions outside the three recent rows remain pinned.
- A selected project follows route identity, not the displayed name. Each
  signed-in cockpit owns one project-list cubit, including the home pane;
  leaving the signed-in shell releases it.
- Activity appears before projects whenever any non-archived session is running or live-unseen. It spans every
  current project, including collapsed/offscreen projects, preserves project/session source order, identifies each
  session's project, and renders each priority session once. Priority IDs are excluded before each project's ordinary
  three rows plus active selected-session pin are chosen. An active selected session stays selected in Activity; an
  inactive selected session remains pinnable ordinarily. The keyed header remains structurally stable at zero height
  when Activity is empty, and keyed Prego reconciliation honors reduced motion as rows enter, leave or reorder.
- Expanded projects show the first three active visible sessions in the shared
  list's order, plus the open session when present outside that head. The
  “All sessions · N” link counts the full active visible inventory, including sessions currently prioritized in
  Activity, and opens the existing sessions page. Compact/project collapse hides ordinary rows without clearing
  cached data or hiding that project's Activity rows; per-project collapse preferences survive layout restore.
- Project hover/keyboard focus reveals New session. Right-click project and
  session menus reuse the shared rename/hide and session action flows.
  Session title tooltips, selection, running/awaiting/unread signals and
  screen-reader actions remain usable at minimum width; collapsing the rail clips
  them with the row instead of overflowing it.
- Opening the sidebar or its session action menu never claims project viewing.
  The main list/detail routes retain viewing ownership. Session mutations use
  the existing action controller and a stable sidebar presentation context. Opening a session menu first retains its
  action owner even if reconciliation removes the row/group; dismissal releases it, while selection transfers to the
  confirmation or admitted operation lease. Mark-read, rename, archive and delete finish handling before disposal.
- `ProjectInventoryService` owns project loading, refresh, mutations, live projection and catalog/reconnect handling
  independently of its presentation Cubit. The cockpit owns one factory instance; consumer replacement replays current
  data without a second load. Optimistic changes and awaited results remain synchronously visible. Disposing the
  cockpit closes the owner and fences late project-state application/unseen seeding, not merely its adapter.
  Throttled activity refresh runs only while the projects page is current; returning from another page triggers
  one immediate read without recreating a Cubit. Both shells use the shared router's topmost-page observation.
- Each winning successful project snapshot admits every current project to the scoped pure-Dart recent inventory,
  independent of expansion or viewport position. `RecentSessionInventoryService` owns admission, reads and live state;
  its Cubit only mirrors immutable snapshots and delegates explicit retry. The signed-in cockpit resolves one factory
  instance before initial project publication and disposes it on exit. A replacement Cubit sees retained data, while a
  new signed-in scope gets an empty inventory. Flutter rebuilds and project expansion dispatch no reads.
  A superseded project response cannot admit stale IDs. A successful local project hide publishes the accepted
  post-hide inventory through that same seam and fences older list responses. If a connection/reload has replaced loaded
  state before hide acceptance, one forced successor fetch replaces the superseded load and publishes its winning
  inventory. Absent IDs and their read metadata are removed; reconnect/catalog invalidation refreshes retained entries,
  including failures. Initial loading/failure stays
  project-local. Live session/activity/unread events update loaded projections.
  Loaded rows remain visible during refresh and logged refresh failures; live
  activity/unread and root lifecycle patches continue against that useful data.
  Lifecycle changes overlapping a returned snapshot trigger a coalesced fresh read before seeding.
  A response or thrown failure retains that lifecycle generation; the next loaded-inventory check
  or root lifecycle event rearms the authoritative read. Initial failures still require explicit retry.
  Closed or superseded reads cannot seed shared unseen state, and an older
  completion cannot release a newer pending read.
- The sidebar is the only navigation pane, including at minimum window width.
  All sessions, new session, detail, and diffs are sibling main-pane routes.
  All sessions uses the shared full list, archive filter, actions, scan/refresh,
  and New task button without a back arrow. Only that page creates a full list
  owner; recent-session menus remain non-viewing action scopes.
- Direct/sidebar-opened detail uses the available main-pane width without a
  redundant back arrow. Pushed details retain Back to their opener, including
  child-to-parent navigation. Archived rows open read-only. New-session creation replaces its page with
  detail. New-session/diff Back returns to the opener when pushed, or to the
  project's all-sessions page for direct entry. Deleting the open session
  returns to all sessions.
- Home directs an existing inventory to the sidebar; empty inventory offers
  Add/Open Project. Loading is labelled, failures retry the shared inventory,
  and disconnected states offer supervised bridge recovery without CLI setup.
  Shared Prego text styles and Material themes resolve the bundled package font.
- Connection status floats over the main pane without changing its bounds.
  Reconnecting appears after the shared grace period; connection lost retains
  Reconnect. Local desired Off, including cold-start/default Off before a user
  starts the bridge, suppresses bridge-offline copy—not relay recovery for
  clients using another bridge. Recovery hides the pill with a
  short fade; reduced motion disables it. Departing content neither intercepts
  input nor remains in accessibility announcements.
- The This computer row always exposes its supervised status through a dot and an
  accessible description. Takeover, login, start failure and crash-give-up
  recovery lives in the sidebar footer. Long repair guidance scrolls within a
  bounded card; compact mode keeps the primary action and full tooltip. Open
  Logs is also available in the This computer popover. Command locks still disable
  recovery mutations, and start failures do not offer nonexistent child logs.
- The canonical `/projects` home receives startup via `/splash` redirect and
  anchors notification route stacks; returning home retains shared inventory
  refresh. No separate project grid competes with the sidebar.
- A root popup temporarily suspends the covered session's viewed/activity claim,
  even when its nested page and typed route remain current. Dismissal restores
  visibility without replacing the session controller, element or composer.
  Notification activation dismisses root popups before revealing its session:
  the same session retains its page and Back stack; another gets the typed stack.
- This computer opens a flat, screen-clamped popover in expanded and compact modes
  without replacing the main pane. A Local bridge heading and process status
  precede one clear Start/Stop/Retry/Take Over action; logs/configuration are
  secondary. A crashed helper offers Retry despite retained On intent. A
  displaced running helper also offers Stop without requiring takeover. Explicit
  Stop cannot become Start if the helper exits before dispatch. Busy states
  disable mutations, not diagnostics; Settings dismisses before opening.
  Outside click and Escape dismiss without an action. App Quit and startup
  preferences belong to application controls, not local bridge controls.
- Settings is a root modal, preserving the current route, session element and
  live composer. Sidebar/⌘, (Ctrl+, elsewhere) open General; the This computer popover
  opens Bridge; session setup opens Harnesses. All tabs and Close remain usable
  at 560 × 480, with independently scrollable tabs/content at large text scales. Escape/outside dismiss;
  active text editing and owned sheets retain their closer dismissal order.
- General contains appearance, default input, launch-at-login and support/legal
  information. Bridge distinguishes connected-bridge configuration from local
  status/logs. Notifications exposes desktop attention, not mobile push options.
  Account owns supervised logout; failed logout stays open, and delayed success
  cannot pop the opener. External auth rejection also dismisses the root modal.
- One harness controller spans its modal overview/detail navigator. Back stays
  inside that flow; Close removes its sheets without cancelling upstream auth.
  Only harness detail has Back; Account's title and Close do not duplicate it.
  Modal blur/dim respects Prego accessibility/quality policy; macOS uses dim
  rather than sampling native indicators. Reduced motion removes the fade.
- On macOS, home shows optional local-agent file-access guidance while the
  protected-file check is denied. Open System Settings is primary; Not now
  dismisses for this run without blocking project navigation. Bridge Settings
  retains an independently reachable This computer permission row. Focus updates
  its status; unsupported systems hide these controls and unknown is not denial.
- Missing layout uses defaults. Failed reads/writes are logged; unavailable
  storage does not prevent navigation or in-memory layout changes.

## Coverage

These levels define required checks, not claims of completed verification.
Executed checks and outstanding native/live gaps are recorded in the step evidence.

| Level | Boundary / scope | Added checks |
|---|---|---|
| L1 | Client E2E; desktop; representative bridge | Sidebar, project opening, Bridge/Settings access. |
| L2 | Automated; no plugin | See [automated checks](#automated-checks-l2). |
| L3 | Client E2E; macOS; representative live bridge | See [live macOS checks](#live-macos-checks-l3). |
| L4 | Client E2E; Windows/Linux | Resize/collapse, native-window size changes, saved-layout restore. |
| L5 | No additional coverage | Lower levels still apply. |

### Automated checks (L2)

- Optional file-access card/dismissal, narrow layout, local Settings statuses and unsupported omission.
- Modal tab/entry selection, keyboard entry, route/element/draft preservation, nested Back/Close,
  text-edit/sheet Escape order, logout failure/late completion/auth rejection, minimum size/large text.
- Root-popup activity visibility across nested navigators; notification popup dismissal,
  same-page/Back preservation, different-session replacement, readiness and logged-failure ordering.
- Popover scope/contextual actions, locks/live updates, explicit Stop intent, expanded/compact anchoring,
  outside/Escape dismissal, preserved main pane.
- Connection grace, pill visibility, fixed content geometry, reduced motion, departing hit testing/semantics,
  sidebar recovery/actions/locks.
- Flat typed route registration, no-back all-sessions presentation, archived read-only navigation,
  new-session replacement, diff/direct-entry Back, home states, package-font resolution.
- Recent ordering/pinning, live inventory mutations, action-scope viewing isolation, invalidation/disposal,
  project-collapse persistence, shared menu/route callbacks. All-project admission happens once per entering ID,
  including collapsed/offscreen projects; priority Activity is deduplicated from ordinary rows, keeps project context,
  selection/navigation/actions, and reconciles keyed movement/reordering under reduced motion. Empty/loading/failed
  entries preserve the stable header and project-local retry. Keep loaded rows through catalog/reconnect refreshes and
  failures, including live unread false, lifecycle patches, failed-reread rearming and superseded-read completion.
  Execute those inventory cases without a mounted Cubit. Verify adapter replay/retry, independent consumer close,
  one eager factory instance per signed-in scope, and disposal before a fresh scope admits data.
- Headless explicit refresh ordering, shared-instance factory parameters, admission joining, completed failed winners,
  later owning reads, partial failure, removal/disposal and useful diagnostic causes. Presentation covers keyboard
  activation, accessible busy/idle names, disabled states, useful-row retention and success/failure notices.
- Width clamp, anchored overshoot/reversal at both bounds, admitted drag-end/cancel and reset-only persistence,
  visible-scrollbar edge hit tests and thumb dragging, intermediate collapse/expand frames with cramped
  session-row signals, both reduced-motion signals, temporary narrow-window mode, running/unread updates
  in both widths, Unicode initials, JSON round-trip, storage failure fallback.

### Live macOS checks (L3)

- Fresh-account autostart, login-item registration, optional Full Disk Access grant/deny/focus-return
  and helper inheritance.
- Settings entries/tabs, native startup preference, dialog keyboard/backdrop/accessibility and retained composer.
- Popover Start/Stop/Retry, Take Over versus Stop, logs and Settings.
- Relay drop/reconnect and intentional-Off presentation, sidebar recovery, resize feel, hover and selected rows.
- Keyboard focus, compact tooltips, relaunch persistence, light/dark appearance,
  recent-session navigation/actions on a live bridge, and native indicator scrolling/clipping
  through the tree and menus.

## Failure Signals And Exploration

Look for overflow at minimum width, drag updates that stall or write per frame,
width jumping on reversal beyond a bound, scrollbars intercepting project toggles,
automatic collapse overwriting user preferences, missing/stale activity marks,
duplicate project inventories or Activity/ordinary session rows, repeated admission on rebuild/expansion, lost project
context, a shifting empty Activity header, a second session-list pane, sidebar browsing clearing unread state,
stale/missing recent rows, a refresh reporting success from old retained data, an indicator settling before its
owning reads, duplicate refresh dispatch, unnamed icon controls, covered transcripts marked viewed,
notification opens stranded behind a popup,
wrong session-action targets, or lost navigation after switching projects. Vary project-name lengths and
Unicode, window sizes, theme, and sidebar width; preserve any already-running
bridge during UI-only checks.

## Maintenance Sources

- `client/desktop/lib/core/widgets/desktop_cockpit_shell.dart`
- `client/desktop/lib/core/widgets/desktop_sidebar.dart`
- `client/module_desktop_core/lib/src/services/desktop_sidebar_refresh_service.dart`
- `client/module_desktop_core/lib/src/cubits/desktop_sidebar/desktop_sidebar_refresh_cubit.dart`
- `client/desktop/lib/core/widgets/desktop_connection_pill.dart`
- `client/desktop/lib/core/widgets/desktop_bridge_recovery_card.dart`
- `client/desktop/lib/core/widgets/desktop_bridge_popover.dart`
- `client/desktop/lib/core/routing/desktop_router.dart`
- `client/desktop/lib/core/platform/desktop_route_dispatcher.dart`
- `client/module_app_ui/lib/src/features/session_detail/session_detail_activity_owner.dart`
- `client/desktop/lib/features/home/desktop_home_pane.dart`
- `client/desktop/lib/features/settings/desktop_settings_modal.dart`
- `client/desktop/test/features/settings/desktop_settings_screens_test.dart`
- `client/desktop/lib/features/sessions/desktop_session_list_screen.dart`
- `client/module_core/lib/src/cubits/recent_sessions/`
- `client/module_core/lib/src/cubits/session_list/session_list_mode.dart`
- `client/module_desktop_core/lib/src/cubits/desktop_sidebar/desktop_sidebar_cubit.dart`
- `client/module_desktop_core/test/cubits/desktop_sidebar_cubit_test.dart`
- `client/desktop/test/core/widgets/desktop_cockpit_shell_test.dart`
- `.plan/active/desktop-ux/PLAN.md`
