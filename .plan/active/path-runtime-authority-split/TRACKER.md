# PATH Runtime Authority Split Tracker

## Series

- Slug: `path-runtime-authority-split`
- Base: `main` at `4854865eedf6`
- Preserved source: PR #1458 at `0caf101b9a`
- Current step: 1/9 — plan replacement sequence
- Open replacement implementation PRs: none
- Architecture review: approved 2026-09-13 after exact ownership clarification; Step 8 core edits stay selector-only

## Steps

| Step | Status | PR | Changed-line ceiling |
|---|---|---|---:|
| 1. Plan replacement sequence | In progress | Pending | 650 |
| 2. Centralize executable and command control | Not started | — | 700 |
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
- **8:** client-core service/cubit → app UI consumers and docs; settings/session presentation; complete user action and
  copy with no persistence.
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
- [ ] Commit, push, and open Step 1 PR.
- [ ] Reply on #1458 with replacement provenance and close it without deleting the branch.
- [ ] Start PR monitor for Step 1.

## Verification Evidence

- Architecture-plan review: APPROVED on permitted second pass; no blocking findings.
- `git diff --check`: passes.
- Added-line width: zero lines over 120 characters before commit.
- Step 1 content: 522 lines, below its 650-line ceiling.
- No Dart/Flutter suites required for plan-only changes.
