# PATH Runtime Authority Split Tracker

## Series

- Slug: `path-runtime-authority-split`
- Base: `main` at `4854865eedf6`
- Preserved source: PR #1458 at `0caf101b9a`
- Current step: 2/9 — centralize executable and command control
- Open replacement implementation PRs: Step 2 pending publication
- Architecture review: approved 2026-09-13 after exact ownership clarification; Step 8 core edits stay selector-only

## Steps

| Step | Status | PR | Changed-line ceiling |
|---|---|---|---:|
| 1. Plan replacement sequence | Merged | #1462 | 650 |
| 2. Centralize executable and command control | In progress | Pending | 700 |
| 3. Settle commands and terminate process trees | Not started | — | 1,000 |
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
| `3999205383` — Windows first-attempt process tree | 3 | Planned |
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
- Step 1 content: 524 lines, below its 650-line ceiling.
- No Dart/Flutter suites required for plan-only changes.

## Step 2 Checklist

- [x] Add injectable concrete `IoHostExecutableLocator`; retain no one-to-one interface.
- [x] Centralize locale-independent process-missing and positive PATH-absence classification.
- [x] Add abortable `HostProcessCommandExecutor` execution with observed termination.
- [x] Add direct host lookup, classification, timeout, abort, and termination tests.
- [x] Run focused Foundation tests and strict analysis.
- [x] Complete architecture-implementation review and apply valid findings.
- [x] Measure the full Step 2 diff against its 700-line ceiling.
- [ ] Commit, push, and open Step 2 PR.
- [ ] Start PR monitor for Step 2.

## Step 2 Evidence

- Focused Foundation tests: 11 passed.
- `dart analyze --fatal-infos`: no issues.
- Architecture implementation review: APPROVED with no violations.
- Full Step 2 diff: 526 changed lines, below the 700-line ceiling.
