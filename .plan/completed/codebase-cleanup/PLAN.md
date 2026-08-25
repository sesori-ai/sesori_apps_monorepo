# Codebase Cleanup: Reliability And Maintainability Series

## Status

- **Plan slug:** `codebase-cleanup`
- **Status:** Completed — all 45 implementation and verification steps executed
- **Plan date:** 2026-08-22
- **Retired:** 2026-08-25
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `origin/main` at `084b30276`
- **Delivery:** 45 numbered PRs completed; Steps 44 and 45 performed the
  regression-document reconciliation and retirement required for durable
  planned work

This plan and `TRACKER.md` are the authority for the series. The code and the
released product remain authoritative where this document becomes stale: every
step re-verifies its evidence against current `main` before changing anything,
because line numbers below are from the implementation base and the repository
merges roughly a hundred PRs a week.

## Goal

Spend a few weeks making the system we already have more reliable and easier to
maintain, without shipping new features:

- fewer lines doing the same job (delete dead code, collapse verbatim and
  near-verbatim copies, stop re-deriving data that already exists);
- fewer failure points on paths that run constantly (one tested primitive
  instead of ten hand-rolled variants, one fake per contract instead of twenty,
  sealed states instead of flag combinations that can disagree);
- fewer places where a contributor has to guess (one directory tree, accurate
  architecture docs, dated compatibility markers, CI that covers every package).

This is not a bug hunt and not edge-case completeness. Every step is judged by
whether the code after it is smaller, simpler, or has fewer ways to be wrong —
never by whether it handles a case no current flow reaches.

## Non-Goals

- No new product behavior, screens, routes, events, or settings.
- No speculative abstractions: nothing is extracted unless it replaces at least
  two existing copies or removes an existing class of error.
- No rewrite of the orchestrator, `SessionDetailCubit` refresh coordination,
  `ConnectionService`/`RelayClient` state machines, event dispatchers, or the
  plugin event/tool trackers. Mechanical dedupe inside them is in scope; lifecycle
  redesign is not.
- No change to the public client↔bridge wire contract outside the explicitly
  gated compatibility step (Step 42), and no removal of any compatibility path
  that still serves a supported public release.
- No removal of the mandatory repository layer, pass-through repositories, or
  per-plugin event semantics; layer and plugin-boundary rules stay as written.
- Session-detail refresh behavior stays owned by the active
  `session-refresh-reconnects` plan; Step 31 touches only pure derivation code.
- Enabling `no_slop_linter` across all bridge packages and typing the client HTTP
  generics are recorded as follow-up decisions, not executed here.

## Investigation Summary

Eight read-the-code audits covered bridge core/runtime, bridge
repositories/services/routing, the plugin packages, shared contracts and
compatibility, client `module_core`, the Flutter shells and `module_prego`, the
test suites, and repo-wide mechanical smells, tooling, and docs. Every claim used
below was verified by reading or grepping the current tree; items the audits
could not fully verify are marked **verify first** in their step.

Baseline facts:

- Non-generated production code: bridge ≈ 100k lines (app 45k, plugins 50k,
  interface/foundation/runtime 7k), client ≈ 70k (app 31k, module_core 25k,
  module_prego 10k), shared ≈ 8k. Tests ≈ 265k lines (bridge/app alone 113k, of
  which 25k is generated Drift schema history).
- `bridge/app/lib/src` carries two parallel layer trees (`src/{api,foundation,
  repositories,routing,services}` and `src/bridge/{api,foundation,repositories,
  routing,services,sse}`), both receiving new files; 29 top-level files import
  the subtree and 23 subtree files import top-level. `bridge/ARCHITECTURE.md`
  describes a third layout: 16 of the 17 paths it names do not exist.
- `client/module_core/lib/src/concurrency/` (12 files, 759 lines) is a
  near-verbatim copy of `shared/sesori_shared/lib/src/concurrency/`, and its only
  consumer `dto_parser.dart` has zero references — 815 dead lines.
- 73 `COMPATIBILITY` markers span v1.3.0 → v1.9.0; several labels name the wrong
  release; no minimum-supported-peer policy exists anywhere in the repository.
  Public releases are `v1.0.7 … v1.8.0`.
- bridge/app tests define 366 fake classes; 62 production types are faked in two
  or more files (282 definitions, 9,734 lines); `FakeBridgePlugin` exists in a
  shared helper yet is re-implemented in 19 files. Thirty-four byte-identical
  `Stdout` fakes exist across four plugin packages. 187 real-duration sleeps are
  used as test synchronization.
- 255 analyzer suppressions, 186 of them for the repository's own
  `no_slop_linter` (110 `prefer_specific_type`, 60
  `prefer_required_named_parameters`); no bridge package runs that linter.
- `shared/sesori_shared` — the crypto and protocol package — is never analyzed
  or tested by any CI workflow; `bridge/Makefile` and `shared/Makefile` analyze
  without `--fatal-infos` while CI uses it.

Estimated series outcome: roughly −9,000 to −12,000 production lines, −6,500 to
−8,000 test lines, −3,000 generated lines, four fewer dependencies, one bridge
layer tree, one fake per shared contract, and accurate docs. The numbers are
targets for honesty, not acceptance criteria; a step that finds its evidence
stale records that and does less.

## Principles For Every Step

- Behavior-preserving by default. A step that intentionally changes observable
  behavior (Steps 19, 21, 38, 40, 41, 42) says so in its PR body and updates
  the affected `docs/regression/` document in the same PR; Step 44 remains the
  final consistency pass for implementation references, not the first place a
  behavior change is documented.
- Delete before you add. Prefer removing the copy over generalizing it; when a
  shared primitive is introduced it must replace at least two existing copies
  and own state, a lifecycle, or an invariant — never exist for file length.
- One area per PR, under the 1,500 changed-line soft cap. Deletion-heavy and
  generated-heavy steps may exceed it; the reason is recorded in the tracker.
- Re-verify before editing. Line references here are from `084b30276`; each
  step greps its claims against current `main`, drops anything that has moved
  on, and records the delta in `TRACKER.md`.
