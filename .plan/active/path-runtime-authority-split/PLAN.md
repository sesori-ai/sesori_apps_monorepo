# PATH Runtime Authority — Replacement PR Series

## Status

- **Plan slug:** `path-runtime-authority-split`
- **Status:** Active; Step 1 raises this replacement plan before extracted implementation work.
- **Plan date:** 2026-09-13
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main` at `4854865eedf6`
- **Preserved source:** PR #1458, branch `opencode-install-status`, immutable reviewed head `0caf101b9a`.
- **Reason for replacement:** PR #1458 reached 5,833 changed lines across 106 files. Every follow-up push restarted
  full-PR AI review and produced new findings in previously reviewed areas. The implementation is preserved, but the
  delivery shape is replaced with independently passing slices under the repository's ~1,500-line soft cap.
- **Architecture review:** Approved 2026-09-13 on the permitted second pass. The first pre-review rejected vague
  ownership; exact file, class, collaborator, dependency, compatibility, and activation boundaries were added before
  approval. The only non-blocking note keeps any Step 8 `module_core` edits limited to presentation selectors.

This plan and `TRACKER.md` govern the replacement sequence. PR #1458 remains provenance, not an implementation branch
for further fix commits. Each implementation slice is rebuilt or extracted from its preserved head without rewriting
that branch or force-pushing published history.

## Goal

Make an ordinary host-resolved PATH runtime authoritative for every Sesori harness:

1. any present PATH command, including an outdated, malformed, unlaunchable, or ambiguously broken command, blocks
   managed fallback and managed-directory mutation;
2. genuinely absent PATH commands may use Sesori-managed runtimes where supported;
3. outdated compatible PATH installations expose only descriptor-owned, verified non-interactive update commands;
4. app-triggered updates stream sanitized progress, re-inspect canonical setup, and start only when compatible;
5. harnesses without a safe updater remain blocked with manual guidance;
6. setup inspection stays bounded and inert; and
7. shutdown settles admitted operations and terminates owned Windows process trees before releasing ownership.

The replacement preserves the intended behavior and valid review fixes from #1458 while reducing review coupling. It
need not preserve branch-local implementation shapes that conflict with current architecture rules.

## Scope And Non-Goals

### In scope

- Locale-independent executable presence classification on POSIX and Windows, including Windows working-directory and
  PATHEXT precedence.
- Managed runtime inventory, selection, install-boundary authority, and startup-upgrade suppression.
- Runtime-outdated setup state and safe updater declarations across all supported harness descriptors.
- Inert Antigravity runtime/profile inspection and pair-aware PATH authority.
- Bridge and shared transport contracts for managed install versus global update operations.
- Operation-scoped client state, analytics, and settings/session presentation.
- Abort, re-inspection, process-tree termination, and shutdown settlement required by admitted operations.
- Regression documentation and harness capability truth.

### Out of scope

- Installing, authenticating, starting a backend, or initializing ACP during setup inspection.
- Replacing explicit binary overrides automatically.
- Inventing updater commands for Copilot, DeepSeek, or Antigravity.
- Deleting preserved managed copies while PATH remains present.
- Sending raw command output, arguments, errors, or local paths across the wire.
- New persistence, scheduled updates, retries, background polling, or compatibility for unpublished internal contracts.

## Fixed Design Boundaries

- `IoHostExecutableLocator` is one injectable concrete Foundation class. It owns executable lookup and process-missing
  classification; tests implement the concrete class directly. No one-to-one interface is retained.
- Foundation returns neutral host/process facts. Plugin repositories map API DTOs and command results into plugin-domain
  outcomes before services apply setup policy.
- PATH evidence is conservative: only positively proven absence permits managed fallback. A broken shim, missing
  interpreter, broken link, malformed version, POSIX error code 3, or unknown probe remains authoritative.
- Managed mutation revalidates PATH authority at the installer boundary before cleanup, staging, or download.
- The newest installed managed version governs startup refresh; a pinned or newer copy prevents downgrade even when an
  older directory remains.
- Updater commands belong to descriptors, are non-interactive and bounded, and are advertised only for PATH runtimes.
- Provisioning operation identity is explicit end to end. Managed installs and global updates never share analytics,
  retry actions, or local state labels accidentally.
- Accepted commands have one lifecycle owner. Shutdown aborts and awaits them; lifecycle disposal finishes before
  `PluginRuntime` disposal.
- Client payloads remain sanitized. Original failures, stack traces, paths, and command output remain useful in local
  logs only.

## Review Findings Preserved

The replacement must address these latest #1458 findings in their assigned slices:

- **`3999200805` (Step 2):** replace the pointless single-implementation locator interface with an injectable concrete
  locator.
- **`3999200808` (Step 6):** map the Antigravity command DTO into plugin-domain probe variants in its repository.
- **`3999205383` (Step 3):** make the first owned Windows shutdown attempt tree-aware and require observed exit.
- **`3999205385` (Step 5):** give Codex setup tests deterministic executable presence instead of developer PATH.
- **`3999205390` (Step 7):** mark canonical inspection only after success or re-inspect from failure handling.
- **`3999205396` (Step 6):** directly test every Antigravity candidate, especially a missing PATH harness beside a
  present server.
- **`3999205399` (Steps 2 and 5):** centralize missing-command classification in Foundation and reuse it in
  descriptors.
- **Lint report `5652131685` (Step 6):** remove the opaque Antigravity command-result model and its suppression through
  repository mapping.

Earlier valid fixes at `efbafc6cee` and host-independent Hermes tests at `0caf101b9a` remain required unless a simpler
replacement design makes their exact implementation obsolete.

## Delivery Plan

Series slug `path-runtime-authority-split`; every PR title is
`<emoji> [path-runtime-authority-split] <description> [step <x>/9]`.

1. **Step 1/9**
   - Title: `🌱 [path-runtime-authority-split] docs: plan replacement PR sequence [step 1/9]`
   - Scope: preserve source provenance, fixed sequence, findings, budgets, and gates in this plan and tracker only.
2. **Step 2/9**
   - Title: `⚙️ [path-runtime-authority-split] foundation: centralize executable and command control [step 2/9]`
   - Scope: add the concrete executable locator, locale-independent classification, abortable command execution, and
     direct Foundation tests. No plugin behavior activates.
3. **Step 3/9**
   - Title: `⚙️ [path-runtime-authority-split] bridge: settle commands and terminate process trees [step 3/9]`
   - Scope: settle accepted lifecycle/runtime commands before disposal and make Windows shutdown tree-aware. This
     independently useful safety slice carries finding `3999205383`.
4. **Step 4/9**
   - Title: `🚧 [path-runtime-authority-split] runtime: make PATH authoritative for managed copies [step 4/9]`
   - Scope: add managed PATH authority, newest-version inventory policy, mutation-boundary revalidation, and PATH-aware
     startup refresh. PATH suppresses managed selection, install, cleanup, and startup upgrades.
5. **Step 5/9**
   - Title: `⚙️ [path-runtime-authority-split] plugins: report outdated PATH runtimes and safe updaters [step 5/9]`
   - Scope: add backend-neutral setup/update metadata and standard harness descriptors/tests. Explicit overrides and
     unsupported updaters remain manual.
6. **Step 6/9**
   - Title: `⚙️ [path-runtime-authority-split] antigravity: inspect PATH pairs without side effects [step 6/9]`
   - Scope: add inert Antigravity API/repository/service inspection and pair-aware authority, repository-domain mapping,
     and exhaustive predicate tests.
7. **Step 7/9**
   - Title: `🚧 [path-runtime-authority-split] bridge: execute sanitized global runtime updates [step 7/9]`
   - Scope: add wire operation identity, bridge admission/execution, sanitized progress and failures, canonical
     re-inspection, and operation-scoped client-core consumption. Headless update control becomes active.
8. **Step 8/9**
   - Title: `⚙️ [path-runtime-authority-split] client: present runtime updates and reconcile docs [step 8/9]`
   - Scope: add settings/session UI, analytics isolation, retry/grouping, regression docs, README, and the capability
     matrix. This is the complete user-facing activation.
9. **Step 9/9**
   - Title: `🌿 [path-runtime-authority-split] verify: run runtime authority coverage and retire plan [step 9/9]`
   - Scope: run the release-level matrix, reconcile preserved behavior and findings, record evidence, and retire the
     plan under `.plan/completed/`.

Only one replacement implementation PR is open at a time. After one merges, create its successor from updated `main`.
Never stack all nine branches or force-push #1458 to mimic this sequence.

## Per-Step Ownership And Data Flow

### Step 1 — plan only

- **Package/layer:** repository process documentation under `.plan/active/path-runtime-authority-split/`.
- **Files/classes:** `PLAN.md` and `TRACKER.md`; no production class.
- **Dependency/data flow:** none. This step changes no runtime, wire, client, database, or user-visible behavior.

### Step 2 — Foundation executable and command control

- **Package/layer:** `bridge/sesori_bridge_foundation`, Foundation/host-adapter layer.
- **Production files:**
  - `lib/src/host_executable_locator.dart` — `HostExecutablePresence` and injectable concrete
    `IoHostExecutableLocator`;
  - `lib/src/host_process_command_executor.dart` — existing `HostProcessCommandExecutor.runAbortable`; and
  - `lib/sesori_bridge_foundation.dart` — public export.
- **Collaborators/ownership:** `IoHostExecutableLocator({required bool? platformIsWindows})` owns filesystem-backed
  executable lookup and process-missing classification, using `dart:io`; it has no interface or resource lifetime.
  `HostProcessCommandExecutor` keeps its existing injected `HostProcessService`, shell/environment flags, capture cap,
  and timeout; `runAbortable` adds `StartAbortSignal` without storing operation state.
- **Dependency/data flow:** `dart:io` host facts → `IoHostExecutableLocator` neutral presence result; and
  `HostProcessService` → `HostProcessCommandExecutor` → neutral `CommandResult`. Plugin policy is forbidden here.
- **Activation:** dormant primitives only. No descriptor, bridge command, wire, or client behavior changes.

### Step 3 — bridge lifecycle and process-tree safety

- **Package/layer:** `bridge/app`; `SystemProcessApi` is the operating-system API boundary, while runtime/lifecycle
  classes own bridge orchestration.
- **Production files/classes:**
  - `lib/src/server/api/system_process_api.dart` — `SystemProcessApi.sendGracefulSignal` and `sendForceSignal` use
    tree-aware Windows `taskkill`, with injected `ProcessRunner`, `ServerClock`, platform flag, and platform name;
  - `lib/src/services/plugin_lifecycle_service.dart` — sealed `_ActivePluginCommand`, `_ActiveResponseCommand`, and
    install-only `_ActiveRuntimeProvisionCommand`, each owning non-null settlement;
  - `lib/src/runtime/plugin_runtime.dart` — private `_RuntimeMutation` owns one `StartAbortController` and one
    `Completer<void>` for each accepted install;
  - `lib/src/runtime/bridge_shutdown_coordinator.dart` — `BridgeShutdownPhase.runtimeDispose` and ordered phases; and
  - `lib/src/orchestrator.dart` — composition registers lifecycle disposal before runtime disposal.
- **Dependency/data flow:** `ProcessRunner` API result → `SystemProcessApi` → existing process service/repository
  → bridge ownership consumer. Separately, runtime mutation → `PluginRuntime` settlement
  → `PluginLifecycleService` → `BridgeShutdownCoordinator` ordered disposal.
- **Activation:** lifecycle safety for existing install commands only. Global-update request types do not land early.

### Step 4 — managed runtime PATH authority

- **Packages/layers:** `bridge/sesori_plugin_runtime` service layer;
  `bridge/sesori_plugin_interface` internal descriptor contract; managed plugin descriptors are plugin consumers;
  `bridge/app` is the startup consumer.
- **Production files/classes:**
  - runtime `managed_runtime_path_authority.dart` — existing multi-implementation `ManagedRuntimePathAuthority` and
    `RuntimeVersionManagedRuntimePathAuthority`;
  - runtime `runtime_version_validator.dart` — `RuntimeVersionValidator` consumes concrete
    `IoHostExecutableLocator` and preserves `RuntimeProbeMissing` versus ambiguous failures;
  - runtime `managed_runtime_inventory.dart`, `managed_runtime_selection_service.dart`,
    `managed_runtime_install_service.dart`, `managed_runtime_upgrade_service.dart`,
    `managed_runtime_provision_service.dart`, and `composition/managed_runtime_composition.dart` —
    `ManagedRuntimeInventory`, `ManagedRuntimeSelectionService`, `ManagedRuntimeInstallService`,
    `ManagedRuntimeUpgradeService`, `ManagedRuntimeProvisionService`, and `ManagedRuntimeComposition`;
  - interface `lifecycle/bridge_plugin_descriptor.dart` — asynchronous `needsManagedRuntimeUpgrade` contract only; and
  - descriptors in `sesori_plugin_opencode`, `sesori_plugin_codex`, `sesori_plugin_copilot`,
    `sesori_plugin_cursor`, `sesori_plugin_deepseek`, `sesori_plugin_omp`, and `sesori_plugin_pi` — managed startup
    authority overrides and caller updates only.
- **Bridge consumers:** `bridge/app/lib/src/runtime/plugin_runtime.dart` passes injected `_setupProcesses` and immutable
  environment; `plugin_lifecycle_repository.dart` forwards the async decision;
  `plugin_lifecycle_service.dart.upgradeManagedRuntimes` admits only eligible startup refreshes; and
  `bridge_runtime_runner.dart` awaits bounded eligibility probes, rechecks shutdown, then continues startup without
  awaiting downloads.
- **Collaborators/ownership:** `RuntimeVersionManagedRuntimePathAuthority` requires `RuntimeManifest` and
  `RuntimeVersionValidator`; `ManagedRuntimeUpgradeService` requires `ManagedRuntimePathAuthority` and
  `ManagedRuntimeInventory`; `ManagedRuntimeInstallService` requires manifest, installer, cleaner, authority, and asset
  resolver. `ManagedRuntimeComposition` constructs these stateless graphs. No app-owned PATH decision enters a plugin.
- **Dependency/data flow:** Foundation locator/command result → `RuntimeVersionValidator`
  → `ManagedRuntimePathAuthority` → selection/install/upgrade services → descriptor
  → `PluginRuntime` repository/service adapters → `BridgeRuntimeRunner` startup consumer.
- **Activation:** PATH presence now blocks managed selection, mutation, cleanup, and startup refresh. No outdated
  status, global updater, wire change, or UI action lands in this step.

### Step 5 — standard harness setup and updater metadata

- **Packages/layers:** `sesori_plugin_interface` owns backend-neutral internal contracts; each standard
  `bridge/sesori_plugin_*` package owns its backend-specific descriptor behavior.
- **Production files/classes:**
  - interface `plugin_setup_status.dart` — `PluginSetupRuntimeOutdated`;
  - interface `plugin_control_capability.dart` — `PluginControlCapability.runtimeUpdate`;
  - interface `bridge_plugin_descriptor.dart` — immutable `PluginRuntimeUpdateSpec({executable, arguments, timeout})`
    and `runtimeUpdateSpec`; and
  - descriptor files for OpenCode, Codex, Copilot, Cursor, DeepSeek, OMP, Pi, Claude, Hermes, and Grok listed in the
    preserved diff. Each descriptor owns only its runtime names, minimum/version interpretation, hint, and updater.
- **Collaborators/ownership:** managed descriptors reuse `RuntimeVersionValidator`; Claude, Hermes, and Grok call the
  concrete Foundation locator for missing-error classification instead of copying helpers. Descriptors remain const and
  inert; `PluginRuntimeUpdateSpec` owns data only. Copilot, DeepSeek, and Antigravity declare no automatic updater.
- **Boundary mapping:** include the minimum existing bridge/shared setup-state mapping required to represent
  `runtimeOutdated` without enabling the update command. Do not land operation progress, command admission, or client
  action code here.
- **Dependency/data flow:** Foundation/runtime probe outcome → owning descriptor boundary → backend-neutral
  `PluginSetupStatus` → existing bridge setup repository mapping. Backend identifiers never enter shared/app policy.
- **Activation:** setup inspection can report an outdated PATH runtime and safe update capability internally/over the
  existing setup snapshot. No surface can request a global update yet.

### Step 6 — Antigravity inert pair inspection

- **Package/layer:** `bridge/sesori_plugin_antigravity`; backend-specific behavior remains entirely in this plugin.
- **Production files/classes:**
  - API `api/antigravity_acp_api.dart` and `api/models/antigravity_version_dto.dart` — `AntigravityAcpApi.version`
    performs only bounded `--version`; `AntigravityVersionDto` remains API-local;
  - repository `repositories/antigravity_runtime_version_repository.dart` — `AntigravityRuntimeVersionRepository`
    maps DTO exit/output into domain probe variants;
  - models `models/antigravity_runtime_version.dart` — sealed domain variants
    `AntigravityRuntimeVersionProbeSucceeded`, `AntigravityRuntimeVersionProbeRejected`, and
    `AntigravityRuntimeVersionProbeFailed`, carrying no `CommandResult`;
  - services `antigravity_runtime_service.dart`, `antigravity_setup_service.dart`,
    `antigravity_runtime_path_authority_calculator.dart`, and `antigravity_managed_runtime_path_authority.dart` —
    `AntigravityRuntimeService`, `AntigravitySetupService`, `AntigravityRuntimePathAuthorityCalculator`, and
    `AntigravityManagedRuntimePathAuthority`; and
  - `runtime/antigravity_plugin_descriptor.dart`, `runtime/antigravity_authentication_composer.dart`, and package export
    update composition/callers in lockstep.
- **Collaborators/ownership:** `AntigravityAcpApi` keeps injected `AcpProcessFactory`, `AcpOutputInterceptor`, and
  `CommandExecutor`; version inspection uses only the executor. `AntigravityRuntimeVersionRepository` injects that API.
  `AntigravityRuntimeService` injects `AntigravityRuntimeRepository` and the stateless calculator.
  `AntigravitySetupService` injects runtime service, version repository, and existing profile inspection service.
  `AntigravityManagedRuntimePathAuthority` injects runtime repository, calculator, and `PlatformTarget`.
- **Dependency/data flow:** Foundation command result → `AntigravityAcpApi` DTO
  → `AntigravityRuntimeVersionRepository` domain probe → `AntigravitySetupService`
  → descriptor setup status. Physical pair evidence flows repository → calculator/service
  → descriptor or managed authority; it never enters shared code.
- **Activation:** Antigravity setup becomes inert and pair-aware. Only `Missing(path, server)` permits managed fallback;
  a missing sibling harness, storage error, malformed pair, or any present server remains authoritative.

### Step 7 — wire, bridge update execution, and client-core consumption

- **Packages/layers:** `shared/sesori_shared` owns released wire values; `bridge/app` owns execution; existing
  `client/module_core` repository/service/state layers consume the contract without presentation.
- **Shared production files/types:**
  - `plugin_management.dart` — `PluginManagementCapability.runtimeUpdate`,
    `PluginRuntimeProvisionKind { managedInstall, globalUpdate, unknown }`, `PluginInstallPhase.updating`, and
    `PluginLifecycleCommandRequest.updateRuntime` / `PluginLifecycleUpdateRuntimeRequest`;
  - `plugin_setup_response.dart` — `PluginSetupState.runtimeOutdated`; and
  - `sesori_sse_event.dart` — `SesoriPluginInstallProgress.operation`, with generated Freezed/JSON files regenerated.
- **Bridge production files/classes:** `plugin_runtime.dart` adds `PluginRuntime.updateRuntime` using the descriptor
  spec, injected `_setupProcesses`, immutable `_environment`, `HostProcessCommandExecutor`, and Step 3
  `plugin_lifecycle_repository.dart` forwards it; `plugin_lifecycle_service.dart` admits
  `PluginLifecycleUpdateRuntimeRequest` into `_ActiveRuntimeProvisionCommand` and executes both operations through
  `_executeRuntimeProvision`; `orchestrator.dart` wires existing dependencies. The service re-inspects through
  `_inspectForCommand` after yielded or thrown failure and marks inspection only after it succeeds.
- **Client-core files/classes:** `services/models/plugin_install_state.dart` adds operation to `PluginInstallState` and
  `PluginInstallProgress`; `services/plugin_management_service.dart` maps update requests/SSE into operation-scoped
  state while using existing `PluginRepository`, `ConnectionService`, `ProductAnalyticsService`,
  `PluginAuthenticationBrowserService`, and `ActiveBridgeLocality`;
  `cubits/plugin_management/plugin_management_cubit.dart` exposes `updateRuntime` through the existing
  service/repository request seam. Global updates are not reported as
  managed-install analytics.
- **Dependency/data flow:** shared Freezed contract → bridge command API → `PluginLifecycleService`
  → `PluginLifecycleRepository` → `PluginRuntime`
  → descriptor-owned updater. Progress returns through the legacy SSE name with explicit operation.
  On client: shared event/request → existing `PluginRepository`
  → `PluginManagementService` → `PluginManagementCubit`. No UI consumer lands yet.
- **Released compatibility:** omitted `SesoriPluginInstallProgress.operation` defaults to `managedInstall` for older
  bridges; unknown enum strings map to `unknown`; the legacy event name remains; older clients can receive progress but
  cannot send the new request, and newer clients show generic non-actionable state for unknown future operations.
- **Activation:** bridge headless callers can request verified global updates. Client core can represent them correctly,
  but no new settings/session action is exposed until Step 8.

### Step 8 — client presentation and documentation

- **Packages/layers:** `client/module_app_ui` consumer/presentation layer, existing `client/module_core` service/cubit
  seam where final presentation selectors require it, `client/app` integration tests, and repository docs.
- **Production files/classes:** `harness_settings_detail_view.dart` (`HarnessSettingsDetailView`),
  `harness_settings_presentation.dart`, `harness_settings_sheets.dart`, `harnesses_settings_view.dart`
  (`HarnessesSettingsView`), and `session_harness_unavailable_notice.dart` (`SessionHarnessUnavailableNotice`), plus
  `app_en.arb` and generated localization files. No backend identifier or updater command enters these files.
- **Client data flow:** `PluginRepository` API/repository → Step 7 `PluginManagementService` →
  `PluginManagementCubit` → `context.watch/select` UI consumers. Presentation switches only on shared setup,
  capability, phase, and operation enums. Disabled/stopping grouping wins over progress; a same-plugin event for a
  different locally active operation is ignored; unknown operation copy stays generic with no guessed retry command.
- **Analytics:** no new arbitrary event or parameter map. Existing `ProductAnalyticsService` install outcomes remain
  restricted to `managedInstall`; global update progress cannot masquerade as an install conversion.
- **Docs:** update `README.md`, `docs/HARNESS_CAPABILITIES.md`,
  `docs/regression/plugin-runtime-installation.md`, and `docs/regression/plugin-setup-and-lifecycle.md` to match only
  behavior merged through this step.
- **Activation:** complete phone/desktop user action and truthful status/progress copy. No database or persistence
  impact.

### Step 9 — verification and retirement

- **Package/layer:** plan evidence only; tests execute owning packages without production edits.
- **Files:** update `TRACKER.md`, reconcile final plan claims, then move this directory from `.plan/active/` to
  `.plan/completed/` after all acceptance gates pass.
- **Dependency/data flow:** none. No user-visible, wire, database, or production behavior changes.

## Size Budgets

Changed lines count additions plus deletions against each PR's merge base, including tests, docs, fixtures, and
generated files. These are ceilings, not targets:

| Step | Ceiling | Basis |
|---|---:|---|
| 1 | 650 | Plan and tracker only. |
| 2 | 700 | Current Foundation diff is 435 lines; leave room for review fixes. |
| 3 | 1,000 | Narrow app lifecycle/process implementation and focused tests. |
| 4 | 1,450 | Runtime core, managed-descriptor startup hooks, and tests must compile together. |
| 5 | 1,400 | Standard descriptor behavior and tests; no Antigravity or app execution flow. |
| 6 | 1,000 | Current Antigravity diff is 737 lines plus required mapping/test corrections. |
| 7 | 1,500 | Shared wire, bridge execution, and minimum client-core consumption. |
| 8 | 1,400 | Client UI/tests and current 354-line documentation change. |
| 9 | 500 | Verification evidence and plan retirement only. |

Before each first push and every follow-up push, measure the whole slice. If a slice approaches its ceiling, move a
clean inactive portion to a later step; do not add compatibility code solely to split an internal contract.

## Dependency And Extraction Rules

- Step 2 lands neutral primitives before consumers.
- Step 3 may use Step 2 command-abort primitives but cannot introduce global-update product behavior.
- Step 4 updates every caller affected by managed-runtime interface changes in the same PR.
- Step 5 may add dormant setup/update metadata; include only minimal boundary mapping required for every package to
  compile. Do not activate a client command early.
- Step 6 owns every Antigravity-specific identifier, pair rule, DTO, and profile interpretation.
- Step 7 updates shared contracts and all consumers required for source compatibility in lockstep. It may carry minimum
  client-core parsing/state support, but presentation stays in Step 8.
- Step 8 owns user copy, grouping, sheets/actions, analytics outcome wording, and feature documentation.
- Generated files stay with their source declaration and are regenerated, never copied or edited selectively.
- Constructor or sealed-type changes include all in-repository callers in the same slice.
- Use #1458 as source evidence. Prefer rebuilding the simpler owner boundary over wholesale cherry-picking files.

## Compatibility And Security

- Preserve backward/forward compatibility only for released client↔bridge transport. The operation discriminator keeps
  the released managed-install default for omitted legacy values; unknown future operations remain generic.
- Internal Dart packages update in lockstep with no shims for branch-local contracts.
- Setup inspection may execute only bounded, inert version/help/profile reads. It must never install, authenticate,
  initialize ACP, or start a backend.
- No raw updater/probe output, arguments, errors, or paths cross the wire. Tests assert sanitized payloads and useful
  local logging.
- PATH-managed trust postures remain separate: PATH authority must not weaken managed artifact verification or E2E
  transport behavior.

## Complexity Budget

Persistent mutable parts: none.

In-memory mutable parts retained from the reviewed implementation:

- one active command entry per plugin, represented by sealed response/runtime-provision variants;
- one runtime mutation completion handle per admitted managed install or global update; and
- existing client per-plugin install state extended with an operation variant rather than a second state machine.

Each is required to settle a concrete admitted operation, join matching requests, reject conflicts, or preserve truthful
UI state. Deliberately not added: updater queues, timers, retries, path caches, global locks, per-command output
buffers, migration state, or speculative recovery registries.

## Cleanup Assessment

Direct cleanup in the series:

- remove the one-to-one `HostExecutableLocator` interface;
- remove per-descriptor process-missing/path-absence helpers;
- remove the Antigravity opaque command-result model and its lint suppression;
- remove stale managed-version downgrade logic and inaccurate installer/updater documentation.

No persisted fields, database columns, routes, or released transport shapes become obsolete. No broader cleanup is
planned.

## Per-Step Verification

- **Step 2:** Foundation analysis/tests. Cover POSIX/Windows lookup, working-directory precedence, PATHEXT, broken
  entries, error-code classification, timeout/abort, and sanitized command results.
- **Step 3:** bridge app lifecycle/runtime/process tests and analysis. Cover graceful/force tree termination, failed
  signals, unconfirmed exit, command completion before stream closure, and lifecycle-before-runtime disposal.
- **Step 4:** plugin runtime/interface plus every managed descriptor's affected tests and analysis. Cover present broken
  PATH entries, true absence, newest managed version, pinned/newer no-downgrade, managed-copy preservation, and
  mutation-boundary revalidation.
- **Step 5:** every standard harness descriptor test and analysis. Cover outdated versus unknown, explicit overrides,
  safe updater availability, manual-only harnesses, deterministic host-independent PATH fixtures, and shared missing
  classification.
- **Step 6:** Antigravity package tests and analysis. Cover blank build labels, unrelated ACP failures, profile failure
  retaining runtime metadata, every pair candidate, and inert inspection.
- **Step 7:** shared contract tests, bridge app lifecycle/runtime/runner tests, client-core state/service tests, and
  owning-package analysis. Cover duplicate joining, conflicts, abort, sanitized failures, recovery inspection after
  yielded/thrown failures, compatibility defaults, and startup abort recheck.
- **Step 8:** client UI/core/app focused tests and analysis. Cover update labels/actions, disabled grouping precedence,
  mismatched progress isolation, unknown-operation fallback, session notices, and analytics operation identity.
- **Step 9:** full bridge analysis and package test matrix plus affected client/shared matrix. Investigate only concrete
  failures; do not rerun unchanged passing commands without cause.

## Architecture And Review Gates

- Architecture-plan review is required for this plan before Step 1 opens.
- Architecture-implementation review applies to Steps 4, 6, 7, and 8 because they move or add production boundaries,
  contracts, or cross-layer flow. Steps 2 and 3 receive it only if extraction changes those boundaries materially.
- Correctness review remains separate from architecture review. Apply valid findings without broad cleanup.
- PR monitoring owns current-head CI, comments, readiness, and merge progression.

## Final Acceptance

Step 9 may retire the plan only when:

1. each slice merged within its recorded ceiling or has an explicitly documented bounded exception;
2. all intended behavior from #1458 is present on `main` or deliberately replaced by a simpler equivalent;
3. every valid review finding listed above has a merged disposition;
4. all supported harnesses report PATH authority and updater capability honestly;
5. relevant bridge, shared, client, and plugin tests/analyzers pass; and
6. regression documentation describes the final implementation without superseded-PR claims.
