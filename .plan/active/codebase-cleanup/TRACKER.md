# Codebase Cleanup: Tracker

## How This Tracker Works

This file holds only what GitHub cannot: the owner's decisions, the rules the
series binds itself to, and the fixed PR titles. It deliberately does **not**
mirror live PR state.

- **Live status lives on GitHub.** `gh pr list --state all --search "[codebase-cleanup]"`
  shows every step's PR and whether it is open or merged. Nothing here needs
  editing when a PR is raised or merged.
- **Per-step evidence lives in `steps/step-NN.md`**, written only by that step's
  own PR. No PR ever edits another step's file, so parallel steps cannot
  conflict here.
- **This file changes only when a decision, principle, or guardrail changes** —
  not as bookkeeping.

Steps that touch disjoint trees run in parallel (the owner asked for up to about
five open PRs). Steps sharing a package stay serialized: 4 after 3 (both
`sesori_shared`), 7 after 5 (both `bridge/app`).

- **Plan slug:** `codebase-cleanup`
- **Implementation base:** `origin/main` at `084b30276`
- **Overlapping work:** open PRs #918 (voice streaming), #956 (composer
  drag-and-drop), #939 (macOS list scrolling) overlap Steps 39–41 — rebase and
  re-scope after they merge; the active `session-refresh-reconnects` plan owns
  session-detail refresh coordination, so Step 31 touches only pure derivation.

## Open Decisions (defaults apply until the owner overrides)

