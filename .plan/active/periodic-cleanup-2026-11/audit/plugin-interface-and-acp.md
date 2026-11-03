# Plugin interface and ACP-family plugins cleanup audit

## Summary

The plugin interface and the ACP-family plugins are in good shape. The ACP base works as the shared owner it was meant to be: plugin-specific behaviour (approval registries, scoped stop, catalogs) sits behind small hooks, and no plugin re-implements turn handling. Most of the debt is code left behind as plugins took over their own responsibilities:

- The shared neutral option catalog is no longer used.
- Three ACP turn-policy switches have no production override.
- Three interface members have had no app caller since projects became bridge-owned.
- The runtime-update metadata has stayed inert for seven weeks.

All removals were verified by deleting the code in a scratch copy of the workspace and running `dart analyze` on the whole bridge workspace. No production library broke anywhere, including `bridge/app`. Only tests and fakes broke.

Top 3 opportunities:

1. Delete `AcpSessionOptionsService` (PI-1).
2. Remove the dead ACP policy switches and the process lane (PI-2).
3. Drop `healthCheck`, `renameProject` and `markFailed` from the interface (PI-3).

Estimated removable code: about 600 lines across production, tests and docs, plus about 230 more if PI-4 is decided as "drop".

## Findings

### PI-1 Delete `AcpSessionOptionsService`: its neutral catalog is dead in production
- Category: leftover
- Evidence:
  - `bridge/sesori_plugin_acp/lib/src/acp_session_options_service.dart` (67 lines) builds a one-agent, one-provider catalog from process defaults. Only the base `getSessionOptions`, `getAgents` and `getProviders` use it (`acp_plugin.dart:1013-1019` and `:2430-2438`).
  - All 7 production subclasses override all three methods and never call super: antigravity, copilot, cursor, deepseek, grok, hermes and omp (`*_plugin_impl.dart`).
  - Analyzer check: after making the three base methods abstract, the only error was in `sesori_plugin_acp/lib/src/testing/test_acp_plugin.dart:5`, which is a test utility.
  - The service's other job, `forgetSession` (`acp_plugin.dart:2193,2203`), just forwards to `AcpSessionConfigurationTracker.forgetSession`. `AcpEventMapper` already holds that tracker (`acp_event_mapper.dart:72`), and its `forgetSession` is called at the same two sites.
  - It is still built in 7 production places: `cursor_plugin_impl.dart:77`, `copilot_plugin_impl.dart:64`, `omp_plugin_impl.dart:96`, `deepseek_plugin_descriptor.dart:322`, `antigravity_plugin_composer.dart:52`, `grok_plugin_impl.dart:77` and `hermes_plugin_descriptor.dart:403`.
  - It is also built in `compose_test_acp_plugin.dart:32` and about 10 test sites.
- Proposal:
  - Make the three methods abstract on `AcpPlugin`.
  - Forget the configuration tracker inside `AcpEventMapper.forgetSession`.
  - Delete the service, its export and `acp_session_options_service_test.dart` (98 lines).
  - Drop the constructor parameter and the 7 production constructions.
  - Give `TestAcpPlugin` a minimal implementation of the three methods, and have the ad-hoc ACP test plugins extend it.
- Size: about 230 lines removed (67 service, 98 test, about 45 composer lines, about 20 base lines, minus about 25 added to the test plugin). About 20 files touched. OMP belongs to the other auditor but changes only mechanically.
- Risk: low. Every live plugin already overrides these methods, so production behaviour is unchanged. No wire, DB or user-visible impact.
- Confidence: verified.
- Decision needed: none.

