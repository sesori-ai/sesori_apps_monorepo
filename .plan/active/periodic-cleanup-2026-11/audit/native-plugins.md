# Native-protocol plugins (Claude, Codex, OpenCode, Pi, OMP) cleanup audit

Scope: `bridge/sesori_plugin_claude`, `sesori_plugin_codex`, `sesori_plugin_opencode`, `sesori_plugin_pi`, `sesori_plugin_omp` and their tests. Snapshot: `.claude/worktrees/cleanup-audit` (read-only). Every finding was re-checked with rg. Codex, Claude and Pi/OMP were audited in parallel and spot-verified before inclusion.

## Summary

Overall health is good. Heavy-users enumeration left no second scan path, and E5 (shared managed-install composition) landed in every descriptor. opencode-shared-service left nothing obsolete, and no code branch serves a harness older than its PATH minimum. Most of the debt is parse surface nothing reads, production APIs only tests use, and one generator that emits about 6k lines of unused v1 models.

Runtime floors (PATH minimum / managed target):

| Harness | PATH minimum | Managed target | Note |
|---|---|---|---|
| OpenCode | 1.14.0 | 2.1.4 | v2 adapter from 2.0.11 |
| Codex | 0.139.0 | 0.164.0 | |
| Pi | 0.99.0 | 1.4.0 | |
| OMP | 17.2.13 | 18.12.6 | |
| Claude | 2.1.221 | 2.1.310 | no managed install |

The OpenCode v1 adapter can still run and is kept on purpose (PN-22). Upstream `opencode-ai` and GitHub latest are still v1 (1.19.5, 2026-10-28), so most PATH users run the path that live checks don't cover.

Top 3:
1. **PN-1:** v2 never emits `BridgeSseSessionIdle`. This is a parity bug found by the audit, not cleanup, and the fix is about 6 lines.
2. **PN-2:** about 5.9k unused generated v1 OpenAPI lines.
3. **PN-3:** Pi's duplicate history DTO tree, about 320 written and 2.1k generated lines.

Estimated removable: about 1.7–1.9k written lines and about 8.3k generated lines, plus about 0.4k test lines. PN-5, PN-14 and PN-15 change the plugin interface, so they must land in the same PR as the interface auditor's changes.

## Findings

