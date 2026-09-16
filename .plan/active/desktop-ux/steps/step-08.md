# Step 8 — First-run defaults and local macOS file access

## Behavior and ownership

Authenticated first use with no saved bridge intent initializes On, starts through the existing
process owner and best-effort enables native launch at login. Existing intent is untouched;
missing and invalid state remain distinct. The instance service reuses its write queue/restore
generation so explicit Off/logout supersedes pending initialization. Start is admitted before
awaiting native enable, preventing that completion from issuing a late start. No new persisted
field, installation marker, wire contract, database migration, retry loop or backend behavior.

One root `FileAccessCubit` observes window focus, preserves this-run dismissal across navigation
and rejects superseded probe results. The shell adapter opens/closes a protected macOS file
read-only without reading its contents: permission denial is denied, other failures remain
logged unknown; other OSes perform no probe. Optional home guidance explains broader access
and agent folder prompts. Settings → Bridge → This computer retains the status/action after
Not now. Nothing grants permission automatically, blocks navigation or restarts a bridge.
The content pass made dismissal quieter and added an external-settings affordance.
Desktop analytics remains outside its approved scope; no speculative tap event was added.

## Revision-scoped verification

Base: `77c781faa648bcbe971aca1813abe1a2ba96ccc6`. Flutter 3.47.4/bundled Dart.
- A: `925dc679962ab1b80b15c588d11b7ff7aa3a4b30`, tree `ab5cf605980d849307477b4c4bc1284aa5b10ba7`.
- B: `71023d959004aef3fb54efacd991ba8b0740f30d`, tree `e8519d85947b675643c1a11f3924eb1360dc48e6`.
- C: `bcfd36fb39a25cb938f63ca628124296d84c5a06`, tree `0679145e3ec5484a40483ac7e0648777c720d37b`.

**81 distinct focused cases**; repeated executions and render probes are not added to this count.
For each row, append its paths to the indicated test command in its stated cwd:

| Cwd | Command prefix | Test paths | Retained result |
|---|---|---|---|
| `client/module_desktop_core` | `dart test --reporter json` | `test/api/desktop_instance_storage_test.dart`, `test/repositories/desktop_instance_repository_test.dart`, `test/services/desktop_instance_service_test.dart`, `test/cubits/file_access_cubit_test.dart` | A: 12+4+13+7 = 36 pass |
| `client/module_desktop_core` | `dart test --reporter json` | `test/orchestration/desktop_startup_orchestrator_test.dart` | B: 14 pass, exit 0 |
| `client/desktop` | `flutter test --no-pub --reporter json` | `test/core/platform/io_file_access_permission_test.dart` | A: 6 pass |
| `client/desktop` | `flutter test --no-pub --reporter json` | `test/features/home/desktop_home_pane_test.dart`, `test/features/settings/desktop_settings_screens_test.dart` | C: 7+18 = 25 pass |

A's core command also attempted startup tests and exited 1: its test fixture returned `Stream`
instead of the required `ValueStream`. B corrected only that fixture/import order; its 14-case
run passed. A's desktop command included all three desktop rows and passed 31 cases; C reran
only the affected two widget suites plus four render probes (29 executions), exit 0.
Counts include the real test named "loading home…", not just a naive exclusion of every name
starting "loading". No tests were rerun solely to repair counting/provenance.
`dart analyze --fatal-infos`: core clean at B, desktop at C, shared UI at A; A's core analyzer
reported the same fixture error/import order and was not clean. Other suites were not repeated.
Logs/manifests: `/tmp/rose-elephant-first-run-{verification,final-verification,ui-final}.json`
and their recorded `/tmp/rose-elephant-first-run-*.log` paths.

DI generated with `dart run build_runner build --build-filter=lib/src/di/injection.config.dart`
in core and `--build-filter=lib/core/di/injection.config.dart` in desktop; `flutter gen-l10n`
in shared UI. All exit 0. Desktop generation retained the known cross-phase
`DesktopActiveBridgeLocality`/`BridgeStatusTracker` registration warning; analysis is clean.
No generated file was edited manually; no dependency changes.

## Visual, architecture and qualification boundaries

At C, actual production widgets with fake state/real fonts produced four inspected PNGs under
`/tmp/rose-elephant-qa.mri9JX/`: `home-access-light`, `home-access-minimum-dark`,
`settings-bridge-access`, `settings-bridge-access-minimum`. Ignored harnesses are
`client/desktop/.dart_tool/first_run_{home,settings}_preview_test.dart`, run with the desktop
Flutter command above. Initial B previews informed the small C affordance/color adjustments.
These are synthetic renders, not native permission/agent behavior or user approval.

Architecture review approved frozen base..B with no findings (run
`ccc09a82-94e0-4ab4-ab09-2a846eb43626`, A1–A13/B-Client). Its supplied 80-case summary
predates the corrected counting above; no reviewer test run is claimed. C adds only presentation
styling/affordance, a stale comment and docs, not architecture/ownership changes.
Inclusive publication totals (all authored/generated additions and deletions, including this
file and regression docs) belong in the PR body, pinned to an immutable publication head.

The running GUI/helper/bridge, live bundle, auth/preferences and native registration were untouched.
No real protected-file probe, System Settings, login item, production-DI smoke or restart ran locally.
Native fresh-account startup/login registration, FDA grant/deny/focus return and inherited helper
access remain required final qualification. Missing safe infrastructure is blocked, not passed,
waived or substituted by fake tests; unavailable native QA is not a delivery gate.
