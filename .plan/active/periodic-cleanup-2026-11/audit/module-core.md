# module_core / module_auth / module_persistence cleanup audit

## Summary
Overall health is good. The lib directories have 0 null assertions, the custom linters are clean, the catch blocks mostly log or keep the cause, and the compatibility markers all still guard public bridges. The main debt is invisible leftovers from app-simplification and heavy-users: work that still runs on every SSE event even though no UI reads its result since the per-project screens went away.

Top 3 opportunities:
1. **MC-1:** Remove the project-level unseen/running aggregate. Nothing has read it since the Projects screen was removed, but it still re-emits on every unseen event. About 130 lines.
2. **MC-2:** Remove the list state of `SessionListCubit`. It sorts and filters a session list on every SSE activity tick, nobody renders it, and its "optimistic rename" is invisible. `docs/regression/projects-and-sessions.md` contradicts the code here. About 500 lines; needs a decision.
3. **MC-3:** Remove 11 production APIs whose last production caller is gone and that only tests still call. About 70 lib lines plus tests.

Estimated total removable: about 800 to 900 lines, roughly 45% lib and 55% tests. A further 4 rule-violation fixes change about 30 lines.

## Findings

### MC-1 Remove the dead project-level unseen/running aggregate (`runningByProjectId`, `unseenByProjectId`)
- Category: leftover
- Evidence:
  - `client/module_core/lib/src/services/models/project_list_state.dart:23-30` declares `runningByProjectId` and `unseenByProjectId` on `ProjectListLoaded`.
  - I ran `rg 'runningByProjectId|unseenByProjectId'` over `client/app/lib`, `client/desktop/lib`, `client/module_app_ui/lib` and `client/module_desktop_core/lib`: 0 hits. The UI readers were removed by app-simplification step 8 (635cbe8bb6, Projects screen) and step 10.
  - These writers still run for nobody, all in `project_inventory_service.dart`:
    - :103 is the `_sessionUnseenTracker.projectUnseen.listen((_) =&gt; _onUnseenUpdated())` subscription. It re-emits the whole `ProjectListLoaded` on every `SesoriSessionUnseenChanged`.
    - :203-219 are `_onUnseenUpdated` and `_unseenByProjectId`.
    - :599-610 is `_emitOrdered`, which copies both maps.
    - :862-880 is the `_refreshProjects` seed plus `seedProjects`.
  - `project_list_service.dart:69-109`: `orderProjects` builds `runningByProjectId` alongside the running-first order. The order itself has a live consumer (the project picker); only the count map is dead.
  - `session_unseen_tracker.dart` holds a project-level aggregate that exists only for this field:
    - the `_projectUnseen` subject (:33-34)
    - `projectUnseen` and `currentProjectUnseen` (:53-57)
    - `seedProjects` (:65-75)
    - the project write in `_handleEvent` (:190-192)
    - the close at :226
  - `_projectTick` must stay because `seedSessions` and `applyLocalSessionUnseen` use it.
  - The class doc at :21-24 still says "held for seconds by the PR-data wait". That is a pr-tracking-removal leftover.
  - Tests and fakes:
    - `lib/src/testing/test_helpers.dart:129-161, 223` (`FakeSessionUnseenTracker` project parts, `emitProjectUnseen`)
    - `test/services/project_list_service_test.dart:90,118`
    - the related cases in `project_inventory_service_test` and `test_helpers_test`
- Proposal:
  - Drop both fields from `ProjectListLoaded`.
  - Drop the `projectUnseen` subscription and the `_onUnseenUpdated`/`_unseenByProjectId` helpers.
  - Change `orderProjects` to return only the list.
  - Delete the project subject, the getters, `seedProjects` and the project write from `SessionUnseenTracker`.
  - Update the doc comment so it describes only sessions.
  - Keep wire `Project.hasUnseenChanges` / `projectHasUnseenChanges`; it is cross-boundary, and older public clients and the bridge use it.
- Size: about 130 lines removed (about 70 lib, about 60 tests and fakes); 5 lib files and about 4 test files.
- Risk: low. No user-visible effect, no wire or DB change. It removes one whole-state re-emit per unseen SSE event.
- Confidence: verified (rg across all shells; the field readers are absent).
- Decision needed: none.