- [x] **D1** minimum supported public peer — **decided `≥ v1.4.0`** by the
  owner on 2026-08-22 (first recorded in PR #1017 on 2026-08-21); Step 42
  executes against it with a per-marker peer-verification line; the bridge-id
  migration consequence (stale `≤ v1.3.x` installs re-register) is accepted
- [x] **D2** flatten `bridge/app/lib/src/bridge/*` into `src/*` — **approved**
  by the owner on 2026-08-22; Step 7 performs the move
- [x] **D3** `flutter_chat_ui` replacement — plain reversed list reached widget-test parity in Step 41
- [ ] **D4** `cryptography_flutter` — default remove as unused (never enabled)
- [ ] **D5** Material→Prego dialog breadth — default only what the footer and
  confirm-sheet consolidation naturally covers
- [ ] **D6** `no_slop_linter` in bridge — default small packages only, record
  counts for the rest

## Locked Principles

- [x] Behavior-preserving by default; Steps 19, 21, 38, 40, 41, 42 (and the
  installer delta in 43) name their intentional changes and update the affected
  regression document in the same PR; Step 44 is the final consistency pass.
- [x] Nothing is extracted unless it replaces at least two copies and owns
  state, a lifecycle, or an invariant.
- [x] Every step re-verifies its evidence against current `main` before editing
  and records the delta in its own `steps/step-NN.md` — never in this file, so
  parallel steps cannot conflict.
- [x] No wire-contract or compatibility removal outside Step 42 and D1.
- [x] No database schema change anywhere in the series.
- [x] Session-detail refresh coordination, dispatcher merging, orchestrator
  splitting, and `ConnectionService`/`RelayClient` lifecycle redesign are out.
- [x] Architecture-implementation review only for Steps 4, 7, 15, 17, 18, 20,
  21, 22, 23, 25, 26, 27, 28, 29, 30, 31, 32, 33, 36, 37.
- [x] 1,500 changed-line soft cap; deletion- or generated-heavy overages are
  recorded with the reason.

## Complexity Guardrails

- [x] One `PendingOperations` and one `KeyedParallelLock` (both in
  `sesori_bridge_foundation`), one `AbortableRequestClient` (app foundation),
  one `PendingPermissionRegistry` base, one managed-runtime start helper, one
  `RuntimeProbeOutcome`, one `NdjsonProcessClient` (`sesori_plugin_runtime`),
  one per-cubit `LoadedStateAnalyticsReporter` — no second variant of any of
  them, and no caller state on singleton services.
- [x] No listener base class, generic tool tracker, merged dispatcher, shared
  client/bridge auth manager, `module_app_ui` package, refresh scheduler,
  idempotency layer, or compatibility shim for unpublished peers.
- [x] Test consolidation uses `implements`/subclass fakes only; no 1:1
  interfaces for testability.
- [x] Step 9 converts private fakes by subclass-and-override; assertions are
  never rewritten to fit a shared fake.
- [x] Step 14 replaces sleeps with injected clocks or `fakeAsync`; no new
  timing constants.
- [x] Step 41 lands only on widget-test parity for the listed scroll behaviors.

## Delivery Steps

Fixed titles and order. Status is GitHub's; evidence is in `steps/step-NN.md`.

| Step | Exact PR title |
|---|---|
| 1/45 | `🌱 [codebase-cleanup] docs: raise the reliability cleanup plan [step 1/45]` |
| 2/45 | `🌿 [codebase-cleanup] client(module_core): delete the dead concurrency copy [step 2/45]` |
| 3/45 | `🌿 [codebase-cleanup] shared: delete dead helpers, models, and the rxdart dependency [step 3/45]` |
| 4/45 | `🌿 [codebase-cleanup] shared: tighten management fields and correct compatibility markers [step 4/45]` |
| 5/45 | `🌿 [codebase-cleanup] bridge(app): delete dead production code [step 5/45]` |
| 6/45 | `🌿 [codebase-cleanup] tooling: close CI gaps, prune dependencies, and refresh docs [step 6/45]` |
| 7/45 | `⚙️ [codebase-cleanup] bridge(app): flatten the duplicated layer tree [step 7/45]` |
| 8/45 | `🌿 [codebase-cleanup] bridge(plugins): add a plugin-interface testing library for console and process fakes [step 8/45]` |
| 9/45 | `⚙️ [codebase-cleanup] bridge(app): consolidate plugin and repository test fakes [step 9/45]` |
| 10/45 | `🌿 [codebase-cleanup] bridge(app): consolidate process-runner and service test fakes [step 10/45]` |
| 11/45 | `🌿 [codebase-cleanup] bridge(plugins): add plugin-local test support for OpenCode, ACP, and Pi [step 11/45]` |
| 12/45 | `🌿 [codebase-cleanup] client(module_core): consolidate test helpers and cubit harnesses [step 12/45]` |
| 13/45 | `🌿 [codebase-cleanup] client: publish a module_core testing library and relocate its tests [step 13/45]` |
| 14/45 | `⚙️ [codebase-cleanup] tests: replace real-duration sleeps with fake time and state awaiting [step 14/45]` |
| 15/45 | `🌿 [codebase-cleanup] bridge(app): share tracked-work helpers and fix logging consistency [step 15/45]` |
| 16/45 | `🚧 [codebase-cleanup] bridge(app): remove the triplicated PluginRuntime command preamble [step 16/45]` |
| 17/45 | `⚙️ [codebase-cleanup] bridge(app): simplify Orchestrator fencing and PluginLifecycleService initialization [step 17/45]` |
| 18/45 | `🚧 [codebase-cleanup] bridge(app): consolidate auth validation, abortable requests, and encryptor ownership [step 18/45]` |
| 19/45 | `⚙️ [codebase-cleanup] bridge(app): deduplicate request-handler error mapping and guards [step 19/45]` |
| 20/45 | `⚙️ [codebase-cleanup] bridge(app): deduplicate SessionRepository, enrichment, and pending-interaction repositories [step 20/45]` |
| 21/45 | `🚧 [codebase-cleanup] bridge(app): replace hand-rolled FIFO lanes with the foundation ParallelLock [step 21/45]` |
| 22/45 | `⚙️ [codebase-cleanup] bridge(app): deduplicate updater and server helpers and seal platform trios [step 22/45]` |
| 23/45 | `⚙️ [codebase-cleanup] bridge(plugins): remove dead contract members and collapse PluginProvider [step 23/45]` |
| 24/45 | `🌿 [codebase-cleanup] bridge(runtime): remove the migration-era dual-mode runtime knobs [step 24/45]` |
| 25/45 | `🚧 [codebase-cleanup] bridge(plugins): fold Codex and OpenCode managed-runtime plumbing into sesori_plugin_runtime [step 25/45]` |
| 26/45 | `🚧 [codebase-cleanup] bridge(plugins): share descriptor setup probing and managed installation [step 26/45]` |
| 27/45 | `🚧 [codebase-cleanup] bridge(plugins): extract the shared pending-permission registry base [step 27/45]` |
| 28/45 | `⚙️ [codebase-cleanup] bridge(plugins): share small mapper helpers and lifecycle wrappers [step 28/45]` |
| 29/45 | `🚧 [codebase-cleanup] bridge(plugins): share stdio pending-request and transport plumbing [step 29/45]` |
| 30/45 | `⚙️ [codebase-cleanup] client(module_core): delete SessionService and inline thin services [step 30/45]` |
| 31/45 | `⚙️ [codebase-cleanup] client(module_core): deduplicate SessionDetailCubit derivation and analytics reporting [step 31/45]` |
| 32/45 | `🚧 [codebase-cleanup] client(module_core): share list-cubit scaffolding and relay request plumbing [step 32/45]` |
| 33/45 | `🚧 [codebase-cleanup] client(module_core): compose NewSessionState from phase and configuration [step 33/45]` |
| 34/45 | `⚙️ [codebase-cleanup] client(module_core): unify plugin-management result and failure types [step 34/45]` |
| 35/45 | `🌿 [codebase-cleanup] client(app, prego): delete dead shell code, components, and localization keys [step 35/45]` |
| 36/45 | `⚙️ [codebase-cleanup] client(app): replace no-op Firebase SDK adapters with no-op interface implementations [step 36/45]` |
| 37/45 | `⚙️ [codebase-cleanup] client(app, prego): let grouped rows own separators and share shell helpers [step 37/45]` |
| 38/45 | `⚙️ [codebase-cleanup] client(app): consolidate sheets, dialogs, and status widgets [step 38/45]` |
| 39/45 | `🌿 [codebase-cleanup] client(app): remove in-file duplication from the prompt composer [step 39/45]` |
| 40/45 | `🚧 [codebase-cleanup] client(app): model the voice interaction as one sealed state [step 40/45]` |
| 41/45 | `🚧 [codebase-cleanup] client(app): render the transcript with a plain reversed list [step 41/45]` |
| 42/45 | `🚧 [codebase-cleanup] compat: retire compatibility paths outside the supported baseline [step 42/45]` |
| 43/45 | `⚙️ [codebase-cleanup] tooling: align installers, assert codegen freshness, and enable no_slop_linter for small bridge packages [step 43/45]` |
| 44/45 | `🌱 [codebase-cleanup] docs: reconcile regression coverage after the cleanup [step 44/45]` |
| 45/45 | `🌿 [codebase-cleanup] test: verify the cleanup series and retire the plan [step 45/45]` |

## Cleanup Ledger

| Artifact | Decision | Owning step |
|---|---|---|
| `client/module_core/lib/src/concurrency/` + `dto_parser.dart` | Delete (dead; verbatim copy of shared) | 2 |
| Shared dead helpers/models, `rxdart` | Delete | 3 |
| OpenCode `GlobalSession`/`SessionProject` in shared | Remove from shared (use generated model or move to plugin) | 4 |
| `bridge/app` dead methods, stub library, `acp_plugin` dep | Delete | 5 |
| Unused pubspec dependencies (incl. `cryptography_flutter` per D4) | Delete | 6 |
| `bridge/app/lib/src/bridge/*` subtree | Flatten into `src/*` (D2) | 7 |
| Duplicated test fakes (bridge, plugins, client) | Consolidate into testing libraries/helpers | 8–13 |
| Real-duration test sleeps | Replace with fake time/state awaiting | 14 |
| Tracked-work copies (app ×10, Claude/Pi) | One `PendingOperations` in foundation | 15, 28 |
| Auth URL normalization ×8, per-message `SessionEncryptor`/`setRoomKey`, hand-rolled abort/deadline ×3 | Normalize once; one encryptor per session; `AbortableRequestClient` | 18 |
| Updater/server helper copies, sealed update result models, `DefaultEditorRepository` | One helper each; sealed; fold into `BridgeSettingsRepository` | 22 |
| `PluginRuntime` stop/disable/restart preamble | One helper + transition record | 16 |
| `registerPlugins` two-phase init | Constructor plugins | 17 |
| `auth/validate.dart`, duplicated `/auth/me` and refresh | Fold into `TokenService` (renamed from `TokenManager`) | 18 |
| Handler error chains, guards, inline JSON errors, unused params | One of each | 19 |
| `enrichSessions` re-derivation, `plugin_session_mapper.dart`, `adoptStoredProjectId` wiring | Delete/simplify | 20 |
| Hand-rolled FIFO tails | `ParallelLock` | 21 |
| Inner generation fences | Delete only if provable (verify first) | 20 |
| Options-epoch re-checks | Reduce only with owner acceptance (verify first) | 21 |
| Wake-lock/editor platform trios | Sealed private implementations | 22 |
| `healthCheck`/`dispose` contract members, `PluginProvider` union, `PluginSetupStatus.versioned` subclasses, dead seams, stale comments | Delete/collapse | 23 |
| Runtime dual-mode knobs | Delete | 24 |
| Codex/OpenCode managed-runtime copies | Fold into runtime | 25 |
| Ownership-record JSON unification | Deferred to D1 | — |
| Descriptor setup/install copies, codex selection service | Share in runtime | 26 |
| ACP/Codex approval registry skeleton | Base in interface | 27 |
| Small mapper helpers, Claude/Pi wrappers | Share | 28 |
| Stdio pending-request/transport copies | One `NdjsonProcessClient` in `sesori_plugin_runtime` (PR #1017 contract) | 29 |
| `SessionService`, `BridgeSettingsService`, view twins, dead state/converter/fields | Delete/inline | 30 |
| `SessionDetailCubit` derivation duplicates, analytics guard duplicates | Consolidate | 31 |
| List-cubit scaffolding, relay request copies | Consolidate | 32 |
| `NewSessionState` six repeated fields | Phase + configuration | 33 |
| Plugin-management parallel result hierarchies | One failure type | 34 |
| Shell/prego dead files, l10n keys, test-hook keys, orphan components/assets | Delete | 35 |
| No-op Firebase SDK adapters | Replace with interface no-ops | 36 |
| `isLast` on 39 sites, settings scaffold ×4, clipboard ×3, size observer ×2, keyboard fork | Consolidate | 37 |
| Rename/confirm sheets, footers, sizing, failure/notice/status widgets, question tiles, sealed→bools | Consolidate | 38 |
| `prompt_input.dart` in-file duplicates | Consolidate | 39 |
| Voice interaction flags | Sealed state | 40 |
| `flutter_chat_ui` mirroring glue | Replace on parity (D3) | 41 |
| Compatibility paths whose peer is a released Sesori surface `< v1.4.0` (D1 decided) | Delete with a per-marker peer-verification line; keep live on-disk/runtime-format peers | 42 |
| Installer drift (`install.ps1` vs `install.sh`), no codegen freshness check, `no_slop_linter` absent from bridge | Parity + fixture tests; offline freshness job; enable linter for small packages (D6) | 43 |
| Mandatory repositories, `StoredSession`, dispatchers, plugin-boundary mapping, SSE ignore arms, archives | Keep | — |
| PR #1017 `RelayConnectionCoordinator`/`PluginEventProcessingDispatcher` extractions, `_MessageListSynchronizer`, app-level voice/attachment controllers | Not adopted (see PLAN "Relationship To PR #1017"); separate evidence-backed follow-up if wanted | — |

## Plan Review

- **Reviewer:** `architecture-plan-review` sub-agent
- **Result:** Draft rejected with seven placement/ownership/naming findings;
  all applied directly without a second review, per repository policy. The
  corrected plan is therefore not described as reviewer-approved.
- **Applied findings:** Step 26 `ManagedRuntimeSelectionService` constructor
  specified with an injected validator and no pass-through process/capture
  parameters, `inspectSetup` owner named, `forHost` kept as a composition seam;
  Step 31 analytics guard becomes a per-cubit `LoadedStateAnalyticsReporter`
  (no caller state on the singleton service, once-per-instance preserved);
  Step 15 `PendingOperations` placed in `sesori_bridge_foundation` with drain and
  count semantics stated and the plugin copies migrated in Step 28; Step 21
  keyed lock named `KeyedParallelLock` in `sesori_bridge_foundation`, `idle`
  defined, multi-key `_enqueueAll` kept private, error-policy unification
  declared as a behavior change; Steps 6/18 keep the `TokenService` suffix
  example and rename `TokenManager` to `TokenService` during the fold; Step 20
  shared repository helpers live in one same-layer file with no
  repository-to-repository dependency; Steps 15/28 state the homes of
  `FilesystemCleaner` (app Layer-0 foundation), `ProcessSpawnOutcome`
  (`sesori_plugin_interface`), and the shared JSON helpers (`sesori_shared`,
  with that suite added to verification).
- **Non-blocking notes folded in:** Step 27 justification corrected; Step 25
  start helper becomes a named collaborator if it outgrows thin composition;
  Step 7 architecture rewrite assigns `runtime/` a layer; Step 15 may also
  build `KeyExchangeManager` in `Orchestrator.create`; Steps 18, 28, 31 added
  to the implementation-review list.
- **Step 1 PR review (bots, 2026-08-22):** twelve inline findings on PR #1018,
  eleven applied, one partially: D1 default became "retain every public
  release; Step 42 removes nothing without an owner-recorded baseline"; D2
  default became "docs-only until the owner approves the move"; Step 17 and 22
  added to the implementation-review list; Step 13 moves only the 13 pure-Dart
  tests (the two `testWidgets` files and the app helper stay); `PendingOperations.
  drain()` keeps all-settled `Future.wait` semantics; Step 15 split — auth URL,
  encryptor ownership, and abortable requests moved to Step 18, updater/server
  helpers and sealed update models to Step 22, generation fences to Step 20,
  options epochs to Step 21; `PluginSetupStatus` keeps type-level version
  presence (no nullable field on every variant); Step 36 keeps the enabled-path
  `_configureFirebaseSdk` wiring; Step 38 adds `module_prego` to scope and
  verification; Step 40 drops the app-level controller; behavior-changing steps
  update regression docs in their own PR. Partially applied: the
  `PendingPermissionRegistry` home stays `sesori_plugin_interface` by the
  plan-review precedent, with `sesori_plugin_runtime` recorded as the fallback
  if the Step 27 implementation review rejects it.
- **PR #1017 reconciliation (2026-08-22):** absorbed its unique items
  (`AbortableRequestClient`, installer parity, bridge-ci list, codegen
  freshness, cleanup-rejection layering, `GoRouterNavigation`,
  `CompositeSubscription` adoption, `DefaultEditorRepository` fold, base64/MIME
  helpers, `releaseAssetUrl`, pending-input doc comments, Codex catch fix, the
  `NdjsonProcessClient` contract and runtime home, and its recorded owner
  decisions offered to D1); recorded what is not adopted and why in PLAN.md.
- **Owner decisions (2026-08-22):** D1 confirmed at `≥ v1.4.0`; D2 approved;
  #1018 kept as the single plan and #1017 closed in its favor.
- **Step 1 PR review round 3 (bot, 2026-08-22):** six new findings; five
  applied (Steps 4 and 20 added to the implementation-review list; Step 7
  moves `plugin_runtime.dart` to `api/` and keeps `runtime/` as the
  CLI/composition subsystem; `PendingOperations.track` and
  `KeyedParallelLock.use` use required named parameters;
  `AbortableRequestClient` moves to the app's Layer-0 foundation because every
  consumer is in `bridge/app`; `DiffCubit` takes the reporter directly), one
  recorded rather than changed (the bridge-id migration deletion stays under
  the owner-decided D1 because its peer is a released Sesori surface older
  than v1.4; the re-registration consequence is now written into D1).
