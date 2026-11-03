# Bridge services, runtime, updater, push and runtime packages cleanup audit

## Summary

The service side is in better shape than the last audit found. Every listener has a live trigger. Both COMPATIBILITY markers in scope still have unmet retiring conditions. The E4 dispatcher deferral still holds, because that code is unchanged since 2026-08-22. The debt sits in four places:
- write-only or test-only state in the updater and push subsystems
- one duplicated composition (the updater in `bin/` and in the runner)
- two-phase initialisation in `PluginLifecycleService`
- small dead policy knobs in `sesori_plugin_runtime`

Top three opportunities:
1. Drop the push maintenance telemetry and prune results that nobody reads (BS-1).
2. Remove dead updater model state such as `currentEligible`, `UpdateResult.alreadyLocked` and `UpdateStage` (BS-2).
3. Build the updater once, shared by `bin/bridge.dart` and `BridgeRuntimeRunner` (BS-3).

Rule debt is concentrated rather than wide:
- about 30 null assertions outside regex groups
- 1 direct `HOME` read
- 3 default-constructed dependencies
- about 4 swallowed rollback or monitor errors

Estimated total removable: roughly 800-1,100 production lines plus about 350 test lines. No wire or DB change is needed for any finding except BS-25, a shared close-code fallback that has no wire impact on the bridge side.

## Findings

### BS-1 Push maintenance telemetry and prune results nobody reads
- Category: leftover
- Evidence:
  - 8 of the 14 `PushSessionTelemetrySnapshot` fields are never read in production.
  - The `PushPrunableRoot` and `PushPrunedSubtree` fields are read only by tests.
  - `PushMaintenanceTelemetryBuilder` (82 lines) builds a `Log.d` line, which is hidden at the default log level.
  - `push_maintenance_telemetry.dart:68-74` swallows a failure with `catch (_)`.
  - Production rg: builder 4 refs, all inside the push subsystem. Test rg: 6.
- Proposal: pick one of two options.
  - (A) Keep one slim debug line: root count, pruned count and duration, computed inline in the tracker.
  - (B) Drop the telemetry entirely and return only what `PushNotificationService` acts on.
- Size: (A) about 110-150 production lines, (B) about 200; plus the matching tests. Files: `push/push_maintenance_telemetry.dart`, `push/push_session_state_tracker.dart`, `push/push_notification_service.dart` and their tests.
- Risk: low. Only debug logging is affected. No wire, DB or user-visible impact.
- Confidence: verified (subagent ref counts; I spot-checked the builder refs).
- Decision needed: A (keep a slim line) or B (drop it)? Is anyone still using this log for heavy-user diagnosis?

### BS-2 Dead updater model state
- Category: leftover
- Evidence:
  - `UpdateResolution.currentEligible` is declared at `updater/models/update_resolution.dart:9` and written only at `release_repository.dart:92`. No production code reads it.
  - `UpdateResult.alreadyLocked` (`update_result.dart:4`) is never produced. Its only production reference is the `case` at `update_service.dart:217`; `LockAcquireResult.alreadyLocked` is a different enum.
  - `UpdateAttempt.stage` and `UpdateStage` are written but never read.
  - `publishedAt` is never read, yet `release_repository.dart:194-203` throws when it is missing.
  - The `ReleaseInfo` JSON codegen is used only by tests.
  - `CachedRelease.track` is a `@Default('stable') String`, a magic string, and the check at `release_repository.dart:58-67` repeats the one at 97-100.
  - `ExplicitUpdateApplied.fromVersion` is nullable but always set.
  - `_kGithubReleasesMaxPages = 1` makes the paging loop run exactly once.
- Proposal:
  - Delete the unread fields, the enum value, the stage tracking and the unused codegen.
  - Make `fromVersion` non-null.
  - Inline the single page fetch.
  - Remove the duplicated track check, or make `track` an enum.
- Size: about 80-120 lines, plus generated churn. About 8 files under `lib/src/updater/`.
- Risk: low to medium.
  - The cached-release JSON on disk is a local file, not a wire contract. Dropping fields is still tolerant, because unknown keys are ignored.
  - Removing the `publishedAt` throw makes the parse more lenient, not less.
