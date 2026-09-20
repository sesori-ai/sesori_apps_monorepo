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
  has loaded it does nothing. The router's route-bound `Cmd/Ctrl+N` binding,
  which was a no-op outside a project route, is deleted with its test.
- One noun (D5): `sessionListNewTask` is deleted for `sessionListNewSession`
  ("New session", phone and desktop); the empty sessions list, the archived
  sessions title and the notification onboarding line say "session". The
  sub-agents bar's task strings stay with step 15.
- No wire, database, persisted-layout or analytics change. The existing
  session-creation outcome event stays authoritative.
- 469 changed lines before this file, 37 of them generated localization output:
  above the 350-line estimate, far below the repository soft cap. The overage
  is the re-indented header block and the three-case shortcut coverage.

## Automated Evidence

- Cockpit shell: the header case proves the labeled New session button with
  its shortcut, no New project label, and the icon button with its tooltip.
  The three D4 cases pass on macOS, Windows and Linux key bindings: open
  project (button and shortcut, held-key repeats ignored), no open project
  (most recently active), no project at all (New project dialog). 63 shell and
  router cases pass.
- Phone: the sessions-list bar, archived-sessions navigation and new-session
  screen suites pass (61 cases) with the renamed string.
- Localization regenerated with `flutter gen-l10n`. `client/module_app_ui` and
  `client/desktop` analyze clean, as do the touched `client/app` tests.
- Architecture review not invoked: no new or moved production class, no
  dependency, contract or lifecycle change.

## Regression Documents

`desktop-cockpit-shell.md` and `session-creation-and-options.md` describe the
new primary button and the shortcut's three cases; the remaining "New task" and
"archived tasks" mentions in `desktop-bridge-supervision.md`,
`projects-and-sessions.md` and `session-archiving-and-deletion.md` say
"session".