### PI-2 Remove dead ACP turn-policy switches and the process-wide prompt lane
- Category: leftover
- Evidence:
  - `serializesPromptsProcessWide =&gt; false` (`acp_plugin.dart:252`): OMP was the last override, and #1075 dropped it on 2026-08-24. The `true` path is dead:
    - `_processTurnTail` at `:171`
    - `_runOnProcessLane` at `:1139-1147`
    - the call at `:1087`
    - the ternary at `:1450`
  - `cancelsActiveTurnForQueuedInput =&gt; true` (`:263`): no override anywhere, not even in tests. Its own doc says `false` "is not valid production behavior". The `false` arm at `:1267` is dead.
  - `failsTurnOnSelectionError =&gt; true` (`:268`): no production override. Cursor only mentions it in a comment (`cursor_plugin_impl.dart:22-26`). The dead fail-open arms are at `:1099` and `:1560-1564`.
  - Analyzer check: no production library references these switches. Only 9 test assertions broke: the hermes, omp, copilot, grok and deepseek plugin tests, plus `acp_step5_policy_test.dart:31,34`.
  - The header doc at `:55-56` lists all three.
- Proposal:
  - Delete the three switches and the process lane.
  - Inline the fail-closed and cancel-on-queue behaviour.
  - Drop the `processWide`/`failClosed` test parameters and the process-lane test (`acp_step5_policy_test.dart:227`).
  - Rewrite the test at `:318`, or drop it.
  - Remove the per-plugin default-value assertions.
- Size: about 45 production lines and about 60 test lines removed. Files: `acp_plugin.dart`, `acp_step5_policy_test.dart`, 5 plugin tests and the Cursor comment.
- Risk: low. Only unreachable branches go. No wire, DB or user-visible impact.
- Confidence: verified.
- Decision needed: none.

### PI-3 Remove plugin-interface members the bridge never calls: `healthCheck`, `renameProject`, `markFailed`
- Category: leftover
- Evidence (all three were deleted in the scratch copy; nothing under `bridge/*/lib` broke):
  - `BridgePluginApi.healthCheck` (`sesori_plugin_interface/lib/src/bridge_plugin.dart:275`):
    - The app never calls it. The only non-test caller is `app/tool/cursor_smoke.dart:39`, which uses the concrete `CursorPlugin`.
    - Implementations: `acp_plugin.dart:774`, `claude_plugin_impl.dart:555`, `codex_plugin_impl.dart:921`, `opencode_plugin_impl.dart:331`, `v2/opencode_v2_plugin.dart:189` and `pi_plugin_impl.dart:491`.
    - Behind the OpenCode and Pi implementations are forwarding chains nothing else calls: `opencode_v2_service.dart:78` → `opencode_v2_repository.dart:40` → `opencode_v2_api.dart:56`; `opencode_api.dart:143`; and `pi_catalog_service.dart:34` → `pi_backend_catalog_repository.dart:56`.
    - Docs mention it at `lifecycle/bridge_plugin.dart:25` and `steady_plugin_lifecycle.dart:42`.
  - `NativeProjectsPluginApi.renameProject` (`bridge_plugin.dart:297`):
    - Renaming became bridge-owned in #550 (2026-07-24). The app now writes `_projectsDao.setDisplayName` (`project_repository.dart:176`).
    - Only OpenCode implements it: `opencode_plugin_impl.dart:867`, `opencode_repository.dart:277`, and the v2 plugin/service/repository at `:198`, `:153` and `:236`.
  - `SteadyPluginLifecycle.markFailed` (`steady_plugin_lifecycle.dart:158`): no production caller; one interface test uses it.
  - Test fallout:
    - App fakes: `fake_bridge_plugin.dart:100-132,220`, plus fakes in `debug_server_test`, `orchestrator_error_recovery_test` and `project_repository_test`.
    - `codex_plugin_write_path_test.dart` uses `healthCheck()` about 15 times to trigger a connection.
    - OpenCode `renameProject` tests in 3 files.
- Proposal:
  - Delete the three members, every implementation and the dead OpenCode/Pi forwarding chains.
  - Point the Cursor smoke tool and the Codex tests at `ensureConnected` or another call that connects.
  - Fix the two doc references.
  - The OpenCode, Pi, Claude and Codex edits are in the other auditor's area but must land together with this change.