- Confidence: verified (`alreadyLocked` and `currentEligible` rechecked with rg). The rest comes from the subagent.
- Decision needed: if `stage` goes, should the downgrade-parse warning that mentions it stay as a plain log?

### BS-3 Updater composition duplicated in `bin/` and the runner
- Category: simplification
- Evidence:
  - `UpdateCommand.run` (`bin/bridge.dart:686-795`) and `BridgeRuntimeRunner._buildUpdateLifecycleService` (`runtime/bridge_runtime_runner.dart:1180-1292`) each resolve the token and build the release, install and artifact repositories, the lock, and the apply and install services.
  - `currentDistributionTarget()` (`distribution_target.dart:48-50`) is a one-line wrapper that both paths call.
- Proposal:
  - Add one `buildUpdaterComposition(...)` (or a static on `UpdateLifecycleService`) that returns the services both paths need.
  - Fold the wrapper into it.
- Size: about 60-80 lines removed. Files: `bin/bridge.dart`, `runtime/bridge_runtime_runner.dart`, `updater/foundation/distribution_target.dart`.
- Risk: medium. Update is a release path. Covered by the updater service tests plus one manual `sesori-bridge update` dry run. No wire or DB impact.
- Confidence: verified (subagent trace).
- Decision needed: none.

### BS-4 Push production API used only by tests
- Category: leftover / test-debt
- Evidence:
  - `getRootIdleSince` has no references at all, not even in tests.
  - Only tests use these:
    - the `reset()` chain through tracker, notifier and service
    - `_lastMaintenanceTelemetry` and `lastMaintenanceTelemetry`
    - `isStarted`
    - the `findPrunableRoots` forwarder
  - `bridge_runtime_builder_test.dart:33-47, 136-176` tests only these seams.
  - `push_dispatcher_test.dart:214-229` duplicates an earlier case.
- Proposal: delete the methods and the tests that exercise only them.
- Size: about 35 production lines and about 190 test lines. About 6 files.
- Risk: low. Only tests are affected.
- Confidence: verified (`getRootIdleSince` has 1 lib ref, which is its declaration, and no test refs).
- Decision needed: none.

### BS-5 PluginLifecycleService two-phase initialisation
- Category: simplification / rule-violation (flattened nullable coordination fields)
- Evidence:
  - `services/plugin_lifecycle_service.dart` holds `_eligiblePluginIds`, `_setupById`, `_metadataSubject` and `_readyPluginIdsSubject` as nullable fields that `initialize()` fills.
  - About 13 `StateError("... not been initialized" / "already initialized")` guards check them, at lines 119, 131, 204, 219, 249, 255, 270, 414, 492, 546, 832, 1245, 1251 and 1369.
  - Null assertions at 208, 444 and 1279 exist only because of that shape.
  - The runner (`bridge_runtime_runner.dart:658-700`) does these steps in order, and nothing subscribes in between:
    1. construct the service
    2. call `uncontrollableDisabledPluginIds()` (678)
    3. call `lifecycleRepository.inspect` (693)
    4. call `initialize(...)` (697)
- Proposal:
  - Make `uncontrollableDisabledPluginIds` a top-level or static function over the descriptors.
  - Run `inspect` first, then construct the service with `setupById` and `disabledPluginIds` as required constructor parameters.
  - Then delete `initialize`, the nullable fields and every guard.
- Size: about 40-60 production lines removed. The test churn is mechanical: 64 `initialize(` calls in `test/services/plugin_lifecycle_service_test.dart` fold into a builder helper.
- Risk: low to medium. Startup ordering is the only thing that changes, and it is a single call site. No wire, DB or user-visible impact.
- Confidence: verified (runner call order read; no listener between construction and initialize).
- Decision needed: none.

### BS-6 `UpdateLock` dead options and legacy parse
- Category: leftover
- Evidence (`updater/foundation/update_lock.dart`, 320 lines):
  - `shouldReleaseLock` is dead: both production callers pass `(_) => true`.
  - The plain-pid lock parse at 295-301 is dead, because bridge-v0.3.0 already wrote JSON.
  - `isProcessAlive` is public but used only in this file and in tests.
  - `_LockOwner.fromJson` parses JSON by hand.
  - `_isPermissionDenied` duplicates `UpdateInstallService.isPermissionDenied`.
