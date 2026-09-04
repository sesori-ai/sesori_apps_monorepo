# Codebase Cleanup 2: Second Reliability And Maintainability Series

## Status

- **Plan slug:** `codebase-cleanup-2`
- **Status:** Active — Step 1/17 (this plan)
- **Plan date:** 2026-09-04
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at `480d82f090` (product version
  1.8.3; latest public release v1.8.2, 2026-08-28)
- **Predecessor:** `codebase-cleanup` (45 steps, retired 2026-08-25, artifacts
  removed in PR #1121). Its decisions that still bind are restated below; its
  audit numbers are not reused.
- **Delivery:** 17 numbered PRs. Step 16 reconciles `docs/regression/`, Step 17
  runs the recorded matrix and retires the plan.

This plan and `TRACKER.md` are the authority for the series. The code remains
authoritative where this document becomes stale: line references below are
from the implementation base, the repository merges many PRs a day, and every
step re-verifies its evidence before editing and records the delta in its own
`steps/step-NN.md`.

## Goal

Make the system we already have smaller, simpler, and harder to break, without
shipping product behavior:

- delete the duplication that grew back or was left behind since the first
  series (the desktop shell, sub-agent sessions, plugin warm-ups, session
  options announcements, and seven new managed-runtime descriptors all landed
  in the last four weeks);
- replace coordination machinery that defends interleavings no ordinary flow
  produces with fewer, honest mutable parts;
- retire compatibility paths whose public peers are no longer supported;
- leave diagnostics intact: every caught error keeps its stack trace.

Every step is judged by whether the code after it is smaller, simpler, or has
fewer ways to be wrong — never by whether it handles a case no current flow
reaches.

## Non-Goals

- No new product behavior, screens, routes, events, or settings.
- No abstraction that does not replace at least two existing copies and own
  state, a lifecycle, or an invariant.
- No rewrite of `Orchestrator`, `PluginRuntime`, `SessionOptionsService`,
  `ConnectionService`, `RelayClient`, the event dispatchers, or the plugin tool
  trackers. Their internals were re-audited (field census below) and carry no
  removable duplication; their coordination exists for observed flows.
- `SessionDetailCubit` refresh, connection, and lifecycle coordination stays
  owned by the active `session-refresh-reconnects` plan, whose Step 3 will
  decide its own sealed-state refactor from diagnostic evidence.
- No compatibility removal outside Step 7 and Decision D1.
- No wire, database, or schema change outside Step 7.
- Files still owned by an active series are not touched: `sesori_plugin_
  antigravity` (antigravity-harness, Steps 5–12 pending), the desktop attention
  service until `desktop-app` retires (Step 11 is gated on it), Pi command
  availability (PRs #1271, #1268, #1237), chat tool payloads (#1221).
- `no_slop_linter` parity for `bridge/app` and the large plugin packages
  remains declined: roughly 1,800 mechanical `prefer_specific_type` and
  `prefer_required_named_parameters` edits with no reliability gain.

## Investigation Summary

Nine targeted audits covered the bridge app, the native plugins, the ACP
family, `module_core`/`module_auth`, the Flutter shells and `module_app_ui`,
Prego/shared/tooling, the test suites, compatibility markers, and repo-wide
mechanical smells. Mechanical scans (normalized sliding-window duplicate
detection over every non-generated Dart file, a single-pass dead top-level
symbol census, a pubspec dependency census, an ARB key census, a fake-class
body census) were run over the whole tree; every claim below was then verified
by reading the code.

Baseline facts at `480d82f090`:

- Non-generated production Dart: bridge ≈ 119k lines, client ≈ 87k, shared
  ≈ 8k. Tests ≈ 285k lines (bridge 176k, client 100k, shared 9k) — the test
  corpus is now a third larger than the production corpus.
- Since the first series retired, 1,073 Dart files changed (+78,912 / −11,516
  lines): `client/module_app_ui` was created and the desktop shell was built;
  `client/app` shrank to a 6.9k-line shell.
- **Verbatim production duplication is modest**: 59 blocks of ≥14 normalized
  lines, ≈1,100 lines total. It concentrates in five clusters: managed-runtime
  install composition repeated in seven plugin descriptors; the budgeted
  cold-start block duplicated in the Codex and OpenCode descriptors; eight
  Flutter platform adapters duplicated between `client/app` and
  `client/desktop`; the session/project view trackers and three pairs of
  bridge listeners; and the optimistic rename state machine duplicated between
  the project and session list cubits.
- **Test duplication is large**: 134 repeated blocks of ≥25 normalized lines
  (≈4,000 lines) inside a dozen files, plus 353 fake declarations for 218
  names in bridge tests and 410 for 206 names in client tests (13 and 71
  groups respectively are byte-identical bodies).
- 81 `COMPATIBILITY` markers. The first series fixed the baseline at public
  `≥ v1.4.0` on 2026-08-22. Public releases since: v1.5.0–v1.5.2 (2026-07-13 to
  07-18), v1.6.0 (07-24), v1.7.0/v1.7.1 (08-05/08-09), v1.8.0–v1.8.2
  (08-20 to 08-28).
- 53 bridge log sites interpolate a caught error into the message
  (`Log.w("…: $e")`, `Log.e("$error")`), discarding the stack trace the
  repository rules require as a logger argument.
- Dead top-level public symbols: 6. Unused ARB keys: 4 of 584. Unused
  dependency declarations: `re_highlight` (client/app; used only by
  `module_app_ui`), `cupertino_icons` (design_catalog), `fake_async`
  (client/app dev), `freezed_annotation` (sesori_plugin_runtime),
  `_fe_analyzer_shared` (no_slop_linter), and a direct `json_annotation`
  dependency in fourteen packages that only ever import it through
  `freezed_annotation`.
- `dart analyze --fatal-infos` is clean for `bridge/app` including
  `tool/benchmarks`.

What the audits did **not** find, recorded so no later session re-hunts it:
no real-duration sleeps returned to the tests; the `PendingOperations`,
`KeyedParallelLock`, `AbortableRequestClient`, `PendingPermissionRegistry`, and
`NdjsonProcessClient` primitives each still have exactly one implementation;
the runtime manifests are per-plugin data tables over one shared
`RuntimeManifest` base (not duplication); the five exhaustive `SesoriSseEvent`
ignore-lists in `module_core` are enforced by the repository's own
`prefer_exhaustive_switch` lint and stay.

## Principles For Every Step

- Behavior-preserving by default. Steps 4, 7, 10, and 11 intentionally change
  observable behavior or contracts; they say so in their PR bodies and update
  the affected `docs/regression/` document in the same PR. Step 16 is the
  consistency pass, not the first place a change is documented.
- Delete before you add. A shared primitive must replace at least two copies
  and own state, a lifecycle, or an invariant. None is introduced for file
  length or "for later".
- Re-verify before editing. Each step greps its claims against current `main`,
  drops what has moved on, and records the delta in its own `steps/step-NN.md`.
  No step edits another step's file or `TRACKER.md` for bookkeeping.
- One area per PR under the 1,500 changed-line soft cap (additions plus
  deletions, generated code and tests included). Deletion-heavy steps may
  exceed it with the reason recorded in the step file.
- Each PR runs the owning package's focused tests plus `dart analyze
  --fatal-infos` (`flutter analyze` for Flutter packages); shared-module
  changes also validate the downstream shells. CI runs the full matrix.
- Architecture-implementation review, through a sub-agent, only for steps that
  add or move production classes, change DI ownership, or touch shared or wire
  contracts: Steps 2, 3, 4, 7, 8, 9, 10, 11. Pure deletions, in-file folds,
  logging, docs, tooling, and test-only steps skip it. At most two review
  passes per step before asking the owner.
- Keep recovered failures observable: no consolidation drops a log that was the
  only trace of an error; Step 6 adds the error and stack as logger arguments
  rather than removing text.
- Test consolidation uses `implements`/subclass fakes only; assertions are
  never rewritten to fit a shared fake or helper.

## Open Decisions

Each decision has a default so execution never blocks. The owner can override
any of them in the Step 1 PR review or later in `TRACKER.md`.

- **D1 — Minimum supported public peer (gates Step 7).** *Default:*
  `≥ v1.6.0` (public 2026-07-24). This mirrors the first series, which chose a
  six-week-old release as its floor on 2026-08-22. It retires every marker
  dated `≤ v1.6.0` whose peer is a released Sesori surface: the
  `legacyMissingPluginId` defaults on `Session`, `CreateSessionRequest`, and
  `PluginProjectIdRequest`; the `Project` path/time/unseen/directory-missing/
  worktree-capability defaults and the `path ← id` decode fallback;
  `OpenProjectRequest.gitAction`; `SessionStatusResponse.unavailablePluginIds`;
  `Session.pullRequestHistory`; the nullable `SesoriProjectUpdated` payload;
  the `project_tile.dart` null-time branch; and the client discovery fallback
  for bridges without plugin attribution. Markers whose peer is a backend or
  on-disk format (Codex rollouts and persisted collaboration modes, OpenCode
  `session.idle`, auth servers returning 404/405) stay regardless of age.
  *Alternative:* `≥ v1.7.0` (2026-08-05) additionally retires the v1.6.1
  markers (`session_catalog_mapper.dart`, `get_sessions_handler.dart:64`,
  `message_part.dart:316` attachments). Accepted consequence of either: a
  client or bridge below the floor fails to decode the now-required fields
  and must update.
- **D2 — Identical Flutter platform adapters live once in `module_app_ui`
  (Step 8).** *Default:* yes. `client/AGENTS.md` currently assigns all
  platform adapters to the shells; the step rewrites that sentence to "shells
  own DI registration and surface-specific adapters; adapters whose
  implementation is identical on every surface live once in
  `module_app_ui/lib/src/platform/`". The `module_app_ui` package gains the
  `file_selector`, `pasteboard`, `path_provider`, and `share_plus`
  dependencies that those adapters wrap.
- **D3 — Paired bridge listeners merge into one owner per concern (Step 4).**
  *Default:* yes. `bridge/app/AGENTS.md` says each listener "owns one trigger's
  subscription/timer lifecycle"; the three pairs below share every
  collaborator and body and differ only by trigger stream. The step rewrites
  the rule to "one concern per listener; a listener may subscribe to every
  trigger of that concern through one `CompositeSubscription`". If declined,
  Step 4 records the decision in its step file and closes without a code
  change.
- **D4 — Historical documents outside `.plan/` are deleted (Step 15).**
  *Default:* delete `docs/codex-plugin-stability-report.md` (a finished
  2026-08-04 test report, no inbound references), `docs/cursor-acp-followups/`
  (a 2026-07-11 deferred-follow-ups tracker for PR #332, no inbound
  references), `docs/plans/auth-reconnect-ux-plan.md` (a July plan kept
  outside the plan directory), and `docs/parallel-plugins/PLAN.md`,
  `CONSIDERATIONS.md`, and `baselines/` (complete since PR #497). Keep
  `docs/parallel-plugins/ARCHITECTURE.md` only if `docs/ARCHITECTURE.md` does
  not already carry its durable content; otherwise fold and delete it too.
- **D5 — Reverse the first series' "install composition stays local"
  (Step 2).** Step 26 of the predecessor deliberately left the
  `ManagedRuntimeInstallService` composition and `http.Client` ownership in
  each descriptor. Seven verbatim copies now exist. *Default:* share it; the
  shared composition owns the client lifecycle it creates.
- **D6 — Desktop attention reconciler timing (Step 11).** *Default:* Step 11
  starts only after the `desktop-app` plan retires (MT gate C), because the
  owner is exercising that flow now. If `desktop-app` has not retired when
  every other step is merged, Step 11 is recorded as deferred and the series
  retires without it.
- **D7 — Variant availability on the session screen (Step 10).** The two
  derivations disagree: New Session hides a model the backend marks
  `isAvailable: false`, the session screen still offers its variants.
  *Default:* the shared derivation applies the `isAvailable` rule on both
  screens, so an unavailable model offers no variants anywhere. *Alternative:*
  keep offering variants on the session screen (the shared derivation takes an
  explicit flag). This is a behavior decision, recorded separately from the
  deduplication so it is not folded in silently.

## Delivery Plan

Fixed titles, complexity, and order. Targets are changed lines (additions plus
deletions, generated code and tests included). Steps whose files do not
overlap run in parallel (the owner previously asked for up to about five open
PRs); the serialization column names the only hard ordering.

| Step | Exact PR title | Target | After |
|---|---|---:|---|
| 1/17 | `🌱 [codebase-cleanup-2] docs: plan the second reliability cleanup series [step 1/17]` | 900–1,200 | — |
| 2/17 | `⚙️ [codebase-cleanup-2] bridge(runtime, plugins): share managed-runtime composition and the budgeted cold start [step 2/17]` | 600–900 | 1 |
| 3/17 | `⚙️ [codebase-cleanup-2] bridge(app): one connection view tracker for sessions and projects [step 3/17]` | 350–500 | 1 |
| 4/17 | `⚙️ [codebase-cleanup-2] bridge(app): merge the paired listeners into one owner per concern [step 4/17]` | 450–650 | 3 (D3) |
| 5/17 | `🌿 [codebase-cleanup-2] bridge: fold the duplicated worktree, Codex turn, and scanner loops [step 5/17]` | 250–400 | 1 |
| 6/17 | `🌿 [codebase-cleanup-2] bridge: pass caught errors to the logger instead of interpolating them [step 6/17]` | 150–250 | 2, 5 |
| 7/17 | `🚧 [codebase-cleanup-2] compat: retire compatibility paths below the v1.6.0 baseline [step 7/17]` | 700–1,100 | 1 (D1) |
| 8/17 | `⚙️ [codebase-cleanup-2] client: share the identical Flutter platform adapters between the shells [step 8/17]` | 800–1,100 | 1 (D2) |
| 9/17 | `⚙️ [codebase-cleanup-2] client: share session-detail and list screen composition between the shells [step 9/17]` | 400–600 | 1 |
| 10/17 | `⚙️ [codebase-cleanup-2] client(module_core, module_auth): share the rename tracker and variant derivation, fold auth duplicates [step 10/17]` | 350–550 | 1 |
| 11/17 | `🚧 [codebase-cleanup-2] client(module_desktop_core): reconcile desktop attention notifications from one desired state [step 11/17]` | 600–900 | desktop-app retired (D6) |
| 12/17 | `⚙️ [codebase-cleanup-2] tests(bridge): consolidate identical fakes and repeated arrange blocks [step 12/17]` | 1,000–1,500 | 2, 3, 4, 5 |
| 13/17 | `⚙️ [codebase-cleanup-2] tests(client): consolidate shared mocks and repeated arrange blocks [step 13/17]` | 1,000–1,500 | 8, 9, 10 |
| 14/17 | `🌿 [codebase-cleanup-2] tooling: prune unused dependencies, localization keys, and dead symbols [step 14/17]` | 100–200 | 8 |
| 15/17 | `🌱 [codebase-cleanup-2] docs: remove historical documents preserved by git history [step 15/17]` | 3,000–3,500 (deletion) | 1 (D4) |
| 16/17 | `🌱 [codebase-cleanup-2] docs: reconcile regression coverage after the second cleanup [step 16/17]` | 100–300 | 2–15 |
| 17/17 | `🌿 [codebase-cleanup-2] verify: run the recorded matrix and retire the plan [step 17/17]` | 50–150 | 16 |

If D1 is changed from the default, the Step 7 title is updated in
`TRACKER.md` before that PR opens.

## Step Details

### Step 2 — managed-runtime composition and budgeted cold start (D5)

**Evidence.** `ManagedRuntimeInstallService(` is composed identically in
seven descriptors — `codex_plugin_descriptor.dart:276-306`,
`copilot_plugin_descriptor.dart:127-160`, `cursor_plugin_descriptor.dart:200-
232`, `deepseek_plugin_descriptor.dart:107-132`, `omp_plugin_descriptor.dart:
141-175`, `open_code_plugin_descriptor.dart:280-311`, `pi_plugin_descriptor.
dart:158-190`. Each builds its own `HostProcessCommandExecutor`, opens an
`http.Client`, wires `RuntimeVersionValidator`, `RuntimeInstallService`
(`BinaryDownloadClient`, `ChecksumValidator`, `ArchiveExtractor`),
`ManagedRuntimeCleaner`, and an `assetResolver` closure over the manifest, then
closes the client in `finally`. `ManagedRuntimeProvisionService(` +
`ManagedRuntimeSelectionService(` are composed the same way in the same seven
`ensureRuntime` methods, and `HostProcessCommandExecutor(` appears 24 times
across the descriptors. The Codex and OpenCode descriptors also duplicate the
budgeted cold-start sequence (`codex_plugin_descriptor.dart:648-697` and
`open_code_plugin_descriptor.dart:674-725`): `api.initialize()` raced against
`_coldStartBudget`, a post-budget error sink, `reporter.markDegradedNow()` /
`markConnected()`, and the abort-observed rollback through `plugin.shutdown`.

**Change.** In `sesori_plugin_runtime`: one composition owner for installs
(for example `ManagedRuntimeInstallService.forManifest({manifest, processes,
probeTimeout, maxCapturedOutputCharactersPerStream})` whose `install(...)`
owns and closes the `http.Client` it creates) and one for provisioning
(`ManagedRuntimeProvisionService.forManifest(...)`), plus one
`BudgetedColdStart` that owns the budget/degraded/abort-rollback sequence and
takes the plugin tag for its log lines. Each descriptor's `installRuntime`
and `ensureRuntime` collapse to the manifest, the output limit, and the
optional explicit executable path; the two cold-start blocks become one call.
No default-constructed dependencies: descriptors still pass `processes` and
the probe timeout explicitly.

**Not done here.** Per-plugin `inspectSetup` hint text and rejection mapping
stay local (they encode each backend's install story). Claude, Grok, and
Hermes descriptors have no managed install and are untouched. The Antigravity
descriptor is in flight and is excluded.

**Size and risk.** 600–900 lines. Behavior-preserving; no wire or persisted
change. Risk is composition wiring: every managed plugin's setup and install
path must still resolve. Architecture-implementation review required.
Regression documents: `plugin-runtime-installation.md`,
`plugin-setup-and-lifecycle.md`.

### Step 3 — one connection view tracker

**Evidence.** `services/session_view_tracker.dart` (78 lines) and
`services/project_view_tracker.dart` (100 lines) are the same ref-counted
"connection → viewed id" structure: `setViewing`, `releaseConnection`,
`clearAll`, `activeXIds`, viewer counts, and a decrement helper. They differ
only in notification shape (`viewStarts` emits every per-connection start;
`changes` emits an aggregate `ProjectViewChange` with newly added ids), in the
project tracker normalizing empty ids to null, and in the project tracker
carrying a dispose fence. Consumers: `Orchestrator` (write side),
`SessionUnseenService` (`isViewed`, `viewStarts`), the two warm-up listeners,
`ViewedProjectGlossaryListener`, and `ViewedProjectPrRefreshListener`.

**Change.** One `ConnectionViewTracker` in `services/` owning the ref-counted
state and exposing both signals every consumer needs: `starts` (per-connection
start, what `viewStarts` is today) and `changes` (aggregate active set plus
newly added ids). The orchestrator holds two instances (sessions, projects);
`SessionUnseenService` keeps its exact semantics because `starts` is preserved.
Delete both old classes and their tests in favor of one suite.

**Size and risk.** 350–500 lines. Behavior-preserving; the two-client unseen
invariant ("viewed by any connection means not bold for anyone") is covered by
the merged unit suite and re-checked live in Step 17. Architecture review
required.

### Step 4 — paired listeners (D3)

**Evidence.** Three listener pairs in `bridge/app/lib/src/listeners/` share
every collaborator and the same body and differ only by trigger:
`viewed_session_plugin_warmup_listener.dart` (63) / `plugin_warmup_setting_
listener.dart` (65) — same `SessionViewTracker`, `PluginWarmupService`,
`PluginWarmupSettingsService`, same `_warm`, same fences;
`current_project_glossary_listener.dart` (51) / `viewed_project_glossary_
listener.dart` (57) — same `ProjectGlossaryPopulationService`, same
`_populate`; `session_options_creation_refresh_listener.dart` (69) /
`session_options_changed_refresh_listener.dart` (105) — same
`SessionOptionsService`, same outcome switch and logging.

**Change.** One listener per concern — `PluginWarmupListener`,
`ProjectGlossaryListener`, `SessionOptionsRefreshListener` — each subscribing
to its two triggers through one `CompositeSubscription`, one
`PendingOperations`, and one dispose fence. Orchestrator composition wires
three listeners instead of six. `bridge/app/AGENTS.md` and `bridge/AGENTS.md`
"one trigger per listener" wording becomes "one concern per listener".

**Size and risk.** 450–650 lines. Behavior-preserving (same triggers, same
work, same logs). Architecture review required. Regression documents:
`session-creation-and-options.md` (automatic options refresh),
`projects-and-sessions.md` (glossary population on view), `plugin-setup-and-
lifecycle.md` (warm-up on view and on setting change).

### Step 5 — in-file duplicate loops

**Evidence.** `services/worktree_service.dart:225-249` and `261-282` run the
same branch-exists / path-exists / `createWorktree` / `WorktreeSuccess` attempt
body twice (color-animal slugs, then hex-suffixed slugs).
`sesori_plugin_codex/lib/src/services/codex_session_service.dart:500-566`
(`startTurn`) and `568-640` (`sendCommand`) each contain the resume →
`_resolveTurnModel` → `_resolveCollaborationMode` → effort → start block twice
(the try body and the `on CodexThreadNotFoundException` force-resume retry), so
the same 25 lines exist four times.
`sesori_plugin_codex/lib/src/repositories/mappers/codex_rollout_tool_mapper.
dart:693-728` and `822-857` duplicate a string/comment-aware JavaScript scan
loop (quote, escape, line comment, block comment tracking).

**Change.** One private attempt helper fed by a candidate-name iterator in the
worktree service; one `_startResolvedTurn` helper taking the operation
closure in the Codex session service; one scan-cursor helper in the rollout
tool mapper. Pure folds inside the owning classes.

**Size and risk.** 250–400 lines. Behavior-preserving; existing suites cover
all three. No architecture review.

### Step 6 — logger arguments

**Evidence.** 53 bridge sites interpolate a caught error into the message,
including `orchestrator.dart:968,1612,1817,1923-1941,2093`, `debug_server.
dart:219-267`, `sse/sse_manager.dart:193`, `sse/bridge_event_mapper.dart:188,
231`, `runtime/bridge_runtime_runner.dart:479,687,924,938,1275`, `acp_plugin.
dart:721,1375`, and the two cold-start blocks folded in Step 2. Each drops the
stack trace and the typed error.

**Change.** `Log.w(message, error, stackTrace)` / `Log.e(...)` at every site
that continues after a catch-all or recovers; `Log.d` sites keep a message-only
debug line where the exception type is specific and expected, and are promoted
to `Log.w` with the error argument where the catch is a catch-all. No site
loses information.

**Size and risk.** 150–250 lines across bridge packages. Diagnostic-only;
no behavior change. No architecture review. Scheduled after Steps 2 and 5 to
avoid textual conflicts in the same files.

### Step 7 — compatibility retirement (D1)

**Evidence.** Markers dated `≤ v1.6.0` whose peer is a released Sesori
surface (all under `shared/sesori_shared/lib/src/models/sesori/` unless
noted): `project.dart:24,50` (nullable `time`), `:26,55` (`hasUnseenChanges`
default), `:30-34` (`path ← id` decode fallback), `:48` (`path` empty-string
default), `:62` (`directoryMissing` default), `:67`
(`supportsDedicatedWorktrees` default), `:126` (`OpenProjectRequest.gitAction`
default); `session.dart:39` (`pluginId` default), `:47`
(`pullRequestHistory` default); `create_session_request.dart:15` and
`plugin_project_id_request.dart:13` (`pluginId` defaults);
`plugin_identity.dart:20` (`legacyMissingPluginId`, six production usages
including `client/module_core/lib/src/repositories/plugin_repository.dart:179,
195` and the bridge's missing-attribution agent-discovery default);
`session_status.dart:13` (`unavailablePluginIds` default);
`sesori_sse_event.dart:325` (nullable `SesoriProjectUpdated` payload);
`client/module_app_ui/.../project_tile.dart:320` (null-time branch, plus
`project_tile_states_test.dart:213`); `client/module_core/.../plugin_
repository.dart:186` (bridges without plugin attribution).

**Change.** Make each field required or non-defaulted, delete the fallbacks
and their tests, and write one peer-verification line per marker in the step
file stating what the v1.6.0 client or bridge actually sends (checked from the
`v1.6.0` tag). Keep every marker whose peer is a backend or on-disk format:
`codex_config_reader.dart`, `codex_collaboration_mode.dart:23,28,32`
(persisted rows), `codex_rollout_*`, `codex_message_repository.dart:561`,
`pi_event_dispatcher.dart:474` (Pi ≤ 0.84.2), `sse_event_mapper.dart:79` and
`generate_sse_events.dart:189` (OpenCode runtimes), and
`app_client_status_repository.dart:19` (auth servers). Keep every marker
dated `> v1.6.0`, including the `/settings/pull-request-refresh` route, which
the first series recorded as retiring only once both minimum peers exceed
v1.8.0.

**Size and risk.** 700–1,100 lines including generated code and tests. This
is a wire-contract change: peers below the floor stop decoding, which D1
accepts. Architecture review required. Regression documents:
`projects-and-sessions.md`, `session-creation-and-options.md`,
`bridge-connectivity.md`, `pull-request-monitoring.md`.

### Step 8 — shared Flutter platform adapters (D2)

**Evidence.** Eight adapter pairs between `client/app/lib/core/platform/` and
`client/desktop/lib/core/platform/` differ only by class names, collaborator
names, doc comments, or an `@LazySingleton` annotation:
`flutter_attachment_thumbnail_storage.dart` / `desktop_attachment_thumbnail_
storage.dart` (133 lines; one differing log string), `file_save_client.dart` /
`desktop_file_save_client.dart` (19), `flutter_image_clipboard.dart` /
`desktop_image_clipboard.dart` (15), `pasteboard_client.dart` /
`desktop_pasteboard_client.dart` (12), `flutter_image_sharer.dart` /
`desktop_image_sharer.dart` (29), `share_plus_client.dart` /
`desktop_share_client.dart`, `temporary_directory_client.dart` /
`desktop_temporary_directory_client.dart` (desktop lacks only `warmUp`),
`desktop_file_image_saver.dart` (same file name in both shells, identical
body), and `firebase/no_op_analytics_client.dart` / `no_op_analytics_client.
dart` (identical). Their tests are duplicated too (`desktop_file_image_saver_
test.dart` and the thumbnail-storage tests, 60 lines).

**Change.** Move one copy of each into `client/module_app_ui/lib/src/platform/`
(exported from the package barrel), keep `warmUp` on the shared temporary
directory client, delete the twins and twin tests, and leave DI registration in
each shell (an injectable module registering the shared classes). Add the
wrapped plugin dependencies to `module_app_ui`. Rewrite the platform-adapter
ownership sentence in `client/AGENTS.md`.

**Not done here.** Adapters that genuinely differ stay in their shell:
local-notification clients, OAuth device descriptors, lifecycle observers,
secure storage, URL launchers, route dispatchers, composer image pickers.

**Size and risk.** 800–1,100 lines (moves plus deletions). Behavior-preserving;
both surfaces already run this exact code. Architecture review required
(moved production classes, DI ownership). Regression document:
`attachments-and-images.md`.

### Step 9 — shared screen composition

**Evidence.** `client/app/lib/features/session_detail/session_detail_screen.
dart` (167) and `client/desktop/lib/features/sessions/desktop_session_detail_
screen.dart` construct `SessionDetailCubit` with the same thirteen arguments
(eleven `getIt` resolutions plus the ids), wire the same
`SessionDetailPresentationScope` capabilities, and
each implement a private `_SessionActivityAnalyticsOwner` (mobile derives
visibility from `ModalRoute`; desktop additionally subscribes to `RouteSource`
to detect a covering settings route). The project-list, session-list, and
new-session wrappers repeat their cubit construction between shells as well
(`project_list_screen.dart:30-57` vs `desktop_project_list_screen.dart:29-56`,
`session_list_cubit_provider.dart:9-29` vs `desktop_session_list_screen.dart:
11-31`, `new_session_screen.dart:15-28` vs `desktop_new_session_screen.dart:
17-30`).

**Change.** Cubits stay out of DI. Each affected cubit gains one
locator-backed factory in `module_core` (for example
`SessionDetailCubit.fromLocator({required GetIt locator, required sessionId,
required projectId})`) so both shells construct it with one call, and
`module_app_ui` gains one `SessionActivityAnalyticsOwner` widget whose
route-visibility policy is an injected callback (mobile passes the `ModalRoute`
check; desktop passes the covered-by-settings check). Delete the two private
owners and the repeated argument lists.

**Size and risk.** 400–600 lines. Behavior-preserving. Architecture review
required (composition seam). Regression documents: `analytics.md` (session
activity events), `projects-and-sessions.md`.

### Step 10 — rename tracker, variant derivation, and auth client folds

**Evidence.** `_ProjectRenameState` (`project_list_cubit.dart:44-92`) and
`_SessionRenameState` (`session_list_cubit.dart:35-83`) are identical modulo
`name`/`title`; `renameProject` (`:706-800`) and `renameSession` (`:469-560`)
run the same token / optimistic apply / bridge call / restore-on-failure flow
with the same `_renameStateBy…Id` map and `_nextRenameToken` counter (added by
PR #1281 on 2026-09-03). `client/module_auth/lib/src/client/http_api_client.
dart:176-207` and `:255-286` map an `http.Response` to `ApiResponse`
identically; `auth_manager.dart:686-756` repeats the decode → parse →
`_persistAuthenticatedResult` → `AuthLoginResult` block in `loginWithEmail` and
`loginWithApple` (a third parse-and-rethrow block at `:862`). Model-variant
derivation exists twice with divergent rules: `new_session_options_service.
dart:433-460` (`availableVariants`, `_validatedModel`) drops a model whose
provider entry is missing or `!isAvailable`, while `session_detail_cubit.dart:
2422-2440` (`_deriveAvailableVariants`, `_withResolvedVariant`) applies the
same `"none"` filter and first-variant fallback but never checks
`isAvailable`, so an unavailable model still offers variants on the detail
screen (recorded as drift after PR #1282).

**Change.** One `OptimisticRenameTracker` (module_core, owning the token,
visible, and confirmed values and the settle rule) used by both cubits; one
pure variant/availability derivation in module_core used by both the
new-session options service and the session-detail cubit (the detail screen
adopts the `isAvailable` rule under D7 — the one intentional behavior change
in this step); one response-mapping helper in the auth HTTP client; one
`_completeLogin` in `AuthManager`. Delete the private copies.

**Size and risk.** 350–600 lines. Behavior-preserving except the stated
alignment; rename, options, and login suites already exist. Architecture
review required (new production class). Regression documents:
`projects-and-sessions.md` (rename), `session-creation-and-options.md`
(variant availability), `account-and-onboarding.md` (login).

### Step 11 — desktop attention reconciler (D6)

**Evidence.** `client/module_desktop_core/lib/src/services/desktop_attention_
service.dart` (605 lines, merged 2026-09-03) coordinates one product fact —
"a pending permission or question for a session while the window is not
focused shows one native notification; resolving it cancels" — through twenty
mutable fields: a per-session generation map plus a global counter, a
per-session serialized write chain plus an in-flight set, a logout-suspended
flag, an auth-cleanup flag plus generation, a deferred-initial-open flag plus
pending request, notification-availability state plus an initialization
future, and window state. Every generation check defends a theoretical
interleaving of show/cancel/logout rather than an observed failure.

**Change.** Keep the same observable behavior with one desired-state
reconciler: the pending-request map is the desired state; one serialized
apply loop (a single future tail) converges the native notification for each
changed session by showing or cancelling; logout and auth cleanup clear the
desired state and let the same loop converge. Target: at most eight mutable
fields, no per-session generations, no in-flight set. Theoretical
interleavings are accepted as bounded and self-healing (the next
reconciliation corrects a stale notification).

**Size and risk.** 600–900 lines including tests. Behavior-preserving for
ordinary flows; the ordering guarantees change from per-operation generations
to convergence. Architecture review required. Regression document:
`notifications.md` (desktop attention). Gated by D6.

### Step 12 — bridge test consolidation

**Evidence.** Byte-identical same-named fakes: `FakeBridgeHostInfo` ×2
(`sesori_plugin_runtime/test/managed_process_service_*_test.dart`),
`FakeUpdateLock` ×2, `FakeLogRepository` ×2, `FakeInstallService` ×2,
`FakePluginWarmupService` ×2, `FakePermissionAutoApprovalService` ×2,
`CapturingStdout`/`FakeStdout`/`ThrowingStdout` pairs, `FakeAcpStdioClient` ×2
(13 groups, 114 lines). Repeated in-file arrange blocks of ≥25 normalized
lines: `sesori_plugin_opencode/test/active_session_tracker_test.dart` (blocks
of 73, 45, 38, 33, 30, 28, 26 lines), `opencode_repository_test.dart` (46, 40,
37, 31, 28), `app/test/persistence/session_dao_test.dart` (35, 33, 32, 31,
29), `app/test/bridge/api/git_remote_api_test.dart` (38, 35),
`get_sessions_handler_test.dart` (29 ×3), `routing_test_helpers.dart` (36),
`question_repository_test.dart` (27), `session_creation_service_test.dart`
(29), `get_session_permissions_handler_test.dart` (31).

**Change.** Identical fakes move to the owning package's existing testing
library or `test/helpers`; each listed file gets file-local arrange helpers
(builders for the repeated fixtures). Fakes that differ in behavior stay local
(the first series recorded why strict fakes must not be merged). Assertions
are never rewritten.

**Size and risk.** 1,000–1,500 lines; may be split by package if the cap is
exceeded, with the reason recorded. Test-only. No architecture review.

### Step 13 — client test consolidation

**Evidence.** 71 byte-identical same-named fake groups (168 lines):
`MockAuthSession` ×15, `MockProductAnalyticsService` ×8, `MockUrlLauncher` ×7,
`MockConnectionService` ×7, `MockSessionListCubit` ×6,
`FixedApplicationSupportDirectory` ×6, `NoOpImageClipboard` and
`NoOpComposerImagePicker` ×2 (10 and 4 lines), `RecordingAttributionRepository`
×2 (9 lines). `sesori_dart_core/testing.dart` already exists but is imported
by only three packages. Repeated in-file arrange blocks: `session_detail_stale_
test.dart` (36, 31, 29, 28 ×3, 26 ×5), `session_detail_event_buffer_test.dart`
(38, 34, 29, 27 ×4, 26), `session_detail_cubit_test.dart` (34, 33, 30, 26 ×2),
`module_auth/test/auth_manager_test.dart` (43, 42 ×2, 38 ×3, 26),
`new_session_cubit_test.dart` (56), `new_session_screen_test.dart` (32, 26),
`app/test/features/project_list/project_tile_{menu,swipe,display}_test.dart`
(51, 34, 34 cross-file), `adaptive_session_list_navigation_test.dart` (30),
`crashlytics_failure_reporter_test.dart` (26).

**Change.** One `Mock*` declaration per contract in `sesori_dart_core/testing.
dart`, imported by `module_app_ui`, `app`, `desktop`, and `module_desktop_core`
tests; file-local arrange helpers for the listed files; the project-tile trio
shares one pump helper. Assertions are never rewritten.

**Size and risk.** 1,000–1,500 lines. Test-only. No architecture review.

### Step 14 — dependency, localization, and dead-symbol hygiene

**Evidence.** Dependencies declared but never imported in their package:
`re_highlight` (`client/app`), `cupertino_icons` (`client/design_catalog`),
`fake_async` (`client/app` dev), `freezed_annotation`
(`bridge/sesori_plugin_runtime`), `_fe_analyzer_shared`
(`shared/no_slop_linter`), and direct `json_annotation` in `bridge/app`,
`sesori_plugin_{acp,claude,codex,cursor,grok,hermes,interface,pi,runtime,
antigravity}`, `client/app`, `client/module_auth`, `client/module_desktop_core`
(all import it only through `freezed_annotation`; `sesori_plugin_opencode` and
`sesori_plugin_deepseek` import it directly and keep it). The step confirms
`build_runner` still resolves `json_serializable` through the transitive
dependency before removing each line. Unused ARB keys:
`sessionListStaleProjectTitle`, `sessionListStaleProjectMessage`,
`sessionListStaleProjectBack`, `voiceErrorNetwork`. Dead public top-level
symbols: `currentProjectName` (`client/app/lib/core/routing/current_project_
name.dart:6`), `kStatusGreen`/`kStatusPurple` (`module_app_ui/.../status_
colors.dart:8,10`), `logwf` (`module_core/.../logging.dart:65`),
`testMultiSseQuestionAsked` (`module_core/.../test_helpers.dart:736`),
`lerpTextStyleNonNull` (`module_prego/lib/utils/lerp_utils.dart:26`).

**Change.** Remove them; regenerate lockfiles and localization output. The
Antigravity package's `json_annotation` line is left for that series to
handle.

**Size and risk.** 100–200 lines. None. No architecture review.

### Step 15 — historical documents (D4)

**Evidence.** Listed under D4. `docs/regression/README.md` already forbids
tombstones; git history preserves every deleted page.

**Change.** Delete the listed files; fix the one inbound reference from
`docs/cursor-acp-followups` (deleted alongside) and check `docs/VISION.md`,
`docs/ROADMAP.md`, and `README.md` for links to the removed pages.

**Size and risk.** About 3,000 deleted lines — over the soft cap for a
deletion-only PR, recorded here. No code impact.

### Steps 16–17 — regression reconciliation and retirement

Step 16 reconciles the regression documents named in each step above,
removing implementation references that no longer exist and recording
executable coverage. Step 17 runs the level and matrix recorded below, writes
the results into `steps/step-17.md`, and moves the plan to
`.plan/completed/codebase-cleanup-2/`.

## Declined Candidates

Recorded so a later session does not re-investigate them without new evidence.

| Candidate | Why not |
|---|---|
| Five exhaustive `SesoriSseEvent` ignore-lists in `module_core` (`sse_event.dart`, `session_detail_cubit.dart` ×2, `session_list_cubit.dart`, `sse_event_tracker.dart`) | Enforced by the repository's own `prefer_exhaustive_switch` rule; the lists are the mechanism that makes a new event variant a compile-time task. |
| 24 classes hand-rolling the `_disposeFuture ??= _dispose()` fence | About eight lines each; a mixin would be a new abstraction with marginal gain and would hide lifecycle order from call sites. |
| Per-adapter ACP session-options services (Copilot 401 lines, OMP 281, Hermes 274, Grok 263, Cursor 137, DeepSeek 115) | Structurally similar but semantically different (config-option catalogs vs reasoning-effort catalogs vs per-project catalogs); a shared base would be the generic tracker the first series rejected. |
| `Orchestrator`, `PluginRuntime`, `PluginLifecycleService`, `SessionOptionsService` internals | Field census found coordination tied to observed flows (generations, leases, epochs the owner explicitly kept in the first series); no removable duplication. |
| `SessionDetailCubit` (35 mutable fields) | Owned by `session-refresh-reconnects`; its tracker already records the sealed-state direction. |
| Runtime manifests (7 files, ~100 lines each) | Per-plugin data over one shared base; not code duplication. |
| Small (9–14 line) chrome overlaps in `module_app_ui` (picker sheets, part widgets, settings rows) | Below the extraction threshold; no state or invariant to own. |
| `no_slop_linter` for large bridge packages | Roughly 1,800 mechanical edits; no reliability gain. |
| `bridge/app/tool/benchmarks` | Allowed one-off executables; analyze clean. |
| Single-variant `PluginAuthenticationChallengeType` enum | Inside the in-flight Antigravity browser-authentication series. |
| `bridge/app/tool/dev_control_host.dart` and the OpenCode client generator | Tooling; no production impact. |

## Cleanup Assessment

- Directly caused cleanup is inside each step: deleted twin adapters and
  tests (8), deleted listener classes (4), deleted tracker class (3), deleted
  private rename states (10), deleted compatibility fallbacks and their tests
  (7), deleted duplicate fakes (12, 13).
- Larger coherent cleanups have their own steps: documents (15), dependencies
  and dead symbols (14).
- Deferred with reason: Step 11 until `desktop-app` retires (D6); Antigravity
  files until that series completes; `SessionDetailCubit` state until
  `session-refresh-reconnects` Step 3 decides.

## Complexity Budget

New production types: the install/provision composition owners and
`BudgetedColdStart` (Step 2, replacing 7 + 7 + 2 copies), `ConnectionView
Tracker` (Step 3, replacing 2 classes), three merged listeners (Step 4,
replacing 6), `OptimisticRenameTracker` and one variant derivation (Step 10, replacing 2
private classes and 2 derivation pairs), `SessionActivityAnalyticsOwner` and four locator factories (Step 9,
replacing 2 private widgets and 8 argument lists). Net: fewer classes, and
every new one replaces at least two copies and owns a lifecycle or an
invariant.

New mutable parts: none. Step 11 removes at least twelve. Steps 3 and 4 remove
duplicated subscriptions and fences. Nothing adds a timer, registry, dedupe
set, or generation counter.

Deliberately not added: a listener base class, a dispose mixin, a generic
session-options service, an SSE event categorization hierarchy, a
compatibility shim for peers below the D1 floor.

## Compatibility

- Only Step 7 changes wire contracts, under D1, with per-marker peer
  verification against the `v1.6.0` tag. Newer peers are unaffected because
  every retired default concerned fields those peers already send.
- Steps 2–6 and 8–15 change no wire, persisted, or database shape.
- Internal Dart APIs (plugin interface, runtime, module barrels) update in
  lockstep with their in-repository consumers; no shims.

## Verification

- Per step: owning package tests, `dart analyze --fatal-infos` (and `flutter
  analyze` where applicable), downstream shells for shared-module changes,
  `git diff --check`. PR bodies carry `## Complexity`, `## What`, `## Why`,
  `## Risk and test focus`, `## Expected result`, and a verification section.
- Steps 2, 3, 4, 7, 8, 9, 10, 11: architecture-implementation review through
  a sub-agent, at most twice.
- Step 17 executes the matrix below.

## Regression Documentation And Final Matrix

Affected feature documents: `plugin-runtime-installation.md`,
`plugin-setup-and-lifecycle.md`, `session-creation-and-options.md`,
`projects-and-sessions.md`, `bridge-connectivity.md`,
`pull-request-monitoring.md`, `attachments-and-images.md`, `analytics.md`,
`account-and-onboarding.md`, `notifications.md`.

### Highest required level

**L3 (Release)** across the affected documents. The series changes no user
journey; it changes the composition behind existing journeys, so release
confidence through each journey's authoritative boundary is the honest proof.
Step 3 additionally executes one targeted relay-integration check with two
logical clients (a session viewed by either client does not bold for the
other) as step evidence, not as an L4 claim.

### Required matrix

| Area | Boundary | Plugins | Platforms |
|---|---|---|---|
| Managed-runtime setup inspection and `ensureRuntime` (Step 2) | Headless bridge | Every managed-runtime production plugin: Codex, OpenCode, Copilot, Cursor, DeepSeek, OMP, Pi | Release-target bridge host |
| Managed install and budgeted cold start (Step 2) | Live plugin | Representative: one managed install (Copilot or DeepSeek) and both budgeted cold starts (Codex, OpenCode) | Release-target bridge host |
| View tracking, warm-up, glossary population, automatic options refresh (Steps 3, 4) | Headless bridge + relay integration (two clients) | Representative | Release-target bridge host |
| Compatibility retirement (Step 7) | Automated with exact `v1.6.0` wire fixtures + headless bridge | None | — |
| Image save, copy, share, thumbnails (Step 8) | Client end to end | Representative | Release-target mobile platform and desktop (macOS) |
| Session open, rename, variant availability, activity analytics (Steps 9, 10) | Client end to end + automated | Representative | Release-target mobile platform and desktop (macOS) |
| Login by email and Apple (Step 10) | Client end to end for email; automated for Apple | None | Release-target mobile platform |
| Desktop attention notifications (Step 11, if executed) | Client end to end | Representative | Desktop (macOS) |
| Everything else | Automated (full suites) + `make analyze` in all three workspaces | — | — |

Any reduction to this matrix requires explicit owner acceptance recorded here
before Step 17 retires the plan.