### MC-2 Remove the `SessionListCubit` list state nobody renders (and its invisible optimistic rename)
- Category: leftover
- Evidence:
  - `client/module_core/lib/src/cubits/session_list/session_list_cubit.dart` (444 lines) is created only as a per-row action cubit:
    - `all_sessions_list.dart:881` creates it lazily per row, and the row calls `updateActionSession`.
    - `desktop_session_detail_screen.dart:60-65` creates it with `sessions: const []`.
  - No widget watches or selects it; I checked `rg 'SessionListCubit'` with `watch|select|BlocBuilder|BlocSelector`.
  - The only state reads are 2 point-in-time getters: `cubit.state.isSessionRunning` (`session_list_action_dispatcher.dart:158`) and `isSessionUnseen` (:240). The row already holds `row.isRunning` / `row.isUnseen`.
  - `state.sessions` is never read, so all of the following produce invisible output:
    - `_emitFiltered` (:411-432), which sorts and filters on every SSE activity or unseen tick
    - the exhaustive SSE switch (:65-135)
    - `_onSessionUpdated` / `_onSessionDeleted` (:212-254)
    - `_reinsertSession` (:399)
    - the `OptimisticRenameTracker` use (:256-333)
  - `session_list_state.dart` and `session_list_resolvers.dart` exist only for that state.
  - `docs/regression/projects-and-sessions.md:736-741` says a session rename "updates the list optimistically". The visible list is `AllSessionsCubit`/`SessionWindowService`, and it has no rename handling (rg). The title changes only when the bridge's `SesoriSessionUpdated` echo arrives, so the doc contradicts the code.
  - Root cause: heavy-users step 11 (95422006fa) made the cubit action-only and moved the list to the shared window, but the list half stayed.
- Proposal, Option A (cheaper):
  - Reduce `SessionListCubit` to its actions: mark seen/unseen, rename, delete or archive, and the retain-scope counter.
  - Remove `SessionListState`, the resolvers, the SSE subscription and the rename bookkeeping.
  - Have the dispatcher take `isRunning` / `isUnseen` from the row.
  - Fix the regression doc. `OptimisticRenameTracker` stays, because `ProjectInventoryService` uses it for projects.
- Proposal, Option B: wire an optimistic title into the `SessionWindowService` rows, then delete as in Option A.
- Size:
  - Option A: about 500 lines removed (about 250 lib, including the state, resolvers and freezed source, plus about 250 of the 591-line test); 4 lib files, 1 to 2 test files, 1 doc.
  - Option B adds about 60 lines back.
- Risk: low to medium. Action semantics (seen, rename, delete outcome) must stay the same. Nothing user-visible changes in Option A, because the state is not rendered today.
- Confidence: verified for "not rendered". Not yet checked whether any desktop test pumps a widget that reads `SessionListCubit` state.
- Decision needed: should a session rename show the new title immediately in the All Sessions list (Option B), or is the current wait for the bridge echo accepted, with the doc corrected (Option A)?

### MC-3 Remove production APIs that only tests call (their production callers were removed)
- Category: leftover
- Evidence: for each item I ran `rg '&lt;name&gt;'` across `client/*/lib` and found only the declaration; the remaining callers are tests.
  - `NewSessionCubit.canRefreshOptions` (`cubits/new_session/new_session_cubit.dart:656-664`). Its UI consumer was removed in app-simplification 11.ii (e439670974). The UI calls `refreshOptions` directly (`new_session_view.dart:229,342,350`).
  - `NewSessionState.isComposerDataLoading` (`new_session_state.dart:231`).
  - `SessionDetailCubit.reassertViewingSession` (`session_detail_cubit.dart:2965-2972`). The caller was removed in #1400 (fb8308e12a). Tests that use it: `session_detail_cubit_test:2444,2451` and `app/test/.../archived_sessions_navigation_test:332`.
  - `ProjectListCubit.loadProjects` (`cubits/project_inventory/project_list_cubit.dart:19`).
  - `ProductAnalyticsPreferenceCubit.retryPendingDisable` (:28).
  - `PromptSendQueue.completeSend` (`prompt_send_queue.dart:97-101`). The bridge queue and `parkAccepted` superseded it; 4 uses in `prompt_send_queue_test`.
  - `PersisterRepository.readStringOrDefault` (`module_persistence/lib/src/repositories/persister_repository.dart:22`).
  - `RelayClient.pendingRequestCount` (`relay_client.dart:139-140`).
  - `idleSessionLaunchCubit` in `lib/src/testing/test_helpers.dart`. It is used nowhere, not even in tests.
  - `OnboardingSurface.connectedEmpty` (`foundation/models/product_analytics/product_analytics_event.dart:11`). It is never sent, because the connected-empty surface is gone and the onboarding views send only `connectSetup` / `bridgeOffline`. The only use is `product_analytics_event_test:172`.
  - `ConnectionService.connect(ServerConnectionConfig config)` (`connection_service.dart:302-306`). It has no production caller; production goes through `connectWithFreshAuthToken` and the reconnect cycle into `_connectViaRelay` (:192, :1012). It also takes a positional parameter, which is a rule violation. It has about 32 test call sites in 8 files.