- Proposal:
  - Remove the predicate and the legacy branch.
  - Make `isProcessAlive` private.
  - Reuse the shared permission check.
  - Use a small `@JsonSerializable` record for the owner, or keep the hand parse if this is the file's only JSON.
- Size: about 40-60 lines. 2-3 files.
- Risk: low. A pre-v0.3.0 lock file cannot exist on a supported install.
- Confidence: verified (subagent). The v0.3.0 JSON format was checked against the tag.
- Decision needed: none.

### BS-7 `NdjsonProcessClient` frame policies that never vary
- Category: leftover
- Evidence:
  - `sesori_plugin_runtime/lib/src/transport/ndjson_process_client.dart:17-35, 61-62, 274-285` define `NonObjectFramePolicy` and `MalformedFrameLogPolicy`.
  - Both production callers pass the same values, `discard` and `metadataOnly`: `sesori_plugin_codex/.../codex_stdio_app_server_client.dart:22-23` and `sesori_plugin_acp/.../acp_stdio_client.dart:47-48`.
  - `_sanitizeForLog` is reachable only from the `sanitizedContent` arm.
- Proposal: delete both enums, the `failPending` and `sanitizedContent` branches, and the sanitiser. Hard-code discard plus a metadata-only log.
- Size: about 35-45 lines. 3 production files and their tests.
- Risk: low. Behaviour is identical for both callers.
- Confidence: verified (rg shows exactly these two callers).
- Decision needed: none.

### BS-8 Duplicated permission requestId-to-sessionId maps in push
- Category: simplification
- Evidence:
  - `PushSessionStateTracker` and `CompletionNotifier` each keep a requestID-to-sessionID map to resolve `SesoriPermissionReplied`, although that event already carries `sessionID`.
  - The `completion_notifier_test.dart:460` fixture builds the reply without `sessionID` and relies on the map.
- Proposal: read `sessionID` from the event, delete both maps and their cleanup, and fix the fixture.
- Size: about 35 lines. 2 production files and 2 test files.
- Risk: low. Worst case, a push badge for an old reply is wrong. No wire change, because the field is already sent.
- Confidence: verified (subagent).
- Decision needed: none.

### BS-9 `ManagedRuntimePathService` reads `HOME` directly
- Category: rule-violation / simplification
- Evidence:
  - `updater/services/managed_runtime_path_service.dart:22` calls `_requireEnv(... key: 'HOME')`. AGENTS.md requires `resolveUserHomeDirectory`.
  - The service rebuilds what `sesoriDataDirectory()` already computes.
  - `ManagedRuntimePaths.cacheDirectory` always equals `installRoot`.
  - Callers: `bin/bridge.dart:689`, `bridge_runtime_runner.dart:270, 447, 478, 1183`, `plugin_generation_factory.dart:48`, `server/host/plugin_state_directory.dart:13`.
- Proposal:
  - Derive the paths from `sesoriDataDirectory()` / `resolveUserHomeDirectory`.
  - Collapse `cacheDirectory` into `installRoot`.
  - Keep the on-disk layout byte-identical. The runner comment at 273 says the legacy shared plugin state directory is a cross-version contract.
- Size: about 20-30 lines. About 7 files touched, mostly call sites.
- Risk: medium. A wrong path would orphan managed runtimes, so the change needs a path-equality test on macOS, Linux and Windows. Also Windows `USERPROFILE` handling becomes correct for free.
- Confidence: verified (rg finds this as the only `'HOME'` read in scope).
- Decision needed: none.

### BS-10 `ManagedRuntimeHandle` flattened instead of sealed
- Category: rule-violation (flattened nullable fields)
- Evidence:
  - `sesori_plugin_runtime`'s `ManagedRuntimeHandle` carries a nullable `record` that only owned runtimes have.
  - Callers force it with `handle.record!` at `sesori_plugin_codex/.../codex_plugin_descriptor.dart:658` and `sesori_plugin_opencode/.../open_code_plugin_descriptor.dart:850`.
  - `identity` and `health` are read only by tests.
  - `RuntimeHealthProbe.version` and `.detail` are never set.
