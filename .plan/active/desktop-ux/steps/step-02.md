# Step 2.a — Sidebar Frame

PR: [#1488](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1488),
ordinal 2/13. Styling/motion/activity additions belong to the separate
[step 2.b follow-up](step-02b.md), as requested by the user on 2026-09-15.

## Scope

Implemented the 200–420 px sidebar, 260 px default, 56 px compact rail,
temporary collapse below 760 px, resize/reset, saved layout, project shortcuts,
and pinned Bridge/Settings actions. One `ProjectListCubit` now belongs to the
signed-in cockpit and serves both sidebar and existing project screen. Main
pane routes and shared mobile split composition are unchanged.

`DesktopSidebarLayout` is the typed persisted value and cubit state. Existing
storage/repository own its JSON boundary; writes are serialized only for user
layout commits, not drag frames. No bridge, wire, database, or account changes.

Cleanup: removed `NavigationRail` and the project screen's duplicate cubit
ownership. Destination classification remains to select the current section.
Analytics: no new event; resizing is not an authoritative product outcome, and
desktop analytics has no approved delivery scope.

Review fixes preserve destination selection and screen-reader activation,
project row identity through reorder/removal, and the failure-aware retry path.
Default width has one source; localization hints describe the new strings.

## Verification

Initial implementation verification:

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
- Architecture implementation review — approved; fresh-context review of the
  complete tracked/untracked delta against `origin/main` found no violations.

After functional review fixes:

- Desktop cockpit widget tests — 12 passed, including semantics activation,
  destination selection, reconnect retry, and project reorder/removal.
- Desktop router tests — 5 passed.
- Desktop core sidebar/storage tests — 19 passed.
- Desktop and desktop-core `dart analyze --fatal-infos` — pass.
- Freezed/JSON and localization generators — pass.

## Native QA

The user approved Peekaboo 4.4.0 for this run; the repository's 4.2.2 pin is
unchanged. The standalone bridge remained running while only the old GUI was
replaced with the tested build. No bridge start/stop/restart/takeover occurred.

Observed expanded/compact layouts, live drag resizing, repeated narrow/wide
window changes, and project-shortcut navigation into the existing sessions
pane. A controlled resize sequence preserved the saved expanded width across
automatic collapse. The user independently confirmed automatic collapse,
dragging, and double-click reset work.

This is partial native coverage, not a full L3 pass. Earlier uncorrelated width
changes were not reproduced in the controlled repeat; no causal claim is made.
Keyboard focus, complete hover/tooltips, light/dark appearance, and relaunch
persistence are not claimed as verified. No further GUI relaunches during this
QA pass: preserve the existing bridge and avoid further secure-storage prompts.
The full plan remains active; no further reduction of its final matrix is implied.

## Test Harness Note

The real sidebar cubit is constructed by `BlocProvider` inside the widget-test
zone. Constructing its restore/write futures in outer `setUp` prevents the
fake clock from draining persistence callbacks correctly. The double-click
check also advances Flutter's short gesture timer before teardown.
