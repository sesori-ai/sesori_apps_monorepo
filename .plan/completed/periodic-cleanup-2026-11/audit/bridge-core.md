# bridge/app core (api, repositories, routing, server, sse, persistence, auth, control, orchestrator, debug_server) cleanup audit

## Summary

Overall the request/data side is in reasonable health. Every item from the previous audit that was in scope is gone: `insertStoredSession`, `takeChildren`/`takeTranslations`/`takeReady`, `getActivity`, `getStoredSessionsByBackendIds`, and persisted options `completeness`. Every public method of the four big repositories has a production caller, and every COMPATIBILITY marker in scope is still live.

The leftovers are whole relay routes that no public client ever called, plus the machinery behind them:

1. `POST /project/questions` (BA-1). It cascades through `QuestionRepository` and `BridgePlugin.getProjectQuestions` in 6 plugins.
2. `POST /global/restart` (BA-2). It brings a full restart/successor/exit-86 subsystem; a decision is needed.
3. `GET /plugin/setup` (BA-4).

The largest test-debt item is four hand-rolled full `NativeProjectsPluginApi` fakes, about 780 lines, that copy the shared `FakeBridgePlugin` (BA-3).

Rule debt is moderate:
- about 39 real null assertions
- about 70 positional-parameter declarations
- silent or inline-`$e` catches in the relay loop
- error translations that drop the cause
- relay control frames parsed with magic strings

`orchestrator.dart` (2,760 lines) still owns unseen-activity and YOLO policy that belongs to existing services (BA-6).

Estimated removable: about 2,700 lines (about 800 lib, 1,900 test) if BA-2 removal is approved, about 1,800 otherwise.

## Findings

### BA-1 Remove the never-called `POST /project/questions` route and `getProjectQuestions` across the plugin boundary
- Category: leftover
- Evidence:
  - Handler: `bridge/app/lib/src/routing/get_project_questions_handler.dart` (27 lines), registered at `orchestrator.dart:740`.
  - No client ever used the literal `"/project/questions"`. I checked:
    - `git grep` at every public client tag v1.0.8 … v1.11.0, plus `app-v1.0.5` and `app-v1.0.6`: 0 hits in non-test files.
    - `git log -S"project/questions" -- mobile client app`: empty.
    - Docs and plans: no hits.
  - The route is the only production caller of `QuestionRepository.getProjectQuestions` and `_getPluginProjectQuestions` (`repositories/question_repository.dart:61-175`, about 110 lines). That repository method is the only caller of `BridgePlugin.getProjectQuestions` (`sesori_plugin_interface/lib/src/bridge_plugin.dart:230-233`), which is implemented in:
    - `claude_plugin_impl.dart:410`
    - `codex_plugin_impl.dart:1744`
    - `opencode_plugin_impl.dart:742`
    - `opencode_v2_plugin.dart:303` and `opencode_v2_service.dart:370`
    - `acp_plugin.dart:2450`
    - `pi_plugin_impl.dart:462` and `pi_extension_ui_service.dart:146`
  - The enum value `SessionOperation.getProjectQuestions` (`repositories/models/session_operation.dart:33`) exists only for it.
  - Tests:
    - `get_project_questions_handler_test.dart` (112 lines)
    - 11 tests in `question_repository_test.dart` (about 450 lines)
    - `acp_plugin_projects_test.dart:824-870`
    - `pi_extension_ui_service_test.dart:69`
    - 6 fake overrides in app tests
- Proposal: delete the handler and its registration, the repository method and its helper, the enum value, the interface method, every plugin implementation, and their tests and fakes. `/session/questions` is unaffected. Afterwards, check whether any `pending_interaction_support.dart` helper has lost its last caller.
- Size: about 250 lib lines and about 650 test lines; about 20 files.
- Risk: low. There is no wire impact, and plugin interfaces have no external consumers. Coordinate with the plugin auditor.
- Confidence: verified
- Decision needed: none

