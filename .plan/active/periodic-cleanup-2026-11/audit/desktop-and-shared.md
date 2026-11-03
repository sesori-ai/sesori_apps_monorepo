# Desktop shell, desktop core, sesori_shared and no_slop_linter cleanup audit

`inpub.sh <regex> <paths>` below is a local helper: it runs `git grep -E <regex> <tag> -- <paths>` for every public tag (`bridge-v0.3.0`…`bridge-v1.0.7` and `v1.0.8`…`v1.11.0`, without v1.9.2, v1.10.0 and v1.10.2).

## Summary
Overall these four packages are healthy. Desktop production code has no null assertions, and its wire types carry fewer leftovers than expected. Every update engine and every bundled-bridge resolver path is still live, so the retired desktop plans left no bundled-bridge leftovers. Nearly all the debt is dead library code that nothing calls, plus linter rules that never run.

Top 3 opportunities:
1. **DS-1:** Delete about 990 lines of `sesori_shared` concurrency code that nothing uses: the isolate pools, `ConcurrentCache` and `IterableExtensions`. This is the sibling of the module_core copy deleted in #1019.
2. **DS-2:** Retire about 715 lines of no_slop_linter rules that never run. One rule is commented out, two are lint rules that no `analysis_options.yaml` turns on, and one guards `dartz`, a package nothing depends on.
3. **DS-3 and DS-4:** Remove dead wire content:
   - The OpenCode-only `GlobalSession` and `SessionProject` types, about 425 lines including generated code.
   - The never-rendered `ControlPromptKind.loginNeeded` control prompt, about 80 lines. No compatibility is owed because the GUI and helper always ship together.

About 2,500 lines can go without a product decision. With the decisions below the total reaches about 2,900 lines, plus about 200 linter suppression comments.

## Findings

