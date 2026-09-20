# Step 2 — New session is the primary action

## Scope

- The sidebar header's labeled primary button is **New session** and shows its
  shortcut (`⌘N`, `Ctrl+N` on Windows/Linux). **New project** is a small
  folder-plus icon button beside it with a tooltip; it hides with the collapsed
  sidebar, where the home pane still offers it. Step 4 moves it onto the
  Projects header.
- `DesktopCockpitShell` owns one resolver for the button and `Cmd/Ctrl+N` (D4):
  the open project, else the most recently active one (the inventory's existing
  order); with no project it opens the New project dialog; before the inventory
  has loaded it does nothing. An open project that is missing from the
  inventory (hidden meanwhile) is never swapped for another one. The router's
  route-bound `Cmd/Ctrl+N` binding, which was a no-op outside a project route,
  is deleted with its test.
- One noun (D5): `sessionListNewTask` is deleted for `sessionListNewSession`
  ("New session", phone and desktop); the empty sessions list, the archived
  sessions title and the notification onboarding line say "session". The
  sub-agents bar's task strings stay with step 15.
- No wire, database, persisted-layout or analytics change. The existing
  session-creation outcome event stays authoritative.

## Automated Evidence

Measured checkpoint: commit `ae744ac76e22537ec7e9b66805a44e4838c5bb1e` with a
clean working tree, Flutter 3.47.4 from `.tool-versions`. Every command below
exited 0. No log files were kept; CI on the PR is the durable record. This
file's later edits are documentation only and were not re-measured.

```sh
cd client/desktop
flutter test --no-pub test/core/widgets/desktop_cockpit_shell_test.dart test/core/routing/desktop_router_test.dart
flutter analyze --no-pub
cd ../app
flutter test --no-pub test/features/session_list/session_list_bar_test.dart \
  test/features/session_list/archived_sessions_navigation_test.dart \
  test/features/new_session/new_session_screen_test.dart
flutter analyze --no-pub test/features/session_list/session_list_bar_test.dart \
  test/features/session_list/archived_sessions_navigation_test.dart
cd ../module_app_ui
flutter analyze --no-pub
```

- Desktop: 64 shell and router cases pass. The header case proves the labeled
  New session button with its shortcut, no New project label, and the icon
  button with its tooltip. The D4 cases pass on macOS, Windows and Linux key
  bindings: open project (button and shortcut, held-key repeats ignored), no
  open project (most recently active), no project at all (New project dialog),
  and an open project missing from the inventory (nothing starts).
- Phone: 61 cases pass with the renamed string.
- All three analyzer runs report no issues. Localization was regenerated with
  `flutter gen-l10n` in `client/module_app_ui`.
- Architecture review not invoked: no new or moved production class, no
  dependency, contract or lifecycle change.

## Size

**544 changed lines = 325 additions + 219 deletions** at the measured
checkpoint, including 37 generated localization lines and 50 lines of plan
files (this file as first written, and the tracker). Reproduce from the root:

```sh
git diff --numstat cc5b9f32bd57e2ab15d51296df321544f129cafe ae744ac76e22537ec7e9b66805a44e4838c5bb1e
```

The base is `git merge-base origin/main ae744ac76e22537ec7e9b66805a44e4838c5bb1e`.
The step estimate was 350; the repository soft cap is 1,500. The overage is the
re-indented sidebar header block and the shortcut coverage. Final
self-inclusive accounting belongs in the PR body.

## Regression Documents

`desktop-cockpit-shell.md` and `session-creation-and-options.md` describe the
new primary button and the shortcut's three cases; the remaining "New task" and
"archived tasks" mentions in `desktop-bridge-supervision.md`,
`projects-and-sessions.md` and `session-archiving-and-deletion.md` say
"session".