- Proposal: make it a sealed `OwnedRuntimeHandle` (non-null record) / `AttachedRuntimeHandle`, and drop the test-only getters and the never-set probe fields.
- Size: about 20-30 lines changed or removed. Runtime package plus 2 plugin descriptors.
- Risk: low to medium. The change is compile-checked, and only the plugin package internals move.
- Confidence: verified (subagent).
- Decision needed: none.

### BS-11 `RuntimeOwnershipRepository` single implementation with unused surface
- Category: simplification
- Evidence:
  - The interface has one implementation.
  - `readByOwnerSessionId` has no caller.
  - `isTrackingOwnedRuntime` is used only by tests (unref.tsv).
  - `trackOwnedRuntime` is used only inside the class.
  - Every caller passes `removeOwnership: true`.
- Proposal:
  - Merge the interface into the class (unless tests rely on the interface, in which case keep it, but trim it).
  - Delete the unused methods.
  - Make `trackOwnedRuntime` private.
  - Drop the always-true flag.
- Size: about 30-40 lines. 2-3 files in `sesori_plugin_runtime`.
- Risk: low.
- Confidence: verified (subagent plus unref.tsv).
- Decision needed: none.

### BS-12 Other production API used only by tests in runtime and services
- Category: leftover
- Evidence:
  - `RuntimeVersionValidator.detectVersion` (`sesori_plugin_runtime`, 156-166) is used only by tests.
  - `PluginRuntime.useStream` (`runtime/plugin_runtime.dart:731-742`) has no production caller; production uses `useStreamIfActive` and `useCatalogImportStream`. It has 12 test refs.
  - `PluginRuntime.isCurrentEventGeneration` (914) is used only by `isCurrentEvent` and tests.
  - `PluginLifecycleService.metadataSnapshot` (187) has 5 refs, all tests.
  - `SessionOperationDispatcher.activeLaneCount` is `@visibleForTesting` and unused in production.
- Proposal: delete `detectVersion` and `useStream`, and move their tests to the production entry points. Make `isCurrentEventGeneration` private. Delete `metadataSnapshot` and `activeLaneCount`, and have tests assert through the streams.
- Size: about 60-80 production lines plus test rewrites. 4 files.
- Risk: low.
- Confidence: verified (rg for each).
- Decision needed: none.

### BS-13 `extractSessionId` with unreachable arms
- Category: leftover
- Evidence:
  - The push `extractSessionId` switch handles 17 event arms, but only 2 can reach it from its callers.
  - The same event set is switched three times.
- Proposal: reduce the switch to the two reachable arms plus a default, and merge the triple switch.
- Size: about 30 lines. 1-2 files in `push/`.
- Risk: low.
- Confidence: verified (subagent caller trace).
- Decision needed: none.

### BS-14 `DynamicPortPolicy` re-checks bounds three times
- Category: simplification
- Evidence: in `sesori_plugin_runtime`, the port bounds are validated in the policy constructor, in the picker and in the probe.
- Proposal: validate once at construction and trust the value afterwards.
- Size: about 30-60 lines. 1-2 files.
- Risk: low.
- Confidence: verified (subagent).
- Decision needed: none.

### BS-15 Four `ManagedRuntime*Selected` subclasses that differ only by tag
- Category: simplification
- Evidence: in `sesori_plugin_runtime`, the four selection subclasses carry identical fields.
- Proposal: use one class plus an enum source.
- Size: about 25 lines. Runtime package and its plugin callers.
- Risk: low. Compile-checked.
- Confidence: verified (subagent).
- Decision needed: none.

### BS-16 Updater swallows rollback failures and drops stacks
- Category: rule-violation
- Evidence:
  - `updater/api/posix_update_api.dart:128-130, 139-141` and `windows_update_api.dart:129-131` catch rollback failures without logging them.
  - `posix_update_api.dart:104` writes to `stderr` instead of `Log`.
  - Mutable `@visibleForTesting` log seams (`update_service.dart:47-57`, `update_reconciliation_service.dart:32-36`, `update_apply_service.dart:33-34`) make about 18 log calls inline `$error` and drop the stack trace.