### BA-2 `POST /global/restart` feeds a whole restart subsystem that no client uses
- Category: leftover
- Evidence:
  - `routing/restart_bridge_handler.dart` has no caller in any public tag, the current client, desktop or shared code.
  - Its only users:
    - `debug_server.dart:120-203`
    - `test/integration/supervised_e2e_test.dart:73`, which per `.plan/active/desktop-app/steps/step-12.md` deliberately "drives restart through the existing `/global/restart` debug route"
    - manual E2E-08 in `.plan/completed/setup-aware-harness-settings/E2E.md:60`
  - It is still registered in the relay `RequestRouter`, and `orchestrator.dart:2535-2541` dispatches `RestartAccepted`, so a paired phone can restart the bridge.
  - Machinery that exists only for this route:
    - `routing/routed_request.dart:31-43` (`RoutedRequestOutcome`/`ResponseOnly`/`RestartAccepted`)
    - `routing/bridge_restart_dispatcher.dart`
    - `routing/models/restart_bridge_response.dart`
    - `server/services/bridge_restart_service.dart`
    - `server/services/windows_restart_successor_launcher.dart` (constructed at `bin/bridge.dart:825`)
    - `server/foundation/bridge_restart_command*.dart` and `bridge_restart_env.dart` (`SESORI_RESTART_PREDECESSOR_PID` read at `runtime/bridge_runtime_runner.dart:263`)
    - the runner's exit-86 branches (`bridge_runtime_runner.dart:786-803` and `985-1012`)
    - `runtime/bridge_runtime.dart:25,55,74`
    - orchestrator wiring (222, 250, 675, 823, 838, 937, 972-983, 2532-2541)
    - `BridgeSupervisedExitCode.restart` (`shared/.../bridge_supervised_exit_code.dart`)
    - the desktop respawn case at `client/module_desktop_core/lib/src/services/bridge_process_service.dart:550`
  - Lib restart files total about 331 lines. Tests:
    - `bridge_restart_service_test` 211
    - `windows_restart_successor_launcher_test` 68
    - `command_builder_test` 25
    - `restart_test_support` 33
    - `restart_bridge_handler_test` 129
    - `bridge_restart_dispatcher_test` 104
    - parts of `debug_server_test`, `routed_request_dispatcher_test` and `supervised_e2e_test`
  - Introduced in 7d397f1e26 (2026-06-22, #288).
- Proposal:
  - (a) Remove the route and the whole subsystem. Make the dispatcher return a plain `RelayResponse`, drop exit 86 and its desktop case, and change the E2E restart step to stop/start on the same data directory.
  - (b) Alternatively, keep restart as a debug-only route and unregister it from the relay router.
- Size: (a) about 370 lib and about 570 test lines across about 20 files; (b) about 5 lines.
- Risk: medium for (a), because it touches shutdown and supervisor sentinel paths. There is no public wire impact. Low for (b).
- Confidence: verified
- Decision needed: remove the bridge restart feature, or keep it as debug-only and remove it from the phone-facing relay router?

### BA-3 Replace hand-rolled full plugin fakes with the shared `FakeBridgePlugin`
- Category: test-debt
- Evidence: these four classes re-implement the whole `NativeProjectsPluginApi` surface (about 33 overrides each):

  | File | Class | Lines |
  |---|---|---|
  | `test/bridge/debug_server_test.dart:1037` | `_FakeBridgePlugin` | 201 |
  | `test/bridge/debug_server_test.dart:1309` | `_TrackingBridgePlugin` | 197 |
  | `test/bridge/orchestrator_error_recovery_test.dart:402` | `_ThrowingSummaryPlugin` | 205 |
  | `test/bridge/repositories/session_repository_test.dart:2438` | `_FakeBridgePlugin` | 178 |

  Twelve other fakes already `extends FakeBridgePlugin`.
- Proposal: extend `FakeBridgePlugin` and override only what each test exercises.
- Size: about 600 test lines removed; 3 files.
- Risk: low (tests only).
- Confidence: verified
- Decision needed: none

### BA-4 Remove the never-called `GET /plugin/setup` route
- Category: leftover
- Evidence:
  - `routing/get_plugin_setup_handler.dart` (16 lines) is the only caller of `PluginLifecycleService.setupSnapshot` (`services/plugin_lifecycle_service.dart:201-212`, which also contains a `!` assertion).
  - No client caller at any tag or in history. Added in 4ef55675d6 (2026-07-22).
  - The shared `PluginSetupResponse` (`plugin_setup_response.dart:32-39`) has no other user. `PluginSetupMetadata` stays, because `plugin_management.dart:71` uses it.
  - Tests: `get_plugin_setup_handler_test.dart` (117 lines) and 3 `setupSnapshot` assertions in `plugin_lifecycle_service_test.dart` (797, 2459, 2745). Re-point those 3 at `managementSnapshot`.
- Proposal: delete the handler and its registration, `setupSnapshot`, the response wrapper (regenerate via codegen) and the handler test.
- Size: about 40 lib and about 140 test lines; 5-6 files.
- Risk: low
- Confidence: verified
- Decision needed: none

### BA-5 Dead and test-only production methods
- Category: leftover
- Evidence:
  - Zero references:
    - `ProjectsDao.deleteProject` (`projects_dao.dart:212`; its comment about PR FKs is stale since v21)
    - `insertMissingProjectsWithActivity` (`:295`)
    - `BridgeDiagnostics.runAll` (`persistence/bridge_diagnostics.dart:14`)
    - `RequestHandlerBase.findHeader` (`request_handler.dart:222`)
    - `PluginLifecycleSettings.copyWithIdleTimeout` (`bridge_settings.dart:44`)
  - Test-only:
    - `ProjectsDao.getProjectsByPath` (`:55`)
    - `getHiddenProjectIds` (`:129`)
    - `hiddenProjectIdsStream` (`:135`)
    - `unhideProject` (`:164`). It also writes `path: projectId`, against the bridge AGENTS rule. Real unhiding goes through `recordOpenedProject`.
    - `CatalogHydrationsDao.deleteForPlugin` (`:24`)
    - `AttachmentSpillStorage.scopeDirectoryPath` (`:152`)
    - `SessionDao.insertSessionsIfMissing` (`session_dao.dart:754`, about 50 lines, 33 test call sites; the sibling of the previous audit's B1)
- Proposal: delete the zero-reference methods, move the test-only DAO writers and readers into test helpers, and make `scopeDirectoryPath` private.
- Size: about 150 lib lines (about 60 move into test helpers); 6 lib files and about 8 test files.
- Risk: low; no schema change.
- Confidence: verified
- Decision needed: none

### BA-6 Move unseen-activity and YOLO policy out of the orchestrator
- Category: simplification
- Evidence:
  - `orchestrator.dart:2034-2084` `_routeUnseenActivity`: the event-to-`SessionUnseenService` mapping and the `displaySessionId ?? sessionID` owner rule. Called at 1911 and 1921.
  - YOLO policy inline in `_processPluginEvent` (1663-1690): `consumeReply`, `isYolo` then `approve`, and `approvePending` on `ServerConnected` and `ProjectUpdated`.
  - Precedent: `_projectActivityService.handleEvent(event)` (1927).
  - `_processPluginEvent` is 199 lines.
- Proposal: add `SessionUnseenService.handleEvent` and `PermissionAutoApprovalService.handleEvent` (returning suppress or continue). The orchestrator keeps only ordering and the generation fences.
- Size: about 80 lines leave the orchestrator, about 60 land in services; 3 files.
- Risk: low to medium. Preserve ordering: unseen is recorded before the `SessionCreated` enqueue. This is not a size-only split.
- Confidence: verified
- Decision needed: none

### BA-7 Swallowed and lossy errors in the relay loop and auth
- Category: rule-violation
- Evidence:
  - In `orchestrator.dart`:
    - 2259: `Log.v` with an inline `$e`
    - 2307-2318: the decrypt error is logged at `Log.v` as inline text
    - 2344, 2357 and 2371: `catch (_)`, silent
  - Error translations that drop the cause: `orchestrator.dart:2294`, `:2388`, `auth/auth_api.dart:69` and `auth/login_email_repository.dart:49`.
  - 10 inline-`$e` log calls: `debug_server.dart` (4), orchestrator (3, including 2107), `loopback_port_api.dart:16`, `bridge_restart_service.dart` and `login_email_repository.dart`.
- Proposal: pass error and stack as logger arguments, log the silent catches at `Log.w`, and keep a typed cause on the translations.
- Size: about 30 lines changed; 5 files.
- Risk: low
- Confidence: verified
- Decision needed: none

### BA-8 `/project/create` is live compatibility with no marker
- Category: rule-violation
- Evidence:
  - `app-v1.0.5`/`app-v1.0.6` and v1.0.8–v1.5.1 call it from the Add project dialog.
  - In v1.6.0–v1.9.1 only dead API code remains.
  - v1.10.1 and v1.11.0 do not contain it (19c5b0cc09).
- Proposal: add `// COMPATIBILITY 2026-11-02 (v1.11.0): Apps older than v1.6.0 create projects here; remove once public apps older than v1.6.0 are unsupported.`
- Size: 2 lines.
- Risk: none.
- Confidence: verified
- Decision needed: none

### BA-9 About 39 null assertions in scope
- Category: rule-violation
- Evidence:

  | File | Count | Lines |
  |---|---|---|
  | `chat_history_repository.dart` | 6 | 697 (two), 1064, 1092, 1193, 1194 |
  | `orchestrator.dart` | 5 | 1269, 1347, 1352 (two), 1546 |
  | regex-group parsers | 6 | |
  | `pending_interaction_support.dart` | 4 | 88, 109, 127, 151 |
  | `catalog_import_repository.dart` | 4 | 520, 521, 850, 853 |
  | `session_options_repository.dart` | 3 | 237-241 |
  | `debug_server.dart` | 3 | 106, 175 |
  | `chat_history_dao.dart` | 2 | 418-419 |
  | `process_repository.dart` and `bridge_instance_repository.dart` | 2 | |
  | `session_repository.dart` | 1 | 347 |
  | `project_repository.dart` | 1 | 187 |
  | `bridge_settings.dart` | 1 | 112 |
  | `mcp_repository.dart` | 1 | 85 |

- Proposal: use promotion or patterns, records for the teardown error pairs, and return the inserted row instead of re-reading it.
- Size: about 60 lines; 13 files.
- Risk: low to medium.
- Confidence: likely (±3)
- Decision needed: none

### BA-10 Positional parameters
- Category: rule-violation
- Evidence:
  - Handler constructors `GetProvidersHandler`/`PostAgentsHandler`/`RenameProjectHandler` (`orchestrator.dart:735,736,751`)
  - `FilesystemApi` (11 methods)
  - `SSEManager.unsubscribe`/`enqueueEvent`
  - `LoginOAuthService.openOAuthBrowser`/`performOAuthLogin`
  - `BridgeSettingsApi.writeConfig`
  - `DefaultEditorApi.openFile`
  - `sanitizeBridgeName`
  - `RateLimitException([message])`
  - About 40 private helpers.
- Proposal: convert the about 25 public declarations.
- Size: about 120 lines; about 15 files.
- Risk: low (compiler-checked).
- Confidence: verified (public list)
- Decision needed: none

### BA-11 Relay control frames parsed with magic strings
- Category: rule-violation
- Evidence: `orchestrator.dart:2210-2234` reads `control["type"] as String?` and `control["connId"] as int?`, and switches on `"phone_connected"`/`"phone_disconnected"`. No model exists in `shared/` or `bridge/`.
- Proposal: a small Freezed sealed `RelayControlMessage` with an unknown fallback.
- Size: about 25 lines added, about 12 removed.
- Risk: low.
- Confidence: verified
- Decision needed: none

### BA-12 Small orchestrator and control tidy-ups (batch with BA-6)
- Category: simplification
- Evidence:
  - The `_failureReporter.recordFailure(...).catchError` pattern repeats at 1776, 2002 and 1084; the last has no `catchError`.
  - Startup duplicates of `handleSseEvent`/`handleProjectsSummary` (1201-1207, 1905-1907, 2622-2623).
  - Close-and-null-out repeated at 1180, 1455, 1523 and 2722.
  - `PushNotificationContentBuilder` is constructed at both 389 and 392.
  - Three time sources: `_clock` at 294, package `clock` at 375 and 571, and `DateTime.now()` at 445, 1269 and in the DAOs.
  - Stale comment at 1334-1336.
  - Redundant `reconnectFuture` local at 1463.
  - `_drainRelayCompletions` (1559) only forwards.
  - `control_channel_loss_listener.dart`: a stale "Phase 2 / PR 1.7" comment (line 10) and defaulted ctor params (26-27).
- Proposal: one `_reportFailure` helper; delete the stale comments and the forwarder.
- Size: about 40 lines; 2 files.
- Risk: low.
- Confidence: verified
- Decision needed: none

## Checked and kept

- COMPATIBILITY markers in scope are all still live:
  - `orchestrator.dart:2481`
  - the PR refresh trio
  - `get_pull_request_refresh_settings_handler.dart:8`: correct, since v1.8.0+ only fall back to it after `/settings` returns 404
  - `get_base_branch_handler.dart:12`
  - the `deleteBranch` pair
  - `worktree_repository.dart:236`: its "(v1.9.2)" names a never-public build, but the boundary is equivalent
- `app_client_status_repository.dart:19`: the auth-server fallback. Needs-check for the compatibility auditor.
- `deleted_sessions.deletedAt` (never read) and `ownerIdentity` (speculative): removing either needs a v23 migration, which isn't worth it.
- Columns that are read: `projectionVersion`, `completedAt`, `acceptedAt` and the options-cache JSON columns.
- The SSE `{payload:{type,properties}}` envelope is a live wire contract (client `connection_service.dart:685`).
- `pendingReplayCount` is used by `tool/benchmarks`, and `boundPort` is a debug and test accessor.
- unref.tsv extension and internal-use false positives.
- `code_assets`/`hooks` are used by `hook/build.dart`.
- All public members of the four big repositories have production callers.
- All other relay routes are used by v1.10.1 or v1.11.0 clients.
- The orchestrator composition root and its about 55 dependencies are all used; the deferred size-only split is not re-proposed.
- The `ProjectsDao` upserts that write `path: projectId` stay. Needs-check: no flow reaches them for a moved folder.
- Deferred items (compatibility floor, E4, D2) are unchanged or belong to the other auditor's area.
- Previous-audit items in scope are confirmed removed.