- Each PR runs the owning package's focused tests plus `dart analyze
  --fatal-infos` (and `flutter analyze` for Flutter packages); shared-module
  changes also validate the downstream product shells. CI runs the full matrix.
- Architecture-implementation review is invoked only for steps that add or move
  production classes, change DI ownership, or touch shared boundaries: Steps 4,
  7, 15, 17, 18, 20, 21, 22, 23, 25, 26, 27, 28, 29, 30, 31, 32, 33, 36, 37.
  Pure deletions, docs, tooling, and test-only steps skip it.
- Keep recovered failures observable: the consolidation of helpers never drops a
  log that was the only trace of an error, and the catch-hygiene items add the
  error and stack as logger arguments rather than interpolating them.
- No compatibility removal without the recorded baseline in Open Decision D1.

## Open Decisions

Each decision has a default so execution never blocks; the owner can override
any of them in the Step 1 PR review or later in `TRACKER.md`.

- **D1 — Minimum supported public peer version (gates Step 42). DECIDED
  2026-08-22: `≥ v1.4.0`**, the owner-approved baseline (first recorded in PR
  #1017 on 2026-08-21 and confirmed by the owner for this plan): remove
  compatibility paths whose peer is a released Sesori surface older than
  v1.4.0; keep every v1.4.x+ marker; managed-runtime and on-disk-data compat
  (Codex rollout formats, OpenCode runtime events) stays regardless of marker
  age unless its peer is itself a released Sesori surface older than v1.4.
  Step 42 therefore retires the nullable `RejectQuestionRequest.sessionId`
  legacy question path and its dispatcher lanes (v1.0.9 clients), the
  `displaySessionId` fallback and the empty-health-body tolerance (v1.1.x
  bridges), the `v1.1.2` post-update relaunch variable, and the `v1.3.0`
  bridge-id migration (peer: `token.json` written by installs last run on
  `≤ v1.3.x`; accepted consequence: such an install, upgraded directly, does
  not find its persisted id and registers as a new bridge, leaving the old
  registration orphaned). The `≥ v1.6.0` (N-2 minors) alternative, which would
  additionally retire the v1.4–v1.5 family (`legacyMissingPluginId` defaults,
  `Project` path/time fallbacks, `unavailablePluginIds`, discovery-404
  fallback, `OpenProjectRequest.gitAction` tolerance), was not chosen.
- **D2 — Flatten the bridge/app layer tree (Step 7). APPROVED 2026-08-22** by
  the owner: the ~210-file mechanical `git mv` (net 0 lines) runs as Step 7,
  scheduled after the dead code is deleted and before the bridge production
  refactors, so every later step is written against the final layout.
- **D3 — Replace `flutter_chat_ui` with a plain reversed list (Step 41).**
  *Default:* run the spike; land only if the listed scroll behaviors (follow,
  detach snapshot, older-page prepend freeze, prompt-row transitions, keyboard
  inset) are at parity in widget tests; otherwise record the spike result and
  close the step without the change.
- **D4 — `cryptography_flutter` in `client/app`.** It is declared but never
  enabled (`FlutterCryptography.enable()` is not called), so it currently does
  nothing. *Default:* remove it as unused in Step 6; enabling native crypto is a
  separate performance decision.
- **D5 — Material→Prego dialog migration breadth (Step 38).** *Default:* only
  the dialogs that the shared sheet footer and confirm-sheet consolidation
  naturally cover; no app-wide chrome migration.
- **D6 — `no_slop_linter` in bridge (Step 43).** *Default:* enable for the
  small packages (`sesori_bridge_foundation`, `sesori_plugin_interface`,
  `sesori_plugin_runtime`) and record per-package warning counts for the rest;
  enabling it in `bridge/app` and the plugins is a later decision.

## Delivery Plan

Fixed titles, complexity, and order. Targets are changed lines (additions plus
deletions, generated and tests included).

| Step | Exact PR title | Target | Scope |
|---|---|---:|---|
| 1/45 | `🌱 [codebase-cleanup] docs: raise the reliability cleanup plan [step 1/45]` | 1,700–2,000 | This plan and tracker only; over the soft cap because the 45-step evidence base (plus the PR #1017 reconciliation and three review rounds) is what lets each later step execute without re-investigation. |
| 2/45 | `🌿 [codebase-cleanup] client(module_core): delete the dead concurrency copy [step 2/45]` | 1,200–1,400 | Delete `module_core/lib/src/concurrency/` + `dto_parser.dart` and their two app tests. |
| 3/45 | `🌿 [codebase-cleanup] shared: delete dead helpers, models, and the rxdart dependency [step 3/45]` | 1,300–1,600 | Trim `sugar_dart`/`iterable_x`/`future_x`, delete four dead models and `RefCountReusableStream`, drop `rxdart`. |
| 4/45 | `🌿 [codebase-cleanup] shared: tighten management fields and correct compatibility markers [step 4/45]` | 250–500 | Required `snapshotToken`/`bridgeId`, `ActiveSession` defaults, converter reuse, relabel/date COMPATIBILITY markers, remove OpenCode DTOs from shared. |
| 5/45 | `🌿 [codebase-cleanup] bridge(app): delete dead production code [step 5/45]` | 700–1,000 | Dead repository/DAO/mapper/tracker methods, test-only core members, stub library, unused `acp_plugin` dependency. |
| 6/45 | `🌿 [codebase-cleanup] tooling: close CI gaps, prune dependencies, and refresh docs [step 6/45]` | 300–500 | `sesori_shared` CI, one bridge-ci package list, `--fatal-infos` parity, unused pubspec deps, `docs/ARCHITECTURE.md`, AGENTS stale names, README plugin lists. |
| 7/45 | `⚙️ [codebase-cleanup] bridge(app): flatten the duplicated layer tree [step 7/45]` | 500–900 | D2 approved: `git mv` `src/bridge/*` into `src/*`, `plugin_runtime.dart` to `api/`, `runtime/` kept as the CLI/composition subsystem; rewrite `bridge/ARCHITECTURE.md` and the app `AGENTS.md` structure. |
| 8/45 | `🌿 [codebase-cleanup] bridge(plugins): add a plugin-interface testing library for console and process fakes [step 8/45]` | 1,100–1,500 | `plugin_interface_testing.dart`; migrate Stdout, HostProcessService, SpawnedProcess, BridgeHostInfo, IOSink, clock fakes across seven packages. |
| 9/45 | `⚙️ [codebase-cleanup] bridge(app): consolidate plugin and repository test fakes [step 9/45]` | 1,200–1,500 | `test/helpers/fakes/`; `FakeBridgePlugin`/`FakeDerivedBridgePlugin`; private copies become subclasses. |
| 10/45 | `🌿 [codebase-cleanup] bridge(app): consolidate process-runner and service test fakes [step 10/45]` | 900–1,300 | `RecordingProcessRunner`, control-client, worktree, process-repository, settings-api, relay-client fakes. |
| 11/45 | `🌿 [codebase-cleanup] bridge(plugins): add plugin-local test support for OpenCode, ACP, and Pi [step 11/45]` | 1,200–1,500 | OpenCode fake API + fixtures, ACP plugin builder, Pi storage fakes. |
| 12/45 | `🌿 [codebase-cleanup] client(module_core): consolidate test helpers and cubit harnesses [step 12/45]` | 800–1,100 | Shared mocks, `buildSessionDetailCubit`, connection-service support. |
| 13/45 | `🌿 [codebase-cleanup] client: publish a module_core testing library and relocate its tests [step 13/45]` | 500–900 | `sesori_dart_core/testing.dart`, app helper de-dup, move the 13 pure-Dart module_core tests out of `client/app/test` (widget tests stay), prune dead exports. |
| 14/45 | `⚙️ [codebase-cleanup] tests: replace real-duration sleeps with fake time and state awaiting [step 14/45]` | 200–500 | Nine worst files; one `awaitState` helper per package. |
| 15/45 | `🌿 [codebase-cleanup] bridge(app): share tracked-work helpers and fix logging consistency [step 15/45]` | 400–700 | `PendingOperations`, session-options listener outcome, logger-argument and catch consistency, clocks, SSE event construction, push maps (verify first). |
| 16/45 | `🚧 [codebase-cleanup] bridge(app): remove the triplicated PluginRuntime command preamble [step 16/45]` | 300–500 | One precondition helper and one transition record for stop/disable/restart. |
| 17/45 | `⚙️ [codebase-cleanup] bridge(app): simplify Orchestrator fencing and PluginLifecycleService initialization [step 17/45]` | 400–700 | `_isCurrentSource` everywhere, non-null plugin ids, one composite, plugins in the constructor. |
| 18/45 | `🚧 [codebase-cleanup] bridge(app): consolidate auth validation, abortable requests, and encryptor ownership [step 18/45]` | 500–800 | `TokenService` (renamed) absorbs `validate.dart`; one `/auth/me` helper; auth-backend URL normalized once; `AbortableRequestClient`; one `SessionEncryptor` per session; one restricted-file writer. |
| 19/45 | `⚙️ [codebase-cleanup] bridge(app): deduplicate request-handler error mapping and guards [step 19/45]` | 500–800 | One guard, one non-empty check, one JSON error builder, unused handler parameters removed. |
| 20/45 | `⚙️ [codebase-cleanup] bridge(app): deduplicate SessionRepository, enrichment, and pending-interaction repositories [step 20/45]` | 500–800 | Plugin-use preamble, chunked reads, `enrichSessions` without re-derivation, shared question/permission helpers. |
| 21/45 | `🚧 [codebase-cleanup] bridge(app): replace hand-rolled FIFO lanes with the foundation ParallelLock [step 21/45]` | 200–400 | Six single tails and four keyed tails on one tested primitive. |
| 22/45 | `⚙️ [codebase-cleanup] bridge(app): deduplicate updater and server helpers and seal platform trios [step 22/45]` | 400–700 | CSV/IO/cleanup/network helper copies, sealed update result models, `DefaultEditorRepository` fold, sealed wake-lock/editor implementations. |
| 23/45 | `⚙️ [codebase-cleanup] bridge(plugins): remove dead contract members and collapse PluginProvider [step 23/45]` | 1,200–1,600 | `healthCheck`/`dispose` off the contract, one `PluginProvider`, `PluginSetupStatus` field, dead seams and stale comments. |
| 24/45 | `🌿 [codebase-cleanup] bridge(runtime): remove the migration-era dual-mode runtime knobs [step 24/45]` | 300–500 | One production behavior for health policy, port policy, early exit, intent store. |
| 25/45 | `🚧 [codebase-cleanup] bridge(plugins): fold Codex and OpenCode managed-runtime plumbing into sesori_plugin_runtime [step 25/45]` | 800–1,300 | Shared draining process, port candidates, status reporter, bridge-plugin wrapper, start helper. |
| 26/45 | `🚧 [codebase-cleanup] bridge(plugins): share descriptor setup probing and managed installation [step 26/45]` | 900–1,400 | Sealed probe outcome, selection service, install factory, one ANSI strip. |
| 27/45 | `🚧 [codebase-cleanup] bridge(plugins): extract the shared pending-permission registry base [step 27/45]` | 500–800 | ACP/Codex skeleton into the interface; Cursor branches move to Cursor. |
| 28/45 | `⚙️ [codebase-cleanup] bridge(plugins): share small mapper helpers and lifecycle wrappers [step 28/45]` | 300–500 | `asStringKeyedMap`/`nonEmptyString`, part constructors, terminal-status extension, compaction command, ACP config parser, Claude/Pi wrapper. |
| 29/45 | `🚧 [codebase-cleanup] bridge(plugins): share stdio pending-request and transport plumbing [step 29/45]` | 600–1,100 | `NdjsonProcessClient` in `sesori_plugin_runtime` per the PR #1017 contract; ACP, Codex, Claude adopt it; Pi keeps its frame shape. |
| 30/45 | `⚙️ [codebase-cleanup] client(module_core): delete SessionService and inline thin services [step 30/45]` | 400–700 | `SessionService`, `BridgeSettingsService`, view API/repository twins, dead state/converter/fields. |
| 31/45 | `⚙️ [codebase-cleanup] client(module_core): deduplicate SessionDetailCubit derivation and analytics reporting [step 31/45]` | 400–700 | Snapshot derivation record, queue view, reply helper, typed agents, shared once-per-state analytics reporter, catch hygiene. |
| 32/45 | `🚧 [codebase-cleanup] client(module_core): share list-cubit scaffolding and relay request plumbing [step 32/45]` | 400–700 | `reconnectAndAwaitOutcome`, ordered emit, optimistic removal, one relay request method, one id generator. |
| 33/45 | `🚧 [codebase-cleanup] client(module_core): compose NewSessionState from phase and configuration [step 33/45]` | 900–1,400 | Sealed phase plus one configuration record; cubit `copyWith` updates. |
| 34/45 | `⚙️ [codebase-cleanup] client(module_core): unify plugin-management result and failure types [step 34/45]` | 300–500 | One failure type, one repository mapper, one cubit mapper, drop redundant flags. |
| 35/45 | `🌿 [codebase-cleanup] client(app, prego): delete dead shell code, components, and localization keys [step 35/45]` | 800–1,100 | Dead files, 14 dead l10n keys, dead test-hook keys, orphan Prego components and assets. |
| 36/45 | `⚙️ [codebase-cleanup] client(app): replace no-op Firebase SDK adapters with no-op interface implementations [step 36/45]` | 500–700 | Three ~15-line no-ops instead of 608 lines of SDK mirrors. |
| 37/45 | `⚙️ [codebase-cleanup] client(app, prego): let grouped rows own separators and share shell helpers [step 37/45]` | 400–700 | `isLast` removed from 39 sites, settings scaffold, clipboard helper, size observer, keyboard-inset fork removal. |
| 38/45 | `⚙️ [codebase-cleanup] client(app): consolidate sheets, dialogs, and status widgets [step 38/45]` | 700–1,100 | Rename/confirm sheets, sheet footer, sheet sizing, failure/notice/status widgets, question tiles, sealed auth challenge. |
| 39/45 | `🌿 [codebase-cleanup] client(app): remove in-file duplication from the prompt composer [step 39/45]` | 200–350 | Paste, draft, pill, and notice duplicates inside `prompt_input.dart`. |
| 40/45 | `🚧 [codebase-cleanup] client(app): model the voice interaction as one sealed state [step 40/45]` | 600–900 | Nine coordination flags become one sealed `_VoiceInteraction`. |
| 41/45 | `🚧 [codebase-cleanup] client(app): render the transcript with a plain reversed list [step 41/45]` | 500–800 | D3 spike; drop `flutter_chat_ui`/`flutter_chat_core` on parity. |
| 42/45 | `🚧 [codebase-cleanup] compat: retire compatibility paths outside the supported baseline [step 42/45]` | 300–700 | D1 decided `≥ v1.4.0`: delete every path whose peer is a released Sesori surface older than v1.4.0, with a per-marker peer-verification line. |
| 43/45 | `⚙️ [codebase-cleanup] tooling: align installers, assert codegen freshness, and enable no_slop_linter for small bridge packages [step 43/45]` | 300–600 | `install.ps1`/`install.sh` parity with fixture tests, offline codegen freshness job, D6 linter rollout for foundation/interface/runtime with counts recorded for the rest. |
| 44/45 | `🌱 [codebase-cleanup] docs: reconcile regression coverage after the cleanup [step 44/45]` | 100–250 | Reconcile affected `docs/regression/` documents. |
| 45/45 | `🌿 [codebase-cleanup] test: verify the cleanup series and retire the plan [step 45/45]` | 80–250 | Run the recorded level and matrix; retire the plan. |

Order rationale: zero-risk deletions and tooling first (2–6) so nothing dead is
moved or faked later; the tree flatten (7) before any bridge production change;
test-infrastructure consolidation (8–14) before the production refactors whose
constructor changes would otherwise churn dozens of private fakes; then bridge
core (15–22), plugins (23–29), `module_core` (30–34), shells (35–41), and the
gated/policy steps (42–43). Steps 39–41 overlap open PRs #918, #956, and #939;
they rebase after those merge and re-scope if the composer or list code moved.

## Step Details

### Step 2 — delete the dead concurrency copy

- Evidence: `client/module_core/lib/src/concurrency/**` (12 files, 759 lines)
  differs from `shared/sesori_shared/lib/src/concurrency/` only by lint
  wording, one import path, and the typo'd `mulit_task_isolate_pool.dart`;
  `impl/message_queue.dart` (97 lines) has no production consumer; the only
  importer is `client/module_core/lib/src/api/parsing/dto_parser.dart:6-7`,
  which has zero references anywhere in `client/`.
- Change: delete `dto_parser.dart`, the concurrency directory,
  `client/app/test/core/concurrency/{message_queue,concurrent_cache}_test.dart`
  (shared already tests `ConcurrentCache`), and any barrel export.
- Verify: `dart analyze --fatal-infos` + `dart test` in `client/module_core`;
  `flutter analyze` + `flutter test test/core` in `client/app`.

### Step 3 — shared dead helpers, models, `rxdart`

- Evidence (member-by-member grep across 1,840 non-generated files): the only
  used members of `shared/sesori_shared/lib/src/extensions/sugar_dart.dart`
  (324), `iterable_x.dart` (59), and `concurrency/future_x.dart` (43) outside
  shared are `jsonDecodeMap`/`jsonCastMap`/`jsonDecodeListMap`,
  `String.normalize` (3 call sites), `String.chunked` (2), `Iterable.partition`
  (1; in the copy deleted by Step 2 — re-check), and `wait2` (2). Everything
  else (`Sugar`, `FutureSugar`, all `StreamExtensions`, `tryCatch*`,
  `Utf8Extension`, most `StringExtensions`, `MapExtensions`, `BoolExtensions`,
  `DurationExtension`, `FutureX.requireType`, `wait3..wait6`, …) is unused.
  `package:rxdart` is imported in shared only by `sugar_dart.dart` and the dead
  `lib/src/streams/ref_count_reusable_stream.dart` (95 + 259 test lines).
  `lib/src/models/auth/auth_url_response.dart`, `logout_response.dart`, and
  `lib/src/models/sesori/discover_project_request.dart` have zero references in
  bridge or client (the deep-link OAuth flow they served was removed in #161).
- Change: keep the used members and `toUnmodifiableList` (used by `partition`),
  delete the rest with their tests; delete the four dead classes, their
  generated parts, barrel exports, and `test/models/project_management_models_test.dart`
  coverage of `DiscoverProjectRequest`; remove `rxdart` from
  `shared/sesori_shared/pubspec.yaml`; regenerate.
- Verify: `dart analyze --fatal-infos` in shared, every bridge package, and every
  client package (the analyzer is the safety net); `dart test` in shared.

### Step 4 — shared field tightening and compatibility-marker hygiene

- `PluginManagementResponse.snapshotToken`/`bridgeId`
  (`shared/…/plugin_management.dart:130-137`): the "Stage 12" producers that
  omitted them never reached a public tag (`git cat-file -e v1.6.0:…` — file
  absent; v1.7.0 already has both). Make both `required String`; tighten
  `_PluginManagementSnapshot.snapshotToken` in
  `bridge/app/lib/src/services/plugin_lifecycle_service.dart:1429`; remove the
  client null branches in `client/module_core/lib/src/services/plugin_management_service.dart:306-314,603`;
  update `plugin_management_contract_test.dart`.
- `ActiveSession` (`shared/…/active_session.dart:14,21-23`): `@Default(null)
  int?` plus lint ignore → `required int?` (wire tolerance unchanged; the
  COMPATIBILITY comment stays).
- `plugin_management.dart:198-201` `_strictIntFromJson` → the exported
  `StrictIntJsonConverter`; **verify first** whether the explicit `type` field
  beside the `unionKey: "type"` union (`:59,85-90`) serializes the same key
  twice and can be dropped without changing JSON.
- Relabel COMPATIBILITY markers to the public release that first shipped the new
  shape (labels "v1.9.0" on shapes in v1.8.0: `plugin_management.dart:67`,
  `plugin_setup_response.dart:21`, `session.dart:60,152`,
  `sesori_sse_event.dart:346`, `messages.dart:33`,
  `session_options_response.dart:19`; "v1.7.2" → v1.8.0 at
  `message_with_parts.dart:18`, `session.dart:145`; "v1.5.0" → v1.5.1;
  "v1.6.1" → v1.7.0 where applicable). Add dated `// COMPATIBILITY` markers to
  the undated legacy paths: `bridge/app/lib/src/bridge/routing/get_agents_handler.dart`,
  `agent_repository.dart:13-21`, `shared/…/session.dart:29,50-59`, the client
  `BridgeSettingsLoadLegacyPartial` types, `client/app/lib/core/routing/deep_link_service.dart:8-46`,
  `bridge/app/lib/src/updater/foundation/update_lock.dart:304`,
  `bridge/sesori_plugin_interface/…/plugin_state_storage.dart:8`. Delete the
  comment-only marker at `session_catalog_mapper.dart:12-14`.
- `GlobalSession`/`SessionProject` (`shared/…/session.dart:88-121`) are
  OpenCode HTTP DTOs used only by `bridge/sesori_plugin_opencode/lib/src/opencode_api.dart:444-469`
  and `opencode_repository.dart:583-600`. **Verify first** whether the generated
  `lib/src/models/openapi/global_session.g.dart` already models the same
  response; if so use it and delete the shared classes, otherwise move them into
  the plugin package. Either way they leave `sesori_shared`.
- Verify: shared tests, bridge `plugin_lifecycle_service_test.dart`, client
  `plugin_management_service` tests, OpenCode plugin tests.

### Step 5 — bridge/app dead production code

All verified with whole-word grep over lib, bin, and test across the repo.

- Repositories/DAOs/mappers/trackers: `session_repository.dart:1483-1544`
  `insertStoredSession` (fixture-only; migrate 7 test files to
  `SessionDao.insertSession`/`createSession`), `:1637`
  `_allocateSessionId(reservedSessionIds)` parameter never passed;
  `session_dao.dart:627-682` `insertSessionsIfMissing`, `:452-464`
  `getArchivedCatalogSessions`; `projects_dao.dart:38-40` `getProjectsByPath`,
  `:120-131` `getHiddenProjectIds`/`hiddenProjectIdsStream`, `:153-172`
  `unhideProject`, `:282-303` `insertMissingProjectsWithActivity`;
  `mappers/plugin_project_mapper.dart` (31 lines, zero callers);
  `mappers/plugin_session_mapper.dart:65-83` `enrichSharedSessions`;
  `trackers/session_event_tracker.dart:95-107,130-156` `takeChildren/
  takeTranslations/takeReady`; `repositories/wake_lock_repository.dart:6`
  `isEnabled`.
- Core/runtime/server/updater/push/auth: `server/repositories/port_repository.dart`
  (52 lines), `server/host/bridge_plugin_host_impl.dart:49-97` `create`,
  `server/api/runtime_file_api.dart:15,27,31-39` ownership-file helpers (carry
  the backend literal `opencode-processes.json` in bridge core),
  `relay_client.dart:189-196` `reconnect`, `runtime/bridge_shutdown_coordinator.dart:44-46`
  `addOrdered`, `repositories/plugin_lifecycle_repository.dart:56-59`
  `stop(intent:)`, `debug_server.dart:73-76` `stop()`,
  `push/push_session_state_tracker.dart:117-119` `findPrunableRootSessionIds`,
  `auth/access_token_provider.dart:11-15` `AccessTokenUpdater` + the
  `token_manager.dart:33-34` setter, `eligible` getters
  (`plugin_runtime.dart:36`, `plugin_lifecycle_repository.dart:16`),
  `updater/models/distribution_target.dart:52-54` `getCurrentAssetName`,
  `updater/foundation/update_policy.dart:43-45` `isInteractiveTerminal`, and
  trivial items (`sse_manager.dart:114` alias and unused `subscribePath`,
  `control/control_channel_loss_listener.dart:11,27` default exit code,
  `auth/token.dart:101-107` rethrow-only catch,
  `server/repositories/process_repository.dart:11-17` no-op null check,
  `updater/api/update_cache_api.dart:40-47` redundant re-check,
  `runtime/bridge_runtime_runner.dart:173-181` one-caller wrapper).
- `bridge/app/lib/sesori_bridge.dart` (5-line TODO stub, no importer) and the
  unused `acp_plugin` path dependency in `bridge/app/pubspec.yaml:33-34`.
- Verify: `dart analyze --fatal-infos` + touched test files + `dart test` in
  `bridge/app`.

### Step 6 — tooling, dependencies, docs

- CI: add `shared/sesori_shared` analyze + test to the bridge (or a new shared)
  workflow; `tool/` scripts are analyzed; `.github/workflows/bridge-ci.yml`
  drives its 12 analyze + 12 test steps from one checked-in package list
  (preserving per-package output and fail-fast) so adding a package edits one
  line, and its path filters gain `install.sh`/`install.ps1` for Step 43's
  parity suite. Makefiles: `bridge/Makefile:92-95` and `shared/Makefile:34-37`
  gain `--fatal-infos`; delete the caveats at `bridge/AGENTS.md:17` and
  `docs/CONTRIBUTING.md:91`.
- Dependencies verified unused by `package:<name>/` grep: `client/app`
  `collection`, `web_socket_channel`, `cupertino_icons`, `cryptography_flutter`
  (D4), `cryptography` → dev-only (used by one test); `client/module_core`
  `intl`; `client/module_auth` `cryptography`; `client/module_prego` `meta`,
  dev `mocktail`/`fake_async`; `bridge/sesori_plugin_codex` dev `fake_async`.
  Keep every `json_annotation` (generator requirement). **Verify first** with a
  `build_runner` run that nothing generated depends on a removed package.
- Docs: `docs/ARCHITECTURE.md` package list and graph (add `sesori_plugin_claude`,
  `sesori_plugin_hermes`, `sesori_plugin_pi`, `client/design_catalog`, missing
  edges); `bridge/AGENTS.md` Module Order (cursor/omp/pi depend on runtime;
  claude/hermes/pi missing) and stale names (`MetadataService`,
  `AccessTokenReader/Writer`, `GithubApi`; the `TokenService` suffix example
  stays because Step 18 renames the class to it); `bridge/app/AGENTS.md:82` stale
  request names; `client/module_core/AGENTS.md` directories (`extensions/`,
  `reporting/` do not exist); `client/AGENTS.md` diagram references a
  non-existent `module_app_ui`; plugin lists in `bridge/README.md`,
  `docs/HOW_IT_WORKS.md`, `docs/GETTING_STARTED.md`, `README.md`.
  `bridge/ARCHITECTURE.md` and the app `AGENTS.md` structure block are rewritten
  in Step 7 against the final layout.

### Step 7 — flatten the bridge/app layer tree (D2)

- Move `src/bridge/{api,foundation,repositories,routing,services,sse,runtime,
  models,persistence}` to `src/{…}`; `orchestrator.dart` and `debug_server.dart`
  to `src/`; `relay_client.dart`, `key_exchange.dart`, `bandwidth_tracker.dart`,
  `log_failure_reporter.dart` to `src/foundation/`;
  `plugin_to_shared_mapping.dart` to `repositories/mappers/`;
  `worktree_types.dart` to `repositories/models/`; the lone
  `routing/handlers/mark_session_seen_handler.dart` into `routing/`;
  `api/generate_session_metadata_response.dart` and
  `api/app_client_status_response.dart` into `api/models/`. 506 import lines in
  lib/bin/test mention `bridge/<layer>/`; 147 sibling imports stay valid.
- `runtime/` today mixes two roles and cannot be given one layer, so the
  flatten separates them: `plugin_runtime.dart` (the below-repository plugin
  access seam that repositories call through `_runtime.use`, i.e. the
  "BridgePlugin is API-layer in app/" rule) moves to `src/api/plugin_runtime.dart`;
  the remaining files (`bridge_cli_*`, `bridge_runtime*`, `bridge_logout_runner`,
  `bridge_shutdown_coordinator`, `plugin_registry`, `plugin_generation_factory`,
  `plugin_cli_options_mapper`, `runtime_provision_formatter`) stay in `src/runtime/`
  as the CLI/composition subsystem, a peer of `server/`, `updater/`, and
  `auth/`, and the docs say so.
- Rewrite `bridge/ARCHITECTURE.md` "Directory Structure" and the
  `bridge/app/AGENTS.md` STRUCTURE block to the resulting tree and layer
  assignment.
- No code changes beyond imports and paths; `git mv` so history follows.
- Verify: `dart analyze --fatal-infos` + full `dart test` in `bridge/app`.

### Step 8 — plugin-interface testing library

- `Console`/`Log` live in `bridge/sesori_plugin_interface/lib/src/console.dart`;
  add `bridge/sesori_plugin_interface/lib/plugin_interface_testing.dart`
  (same pattern as `acp_testing.dart`) exporting `BufferingStdout`,
  `CapturingStdout`, `ThrowingStdout`, `FakeHostProcessService` (scripted spawn
  results, recorded signals), `FakeSpawnedProcess` (controllable exit/stdout),
  `FakeBridgeHostInfo`, `AdvancingServerClock`, and one `CapturingIOSink` with
  the richest surface of the three copies.
- Replace: `_BufferingStdout` ×14 (codex/acp/pi/claude) and its `write` variant
  ×4 (bridge/app), `_CapturingStdout` ×7, `_FakeStdout` ×6, `_ThrowingStdout`
  ×4; runtime `_FakeHostProcessService` ×4, `_FakeBridgeHostInfo` ×4,
  `_FakeSpawnedProcess` ×3, `ServerClock` fakes ×5 (714 lines across four
  runtime test files); codex and opencode probe-process fakes become subclasses;
  `CapturingIOSink` copies in `acp/claude/pi lib/src/testing/fake_*_process.dart`.
- Verify: `dart analyze --fatal-infos` + `dart test` in interface, runtime, app,
  codex, opencode, acp, pi, claude.

### Step 9 — bridge/app plugin and repository fakes

- `bridge/app/test/bridge/routing/routing_test_helpers.dart` (1,685 lines) holds
  `FakeBridgePlugin` (386 lines, 62 importers), `FakeSessionMetadataRepository`,
  `FakePullRequestRepository`, `FakePrSyncService`, `FakeSessionRepository`;
  19 files re-implement `NativeProjectsPluginApi` (2,136 lines) and 8 implement
  `BridgeDerivedProjectsPluginApi` (368 lines) with no shared fake.
- Move the fakes to `bridge/app/test/helpers/fakes/`, add
  `FakeDerivedBridgePlugin`, convert private copies (`debug_server_test`,
  `orchestrator_error_recovery_test`, `session_repository_test`,
  `project_repository_test`, `worktree_service_test`,
  `session_lifecycle_service_test`, `update_session_archive_status_handler_test`,
  `integration/pr_sync_fk_regression_test`, `session_creation_service_test`, the
  derived copies) to `extends FakeBridgePlugin` overriding only scenario methods.
  Do not rewrite assertions; subclass-and-override preserves behavior.
- Verify: full `dart test` + `dart analyze --fatal-infos` in `bridge/app`.

### Step 10 — bridge/app process-runner and service fakes

- `helpers/restart_test_support.dart:12 NoopProcessRunner` exists; six
  byte-equivalent `_NoopProcessRunner` copies, `_RecordingProcessRunner` ×7,
  `_FakeProcessRunner` ×7, two public `FakeProcessRunner`s with different APIs
  → `test/helpers/fake_process_runner.dart` with `NoopProcessRunner` and one
  responder-style `RecordingProcessRunner`. Also `_FakeTokenRefresher` ×7
  (helper exists), `_FakeControlChannelClient` ×6 (197 lines),
  `_FakeWorktreeService` ×6 (329), `_FakeProcessRepository` ×5 (216),
  `_MemoryBridgeSettingsApi`/`_QueueBridgeSettingsApi` ×7, `_RecordingRelayClient` ×3.
- Verify: `dart test` in `bridge/app` (`bridge/api/*`, `worktree*`, `server/*`,
  `updater/*`, `control/*`).

### Step 11 — OpenCode, ACP, Pi test support

- OpenCode: `_FakeApi` ×2 + `FakeOpenCodeApi` (579 lines) and hand-built
  `Project(` ×84 / `Session(` ×51 literals → `test/support/fake_open_code_api.dart`
  and `open_code_fixtures.dart` (`testProject`, `testSession`).
- ACP: `TestAcpPlugin(` ×14 with ~17 args, `AcpSessionOptionsService(` ×18,
  `AcpEventMapper(` ×22, `AcpLaunchSpec(...)` ×21 → `buildTestAcpPlugin({cwd,
  …overrides})` and `testAcpCollaborators(cwd)` in `acp/lib/src/testing/`.
- Pi: `PiSessionStorageApi` fakes ×4 → `test/support/`.
- Verify: `dart test` in opencode, acp, cursor, omp, hermes, pi.

### Step 12 — module_core test helpers and harnesses

- Add to `client/module_core/test/helpers/test_helpers.dart`: `MockAuthSession`,
  `FakeAuthSession`, `MockLifecycleSource`, `MockPermissionRepository`,
  `MockNotificationCanceller`, `MockSessionDetailLoadService`,
  `MockRelayHttpApiClient`, `MockRoomKeyStorage`, `InMemorySecureStorage`,
  `FakePushMessagingSource`; remove the redefinitions (`MockFailureReporter`
  ×5, `MockConnectionService` ×4, `MockProductAnalyticsService` ×5,
  `FakeLifecycleSource` ×3, `AuthSession` fakes ×15, …).
- `test/cubits/session_detail/session_detail_test_support.dart` with
  `buildSessionDetailCubit({…named overrides})` replacing 28 long-hand
  constructions in six files; `test/capabilities/server_connection/connection_service_test_support.dart`.
- Verify: `dart test` in `client/module_core`.

### Step 13 — module_core testing library and test relocation

- `client/module_core/lib/testing.dart` exporting data factories
  (`testSession`, `testProject`, `testHealthResponse`, …), `FakeLifecycleSource`,
  `FakeSessionUnseenTracker`, `MockSseEventTracker`, `MockRouteSource`,
  `delegateSessionRepositoryToService`, `registerCoreFallbackValues`, so
  `client/app/test/helpers/test_helpers.dart` (868 lines, 0.63 shingle
  containment with the module_core helper and already diverged) keeps only
  app-only mocks. `mocktail` becomes a regular dependency of module_core for
  that library; call it out in the PR.
- Of the 16 files under `client/app/test` that import
  `package:sesori_dart_core/src/...`, move the 13 pure-Dart ones (relay client,
  room-key storage, connection service/config/SSE event, voice API, relay HTTP
  client, connection-overlay cubit, login cubit, session-detail cubit, plus the
  converter and concurrency tests that Steps 2/30 delete) to
  `client/module_core/test` on `package:test`; the two app widget tests
  (`diff_hunk_widget_test.dart`, `diff_line_widget_test.dart`, which use
  `testWidgets` and `package:sesori_mobile`) and the app helper stay in
  `client/app` and stop deep-importing `src/` where the testing library makes
  that possible; then prune the exports in `lib/sesori_dart_core.dart` with no
  production consumer
  (`notification_api.dart`, `plugin_preference_api.dart`,
  `plugin_preference_repository.dart`, `bridge_repository.dart`,
  `product_analytics_preference_models.dart`,
  `session_options_repository_result.dart`, `session_list_item_state.dart`,
  `analytics_delivery_result.dart`, `plugin_discovery_snapshot.dart`,
  `relay_config.dart`, `session_options_request_mode.dart`, `sse_event.dart` —
  re-verify each after the move).
- Verify: `dart test` in module_core; `flutter test` in `client/app`.

### Step 14 — test timing

- 187 real-duration sleeps (`session_detail_stale_test.dart` 15 waits of
  120–300 ms, `connection_service_reconnect_test.dart` 2×1,400 ms,
  `bridge/app/test/bridge/foundation/process_runner_test.dart` 2×3 s,
  `codex_desktop_app_locator_test.dart` 1,100 ms,
  `orchestrator_token_reauth_test.dart` 5×200–300 ms, app
  `session_detail_cubit_test.dart` 18 waits, `session_detail_cubit_permission_test.dart`,
  `sse_event_tracker_test.dart`, `session_tile_menu_test.dart` 1 s).
- Drive time through the injectable clocks (`ServerClock` in bridge;
  `ClockProvider` in module_core, whose `_TestClockProvider` is already defined
  twice) or `fakeAsync`; one `awaitState<S>(cubit, predicate)` helper per
  package replaces the private `_awaitLoaded` ×6, `_settle` ×4, `_waitFor*` ×4.
- Verify: run each touched suite three times locally (`dart test -j1`) before
  relying on CI; no production change.

### Step 15 — bridge/app tracked-work helpers and logging consistency

- `PendingOperations` in `bridge/sesori_bridge_foundation` beside `ParallelLock`
  (it is used by the app and, in Step 28, by the Claude and Pi plugins, so the
  audience rule puts it in the foundation package, not under the app): surface
  `track({required Future<void> operation})`, `drain()`, `isEmpty`, `length`
  (required named parameters per the repository convention); `drain()` awaits
  `Future.wait` (default `eagerError: false`) over the futures tracked at call
  time — it completes only after every captured operation has settled, then
  surfaces the first error, so disposal never closes a database or stream
  while a tracked write is still running — and does not await futures tracked
  afterwards; exactly what the copies do today, including the orchestrator's
  shutdown summary that reads the count. It
  replaces the identical `Set<Future<void>>` + `whenComplete(remove)` +
  `Future.wait` + memoized dispose skeleton at `listeners/chat_history_listener.dart`,
  `chat_history_activity_listener.dart`, `session_options_changed_refresh_listener.dart`,
  `session_options_creation_refresh_listener.dart`, `viewed_project_pr_refresh_listener.dart`,
  `debug_server.dart`, twice in `orchestrator.dart`, `session_creation_service.dart:20`,
  and `session_operation_dispatcher.dart:15-16` (drain semantics unchanged).
- `push_session_state_tracker.dart:33-37,506-509` role strings
  (`"assistant"/"user"/"error"`) → enum ("No Magic Strings").
- Session-options refresh listeners (`session_options_changed_refresh_listener.dart:53-82`,
  `session_options_creation_refresh_listener.dart:43-68`) share one outcome
  handler or move outcome logging into `SessionOptionsService`.
- Consistency bucket: 26 `Log.x("… $e")` interpolations → logger arguments;
  `.catchError((_) {})` at `orchestrator.dart:1528`, `bridge_event_mapper.dart:195`,
  `sse_manager.dart:212` unified with the logging variant; four clock sources in
  `Orchestrator.create` → one; `SesoriServerApi` constructed twice with identical
  args; duplicated `reconcile()` try/catch in the runner; stale "Phase 2 (PR
  2.7)" text; `plugin_runtime.dart:1848-1853` three nullable subscriptions →
  one `CompositeSubscription` per generation; `bridge_event_mapper.dart:25-28`
  builds SSE JSON maps and re-parses them — construct the `SesoriSseEvent`
  variants directly.
- **Verify first:** the push `requestID→sessionID` maps
  (`push_session_state_tracker.dart:10,70-73,366-377,415`,
  `completion_notifier.dart:22,65-66,122-126`) exist only to recover a session
  id that `SesoriPermissionReplied.sessionID` (required, non-null) already
  carries; delete them only after confirming every plugin emits the same
  `sessionID` on Asked and Replied.
- Verify: `test/listeners/*`, `test/bridge/debug_server_test.dart`, orchestrator
  shutdown/event-ordering tests, `test/push/*`, `test/bridge/sse/*`,
  `orchestrator_emit_bridge_event_test.dart`; `sesori_bridge_foundation`
  tests for `PendingOperations`.

### Step 16 — PluginRuntime command preamble

- `bridge/app/lib/src/bridge/runtime/plugin_runtime.dart:717-816` (`_stop`),
  `:818-910` (`_prepareDisable`), `:957-1073` (`_restart`) repeat the ~50-line
  guard ladder (shuttingDown → accessGate → `forceCanTakeOverTransition` →
  `commandTransitionOwner` → hadPlugin/leaseCount → busy → workStateUnknown),
  the owner/completer/transition setup, and the `finally` reset; `stop/
  prepareDisable/restart` are pass-throughs with one caller each; `use` is
  `useWithGeneration` minus `.value`.
- Change: `_stopPreconditionConflict({slot, intent}) → PluginRuntimeCommandResult?`;
  `_beginCommandTransition`/`_settleCommandTransition`; fold the wrappers;
  implement `use` via `useWithGeneration`; model `commandTransitionOwner` +
  `commandTransitionCompleter` (`:1838-1839`, checked together at `:935-942`)
  as one nullable `_CommandTransition` record so owner-without-completer is
  unrepresentable.
- Verify: `test/bridge/runtime/plugin_runtime_test.dart`,
  `test/helpers/plugin_runtime_test_support.dart`,
  `test/services/plugin_lifecycle_service_test.dart`.

### Step 17 — Orchestrator and PluginLifecycleService

- Orchestrator: `:1394-1401` repeats the check at `:1366-1372` with no await
  between; the inline `generation != null && !_pluginRuntime.isCurrentEvent`
  block ×4 while `_isCurrentSource` (`:1690-1702`) encodes it; `String? pluginId`
  in four signatures although `NormalizedSourcedBridgeEvent.pluginId` is
  non-null; `_startAndServe :963-1036` wraps listener wiring and summary
  building in one "failed to connect to relay" catch that drops type and stack
  (narrow it to `connect()`); three `CompositeSubscription`s cancelled together
  → one; `pluginEventListeners` one-element list; `_pushDispatcher` held only
  for a no-op `dispose` chain.
- `PluginLifecycleService`: `registerPlugins` is called once, immediately after
  construction (`bridge_runtime_runner.dart:661-681`), yet populates five
  nullable fields re-checked at ~10 sites → take `plugins` in the constructor;
  `_publishReadyPluginIds` hand-rolls list equality (`ListEquality` imported);
  `_mapStopIntent` and the runtime→lifecycle state switch duplicated;
  `updateIdleTimeout` calls `_requireBridgeId()` three times. ~20 test call
  sites switch to a constructor argument. `PluginLifecycleSnapshot`
  (`repositories/plugin_lifecycle_repository.dart:5-17,82-97`) duplicates
  `PluginRuntimeSnapshot` except `transition` → `transitionSettled: bool`; the
  repository stays and returns the runtime snapshot ("No Redundant Model Layers").
- Verify: `test/bridge/orchestrator_*_test.dart`, `test/push/*`,
  `test/services/plugin_lifecycle_service_test.dart`,
  `test/bridge/routing/get_plugin_setup_handler_test.dart`.

### Step 18 — bridge auth consolidation, abortable requests, encryptor ownership

- Auth-backend URL trailing-slash normalization copied in `auth/validate.dart:28`,
  `token_manager.dart:92-94`, `login_email_api.dart:8`, `login_oauth_api.dart:9`,
  `bridge_registration_api.dart:20-22`, `profile.dart:11`,
  `push/push_notification_client.dart:34`, `api/sesori_server_api.dart:53` →
  normalize once in `BridgeCliOptions.resolveAuthBackendUrl`.
- `sesori_server_api.dart`, `token_manager.dart`, and
  `bridge_registration_api.dart` each hand-roll completer + deadline timer +
  `http.AbortableRequest` + finally-cancel (PR #1017 finding F5) → one final
  class `AbortableRequestClient` in the app's Layer-0
  `bridge/app/lib/src/foundation/abortable_request_client.dart` (every consumer
  is in `bridge/app`; no plugin uses it, so by the audience rule it does not
  belong in `sesori_bridge_foundation`) with
  `Future<http.Response> send({required http.Client client, required String
  method, required Uri url, required Map<String, String>? headers, required
  Object? body, required Duration deadline, required AbortSignal? abortSignal})`
  that builds the combined abort trigger (deadline plus optional external
  signal), buffers the response via `http.Response.fromStream` inside the
  deadline, checks `AbortSignal.isAborted` first and subscribes/unsubscribes in
  its finally path; callers keep status handling and retry policy.
- `TokenValidationResult.isValid` (`auth/validate.dart:10-17`) → sealed
  `Valid(tokens)` | `Invalid`.
- One `SessionEncryptor` per session (built in `Orchestrator.create`, required
  by `OrchestratorSession` and `SSEManager`; delete `setRoomKey`, the nullable
  room key, the lazy init, and `KeyExchangeManager`'s never-injected optional
  `cryptoService`). Same key, cipher, and per-call random nonce; confirm the
  `package:cryptography` nonce policy in the PR. Optionally build
  `KeyExchangeManager` in `create` as well so `OrchestratorSession` no longer
  carries raw key bytes only for `_startAndServe`.
- POST `/auth/refresh` + `AuthResponse.fromJson` exists at
  `auth/token_manager.dart:92-113` and `auth/validate.dart:60-90`; GET
  `/auth/me` at `validate.dart:28-49` and `profile.dart:10-24`; `validate.dart`
  hand-rolls a non-singleflight refresh so startup can refresh through two code
  paths; `runtime/bridge_runtime_auth.dart:61-112` loads tokens twice with
  duplicated `PathNotFound/FileSystem/Format` ladders; `auth/token.dart:76-94`
  and `auth/bridge_id_storage.dart:25-37` repeat the create-dir/chmod 700/
  write/chmod 600 sequence.
- Change: rename `TokenManager` to `TokenService` (the class orchestrates token
  storage, refresh HTTP, and now validation — the Layer-3 `Service` suffix;
  `Manager` is forbidden by `bridge/AGENTS.md`; four lib files and two test
  files reference it), fold `validateToken` into it (probe `/auth/me`; on 401
  `getAccessToken(forceRefresh: true)`); `fetchUsername` reuses the `/auth/me`
  helper; delete `validate.dart`; `ensureAuthenticated` loads once; one
  `writeRestrictedFile`. Retry-once semantics and file modes are preserved
  exactly. A shared client/bridge auth policy is explicitly not built.
- Verify: `test/auth/*`, `test/bridge/runtime/bridge_runtime_auth_test.dart`,
  `test/push/push_notification_client*`, CLI options tests,
  `test/bridge/sse_manager_test.dart`, `key_exchange_test.dart`, orchestrator
  relay tests, `bridge/app` unit tests for `AbortableRequestClient` (deadline,
  external abort, cleanup without leaked listeners), plus a manual bridge start
  with an expired access token.

### Step 19 — routing layer

- `bridge/routing/request_handler.dart:33-61` and `:93-127` are two ~30-line
  try/catch chains identical except the `StaleSessionPromptOptionsException`
  arm; `request_router.dart:70-97` is a third copy that maps unknown errors to
  502 where the handlers map to 500; 30 `if (x.isEmpty) throw
  buildErrorResponse(request, 400, "empty … id")` guards; 59 `pathParams/
  queryParams/fragment` declarations in `handle()` signatures used by three
  handlers (`fragment` by none); eight inline `RelayResponse(status: 409/400,
  headers: {"content-type": …}, body: jsonEncode(...))` duplicating
  `buildArchivedRejectionResponse`/`buildStaleOptionsRejectionResponse`.
- Change: one `_guard` on `RequestHandlerBase`; router keeps unmatched/invalid
  target handling plus a last-resort catch with the same 500 shape;
  `requireNonEmpty(request, value, label)`; drop `fragment` and unused
  `queryParams`; one `buildJsonErrorResponse(request, status, json)`.
- Behavior change: unknown-error status unified to 500. **Verify first** that no
  client path branches on 502 (`SafeApiClient`/`RelayHttpApiClient` error
  mapping); if one does, keep 502 and note it.
- Verify: `test/bridge/routing/*`, `test/routing/*`, `request_router_test`.

### Step 20 — SessionRepository, enrichment, pending interactions

- `session_repository.dart`: `_requireBinding → _runtime.use →
  _primeDerivedSessionDirectory` preamble ×7 (`:282-295, 312-346, 348-378,
  423-437, 567-588, 984-997, 999-1012`) → one `_useSessionPlugin`;
  `PromptModel→(providerID, modelID)` switch ×3 beside the existing
  `_toPluginVariant`; `getExistingSessionIds`/`getArchivedSessionIds` same
  500-chunk loop; `findProjectIdForSession` + `getSessionForProject`
  (`:959-974`) used only by `get_session_handler.dart:36-60`, which re-reads the
  row it just read → one `getCatalogSession`; `_requireBinding` duplicated in
  `question_repository.dart:297-309` and `permission_repository.dart:113-125`;
  `_generateSessionId` duplicated in `catalog_import_repository.dart:564-573`;
  placeholder `ProjectDto(hidden: true, createdAt: 0, …)` literal ×3.
- `enrichSessions` (`:1070-1109` → `mappers/plugin_session_mapper.dart:6-63`):
  its only production caller `get_sessions_handler.dart:95,131` passes sessions
  already produced by `SessionCatalogMapper.map` from the same rows, so it
  re-reads rows and re-applies title/time/hasWorktree/promptDefaults/unseen/
  lastUserActivityAt/projectID it already has; `adoptStoredProjectId`/
  `bridgeDerivedProjectPluginIds` (`:75,85,1104`, wired at
  `orchestrator.dart:217`) exist only for that no-op branch → `enrichSessions`
  = fetch visible PRs + `copyWith(pullRequest:)`; delete the mapper, the
  parameter, and its wiring (one fewer DB round-trip per `/sessions`).
- `PermissionRepository` is ~85% a copy of the question half of
  `QuestionRepository` (`:22-52`≈`:27-59`, `_isVisible`, tombstone guard,
  `_mapPending*`) → one same-layer file
  `repositories/pending_interaction_support.dart` holding the bridge-local
  `({id, sessionID, displaySessionId})` projection record and the shared
  binding/visibility/tombstone/mapping helpers, imported by both repositories;
  neither repository depends on the other; no plugin-boundary change.
- Small items: `session_repository.dart:1035` `on Object { return … }` drops
  error and stack (sibling logs) → `Log.w`; `api/bridge_settings_api.dart:26-39`
  and `bridge/persistence/bridge_diagnostics.dart:44` read `HOME`/`USERPROFILE`
  directly → `resolveUserHomeDirectory`; `ProjectActivity` ≡ shared
  `ProjectTime` (use it); `PullRequestTargetSelected` copies eight
  `GhPullRequest` fields (carry the DTO + target); `session_dao.dart:168-176`
  decides `preservePullRequestScope` inside a DAO → move to the repository.
- **Verify first — inner generation fences:** `commitCurrentGeneration`
  (`plugin_runtime.dart:317-349`) already refuses stale generations, holds a
  lease and `durableCommitCount` during the callback (`:1295-1310`), and
  re-checks after; the repository callbacks re-check anyway
  (`session_repository.dart` ×10, `catalog_import_repository.dart` ×6,
  `project_activity_repository.dart` ×2). Delete the 18 inner checks only if
  `_waitForDurableCommits` provably gates every generation bump, naming the
  await boundary that makes each removed check dead in the tracker; otherwise
  keep them and record why.
- Verify: `session_repository_test` (incl. `enrichSessions` cases `:395-639`
  and the observed-projection cases), `plugin_runtime_test` generation cases,
  `get_session_handler_test`, `get_sessions_handler_test`,
  `catalog_import_repository_test`, both pending-interaction repository tests,
  `get_session_permissions_handler_test`, `reply_to_question_handler_test`.

### Step 21 — FIFO lanes on `ParallelLock`

- Hand-rolled "await previous; try; finally release" tails with divergent error
  policy: single tails at `project_mutation_service.dart:25,65-69`,
  `project_activity_service.dart:19,167-174`, `session_unseen_service.dart:57,361-374`,
  `bridge_settings_repository.dart:19,84-111`, `chat_history_service.dart:55,209-240`,
  `plugin_lifecycle_service.dart:108,670-679` (found during Step 21's
  re-verification); keyed tails at `session_options_service.dart:170-199`,
  `chat_history_service.dart:824-858` (`_enqueueRead`/`_enqueueAll`
  near-duplicates), `session_event_dispatcher.dart:108-147`, and
  `server/api/runtime_file_api.dart:23,95-112` (also found during
  re-verification).
  `sesori_bridge_foundation/lib/src/parallel_lock.dart:5-43` is an error-safe
  FIFO lane used once (`project_repository.dart:33`).
- Change: Phase A — six single tails → `ParallelLock(maxParallelOperations: 1)`
  plus a new `Future<void> get idle` on `ParallelLock` that resolves when no
  operation is running or queued at call time (later enqueues are not awaited —
  the same meaning as today's `await _writeTail` at dispose); Phase B — a
  `KeyedParallelLock<K>` in `sesori_bridge_foundation` beside `ParallelLock`
  (`use({required K key, required Future<T> Function() operation})`, per-key
  `idle`, entries removed when idle — required named parameters like the
  existing `ParallelLock.use(operation:)`) for the
  four keyed sites (including the already key-scoped session-options
  invalidations); `ChatHistoryService._enqueueAll` stays a private method of
  that service expressed as ordered acquisition of the per-key locks, and
  `_enqueueRead` becomes a one-line `use`. Every replaced tail already
  released its lane on failure, so the lock's error-safe release preserves
  behavior; what the caller observes (rethrow, swallow-and-log, or stream
  error) stays per site. `SessionOperationDispatcher` lanes,
  the orchestrator per-plugin lane, and the three dispatchers are not merged
  (different domains; only the idiom overlaps).
- **Verify first — options-epoch re-checks:** `SessionOptionsService`
  `_isCurrentInvalidationEpoch` ×18 between pure reads (`:274,329,336,341,
  437,454,466,531,537,541`, …); the only side effect the epoch protects is
  `_repository.commit`, and `_tryCommit:454-461` already compensates a commit
  that raced an invalidation. Check at entry and immediately before commit and
  keep the post-commit compensation — only if the owner accepts that a
  just-invalidated retained snapshot may be served once (self-correcting via
  forced discovery); otherwise keep and record.
- Verify: `project_mutation_service_test`, `session_unseen_service_test`,
  `bridge_settings_repository_test`, `chat_history_service_test`,
  `session_event_dispatcher_test`, `session_options_service_test` invalidation
  cases, `plugin_lifecycle_service_test`, `runtime_file_api_test`,
  plugin-event-listener integration tests; FIFO and drain semantics are
  the review focus. The unified error policy is recorded against
  `bridge-connectivity.md`/`session-creation-and-options.md` in the same PR
  where it changes an observable outcome.

### Step 22 — updater/server helper dedupe and platform trios

- Updater/server copies: `_parseCsvLine` ×2 (`process_id_lookup_api.dart:88-116`,
  `system_process_api.dart:226-254`); `_isFileMissing`/`_isPermissionDenied`
  (`runtime_file_api.dart:217-225`, `update_lock.dart:279-297`,
  `update_install_service.dart:112-120`) → `FilesystemPermissionValidator`;
  `UpdateLock._cleanupPath` and both `_deleteIfExists` → `FilesystemCleaner`,
  which moves from `updater/foundation/` to the app's Layer-0
  `lib/src/foundation/` beside `FilesystemPermissionValidator` because
  `server/api/` now consumes it too; one `isTransientNetworkError` beside
  `isRetryableHttpStatus` replacing the four `SocketException/TimeoutException/
  HttpException/ClientException` ladders; one `UpdateResult.userFacingReason`
  for the duplicated `_stageFailureReason`.
- Impossible states: `UpdateInstallResult` → sealed `Staged(path)` |
  `StageFailed(result)` (removes the `result != success || stagingPath == null`
  checks and the `case success: 'an unexpected error'` arms);
  `UpdateResolution.latestEligible/latestVersion` (always both null or both set)
  → one nullable record.
- `DefaultEditorRepository` (single pass-through over `DefaultEditorApi`; PR
  #1017 finding F4) → fold `openFile` into `BridgeSettingsRepository` as
  `openInDefaultEditor(...)` (that repository already owns the config-file
  lifecycle), `BridgeConfigService` drops the second dependency; layering stays
  API → Repository → Service; delete the file, its DI registration, and its fake.
- Platform trios → sealed private implementations per `bridge/AGENTS.md:132-138`:
  wake lock (`api/wake_lock_client.dart` + three impls) and default editor
  (`api/default_editor_api.dart` + three impls); one `ProcessStarter`/
  `WarningLogger` typedef; `SleepPreventionService` loses its default `Log.w`
  dependency.
- Verify: `test/updater/*`, `test/server/*`, the three wake-lock tests, editor,
  bridge-config/settings-repository, and sleep-prevention tests.

### Step 23 — contract dead members and `PluginProvider`

- `BridgePluginApi.dispose()` (`bridge_plugin.dart:249-256`, "will be removed
  once the bridge core stops calling it") — core no longer calls it
  (`orchestrator.dart:1123-1124`); `healthCheck()` has zero production callers
  in `bridge/app`, client, or shared (7 implementations, 18 test files);
  `PluginAgentVariant` referenced only in its own file; `PluginApiException`
  used only by OpenCode → move there; `OpenCodePlugin.autoInitialize`
  (`opencode_plugin_impl.dart:38,64-73,121-130`) only ever `false`.
- `PluginProvider` (`sesori_plugin_interface/lib/src/models/plugin_provider.dart:30-125`)
  is a 10-way sealed union whose variants carry identical fields and are never
  discriminated (`authType` has zero consumers; the app mapper reads
  `id/name/defaultModelID/models` only); producers
  `pi_backend_catalog_repository.dart:264-330` and opencode
  `provider_mapper.dart:103-170` are two 65-line id→variant switches → one
  class; both producers become one constructor call; ~1,000 generated lines go.
- `PluginSetupStatus.versioned` triplicated `_Versioned*` subclasses with
  hand-written `==/hashCode/toString` (`plugin_setup_status.dart:39-59,84-109,133-153`)
  → keep the type-level distinction but stop hand-writing it: compose one
  sealed version-presence value (`RuntimeVersionPresence {known(version),
  unknown}`) on the variants that can carry a version, or generate equality
  for explicit versioned variants — never a nullable `runtimeVersion` on every
  variant, which would let a runtime-missing status carry a version.
- Dead seams: `sessionIdFor` (`acp_approval_registry.dart:200`,
  `codex approval_registry.dart:169`) and never-injected `idGenerator`
  (`acp:51-95`, `codex:84-92`, `cursor:23`); `defaultClaudeProcessFactory`
  (`claude_process_factory.dart:96`), `defaultPiProcessFactory`
  (`pi_process_factory.dart:80`) zero references; `AcpStdioClient.processFactory`
  required instead of `?? defaultAcpProcessFactory` (check how many of the 23
  test constructions rely on the default).
- Stale migration comments (`open_code_ownership_record.dart:15-25`,
  `open_code_runtime_policy.dart:13-22`, `opencode_plugin.dart` barrel,
  `managed_runtime_spec.dart:39-43`, `managed_runtime_monitor.dart:16-20`,
  `runtime_record_mapper.dart:3-5`); `hermes_identity.dart:3-5` wrongly says
  pi/omp are absent from `Harness`; identity literals vs `Harness.x.name`
  (optional consistency).
- Verify: interface suite, opencode plugin tests, pi catalog repository tests,
  `get_providers_handler_test`, `session_options_repository_test`, the 18
  `healthCheck` test deletions, `dart analyze --fatal-infos` in every bridge package.

### Step 24 — runtime dual-mode knobs

- `bridge/sesori_plugin_runtime/lib/src/managed_runtime_spec.dart:39-59`
  (`RuntimeHealthPolicy.attemptCount`, 0 production uses), `:78-87`
  (`RuntimeRecordTiming.afterSpawn`, 0 uses), `:94,114` `preProbeBindable` and `:105,140`
  `failFastOnSpawnError` (both descriptors pass `true`), `:176` `validateRuntime`
  (never set), `:180` `failOnEarlyChildExit` (`true` in both);
  `managed_process_service.dart` branches at `:173-182, 228-230, 247-260,
  268-271, 280-282, 301-303, 313-317, 322-333, 353-355, 382-395, 431`.
- Change: delete the unused variants; make the single production behavior
  unconditional; rewrite the migration-era doc comments. Stays inside
  `sesori_plugin_runtime`; no persisted-schema change.
- Verify: runtime suite (`managed_runtime_monitor_test`,
  `managed_process_service_start_test`), codex/opencode descriptor and
  runtime-policy tests.

### Step 25 — Codex/OpenCode managed-runtime fold

- Name-normalized diffs: `codex_status_reporter.dart:1-93` ≡
  `open_code_bridge_plugin.dart:11-94` except codex's `markDisconnected`
  suppression (drift: the fix exists only in codex); `codex_bridge_plugin.dart:10-134`
  vs `open_code_bridge_plugin.dart:95-224` (ordered shutdown byte-equivalent;
  opencode adds an attach-mode guard); `codex_managed_api.dart` ≡
  `open_code_managed_api.dart`; `_DrainingCodexProcess`
  (`codex_runtime_policy.dart:195-240`) ≡ `_DrainingOpenCodeProcess`
  (`open_code_runtime_policy.dart:249-296`); `codexDynamicCandidates` vs
  `openCodeDynamicCandidates` (second drift: only codex has the bounded-draws
  fix); descriptor `start()` tails (`codex_plugin_descriptor.dart:468-629` vs
  `open_code_plugin_descriptor.dart:525-790`): service construction, port
  policy, reporter/monitor/api/wrapper assembly, bounded cold start, late-abort
  rollback ≈ 120 lines the same modulo names.
- Change (in `sesori_plugin_runtime`): `DrainingSpawnedProcess` +
  `dynamicPortCandidates(...)`; `ManagedRuntimeStatusReporter` (codex's variant);
  a lifecycle-only `ManagedRuntimeApi` plus generic
  `ManagedRuntimeBridgePlugin<R, A>` with an owned-only-interrupt option for
  OpenCode attach mode. `BridgePluginApi` is sealed around project ownership,
  so the lifecycle API remains a separate facet rather than becoming another
  project-ownership subtype. Re-verification found that descriptor startup is
  no longer one invariant: OpenCode now has attach, unreachable/degraded, and
  nullable-handle branches with different rollback ownership, while Codex is
  managed-only. The planned `startManagedRuntimePlugin(...)` helper is therefore
  dropped instead of flattening those policies into flags. Descriptors keep
  config parsing, all startup/abort/rollback orchestration, OpenCode
  attach/degraded branches, and spawn/probe seams. Ownership-record unification
  (JSON keys in
  `codex-processes.json`/`opencode-processes.json`) is **deferred** to the D1
  decision.
- Verify: runtime suite; `codex/test/runtime/*`; `opencode/test/runtime/*`;
  start/shutdown ordering is the review focus.

### Step 26 — descriptor setup and installation

- Re-verification found five structurally similar, but not identical,
  `installRuntime` pipelines (Cursor, OMP, Pi, Codex, OpenCode), five managed
  install capability checks, and duplicated setup probing/selection across the
  same descriptors. OMP resolves Linux assets asynchronously from host libc;
  install executors use different capture policies; and every descriptor owns
  an `http.Client` whose lifetime spans the install stream. The planned install
  factory would therefore either leak ownership or flatten real policy. The
  executor count is now 24 production constructions and `64 * 1024` has broader
  plugin-specific uses, so neither an executor factory nor a shared probe-limit
  constant is justified. Cursor, Codex, and Hermes retain byte-identical CSI
  stripping, while Claude has the existing stronger CSI+OSC variant.
- Change (runtime package): add sealed mechanical probe outcomes
  `RuntimeProbeReady(version)`, `RuntimeProbeMissing`, `RuntimeProbeTimedOut`,
  `RuntimeProbeNonZeroExit`, `RuntimeProbeUnrecognized`, and
  `RuntimeProbeFailed` from `RuntimeVersionValidator.probe()`. Outdated is not a
  raw probe outcome because minimum-versus-exact acceptance belongs to runtime
  selection policy. Add `ManagedRuntimeSelectionService` owning only explicit
  → PATH → fallback candidates → managed precedence, abort boundaries, selected
  source/path/version, and minimum-versus-exact managed-version policy. It
  receives only an injected validator and manifest. Its `select({required
  String? explicitExecutablePath, required List<String>
  fallbackExecutableCandidates, required Map<String, String> environment,
  required String stateDirectory, required StartAbortSignal abortSignal,
  required ManagedRuntimeVersionPolicy managedVersionPolicy})` accepts neutral,
  already-parsed candidates: each descriptor trims/interprets its own `--bin`
  config first, and Codex resolves desktop-app paths before calling it. The
  result is sealed selected/not-selected data with a neutral source
  (`explicit`, `path`, `fallback`, `managed`), selected path/version, rejected
  PATH version when present, and either the mechanical probe failure or rejected
  version that prevented selection. The service takes no `PluginConfig`,
  platform locator, process service,
  capture limit, auth callback, hint strings, or `PluginSetupStatus` vocabulary.
  `ManagedRuntimeProvisionService` consumes the same selection seam; Codex's
  duplicate selection service is removed. Descriptors continue mapping neutral
  selection/probe outcomes to their exact existing setup variants and hints,
  and keep backend-specific authentication checks.
- Add `RuntimeManifest.supportsManagedInstallOn({required PlatformTarget
  target})` with the synchronous `assetFor` default; OMP overrides it with its
  libc-aware capability rule. Keep install composition local so each descriptor
  visibly owns asset resolution, output policy, and HTTP client disposal. Add
  foundation `stripAnsi()` using the existing CSI+OSC behavior and migrate the
  Cursor, Codex, Hermes, and Claude ANSI-stripping copies. Version-probe logic
  remains descriptor-local where it differs: Hermes probes
  `hermes acp --version` and interprets backend-specific non-zero output, while
  Claude and DeepSeek remain custom/no-manifest probes. No generic
  `inspectSetup`, auth callback, hint table, install factory, executor factory,
  or shared output-limit constant is introduced.
- Preserve each descriptor's explicit-bin authority, selected runtime version,
  installability, unknown/outdated/missing classification, auth behavior, and
  setup hint text. In particular Cursor's managed setup accepts its current
  minimum-version rule, OMP/Pi/Codex/OpenCode keep exact pinned-managed checks,
  OpenCode attach mode remains unprobed ready, and abort still throws
  `PluginStartAbortedException`.
- Verify: descriptor/setup tests in cursor, omp, pi, codex, opencode, hermes;
  runtime probe/selection/provisioning tests; foundation ANSI tests and Claude's
  OSC coverage; `PluginSetupStatus` wire shape unchanged.

### Step 27 — pending-permission registry base

- Current re-verification finds `acp_approval_registry.dart` and Codex
  `approval_registry.dart` still duplicate bridge-request-id allocation,
  pending storage keyed by bridge id, typed stream attachment/disposal,
  session/project snapshots, pending-input queries, reply/reject removal,
  clearing SSEs, per-session cancellation, and settle-all disposal. Their JSON
  parsing, request classification, wire responders, permission summaries, and
  question builders are not the same invariant and stay local. Claude remains
  structurally different: response delivery can fail without consuming an
  entry, it owns allowed-tool/denial state and project-update events, and it has
  no request stream or JSON-RPC responder.
- Change: add `PendingPermissionRegistry<TRequest, TPayload>` in
  `sesori_plugin_interface`, the contract-owning layer that already hosts
  implementor support such as `SteadyPluginLifecycle` and
  `PluginStatusController`. It owns only generated `br-N` ids, opaque payload
  storage alongside exact `PluginPendingPermission`/`PluginPendingQuestion`
  snapshots, request-stream subscription, session/project queries,
  `hasPendingInput`/`hasAnyPendingInput`/pending session ids, removal on
  reply/reject, contract clearing events, session cancellation, and settle-all
  disposal with observable recovered failures. Protected registration methods
  allocate the id, store one permission/question snapshot atomically, emit the
  corresponding asked event, and return the id. Each private entry contains
  only the opaque `TPayload` and one permission/question contract snapshot.
  Subclasses implement request dispatch and supply typed protocol callbacks for
  permission reply, question reply, question rejection, and cancellation. Neutral
  cancellation-reason and question-reply-outcome enums let those hooks choose
  protocol responses without exposing ACP/Codex ids, methods, params, or
  builders to the interface package. Ordinary reply/reject removes the entry
  before invoking its protocol hook, preserving current ACP/Codex behavior: a
  thrown responder consumes the entry and emits no clearing SSE. Cancellation
  and disposal catch and log each failed protocol resolution, continue settling
  the remaining entries, and emit each contract clearing event independently.
- ACP and Codex subclasses retain all request classification, session parsing,
  response payloads/errors, option selection, permission summaries, question
  builders, and malformed-answer behavior. An ACP invalid answer still consumes
  and declines the request, emits question rejection, and returns handled.
  `_asMap`/string parsing remain local for Step 28. `PluginPendingPermission`,
  `PluginPendingQuestion`, and `PluginPermissionReply` wire shapes are unchanged.
- `sesori_plugin_interface` remains the owner: the base depends only on Dart
  async and interface-owned contract/event/log types. Moving it into
  `sesori_plugin_runtime` would make ACP and its Cursor, OMP, Hermes, and DeepSeek
  consumers depend on managed-process supervision for unrelated approval state.
  There is no runtime-package fallback in this step.
- Move Cursor's fire-and-forget request acknowledgement/reinjection
  (`cursor/generate_image`, `cursor/update_todos`) and its notification sink out
  of the ACP registry into `CursorApprovalRegistry.handleExtensionRequest`.
  `CursorPluginImpl.buildApprovalRegistry` continues wiring
  `handleAgentNotification` into the Cursor-owned constructor callback. Cursor
  responds with the empty ACK before reinjecting an `AcpNotification`, catches
  and logs reinjection failure with the method/error/stack, and returns handled
  so one malformed notification cannot break approval routing. The ACP base,
  base `AcpPlugin`, and DeepSeek constructor contain no Cursor method set or
  notification callback. ACP's active-session fallback remains because
  DeepSeek now also relies on it. DeepSeek remains an ACP subclass and registers
  its questions through the shared engine; its DTO mapping and strict answer
  validation stay local.
- Doc comments on the `BridgePluginApi` question/permission methods state the
  pending-input lifecycle expectation (reply/dispose/cancel must resolve or
  log), per PR #1017 Step 8.
- Verify: focused interface tests for ids/storage/query/removal/events,
  cancellation isolation, disposal, and recovered-failure logging; ACP and
  Codex protocol integration tests; Cursor fire-and-forget/question tests;
  DeepSeek mapping/validation tests; Claude approval tests unchanged. Approval
  correctness is high-stakes, so every affected plugin suite remains required.

### Step 28 — small plugin helpers and lifecycle wrappers

- Re-verification retains exact small copies only. Claude and Pi duplicate the
  same first-error/all-cleanups shutdown sequence, process-spawn outcome, and
  global tracked teardown sets. Cursor and OMP duplicate ACP config-option
  selection and flattening. ACP/Codex/OpenCode share attachment base64
  normalization, ACP/Codex share MIME normalization, four GitHub manifests
  share release-asset URL assembly, and three plugins construct the same
  compaction command. Repeated text/reasoning/tool message parts and terminal
  tool-status checks remain byte-equivalent in Claude/Pi and their trackers.
- Add `PluginMessagePart.fromText/fromThinking/fromTool`,
  `PluginToolStatus.isTerminal`, `PluginCommand.compaction`, and neutral
  `ProcessSpawnOutcome` in `sesori_plugin_interface`. Add a protected
  `SteadyPluginLifecycle.runShutdownCleanups` that attempts every cleanup and
  rethrows the first error with its original stack. Claude and Pi use these
  primitives; their global tracked teardown sets use Step 15
  `PendingOperations`, while Claude's per-session map and Pi's per-session idle
  future remain local.
- Add `asStringKeyedMap` and `nonEmptyString` beside `jsonDecodeMap` in
  `sesori_shared`, and migrate only byte-equivalent consumers. Cursor's
  empty-string acceptance and OpenCode's empty-map fallback remain local. Add
  ACP-owned `AcpConfigOptionParser` for Cursor/OMP config options while keeping
  each plugin's output model local.
- Add pure attachment base64/MIME normalization in
  `sesori_plugin_interface/lib/src/messages/attachment_normalization.dart` and
  migrate exact ACP/Codex/OpenCode copies. Pi's variant stays local because its
  fallback contract differs. Claude/Pi DTO scalar parsers and Claude/Codex
  `_decodeErrorForLog` stay local because their validation and privacy behavior
  are not equivalent.
- Add `RuntimeManifest.githubReleaseAssetUrl` for OpenCode, Codex, OMP, and Pi;
  each manifest still owns its exact repository and tag (`v` versus Codex's
  `rust-v`), while Cursor's non-GitHub URL is unchanged. Add contextual logs to
  the remaining Codex swallow-and-continue catches. Collapse repeated stale
  selection exception construction only inside Claude and Pi.
- Verify: analyzers and full suites for shared, interface, runtime, ACP, Codex,
  Claude, Pi, Cursor, OMP, and OpenCode; architecture implementation review.

### Step 29 — stdio transport plumbing

- `acp_stdio_client.dart` (454), `codex_stdio_app_server_client.dart` (348),
  `codex_app_server_client.dart` (427), `pi_rpc_client.dart` (642),
  `claude_stream_client.dart` (407) each re-implement request-id allocation +
  pending-completer map + per-request timeout + "process exit fails all
  pending" (`_failPending` in all five) + stderr capture + SIGTERM/wait/SIGKILL
  dispose; `_redactForLog` byte-identical in claude and codex.
- Change: adopt the `NdjsonProcessClient` contract written for PR #1017 Step 7
  (it is the more complete design of the same consolidation): one final class
  in `sesori_plugin_runtime/lib/src/transport/ndjson_process_client.dart` —
  the plugin-only process-infrastructure package, chosen over
  `sesori_bridge_foundation` because the bridge app never uses a line-framed
  subprocess transport and over the contract package because it is stateful —
  with a minimal `NdjsonProcessHandle` interface (stdin sink, broadcast stdout
  and stderr line streams, done future, kill) and thin adapters for each
  plugin's handle type; `StderrPolicy {discard, forwardSanitized}` with
  adapter-owned sanitization; policy values `MalformedFramePolicy {discard,
  failPending}` (ACP/Claude discard, Codex fail all pending),
  `NonObjectFramePolicy`, `redactMalformedFrames`, `logTag`, and one injected
  `responseCorrelationId: Object? Function(Map<String, dynamic>)` so the
  transport holds no backend frame-shape knowledge; API `request`, `dispatch`
  (write acceptance separate from the correlated response, preserving ACP's
  prompt-accepted boundary), `sendFrame`, `notifications`, `isAttached`,
  `exit`, `reset({gracefulTimeout})`, `dispose({reason, gracefulTimeout})`, and
  pre-spawn `AttachToken beginAttach()` + `attach({token, process})` that
  rejects and reaps a superseded handle. ACP and Claude add the
  `sesori_plugin_runtime` dependency (direction stays plugins → runtime →
  interface/foundation; Codex already depends on it) and `bridge/AGENTS.md`'s
  module order is updated in the same PR. Preserved divergences are explicit
  constructor values; the one intended unification — teardown becomes
  close-stdin → short drain → terminate → timed force-kill for all adopters
  (ACP currently skips the stdin close) — is a recorded behavior delta. Pi's
  frame shape and `claude_stream_client`'s one-way stream adopt only the
  pending-request/lifecycle parts that fit; Codex's WebSocket client stays
  local. Transport hot path — land per plugin with green tests, after Step 8's
  fakes.
- Verify: `acp_stdio_client_test`, codex client tests, `pi_rpc_client_test`,
  `claude_stream_client_test`; fake-process round-trips for timeout, broken
  pipe, stale generation, kill ordering; each adopting plugin's protocol suite
  proves identical frame/error semantics (Codex fail-all-on-malformed, Claude
  redaction, ACP discard); the teardown-order delta is asserted intentionally.

### Step 30 — `SessionService` and thin services

- `client/module_core/lib/src/capabilities/session/session_service.dart` (149
  lines, 16 methods): only five are called (`markSessionSeen`, `archiveSession`,
  `renameSession`, `deleteSession`, `createSessionWithMessage`); eleven are
  unused pass-throughs; `SessionDetailCubit` already bypasses it; its only logic
  is `_resolveModel` + `command?.normalize()` (`:116-118, 138-140, 143-148`).
  Point `SessionListCubit`/`NewSessionCubit` at `SessionRepository`, move the
  two normalizations into the repository, delete the class, its DI
  registration, and the misnamed `slash_command_service_test.dart`; update ~8
  test files.
- `BridgeSettingsService` (34 lines of delegations) inlined per
  `client/AGENTS.md`; `SessionViewApi`+`SessionViewRepository` and
  `ProjectViewApi`+`ProjectViewRepository` (49 lines, 4 DI registrations) →
  one view-declaration API/repository; `ServerConnectionConfig.authToken`
  required (every caller passes non-null); `project_viewing_service.dart:111-161`
  claim lookup ×3 → `_withOwnedClaim`.
- Dead: `SessionListStaleProject` (`session_list_state.dart:43-48`, never
  emitted; two UI branches), `api/converters/http_method_converter.dart` + its
  app test, `ConnectionService.activeDirectory`/`setActiveDirectory` +
  `ProjectListCubit.setActiveProject` (write-only),
  `SessionDetailLoadResultLoaded.isBridgeConnected` (produced, never read),
  the `GoRouterNavigation` extension
  (`client/app/lib/core/routing/app_router.dart:245-253`, no callers), and the
  dead helper at `client/app/test/helpers/test_helpers.dart:535-537`.
- Layering fix (PR #1017 F12): `session_list_cubit.dart` imports
  `../../api/session_api.dart` only because `SessionCleanupRejection`/
  `SessionCleanupRejectedException` live there; `session_api.dart` keeps a
  private DTO parse of the 409 body and throws the API-layer exception carrying
  the DTO, `SessionRepository` maps it to a domain `SessionCleanupRejection` in
  `client/module_core/lib/src/repositories/models/session_cleanup_rejection.dart`
  (the domain exception keeps the original as a typed `innerError`), and the
  cubit drops the API import.
- `CompositeSubscription` adoption (PR #1017 F13) in `session_detail_cubit.dart`
  (five hand-tracked subscriptions), `plugin_management_cubit.dart`, and
  `diff_cubit.dart`, matching the sibling cubits.
- Verify: `build_runner` in module_core; `dart test test/cubits/session_list
  test/cubits/new_session test/capabilities`; `flutter test test/features/
  new_session test/features/session_list test/core/widgets` in `client/app`.

### Step 31 — `SessionDetailCubit` derivation and analytics

- Derivation duplicates: agent filter ×3 (`:520-522, 1766-1769, 2283-2286`;
  `SessionDetailSnapshot.agents` is `List<AgentInfo?>` though every source is
  non-null — type it), `assistantAgentModel` switch ×2, childIds/childStatuses
  ×2, `retryMessage` switch ×3, visible-queue trio ×8, "refresh ended" emit
  block ×4, `retryErrorMessage` a pure function of `sessionStatus`,
  `replyToQuestion`/`rejectQuestion`/`replyToPermission` (`:2063-2150`) same
  optimistic-resolve ladder ×3, hand-spelled snake_case of enum names, doc
  drift at `:122-130`. Change: `_deriveSnapshot` record, `_queueView`,
  `_emitRefreshEnded`, extension getter for `retryErrorMessage`,
  `_submitReply`, `.name`. Refresh coordination fields and triggers are
  untouched (owned by `session-refresh-reconnects`).
- Analytics: the once-per-inventory-state guard enum, fields, retry-on-
  activation subscription, and then/catchError machine are identical in
  `project_list_cubit.dart:35,49-50,190-246` and `diff_cubit.dart`;
  `_reportProductEvent` ×3, `_analyticsInputMode` ×2 → one per-cubit
  collaborator `LoadedStateAnalyticsReporter` under
  `client/module_core/lib/src/services/` (the home of existing per-instance
  collaborators such as `NewSessionSelectionTracker`), one instance per cubit,
  built in the shell's `BlocProvider(create:)` with
  `getIt<ProductAnalyticsService>()` and injected into the cubit as a required
  constructor dependency; it owns the guard state and the activation-retry
  subscription, so once-per-cubit-instance semantics are preserved and the
  singleton `ProductAnalyticsService` gains no caller state. `DiffCubit` then
  depends only on the reporter (its sole remaining analytics use);
  `ProjectListCubit` keeps the service as well where it reports other events;
  `_analyticsInputMode` beside `AnalyticsInputMode`.
- Catch hygiene: `.catchError((_) {})` at `session_detail_cubit.dart:812,1020`
  → the logging variant used elsewhere; `relay_client.dart:472-474`,
  `project_viewing_service.dart:279-281,306-308`, `project_list_cubit.dart:496`
  log without the error object → pass it; the `TimeoutException` fall-throughs
  move with Step 32.
- Verify: `dart test test/cubits/session_detail test/cubits/project_list
  test/cubits/session_diffs test/services/product_analytics_service_test.dart`;
  `flutter test test/features/session_detail`.

### Step 32 — list cubits and relay plumbing

- `session_list_cubit.dart:55-64,309-339,509-566` vs
  `project_list_cubit.dart:99-108,375-448,507-600`: `_reconnectIfNeeded`
  identical (incl. a silent `on TimeoutException catch (_)`), `retryLoad*`,
  `_onStaleReconnect`, `_activeRefresh ??=` coalescing, navigate-back `pairwise()`
  subscription; project "reorder + unseen + emit" ×4; session archive/delete
  optimistic flows ×2. Change: `ConnectionService.reconnectAndAwaitOutcome({timeout})`
  (logs the timeout), `_emitOrdered`, `_runOptimisticRemoval`; the route/refresh
  one-liners stay.
- `RelayHttpApiClient.get/post/postWithTimeout/patch/delete` are five 25-line
  copies (`headers:` never passed) → one `_request`; `_nextRelayRequestId` +
  counter + `Random` duplicated with `ConnectionService` → one generator;
  `ConnectionService` cancel-timer/complete pair ×4, "attempt superseded →
  bail" guard ×4, "clear connecting client, disconnect, generic error" ×4,
  backoff reset ×4 → small private helpers; `RelayClient` three identical
  `_close*Controller`s, framing re-implemented in
  `_sendEncryptedMessageWithEncryptor`, `sendSessionView`/`sendProjectView`
  twins, stale doc at `:833`; `ClockProvider`/`RelayClientFactory` need no DI
  registration. Strictly mechanical; no lifecycle change on the auth/crypto path.
- Verify: `dart test test/cubits/session_list test/cubits/project_list
  test/capabilities` (`connection_service_reconnect_test`, `_sse_test`,
  `_auth_state_test`, `relay_client_handshake_replay_test`); `flutter test
  test/capabilities test/core/api`.

### Step 33 — `NewSessionState` phase + configuration

- `cubits/new_session/new_session_state.dart:80-256`: `idle/sending/
  restoringSubmission/creationError/discoveryError` each carry the same six
  configuration fields; `agentModelData` spends 65 lines destructuring them; the
  cubit re-spells all six in `_emitConfigurationUpdate` (60 lines),
  `_emitDiscoverySuccess` (40), `_emitDiscoveryError` (50), `createSession`,
  `acknowledgeRestoredSubmission`.
- Change: `composing({config, phase})` | `created({session})` with sealed
  `NewSessionPhase {idle, sending(submission), restoringSubmission(submission,
  reason), creationError(reason), discoveryError(reason)}`; updates become
  `copyWith(config:)`/`copyWith(phase:)`; `agentModelData` a getter on the
  config. ~15 UI pattern-match sites; large but mechanical test churn
  (`new_session_cubit_test`, `new_session_plugin_selection_test`). The
  fast-new-session-launch restoration semantics (snapshot retained across
  discovery/reconnect refreshes, cleared only on consumption/submission/route
  exit) are preserved exactly.
- Verify: `dart test test/cubits/new_session`; `flutter test test/features/new_session`.

### Step 34 — plugin-management types

- `repositories/models/plugin_management_result.dart:65-121`:
  `PluginAuthenticationStartResult` and `…CancelResult` differ only in the
  success variant; `plugin_repository.dart:35-87` maps 404/409/uncertain/failure
  twice; the cubit maps five failure variants to the presentation error twice
  (`:51-93,155-186,302-350,368-386,546-564`); `_runCommand`/`_runTimeoutPlan`
  repeat the mutation→action mapping; `_onConnectionStatus` has identical
  bodies in both branches of `_receivedInitialStatus`;
  `PluginAuthenticationPresentationState` four variants carry the same
  `{pluginId, verificationUri, userCode}` triple.
- Change: `PluginAuthenticationFailure {notFound|conflict|unsupported|
  uncertain|request}`; `StartChallenge|StartFailed`, `CancelSuccess|CancelFailed`;
  one repository mapper; one cubit `_failureFor`; drop the flag; optionally a
  `challenge` record with a phase enum (the shell's sealed→bools flattening in
  `harnesses_settings_screen.dart:115-177` is fixed in Step 38 against this).
- Verify: `plugin_management_service_test`, `plugin_management_cubit_test`,
  `plugin_repository_test`; `flutter test test/features/settings`.

### Step 35 — shell and design-system dead code

- `client/app`: `lib/core/status_colors.dart` (never imported),
  `features/session_diffs/utils/binary_detector.dart` (+ its only test), 14
  unreferenced `app_en.arb` keys (`notificationCategorySystemUpdateDescription`,
  `sessionDetailPickerModel`, `backgroundTasksTitle`, `backToLogin`,
  `loginAwaitingCallback`, `loginCallbackTimeout`, `loginCallbackMissingParams`,
  `loginStateMismatch`, `loginPkceStateMissing`, `voiceStopRecording`,
  `voiceRecording`, `fetchDirectoryGoBack`, `projectFolderMissing`,
  `projectFolderMissingMessage`; regenerate `app_localizations*`), eight
  test-hook keys never looked up (`harnesses_action_error`, `yolo_setting`,
  `yolo_retry`, `pull_request_refresh_cancel`,
  `new_session_dedicated_workspace`, `attachmentCollection.surface`,
  `filePartWidget.previewImage`, `filePartWidget.previewTapTarget`), the
  double-keyed `KeyedSubtree` wrappers in `harnesses_settings_screen.dart:225-228,
  260-263, 273-276, 454-457` (pick one scheme), `NewFolderDialog`
  `@visibleForTesting` without a test.
- `client/module_prego`: orphans `components/main_screens/prego_quick_action_button.dart`
  (294), `prego_total_balance.dart` (104), `prego_price.dart` (135),
  `components/icons/prego_hero_icon.dart` (154) + `assets/svgs/hero_icons/`
  (10 SVGs, pubspec entry); test-only `PregoSkeletonListTile`
  (`prego_skeleton.dart:215-264`), `PregoPopupAlertsNotificationsAction`,
  `debugGlassEntryHeight`. **Verify first** whether `design_catalog` wants the
  skeleton tile before deleting it.
- Verify: `flutter analyze` + `flutter test test/features/settings
  test/features/session_diffs` in `client/app`; `flutter gen-l10n`; `flutter
  test` in `module_prego`; `make catalog-check`.

### Step 36 — Firebase no-op adapters

- `client/app/lib/core/platform/firebase/no_op_firebase_analytics_adapter.dart`
  (418), `no_op_firebase_messaging_adapter.dart` (87),
  `no_op_firebase_crashlytics_adapter.dart` (64), `no_op_firebase_app_adapter.dart`
  (39) mirror entire FlutterFire SDK surfaces, but each SDK object has exactly
  one consumer that is already a thin wrapper of a tiny module_core interface
  (`AnalyticsClient` 2 members, `FailureReporter` 3, `PushMessagingSource` 8);
  `client/desktop/lib/core/platform/no_op_analytics_client.dart` is already the
  11-line version of the pattern.
- Change: register `@firebaseDisabledEnvironment` `NoOpPushMessagingSource`,
  `NoOpFailureReporter`, `NoOpAnalyticsClient`; keep only the enabled-environment
  SDK registrations; delete the four no-op SDK adapters and the disabled-
  environment `FirebaseApp` registration in `firebase_register_module.dart:20-61`.
  `main.dart:33-49` (`_configureFirebaseSdk`: background-message handler
  registration and the Crashlytics `FlutterError`/`PlatformDispatcher` hooks) is
  enabled-path startup wiring and is kept exactly as is. Affects
  firebase-disabled builds only (web/linux/windows, Android profile).
- Verify: `flutter test test/core/di/firebase_dependency_registration_test.dart
  test/core/platform/ test/main_startup_notification_wiring_test.dart`.

### Step 37 — grouped rows and shell helpers

- `PregoGroupedRows` (`client/module_prego/lib/components/surfaces/prego_grouped_rows.dart:25-45,68-69,132-152`)
  leaves divider suppression to each row, so 39 `isLast:` call sites compute
  "is any later row shown" — e.g. `harnesses_settings_screen.dart:476-487` is a
  ten-term boolean repeated in diminishing form ten times → the container wraps
  non-last children in a private `_GroupedRowPosition` inherited widget that
  `PregoGroupedRow` reads; delete the parameter everywhere.
- Settings page shell repeated ×4 (`_contentTopPadding` + sliver scaffold) →
  `SettingsPageScaffold`; `main.dart:208-242` three identical gating getters →
  one; three clipboard implementations (`copy_icon_button.dart:34-46` silently
  swallows, `onboarding_view.dart:746-766`, `harnesses_settings_screen.dart:1001-1012`)
  → one helper that logs (also fixes `core/utils/syntax_highlight.dart:76`);
  `_MeasureSize`/`_MeasureSizeRenderBox` (`session_detail_loaded_view.dart:298-320`)
  duplicates prego's private `_HeightObserver` → one exported
  `PregoSizeObserver`; `flutter_keyboard_visibility` (git-forked dependency,
  one use at `prompt_input.dart:869-881`) → `MediaQuery.viewInsetsOf(context)
  .bottom > 0` as three other sheets already do (**verify first** the fork's
  commit rationale for Android; tests switch to `tester.view.viewInsets`).
- Verify: `flutter test` in `module_prego`; `flutter test test/features/settings
  test/features/session_detail test/main_startup_notification_wiring_test.dart`.

### Step 38 — sheets, dialogs, status widgets

- Rename sheets (`rename_project_dialog.dart:26-124` ≡ `rename_session_dialog.dart:26-118`)
  → one `RenameSheet`; `_DeleteSessionSheet`/`_ArchiveSessionSheet`
  (`session_cleanup_dialogs.dart:7-83,84-154`) → one `_CleanupConfirmSheet`;
  two-button sheet footer in seven files → `PregoSheetActions`; bottom-sheet
  sizing boilerplate ("capture before presenting" + `contentTopInset` math) in
  seven files → a sizing option on `showPregoBottomSheet`; `_ErrorView` ≡
  `SessionDetailErrorView` → `RemoteFailureView`; single-row notices ×5 →
  `GroupedNoticeRow`; `_statusIcon` switch ×3 → `SessionStatusIcon`;
  `agent_part_widget` vs `retry_part_widget` row; `question_modal.dart` three
  option tiles (`:727-918`) → `_ChoiceTile`; `harnesses_settings_screen.dart:115-177`
  flattens the sealed authentication presentation into booleans → pattern-match
  the sealed state (aligned with Step 34). Material→Prego migration limited per D5.
- Scope note: `PregoSheetActions` and the `showPregoBottomSheet` sizing option
  live in `client/module_prego`, so that package is in scope, not only the app.
- Behavior: visual parity is the acceptance criterion; dialog chrome is
  user-visible, so this step updates `questions-and-permissions.md`,
  `session-archiving-and-deletion.md`, and `projects-and-sessions.md` in the
  same PR.
- Verify: `flutter analyze` + `flutter test` in `client/module_prego`; `flutter
  test test/features/session_list test/features/project_list
  test/features/settings test/features/session_detail` in `client/app`.

### Step 39 — prompt composer in-file duplication

- `prompt_input.dart`: `_ComposerPasteAction._pasteImageOrText` (`:51-68`) vs
  `_PromptInputState._pasteImageOrText` (`:1551-1575`); `_restoreDraft`
  (`:251-262`) vs `_applyDraft` (`:700-712`); `_showRecordingLimitReached`
  (`:793-798`) is `_showComposerNotice` with a fixed string;
  `_buildHoldToTalkComposer` (`:1085-1134`) vs `_buildTypingVoicePill`
  (`:1396-1431`); mic+primary trailing `Row` ×2. Route the action through the
  state method, merge drafts (`notify: bool`), one `_buildVoicePill(hint:,
  trailing:)`. Rebase after #956/#918.
- Verify: `flutter test test/features/session_detail test/features/new_session`.

### Step 40 — voice interaction sealed state

- Twelve coordination fields (`_voiceState`, `_maxDurationSub`,
  `_minimumRecordingDurationTimer/Reached`, `_recordingPointer/Position`,
  `_cancelTargetEngaged`, `_pinnedVoiceLayout`, `_releaseRequestedDuringStart`,
  `_isRecordStartInFlight`, `_isCancelInFlight`, `_voiceInteractionId`,
  `_cancelDragProgress`) with `_displayedVoiceState` reconciling two of them and
  every transition re-checking combinations → `sealed class _VoiceInteraction
  {idle; starting(id, releaseRequested, pinnedLayout); recording(id,
  pinnedLayout, minDurationReached, pointer?, cancelEngaged); transcribing(id,
  pinnedLayout); cancelling}` (keep the two `ValueNotifier`s). The sealed state
  stays widget-local: it is ephemeral gesture/layout state, so no app-level
  controller class is introduced (business orchestration remains in cubits and
  the shell stays thin). User-visible voice UX; lands after Step 39 and before
  the replacement for #918, which will adapt realtime preview transitions to
  this sealed state per the owner's 2026-08-24 sequencing decision; updates
  `voice-input.md` in the same PR.
- Verify: `flutter test test/features/session_detail`; manual hold-to-talk,
  cancel-drag, max-duration, and minimum-duration flows on the release-target phone.

### Step 41 — transcript list (D3)

- `session_detail_message_list.dart` replaces every `flutter_chat_ui` default
  (bare `chatMessageBuilder`, `SizedBox.shrink()` composer/scroll/empty
  builders, zero animation durations, `shouldScrollToEndWhenSendingMessage:
  false`) and keeps ~350 lines of controller mirroring (`_syncChatController*`,
  `_chatEntriesFor`, `_entriesMatch`, `_entryIdForMessage`, `_kRoleMetadataKey`,
  `_promptsUsingMessageEntryId`, `_chatThemeCache`, `_resolveUser`, duplicate-id
  dedupe) to drive what is effectively a reversed animated list; these are the
  only two imports of `flutter_chat_ui`/`flutter_chat_core` in `client/`.
- Spike: `ListView.builder(reverse: true, controller: _follow.scrollController)`
  keyed by message/prompt id, keeping `ScrollFollowTracker`, the detached
  snapshot, `_revealable`, `_animatedPromptRow`, and pagination via the existing
  tracker. Land only on widget-test parity for follow/detach, older-page
  prepend freeze, prompt-row transitions, and keyboard inset; otherwise record
  the result. Rebase after #939. Names `session-turns.md` and
  `session-history-and-recovery.md`.
- Verify: `flutter test test/features/session_detail/` (the existing message-list
  test is rewritten); manual scroll checks on the release-target phone.

### Step 42 — compatibility expiry (D1)

- Executes against the owner-recorded D1 baseline `≥ v1.4.0` (decided
  2026-08-22): nullable `RejectQuestionRequest.sessionId`
  (`reply_to_question_request.dart:25`) +
  `pending_interaction_service.dart:78-105` legacy owner resolution +
  `session_operation_dispatcher.dart:62 dispatchLegacyQuestion` and the
  per-plugin admission lane/settlement tracking that exist only for it
  (`:154-176, 211-219`); `session_detail_cubit.dart:1124` `displaySessionId`
  fallback; `health_response.dart:16` nullable + `add_project_dialog.dart:692`
  + `connection_service.dart:423` empty-body tolerance;
  `legacy_post_update_relaunch.dart` + three consumers (v1.1.2);
  `BridgeIdMigrationService` + `readLegacyBridgeId` + its two startup
  invocations (v1.3.0); the obsolete unprefixed OpenCode CLI aliases;
  `codex_config_reader.dart` fallback reads
  (v1.1.2) only if the peer is released-Sesori-era data rather than a live
  rollout format; write-only managed-runtime start-intent state with no
  production reader. Under the `≥ v1.6.0` candidate, additionally the v1.4–v1.5
  family listed in D1. `GET /pull-request-refresh-settings` stays
  until the current client migrates to `/settings` (migrate the client in this
  step; keep the route until the baseline passes v1.8.0). Regression documents
  retain only supported behavior and executable coverage, not deleted-artifact
  tombstones.
- Verify: handler tests for each removed route/field; a current client against
  the baseline bridge and the current bridge against the baseline client (or
  equivalent wire fixtures).

### Step 43 — installer parity, codegen freshness, `no_slop_linter` (D6)

- Installer parity (PR #1017 finding F16): stable-version validation differs
  (regex vs `[version]::TryParse`, which accepts four-component versions), so
  the two installers can select different releases from identical metadata.
  Both installers pin the canonical GitHub hosts so environment variables cannot
  redirect executable downloads, and `install.ps1` gains exact three-component
  validation; fixture-driven parity tests
  extending `bridge/app/test/tool/installers_test.dart` cover release selection
  and order, partial releases, checksum parsing, archive/checksum URL
  construction including hostile host variables, and manifest writing for both
  scripts. The PowerShell rejection of non-three-component versions is a
  recorded behavior delta (matches `install.sh`).
- Codegen freshness: a CI job regenerates the OpenCode outputs that are fully
  reproducible from committed inputs (SSE events from the committed manifest)
  and fails on diff; the OpenAPI-derived client requires an uncommitted spec and
  is recorded as out of scope rather than adding network access to CI.
- `bridge/analysis_options.yaml:1-3` has the `plugins:` block commented out;
  no bridge package runs the repository's own linter. Enable it for
  `sesori_bridge_foundation`, `sesori_plugin_interface`, `sesori_plugin_runtime`
  (validating whether a per-package `analysis_options.yaml` under the pub
  workspace accepts `plugins:` or the workspace root must carry it), fix what
  it reports there, and record per-package warning counts for `bridge/app` and
  the plugins in `steps/step-43.md` for the owner's later decision.
- Verify: installer parity suite; the freshness job fails when an offline-
  reproducible output is dirtied locally; `dart analyze --fatal-infos` in the
  three packages; CI green.

### Steps 44–45 — regression documentation and retirement

Step 44 reconciles the regression documents listed below against the merged
implementation and completes the cleanup ledger. Step 45 runs the recorded
level and matrix, records the result, and moves the plan to
`.plan/completed/codebase-cleanup/` only when that coverage passes or the owner
records an explicit acceptance of any unexecuted rows.

## Relationship To PR #1017 (`reliability-cleanup`)

PR #1017 raises a parallel 14-step plan for the same effort from a separate
session (five investigations, two plan-review rounds, an owner vagueness waiver
and a recorded compat baseline, all dated 2026-08-21). Two active plans for one
effort would collide step by step, so this plan absorbs what #1017 has that
this one lacked and records what it does not adopt; the owner decides which PR
is the single durable plan (recommendation: this one, with #1017 closed and its
two orchestrator extractions kept as a separate evidence-backed follow-up).

Absorbed from #1017 (with the step that now owns each):

- the recorded owner decisions — compat baseline `≥ v1.4.0` (confirmed by the
  owner for this plan on 2026-08-22 as D1), desktop control stack kept (this
  plan never proposed removing it);
- `AbortableRequestClient` for the three hand-rolled deadline/abort sequences
  (F5 → Step 18);
- `install.sh`/`install.ps1` parity with fixture tests, the one-list
  `bridge-ci.yml`, and the offline codegen freshness job (F16 → Steps 6, 43);
- the cleanup-rejection layering fix, `GoRouterNavigation`, the dead test
  helper, and `CompositeSubscription` adoption in three cubits (F12/F13 →
  Step 30);
- `DefaultEditorRepository` folded into `BridgeSettingsRepository` (F4 →
  Step 22);
- base64/MIME normalization helpers, the manifest `releaseAssetUrl` default,
  the pending-input contract doc comments, and the Codex silent-catch fix (F8/F9
  → Steps 27, 28);
- the complete `NdjsonProcessClient` contract and its `sesori_plugin_runtime`
  home (Step 7 → Step 29).

Not adopted, and why:

- `RelayConnectionCoordinator` and `PluginEventProcessingDispatcher`
  extractions (#1017 Steps 5–6, 1,900–3,300 relocated lines, the plan's own
  highest-stakes risk): pure relocation with no line reduction on the
  reconnect/resume and SSE-ordering paths; this series optimizes for fewer
  lines and failure points, so they stay a separate follow-up the owner can
  schedule once this series lands.
- Keeping `flutter_chat_ui` behind a `_MessageListSynchronizer` (#1017 Step
  11): superseded by D3, which removes the mirroring glue and two dependencies
  if the spike reaches parity.
- App-level `PromptVoiceController`/`PromptAttachmentStaging` collaborators
  (#1017 Step 11): the Step 1 review found an app-level controller conflicts
  with the thin-shell rule; Step 40 keeps the sealed voice state widget-local.
- `#1017` deferring `NewSessionCubit` configuration plumbing behind
  `session-refresh-reconnects`: that plan owns `SessionDetailCubit` refresh
  triggers, not `NewSessionCubit`; Step 33 proceeds, and Step 31 stays out of
  refresh coordination.
- `#1017`'s Step 9 keeps the isolate pool because `dto_parser.dart` uses it;
  `dto_parser.dart` itself has zero references, so Step 2 deletes both.

## Cleanup Assessment

This series is cleanup, so the assessment records what is deliberately kept:

- Mandatory repository layer and pass-through repositories (`DefaultEditorRepository`,
  `SessionUnseenRepository`, `WorktreeRepository` delegates, updater/registration
  repositories, `PermissionRepository`/`LegalRepository` in module_core).
- `StoredSession` as a deliberate 12-of-24-field projection; `SessionDto` never
  reaches services.
- The three bridge dispatchers (`RoutedRequestDispatcher`, `SessionOperationDispatcher`,
  `SessionEventDispatcher`) and the orchestrator's per-plugin lane; only the
  FIFO idiom is shared (Step 21).
- Local `PluginRuntimeState` and the 1:1 `plugin_to_shared_mapping.dart`
  boundary; `SSEManager._toOpenCodeFormat`; the `BridgeEventMapper` SSE parse
  path that is a plugin-interface contract.
- Plugin event dispatchers/tool trackers, history mappers, catalog
  services/repositories, runtime manifests, Hermes vs OMP session-options
  services, Cursor vs OMP cleanup services — backend-shaped, not copies.
- Five ~50-arm SSE "ignore" switches: collapsing to `case _:` would trade away
  compile-time exhaustiveness when a new event is added.
- `bootstrapSesoriApp` test seam, `module_auth` HTTP client placement,
  `OAuthStorageService` clear methods, `prego_tappable` platform variants,
  `prego_buttons_solid`, `background_tasks_*` split, `universal_platform`.
- `docs/parallel-plugins/PLAN.md` as an explicit archive. `AGENTS.bak.md` was
  listed here too until the owner had it deleted; Git history retains it.
- Codex `archiveSession` commented body (retained at reviewer request) and the
  live Codex/OpenCode/runtime COMPATIBILITY rows owned by backend versions.

## Complexity Budget

New shared production primitives, each replacing at least two existing copies
and owning a real invariant:

1. `PendingOperations` (`sesori_bridge_foundation`) — 10 app copies plus the
   Claude/Pi copies of tracked in-flight work.
2. `ParallelLock.idle` + `KeyedParallelLock` (`sesori_bridge_foundation`) — 8
   hand-rolled FIFO tails.
3. `RequestHandlerBase._guard`, `requireNonEmpty`, `buildJsonErrorResponse` —
   3 error chains, 30 guards, 8 inline responses.
4. `PendingPermissionRegistry` base (plugin interface) — 2 ~215-line skeletons.
5. `ManagedRuntime*` shared classes and `startManagedRuntimePlugin` (runtime) —
   Codex/OpenCode pairs that have already drifted twice.
6. `RuntimeProbeOutcome`, `ManagedRuntimeSelectionService.select`,
   `ManagedRuntimeInstallService.forHost`, `stripAnsi` — 5–7 descriptor copies.
7. `NdjsonProcessClient` + `NdjsonProcessHandle` (`sesori_plugin_runtime`) —
   three drifted stdio transports, parts of two more.
7a. `AbortableRequestClient` (app Layer-0 foundation, stateless per call) —
   three hand-rolled deadline/abort sequences.
8. Interface/plugin helper additions (`PluginMessagePart` constructors,
   `PluginToolStatus.isTerminal`, `PluginCommand.compaction`,
   `AcpConfigOptionParser`, `asStringKeyedMap`, `nonEmptyString`).
9. `ConnectionService.reconnectAndAwaitOutcome`, `RelayHttpApiClient._request`,
   one relay request-id generator — 2 cubit copies, 5 method copies, 2 generators.
10. `NewSessionPhase` + configuration record; `PluginAuthenticationFailure`;
    `_VoiceInteraction`; sealed `UpdateInstallResult`/`TokenValidationResult` —
    each replaces a flag/field combination that could disagree.
11. Shell/prego: `_GroupedRowPosition`, `SettingsPageScaffold`, clipboard helper,
    `PregoSizeObserver`, `RenameSheet`, `_CleanupConfirmSheet`,
    `PregoSheetActions`, sheet sizing option, `RemoteFailureView`,
    `GroupedNoticeRow`, `SessionStatusIcon`, `_ChoiceTile`.
12. Test-only: `plugin_interface_testing.dart`, bridge/app `test/helpers/fakes/`,
    `sesori_dart_core/testing.dart`, per-package test support and harness
    builders, one `awaitState` helper per package.

Deliberately not added: a listener base class, a generic tool tracker, a merged
dispatcher, a shared client/bridge auth manager, a `module_app_ui` package,
a session-detail refresh scheduler, an orchestrator split, a pending-session or
idempotency layer, and any compatibility shim for unpublished peers. If a step
needs machinery beyond this list, it stops and asks.

## Compatibility

- Client↔bridge wire contracts are unchanged by every step except Step 42,
  which removes paths only for peers below the owner-decided D1 baseline
  (`≥ v1.4.0`) and updates the affected regression document in the same PR.
- Step 4 makes `snapshotToken`/`bridgeId` required because every public producer
  already sends them (verified against tags); decoding of existing payloads is
  unchanged. `ActiveSession` keeps its nullable wire fields.
- Step 19 unifies the unknown-error status to 500 only after confirming no
  client branches on 502.
- Step 23 changes bridge-internal models only (`PluginProvider`,
  `PluginSetupStatus`); the `ProviderInfo` and `PluginSetupStatus` wire shapes
  are unchanged.
- Step 25 defers the ownership-record JSON unification (older bridges reading
  a newer `*-processes.json` would quarantine it) to D1.
- No database schema change in any step (schema stays v13).
- Dart/Flutter modules and plugin interfaces have no external consumers; every
  in-repository consumer is updated in lockstep, with no shims.

## Verification

- Per-step verification is listed in each step; every PR additionally runs
  `dart analyze --fatal-infos` (or `flutter analyze`) in each touched package
  and, for shared-module changes, the downstream product shells.
- Test-only steps (8–14) run the complete suites of every touched package;
  Step 14 runs each touched suite three times locally.
- Steps that touch crypto, auth, approvals, or plugin start/shutdown (15 encryptor
  item, 18, 25–27, 29) are landed one package at a time with green tests and a
  manual smoke of the affected flow.
- Each step records in `TRACKER.md`: the re-verification delta against current
  `main`, the merge-base `git diff --numstat` size, the test/analyze commands and
  results, and whether architecture-implementation review ran.

## Regression Documentation And Final Matrix

Behavior-changing steps (19, 21, 38, 40, 41, 42, and the installer delta in 43)
update their affected feature document in the same PR. Step 44 is the final
consistency pass over the documents below (most will record "no behavior
change, implementation references updated"):

- `docs/regression/bridge-connectivity.md` — Step 19 status unification, Step
  42 health/legacy-route removals, Step 15 encryptor ownership.
- `docs/regression/questions-and-permissions.md` — Step 27 registry base,
  Step 42 legacy question path, Step 38 question tiles.
- `docs/regression/plugin-setup-and-lifecycle.md` and
  `docs/regression/plugin-runtime-installation.md` — Steps 23–26.
- `docs/regression/session-creation-and-options.md` — Steps 30, 33, 22.
- `docs/regression/session-turns.md`, `docs/regression/session-history-and-recovery.md`
  — Step 41 transcript list, Step 20 `/sessions` enrichment.
- `docs/regression/voice-input.md` — Steps 39–40.
- `docs/regression/projects-and-sessions.md`,
  `docs/regression/session-archiving-and-deletion.md` — Step 38 sheets, Step 37
  settings rows.
- `docs/regression/account-and-onboarding.md` — Step 18 bridge auth.
- `docs/regression/bridge-installation-and-updates.md` — Step 15 updater helpers.
- `docs/regression/notifications.md`, `docs/regression/analytics.md` — Step 36
  firebase-disabled builds, Step 31 analytics reporter.
- `docs/regression/design-catalog.md` — Step 35 Prego deletions (expected: no change).

### Highest required level

**L3 Release**, because the plugin-boundary steps (25–27, 29) change how every
registered production plugin starts, provisions, approves, and talks to its
process, and the shell steps (38, 40, 41) change user-visible chrome, voice, and
transcript rendering. Everything else is proved at the Automated boundary by the
owning suites.

### Required matrix

- **Automated:** every touched package's full suite green; `dart analyze
  --fatal-infos` across bridge, client, and shared; CI matrix green.
- **Plugins:** for Steps 25–27 and 29, enumerate every plugin registered by the
  production `knownPlugins` composition in the build under test; for each,
  prove setup inspection, runtime start, one prompt, and one approval round
  trip through the headless bridge or live plugin boundary. Unsupported
  capabilities are not failures.
- **Client:** one release-target phone platform, narrow and wide layouts, for
  Steps 38, 40, 41: rename/archive/delete sheets, question modal, settings rows,
  hold-to-talk/cancel/limit flows, transcript follow/detach/prepend/keyboard.
- **Compatibility (after Step 42):** current client against the D1 baseline
  bridge and current bridge against the D1 baseline client (or equivalent wire
  fixtures); health, agents, question rejection, and settings routes exercised.
- **Tooling:** `make analyze` and `make test` from `bridge/`, `client/`, and
  `shared/` succeed with `--fatal-infos` parity.

Any reduction to this matrix at retirement requires the owner's explicit
acceptance recorded in this file.

**Owner acceptance 2026-08-25:** Hermes setup/start/prompt/approval execution is
accepted as blocked because its detected ACP `0.20.4` runtime requires provider
credentials unavailable to this run. The client row is accepted with live narrow
iOS simulator coverage plus the passing wide-layout and cancel/limit widget
suites; live wide-phone, physical microphone, and haptic behavior are not
claimed. These accepted gaps do not waive any other matrix row.

## Risks And Accepted Limits

- Line references rot quickly in this repository; every step re-verifies and
  may do less than estimated. Estimates are targets, not promises.
- Concurrency-sensitive steps (16, 17, 21, 22, 25) are behavior-preserving by
  intent, but ordering regressions are the realistic failure; they are landed
  one step at a time with the existing ordering/shutdown suites as the contract.
- Steps 38, 40, 41 are user-visible; parity, not polish, is the acceptance bar,
  and Step 41 may legitimately end as a recorded "not landed".
- Step 42 removes compatibility for peers older than the owner-decided
  `≥ v1.4.0` baseline; each marker still gets a per-peer verification line in
  the tracker and stays, with reason, if its peer turns out to be live on-disk
  or runtime data rather than a released Sesori surface. The accepted
  consequence of dropping the v1.3.0 bridge-id migration (a stale `≤ v1.3.x`
  install re-registers as a new bridge) is recorded under D1.
- Consolidating fakes changes test code at scale; a subclass that overrides less
  than the private copy did can hide a behavior difference. Step 9 keeps every
  private default by overriding, never by rewriting assertions.
- The tree flatten (Step 7) conflicts with any unmerged bridge branch; it is
  scheduled while bridge PR traffic is low and announced in the PR.

## Expected Result

After Step 45: the same product behavior, measurably less code (targets above),
one bridge layer tree that matches its architecture document, one fake per
shared contract, tested primitives instead of hand-rolled lanes and
request tables, sealed states where flags used to coordinate, dated and correctly
labelled compatibility markers with a recorded support baseline, CI covering the
shared crypto/protocol package, no database change, and only Step 28's additive
non-null message-part defaults changing the default wire contract.
