# Step 7.b — Settings modal

## Delivered behavior

Root modal with General/Harnesses/Bridge/Notifications/Account; current session,
route and composer stay mounted. General owns native startup preferences;
connected-bridge configuration and this-computer diagnostics remain distinct.
Harness Back is internal; Close dismisses owned sheets without cancelling auth.
Account retains supervised logout, not a second Back button. A definitive app
refresh-token rejection closes the root overlay through the existing auth gate.
Desktop settings routes/wrapper/destination state are retired. Mobile profile
presentation is explicitly unchanged. No database, wire or harness contract changes.

## Revision-scoped evidence

Base: `ae9b093067810e784ebd41ddd5daa371d009d076`. Flutter 3.47.4/bundled Dart.
**87 distinct cases**, not sums of reruns:

| Revision | Retained evidence |
|---|---|
| `8e4b42b4469e46264d6c430113b0124e11c4a446` | 5 Escape/dispatcher cases passed; three other suites failed compilation and are not counted here. |
| `f4187384169afc8bf75b27bed358b8eab40837f7` | 48 desktop cases passed after log-callback repair; 37 router/cockpit cases retained, 11 modal cases superseded below. |
| `5eae78681d8de54cd8efc411989d612470662ba1` | 30 mobile settings cases; shared-UI/mobile analyzers clean after explicit profile header policy. |
| `fb135f863f1f92810481e572de013d3aa1fa8949` | 14 modal/new-session cases; 3 composer cases retained, modal cases superseded below. |
| `16e878ab20133601bdd38021bcde74b57dd75261` | 12 modal cases and desktop analyzer pass; tree `ed1dc44512294b33d579ed281455b882b121e53d`. |

Tests use `flutter test --no-pub --reporter json` in the owning app. Desktop paths:
`test/core/widgets/{desktop_escape_dismissal,desktop_cockpit_shell}_test.dart`,
`test/core/platform/desktop_route_dispatcher_test.dart`,
`test/core/routing/desktop_router_test.dart`,
`test/features/{settings/desktop_settings_screens,new_session/desktop_new_session_screen}_test.dart`.
Mobile: `test/features/settings/settings_screen_test.dart`. Analysis:
`dart analyze --fatal-infos` in `client/{desktop,module_app_ui,app}`.
Logs: `/tmp/rose-elephant-settings-modal-*.log` (failed attempts remain labelled).

Nine real-font production-widget fixtures were inspected: all tabs, harness
detail, light/dark and minimum-size scrolling. Five remain from `f418738`; Account,
harness overview/detail and minimum startup were refreshed at `fb135f8`.
The auth-listener/nullable-owner follow-up changes no rendered geometry. Fixtures:
`client/desktop/.dart_tool/settings_modal_preview_test.dart`; PNGs:
`/tmp/rose-elephant-qa.mri9JX/settings-*.png`. These are synthetic Flutter renders,
not native/live QA or user approval. No renderer was changed to obtain them.

Read-only architecture review approved the full frozen base-to-`16e878a` scope,
with no findings (run `9a3fff52-7ec4-46fe-8083-2e5ff5acd29f`, A1–A13 and B-Client).
Subsequent changes only complete this evidence/tracker; no further code changed.
Final inclusive diff accounting belongs in the PR body. The modest 1,650-line
ceiling retains route retirement and roughly 650 lines of settings-test replacement;
shared preparation was already split into #1500. No generated output changes.

The running GUI/bridge/helper, production DI/auth/preferences, native registration
and live bundle were untouched. Production-wired smoke stays in isolated CI.
Native keyboard/backdrop/accessibility, live entry flows, native preference OS
mutation, relaunch, lifecycle and energy checks remain in final qualification;
unavailable testing is not silently waived or treated as a delivery gate.
