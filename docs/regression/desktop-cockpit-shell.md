# Desktop Cockpit Shell

## Capability

Desktop project navigation in a resizable sidebar, with a compact initials rail
and desktop-owned layout preferences. The sidebar and main project list share
one signed-in project inventory; one shared recent-session cache feeds the tree.

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
  the project overview. The labeled New project button uses the shared folder
  dialog and project-list cubit. Pinned Bridge and Settings retain their routes
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
  signed-in cockpit owns one project-list cubit, including the main project
  screen; leaving the signed-in shell releases it.
- Expanded projects show the first three active visible sessions in the shared
  list's order, plus the open session when present outside that head. The
  “All sessions · N” link counts the active visible inventory and opens the
  existing sessions page. Compact/project collapse hides rows without clearing
  their cached data; per-project collapse preferences survive layout restore.
- Project hover/keyboard focus reveals New session. Right-click project and
  session menus reuse the shared rename/hide and session action flows.
  Session title tooltips, selection, running/awaiting/unread signals and
  screen-reader actions remain usable at minimum width.
- Opening the sidebar or its session action menu never claims project viewing.
  The main list/detail routes retain viewing ownership. Session mutations use
  the existing action controller; its context survives removal of a session row.
- Expanded project loads are cached per signed-in shell. Live session/activity/unread
  events update its projection; reconnect/catalog invalidation refreshes known
  projects, including failed reads. A project's retry/loading state does not
  block its siblings. Lifecycle changes during a read trigger a coalesced fresh
  snapshot. Closed or superseded reads cannot seed shared unseen state.
- Missing layout uses defaults. Failed reads/writes are logged; unavailable
  storage does not prevent navigation or in-memory layout changes.

## Coverage

These levels define required checks, not claims of completed verification.
Executed checks and outstanding native/live gaps are recorded in the step evidence.

| Level | Boundary / scope | Added checks |
|---|---|---|
| L1 | Client end to end; desktop; representative bridge | Sidebar renders; a project opens; Bridge and Settings remain reachable. |
| L2 | Automated; no plugin | Recent ordering/pinning, live inventory mutations, action-scope viewing isolation, invalidation/disposal, project-collapse persistence, shared menu/route callbacks; width clamp, drag-end-only persistence, reset, intermediate collapse/expand frames, both reduced-motion signals, temporary narrow-window mode, running/unread updates in both widths, Unicode initials, JSON round-trip, storage failure fallback. |
| L3 | Client end to end; macOS; representative live bridge | Resize feel, hover and selected rows, keyboard focus, compact tooltips, relaunch persistence, light/dark appearance, recent-session navigation/actions on a live bridge, and native indicator scrolling/clipping through the tree and menus. |
| L4 | Client end to end; Windows/Linux | Resize/collapse, native-window size changes, and saved-layout restore. |
| L5 | No additional coverage | Lower levels still apply. |

## Failure Signals And Exploration

Look for overflow at minimum width, drag updates that stall or write per frame,
automatic collapse overwriting user preferences, missing/stale activity marks,
duplicate project inventories, sidebar browsing clearing unread state, stale/missing recent rows,
wrong session-action targets, or lost navigation after switching projects. Vary project-name lengths and
Unicode, window sizes, theme, and sidebar width; preserve any already-running
bridge during UI-only checks.

## Maintenance Sources

- `client/desktop/lib/core/widgets/desktop_cockpit_shell.dart`
- `client/desktop/lib/core/widgets/desktop_sidebar.dart`
- `client/module_core/lib/src/cubits/recent_sessions/`
- `client/module_core/lib/src/cubits/session_list/session_list_mode.dart`
- `client/module_desktop_core/lib/src/cubits/desktop_sidebar/desktop_sidebar_cubit.dart`
- `client/module_desktop_core/test/cubits/desktop_sidebar_cubit_test.dart`
- `client/desktop/test/core/widgets/desktop_cockpit_shell_test.dart`
- `.plan/active/desktop-ux/PLAN.md`