- Size: about 150 lines removed (about 60 production, about 90 tests and fakes). About 20 files.
- Risk: low. Not on the wire: the app's `health_check_handler` does not use the plugin probe. No DB or user-visible impact.
- Confidence: verified.
- Decision needed: none.

### PI-4 Inert runtime-update metadata and a stalled plan
- Category: leftover
- Evidence:
  - `PluginRuntimeUpdateSpec` and `runtimeUpdateSpec` (`bridge_plugin_descriptor.dart:21-28,107-112`) are documented as "inert until the bridge adds an explicit runtime-update command".
  - The app maps `PluginControlCapability.runtimeUpdate =&gt; null` (`plugin_lifecycle_service.dart:1308`), so it never exposes the capability.
  - Even so, 8 descriptors compute both: `claude:121`, `codex:254`, `cursor:140,144`, `grok:68-79`, `hermes:79-90`, `omp:118`, `opencode:321` and `pi:127`.
  - 14 test files assert them.
  - The owning plan, `.plan/active/path-runtime-authority-split/`, merged step 6 (#1474) on 2026-09-13, but its tracker still says "Step 6 In progress". Step 7 ("Execute sanitized global runtime updates") has not started.
- Proposal: either resume step 7, or delete the spec, the enum value, the app mapping, the 8 overrides and their tests, and close the plan. Fix the stale tracker in either case.
- Size: if dropped, about 230 lines (about 100 production across 10 files, about 130 test lines across 14 files). If resumed, only the tracker fix.
- Risk: low either way. The metadata is internal and never crosses the wire.
- Confidence: verified.
- Decision needed: should the PATH runtime-update command (plan step 7) still ship? If not, remove the metadata.

### PI-5 Throwing convenience accessors on `PluginMessagePart` are forced casts used only by tests
- Category: rule-violation
- Evidence:
  - `plugin_message.dart:164-222` adds `text`, `tool`, `state`, `attachment`, `agentName`, `attempt`, `retryError` and `asText`/`asReasoning`/`asTool`/`asFile`/`asAgent`/`asRetry` to the union. Each throws a `StateError` on the wrong variant, which is the forced-cast pattern AGENTS.md bans. They came from #1107 (2026-08-25).
  - Analyzer check (block deleted in the scratch copy): no production library uses them. About 400 test uses break:
    - `state` 223
    - `text` 99
    - `tool` 40
    - `attachment` 31
    - `agentName` 5
    - `asTool` 5
    - `attempt` and `retryError` 1 each
  - Those tests are spread across acp, antigravity, claude, codex, opencode and pi.
- Proposal: move the block into a test-only extension exported from `plugin_interface_testing.dart`. Delete `asText`, `asReasoning`, `asFile`, `asAgent` and `asRetry` outright, because no test uses them.
- Size: about 60 production lines leave the union (about 35 move, about 25 are deleted), plus about 25 one-line test imports.
- Risk: low. The JSON shape is unchanged because these members are excluded from JSON.
- Confidence: verified.
- Decision needed: none.

### PI-6 Stale ACP entries in `docs/HARNESS_CAPABILITIES.md`
- Category: leftover (docs)
- Evidence (checked against code by a sub-agent, spot-checked here):
  1. L923-931, MCP table "minimum → target" column: every ACP target is out of date. Doc vs code:
     - Antigravity 1.3.0 vs 1.4.3 (`antigravity_release.dart:15`)
     - Copilot 1.0.92 vs 1.0.103 (`copilot_runtime_manifest.dart:13`)
     - Cursor 2026.10.01 vs 2026.10.22-27dcf5f
     - DeepSeek 0.2.0 vs 0.2.1
     - Grok 1.0.46 vs 1.0.70
     - Hermes 0.21.5 vs 0.22.5
  2. L592-595 says the ⬜ plugins never reach `authenticationRequired`. That is false for Copilot:
     - The shared ACP `authenticate` throws `PluginAuthenticationRequiredException` (`acp_agent_api.dart:110,127`).
     - Copilot re-wraps it with its login hint (`copilot_session_options_service.dart:98-106`).
     - The runtime then moves the slot to `PluginSetupAuthenticationRequired` (`plugin_runtime.dart:481-483,2057-2066`).
  3. L146 says Cursor quota needs a "Headless payload" check. Cursor runs over ACP, so it should say "ACP payload".
  4. These footnotes cite runtimes outside the supported range. The claims still hold in code, so they need a "not re-probed on the current pin" note:
     - L1131 (fn 6) and L1273 (fn 17) cite Hermes 0.19.0, below the 0.20.0 minimum.
     - L1211-1212 (fn 19) cites an Antigravity 1.0.0 probe, but the pin is exactly 1.4.3.
  5. L344-347 and L1157-1167 (fn 9) are history about runtimes below the supported minimum. Trim each to one line.
  6. Probable: L310 says Grok child sessions have no start time. Saved Grok children do carry `time.created` (`grok_session_catalog_repository.dart:51-63`). Not confirmed end to end.
  7. Judgement call: fn 4 (L1098-1103) keeps Copilot sub-agents at 🚫 while citing sub-agent IDs since 1.0.81. The pin is 1.0.103.
- Proposal: one doc edit:
  - Drop or relabel the version column.
  - Fix L592-595 and L146.
  - Add the "not re-probed" notes.
  - Trim the two history passages.

  Fold it into the next substantive PR rather than a standalone one.
- Size: about 12 doc lines deleted and about 18 rewritten. 1 file.
- Risk: none (docs only).
- Confidence: verified for items 1-5, likely for item 6.
- Decision needed: for item 7, should Copilot's sub-agent cells become ⬜ (unverified) or stay 🚫 until someone re-probes? Low stakes.

### PI-7 Retire the v1.9.0 "only the default mode" COMPATIBILITY markers
- Category: leftover (compatibility condition met)
- Evidence:
  - Markers at `copilot_session_options_service.dart:216-222` and `cursor_catalog_tracker.dart:87-95`. Both came from 051170c290 and first shipped publicly in v1.9.0 on 2026-09-24.
  - Their own retiring condition is that catalogs captured before 2026-09-21 are served for up to 30 days. That window ended on 2026-10-21.
  - Damage if an old catalog still names a non-default mode: Cursor falls back to `?? defaultModeId` (`cursor_plugin_impl.dart:249`), and Copilot leaves the mode unset. Either way the turn runs in the default mode.
- Proposal: accept only the default mode in both places, delete the markers, and update the affected tests.
- Size: about 15 production lines plus the matching tests. 2 production files.
- Risk: low. The wire shape is unchanged.
- Confidence: likely. I did not count exactly which tests depend on naming a non-default mode.
- Decision needed: none.

### PI-8 Empty-string sentinels and null assertions in the ACP family
- Category: rule-violation
- Evidence:
  - Empty string for a missing session id:
    - `acp_approval_registry.dart:179-185` (`resolveSessionId` returns `""`). Callers test `.isEmpty` at `:230`, `:250`, `cursor_approval_registry.dart:59` and `:157`.
    - `acp_protocol.dart:68` (`AcpAuthMethod.id`) and `:221` (`AcpNewSessionResult.sessionId`) fall back to `""` when the id is missing. The empty value is checked later at `acp_agent_api.dart:148` and `acp_plugin.dart:831,859`.
  - Other empty-string sentinels: `cursor_plugin_impl.dart:266` passes `""` as the model id to `thoughtLevelForModel`, and `cursor_approval_registry.dart:92` falls back to an empty option id.
  - Null assertions: `cursor_catalog_service.dart:103` (`_inFlight!`) and `hermes_catalog_repository.dart:73,76,78` (`discoveryStack!`, `cleanupStack!`, `catalog!`).
- Proposal:
  - Make `resolveSessionId` return `String?`.
  - Have `fromJson` throw `FormatException` when an id is missing.
  - Let `thoughtLevelForModel` accept a null id.
  - Replace the assertions:
    - `while (_inFlight case final pending?)` in the Cursor catalog service.
    - One `(Object, StackTrace)?` record per failure in the Hermes catalog repository.
- Size: about 25 lines changed, about 8 removed. 7 files.
- Risk: low. A silently empty id becomes an explicit decode failure, on paths that already reject empty ids.
- Confidence: verified.
- Decision needed: none.

### PI-9 Small DeepSeek and Antigravity leftovers
- Category: leftover / test-debt
- Evidence:
  - `deepseek_plugin_impl.dart:140-145` builds the prompt `_meta` as a raw map. The typed `DeepSeekPromptMetadataDto` and `parsePromptMetadata` (`deepseek_acp_api.dart:31-37`) are used only by the conformance test (`:342`). So that test checks a DTO production never sends.
  - `antigravity_catalog_tracker.dart:9`: `newSessionDefaultModelId` has no references.
- Proposal: build the DeepSeek meta from the DTO's `toJson()`, and delete the Antigravity getter.
- Size: about 3 lines. 2 files.
- Risk: low. The wire payload stays the same, but the DTO's JSON key has not been checked yet.
- Confidence: references verified; DTO key unverified.
- Decision needed: none.

## Checked and kept

- **ACP scoped-stop strategies** (`acp_plugin.dart:1792-2095`): each serves one plugin, but they run on private turn state. The enum seam is the right owner.
- **Single-plugin ACP hooks**: cheap override seams, each with a live production override.
- **The two settlement-timeout getters**: only tests override them, but they are legitimate timing seams that keep tests from waiting 5-20 s.
- **Cursor, DeepSeek and Antigravity approval registries**: they handle each plugin's own extension methods on the shared base. Placed correctly, not duplicated.
- **Grok and Hermes PATH version probes**: their arguments, parsers and states differ. The shared validator is tied to `RuntimeManifest`, so sharing would save only about 40 lines.
- **Descriptor boilerplate** (`_setupProbeOutputLimit`, `_explicitBin`, `_isUnknownRejection`): a few lines each, with plugin-specific names.
- **Agent and provider projections in the per-plugin option services**: each harness differs, so there is no clean share.
- **String-literal plugin ids instead of `Harness.X.name`**: three of these plugins don't depend on `sesori_shared`, and adding it for one string isn't worth it.
- **deps.tsv**: `json_annotation` is needed by the generated code. `lints` and `build_runner` are tool dependencies.
- **unref.tsv `GrokSubagentStatusMapping`**: a false positive. It is used via `toPluginToolStatus()` (`grok_event_mapper.dart:77,83`, `grok_session_replay_collector.dart:51`).
- **unref.tsv DeepSeek `parse*Request`/`Response` wrappers**: thin conformance-test entry points over validators that production also uses. Kept.
- **Test utilities** (`fake_stdout`, `fake_acp_process`, `compose_test_acp_plugin`, `test_acp_plugin`): exported for tests. False positives.
- **`canTransitionTo` and `pendingQuestionPayload`/`settlePendingQuestion`**: both are used in production.
- **OpenCode-only `BridgeSseEvent` variants**: still produced. They belong to the other auditor.
- **D2 session `Map` payloads, the ACP size-only split and E5 managed install**: previous decisions still hold. Not re-proposed.
- **Overlap with the other auditor**: OMP builds the PI-1 service and asserts the PI-2 switches. OpenCode, Pi, Claude and Codex carry the PI-3 and PI-4 implementations.
