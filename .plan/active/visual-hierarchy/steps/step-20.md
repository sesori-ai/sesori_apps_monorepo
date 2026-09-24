# Step 20 — Command palette

## What changed

- `module_core`'s title matcher gains `titleMatchRanges`: the merged, sorted
  ranges where a query's words occur in a title, for highlighting.
- `client/desktop` gains `desktop_command_palette.dart`: `DesktopCommand`
  (label, icon, shortcut, action), the `desktopShortcut`/`desktopShortcutLabel`
  helpers, and `showDesktopCommandPalette`, a dialog built on
  `PregoPickerSearchList` with Commands, Sessions (newest first, with their
  project) and Projects. Matched letters are bold in the brand colour. The
  palette snapshots the cockpit's `ProjectListCubit` and `RecentSessionsCubit`
  when it opens, so live updates cannot move rows under the highlight.
- `DesktopCockpitShell` owns one command list (New session, Toggle sidebar
  while the window can expand it, Settings, Go back). Its `CallbackShortcuts`
  binds each command's shortcut plus Cmd/Ctrl+K, replacing the inline closures.
  The router's own Cmd/Ctrl+, and Cmd/Ctrl+[ bindings moved into that list;
  the router passes `onGoBack`.
- The sidebar gains a Search row under New session, labelled with ⌘K/Ctrl+K.
- Mark as unread stays a page-only shortcut on the session page.

## Verification

- `client/module_core` `test/utils/title_matcher_test.dart` passes with the
  new ranges test.
- `client/desktop` `test/core/widgets/desktop_cockpit_shell_test.dart` passes
  on macOS, Windows and Linux, including the new palette test (order, filter,
  No matches, Enter on a session and a project, Down past a heading, Esc, the
  Search row, a command from the palette and by its shortcut);
  `test/core/routing` and `test/features/settings/desktop_settings_screens_test.dart`
  pass with their harnesses reading the shell's callbacks.
- `dart analyze --fatal-infos` clean in `client/module_core` and
  `client/desktop`.
