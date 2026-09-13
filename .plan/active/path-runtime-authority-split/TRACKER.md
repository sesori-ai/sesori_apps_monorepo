# PATH Runtime Authority Split Tracker

## Series

- Slug: `path-runtime-authority-split`
- Base: `main` at `4854865eedf6`
- Preserved source: PR #1458 at `0caf101b9a`
- Current step: 3/9 — settle commands and terminate process trees
- Open replacement implementation PRs: Step 3 — #1466
- Architecture review: approved 2026-09-13 after exact ownership clarification; Step 8 core edits stay selector-only

## Steps

| Step | Status | PR | Changed-line ceiling |
|---|---|---|---:|
| 1. Plan replacement sequence | Merged | #1462 | 650 |
| 2. Centralize executable and command control | Merged | #1463 | 850 |
| 3. Settle commands and terminate process trees | In progress | #1466 | 1,000 |
| 4. Make PATH authoritative for managed copies | Not started | — | 1,450 |
| 5. Report outdated PATH runtimes and safe updaters | Not started | — | 1,400 |
| 6. Inspect Antigravity PATH pairs without side effects | Not started | — | 1,000 |
| 7. Execute sanitized global runtime updates | Not started | — | 1,500 |
| 8. Present runtime updates and reconcile docs | Not started | — | 1,400 |
| 9. Run coverage and retire plan | Not started | — | 500 |

## Ownership And Activation Map

- **1:** `.plan` documentation; no production owner or behavior.
- **2:** `sesori_bridge_foundation` Foundation/host adapter; `IoHostExecutableLocator` and
  `HostProcessCommandExecutor`; dormant neutral primitives.
- **3:** `bridge/app` API/runtime/service; `SystemProcessApi`, `PluginRuntime`, `PluginLifecycleService`, and
  `BridgeShutdownCoordinator`; existing install/shutdown safety only.
- **4:** plugin runtime/interface → managed descriptors → app startup; `RuntimeVersionManagedRuntimePathAuthority`,
  selection/install/upgrade services, and `BridgeRuntimeRunner`; PATH blocks every managed path with no updater action.
- **5:** plugin interface → standard descriptors; `PluginSetupRuntimeOutdated`, `PluginRuntimeUpdateSpec`, and each
  owning descriptor; setup/capability only with no command execution.
- **6:** Antigravity API → repository → service → descriptor; `AntigravityAcpApi`,
  `AntigravityRuntimeVersionRepository`, `AntigravitySetupService`, and authority calculator; inert pair-aware setup.
- **7:** shared wire → bridge runtime/repository/service → client-core repository/service/cubit;
  `PluginRuntimeProvisionKind`, `PluginLifecycleService`, `PluginRuntime`, `PluginManagementService`, and
  `PluginManagementCubit`; headless update plus non-presentational client consumption.
- **8:** client-core service/cubit → app UI consumers and docs; settings/session presentation;
  complete user action and copy with no persistence.
- **9:** plan evidence only; no production owner or behavior.

Exact files, constructor collaborators, dependency flows, compatibility defaults, and plugin ownership are recorded in
`PLAN.md` under `Per-Step Ownership And Data Flow`.

## Preserved Review Findings

| Comment / report | Target step | Status |
|---|---:|---|
| `3999200805` — concrete executable locator | 2 | Planned |
| `3999200808` — Antigravity repository mapping | 6 | Planned |
| `3999205383` — Windows first-attempt process tree | 3 | Implemented |
| `3999205385` — deterministic Codex PATH tests | 5 | Planned |
| `3999205390` — recovery inspection after enable failure | 7 | Planned |
| `3999205396` — direct Antigravity absence predicate tests | 6 | Planned |
| `3999205399` — centralized missing-command policy | 2, 5 | Planned |
| `5652131685` — Antigravity lint suppression | 6 | Planned removal |

## Step 1 Checklist

- [x] Preserve #1458 source branch and immutable reviewed head.
- [x] Measure the original PR: 5,833 changed lines across 106 files.
- [x] Define coherent replacement slices and hard ceilings.
- [x] Map all latest review findings to replacement slices.
- [x] Complete architecture-plan review and apply valid findings.
- [x] Validate plan/tracker formatting and changed-line budget.
- [x] Commit, push, and open Step 1 PR.
- [x] Reply on #1458 with replacement provenance and close it without deleting the branch.
- [x] Start PR monitor for Step 1.

## Step 1 Evidence

- PR #1462 merged at `27cd7c76fa`.
- Architecture-plan review: APPROVED on permitted second pass; no blocking findings.
- `git diff --check`: passed.
- Added-line width: zero lines over 120 Unicode characters or UTF-8 bytes.
- Immutable size range: `4854865eedf6152d1371777f061adbb1514a34c5` to
  `27cd7c76faa0fc9814be465c2ccb9bcb9773e5ac`.
- Base-to-head numstat: `444 0` for `PLAN.md` and `80 0` for `TRACKER.md`; 524 changed lines total.
- Final review-fix commit (`2f79efb056ae` to `27cd7c76faa0`) changed `PLAN.md` by `15 13` and `TRACKER.md` by
  `4 4`; the immutable base-to-head total above includes that tracker reconciliation.
- Step 1 content: 524 lines, below its 650-line ceiling.
- No Dart/Flutter suites required for plan-only changes.

## Step 2 Checklist

