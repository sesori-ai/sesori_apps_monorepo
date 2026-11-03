# Cross-cutting cleanup audit (compatibility and dependencies; CI and docs are in the partial files)

## Summary
Compatibility code and stalled plans are the main debt; dependencies, CI and regression docs are in good shape.
- **No gate:** nothing enforces a minimum peer version, so every code marker is reachable and retiring them is a support-window decision.
- **Top 3:**
  1. A support floor plus a bridge-version check (XC-1).
  2. Retiring the 8 finished plans (XC-DOC-1).
  3. The dormant runtime-update seam (XC-DOC-2).
- **Removable with no decision:** about 300 lines. Up to about 4,500 more depend on decisions.

## Findings

### XC-1 Retiring compatibility needs a support floor; no minimum-version gate exists
- Category: leftover (needs a decision)
- Evidence:
  - **Gate search, all negative:**
    - The bridge has sent `HealthResponse.version` since v1.0.8 (`shared/sesori_shared/lib/src/models/sesori/health_response.dart`), but no client code reads it.
    - The offline placeholder `HealthResponse(version: "", ...)` at `client/module_core/lib/src/capabilities/server_connection/connection_service.dart:360` uses an empty string for missing data, which breaks an AGENTS.md rule.
    - `framing.dart` `protocolVersion = 0x01` is never compared.
    - No bridge route rejects an app version.
    - There is no forced-update or minimum-version flag in `remote_config_flags.dart`.
    - The CLI bridge updates itself at start and every 4 h (`bridge/app/lib/src/updater/services/update_service.dart`).
  - **Prior decisions:**
    - CONSOLIDATION item 7 requires a supported-peer decision plus per-field release evidence.
    - #1296 proposed D1 (`>= v1.6.0`), but that PR was closed and D1 was never decided.
    - The decision is still missing. The evidence now exists: the table below traces every marker to the first public release involved.
  - **Largest blocks:**
    - The complete-list mode in `client/module_core/lib/src/services/session_window_service.dart` (891 lines in total) serves bridges without `/sessions/page`. It is about 150 lines and goes at a v1.11.0 bridge floor.
    - The legacy session-options path goes at a v1.7.0 bridge floor (about 200 lines in all). It is:
      - `session_detail_load_service.dart:337`;
      - the unmarked `NewSessionOptionsSource.legacy` and `_loadLegacy` in `new_session_options_service.dart:97,183`;
      - `SessionRepository.loadLegacySessionOptions` (about lines 294–334);
      - `session_options_repository_result.dart` (66 lines).
    - The pull request refresh settings stack (about 70 lib hits and 20 test files) goes at a v1.10.1 app floor. I checked the client at each tag: apps from v1.10.1 on no longer use it. It is:
      - `pull_request_refresh_settings_service.dart`;
      - two route handlers;
      - the shared model;
      - the `bridge_settings*` fields;
      - the orchestrator wiring.
    - Also going at a v1.10.1 app floor: `get_base_branch_handler.dart` with `base_branch_response.dart`, and `project_view` (`orchestrator.dart:2481`, `messages.dart:55`).
- Proposal:
  1. The owner picks a floor for each direction.
  2. Before removing any bridge-direction marker, add a client-side gate. `ConnectionService` compares `HealthResponse.version` with a `minimumSupportedBridgeVersion` constant. Below it, the app shows "Update your bridge" instead of degrading silently. This is about 30 lines with no wire change, and AGENTS.md requires surfacing unsupported peers explicitly.
  3. For the app direction, either accept that older apps degrade, or have the auth server enforce `DeviceInfo.appVersion`.
  4. Retire one boundary group per PR, each under 1,500 lines.

**Bridge floor** (client code that tolerates old bridges):

| Drop support for bridges older than | Markers | Lib lines | Test lines |
|---|---|---|---|
| v1.4.1 (2026-07-10) | 6 | ~24 | – |
| v1.5.1 (07-17) | 10 | ~43 | – |
| v1.6.0 (07-24) | 13 | ~59 | – |
| v1.7.0 (08-05) | 20 | ~291 | ~422 |
| v1.8.0 (08-20) | 32 | ~361 | ~524 |
| v1.8.1 (08-26) | 44 | ~393 | – |
| v1.8.4 (09-15) | 53 | ~429 | – |
| v1.9.0 (09-24) | 57 | ~466 | ~698 |
| v1.9.1 (10-14) | 66 | ~512 | – |
| v1.10.1 (10-27) | 74 | ~545 | ~853 |
| v1.11.0 (11-01) | 80 | ~734 | ~1,061 |

