# Step 6 — Sidebar Bridge popover

## Delivered behavior

- The pinned Bridge row opens Prego's flat, screen-clamped popover in expanded
  and compact modes, preserving the current main pane and its viewing owner.
- Process/client status, Bridge On/Off, conditional Take Over, Start at login,
  Open Logs, Bridge settings… and Quit use the existing command cubit. Switch
  presentation follows the authoritative command target, not stale desired intent.
- Opening refreshes native launch-at-login state through the existing activity
  owner. Mutations stay locked during work; diagnostics remain available.
  Read failures remain logged/retryable and late completion cannot emit after close.
- Outside click/Escape dismiss without taking an action. Settings and Quit
  dismiss before delegation. Settings intentionally opens the existing route
  until step 7 supplies the modal's Bridge tab.
- `/splash` presents the shared home pane. The dashboard and redundant project
  index disappear. Dashboard-only recent-log buffers/streams and crash snapshot
  fields are removed; bounded pipe drains, rotating persistence and exit/count
  diagnostics remain. No migration or internal compatibility shim is needed.

No new mutable fields, timers, subscriptions, DI services, database/wire/auth
contract, or native renderer change. These are existing outcomes on a different
surface, not a new analytics event. No GUI/bundle/preference/account mutation or
live bridge/helper launch, stop, restart, takeover or Quit was performed.

## Reproducible verification

Workspace: `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.
Pinned executables: `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/`.
Cwds below are relative to the workspace.

The initial working tree was captured unchanged as
`7a00b4906496786ca765ac8bdfeb4966ea9c4039`, tree
`fa7447d2bf1a0c306a3b4cc4610e1a8b48c31599`:

| Cwd | Command | Result |
|---|---|---|
| `client/desktop` | `flutter test --reporter json test/core/widgets/desktop_bridge_popover_test.dart test/core/widgets/desktop_cockpit_shell_test.dart test/core/routing/desktop_router_test.dart test/features/auth_gate/auth_gate_view_test.dart test/features/home/desktop_home_pane_test.dart test/features/settings/desktop_settings_screens_test.dart` | 57 pass |
| `client/module_desktop_core` | `dart test --reporter json test/cubits/bridge_control/bridge_control_cubit_test.dart` | 32 pass |

After causal snapshot cleanup, the additional compact/expanded test and a
constructor-syntax-only lint fix, checkpoint
`c1e94b04d09c9412010c18d19311aca088034ed4`, tree
`5a033c2a43e0429c89fc07679c0aa683f43b2dbe`:

| Cwd | Command | Result |
|---|---|---|
| `client/module_desktop_core` | `dart test --reporter json test/services/bridge_process_service_test.dart test/trackers/bridge_process_log_tracker_test.dart` | 41 pass |
| `client/desktop` | `flutter test --reporter json test/core/widgets/desktop_cockpit_shell_test.dart` | 26 pass, including 25 reruns |
| `client/desktop` | `flutter test --reporter json .dart_tool/bridge_popover_preview_test.dart` | 3 fixtures pass |
| Each of `client/desktop`, `client/module_desktop_core`, `client/module_app_ui` | `dart analyze --fatal-infos` | clean |

There are **131 distinct focused cases**, not 156; fixtures are separate.
Generation, formatting and diff checks pass. Logs are
`/tmp/rose-elephant-popover-{desktop-first,core-first,log-cleanup-tests,cockpit-final,previews}.log`
and `/tmp/rose-elephant-popover-{desktop,module_desktop_core,module_app_ui}-analyze-final.log`.
The final checkpoint logs include revision/tree/cwd/command headers; initial
logs precede their identical-source checkpoint commit.

Three inspected PNGs under `/tmp/rose-elephant-qa.mri9JX/bridge-popover-*.png`
show light Off, dark connected and minimum-size compact Take Over. They use
production widgets, real bundled fonts, synthetic state and Linux Flutter
rendering. The private harness captures above the root navigator so the actual
popover overlay is included. These are not native/live/energy evidence or user approval.

## Remaining qualification and size

Native On/Off, Take Over, Start at login, log application launch and Quit cannot
be exercised on the current app without violating the user's preservation
constraints. They remain in the final testing handoff, not a merge/continuation
gate. Earlier native platform-view and profile-build limitations still apply.
The measured replacement plus causal cleanup raised the original 900-line
target to 1,400; final self-inclusive accounting is recorded in the PR body.
