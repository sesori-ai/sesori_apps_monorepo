# Step 8 — First-run defaults and local macOS file access

## Behavior and ownership

Authenticated first use with no saved bridge intent initializes On, starts through the existing
process owner and best-effort enables native launch at login. Existing intent is untouched;
missing and invalid state remain distinct. The instance service reuses its write queue/restore
generation so explicit Off/logout supersedes initialization, including after a failed Off write.
Auth lost during persistence delegates admitted On to the process owner's login-required state;
it starts no infrastructure until sign-in. Disposal still cancels admission. Start precedes native
enable, preventing its completion from issuing a late start. Shell composition refreshes the
existing control owner's native state after its initial load, updating General and the tray.
No new persisted field, marker, wire contract, migration, retry loop or backend behavior.

One root `FileAccessCubit` observes window focus, preserves this-run dismissal across navigation
and rejects superseded probe results. The shell adapter opens/closes a protected macOS file
read-only without reading its contents: permission denial is denied, other failures remain
logged unknown; other OSes perform no probe. Optional home guidance explains broader access
and agent folder prompts. Settings → Bridge → This computer retains the status/action after
Not now. Nothing grants permission automatically, blocks navigation or restarts a bridge.
The content pass made dismissal quieter and added an external-settings affordance.
Desktop analytics remains outside its approved scope; no speculative tap event was added.

## Revision-scoped verification