- [x] Add injectable concrete `IoHostExecutableLocator`; retain no one-to-one interface.
- [x] Centralize locale-independent process-missing and positive PATH-absence classification.
- [x] Add abortable `HostProcessCommandExecutor` execution with observed termination.
- [x] Add direct host lookup, classification, timeout, abort, output-drain, and termination tests.
- [x] Run focused Foundation tests and strict analysis.
- [x] Complete architecture-implementation review and apply valid findings.
- [x] Measure the full Step 2 diff against its review-adjusted 850-line ceiling.
- [x] Commit, push, and open Step 2 PR (#1463).
- [x] Start PR monitor for Step 2.

## Step 2 Evidence

- PR #1463 merged as `825583d25d` from accepted head `869eb8c65b`.
- Focused Foundation tests: 21 passed.
- Cursor hung-version-probe CI regression: passed.
- `dart analyze --fatal-infos`: no issues.
- Architecture implementation review: APPROVED with no violations.
- Immutable Step 2 implementation range: `b20e1268a2546daec24412db8700b2f1b7048515` to
  `c0bfe0cb00e273ccba3026d7f034fb4877a09b03`.
- Numstat basis: `.plan` paths are repository-relative; remaining paths are relative to
  `bridge/sesori_bridge_foundation/`.

  | File | Additions | Deletions |
  |---|---:|---:|
  | `.plan/active/path-runtime-authority-split/PLAN.md` | 1 | 1 |
  | `.plan/active/path-runtime-authority-split/TRACKER.md` | 53 | 9 |
  | `lib/sesori_bridge_foundation.dart` | 1 | 0 |
  | `lib/src/host_executable_locator.dart` | 170 | 0 |
  | `lib/src/host_process_command_executor.dart` | 155 | 9 |
  | `test/host_executable_locator_test.dart` | 202 | 0 |
  | `test/host_process_command_executor_test.dart` | 216 | 8 |

- Implementation head: 798 additions plus 27 deletions, or 825 changed lines across 7 files.
- This evidence edit replaces lines one-for-one; base-to-current numstat remains 798 + 27 = 825.
- All churn is authored; generated churn is zero.
- Review-expanded lookup and spawn fencing raised the Step 2 ceiling from 700 to 850; the total remains below it.

## Step 3 Checklist

- [x] Make graceful and forceful Windows shutdown requests process-tree-aware.
- [x] Separate a standalone Windows successor through the named one-shot launcher before terminating the predecessor tree.
- [x] Await the launcher's zero-exit child-creation acknowledgement before permitting predecessor shutdown.
- [x] Preserve the native Windows environment and override only the consumed launcher marker for the real successor.
- [x] Preserve every non-zero tree-termination result unless pre-inspection proved the root was already absent.
- [x] Track and await accepted `PluginRuntime` mutations during disposal.
- [x] Give lifecycle response commands and accepted provisions distinct sealed ownership.
- [x] Settle active lifecycle commands before closing their progress and snapshot streams.
- [x] Dispose `PluginLifecycleService` before `PluginRuntime` in separate shutdown phases.
- [x] Add focused process-tree, mutation-settlement, command-settlement, and phase-order tests.
- [x] Run focused bridge tests and strict analysis.
- [x] Complete architecture-implementation review and apply valid findings.
- [x] Measure the full Step 3 diff against its 1,000-line ceiling.
- [x] Commit, push, open Step 3 PR, and start its monitor.

## Step 3 Evidence

- Numstat/merge base: `825583d25d53587c28292b506e27e34f251cf98d` (Step 2 squash merge).
- Initial implementation head: `87fdf32596bd1c7cfe7a68382dd84a8c2b3fa37f`.
- First review-fix checkpoint: `67e061722ad85a8f087f47a158227a28a98ec7c0`.
- Second review-fix implementation checkpoint: `4d45b00c5db895f3fc355ea55acec070c92a8c63`.
- Second review accepted/evidence head: `fed982198691b1083660a12d9be8197148082e80`.
- Named-launcher follow-up implementation checkpoint: `54cad58138ba96c89561d1f50c65a41834ca57a5`.
- Acknowledged-handoff implementation checkpoint: `34e1827c2f1b1d2e36dde85110ca29a486d08c32`.
- Native-environment handoff checkpoint: `PENDING_NATIVE_ENVIRONMENT_HANDOFF_HEAD`.
- The following evidence-only commit replaces that placeholder without changing base-to-head numstat; its accepted head
  is recorded in the PR body because a commit cannot embed its own hash.
- Initial focused process, shutdown, runtime, lifecycle, runner, and restart tests: 189 passed.
- Latest review-round affected process, runner, and restart tests: 80 passed.
- Named-launcher extraction tests: 12 passed.
- Acknowledged-handoff affected matrix: 90 tests passed.
- Native-environment handoff affected matrix: 90 tests passed.
- `dart analyze --fatal-infos` for `bridge/app`: no issues.
- Second/final architecture implementation review: APPROVED with no violations.
- `git diff --check`: passed.
- Initial head: 312 additions plus 66 deletions, or 378 changed lines across 11 files.
- First review-fix checkpoint: 472 additions plus 72 deletions, or 544 changed lines across 18 files.
- Current review-fix tree: 813 additions plus 83 deletions, or 896 changed lines across 27 files.
- All churn is authored; generated churn is zero; the total remains below the 1,000-line ceiling.
