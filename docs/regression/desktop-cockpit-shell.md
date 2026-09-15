# Desktop Cockpit Shell

## Capability

Desktop project navigation in a resizable sidebar, with a compact initials rail
and desktop-owned layout preferences. The sidebar and main project list share
one signed-in project inventory.

## Required Behavior

- Expanded width defaults to 260 logical pixels and clamps to 200–420. Dragging
  changes width immediately; only drag completion/cancellation, double-click
  reset, and explicit collapse toggles write layout preferences.
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
  in a visually separated footer.
- Running projects show the shared rotating outline sparkle; unread projects
  show its static filled state. Compact avatars retain the indicator. Tooltips
  and accessibility descriptions include running counts and unread status;
  live state updates also clear stale unread marks.
- A selected project follows route identity, not the displayed name. Each
  signed-in cockpit owns one project-list cubit, including the main project
  screen; leaving the signed-in shell releases it.
- Missing layout uses defaults. Failed reads/writes are logged; unavailable
  storage does not prevent navigation or in-memory layout changes.

## Coverage

| Level | Boundary / scope | Added checks |
|---|---|---|
| L1 | Client end to end; desktop; representative bridge | Sidebar renders; a project opens; Bridge and Settings remain reachable. |
| L2 | Automated; no plugin | Width clamp, drag-end-only persistence, reset, intermediate collapse/expand frames, both reduced-motion signals, temporary narrow-window mode, running/unread updates in both widths, Unicode initials, JSON round-trip, storage failure fallback. |
| L3 | Client end to end; macOS; representative live bridge | Resize feel, hover and selected rows, keyboard focus, compact tooltips, relaunch persistence, light/dark appearance, and navigation with the shared project list. |
| L4 | Client end to end; Windows/Linux | Resize/collapse, native-window size changes, and saved-layout restore. |
| L5 | No additional coverage | Lower levels still apply. |

## Failure Signals And Exploration

Look for overflow at minimum width, drag updates that stall or write per frame,
automatic collapse overwriting user preferences, missing/stale activity marks,
duplicate project inventories, or lost navigation after switching projects. Vary project-name lengths and
Unicode, window sizes, theme, and sidebar width; preserve any already-running
bridge during UI-only checks.

## Maintenance Sources

- `client/desktop/lib/core/widgets/desktop_cockpit_shell.dart`
- `client/desktop/lib/core/widgets/desktop_sidebar.dart`
- `client/module_desktop_core/lib/src/cubits/desktop_sidebar/desktop_sidebar_cubit.dart`
- `client/module_desktop_core/test/cubits/desktop_sidebar_cubit_test.dart`
- `client/desktop/test/core/widgets/desktop_cockpit_shell_test.dart`
- `.plan/active/desktop-ux/PLAN.md`