- Proposal: log rollback failures with error and stack, route the stderr write through `Log`, replace the seams with the normal `Log` API, and pass the stacks.
- Size: about 30-40 lines changed, a net reduction of about 10. 5 files.
- Risk: low. Logging only. A rollback failure is the moment this diagnosis matters.
- Confidence: verified (subagent).
- Decision needed: none.

### BS-17 Default-constructed dependencies
- Category: rule-violation
- Evidence:
  - `runtime/bridge_shutdown_coordinator.dart:33-34` has `backstopExitCode ?? _alwaysZero` and `exitProcess ?? io.exit`. The runner (173-178) passes `backstopExitCode` but not `exitProcess`. All 18 test constructions pass both.
  - `push/push_rate_limiter.dart:6` has `now ?? DateTime.now`.
  - `services/session_unseen_service.dart:38-40` has `now ?? DateTime.now().millisecondsSinceEpoch`. The orchestrator omits it at `orchestrator.dart:327` and tests pass it.
- Proposal: make each parameter required, and pass `io.exit` or the `ServerClock` from the runner and orchestrator.
- Size: about 10 lines changed. 3 production files and 2 composition sites.
- Risk: low.
- Confidence: verified.
- Decision needed: none.

### BS-18 Null assertions (grouped)
- Category: rule-violation
- Evidence (about 30 sites, excluding regex `match.group(n)!`):
  - `services/plugin_lifecycle_service.dart`: 208, 444, 1193, 1279, 1496 (`firstStackTrace!`)
  - `runtime/plugin_runtime.dart`: 208, 217, 241, 242, 844, 1458, 1459, 1749, 2159
  - `runtime/bridge_runtime_runner.dart`: 628, 669, 670, 672 (`pluginConfigs[descriptor.id]!`), 1094 (`options.controlUrl!`)
  - `runtime/bridge_shutdown_coordinator.dart`: 49, 78, 108 (`_actions[phase]!`)
  - `runtime/bridge_runtime.dart`: 84
  - `services/session_options_service.dart`: 450, 496
  - `services/session_unseen_service.dart`: 238, 285 (`row.activityAt!`)
  - `services/session_continuation_service.dart`: 171 (`model!.variant!`)
  - `bin/bridge.dart`: 107, 158, 161, 494 (map lookups); 136, 244, 267, 687 (`argResults!`); 164 (`globalResults!`)
  - `foundation/relay_client.dart`: 256, 292 (`current!`)
- Proposal, by pattern:
  - The `Error.throwWithStackTrace(first, firstStackTrace!)` pattern becomes a `(Object, StackTrace)?` record.
  - The phase and plugin map lookups become maps built from exhaustive enum or descriptor iteration, or a `switch` with a promoted local.
  - `argResults!` becomes a single local at the top of `run`.
  - The BS-5 sites disappear with BS-5.
- Size: about 40 lines changed, almost no net removal. About 10 files.
- Risk: low. Each site is local.
- Confidence: verified (rg `!\.|!\)|!;|!\]` and each site read).
- Decision needed: none.

### BS-19 CLI leftovers in `bin/bridge.dart`
- Category: leftover / simplification
- Evidence:
  - The retired `--import-plugin` option is still parsed (`bin/bridge.dart:103-105, 140`).
  - `ConfigYoloCommand` and `ConfigWarmupCommand` are near-identical.
  - `BridgeSettingsRepository` is constructed 5 times.
  - The `auth-backend` and `debug-port` options default to `''` (L110, L118), so an empty string stands in for "missing".
- Proposal:
  - Remove `--import-plugin`.
  - Share one boolean-setting command.
  - Construct the settings repository once per command.
  - Make the two option defaults null.
- Size: about 40-55 lines. 1 file plus CLI tests.
- Risk: low to medium. A user script that still passes `--import-plugin` would now fail argument parsing.
- Confidence: verified (subagent).
- Decision needed: drop `--import-plugin` outright, or reject it with a one-line "no longer supported" message? CLI flags are not the client-bridge wire, so no compatibility is owed.