**App floor** (bridge code that tolerates old apps):

| Drop support for apps older than | Markers | Lib lines | Test lines |
|---|---|---|---|
| v1.5.1 | 2 | ~8 | – |
| v1.6.0 | 3 | ~10 | – |
| v1.7.1 | 5 | ~55 | – |
| v1.8.0 | 11 | ~140 | ~270 |
| v1.8.4 | 14, plus the unmarked shell-title alias | ~190 | – |
| v1.9.0 | 16 | ~196 | ~322 |
| v1.9.1 | 18 | ~221 | – |
| v1.10.1 | 36 | ~482 | ~861 |

**Same floor in both directions** (includes the two markers that apply to both, #95 and #139):

| Floor | Markers | Lib lines | Test lines |
|---|---|---|---|
| v1.8.0 | ~44 | ~505 | ~800 |
| v1.9.0 | ~75 | ~640 | ~1,036 |
| v1.10.1 | ~112 | ~1,005 | ~1,730 |

- Size: as in the tables, plus about 30 lines added for the gate.
- Risk: medium and visible on the wire. Without the gate, peers below the floor fail silently. The bridge side carries little real risk because of auto-update; the risk is old app installs.
- Confidence: verified that no gate exists and verified each marker's boundary. Line counts are rough.
- Decision needed:
  - the minimum supported bridge and app versions;
  - whether to add the gate first;
  - whether to enforce the app floor on the auth server or accept degradation.

#### Marker group table
`#n` is the marker's position among the 140 code markers in `compat.txt`. The 26 markers under `.plan/completed` are historical text and need no action.

Prefixes: `sh/` = `shared/sesori_shared/lib/src/models/sesori/`, `mc/` = `client/module_core/lib/src/`.

| Group | Markers | Files | Protects | Peers needing it | Verdict |
|---|---|---|---|---|---|
| Auth-server 404/405 branch | #1 | bridge/app `app_client_status_repository.dart:19` | nothing (both branches identical) | Sesori-run server | Retire now (XC-2) |
| Plan advertised as agent | #18 #21 #28 #35 #36 #37 | `claude_plugin_impl.dart:457`, `claude_agent_selection.dart:15`, `codex_collaboration_mode.dart:31`, `copilot_session_options_service.dart:216`, `cursor_catalog_tracker.dart:89`, `omp_session_options_service.dart:264` | catalogs cached before 2026-09-21 | condition met 2026-10-21 | Retire now (XC-2) |
| OpenCode `session.idle` | #38 #39 | `sse_event_mapper.dart:122`, `tool/generate_sse_events.dart:266` | the only idle signal OpenCode has | OpenCode runtime | Keep; misleading marker (XC-3) |
| Codex null agent | #26 | `codex_collaboration_mode.dart:23` | live path (`agent` is nullable on the wire) | – | Keep; misleading marker (XC-3) |
| Codex runtime and rollout workarounds | #22 #23 #25 #30–#34 | `codex_rollout_api.dart:224,294`, `codex_plugin_impl.dart:1423`, `codex_message_repository.dart:908`, `codex_rollout_tool_mapper.dart:496,550`, `codex_rollout_tailer.dart:18,210` | Codex ≤0.147 and 0.144.x; old on-disk rollouts | Codex minPath 0.139.0 | Keep; #25 goes when the Codex minimum passes 0.147 |
| Legacy `.worktrees/` | #4 | `worktree_repository.dart:236` | worktrees already on disk | local | Keep |
| Voice retryability | #52 | `mc/repositories/voice_repository.dart:111` | older Sesori voice server | Sesori-run | Retire after confirming the server (about 3 lines) |
| Native storage v1 | #40 #44 | `client/app/.../injection.dart:37`, `mc/migrations/deprecated_native_storage_v1/` | installs upgrading from ≤v1.9.0 | local upgrade | Decision (XC-4) |
| Requests without pluginId | #67 #100, plus #95 (both directions) | `sh/create_session_request.dart:15`, `sh/plugin_project_id_request.dart:13`, `sh/plugin_identity.dart:21` | OpenCode meaning | apps &lt; v1.5.1 | Floor |
| Open project with path only | #114 | `sh/project.dart:133` | no `gitAction` | apps &lt; v1.5.2 | Floor |
| Unarchive via `archived:false`; pagination limit | #11 #127 | `session_lifecycle_service.dart:146`, `sh/session.dart:155` | old requests | apps &lt; v1.7.1 | Floor |
| Older-app requests (v1.8.0) | #5 #9 #7 #128 #137 #27 | `delete_session_handler.dart:25`, `update_session_archive_status_handler.dart:30`, `get_pull_request_refresh_settings_handler.dart:8`, `sh/session.dart:162`, `protocol/messages.dart:37`, `codex_collaboration_mode.dart:28` | deleteBranch, old PR-refresh read, inline images, "default" alias | apps &lt; v1.8.0 | Floor |
| Scoped and atomic stop | #58 #59 | `sh/abort_session_request.dart:30,34` | – | apps &lt; v1.8.3 / v1.8.4 | Floor |
| storedOnly and shell-title alias | #129, plus the unmarked alias | `sh/session.dart:172`, `plugin_to_shared_mapping.dart:89`, `duplicated_shell_title_mapper.dart` | – | apps &lt; v1.8.4 | Floor |
| fastMode omitted | #68 #117 | `sh/create_session_request.dart:22`, `sh/send_prompt_request.dart:21` | – | apps &lt; v1.9.0 | Floor |
| Full tool parts; plain responses | #130 #136 | `sh/session.dart:177`, `protocol/messages.dart:19` | – | apps &lt; v1.9.1 | Floor |
| Older-app routes and fields (18 markers) | #0 #2 #3 #6 #8 #10 #12–#17 #19 #20 #24 #64 #69 #138 | project_view (`orchestrator.dart:2481`, `messages.dart:55`); PR refresh (`bridge_settings.dart:176`, `bridge_settings_repository.dart:46`, `patch_bridge_settings_handler.dart:26`, `pull_request_refresh_settings_service.dart:6`, `sh/bridge_settings_response.dart:12`); `get_base_branch_handler.dart:12`; Claude and Codex question routes (`claude_approval_registry.dart:48,58,400,410`, `claude_plugin_impl.dart:424,437,482,488`, codex `approval_registry.dart:88`); `sh/delete_session_request.dart:14` | – | apps &lt; v1.10.1 | Floor |
| Project field defaults and event payload | #103 #110 #111 #102 #109 #120 | `sh/project.dart:25,27,59,64,71`, `sh/sesori_sse_event.dart:325` | unseen, missing directory, time | bridges &lt; v1.3.0 to v1.4.1 | Floor |
| Directory-as-id; sessions without plugin | #48 #107 #108 #122 | `mc/repositories/project_repository.dart:35`, `sh/project.dart:39,57`, `sh/session.dart:39` | – | bridges &lt; v1.5.1 | Floor |
| Visibility capability | #112 | `sh/project.dart:76` | – | bridges &lt; v1.5.2 | Floor |
| Plugin statuses | #47 #134 | `plugin_repository.dart:294`, `sh/session_status.dart:13` | – | bridges &lt; v1.6.0 | Floor |
| Legacy options, attachments, harness capabilities, "codex" alias | #46 #54 #88 #96 #97 #98 #29 | `plugin_repository.dart:281`, `session_detail_load_service.dart:337` (plus the unmarked path, XC-5), `sh/message_part.dart:399`, `sh/plugin_list_response.dart:21,36,40`, `codex_collaboration_mode.dart:36` | – | bridges &lt; v1.7.0 | Floor |
| Pagination cursor | #89 | `sh/message_with_parts.dart:19` | – | bridges &lt; v1.7.1 | Floor |
| v1.8.0 bridge fields | #42 #43 #63 #93 #99 #101 #118 #121 #123 #131 #133 | `mc/api/session_api.dart:244,294`, `sh/active_session.dart:20`, `sh/pending_permission.dart:29`, `sh/plugin_management.dart:74`, `sh/plugin_setup_response.dart:22`, `sh/sesori_sse_event.dart:240,344`, `sh/session.dart:58`, `sh/session_cleanup_rejection.dart:21`, `sh/session_options_response.dart:25` | – | bridges &lt; v1.8.0 | Floor |
| Message-part `@Default("")` (also empty string as missing data); import progress | #76–#86 #66 | `sh/message_part.dart:106–211`, `sh/catalog_import_progress.dart:51` | – | bridges &lt; v1.8.1 | Floor |
| v1.8.2 bridge fields | #75 #90 #113 #132 | `sh/message.dart:54`, `sh/message_with_parts.dart:22`, `sh/project.dart:78`, `sh/session_options_response.dart:17` | – | bridges &lt; v1.8.2 | Floor |
| v1.8.3 bridge fields | #62 #65 | `sh/abort_session_request.dart:110`, `sh/bridge_settings_response.dart:17` | – | bridges &lt; v1.8.3 | Floor |
| v1.8.4 bridge fields | #60 #91 #116 | `sh/abort_session_request.dart:47`, `sh/message_with_parts.dart:30`, `sh/queued_prompt.dart:27` | – | bridges &lt; v1.8.4 | Floor |
| Notification policy | #139 (both directions) | `protocol/messages.dart:91` | – | peers &lt; v1.8.4 | Floor |
| v1.9.0 bridge fields | #53 #115 #124 #126 | `session_auto_continuation_service.dart:18`, `sh/provider_info.dart:41`, `sh/session.dart:60,79` | – | bridges &lt; v1.9.0 | Floor |
| v1.9.1 bridge fields | #49 #51 #70 #71 #87 #92 #104 #125 #135 | `session_repository.dart:159,253`, `sh/filesystem_suggestion.dart:26`, `sh/health_response.dart:28`, `sh/message_part.dart:222`, `sh/message_with_parts.dart:35`, `sh/project.dart:30`, `sh/session.dart:65`, `sh/yolo_settings.dart:14` | – | bridges &lt; v1.9.1 | Floor |
| v1.10.1 bridge fields | #41 #61 #72 #73 #74 #94 #105 #119 | `session_abort_scope_dialog.dart:101`, `sh/abort_session_request.dart:59`, `sh/mcp.dart:171,174,188`, `sh/pending_question.dart:30`, `sh/project.dart:32`, `sh/sesori_sse_event.dart:275` | – | bridges &lt; v1.10.1 | Floor |
| Paged sessions, file preview, project count | #45 #50 #55 #56 #57 #106 | `file_preview_repository.dart:18`, `session_repository.dart:172`, `session_window_service.dart:73,79,384`, `sh/project.dart:35` | – | bridges &lt; v1.11.0 | Floor |

Totals: 7 to retire now, 15 to keep or outside peer policy, 36 at an app floor, 80 at a bridge floor, 2 in both directions. That makes 140.

### XC-2 Retire the dead auth-server branch and the 2026-09-21 Plan-as-agent markers now
- Category: leftover
- Evidence:
  - **Dead branch:** in `bridge/app/lib/src/repositories/app_client_status_repository.dart:17-23`, the marked 404/405 branch and the fallthrough return the same `AppClientStatusUnavailable(...)`.
  - **Plan markers:** they retire "once no catalog captured before this date can still be served". Catalogs go stale after 10 minutes (`session_options_service.dart:15`) and are kept for 30 days (`orchestrator.dart:295`). So the condition was met on 2026-10-21.
  - **How current clients pick agents:** they resolve agent candidates against the served catalog (`session_detail_cubit.dart:1763,3383`, `session_selection_calculator.dart:37,150`).
  - **After removal:**
    - Claude rejects an unknown agent with an explicit stale-options error.
    - Codex `fromAgent` returns null, and `codex_app_server_api.dart:224` starts the turn without a collaborationMode, which means the default editing mode.
- Proposal:
  - Collapse the `if`.
  - Delete `ClaudeAgentSelection.plan` and the plan-exit branch at `claude_plugin_impl.dart:457`.
  - Delete the Codex `"plan" => plan` mapping. The `plan` enum value stays, because plan mode still uses it (`codex_session_service.dart:745,952`).
  - Delete the stale-Plan acceptance in Copilot, Cursor and OMP.
- Size: about 55 lib and 80 test lines; 7 files plus tests.
- Risk: low. If a v1.8.x app sends a saved "Plan" agent without checking the catalog:
  - Claude fails loudly.
  - Codex runs the turn in editing mode. If that is unacceptable, make Codex reject unknown agents too (about 3 lines).
- Confidence: verified for the dead branch and the met condition. How v1.8.x apps persist the agent is likely but not traced at the tags.
- Decision needed: none.

### XC-3 Two markers call live code compatibility; removing it as written would break behavior
- Category: leftover (misleading comment, safety)
- Evidence:
  - **OpenCode (#38, #39):**
    - The marker at `sesori_plugin_opencode/lib/src/sse_event_mapper.dart:122` reads "remove when those runtimes are unsupported". With `_minPathVersion = "1.14.0"`, that sounds met.
    - But `SseSessionIdle → BridgeSseSessionIdle` is OpenCode's only producer of `BridgeSseSessionIdle`; `session.status` idle maps to `BridgeSseSessionStatus`.
    - `BridgeSseSessionIdle` drives `_finalizeOpenToolParts` (`orchestrator.dart:1696`), `recordSessionCompletion` (`session_event_service.dart:130`) and `markSessionIdle` (`:236`).
    - Deleting the branch would silently stop OpenCode session-completion records and tool-part finalization.
  - **Codex (#26):** the marker at `codex_collaboration_mode.dart:23` says "Older apps omit the agent". But `agent` is `String?` on the current wire (`send_prompt_request.dart:15`, `create_session_request.dart:18`), and `session_api.dart` passes it nullable, so the path is live.
- Proposal:
  - Reword the OpenCode marker now. With the next OpenCode runtime update, derive `BridgeSseSessionIdle` from `session.status` idle, then delete the deprecated variant and the generator branch (`tool/generate_sse_events.dart:266`).
  - Drop the marker from Codex `null => defaultMode`.
- Size: about 4 comment lines now. The later OpenCode change is about 10–20 lines net, plus regenerating the generated code.
- Risk: none for the comments. Medium for the later change, which needs a live check of an OpenCode turn ending.
- Confidence: verified. Not verified: whether OpenCode ≥1.14 always emits `session.status` idle.
- Decision needed: none.

### XC-4 Native storage v1 migration: choose the oldest install that may upgrade directly
- Category: leftover (needs a decision)
- Evidence: this code exists only to migrate installs older than v1.9.1. It is not wire compatibility, and no native platform code depends on it.
  - `client/app/lib/core/di/injection.dart:37` (#40)
  - `client/module_core/lib/src/migrations/deprecated_native_storage_v1/` (415 lines, 139 of them generated; #44)
  - `client/app/lib/core/platform/deprecated_native_storage_v1/flutter_legacy_native_storage_adapter.dart` (16 lines)
  - `client/app/integration_test/native_persistence_migration_test.dart` (297 lines)
- Proposal: set an upgrade-from baseline, then delete the migration directory, the adapter, the DI line and the test. An example baseline: installs older than v1.9.1 start fresh and the user signs in again.
- Size: about 430 lib lines (about 140 generated) and about 300 test lines.
- Risk: medium and visible to users. Anyone who skips straight from an old version loses local settings and has to sign in again. Decide this together with the XC-1 app floor.
- Confidence: verified.
- Decision needed: should installs older than v1.9.1 keep migrating their data?

### XC-5 Compatibility code without a marker
- Category: rule-violation
- Evidence:
  - **Shell-title alias:** `bridge/app/.../plugin_to_shared_mapping.dart:89` and `duplicated_shell_title_mapper.dart` (20 lines). The comment says "Apps since v1.8.4 render the command from shellCommand… Live events keep the title for older apps".
  - **New-session options:** `new_session_options_service.dart:97,183` (`NewSessionOptionsSource.legacy`, `_loadLegacy`). Only the session-detail half is marked.
  - **`/agent` and `/provider`:** the bridge handlers are `post_agents_handler.dart` and `get_providers_handler.dart`. Current clients call these routes only from `loadLegacySessionOptions` (`session_repository.dart:299-300`), so the app boundary needs a check.
  - **Test-only methods:** `SessionRepository.listAgents` and `listProviders` (`session_repository.dart:279-287`) are used only by `lib/src/testing/test_helpers.dart`.
- Proposal:
  - Add dated markers so these sites retire with the XC-1 floors:
    - the shell-title alias at the v1.8.4 app floor;
    - the legacy options path at the v1.7.0 bridge floor;
    - `/agent` and `/provider` at an app floor still to be confirmed.
  - Delete the two test-only repository methods and their helper stubs.
- Size: about 6 marker lines added and about 20 lines removed. The marked code (about 260 lines) is counted in XC-1.
- Risk: none.
- Confidence: verified, except the app boundary for `/agent` and `/provider`.
- Decision needed: none.

### XC-6 Unused or misplaced dependencies
- Category: leftover
- Evidence: I checked `deps.tsv` and confirmed each item with rg across lib, test, bin, tool and hook.
  - `client/app` `freezed_annotation`: there is no freezed code in client/app; the dependency came in with the #329 rename.
  - `client/app` `flutter_svg`: only `test/helpers/test_helpers.dart` imports it, so it belongs in dev dependencies.
  - `module_app_ui` dev dependency `cupertino_ui`: added in #1243 and never imported.
  - `shared/no_slop_linter` dev dependency `path`: never imported. Its `dartz` dev dependency is used and stays.
  - Needs-check: `client/app` dev dependency `vector_graphics_compiler` is referenced nowhere, but it may be the manual tool for regenerating the `.vec` assets.
  - Needs-check: the `no_slop_linter` dev dependency in 7 packages. The plugin is loaded by path in `client/analysis_options.yaml`.
- Proposal:
  - Remove the 3 unused dependencies and move `flutter_svg` to dev dependencies.
  - Settle the two needs-check items first: confirm how the `.vec` assets are regenerated, and confirm `dart analyze --fatal-infos` still runs the custom lints after removing one `no_slop_linter` dev dependency.
  - Do all of this inside the weekly update-dependencies PR.
- Size: about 5–12 pubspec lines plus lockfiles.
- Risk: low.
- Confidence: verified for the first 4.
- Decision needed: none.

### XC-7 Marker format and accuracy violations
- Category: rule-violation
- Evidence:
  - **Non-product labels:** 8 Codex markers use a label other than a product version: #22, #23, #34 ("Codex JSONL writer"), #25 ("Codex app-server &lt;=0.147"), #30, #31, #32, #33.
  - **Wrong comment style or position:** `///` at `codex_rollout_tool_mapper.dart:496,550` and `codex_rollout_tailer.dart:18`; the last one sits above the class instead of the branch.
  - **Retiring condition missing or vague:**
    - #67, #100, #122 ("Remove default; require it")
    - #95, #102, #109, #120
    - #132 (no cleanup stated)
    - #11 ("when out of support")
  - **Wrong boundary:**
    - #134 says pre-v1.5.1, but the field first went public in v1.6.0.
    - #48 says "older than v1.5.0", which may never have been public (see below).
  - **Boundaries at versions that were never public:** "v1.10.0" in #0, #64, #138 and "v1.9.2" in #2, #3, #8, #10. Both mean v1.10.1.
  - **Possibly never public:** v1.5.0 and v1.6.1 have no GitHub release, but the brief doesn't list them as never public.
- Proposal: fix each one the next time its group is touched (XC-1 PRs or a Codex runtime update), not in a standalone PR.
- Size: about 30 comment lines.
- Risk: none.
- Confidence: verified.
- Decision needed: confirm whether v1.5.0 and v1.6.1 were ever public.

### XC-CI-1 to XC-CI-13 and XC-DOC-1 to XC-DOC-14
These are complete in the brief's format in [ci.md](ci.md) and [docs-and-plans.md](docs-and-plans.md).

## Re-check of deferred items
- **CONSOLIDATION item 7 and the compatibility floor:** still deferred, because there is still no decision. The evidence it asked for is now in XC-1, so the only blocker left is the decision itself.
  - The #1296 inventory is covered by the XC-1 table, except `Session.pullRequestHistory`, which no longer exists (PR tracking was removed).
  - The auth-server and on-disk markers (#1, #4, #52, the Codex group) stay out of any floor, as CONSOLIDATION requires.
- **Dependencies (item 14):** nothing was retained there; the XC-6 items are new.
- **Desktop attention:** becomes eligible once XC-DOC-1 retires desktop-app.

## Checked and kept
- **`json_annotation`:** json_serializable 6.15.2 warns when it is not a direct dependency, so it stays in every package that uses it.
- **bridge/app `hooks` and `code_assets`:** used by `hook/build.dart`.
- **module_persistence `sqlite3`:** likely pins the native build hooks. It stays; check before removing.
- **`crypto` and `cryptography`:** they do different jobs. The constraint drift between them is cosmetic and the update-dependencies skill handles it.
- **Codex runtime workarounds and the `.worktrees/` legacy path:** these are runtime and on-disk compatibility, not peer policy.
- **`/project/current`:** still used by `project_api.dart:27`.
- **Codex `CodexCollaborationMode.plan` enum value:** live plan mode.
- **CI and docs:** see "Checked and kept" in the two partial files.
