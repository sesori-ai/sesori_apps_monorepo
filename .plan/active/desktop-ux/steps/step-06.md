# Step 6 — Focused local-bridge popover

## Delivered behavior and content audit

The user rejected the first popover's option list and appearance. The final
composition reviews the purpose of each action instead of preserving that list:

- Local bridge heading + process-status detail; client connection state is
  separate and may describe another bridge. Tray status retains its entity prefix.
- One prominent Start, Stop, Retry or Take Over action matching the process
  state. A stopped crash offers recovery, not Stop because intent remained On.
  A displaced running helper retains Stop without requiring takeover.
- Explicit Start/Stop use the existing serialized command owner. Stop cannot
  accidentally become Start if the helper exits before the click is dispatched.
- Logs and configuration remain quieter secondary actions. App Quit belongs in
  application/tray controls; launch-at-login belongs under General preferences
  in step 7 (native tray registration remains available meanwhile).
- Opening the flat, screen-clamped popover preserves the main pane. Busy states
  disable mutations, not diagnostics; Settings dismisses before opening. Outside
  click and Escape dismiss without taking an action.
- `/splash` hosts the home pane; the dashboard/project index are deleted.
  Dashboard-only recent-log buffers/streams and crash snapshot fields are removed;
  bounded pipe drains, rotating persistence and crash exit/count diagnostics remain.

`PLAN.md` now audits content, labels, scope, grouping and hierarchy across the
remaining settings, first-run and shortcut work, with a final step-11 content pass.
No new mutable fields, timers, subscriptions, DI services, database/wire/auth
contract or native renderer change. No new analytics outcome warrants an event.
No running GUI, bridge, bundle, account or native preference was mutated.

## Reproducible verification

Workspace: `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.
Pinned binaries: `/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/`.
Cwds are relative to that workspace. Initial commands ran on working trees
subsequently captured unchanged by the listed checkpoint commits.

| Checkpoint | Cwd | Command | Relevant result |
|---|---|---|---|
| `7a00b4906496786ca765ac8bdfeb4966ea9c4039` | `client/desktop` | `flutter test --reporter json test/core/widgets/desktop_bridge_popover_test.dart test/core/widgets/desktop_cockpit_shell_test.dart test/core/routing/desktop_router_test.dart test/features/auth_gate/auth_gate_view_test.dart test/features/home/desktop_home_pane_test.dart test/features/settings/desktop_settings_screens_test.dart` | 57 then passed; only 26 unchanged routing/auth/home/settings cases are carried forward below |
| `c1e94b04d09c9412010c18d19311aca088034ed4` | `client/module_desktop_core` | `dart test --reporter json test/services/bridge_process_service_test.dart test/trackers/bridge_process_log_tracker_test.dart` | 41 pass; unchanged thereafter |
| `645ae230b8c9bac320f042cdadffbdb8bb97404b` | `client/desktop` | `flutter test --reporter json test/core/widgets/desktop_bridge_popover_test.dart test/core/widgets/desktop_cockpit_shell_test.dart` | 33 pass |
| `645ae230b8c9bac320f042cdadffbdb8bb97404b` | `client/module_desktop_core` | `dart test --reporter json test/cubits/bridge_control/bridge_control_cubit_test.dart` | 30 pass |
| `645ae230b8c9bac320f042cdadffbdb8bb97404b` | `client/desktop` | `flutter test --reporter json .dart_tool/bridge_popover_preview_test.dart` | 3 revised fixtures pass |
| `645ae230b8c9bac320f042cdadffbdb8bb97404b` | `client/module_desktop_core`, `client/module_app_ui` | `dart analyze --fatal-infos` | clean |
| `c9a04e3dafc585abca55755ea3fb1cf767d512ec` | `client/desktop` | `dart analyze --fatal-infos` | clean after equivalent exhaustive action matching |

Trees respectively: `fa7447d2bf1a0c306a3b4cc4610e1a8b48c31599`,
`5a033c2a43e0429c89fc07679c0aa683f43b2dbe`,
`cae4ca9105ecb0d2fe007a5ac07febf9ea134a29`,
`02592d39aa399296774255ddd4b5b673f158deb2`.

**130 currently relevant cases** = 26 + 41 + 33 + 30. Superseded popup/refresh
cases and repeated cockpit cases are not counted again. The final matching
refactor moves the identical takeover choice outside the exhaustive switch;
preceding tests/renders are baseline evidence, not claimed reruns at `c9a04e3`.
Generation, formatting and diff checks pass. Logs:
`/tmp/rose-elephant-popover-{desktop-first,log-cleanup-tests,focused-ui-final,focused-control,focused-previews}.log`
and `/tmp/rose-elephant-popover-focused-*-analyze*.log`.

Three inspected `/tmp/rose-elephant-qa.mri9JX/bridge-popover-focused-*.png` images
show light Off, dark connected and minimum-width contention. The ignored harness
uses real bundled fonts, production widgets and synthetic state/Linux rendering;
it captures above the root navigator to include the actual overlay. Earlier
`bridge-popover-*.png` fixtures without `focused-` show the rejected composition.
Fixtures are not native/live/energy evidence or user approval.

## Review and remaining qualification

Initial architecture review approved only `b69a4857..c1e94b04`, before the user's
content revision. The full original report/provenance are retained at
`/tmp/rose-elephant-popover-architecture-initial{.md,-provenance.json}`.
Final fresh-context architecture review **APPROVED** exact range
`b69a4857289d30106bbd06af963437cdfa4699e7..c9a04e3dafc585abca55755ea3fb1cf767d512ec`,
with no findings. Run `96ac46a1-5d5b-435f-8d71-0b5a73a51ba1`; full report:
`/tmp/rose-elephant-popover-architecture-final.md`. Later commits only update docs.
Native lifecycle, registration and OS log-launch checks remain in the final
user testing handoff, not merge gates. The running bridge was never stopped,
restarted or taken over. Earlier native platform-view/profile-build limits remain.
Final self-inclusive diff accounting belongs in the PR body.