Base: `77c781faa648bcbe971aca1813abe1a2ba96ccc6`.
Worktree root: `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.
All cwd values below are relative to that root. `dart` and `flutter` resolve to
`/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/`.

| Checkpoint | Commit | Tree |
|---|---|---|
| A | `925dc679962ab1b80b15c588d11b7ff7aa3a4b30` | `ab5cf605980d849307477b4c4bc1284aa5b10ba7` |
| B | `71023d959004aef3fb54efacd991ba8b0740f30d` | `e8519d85947b675643c1a11f3924eb1360dc48e6` |
| C | `bcfd36fb39a25cb938f63ca628124296d84c5a06` | `0679145e3ec5484a40483ac7e0648777c720d37b` |
| D | `0603fe20d7a6e71e40419bf9e43ece87f07fdc96` | `1a28115481c847ae9687c726c9a5ab8530185dae` |

**150 distinct retained cases**, not accumulated reruns: A's storage 12 + repository 4 +
file-access cubit 7 + adapter 6; C's home 7 + Settings 18; D's instance service 14 + startup 14 +
controls 33 + process service 35. The initial 81-case publication is superseded by these retained
checkpoints, not added to them. Render probes are separate. Each invocation below is complete.

| Checkpoint | Cwd | Exact command | Result and retained scope |
|---|---|---|---|
| A | `client/module_desktop_core` | `dart test --reporter json test/api/desktop_instance_storage_test.dart test/repositories/desktop_instance_repository_test.dart test/services/desktop_instance_service_test.dart test/orchestration/desktop_startup_orchestrator_test.dart test/cubits/file_access_cubit_test.dart` | Exit 1: 36 passes; startup fixture failed compilation (`Stream` instead of required `ValueStream`). Retain storage/repository/file-access 23; service 13 superseded by D. |
| A | `client/desktop` | `flutter test --no-pub --reporter json test/core/platform/io_file_access_permission_test.dart test/features/home/desktop_home_pane_test.dart test/features/settings/desktop_settings_screens_test.dart` | Exit 0: 31 cases. Retain adapter 6; widget cases superseded by C. |
| B | `client/module_desktop_core` | `dart test --reporter json test/orchestration/desktop_startup_orchestrator_test.dart` | Exit 0: 14 cases after fixture/import correction; superseded by D. |
| C | `client/desktop` | `flutter test --no-pub --reporter json test/features/home/desktop_home_pane_test.dart test/features/settings/desktop_settings_screens_test.dart .dart_tool/first_run_home_preview_test.dart .dart_tool/first_run_settings_preview_test.dart` | Exit 0: 25 retained widget cases + 4 render probes. |
| D | `client/module_desktop_core` | `dart test --reporter json test/services/desktop_instance_service_test.dart test/orchestration/desktop_startup_orchestrator_test.dart test/cubits/bridge_control/bridge_control_cubit_test.dart test/services/bridge_process_service_test.dart` | Exit 0: 96 cases, all retained. |
| A/B/D | `client/module_desktop_core` | `dart analyze --fatal-infos` | A exit 3: fixture type/import errors; B/D exit 0, no issues. D supersedes B. |
| A/C/D | `client/desktop` | `dart analyze --fatal-infos` | All exit 0, no issues. D supersedes C/A. |
| A | `client/module_app_ui` | `dart analyze --fatal-infos` | Exit 0, no issues; unchanged since. |

D tests prove failed explicit Off blocks defaults both before and after its error settles;
auth-loss admission delegates to the existing process owner, which waits without infrastructure
and resumes after sign-in; successful native enable notifies the existing refresh path;
refresh updates both General state and the tray action. No new native operation is exercised.
Counts include the real test named "loading home…", not a naive exclusion of every name
starting "loading". No tests were rerun solely to repair counting/provenance.
Logs/manifests: `/tmp/rose-elephant-first-run-{verification,final-verification,ui-final,review-verification}.json`
and their recorded `/tmp/rose-elephant-first-run-*.log` paths. These are revision-scoped,
not a fresh all-green whole-head test command. Local production-DI smoke remains excluded.

## Generation provenance

Generation ran before A on an uncommitted tree whose hash was **not captured**. A contains the
resulting generated files; it is not represented as the generation-time whole tree. No generator
was rerun for D: the callback is not a constructor/DI registration change. Exact invocations:

| Cwd | Exact command | Result |
|---|---|---|
| `client/module_desktop_core` | `dart run build_runner build --build-filter=lib/src/di/injection.config.dart` | Exit 0 |
| `client/desktop` | `dart run build_runner build --build-filter=lib/core/di/injection.config.dart` | Exit 0; known cross-phase `DesktopActiveBridgeLocality`/`BridgeStatusTracker` registration warning |
| `client/module_app_ui` | `flutter gen-l10n` | Exit 0 |

Logs: `/tmp/rose-elephant-first-run-generate-{module_desktop_core,desktop,module_app_ui}.log`.
No generated file was edited manually; no dependency changes.

## Visual, architecture and qualification boundaries

At C, actual production widgets with fake state/real fonts produced four inspected PNGs under
`/tmp/rose-elephant-qa.mri9JX/`: `home-access-light`, `home-access-minimum-dark`,
`settings-bridge-access`, `settings-bridge-access-minimum`. Ignored harnesses are listed in C's
exact command above. Initial B previews informed C's small affordance/color adjustments; they
are not retained as final render evidence. D has no geometry changes, so C renders were not
rerun or relabelled. These are synthetic renders, not native permission/agent behavior or approval.

Architecture review approved frozen base..B with no findings (run
`ccc09a82-94e0-4ab4-ab09-2a846eb43626`, A1–A13/B-Client). Its supplied 80-case summary
predates corrected counting; no reviewer test run is claimed. C changed presentation/docs only.
The final follow-up review approved published `c689d593a9813c3a6af121ed7def232d69e70dd0`..D
without findings (run `35deef9c-fb69-4621-b8df-c9b4e35c0b06`, A1–A13/B-Client).
It covers the callback/lifecycle composition, not native behavior; supplied tests were not rerun.
Inclusive publication totals (all authored/generated additions and deletions, including this
file and regression docs) belong in the PR body, pinned to an immutable publication head.

The running GUI/helper/bridge, live bundle, auth/preferences and native registration were untouched.
No real protected-file probe, System Settings, login item, production-DI smoke or restart ran locally.
Native fresh-account startup/login registration, FDA grant/deny/focus return and inherited helper
access remain required final qualification. Missing safe infrastructure is blocked, not passed,
waived or substituted by fake tests; unavailable native QA is not a delivery gate.
