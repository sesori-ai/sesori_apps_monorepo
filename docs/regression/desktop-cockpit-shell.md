# Desktop Cockpit Shell

## Capability

Desktop project navigation in a resizable sidebar, with a compact initials rail
and desktop-owned layout preferences. The sidebar and home pane share one
signed-in project inventory; one shared recent-session cache feeds the tree.
The main pane hosts one full-width routed page.

## Required Behavior

- Expanded width defaults to 260 logical pixels and clamps to 200–420. Dragging
  changes width immediately; only drag completion/cancellation, double-click
  reset, and explicit sidebar/project collapse toggles write layout preferences.
- Collapse uses a 56-pixel rail with deterministic two-grapheme project avatars
  and full-name tooltips. Expanding restores the user's width. Width and label
  transitions animate together; reduced motion disables the transition without
  delaying drag feedback.
- Windows narrower than 760 pixels temporarily collapse the sidebar without
  changing saved preferences. Widening restores the user's expanded/collapsed
  choice. The native minimum window remains 560 × 480.
- Project shortcuts open the existing sessions route. The Projects header opens
  home pane. The labeled New project button uses the shared folder
  dialog and project-list cubit. Pinned Bridge and Settings remain available
  in a visually separated footer. A compact Projects shortcut remains available
  in empty/recovery states even when the window is too narrow to expand.
- Running projects show the shared rotating outline sparkle; unread projects
  show its static filled state. On macOS, preserve Prego's native platform-view
  path so spinning does not schedule recurring Flutter frames. Verify its
  scrolling, clipping, and collapse/expand hierarchy natively. Compact avatars
  retain the indicator. Tooltips
  and accessibility descriptions include running counts and unread status;
  live state updates also clear stale unread marks.
- A selected project follows route identity, not the displayed name. Each
  signed-in cockpit owns one project-list cubit, including the home pane;
  leaving the signed-in shell releases it.
- Expanded projects show the first three active visible sessions in the shared
  list's order, plus the open session when present outside that head. The
  “All sessions · N” link counts the active visible inventory and opens the
  existing sessions page. Compact/project collapse hides rows without clearing
  their cached data; per-project collapse preferences survive layout restore.
- Project hover/keyboard focus reveals New session. Right-click project and
  session menus reuse the shared rename/hide and session action flows.
  Session title tooltips, selection, running/awaiting/unread signals and
  screen-reader actions remain usable at minimum width; collapsing the rail clips
  them with the row instead of overflowing it.
- Opening the sidebar or its session action menu never claims project viewing.
  The main list/detail routes retain viewing ownership. Session mutations use
  the existing action controller; its context survives removal of a session row.
- Expanded project loads are cached per signed-in shell. Live session/activity/unread
  events update its projection; reconnect/catalog invalidation refreshes known
  projects, including failed reads. A project's retry/loading state does not
  block its siblings. Lifecycle changes during a read trigger a coalesced fresh
  snapshot. Closed or superseded reads cannot seed shared unseen state.
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
- The Bridge row always exposes its supervised status through a dot and an
  accessible description. Takeover, login, start failure and crash-give-up
  recovery lives in the sidebar footer. Long repair guidance scrolls within a
  bounded card; compact mode keeps the primary action and full tooltip. Open
  Logs is also available in the Bridge popover. Command locks still disable
  recovery mutations, and start failures do not offer nonexistent child logs.
- The canonical `/projects` home receives startup via `/splash` redirect and
  anchors notification route stacks; returning home retains shared inventory
  refresh. No separate project grid competes with the sidebar.
- A root popup temporarily suspends the covered session's viewed/activity claim,
  even when its nested page and typed route remain current. Dismissal restores
  visibility without replacing the session controller, element or composer.
  Notification activation dismisses root popups before revealing its session:
  the same session retains its page and Back stack; another gets the typed stack.
- Bridge opens a flat, screen-clamped popover in expanded and compact modes
  without replacing the main pane. A Local bridge heading and process status
  precede one clear Start/Stop/Retry/Take Over action; logs/configuration are
  secondary. A crashed helper offers Retry despite retained On intent. A
  displaced running helper also offers Stop without requiring takeover. Explicit
  Stop cannot become Start if the helper exits before dispatch. Busy states
  disable mutations, not diagnostics; Settings dismisses before opening.
  Outside click and Escape dismiss without an action. App Quit and startup
  preferences belong to application controls, not local bridge controls.
- Settings is a root modal, preserving the current route, session element and
  live composer. Sidebar/⌘, (Ctrl+, elsewhere) open General; the Bridge popover
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
- Missing layout uses defaults. Failed reads/writes are logged; unavailable
  storage does not prevent navigation or in-memory layout changes.

## Coverage

These levels define required checks, not claims of completed verification.
Executed checks and outstanding native/live gaps are recorded in the step evidence.

| Level | Boundary / scope | Added checks |
|---|---|---|
| L1 | Client end to end; desktop; representative bridge | Sidebar renders; a project opens; Bridge and Settings remain reachable. |
| L2 | Automated; no plugin | Modal tab/entry selection, keyboard entry, route/element/draft preservation, nested Back/Close, text-edit/sheet Escape order, logout failure/late completion/auth rejection, minimum size/large text; root-popup activity visibility across nested navigators; notification popup dismissal, same-page/Back preservation, different-session replacement, readiness and logged-failure ordering; popover scope/contextual actions, locks/live updates, explicit Stop intent, expanded/compact anchoring, outside/Escape dismissal, preserved main pane; connection grace, pill visibility, fixed content geometry, reduced motion, departing hit testing/semantics, sidebar recovery/actions/locks; flat typed route registration, no-back all-sessions presentation, archived read-only navigation, new-session replacement, diff/direct-entry back, home states, package-font resolution; recent ordering/pinning, live inventory mutations, action-scope viewing isolation, invalidation/disposal, project-collapse persistence, shared menu/route callbacks; width clamp, drag-end-only persistence, reset, intermediate collapse/expand frames with cramped session-row signals, both reduced-motion signals, temporary narrow-window mode, running/unread updates in both widths, Unicode initials, JSON round-trip, storage failure fallback. |
| L3 | Client end to end; macOS; representative live bridge | Settings entries/tabs, native startup preference, dialog keyboard/backdrop/accessibility and retained composer; popover Start/Stop/Retry, Take Over versus Stop, logs and Settings; relay drop/reconnect and intentional-Off presentation, sidebar recovery, resize feel, hover and selected rows, keyboard focus, compact tooltips, relaunch persistence, light/dark appearance, recent-session navigation/actions on a live bridge, and native indicator scrolling/clipping through the tree and menus. |
| L4 | Client end to end; Windows/Linux | Resize/collapse, native-window size changes, and saved-layout restore. |
| L5 | No additional coverage | Lower levels still apply. |

## Failure Signals And Exploration

Look for overflow at minimum width, drag updates that stall or write per frame,
automatic collapse overwriting user preferences, missing/stale activity marks,
duplicate project inventories or a second session-list pane, sidebar browsing clearing unread state, stale/missing recent rows,
covered transcripts marked viewed, notification opens stranded behind a popup,
wrong session-action targets, or lost navigation after switching projects. Vary project-name lengths and
Unicode, window sizes, theme, and sidebar width; preserve any already-running
bridge during UI-only checks.

## Maintenance Sources

- `client/desktop/lib/core/widgets/desktop_cockpit_shell.dart`
- `client/desktop/lib/core/widgets/desktop_sidebar.dart`
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