### PN-1 OpenCode v2 never emits `BridgeSseSessionIdle`, so v2 turns skip completion recency and tool finalization
- **Category:** leftover. It is a parity gap left by the v2 adapter, and a bug, raised under the findings rule.
- **Evidence:**
  - `lib/src/v2/sse/v2_event_mapper.dart:20-44` maps `V2SessionExecutionSucceeded`, `Failed` and `Interrupted` only to `BridgeSseSessionStatus(idle)`.
  - A production rg for `BridgeSseSessionIdle(` finds a producer in every other adapter:
    - Claude `claude_session_service.dart:670`
    - Codex `codex_event_mapper.dart:228` and `codex_plugin_impl.dart:384`
    - Pi `pi_session_service.dart:893,945,1053,1204`
    - ACP `acp_plugin.dart:1731`
    - OpenCode v1 `sse_event_mapper.dart:123`
  - There is none under `lib/src/v2`. `.plan/active/opencode-v2/PLAN.md:36` confirms v2 never sends `session.idle`.
  - Two app paths run only on Idle:
    - `bridge/app/lib/src/services/session_event_service.dart:130-146` calls `recordSessionCompletion`, which advances `updatedAt` (#1345).
    - `orchestrator.dart:1696-1702` calls `_finalizeOpenToolParts`.
  - Live idle status is still covered through `stampLiveStatus`.
  - On the v1 side, the marker at `sse_event_mapper.dart:122` (and `tool/generate_sse_events.dart:266`) says "Older OpenCode runtimes emit session.idle. Remove … when those runtimes are unsupported." That is wrong: current v1 still emits it ("Emitted for backward compatibility" upstream), and app completion depends on it.
- **Proposal:**
  - In `V2EventMapper.map`, also emit `BridgeSseSessionIdle` for the three execution-end events that `status()` maps to idle, using the same interrupt-reason filter. Add one test.
  - Replace the v1 marker with a plain comment saying this branch drives turn completion.
- **Size:** about +6 lib lines, +20 test lines and 2 comment lines.
- **Risk:** low-medium. v2 sessions will start to reorder on completion and finalize stranded tools, which other harnesses already do. No wire or DB change.
- **Confidence:** likely. The static trace is complete but not reproduced live. Even if a v2 `session.updated` already bumps `updatedAt`, tool finalization is still missing.
- **Decision needed:** none.

### PN-2 Stop generating 60 unused OpenCode v1 OpenAPI models (about 5.9k generated lines)
- **Category:** leftover
- **Evidence:**
  - An import graph from `lib/` leaves 60 of the 120 files in `lib/src/models/openapi/` unreachable, about 5,935 lines in total.
  - 42 of them are `event*.g.dart` files (about 4,425 lines), created by `roots.addAll(_eventSchemasFromManifest())` at `tool/generate_opencode_client.dart:529`.
  - Production decodes SSE through the manifest codegen (`sse_event_data.g.dart`) instead. That is the only generator CI checks (`bridge-ci.yml:155-157`).
  - The only consumer of the event models is `test/openapi_models_round_trip_test.dart:8-9,135-140`.
  - The other about 18 files (about 1.5k lines) are request-body types pulled in by the `requestBodySchema` roots at line 524. Examples: `agent_part_input`, `text_part_input`, `worktree_*_input`, `pty`, `todo`, `session_command_response`, `question_answer` and the error types.
  - The v1 API sends hand-written bodies, and the v2 surface comment says its bodies are "hand-written like v1's".
  - The v2 surface sets no `eventManifest`, so changing line 529 affects only v1.
- **Proposal:**
  - Keep the manifest cross-check warnings (lines 546-569) but stop using event schemas as generation roots.
  - Drop the request-body roots after checking that v2 still regenerates every type it imports.
  - Regenerate, and delete the `EventQuestionRejected` round-trip case.
  - Remove `"session.fork"` from `tool/opencode_v1_surface.json`.
- **Size:** about −4.4k generated lines, up to about −5.9k; about −15 test lines; about 5 tool lines.
- **Risk:** low. Production imports none of these files, and no CI drift check covers this generator.
- **Confidence:** verified.
- **Decision needed:** none.

### PN-3 Pi keeps two parallel history DTO trees (on-disk files and RPC `get_entries`)
- **Category:** simplification
- **Evidence:**
  - `pi_session_history_dto.dart` defines the RPC tree: `PiSessionEntriesDto` (:10), `PiSessionEntryDto` (:47) and `PiAgentMessageDto` (:294).
  - The same file defines a near-copy file tree: `PiSessionFileHistoryDto` (:20), `PiSessionFileHeaderDto` (:30), `PiSessionFileEntryDto` (:133) and `PiSessionFileAgentMessageDto` (:219).
  - `pi_session_process_repository.dart` (`_normalizeFileHistory` at :978, then `_normalizeFileEntry`/`_normalizeFileMessage` through :1119) copies one tree into the other field by field. The only real differences are the v1 synthetic ids and parentIds, and `hookMessage`→`custom`.
  - The `.freezed.dart` file is 4,010 lines, about half of it for the file tree.
  - The file path only runs on `PiHistoryRpcStartupUnavailableException`.
- **Proposal:** in `_readPiSessionHistory` (`pi_session_storage_api.dart:431-512`), add the v1 ids and rename `hookMessage` at the JSON-map level, then decode straight into `PiSessionEntryDto`. Delete the file tree and the three `_normalizeFile*` methods.
- **Size:** about −320 written and about −2,100 generated lines.
- **Risk:** low-medium. It touches only the fallback for sessions that cannot start RPC, and existing tests cover v1 and hookMessage. On-disk v1 support stays.
- **Confidence:** likely. Confirm the field equivalence while editing.
- **Decision needed:** none.

### PN-4 Codex: delete the dead collab tool-call parse path
- **Category:** leftover
- **Evidence:**
  - `codex_sub_agent_item_dto.dart` holds `CodexCollabAgentToolCallItemDto`, three enums, `CodexCollabAgentStateDto` and `_threadIdListFromJson`.
  - `CodexCollabItem` is at `codex_sub_agent_item_event_dto.dart:18`, and the parser branch at `codex_sub_agent_item_parser.dart:29-46,72-79`.
  - rg finds `CodexCollabItem` only in those files. The only production consumer (`codex_plugin_impl.dart:439-475`) matches only `CodexSubAgentActivity`.
  - Added in #1263 and never consumed.
- **Proposal:** delete all of these and regenerate. Collab items then fall to `unknown`.
- **Size:** about −80 written, −150 generated and −100 test lines.
- **Risk:** low.
- **Confidence:** verified.
- **Decision needed:** none.

### PN-5 Remove the dead `healthCheck()` from every native plugin (with the interface audit)
- **Category:** leftover
- **Evidence:**
  - `bridge_plugin.dart:275` has no caller in `bridge/app/lib`. The only call is in the dev tool `app/tool/cursor_smoke.dart:39`.
  - Implementations:
    - Claude `:555`
    - Codex `:921-928`
    - OpenCode v1 `opencode_api.dart:143-153`, which swallows every error with `catch (_) { return false; }` and no log
    - OpenCode v2 through four forwarding layers, from `opencode_v2_plugin.dart:189` to `opencode_v2_api.dart:56`
    - Pi from `pi_plugin_impl.dart:491` to `pi_backend_catalog_repository.dart:56`, which spawns a process for nothing
  - The interface README (lines 41 and 87) documents it as an instantaneous probe.
- **Proposal:** remove it from the interface and every layer in one lockstep PR. Update the README and `cursor_smoke.dart`.
- **Size:** about −60 lib and −40 test lines, about 12 files.
- **Risk:** low.
- **Confidence:** verified.
- **Decision needed:** none beyond coordinating with the interface audit.

### PN-6 Unify Claude's and Codex's MCP elicitation form schema
- **Category:** simplification
- **Evidence:**
  - `claude_form_schema.dart` (272 lines) and `codex/.../codex_form_schema.dart` (310 lines) share 240 normalized lines (difflib ratio 0.90).
  - The Codex copy (step 27) adds checks Claude's copy (step 21) lacks: label uniqueness, `enumNames`, `_integerBound`, anyOf array items, unfulfillable minimum and ambiguous option labels.
  - Both copies contain the same null assertions.
  - The schema is the MCP-standard elicitation schema, not a backend concept. ACP's `acp_elicitation_mapper.dart` (293 lines) is handed to the ACP auditor.
- **Proposal:** move the stricter Codex version into a shared package (`sesori_plugin_runtime`, which Claude would add as a dependency) and delete both copies. Fix the null assertions while moving it.
- **Size:** about −250 lines.
- **Risk:** low-medium. Claude would start rejecting malformed schemas that Codex already rejects.
- **Confidence:** verified.
- **Decision needed:** none.

### PN-7 Claude: stream-json variants and fields parsed but never surfaced
- **Category:** leftover
- **Evidence:**
  - `claude_event_dispatcher.dart:180-224` maps five variants to `[]`; there is a "ponytail: parsed but not surfaced" note at `:210`. The variants are thinking-tokens, task-progress, tool-progress, hook-started and hook-output (`claude_stream_message.dart:270-424`).
  - Fields with no reader:
    - `ClaudeInitMessage`: model, permissionMode, capabilities, tools, slashCommands, cliVersion, cwd and `supports()`
    - `ClaudeApiRetryMessage`: maxRetries, errorStatus and error
    - `ClaudeResultMessage.stopReason`
    - `ClaudeRateLimitMessage`: info and status
  - #945 kept them "for a future UI surface".
  - Correction to the sub-audit: the base `ClaudeStreamMessage.raw` is read (`claude_session_process_repository.dart:615`, `isReplay`). Keep it, or parse `isReplay` into a typed field.
- **Proposal:** collapse the five variants into one `ClaudeIgnoredMessage(type, subtype)` and delete the unused fields.
- **Size:** about −180 lines.
- **Risk:** low.
- **Confidence:** verified.
- **Decision needed:** confirm there is no near-term UI for thinking or task-progress output.

### PN-8 Parsed-but-unused data fields (Claude transcripts, Codex, Pi)
- **Category:** leftover
- **Evidence:**
  - **Claude:**
    - `claude_transcript_api.dart:202` makes a `Map.unmodifiable(json)` copy for every transcript line, stored as record `raw`. Nothing reads it.
    - `gitBranch` and `version` feed only `ClaudeSessionRecord.gitBranch` and `cliVersion`, which nothing reads.
    - `transcriptPath` is also unread.
  - **Codex** fields with no reader:
    - `CodexSessionRecord.cliVersion`
    - `revisedPrompt` and `audioUrl` (`codex_image_bearing_item_dto.dart:38,107`). `audioUrl` is required, so an item without it fails to parse.
    - The rollout DTO's `revisedPrompt` (which holds prompt text), `encryptedContent` and `taskName` (`:113,336,468`)
    - `codex_thread_dto.dart:41` `agentRole`
  - **Pi:** `PiCatalogModelDto.input` (`pi_catalog_dto.dart:21`).
- **Proposal:** drop these fields and regenerate.
- **Size:** about −110 written lines plus generated code.
- **Risk:** low. Removes one allocation per transcript line on history loads and scans.
- **Confidence:** verified.
- **Decision needed:** none.

### PN-9 Codex composition: one-implementation interface, seven unused descriptor parameters, and a test factory that copies production wiring
- **Category:** simplification
- **Evidence:**
  - `runtime/codex_managed_api.dart` is a "test seam" interface with a single implementation.
  - These descriptor parameters (`:143-152`) have zero test uses: `buildApi`, `candidatePorts`, `random`, `degradedDebounce`, `coldStartBudget`, `versionProbeTimeout` and `provisionService`. Related code: the typedef at `:45-52` and the branch at `:684-695`.
  - `test/support/codex_plugin_test_factory.dart` (about 90 lines, 21 call sites) nearly copies `_defaultBuildApi` (`:54-125`).
  - Test fakes are duplicated: `_StubChannel`, `_MemoryHostJsonStore`, `_Transport` and `_StubAppServerApi`, each twice.
  - `OpenCodeManagedApi` stays, because it has two real implementations.
- **Proposal:**
  - Type the generic on `CodexPlugin` and delete the interface, typedef, export, parameters and branch.
  - Add one composition function that both production and tests call.
  - Move the duplicated fakes to `test/support`.
- **Size:** about −150 lines.
- **Risk:** low.
- **Confidence:** verified.
- **Decision needed:** none.

### PN-10 Codex parses live command and file-change items twice
- **Category:** simplification
- **Evidence:**
  - The typed DTO is built at `codex_plugin_impl.dart:476-478`.
  - `codex_tool_lifecycle_tracker.dart:206-225` rebuilds the same tools from the raw map (`_applyAppServerTool`, `:699-730`). That branch only runs when the lenient typed parse fails, which effectively never happens.
  - `codex_event_mapper.dart:515-546` re-reads raw fields through `_toolStatus` (`:631-642`). That path is reachable.
  - Both paths come from #749.
- **Proposal:**
  - Delete the raw tracker branch.
  - Pass the typed DTO into the mapper fallback.
  - Delete the raw reads and `_toolStatus`.
- **Size:** about −60 to −90 lines.
- **Risk:** low-medium (live tool rendering); tests cover it.
- **Confidence:** likely.
- **Decision needed:** none.

### PN-11 Production APIs that only tests use
- **Category:** leftover
- **Evidence:**
  - **Claude:**
    - `ClaudeCatalogService.selectModel` and `selectAgent` (`:122-157`, dead since #809)
    - `ClaudeStreamClient.sendControlResponseError`, `isConnected`, and the `init` getter with its `_init` field
    - `ClaudeApprovalRegistry.handle` returns a bool its only caller ignores
  - **Pi:**
    - The public `resolveEffectiveSessionDirectory` (`:165-172`)
    - `residentSessionIds` (`:156`)
    - `PiRpcCommand.getTree`, which has zero references
  - **OpenCode:** `OpenCodeApi.forkSession` (`:328-339`) has no caller; only the fake overrides it.
- **Proposal:** delete them, rewrite the affected tests through public behaviour, and make `handle` return `void`.
- **Size:** about −95 lib and −90 test lines.
- **Risk:** very low.
- **Confidence:** verified.
- **Decision needed:** none.

### PN-12 Test fakes shipped as public production libraries, plus stale doc comments
- **Category:** test-debt
- **Evidence:**
  - `lib/claude_testing.dart` with `fake_claude_process.dart` (171 lines), and `lib/pi_testing.dart` with `fake_pi_process.dart` (180) and `pi_protocol_fixtures.dart` (19). Only each package's own tests import them.
  - `pi_protocol_fixtures_test.dart` tests only the fixtures.
  - Stale doc comments:
    - `lib/pi_plugin.dart` says Pi is "intentionally not registered"; it has been registered since v1.8.2.
    - `codex_plugin_impl.dart:42-58` says approvals "still throw" and land in "Phase 5".
    - `codex_app_server_client.dart:49-51` says requests are "not yet routed".
    - `codex_image_bearing_item_parser.dart:8` says "in this step".
    - The Codex descriptor and `lib/codex_plugin.dart` say the plugin is registered in "bin/bridge.dart"; it is registered in `app/lib/src/runtime/plugin_registry.dart:21`.
- **Proposal:** move the fakes into each package's `test/support/`, delete the two testing libraries and the fixture self-test, and fix the doc comments. A shared Claude/Pi fake (difflib ratio 0.70) is not worth a cross-package test dependency.
- **Size:** about −40 lines net, about 370 lines moved.
- **Risk:** very low.
- **Confidence:** verified.
- **Decision needed:** none. Whether this convention should apply repo-wide is for the interface auditor.

### PN-13 Pi decodes each live message up to four times, using magic role strings and forced casts
- **Category:** rule-violation / simplification
- **Evidence:**
  - `pi_history_mapper.dart:33-54` has four `decodeX` helpers. Each checks a raw `role`/`type` string, then force-casts with `as PiAssistantMessageDto?`.
  - `pi_event_dispatcher.dart:252` checks the role again, and `_nonAssistantEnd` (`:345-350`) tries each decoder in turn.
  - `pi_quota_interruption_mapper.dart:22` also uses the helpers.
- **Proposal:** decode once into the sealed `PiAgentMessageDto` and switch on the variant.
- **Size:** about −40 lines.
- **Risk:** low.
- **Confidence:** verified.
- **Decision needed:** none.

### PN-14 Drop the always-null `getSessions` `start` and `limit` (with the interface audit)
- **Category:** leftover
- **Evidence:**
  - Every caller passes null: the only production callers (`catalog_import_repository.dart:257`, `session_repository.dart:966`), `claude_plugin_impl.dart:412` and the Antigravity super call.
  - Each plugin still passes them down and slices in memory:
    - Claude: transcript catalog repository `:138`
    - Codex: `:951` → session service `:81` → catalog repository `:162`
    - OpenCode v1: `:404`
    - OpenCode v2: plugin `:201` → service `:163`
    - Pi: `:147` → catalog repository `:53`
    - ACP: `:881`
  - The benchmark fakes in `app/tool/benchmarks` also implement them.
- **Proposal:** remove both parameters everywhere in one lockstep PR.
- **Size:** about −50 lib lines plus call sites, about 14 files.
- **Risk:** low. Internal contract, no wire change.
- **Confidence:** verified.
- **Decision needed:** none beyond coordinating with the interface audit.

### PN-15 Overrides that repeat the interface default
- **Category:** leftover
- **Evidence:**
  - `getQueuedPrompts` (`const []`) and `cancelQueuedPrompt` (`false`) repeat the defaults at `bridge_plugin.dart:195,202`. They appear in Codex (`:1058,1061`), OpenCode v1 (`:613,616`) and OpenCode v2 (`:329,331`).
  - Codex `primeSessionDirectory` (`:948`) repeats the `{}` default at `bridge_plugin.dart:341`.
- **Proposal:** delete them, unless the interface audit makes these members abstract.
- **Size:** about −25 lines.
- **Risk:** none.
- **Confidence:** verified.
- **Decision needed:** none.

### PN-16 Reword the v1.9.0 "Plan advertised as an agent" COMPATIBILITY markers instead of retiring them
- **Category:** leftover (marker accuracy)
- **Evidence:**
  - The markers are in `claude_agent_selection.dart:15-18` (plus the plan-exit branch at `claude_plugin_impl.dart:457-475`), `codex_collaboration_mode.dart:31-35` and `omp_session_options_service.dart:264-267`. Copilot and Cursor carry the same wording; they belong to the ACP auditor.
  - Each says to remove it "once no catalog captured before this date can still be served". With 30-day catalog retention (`orchestrator.dart:295`), that reads as met since about 2026-10-21.
  - But `NewSessionDefaultsRepository` stores the agent with no expiry. `_withLastUsedPromptDefaults` (`:233-247`) returns it, and clients merge it into the new-session selection (`new_session_options_service.dart:307-310`).
  - Current clients validate the merged agent against the catalog (`session_selection_calculator.dart:107-116`, since v1.8.3 / #1294). Older public apps can still send "plan".
  - What removal would do:
    - Codex: an editing turn instead of read-only plan mode.
    - Claude: the send fails with `staleOptions`.
    - OMP: the turn runs in the default mode.
- **Proposal:** keep the aliases. Reword the condition to cover stored defaults and older apps.
- **Size:** about 10 comment lines.
- **Risk:** none for the rewording. Retiring the markers under the current wording risks unintended edits in Codex.
- **Confidence:** verified on the code path. I haven't checked whether stored rows with "plan" actually exist.
- **Decision needed:** only if the user would rather clear stored defaults once and retire all five.

### PN-17 Pi and OMP repeat the managed-runtime setup-status code and force-cast the selection
- **Category:** simplification / rule-violation
- **Evidence:**
  - `pi_plugin_descriptor.dart:222-286` and `omp_plugin_descriptor.dart:208-273` are identical apart from strings.
  - Both force-cast the selection with `as ManagedRuntimeNotSelected` and `as ManagedRuntimeAutomaticNotSelected` (Pi `:250,275`; OMP `:236,262`).
  - `_isUnknownRejection` and `_versionValidator` are also identical.
  - The 64 KiB executor is built 4 times in Pi and 3 times in OMP.
  - DeepSeek and Copilot already switch exhaustively over the same types.
- **Proposal:** at minimum, replace the casts with exhaustive switches. Optionally add one `managedRuntimeSetupStatus` helper in `sesori_plugin_runtime`, shared by four descriptors.
- **Size:** about 20 lines changed, or about −150 lines net with the helper.
- **Risk:** low.
- **Confidence:** verified.
- **Decision needed:** casts only, or the shared helper? The helper makes the hint wording the same across harnesses.

### PN-18 Claude: small duplications in the live path
- **Category:** simplification
- **Evidence:**
  - `retryStatus` (`:166-178`) duplicates `_mapRetry` (`:666-683`), and `claude_plugin_impl.dart:805-810` calls both for one frame.
  - `_findSession` (`:753-771`) duplicates the catalog repository's `_toPluginSession` (`:221-235`).
- **Proposal:** derive one from the other in each pair.
- **Size:** about −30 lines.
- **Risk:** low.
- **Confidence:** likely.
- **Decision needed:** none.

### PN-19 Grouped AGENTS.md rule violations
- **Category:** rule-violation
- **Null assertions** (heuristic counts; listed sites were checked):
  - Claude, about 10: `claude_backend_catalog_repository.dart:218,220,238`, `claude_quota_interruption_mapper.dart:43,48`, `claude_mcp_login_output_parser.dart:73,78`, plus the form schema (PN-6).
  - Codex, about 21:
    - `codex_tool_outcome_storage.dart:28,46,100` (should become a sealed result)
    - `approval_registry.dart:324-339`
    - `codex_event_mapper.dart:865-877`
    - `codex_plugin_impl.dart:324,542`
    - `codex_message_repository.dart:405,440`
    - `codex_session_mapper.dart:75`
    - tracker `:64,213`
  - OpenCode, about 18:
    - descriptor `:655,694,850`
    - `opencode_repository.dart:156,207`
    - `opencode_v2_service.dart:636`
    - `open_code_catalog_database_api.dart`, 4 sites
    - `opencode_v2_api.dart:97,165,495`
  - Pi, about 14:
    - `pi_backend_catalog_repository.dart:113,194,261,275,334` (parse into a non-null record)
    - `pi_session_process_repository.dart:271-275`
    - `pi_session_storage_api.dart:1327,1340`
    - `pi_rpc_client.dart:460`
    - `pi_plugin_impl.dart:525`
  - OMP, 5: `omp_catalog_service.dart:81,99`, `omp_session_options_service.dart:90,263`, `omp_session_cleanup_service.dart:36`.
- **Magic strings:**
  - Claude:
    - `"anthropic"` 6 times, although a constant exists at `claude_backend_catalog_repository.dart:34`
    - raw control subtypes (`claude_approval_registry.dart:141,144`)
    - tool names, and `claude_session_service.dart:817-834` parses `ScheduleWakeup` maps by hand
  - Codex: `?? "openai"` 7 times.
  - Pi: `"pi"` at `pi_plugin_impl.dart:544` and `pi_backend_catalog_repository.dart:177`.
- **Empty string standing for missing data:**
  - OpenCode: `executablePath: ""` in the attach, shared and degraded modes (`descriptor:701,731,778`), and `?? ""` at `open_code_runtime_policy.dart:223,386`.
  - Codex: `codex_app_server_client.dart:19-22`, `approval_registry.dart:272`, `codex_event_mapper.dart:815`, `codex_runtime_policy.dart:135`, `codex_question_mapper.dart:29`.
  - The two ownership-record `?? ""` sites mirror persisted bytes. Leave them unless that record changes anyway.
- **Optional or defaulted parameters that should be required:**
  - `OmpPlugin` factory: `binaryPath`, `launchDirectory`, `scratchDirectory`, with a fallback to `Directory.current` (`omp_plugin_impl.dart:35-41`)
  - `CodexRolloutApi` and `CodexConfigReader` `environment`, which falls back to `Platform.environment`. Both also resolve `CODEX_HOME` separately.
  - `OpenCodeApi.listSessions({String? directory})`
  - about 75 positional parameters on Codex methods outside the interface
- **Swallowed errors:**
  - `codex_plugin_descriptor.dart:451` catches `on Object` around `codex login status` and logs nothing.
  - OpenCode v1 `healthCheck` (removed by PN-5).
- **Proposal:** fix each plugin inside the PRs above where files overlap, otherwise one small PR per plugin.
- **Size:** about 250 lines changed, about 35 files.
- **Risk:** low.
- **Confidence:** verified for the listed sites; the counts are heuristic.
- **Decision needed:** none.

### PN-20 Turn-lifecycle state flattened into parallel mutable maps (Codex, Pi)
- **Category:** structural
- **Evidence:**
  - **Codex:** `codex_plugin_impl.dart` (1,867 lines) keeps seven per-thread maps at `:124-151`; `_activeTurnByThread` alone has 23 references.
    - Thread directory and model are mirrored across the plugin, the session service and the event mapper, which holds seven mutable maps. The model is pushed in by hand at 6 sites.
    - There are about 25 `method == "..."` string checks and about 80 raw `params["..."]` reads.
  - **Pi:** `_PiTurn` (`:76-82`) and `_PiSessionTurnState` (`:34-64`) in `pi_session_service.dart` (1,395 lines) use many mutable booleans and fields. It is the most-changed Pi file, with 8 commits since 2026-09-06.
- **Proposal:**
  - Codex: one owner of per-thread live context, a sealed per-thread turn state, and a `CodexNotificationMethod` enum, done after PN-10.
  - Pi: remodel `_PiTurn` as sealed phases when the next turn-lifecycle bug lands there.
- **Size:** Codex about 300–500 lines; Pi about 150.
- **Risk:** high for Codex, medium for Pi.
- **Confidence:** verified for the code shape. How many bugs this area produces is unknown.
- **Decision needed:** whether to schedule it at all.

### PN-21 Cross-plugin duplication handed to the ACP and interface auditors
- **Category:** structural
- **Evidence:**
  - OMP's `omp_acp_api.dart` (170 lines) repeats the scratch-lease lifecycle (open, settle, close, scratch directory) of Hermes, Grok, Antigravity and the Cursor probe (about 700 lines across 5 plugins).
  - OMP overrides all four catalog getters while still passing `AcpSessionOptionsService` to the base.
  - The forwarding `new composed(...) : this._(...)` constructor (`codex_plugin_impl.dart:161-197`) repeats in six plugins.
- **Proposal:** the ACP audit decides; one possible fix is a shared scratch-lease helper in `sesori_plugin_acp`.
- **Size:** about −300 lines.
- **Risk:** medium.
- **Confidence:** likely.
- **Decision needed:** owned by the ACP audit.

### PN-22 OpenCode v1 adapter: still reachable and kept on purpose; removing it would mean raising the PATH minimum
- **Category:** structural (decision record)
- **Evidence:**
  - Adapter selection in `open_code_plugin_descriptor.dart:832-843`:
    - a shared endpoint selects v2
    - no server handle (degraded start, unreachable attach, no binary) selects v1
    - otherwise `probeOpenCodeProtocol` decides
  - The 2026-09-25 user decision (D1/D4) and `HARNESS_CAPABILITIES.md:317` keep v1 with `minPathVersion` 1.14.0.
  - Upstream `opencode-ai` and GitHub latest are 1.19.5 (v1); v2 ships only as `@opencode/cli` 2.2.5.
  - Code that exists only for v1:
    - about 5.4k hand-written lines
    - about 3.9k used generated lines, plus PN-2's 5.9k unused
    - about 11.5k test lines
  - Live checks cover v2 only.
  - A degraded or no-server start builds the v1 adapter even for v2 users until restart; the comment at `:832` says this.
- **Proposal:** keep it. The trigger for removal would be raising `minPathVersion` to 2.0.11 after upstream makes v2 its main release, which would remove about 20k lines.
- **Risk:** high if removed now.
- **Confidence:** verified.
- **Decision needed:** whether to add a v1 live check, since v1 is still upstream's default.

## Checked and kept

- **No branch below the PATH minimum.** These version workarounds sit inside the supported ranges:
  - Codex 0.144.x and ≤0.147 markers are above 0.139.0.
  - Claude `_UnstartedCompaction` is not excluded by 2.1.221.
  - Pi's 1.0.4 startup extension and llama.cpp exclusion are above 0.99.0.
  - OMP `unrestorableSessionMessage` (18.6.3) is above 17.2.13.
- **Kept COMPATIBILITY markers:**
  - Claude and Codex v1.9.2 markers protect public v1.9.1 clients.
  - Codex v1.6.0/v1.7.0 aliases, legacy message ids and rollout exit status.
  - The OpenCode `session.idle` branch (PN-1 only rewords its comment).
- **On-disk compatibility** (Claude older-CLI transcript fallbacks, Pi v1 session files, Codex `turn_context` fallback) has backend retiring conditions, per the CONSOLIDATION deferral.
- **E5** `ManagedRuntimeComposition` landed in the Codex, OpenCode, Pi and OMP descriptors. Heavy-users steps 7–9 and OpenCode `readCatalogSnapshot` left no parallel scan path.
- **OpenCode v1 catalog `Unavailable`** is reachable (`listCatalogSessions` returns null on `x-next-cursor`), so the app's parent-walk fallback stays.
- **OpenCode shared service** is v2-only and keeps the private-server fallback by design.
- **OpenCode code that stays:**
  - `OpenCodeManagedApi` has two implementations.
  - The v1 and v2 MCP auth services differ (similarity 0.48).
  - The barrel is used by an app test.
  - The README is current.
- **Session-storage parsing** differs per on-disk format. The shared skeleton (stat-stamp cache plus `Isolate.run`, including the identical `({int size, DateTime modified})` typedef in Claude and Pi) is about 30 lines each, too little to extract.
- **Live versus replay projection** is already shared within each plugin.
- **Pi versus OMP:** OMP is built on the ACP base, not on Pi's RPC stack. Only the setup code duplicates (PN-17).
- **Claude versus Codex** approval registries (0.13) and process factories (0.53) are backend-typed.
- **No-op interface members** are honest harness gaps; archival stays in the bridge DB:
  - Claude `deleteWorkspace`
  - Pi `archiveSession`, `deleteWorkspace`, `getPendingPermissions`
  - Codex `archiveSession`, `deleteWorkspace`, `forgetMcpAuthentication`
  - Codex and OpenCode quota readiness (active quota plan)
- **unref.tsv false positives:**
  - Claude `ClaudeTaskStatusMapping` and `unsupportedRedactedThinking`
  - Codex `CodexMcpOAuthFailureParsing`, `environmentContext`, `recommendedPlugins` and `CodexCollaborationModeDto`
  - Pi `clearTimeout`/`queueMicrotask`, which are JavaScript
- **deps.tsv:** `json_annotation` is needed by json_serializable in Claude, Codex and Pi.
- **Logging:** Codex `Log.w` calls without an error object are deliberate privacy redactions. Every Pi/OMP `on Object catch` logs.
- **Large files:** no split lowers risk beyond PN-3, PN-7 and PN-20.
- **Previous audit D3** is done.
- **todo.txt:** the `claude_event_dispatcher.dart:210` note is resolved by PN-7.
