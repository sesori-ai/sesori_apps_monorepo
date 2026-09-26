# Step 22 — Run final coverage and retire the plan

## Scope

- Executes the plan's final matrix on merged `main` and records every cell.
  A cell that was not executed is recorded as unexecuted, never as passed.
- Retires the plan to `.plan/completed/desktop-ui-polish/` and points
  `docs/ROADMAP.md` at the new path.
- Documentation only. No code, wire, database, string or user-visible change.

## Final Matrix

| Cell | Result |
|---|---|
| Client packages, automated | Passed |
| Five touched plugins, automated | Passed |
| Live Claude Code turn | Unexecuted |
| macOS desktop, L3 end to end | Unexecuted as one pass; parts ran live in steps 7 and 15 |
| iOS and Android, automated | Passed through the `app` suite |
| iOS and Android, device smoke | Unexecuted |
| Windows and Linux, build | Passed in CI |
| Windows and Linux, visual smoke | Unexecuted |

## Automated Evidence

Measured checkpoint: `main` at commit
`7603a8a196f6b73284a62e5b3681bd1fe994ca6f` with a clean working tree,
Flutter 3.47.5 (Dart 3.13.4). Every command below exited 0. No log files were
kept.

```sh
for d in module_prego module_app_ui app desktop design_catalog; do
  (cd client/$d && flutter test --no-pub && dart analyze --fatal-infos)
done
for d in module_core module_desktop_core module_auth; do
  (cd client/$d && dart test && dart analyze --fatal-infos)
done
for p in claude codex cursor copilot omp; do
  (cd bridge/sesori_plugin_$p && dart test && dart analyze --fatal-infos)
done
```

- Client: `module_prego` 326, `module_app_ui` 403, `app` 776, `desktop` 274,
  `design_catalog` 21, `module_core` 1,833, `module_desktop_core` 336 and
  `module_auth` 114 cases pass. The analyzer is clean in all eight.
- Plugins: Claude 322, Codex 461, Cursor 175, Copilot 18 and OMP 64 cases
  pass. The analyzer is clean in all five. The catalog cases list only the
  default entry, and the cases that still send "Plan" or "Ask" pass, so
  released mode values are still honoured.
- CI: every check on #1587's final head
  `3bf4d45dac4569abb0dc2974114726de8cddb6c7` passed, including the macOS,
  Linux and Windows builds. That head has the same tree as
  `1c0766043c305556584fdb02bf34eda6327f10d0`, and `main` has changed only
  Markdown since.

## Unexecuted Cells

- **macOS desktop, L3.** Not run as one end-to-end pass. No bridge was
  running on this Mac when the step ran, and the agent does not drive the
  pointer or keyboard on the user's machine. Live evidence from the series:
  the user checked the title bar, dragging, zoom, full screen and appearance
  against their bridge in step 7, and step 15's approved variant ran as the
  desktop app during its review rounds. The sidebar and Activity, rail,
  menus, project page, session page, archive with Undo, delete, new session
  page and agent entry are covered by widget and cubit tests only.
- **Live Claude Code turn.** Not run, in step 14 or here. A plugin test
  covers the same path against the fake process: a session sent "Plan" and
  then "Agent" sets the permission mode to `plan` and then `default`.
- **iOS and Android device smoke.** Not run. The `app` suite covers what the
  phone gained in steps 13 and 16–19: the shared heading and project
  selector, the timeline, the filter chips, archive with Undo and the session
  menu.
- **Windows and Linux visual smoke.** Only the CI builds ran. Native chrome,
  the floating panel and compact menus were not checked on a Windows or Linux
  machine.

## Acceptance

The user explicitly accepted the four unexecuted cells above on 2026-09-22
("i accept the current limitations"), so the plan retires. The acceptance
permits retirement; it does not claim that those cells passed.

## Regression Documents

None changed. Step 21 reconciled them with the merged series.