- Proposal:
  - Delete the first 10 items, along with the tests that exercise only them. Where a test uses the API as a setup shortcut, switch it to the production entry point.
  - For `ConnectionService.connect`, either move the 32 test sites to `connectWithFreshAuthToken` (that needs an auth-token stub in `test_helpers`), or at minimum make it `@visibleForTesting` with a named `config:` parameter.
- Size: about 70 lib lines removed, about 120 test lines removed or adjusted. The `connect` migration touches about 32 call sites.
- Risk: low. Test-only surfaces; no wire, DB or user-visible change. Removing the analytics enum value only stops a value that is never emitted.
- Confidence: verified (rg per name).
- Decision needed: none.

### MC-4 Stop putting a fabricated `HealthResponse(version: "")` on `ConnectionBridgeOffline`
- Category: rule-violation (empty string as missing data / fabricated state)
- Evidence:
  - `connection_service.dart:360` builds `const bridgeOfflineHealth = HealthResponse(healthy: true, version: "", filesystemAccessDegraded: false)`. It feeds:
    - `ConnectionStatus.bridgeOffline(health:)` at :383 and :633
    - `_subscribeBridgeStatus(health:)` at :367-370, whose `health` parameter (:606) is used only to emit `bridgeOffline`
    - the success response at :384
  - `models/connection_status.dart:36-39`: `ConnectionBridgeOffline.health` has no reader. The only status `health` reader is `add_project_dialog.dart:963`, which reads it on `ConnectionConnected`. `BridgeKindCubit` uses `lastHealth`, which this path does not touch.
  - Production callers of `_connectViaRelay` use only the `SuccessResponse` type check (:195, and the reconnect handling after :1012).
- Proposal:
  - Drop `health` from the `bridgeOffline` variant and from `_subscribeBridgeStatus`.
  - Make `_connectViaRelay` return an outcome without a fake payload, e.g. `({bool connected, int? closeCode})`, once `connect()` is gone (MC-3).
- Size: about 15 lib lines changed, about 37 test construction sites simplified.
- Risk: low. Internal Dart type only; no wire change.
- Confidence: verified.
- Decision needed: none.

### MC-5 Log swallowed failures in the analytics and storage paths (and the phone launch)
- Category: rule-violation (a recovered failure must stay observable / keep the cause)
- Evidence:
  - `repositories/analytics_repository.dart:46-53`: `_deliver` has `on Object { return AnalyticsDeliveryResult.failed; }`. The error and stack are lost. Callers log "Failed to deliver ... analytics event" without a cause (for example `project_inventory_service.dart:194-199`, `registered_bridges_service.dart:269`).
  - `repositories/product_analytics_preference_repository.dart:255-257` (`ServerConfirmedStorageFailed`) and :276-279 (`PendingSync`): secure-storage write failures with no log and no `innerError`. The sibling catches at :93 and :199 do log, so the inconsistency is local.
  - `cubits/plugin_management/plugin_management_cubit.dart:97-101`: `on Object { launched = false; }`. `DesktopUrlLauncher` logs internally, but `client/app/lib/core/platform/flutter_url_launcher.dart` does not, so a phone launch exception disappears.
- Proposal:
  - Use `on Object catch (error, stackTrace)` with `logw(...)` in the 3 repository catches.
  - In the cubit, either log the error or drop its catch once `FlutterUrlLauncher` logs and returns false the way the desktop launcher does. The second option is cleaner because it gives one owner.
- Size: about 12 lines changed in 3 or 4 files.
- Risk: low. Logs only.
- Confidence: verified.
- Decision needed: none.

### MC-6 Delete the dead PKCE and provider storage in `OAuthStorageService`
- Category: leftover
- Evidence:
  - In `client/module_auth/lib/src/storage/oauth_storage_service.dart`, `saveAuthProviderAndPkceVerifier` (:11-24), `getPkceVerifier` (:26-38) and `getAuthProvider` (:54-67) are called only by `token_storage_service_test.dart:384-446`. They were already dead before the June rename.
  - `auth_manager.dart` uses only `saveOAuthSession` / `getOAuthSession` and the `clear*` calls (:470,476,482,846-848).
  - `AuthSecretKey.pkceVerifier` / `oauthProvider` (`auth_secret_key.dart:8-9`) are now only cleared on logout. The deprecated native-storage importer copies `...AuthSecretKey.values` (`legacy_native_storage_migration_repository.dart:27`).
- Proposal:
  - Delete the 3 methods and their tests now.
  - Keep the 2 keys and their `clear*` calls until the v1.9.1 native-storage importer retires, because they wipe values written by released builds. Then remove them together with the importer.