### BS-20 `PlatformChecker` is a 1:1 interface
- Category: simplification
- Evidence: `foundation/device_type_detector.dart:10-25` defines an interface with one implementation. Tests fake it; a constructor function parameter or the existing `Platform` seam would do the same.
- Proposal: replace it with a `bool Function()` / an enum value injected at composition, or with the concrete class.
- Size: about 20 lines. 2 files plus tests.
- Risk: low.
- Confidence: verified (4 lib refs, 11 test refs).
- Decision needed: none.

### BS-21 Small push leftovers
- Category: leftover
- Evidence:
  - The `ContinuationTimerFactory` seam is unused: 2 lib refs, no test refs.
  - `PushRateLimiter.shouldSend` takes a `sessionId` it never reads.
  - A `catchError` drops the stack.
  - `orchestrator.dart:1196` feeds `projectUpdated` events to the completion listener, which ignores them. That part is the orchestrator auditor's area.
- Proposal: delete the seam and the unused parameter, keep the stack, and stop feeding the ignored event (cross-boundary).
- Size: about 15-20 lines. 3-4 files.
- Risk: low.
- Confidence: verified (seam rg).
- Decision needed: none.

### BS-22 Runtime package residue
- Category: leftover / rule-violation
- Evidence:
  - Stale comments at `runtime_restart_policy.dart:4-10, 55`.
  - A redundant stdout drain in `managed_runtime_monitor.dart:118, 126, 133` that swallows errors.
  - `_pinnedPort` duplicates the selected port.
  - `ProcessIdentity.platform` is a `String` compared with magic `"windows"` / `"win32"` (`managed_process_service.dart:658-661`).
- Proposal: fix the comments, drop the duplicate drain, inline `_pinnedPort`, and turn the platform into an enum parsed at the boundary.
- Size: about 20-30 lines. 3-4 files in `sesori_plugin_runtime`.
- Risk: low.
- Confidence: verified (subagent).
- Decision needed: none.

### BS-23 Unused `lints` dev dependency in all 16 bridge pubspecs
- Category: leftover
- Evidence:
  - `lints:` appears in 16 bridge `pubspec.yaml` files.
  - No `analysis_options.yaml` includes `package:lints/...`. They chain to `app/analysis_options.yaml`, which includes the local `all_lint_rules.yaml`.
- Proposal: remove the dev dependency and regenerate the lockfiles.
- Size: 16 lines plus lockfile churn.
- Risk: low.
- Confidence: verified.
- Decision needed: none.

### BS-24 Close the listener-pair deferral by merging the warm-up pair
- Category: simplification (re-check of the deferred item)
- Evidence:
  - The 2026-09 deferral covered listener pairs. The glossary pair has since been deleted (409b60cf95, 69cca88bac), so the unified-view-tracker part is moot.
  - The remaining pair, `listeners/plugin_warmup_setting_listener.dart` and `listeners/viewed_session_plugin_warmup_listener.dart`, both drive `PluginWarmupService`.
- Proposal: merge them into one warm-up listener, or explicitly close the deferral as "kept".
- Size: about 85 lines if merged. 2 to 1 files plus orchestrator wiring.
- Risk: low to medium. Warm-up timing is user-visible: the first prompt can be slower if this regresses.
- Confidence: verified (subagent).
- Decision needed: merge the warm-up pair, or record the deferral as closed and kept?

### BS-25 Relay `1000 + "replaced"` rollout fallback (cross-boundary)
- Category: leftover
- Evidence:
  - `foundation/relay_client.dart:45-52, 68-74, 187` carry `closeReason` only for this fallback, according to their own doc comments.
  - `shared/sesori_shared/lib/src/protocol/close_codes.dart:63-65` matches `1000 && reason == "replaced"`.
  - `control/control_status_notifier.dart:173-174` consumes it.
  - The relay server has emitted the dedicated code 4007 since d2face7 (2026-07-07); `handler.go:266` sends 4007 with reason "replaced".
- Proposal: once the relay deployment is confirmed, drop `closeReason` from `RelayDisconnected` and `RelayClient`, delete the fallback branch in `close_codes.dart`, and keep the reason only in the orchestrator log line if useful.
- Size: about 15-20 lines across foundation, control and shared.
- Risk: low. The relay is server-side and not a client-bridge wire. A pre-July relay is not in production.
- Confidence: likely. Needs a check that the production relay runs a build after d2face7.
- Decision needed: none, if the deployment check passes.

