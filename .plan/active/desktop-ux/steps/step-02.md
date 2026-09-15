# Step 2 — Sidebar Frame

## Scope

Implemented the 200–420 px sidebar, 260 px default, 56 px compact rail,
temporary collapse below 760 px, resize/reset, saved layout, project shortcuts,
and pinned Bridge/Settings actions. One `ProjectListCubit` now belongs to the
signed-in cockpit and serves both sidebar and existing project screen. Main
pane routes and shared mobile split composition are unchanged.

`DesktopSidebarLayout` is the typed persisted value and cubit state. Existing
storage/repository own its JSON boundary; writes are serialized only for user
layout commits, not drag frames. Collapsed project IDs are round-tripped for
the next sidebar-tree step. No bridge, wire, database, or account changes.

Cleanup: removed `NavigationRail`, its destination enum/path classifier, and
the project screen's duplicate cubit ownership. No other causal cleanup found.
Analytics: no new event; resizing is not an authoritative product outcome, and
desktop analytics has no approved delivery scope.

## Verification

- `client/`: `dart pub get` — pass.
- `module_desktop_core`, `desktop`, `module_prego`, `module_app_ui`:
  `dart analyze --fatal-infos` — pass.
- Desktop core sidebar/storage/repository tests — 23 passed.
- Prego initials-avatar widget tests — 2 passed.
- Desktop cockpit/router/project-recovery widget tests — 16 passed.
- Mobile adaptive-session-route and project-tile-display regression tests —
  10 passed.
- `flutter build macos --debug --no-pub` — pass with the existing Xcode
  unqualified Run Script output warning.
- macOS debug app `codesign --verify --deep --strict` — pass.
- Native macOS interaction/resize feel — blocked: QA launcher reports
  `macOS QA MCP setup error: peekaboo is not installed or not on PATH`.
  The existing app and standalone bridge were not stopped or replaced.
- Architecture implementation review — approved; fresh-context review of the
  complete tracked/untracked delta against `origin/main` found no violations.

The user explicitly requires reusing the already-running bridge. Any later
GUI check must preserve it; do not start, restart, take over, or stop a bridge.
The full plan remains active; no reduction of its final matrix is implied.

## Test Harness Note

The real sidebar cubit is constructed by `BlocProvider` inside the widget-test
zone. Constructing its restore/write futures in outer `setUp` prevents the
fake clock from draining persistence callbacks correctly. The double-click
check also advances Flutter's short gesture timer before teardown.