### DS-1 Delete the dead concurrency code in sesori_shared
- Category: leftover
- Evidence:
  - The isolate code in `shared/sesori_shared/lib/src/concurrency/isolate/**` is 597 lines with no tests. It covers MultiTaskIsolate, SingleTaskIsolate, the pools, transient isolates, the vm/web/stub platform files, `IsolateConfigs` and `IsolateTask`. The barrel exports it at `lib/sesori_shared.dart:5`.
  - Searching every `.dart` file outside that directory for `MultiTaskIsolate|SingleTaskIsolate|TransientIsolate|IsolateConfigs|IsolateTask` finds nothing.
  - `concurrency/concurrent_cache.dart` (55 lines, exported at `:2`) has no production users anywhere; `ConcurrentCache` and `getOrFetch` appear only in `test/concurrency/concurrent_cache_test.dart` (232 lines).
  - `extensions/iterable_x.dart` (30 lines) provides `reduceSafe`, `partition` and `toUnmodifiableList`. Its only production caller is the dead `multi_task_isolate_pool.dart`; its test is `test/extensions/iterable_x_test.dart` (74 lines).
  - `package:collection` is imported only by `iterable_x.dart`.
  - This code is the twin of the module_core copy deleted in 00cc035638 (#1019, 1,366 lines). Neither the previous audit nor CONSOLIDATION recorded a reason to keep the shared copy.
- Proposal:
  - Delete the isolate directory, `concurrent_cache.dart`, `iterable_x.dart`, their tests and the three barrel exports.
  - Drop the direct `collection` dependency if `dart analyze` stays clean. freezed_annotation already re-exports `DeepCollectionEquality`.
- Size: about 680 library lines and 306 test lines removed. Touches 15 or more files in sesori_shared only.
- Risk: low. Nothing outside the package uses it, and Dart packages have no external consumers. No wire, database or user-visible impact.
- Confidence: verified. The `collection` dependency removal still needs `dart analyze` to confirm.
- Decision needed: none

### DS-2 Retire no_slop_linter rules that never run, and fix the stale plugin docs
- Category: leftover
- Evidence:
  - `prefer_size_const`: its registration is commented out in `shared/no_slop_linter/lib/main.dart` (`// registry.registerWarningRule(PreferSizeConstRule(...))`). It has been disabled since the package was imported (b65aada389, 2026-05-18). No `SizeConst` class exists anywhere in the repo. The rule is 83 lines and its test is 64.
  - `avoid_hardcoded_colors` (64 + 54 lines) and `avoid_hardcoded_text_styles` (73 + 58 lines) are registered with `registerLintRule`, which leaves them disabled by default.
    - None of the four `analysis_options.yaml` files that load the plugin turns them on: `bridge/`, `bridge/app/`, `client/` and `shared/sesori_shared/`. They have never run since the linter was added (f11e0b6e61, 2026-03-30).
    - Turning them on today would flag about 100 color literals and about 20 `TextStyle(` calls, mostly in module_app_ui and module_prego.
  - `avoid_dartz_tuple` (82 lines) and its fix `dartz_tuple_to_record_fix` (71 lines), plus their tests (79 + 87 lines):
    - No package in the repo depends on `dartz`. Only no_slop_linter's own dev dependencies list it, for these tests.
    - The rule can never fire.
  - `main.dart` header comment and README:
    - The header tells users of `avoid_navigator_of` to "use AutoRoute", but the project uses GoRouter.
    - The header lists `prefer_size_const`, which is disabled, and omits `avoid_raw_go_router`.
    - The README configuration example uses the old `analyzer: plugins:` layout.
  - The 13 no_slop_linter entries in `unref.tsv` are false positives: they are visitor `visit*` overrides and `diagnosticCodes`.
- Proposal:
  - Delete the four rules and the dartz fix, with their tests and registrations.
  - Remove the `dartz` dev dependency.
  - Update the `main.dart` header and the README list to match the registered rules.
- Size: about 373 library lines and 342 test lines removed. Touches about 12 files in `shared/no_slop_linter`.
- Risk: low. These rules produce no diagnostics today, so analysis results do not change.
- Confidence: verified
- Decision needed: should hardcoded colors and text styles be enforced? If so, turn the two lint rules on and fix or suppress about 120 sites, mostly in module_app_ui and module_prego. Otherwise delete them as proposed. Deletion is the default because they have been off for seven months.

### DS-3 Delete the dead OpenCode `GlobalSession` and `SessionProject` wire types
- Category: leftover (also a rule violation: a backend concept outside its plugin)
- Evidence:
  - `shared/sesori_shared/lib/src/models/sesori/session.dart:97-130`. The doc comments describe them as the OpenCode `/experimental/session` `GlobalInfo` and `ProjectInfo` types, which is a backend concept sitting in shared code.
  - Searching `bridge` and `client` finds no references at HEAD.
  - `inpub.sh '\bGlobalSession\b|\bSessionProject\b' bridge client` found no references in any public release from bridge-v0.3.0 to v1.11.0, so they were never on the wire.
  - Generated code: about 350 lines in `session.freezed.dart` (lines 859 to about 1210) and about 40 lines in `session.g.dart`.
- Proposal: delete both classes and regenerate sesori_shared.
- Size: about 35 hand-written lines and about 390 generated lines removed. One source file plus generated output.
- Risk: low. No wire impact because the types were never sent.
- Confidence: verified
- Decision needed: none

### DS-4 Remove the never-rendered `ControlPromptKind.loginNeeded` control prompt
- Category: leftover
- Evidence:
  - The bridge sends the prompt from `bridge/app/lib/src/services/control_prompt_service.dart:58-83` (`announceLoginNeeded`). Its only caller is `bridge/app/lib/src/runtime/bridge_runtime_runner.dart:547`, and the method has three tests at `bridge/app/test/services/control_prompt_service_test.dart:116-141`.
  - On the desktop side, every prompt goes into `BridgePromptTracker`. The only consumer, `DesktopBridgeTakeoverOrchestrator` at `desktop_bridge_takeover_orchestrator.dart:145`, drops anything that is not `replaceBridge`. A `loginNeeded` prompt is never shown; it is cleared only when the helper disconnects.
  - The real signal is the auth-required exit code: "the exit code is the authoritative signal", per the runner comment.
  - Under the documented contract (`control_message.dart:11-14`), the GUI talks only to the helper from its own bundle and release builds reject a mismatched build identity. No cross-version compatibility is owed.
  - The `unknown` fallbacks are also unreachable:
    - The bridge never sends `ControlPromptKind.unknown` or `ControlRelayConnectionState.unknown`; see `control_status_notifier.dart:167-176`.
    - The fallbacks exist only for "a newer helper", which the build-identity check rules out.
    - `ControlStartupState.unknown` is different: it is the real "no status yet" seed at `bridge_control_status.dart:29`, so it stays.
- Proposal:
  - Delete `announceLoginNeeded` and its call and tests.
  - With `loginNeeded` gone, `promptRequest` only ever means replace-bridge, so drop `ControlPromptKind` and the `kind` field along with the takeover filter.
  - Drop the `unknownEnumValue` fallback and `unknown` value on `ControlRelayConnectionState`, plus the two cubit switch arms (`bridge_control_cubit.dart:556`, `bridge_control_state.dart:123`).
  - Update the three desktop tests that build `loginNeeded` prompts.
- Size: about 80–100 lines removed. Touches about 10 files across bridge/app, sesori_shared and module_desktop_core.
- Risk: low. The GUI and helper ship together, so there is no user-visible change.
- Confidence: verified
- Decision needed: none

### DS-5 Delete the duplicate EventQueue test in bridge/app
- Category: test-debt
- Evidence:
  - `bridge/app/test/bridge/event_queue_test.dart` (276 lines, 13 cases) tests `EventQueue` from sesori_shared and uses no bridge types.
  - `shared/sesori_shared/test/concurrency/event_queue_test.dart` (829 lines, 42 cases) covers the same behaviors: FIFO order, auto-drain, enqueue during drain, head retention on error, poison drop, maxSize, pause/resume, buffering, dispose, cancel/re-listen and orphan buffering.
  - The bridge suite's one apparently unique case, "dequeue callback can serialize payload envelope" (lines 40-55), only tests `jsonEncode` of a `SesoriSseEvent` and says nothing about the queue.
  - Production user: `bridge/app/lib/src/sse/sse_manager.dart`.
- Proposal: delete the bridge copy. Before deleting, spot-check that each of its 12 queue cases has a counterpart in the shared suite.
- Size: 276 test lines removed. One file.
- Risk: low.
- Confidence: verified. The case mapping is by name.
- Decision needed: none

### DS-6 Re-check of the deferred desktop attention finding
- Category: simplification (re-check of a deferred item)
- Evidence:
  - `client/module_desktop_core/lib/src/services/desktop_attention_service.dart` is now 628 lines (605 at deferral). Its state has not changed shape:
    - four subscriptions;
    - `_pendingRequests`, `_attentionGenerations`, `_sessionNotificationWrites` and `_inFlightNotifications`;
    - six bools at lines 59-64;
    - two counters.
  - Five commits since deferral (d1813409e3, f1e3276591, 42bd804bca, ff232d332c, 97d3220526) added 47 lines and removed 24. Its test file is 1,263 lines.
  - Reopening condition from CONSOLIDATION:
    - Half met: Gate C was retired on 2026-09-26, and desktop has shipped publicly since v1.10.1.
    - Not met: desktop-app is still in `.plan/active`, with step 21 (regression docs) and step 22 (coverage and retirement) pending.
  - The logout, disposal and auth-cleanup barrier contract still applies. Callers are `desktop_logout_orchestrator.dart:101,103,107,189`.
  - A small slice is independent of that contract. Notification-open routing at `desktop_attention_service.dart:574-605` duplicates `client/module_core/lib/src/routing/notification_open_dispatcher.dart:108-145`:
    - both build the `AppRouteSessionDetail` the same way;
    - both apply the same `showsEditableLocation` short-circuit;
    - both send the same `RouteStack` of home plus session.
- Proposal:
  - (a) Now: extract the shared "open session detail from a notification" step into module_core (a function taking the route dispatcher, route source and request) and call it from both. Desktop keeps its window-show, logout fence and accountId gate; phone keeps its computer switch.
  - (b) The state consolidation, roughly 600–900 lines, stays a dedicated architecture-reviewed scope. It must demonstrate the CONSOLIDATION barriers first: synchronous rejection, awaited native writes and cancellation before credential removal, and a finite drain for disposal and auth cleanup. It also needs deterministic tests and native evidence.
- Size: (a) about 25 lines removed. (b) about 600–900 lines changed.
- Risk: (a) low. (b) medium to high: it touches the account boundary at logout.
- Confidence: verified
- Decision needed: schedule (b) now, since desktop is public and Gate C is retired, or after desktop-app step 22 retires the plan? (a) can land either way.

### DS-7 Phone and desktop platform adapter copies have grown since the deferral
- Category: simplification (re-check of the deferred "Shared Flutter adapters" item)
- Evidence: there are now 11 near-identical pairs in `client/app/lib/core/platform/` and `client/desktop/lib/core/platform/`, about 230 lines on each side.

  Byte-identical after renaming:
  - image clipboard, 15 lines
  - `path_provider_temporary_directory_provider`, 12 lines
  - master key store, 12 lines

  Differing by 1–7 lines:
  - file image saver, 17/19 lines
  - file save client, 19 lines
  - pasteboard client, 12 lines
  - image sharer, 29 lines
  - no-op feedback-prompt config source, 11/10 lines
  - no-op founder-call config source, 19/17 lines
  - route dispatcher: `go_router_route_dispatcher.dart` and `desktop_route_dispatcher.dart`, 76 lines each. They differ only in router injection (global `appRouter` versus an injected `GoRouter` and `routerReady`) and in the phone's extra navigator key when dismissing popups.

  The temp-dir provider, master key store and founder-call copies are new since the deferral.

  Some of these need no new dependencies:
  - The two no-op config sources import only `injectable` and `sesori_dart_core`.
  - The route dispatcher needs only `flutter` and `go_router`, which module_app_ui already depends on.
- Proposal:
  - (a) Now, with no change to the dependency boundary: move the route dispatcher, parameterized by router, readiness future and popup navigator keys, into module_app_ui. Move the two no-op config sources into module_core next to their interfaces. Shells keep their DI registrations.
  - (b) The remaining plugin-backed adapters (file_selector, pasteboard, path_provider, share_plus, flutter_secure_storage) still depend on the deferred decision about module_app_ui dependencies.
- Size: (a) about 105 lines removed across 6 files. (b) about 125 more lines.
- Risk: low for (a); routing is covered by existing dispatcher tests. (b) needs the device proof that CONSOLIDATION asks for.
- Confidence: verified
- Decision needed: approve (b), the module_app_ui (or a new small Flutter platform package) dependency boundary for plugin adapters? (a) needs no decision.

### DS-8 Production APIs that only tests use, or nothing uses, in sesori_shared
- Category: leftover
- Evidence:
  - `OAuthProvider.apiCallbackPath` (`models/auth/auth_provider.dart:41`) has zero references, including tests.
  - `RelayProtocol.canEncryptMessage` (`protocol/constants.dart:27-29`) is used only in tests. Production checks `maxPlaintextMessageBytes` directly in `relay_client.dart`.
  - `RelayCryptoService.decodePublicKey(String)` (`crypto/crypto_service.dart:89-95`) is used only in tests. Production calls `decodePublicKeyFromBytes` from bridge `key_exchange.dart` and client `relay_client.dart`.
  - `EventQueue.isPaused` (`concurrency/event_queue.dart:152`) is used only in tests (13 references).
- Proposal: delete the four members and point their tests at public behavior or the bytes API.
- Size: about 20 library lines and about 30 test lines.
- Risk: low.
- Confidence: verified
- Decision needed: none

### DS-9 Client pubspecs list no_slop_linter as a dev dependency they don't need
- Category: leftover
- Evidence:
  - Nine client pubspecs declare `no_slop_linter: path:`: app, design_catalog, desktop, module_app_ui, module_auth, module_core, module_desktop_core, module_persistence and module_prego.
  - The plugin is loaded through the `plugins:` section of `client/analysis_options.yaml`, the same way `bridge/analysis_options.yaml` loads it. Bridge packages have no such dependency and CI analysis there works.
  - deps.tsv reports `module_persistence` as "no import".
  - The dependency pulls the linter's tight `analysis_server_plugin >=0.3.18 <0.3.19` and `analyzer >=13.3.0 <14` constraints into the client's dependency resolution, which constrains codegen and analyzer upgrades.
- Proposal: remove the nine dev dependencies, then confirm with `dart analyze --fatal-infos` in one client package that plugin diagnostics still appear.
- Size: about 18–27 lines across 9 pubspecs, plus lockfiles.
- Risk: low. If the analysis server needs the dependency, plugin diagnostics would silently disappear, so the verification step is required.
- Confidence: likely. Not verified by running the analyzer.
- Decision needed: none

### DS-10 Stale package docs
- Category: leftover (stale docs)
- Evidence:
  - The STRUCTURE and WHERE TO LOOK sections of `shared/sesori_shared/AGENTS.md` (lines 11-37) still describe:
    - `models/opencode/`, which is now `models/sesori/`;
    - "24 exports";
    - "RelayMessage — 11 variants";
    - "Add OpenCode model".

    They omit the concurrency, transcript, voice, auth and control-protocol areas.
  - `client/desktop/AGENTS.md:61` says "Desktop is unpublished: sign out in an old per-value-storage build…". The shared store landed in 6056290483 (2026-09-26), before the first public desktop release, v1.10.1 (2026-10-27). Public desktop builds never used per-value storage.
- Proposal:
  - Replace the sesori_shared STRUCTURE tree with a short, accurate area list.
  - Delete the desktop "unpublished" sentence and its sign-out advice.
- Size: about 30 lines changed in 2 files.
- Risk: none.
- Confidence: verified
- Decision needed: none

### DS-11 `Session.branchName` is kept only for older public apps but has no marker
- Category: leftover (compatibility bookkeeping)
- Evidence:
  - `shared/sesori_shared/lib/src/models/sesori/session.dart:47-51` declares `required String? branchName`. Its comment describes worktree semantics, but no current client production code reads it; the only client hits are `module_core/lib/src/testing/test_helpers.dart:704,733`. #2050 (2026-10-25) removed the display.
  - `inpub.sh '\.branchName' client` shows public apps v1.6.0–v1.9.1 read it.
  - The bridge still fills it from `session_dao` and `session_catalog_mapper`.
  - Missing keys decode as null in those apps, so dropping the field degrades rather than breaks them: they just lose the branch label.
- Proposal:
  - Either add a `// COMPATIBILITY 2026-11-02 (v1.11.0): Apps v1.6.0–v1.9.1 show the session branch…` marker and fix the comment,
  - or drop the field from the wire model while the bridge keeps its own column.
- Size: 2 lines changed (marker), or about 5 lines plus generated code (drop).
- Risk: dropping it removes the branch label in v1.6.0–v1.9.1 apps connected to new bridges.
- Confidence: verified
- Decision needed: mark and keep, or accept the cosmetic loss in older apps and drop it? This falls under the compatibility-floor decision.

### DS-12 Legacy `server.*` and `global.disposed` SSE variants
- Category: leftover (depends on the compatibility floor)
- Evidence:
  - `shared/sesori_shared/lib/src/models/sesori/sesori_sse_event.dart:36-49` defines `serverConnected`, `serverHeartbeat`, `serverInstanceDisposed({directory})` and `globalDisposed`.
  - Only public bridges bridge-v0.3.0 through v1.4.1 produce them (`inpub.sh` on `SesoriSseEvent.server*` and the variant constructors in `bridge`). No bridge from v1.5.1 on produces them.
  - Clients from v1.2.0 to HEAD list them only in ignore arms:
    - `sse_event_tracker.dart:111-114`
    - `session_list_cubit.dart:77-80`
    - `session_detail_cubit.dart:1494-1497` and `:1570-1573`
    - `server_connection/models/sse_event.dart:34-37`
  - Removing them would make old bridges' heartbeats decode as unknown types. The client already skips those with a `logw` in `connection_service`, so the cost is log noise against bridges up to v1.4.1, not a failure.
- Proposal: delete the four variants and their five sets of ignore arms once the supported bridge floor is above v1.4.1.
- Size: about 35 hand-written lines plus about 150 generated lines.
- Risk: low. Against bridges up to v1.4.1, each old heartbeat becomes a warning log line.
- Confidence: verified
- Decision needed: raise the minimum supported bridge above v1.4.1? This is CONSOLIDATION item 7; the compatibility auditor owns the floor.

### DS-13 Too many suppressions for `prefer_specific_type`
- Category: simplification (linter weight)
- Evidence:
  - The repo has 252 `no_slop_linter/prefer_specific_type` suppressions, against 56 for the next most-suppressed rule, `prefer_required_named_parameters`.
  - About 150 justify a JSON or wire boundary ("json parsing callback", "ACP JSON object values are heterogeneous", `Map<String, Object?>` typedefs).
  - About 47 justify a caught-error or `cause` value ("caught Dart failures can be Error or Exception", "causes can be any object"). That pattern is exactly what AGENTS.md asks for: keep the original in `innerError` or `cause`.
  - The rule already exempts `fromJson` and `toJson` signatures; see `prefer_specific_type_rule.dart:14-30`.
- Proposal: widen the exemptions to:
  - `Map<String, Object?>` and `Map<String, dynamic>` JSON maps;
  - `dynamic` and `Object?` parameters of JSON decode callbacks;
  - `Object` error, cause and innerError fields and parameters, including `(Object error, StackTrace)` handlers.

  Then delete the suppressions those exemptions cover.
- Size: about 40 rule lines added, about 150–200 suppression lines removed across about 100 files.
- Risk: low. This only changes lint behavior, though wider exemptions catch fewer real `Object` uses.
- Confidence: likely. Categories come from a keyword classification of the suppression reasons.
- Decision needed: widen `prefer_specific_type` exemptions as above, or keep the strict rule with suppressions?

### DS-14 Null assertions in tests within scope
- Category: rule-violation
- Evidence:
  - Production code in scope has none; the linter enforces this.
  - Tests have about 36: client/desktop 13, module_desktop_core 12, sesori_shared 11. Examples:
    - `invocation.namedArguments[#state]! as …` in `desktop_instance_service_test.dart:105,150,175`
    - `processService.stopGate!.complete()` in `bridge_control_cubit_test.dart:533,552,584,807,938`
    - `Platform.environment[...]!` in `test/native/packaged_*_probe.dart`
  - `avoid_bang_operator` is registered with `ignoreTestFiles: true` (`main.dart`), so tests are exempt by design.
- Proposal: if the no-null-assertion rule should cover tests, set `ignoreTestFiles: false` for `avoid_bang_operator` and fix the sites. They are mostly a typed-gate getter or a `case` pattern.
- Size: about 36 sites changed in about 15 test files. Repo-wide the count would be larger.
- Risk: low.
- Confidence: verified (counted with a regex)
- Decision needed: should `avoid_bang_operator` apply to test files?

## Checked and kept
- **Sparkle and Velopack update engines:** both live. `DesktopInstallKind` (`desktop_install_kind.dart`) uses Sparkle on macOS, Velopack on Windows and AppImage, and the system package manager for DEB and RPM.
- **Bundled bridge:** `desktop_bridge_executable_path_resolver.dart` and the `SESORI_DESKTOP_BRIDGE_PATH`, `_BUNDLE_IDENTITY` and `_RELEASE_CHANNEL` variables are live, used by the release bundle and CI qualification scripts. No retired-plan leftovers found.
- **Window and gesture overrides in `unref.tsv`:** `onWindow*` in `flutter_window_host.dart`, `didUpdateTweens`/`forEachTween` in `desktop_cockpit_shell.dart` and `hasSufficientGlobalDistanceToAccept` in `desktop_window_drag_area.dart` are framework overrides. False positives.
- **Test seams:** `helperConnectionStream` (`control_channel_server.dart:62`) and `parsePathStream` (`io_bridge_process_environment.dart:126`) expose live private logic. Removing them only reshapes tests.
- **Shared extensions:**
  - `storedImage` is used in bridge `chat_history_repository`.
  - `safeRemoteUri` is used in module_app_ui and module_core.
  - `hasRenderableUserContent` has 18 production references.
  - Every `sugar_dart` member is used.
- **`wait2` (`future_x.dart`):** used 17 times in the OpenCode plugin. Replacing it with the record `.wait` would change errors to `ParallelWaitError`.
- **deps.tsv entries for module_desktop_core and desktop:** json_annotation, json_serializable, freezed, injectable_generator and build_runner all drive code generation (`BridgeRegistrationRecord`, `DesktopSidebarLayout`, `injection.config.dart`).
- **Fields still required by public app decoders:** `CatalogImportProgress.projectsSeen`/`completedAt`, `Message.error.errorName` and `SessionAutoContinuationStatus.resetAt` are `required` in released decoders, so the bridge must keep sending them until the floor is above v1.11.0.
- **Base-branch and PR-refresh wire:** `BaseBranchResponse` and `SetBaseBranchRequest` (apps v1.2.0–v1.9.1), and `PullRequestRefreshSettingsResponse` and `pullRequestRefreshInterval` (apps v1.7.0–v1.9.1), are still served for public apps and already compatibility-marked. The compatibility auditor owns them.
- **`McpConnectorOfferTarget.offerKey`:** the client passes it back unread. It is the bridge's correlation key, not a leftover.
- **Empty-string defaults:** `MessagePart` `@Default("")` fields and `Project.path @Default("")` are empty-as-missing, but they carry v1.8.1 and v1.5.0 compatibility markers. The compatibility auditor owns their retirement.
- **Non-bridge enums:** `NotificationEventType`, `AuthClientType`, `DevicePlatform`, `BridgeConnectionNotificationPolicy` and `RelayMessage` presence variants serve relay and auth-server peers, not client↔bridge. They are outside the floor rules.
- **`io_launch_at_login.dart:234-245` reads HOME/USERPROFILE:** the AGENTS rule covers bridge code only, and the desktop GUI has no `sesori_bridge_foundation` dependency. Single site.
- **`jwt_claims.dart` `catch (_)`:** documented never-throw contract, where null means "no claim". Not a swallowed failure.
- **Duplicated desktop test fakes:** `_FakeControlChannelServer` (×3, 16–41 lines) and `_RecordingLogSink` (×3) are small. The other repeated `Mock*` classes are one-liners. Not worth centralizing (CONSOLIDATION item 13).
- **Big files:** `bridge_process_service.dart` (838), `desktop_settings_modal.dart` (610) and `bridge_control_cubit.dart` (589) were reviewed for duplication. No concrete split with clear risk reduction beyond DS-6.
- **Other linter rules:** the remaining warning rules have few suppressions (go_router 21, navigator 12, modal 7, as-cast 7, bang 8) and encode live project conventions (Tabler icons, Prego modals, GoRouter, directional layout). They earn their keep.
- **Out of scope, noted for the relevant auditors:**
  - `client/app/docs/openapi.json` (328 KB) is an OpenCode OpenAPI spec under client docs.
  - `NotificationOpenDispatcher._dispatch(NotificationOpenRequest request)` in module_core takes a positional parameter.