- Size: about 45 lib lines and about 60 test lines removed; 2 files.
- Risk: low. Auth flow is unchanged (verified that nothing reads these values).
- Confidence: verified.
- Decision needed: none.

### MC-7 Route parsing still falls back to `""` for missing ids
- Category: rule-violation (empty string as missing data)
- Evidence: `client/module_core/lib/src/routing/app_routes.dart:388,390` (`AppRouteSessionDetail.fromParams`) and :445,447 (`AppRouteSessionDiffs.fromParams`) use `pathParams[...] ?? ""`. The newer sibling routes at :275 and :491-493 throw `ArgumentError("Missing ... identity")` instead.
- Proposal: use the same `?? (throw ArgumentError(...))` form, so a malformed deep link fails loudly instead of loading a session with id `""`.
- Size: 4 lines changed.
- Risk: low. GoRouter supplies these path params for these patterns, so the change only affects malformed internal paths.
- Confidence: verified.
- Decision needed: none.

## Checked and kept
- **Mechanical unref.tsv (84 test-only / 34 unreferenced):** the real items are in MC-1, MC-3 and MC-6. The rest are false positives:
  - extension members used implicitly
  - `RealtimeVoiceErrorCode` values parsed from the wire
  - `FileTypeBadge` used in switches
  - freezed factory names
  - the `withClock` `@visibleForTesting` constructor
  - the `setLogLevel` logging API
  - `emitStatusForTesting` and `sendTail` (deliberate test hooks)
  - `MockPluginManagementService` and the other helpers in `lib/src/testing` (that library is deliberate since #1038, which is also why mocktail is a production dependency)
- `VoiceRealtimeSampleRate.hz24000/44100/48000`: unused values, but they document the server contract. Cosmetic.
- deps.tsv:
  - module_persistence `sqlite3`: kept, because it backs `NativeDatabase` through `drift/native.dart` and the native hooks.
  - module_auth `json_annotation`: kept, because json_serializable requires it.
  - builder and linter dev dependencies are tooling.
- **Compatibility markers in scope** (session_api :244/:294; plugin_repository :281/:294; project_repository :35; session_repository :159/:172/:253; session_auto_continuation :18; session_detail_load :337; session_window :73/:79/:384; file_preview :18; legacy native storage importer :18): every one guards a route or field that public bridges up to v1.10.1 or older lack, or released mobile data. No support floor has been declared, so none is retirable yet.
- `voice_repository.dart:111` (v1.8.2, auth server omits retryability): I could not verify whether the deployed auth server always sends it. If it does, about 5 lines can go. Needs a server check.
- Remote Config flags (`client/app/lib/core/platform/remote_config_flags.dart`, out of scope): every flag is read. `voiceLiveEnabled` stays gated on purpose until the Firebase setting is done. The voice engine picker has no embedded-model leftovers.
- **E2 thumbnail whole-cache pruning** (`message_image_repository.dart:336,415`): unchanged since the 2026-09 audit. Still deferred until a measured benefit exists.
- `SessionDetailCubit` (3507 lines, 21 dependencies): the previous audit declined a size-only split, and nothing in the code changes that. Its largest section is the message queue (about 760 lines, :2173-2932). If a split is ever wanted, that section is the natural seam, but no concrete risk reduction was found.
- `NewSessionOptionsState` (11 variants): no UI switches on them; the UI reads derived getters. It is an internal state machine and each variant is produced. Collapsing them would need a design pass, and I found no verified excess.
- `ProjectListCubit` forwards to `ProjectInventoryService`. That matches the documented presentation-adapter pattern. The onboarding analytics forwarders hosted in `ProjectInventoryService:151-199` are a small cohesion oddity and not worth moving on their own.
- Test null assertions: about 145 in module_core tests, none in lib. Tests are lint-exempt, and converting them is cosmetic.
- Locally redeclared one-line mocktail mocks (`MockAuthSession` x9, `MockConnectionService` x6, etc.) while `test_helpers` exports some of them: one-line declarations, and some avoid the shared mocks' default stubs on purpose. Not worth churn.
- Retired-plan sweeps (pr-tracking-removal, app-simplification, voice-live, heavy-users): only the leftovers in MC-1 (including the stale "PR-data wait" comment), MC-2 and MC-3 were found. The remaining voice-live code backs a live, gated feature.
- Cross-boundary notes for the other auditors:
  - `FlutterUrlLauncher` does not log launch failures (MC-5).
  - `docs/regression/projects-and-sessions.md:736-741` has the rename claim (MC-2).
  - `archived_sessions_navigation_test:332` in `client/app` uses `reassertViewingSession` (MC-3).
