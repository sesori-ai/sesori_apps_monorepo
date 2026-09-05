# Periodic cleanup tracker

Authority: [PLAN.md](PLAN.md). Fixed proposed series: **25 steps**.
The user authorized consolidating #1296, closing it, and broad documentation
simplification. Refactor execution was accepted on 2026-09-05 when the user
asked to start working the plan; steps execute in order from step 2.
[Source-step dispositions](CONSOLIDATION.md).

| Step | Exact PR title | Status | PR |
| --- | --- | --- | --- |
| 1/25 | 🌱 [periodic-cleanup] docs: consolidate the repository cleanup plan [step 1/25] | Merged | [#1295](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1295) |
| 2/25 | ⚙️ [periodic-cleanup] client: preserve streamed text across refresh [step 2/25] | Merged | [#1299](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1299) |
| 3/25 | ⚙️ [periodic-cleanup] client: preserve live transcript during refresh [step 3/25] | Merged | [#1303](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1303) |
| 4/25 | ⚙️ [periodic-cleanup] bridge: remove unused session paths and tracker state [step 4/25] | Merged | [#1305](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1305) |
| 5/25 | 🚧 [periodic-cleanup] bridge: remove unused options cache metadata [step 5/25] | Merged | [#1308](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1308) |
| 6/25 | ⚙️ [periodic-cleanup] plugins: keep session status events typed [step 6/25] | Merged | [#1309](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1309) |
| 7/25 | 🚧 [periodic-cleanup] plugins: keep message events typed [step 7/25] | Merged | [#1311](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1311) |
| 8/25 | ⚙️ [periodic-cleanup] bridge: narrow session and activity projections [step 8/25] | Merged | [#1313](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1313) |
| 9/25 | ⚙️ [periodic-cleanup] plugins: stop forwarding unused backend events [step 9/25] | Merged | [#1314](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1314) |
| 10/25 | ⚙️ [periodic-cleanup] client: share native thumbnail storage [step 10/25] | Merged | [#1318](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1318) |
| 11/25 | ⚙️ [periodic-cleanup] client: share optimistic rename bookkeeping [step 11/25] | Merged | [#1320](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1320) |
| 12/25 | ⚙️ [periodic-cleanup] runtime: share managed installer composition [step 12/25] | Merged | [#1322](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1322) |
| 13/25 | ⚙️ [periodic-cleanup] runtime: share provisioning and bounded cold-start waiting [step 13/25] | Merged | [#1323](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1323) |
| 14/25 | 🌿 [periodic-cleanup] bridge: fold repeated worktree and Codex algorithms [step 14/25] | Merged | [#1324](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1324) |
| 15/25 | 🌿 [periodic-cleanup] bridge: preserve caught errors and stacks in logs [step 15/25] | Merged | [#1326](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1326) |
| 16/25 | ⚙️ [periodic-cleanup] client: share shell cubit composition [step 16/25] | Merged | [#1328](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1328) |
| 17/25 | ⚙️ [periodic-cleanup] auth: share response and interactive login completion [step 17/25] | Merged | [#1329](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1329) |
| 18/25 | 🌿 [periodic-cleanup] tests: consolidate substantial bridge fixtures [step 18/25] | Merged | [#1330](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1330) |
| 19/25 | 🌿 [periodic-cleanup] tests: consolidate substantial client fixtures [step 19/25] | Merged | [#1331](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1331) |
| 20/25 | 🌿 [periodic-cleanup] tooling: remove verified unused dependencies and symbols [step 20/25] | Merged | [#1333](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1333) |
| 21/25 | 🌿 [periodic-cleanup] docs: simplify repository documentation [step 21/25] | In review | [#1335](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1335) |
| 22/25 | 🌱 [periodic-cleanup] docs: simplify client regression guides [step 22/25] | Proposed | — |
| 23/25 | 🌱 [periodic-cleanup] docs: simplify bridge regression guides [step 23/25] | Proposed | — |
| 24/25 | 🌱 [periodic-cleanup] docs: reconcile cleanup regression coverage [step 24/25] | Proposed | — |
| 25/25 | 🌿 [periodic-cleanup] verify: run coverage and retire the plan [step 25/25] | Proposed | — |

## Evidence and execution

- Initial audit commit: `1508f3bce`; first pass was structural/source inspection.
- Deeper pass: three failing diagnostics against unchanged production code,
  plus one passing nearby refresh test. See [evidence](evidence/README.md).
  Test sources restored; no production change delivered in this PR.
- Architecture plan review (2026-09-04): initial proposal **Rejected**, pre-review
  gate passed. Three findings corrected directly, without claiming re-approval:
  (1) reconcile before/live/fetched messages before consuming staleness;
  (2) produce app-owned normalized message/status values before Layer-4 SSE,
  with repository conversion and no new SSE-to-repository mapper imports;
  (3) inject an explicit core temporary-directory platform interface with shell
  adapters, not a loader callback. No additional mutable-state machinery added.
  The corrected version has not been re-reviewed, following repository rules.
- Original consolidated validation: 55 relative links resolve; all 25 exact titles and
  scope rows agree; all 17 source-step dispositions are recorded; whitespace passes.
  Diagnostic source files were restored; evidence patches were unchanged at
  consolidation. The later PR-feedback diagnostic revision is recorded below.
- Implementation tests, live-plugin/platform retirement matrix: not run.
- Scope decision: accepted 2026-09-05 (see authority line), including the
  unversioned reconciliation limits recorded in step 3.
- Existing refresh diagnostic plan: linked handoff, not falsely retired.
- Retirement: not eligible; requires all recorded matrix rows to pass.

## Consolidation update — 2026-09-04

- #1296 reviewed at `c7f35a5c7936ac3cc1b9ed7399b7b81436c8253a`; useful
  work is now owned by the steps above. #1296 was closed after the consolidated
  update was pushed to #1295.
- #1294 verified merged as `da2e9eeb47`; selection cleanup is externally
  completed. No variant or calculator rewrite remains in this series.
- Eleven additional steps adopted, three overlapping refactors consolidated,
  and policy-dependent/low-benefit ideas retained with explicit dispositions.
- Architecture plan review of the material consolidation (2026-09-04):
  **Approved**, pre-review gate passed; B-Client and B-Bridge applied, public
  shared wire contracts unchanged. No new findings or corrections required.
- Original retirement matrix retained and expanded for adopted work.
- Latest user steering: audit root/package/general docs and simplify every
  regression guide, removing pointless content. Steps 21–24 own this broader
  pass; historical deletion is only one part.

## PR feedback corrections — 2026-09-04

- Initial buffer correction used completed-message timestamps; the subsequent
  loader inspection below supersedes that unreliable predicate.
- Move transcript merge policy to a service-layer calculator and normalized
  event values to repository models. Core DI registers shared native storage;
  shell modules bind only the platform provider.
- Installer/provision services keep injected constructors. One explicit runtime
  composition owner builds both graphs, preserving all seven plugins' inputs.
- Preserve directory-client failure/retry tests, defer pruning without weakening
  its awaited budget contract, and update feature docs in behavior-changing PRs.
- Correct the merged refresh PR states and superseded trigger/options proposals;
  required live observation remains pending. Repair the verification table.
- Replace the streaming diagnostic's fixed delay with an observed delta-flush
  predicate. The final assertion still distinguishes `after` from `before-after`.
- These valid PR findings were applied directly, without claiming that the
  previously approved plan review covered this revised text.
- Validation: 61 relative links, all 25 exact titles, and the contiguous 13-row
  verification matrix pass. Revised delta diagnostic reproduces expected
  `before-after`, actual `after` without a fixed delay; test source restored.

## Follow-up PR feedback — 2026-09-04

- Confirmed Codex/Pi/Claude history omits completion timestamps and that Codex
  emits the shared MCP-tools event. Corrected the actual producer/loader scope.
- Step 2 uses exact content coverage for text/reasoning and seeds the next
  accumulator from installed content. No inferred finality or extra state;
  explicit divergent-history limitation retained. Its buffer-contract change
  raises the planned title to moderate complexity and its estimate to 200–400.
- Step 3 derives assistant metadata and selection inputs after reconciliation,
  using effective options catalogs. Step 9 includes Codex suppression/tests and
  now has a plugins-scoped title; the denominator remains 25.
- Named the source and destination of the temporary-directory test move and
  preserved the grouped-snapshot option's transcript handoff/other-group deferral.
- Valid review corrections applied directly; no claim of another architecture
  approval or newly executed product tests. Prior diagnostic evidence is unchanged.
- Validation: all 63 relative links, 25 exact titles, the contiguous 13-row
  verification matrix and Git whitespace checks pass.

## Step 2 execution — 2026-09-05

- Refresh retires a streaming accumulator only when the fetched same-ID
  text/reasoning part starts or ends with the whole buffered value; otherwise
  the buffer survives. The suffix case covers a tail-only accumulator after a
  reconnect outside the replay window (PR review finding). `appendDelta` takes a lazy base-text lookup so a new accumulator
  seeds once from the installed part. `StreamingTextBuffer.clear` had no
  remaining production caller and was removed.
- Both audit diagnostics are promoted as cubit tests, parameterized over text and
  reasoning with `completed: null` assistant messages: covering, extending,
  shorter/absent, divergent, and final-part-during-reload cases.
- Not added: per-harness Codex/Pi/Claude history fixtures in the client suite.
  The cubit reads no harness-specific field; the null-completion assistant
  fixture is the whole boundary it observes. Recorded here for step 25's matrix.

## Step 5 execution — 2026-09-05

- Schema 15 rebuilds the options-cache table without the completeness column
  through a Drift `TableMigration` (SQL column copy, no enum deserialization).
  Entry, DAO row, and service commit lose the field; capture-time
  `_canReplace` is unchanged. `SessionOptionsCacheDecodingException.revision`
  is non-null and the pre-row ArgumentError conversion plus unknown-revision
  retry branch are gone. Recovery log names plugin and revision only, keeping
  the payload-bearing cause off the log as the existing privacy test requires.
- Migration test upgrades a v14 row whose stored completeness is `unknown`,
  verifies the column is dropped, rows and the project cascade survive.
- Line split, measured at PR head `74a8c616d1` against merge base `338c9b8cb9`
  (`git diff --numstat 338c9b8cb9..74a8c616d1`, classifying paths matching
  `drift_schemas/`, `.g.dart`, `.steps.dart`, or `test/drift/default/generated/`
  as generated): total 5466+/313- = generated 5224+/100- + handwritten
  242+/213-. Self-inclusive: the handwritten figure counts this tracker note as
  it stood at that head; this sentence adds a few lines more. Generators:
  build_runner, drift_dev schema dump/steps/generate.

## Step 6 execution — 2026-09-05

- `BridgeSseSessionStatus.status` is a `PluginSessionStatus`; every producer
  (ACP shared tracker and plugin, Claude, Codex, OpenCode, Pi) emits the typed
  value. OpenCode drops a status kind it does not recognise at the plugin
  boundary instead of relaying an unparseable payload.
- New `NormalizedBridgeEvent` sealed payload under `repositories/models/`:
  status, other, and terminal-handoff (payload non-handoff by type).
  `SessionEventMapper.normalize` is the single conversion, exposed through
  `SessionEventService.toNormalized` and applied by the dispatcher after the
  publication/generation checks. Orchestrator delivers status through
  `BridgeEventMapper.buildSessionStatusEvent`; the history listener ignores
  status and handoff payloads. The message variant follows in step 7.

## Step 7 execution — 2026-09-05

- `BridgeSseMessageUpdated.info` is a `PluginMessage`; ACP, Claude, Codex,
  OpenCode and Pi emit typed envelopes (ACP and Codex stop building shared
  messages internally). OpenCode drops an unknown message role at the plugin
  boundary instead of relaying a raw payload.
- `NormalizedMessageEvent` joins the normalized payload; the mapper converts
  once through `toSharedMessage`, the orchestrator delivers it through
  `BridgeEventMapper.buildMessageUpdatedEvent`, and the history listener stores
  the same shared value with no decode/drop branch.
- The residual session parse-failure log names the event type, error and stack
  without dumping the payload. Failure-reporter failures are logged instead of
  swallowed in the mapper, orchestrator and SSE manager.

## Step 8 execution — 2026-09-05

- `SessionDao.getSessionIdsByBackendIds` projects backend id and stable id for
  one plugin's requested ids; `SessionRepository.getSessionIdsByBackendIds`
  returns `Map<String, String>` and both consumers (event translation, subtask
  child remapping) use it. Full-record reads keep their existing callers.
- `ProjectsDao.getActivityTimestamps` projects id and both activity columns for
  requested ids; `ProjectRepository.getActivities` maps those rows without
  `getAllProjects()`. Unused `getActivity` deleted. Empty inputs return empty at
  the DAO. Real SQLite tests cover plugin isolation with a shared backend id,
  missing ids, empty input and timestamp values.

## Step 9 execution — 2026-09-05

- Consumer check before deletion: no client revision in Git history ever
  destructured, case-handled or type-checked any of the fifteen `Sesori*`
  variants; every public release through v1.8.2 routes them to no-op lists.
  The shared decoders and client ignore-list entries for the fourteen dropped
  kinds were removed after the user's PR review (see the correction below).
- Fourteen `BridgeSseEvent` variants are deleted with their identity and wire
  mapping arms; the remaining union stays exhaustively handled. OpenCode maps
  the matching `SseEventData` kinds to null at its boundary; Codex no longer
  forwards `mcpServer/startupStatus/updated` (mapper test asserts no event).
  `skills/changed` catalog invalidation is retained.
- Correction during PR review: `installation.update-available` was listed in
  audit D3 but the bridge push builder consumes it for the documented
  immediate installation-update notification, so that bridge and shared
  variant are retained. Per the user's PR comment the other fourteen shared
  `SesoriSseEvent` variants are deleted too; a newer client already ignores an
  unknown event type from an older bridge, so the compatibility rule holds.

## Step 10 execution — 2026-09-05

- Core owns `FileAttachmentThumbnailStorage` and `TemporaryDirectoryClient`
  under `foundation/io/`, registered once by core DI; the required platform
  capability `TemporaryDirectoryProvider` lives in `foundation/platform/`. Each
  shell binds one thin path_provider adapter (`@LazySingleton(as:)` on the
  adapter class, no RegisterModule getter needed). The mobile recording
  provider stays lazy and consumes core's client.
- Deleted both shell storage/client copies, their static active-path
  registries and opportunistic temp-file sweeping; metadata reads skip
  temporary files. The client suite moved to
  `client/module_core/test/foundation/io/` with a required-provider fake and no
  test-only constructor; the storage suite moved beside it. Shell DI tests
  assert only the adapter binding.

## Step 11 execution — 2026-09-05

- `client/module_core/lib/src/cubits/shared/optimistic_rename_tracker.dart`
  owns the pending-token/visible/confirmed algorithm; `SessionListCubit` and
  `ProjectListCubit` instantiate one per entity in place of their private
  copies and keep entity maps, repository calls, refresh and projection. Unit
  tests cover newest-success confirmation, fallback after a failed visible
  rename, newer-confirmation precedence and a null original; both cubit rename
  suites pass unchanged.

## Step 12 execution — 2026-09-05

- Stateless `ManagedRuntimeComposition.createInstaller` in
  `sesori_plugin_runtime/lib/src/composition/` builds the checksum, extractor,
  installer and cleaner graph from a descriptor's manifest, executor, download
  client, version validator and asset resolver, returning
  `ManagedRuntimeInstallService` through its unchanged constructor. Codex,
  OpenCode, Copilot, Cursor, Pi, OMP and DeepSeek call it; each keeps its
  operation-local HTTP client and finally-close, executor limits and Windows
  shell policy, probe timeout, validator and asset resolver (OMP's dynamic
  Linux resolution included). Existing runtime and descriptor suites pass.

## Step 13 execution — 2026-09-05

- `ManagedRuntimeComposition.createProvisioner` builds the selection service and
  inventory from a descriptor's manifest, version validator and fallback
  candidates; all seven managed descriptors use it and keep their probes,
  explicit-bin short-circuits, fallback ordering and version policy.
- `ManagedRuntimeColdStartService` (immutable budget and log tag) owns the
  bounded initialize wait, connected/degraded report and post-budget failure
  sink for Codex and OpenCode with one invocation-local `budgetExceeded`.
  Descriptors keep API creation, OpenCode's condition for waiting at all, and
  the unconditional abort-rollback check. Unit tests cover completion, failure
  and budget exhaustion with a late failure; descriptor suites pass unchanged.

## Step 14 execution — 2026-09-05

- `WorktreeService.create`: both candidate loops share one attempt helper that
  returns taken / failed / created; the slug loop moves on after a failed
  creation while the suffix loop still stops after one, and collision checks,
  candidate order, bounds and fallback outcome are unchanged.
- `CodexSessionService`: `_prepareTurn` resumes when needed and derives model,
  mode and effort once; `startTurn` and `sendCommand` keep exactly one forced
  resume retry on `CodexThreadNotFoundException`, recompute through it, and
  retain their different arguments and result shapes.
- Rollout tool mapper: one `_JsLexicalState` owns the string/comment cursor
  advance used by both scanners; quoted escapes and line/block comments are
  handled identically. Owning suites pass unchanged; no new tests were needed.

## Step 15 execution — 2026-09-05

- Recount after steps 7/13/14: 72 log lines interpolate an error or stack.
  Changed 36 recovered-failure sites across the orchestrator, debug server,
  SSE manager/mapper, runtime runner, device detection, host process service,
  worktree repository, push, diagnostics, git CLI, Codex client/descriptor and
  OpenCode service/tracker/SSE/descriptor to pass the typed error and stack
  through the logger's arguments, capturing the stack where the catch lacked it.
- Left as-is: `Log.d`/`Log.v` sites (the logger takes no error there and they
  are expected, ignored failures), deliberately redacted Claude/Codex frame
  logs, terminal `Log.e("$error")` exits the GUI reads, and exception messages
  built from a cause (out of this step's scope). No new logging category.

## Step 16 execution — 2026-09-05

- `client/module_core/lib/src/di/cubit_composition.dart` exports four named
  functions (`createSessionDetailCubit`, `createProjectListCubit`,
  `createSessionListCubit`, `createNewSessionCubit`) taking a required `GetIt`
  locator plus runtime ids and returning a fresh cubit with the collaborators
  both shells resolved. All eight shell sites call them inside their existing
  `BlocProvider(create:)`; route ids, disposal and surface presentation stay in
  the shells, and the session-activity analytics owners remain separate. No
  GetIt import in cubits, no singleton, static locator or wrapper widget.

## Step 17 execution — 2026-09-05

- `HttpApiClient._toApiResponse` is the single response-to-`ApiResponse` branch
  for ordinary and multipart requests: non-2xx keeps status and raw body, an
  empty 2xx body reaches `fromJson(null)`, and a decode/parse failure logs the
  typed `_JsonResponseParsingException` under the per-operation label before
  returning `ApiError.jsonParsing`. `AuthManager._completeInteractiveLogin`
  takes the captured generation and parsed `AuthLoginResponse`, runs the
  existing `_persistAuthenticatedResult` call (OAuth state cleared, no OAuth
  ownership) and returns `AuthLoginResult`; email keeps its own request, 401
  message and validation, Apple its own request. The shared parse now throws the
  file-local `_AuthResponseParsingException(innerError:)` whose presentation
  names only the cause type, replacing the string-only wrapping. OAuth polling
  and token refresh are untouched.

## Step 18 execution — 2026-09-05

- Two bridge fixture clusters consolidated, both test-only and deletion-heavy:
  `active_session_tracker_test.dart` now builds its 75 `Project` and 15
  `Session` values through the package's existing
  `openCodeProject`/`openCodeSession` fixtures instead of repeating the full
  literals, keeping every id, worktree, sandbox, parent and title the cases
  assert on; `git_remote_api_test.dart` drops its duplicate `FakeProcessRunner`
  and `Invocation` for the shared `helpers/fake_process_runner.dart`
  `RecordingProcessRunner`, and folds its thirteen identical `GitCliApi(...)
  .hasGitHubRemote(...)` constructions into one file-local `_hasGitHubRemote`
  builder.
- Line split, measured at the squashed commit `7a396d1fc8` on `main`
  (`git diff --numstat 7a396d1fc8~1..7a396d1fc8 -- \
  bridge/sesori_plugin_opencode/test/active_session_tracker_test.dart \
  bridge/app/test/bridge/api/git_remote_api_test.dart`): 81+/930- and 48+/222-,
  so 129+/1,152- across the two suites, excluding the tracker note in the same
  commit.
- Retained deliberately: the `Session`/`GlobalSession` literals in
  `opencode_repository_test.dart` and `opencode_service_test.dart` (needs a
  nullable-title fixture and a new global-session fixture), the
  `CreateSessionRequest` literals in the session creation and handler suites,
  the `createTestDatabase` + `singlePluginSessionRepository` harness in
  `session_repository_test.dart`, the repeated insert blocks in
  `session_unseen_service_test.dart` and the `get_session_diffs` handler suites,
  and the remaining duplicated `ProcessRunner`, `_FakeSessionRepository` and
  `_FakeBridgePlugin` fakes. Each is a real cluster, but folding them here would
  have doubled this PR past its size budget without making the two clusters
  above any clearer.

## Step 19 execution — 2026-09-05

- Two client session-detail suites gain a group-local `buildCubit` builder and
  drop their repeated 14-line `SessionDetailCubit(...)` constructions.
  `session_detail_cubit_test.dart` folds 47 copies, whose only differences were
  the session/project viewing services and the lifecycle source, and
  `session_detail_stale_test.dart` folds 21 copies differing only in the
  lifecycle source and the refresh cooldown. The stale builder defaults
  `eventRefreshMinInterval` to the production five seconds, so the twelve cases
  that omitted it keep their exact behavior, and the nine coalescing cases still
  name the short test cooldown.
- Line split, measured at PR head `e6cb5b1132` against merge base `7a396d1fc8`
  (`git diff --numstat 7a396d1fc8..e6cb5b1132 -- \
  client/module_core/test/cubits/session_detail/session_detail_cubit_test.dart \
  client/module_core/test/cubits/session_detail/session_detail_stale_test.dart`):
  71+/690- and 45+/324-, so 116+/1,014- across the two suites. The path filter
  makes the figure self-exclusive: it counts neither this tracker note nor the
  later fix commits on the branch.
- Retained deliberately: the single case in `session_detail_cubit_test.dart` that
  passes `notificationCanceller: null` keeps its explicit construction, because
  that null is the behavior under test rather than shared setup. The auth,
  new-session and project-tile suites named in the plan were left alone; their
  repeated setup is smaller and already goes through existing stub helpers, so
  folding it here would have pushed this PR past its size budget without making
  those suites clearer.

## Step 20 execution — 2026-09-05

- Every candidate re-verified against implementation main before deletion; each
  named symbol and key appeared only in its own defining file (plus generated
  localization) with no consumer in production, test, generated or tool code.
- Dependencies removed: `re_highlight`, `fake_async` and `json_annotation` from
  `client/app` (the highlighter is used only by `module_app_ui`, which keeps its
  own declaration); `cupertino_icons` from `client/design_catalog`;
  `_fe_analyzer_shared` from `shared/no_slop_linter`; and the annotation and
  generator set (`freezed_annotation`, `json_annotation`, `freezed`,
  `json_serializable`, `build_runner`) plus the now-inert `build.yaml` from
  `bridge/sesori_plugin_runtime`, which contains no annotated source and no
  generated file. `sesori_plugin_antigravity` was left to its active series.
- Symbols and keys removed: `currentProjectName` (its whole file), `kStatusGreen`
  and `kStatusPurple` (`kStatusAmber` stays; the session tile uses it), `logwf`,
  `testMultiSseQuestionAsked`, `lerpTextStyleNonNull` and the four localization
  keys `sessionListStaleProjectTitle`, `sessionListStaleProjectMessage`,
  `sessionListStaleProjectBack`, `voiceErrorNetwork`, with localizations
  regenerated from the ARB. Dropping the text-style helper made
  `package:flutter/painting.dart` unnecessary in `lerp_utils.dart`.
- Line split, measured at PR head `18dde01358` against merge base `ee6826dbc1`
  (`git diff --numstat ee6826dbc1..18dde01358 -- . ':(exclude).plan'`):
  4+/137- outside the plan directory, so this step is almost entirely deletion.
- The narrow repository methods from step 4 remain their own finding; this scan
  did not revisit them.

## Step 21 execution — 2026-09-05

- Completion verified before every deletion. `docs/parallel-plugins/PLAN.md`
  ("complete", merged through PR #497), `CONSIDERATIONS.md` (historical audit
  reconciled through Stage 9) and `docs/codex-plugin-stability-report.md`
  (matrix and F-12 follow-up complete) are removed; git history retains them and
  no doc outside `.plan/` linked to them. The Stage 1a/9 baseline JSON artifacts
  go with the plan that was their only consumer.
- `docs/parallel-plugins/ARCHITECTURE.md` was durable, not historical, so its
  current content moved into `docs/ARCHITECTURE.md` as "Catalog ownership and
  the plugin boundary": the ownership decision and boundary lists, update
  semantics including child ancestry and import-not-sync, identity, and parallel
  runtime behavior. Stage numbering, the performance gate, the schema-v11
  migration history and the completion evidence were dropped with the plan.
- `docs/plans/auth-reconnect-ux-plan.md` was **not** deleted. Its status tracker
  shows PRs 4-7 and the deferred bridge-offline recovery item not started, so it
  is a live plan, not a completed report. The plan's candidate list assumed
  completion; execution disproved it.
- `docs/cursor-acp-followups/README.md` keeps only its two genuinely open items
  (D1 plan-mode rejection routing, blocked on a live trace; Theme E typed ACP
  boundary DTOs, deliberately deferred). The nine resolved themes are removed
  rather than kept as status tombstones.
- One authoritative install page: `bridge/INSTALL.md` already documented the
  installers, npm bootstrap, install locations, update track and uninstall in
  full, so the duplicate copies in `bridge/README.md` and `bridge/app/README.md`
  became links to it. `bridge/README.md`'s catalog section now links to the
  architecture page instead of restating the import endpoints, and keeps the
  operational CLI detail that is genuinely its own.
- `docs/cleanup-audit-2026-09-04.md` keeps its findings and its stated baseline
  commit; a one-line note records that some of its file references no longer
  resolve because this series has since executed them. The README/GETTING_STARTED
  overlap was left alone: the README's three-step summary is a landing page that
  already links to the full walkthrough.
- Link check across every tracked Markdown file outside `.plan/` and
  `.opencode/`: no broken relative link remains.
- Title kept from this tracker; the planned 🌱 became 🌿 because review has to
  confirm each deleted report was complete and that the architecture
  consolidation preserved the durable content.
- Line split. Both commands run as written and are stable across later
  tracker-only commits, because each pathspec excludes this file:
  `git diff --numstat b57d30c770..28680774f3 -- '*.md' ':(exclude).plan'` gives
  125+/3,560- of documentation prose, and
  `git diff --numstat b57d30c770..28680774f3 -- '*.json'` gives 0+/8,057- of
  retired baseline artifacts. `28680774f3` is the last commit on this branch that
  changed either; substituting any later head leaves both figures unchanged. The
  prose figure is within the step's deletion-heavy allowance, and the JSON is a
  measurement artifact rather than prose. No self-inclusive total is recorded:
  writing one changes the head it would have to be measured at.
- Correction applied during review: the parallel-runtime paragraph carried over
  from the retired document described a `--plugin <id>` flag and persisted
  `enabledPlugins` ordering. Neither exists. The section now states the
  implemented rule — the `plugins.disabled` denylist, case-insensitive
  display-name ordering tie-broken by id, OpenCode preferred as the default when
  selectable, and per-plugin `--<pluginId>-<name>` options — matching
  `plugin_lifecycle_service.dart`, `plugin_registry.dart` and
  `plugin_cli_options_mapper.dart`.