## Cross-boundary notes (other auditors' areas, not audited)
- `bin/bridge.dart:345-425` holds the logout composition. A ponytail at `bin.dart:406` (4fe916ca40, 2026-10-30) notes that `BridgeRegistrationService.unregister` needs no register inputs. The fix sits in `auth/`.
- `bridge/AGENTS.md:107` and `bridge/app/AGENTS.md:124` still describe "client disposal" wording that no longer matches the push and listener code. Fix this in whichever cleanup PR touches push.
- The `bridge/AGENTS.md` Module Order omits antigravity, copilot and deepseek.
- The `path-runtime-authority-split` tracker is stale against the code: steps 7-9 show as not started, but parts have landed.
- About 20 `CommandExecutor` fakes are copied across about 8 bridge packages. One shared fake in a test-support library would cut the churn on every executor API change.
- heavy-users follow-up: `idx_sessions_archive` is unused and needs migration v22 (the DB auditor's area).

## Checked and kept
- `services/pull_request_refresh_settings_service.dart:6` COMPATIBILITY marker: its retiring condition ("public apps older than v1.9.2 unsupported") is not met.
- `services/session_lifecycle_service.dart:146` COMPATIBILITY marker (refuse unarchive, v1.7.0): still owed to public apps.
- E4 `SessionOperationDispatcher` lock composition: unchanged since 2026-08-22, so the deferral reason holds. The `_track` swallow is intentional.
- Uncontrollable-lifecycle startup check: live, because the OpenCode `noAutoStart` attach mode drops `lifecycle` (`open_code_plugin_descriptor.dart:314-317`).
- `_PluginRuntimeSlot` with 26 mutable fields: every field is both read and written. The 3 per-generation subscriptions are cancelled together in `_cancelGenerationSubscriptions`; a CompositeSubscription rebuilt per generation buys little.
- Splitting `BridgeRuntimeRunner.run` (about 880 lines) or `plugin_runtime.dart` (2.3k): size alone is not a concrete benefit, consistent with the previous audit.
- `chat_history_service.backfillSession`: used internally (line 992). The `_inFlightBackfills` dedupe has a named reconnect flow.
- The `chat_history_service.dart:605` "legacy shape": the inline-image aggregate for released apps, a real wire contract.
- `SessionAbortService` with three `Stream<String>` streams: each consumer needs one, and merging them into a sealed stream is marginal.
- `listeners/chat_history_listener.dart:42`, `onError: (Object _) {}`: the orchestrator logs the same stream's errors.
- `session_options_service.dart:797, 831`: catch-and-continue sites with a retry or remove flow.
- `session_unseen_service.dart:363`, a positional `operation` in the private `_serialize`: a marginal rule nit, so fix it only when the file is touched.
- `PluginIdleTimerScheduler`: a real test seam for idle timeouts.
- `ControlUnregisterService._terminate` and the `SessionDeletionService` closures: scoped operations, not event-notification callbacks.
- All 12 listeners: every trigger is live.
- The updater's `ManagedRuntimeManifestApi`: a live npm manifest contract.
- The `PlatformUpdateApi` posix and Windows split: platform behaviour really differs.
- The forwarding updater repositories: required by the layer rule.
- The CLI updater: the desktop app skips it through `isSupervised`.
- Every `foundation/` file has a production caller.
- `ProcessRunner` vs `CommandExecutor`: different responsibilities.
- `bridge/app` `json_annotation` (required by json_serializable), `build_runner` (a tool) and `code_assets`/`hooks` (used by `hook/build.dart`): deps.tsv false positives.
- unref.tsv false positives: `extensive` (a glossary word list entry) and `ArchiveFormatX` (used at `runtime_install_service.dart:138`).
- Previous-audit "unified view tracker" deferral: moot now that the glossary pair is gone (see BS-24).
- `project_glossary_term_calculator.dart:403` ponytail (suffix folding): a deliberate documented heuristic. The `match.group(n)!` calls there are regex-guaranteed.
