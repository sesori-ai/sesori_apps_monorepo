# Step 9.c.2c — Typed sidebar refresh and purposeful controls

Delivery 19/22; branch `desktop-ux/sidebar-refresh-controls`.
Base: #1543 squash `a772a85a141b617f0d766d0d6a7d6aa11b654a30`, tree
`cee8b57a727f3f5dad3677194b61c1b4b2e1e6e9`. The older stash-source branch is preserved, not reset or rewritten.
This successor owns both the typed refresh workflow and its first production control, not presentation alone.
Target ≤1,450 all-path changed lines, including generated output, tests and documentation;
remeasure before publishing.

## Required behavior

- Compose the existing scoped `ProjectInventoryService` and `RecentSessionInventoryService` instances below
  presentation. Neither Cubits nor widgets implement operation ports, complete request buses, or perform sequencing.
- Explicit refresh updates current projects and their recent-session inventories. Follow eventual winning reads even
  when a later owning read supersedes a successor that has already completed. Preserve failure and supersession
  observability; useful rows remain visible. Add direct lower-layer tests for these sequences before claiming them.
- Ship the workflow with its first refresh control and typed busy/failure presentation. No future-only API, second
  inventory, new automatic retry policy, timer, global registry, or per-row persistence is justified by this delivery.
- Keep `_SidebarInventory` render-only and the Activity projection Flutter/Prego-free at desktop-core Layer 4.
  Preserve all-project Activity, priority exclusions, selected-session pinning, independent action scopes and leases.
- Simplify controls using plain-language local-computer wording. Keep local supervision distinct from a connected
  remote computer; Quit remains app-scoped. Retain useful-only hints, semantics, stable keys, reduced motion and
  native Apple indicators. Any applicable analytics use existing authoritative outcomes, not arbitrary tap tracking.

## Execution boundary

Selectively reuse the local stash named `sidebar-activity-controls-successor`, object
`1bfa2c1ff8ad859773303eb60e7a81902d7d8668` (created on `desktop-ux/sidebar-activity-controls`).
Only control presentation, hints, labels and relevant test intent were reused. The stash remains intact; current
Activity ownership/action leases were retained. The concrete plan below received approval before implementation.

Run focused fake-backed service/adapter/control tests and owning analyzers. Do not bootstrap production DI, relaunch
the real GUI, stop/take over a bridge/helper, touch authentication/preferences/registration or run the app smoke
locally.
Synthetic previews, automated tests and architecture review do not establish native qualification.

## Reviewed plan and implementation

- Plan: `/tmp/rose-elephant-sidebar-refresh-controls-plan.md`, SHA-256
  `8a8e62428c228b5db540601437efcfeee02bc3fd537614fb25831fcd805462fe`.
- Architecture plan review: `53baaeb8-7dbc-4e5e-a621-356a5b9a32d2`, approved without findings.
  Preserved report: `/tmp/rose-elephant-sidebar-refresh-controls-plan-review.md`, SHA-256
  `a9691d55fe1d0ca9d6f322dd0b8cbd9f2544cdb96b881bf1b8170bd3f26b8512`.
- `ProjectInventoryService` follows `_latestFetch` after every awaited result. It adds no state or requests;
  ordinary coalescing and publication/application fences remain distinct.
- `RecentSessionInventoryService.refresh()` joins pending reads and refreshes other currently admitted entries.
  One latest-read map replaces the pending map. Each handle owns identity, pending status and typed completion;
  completed failure remains observable when useful rows survive. Removal evicts the handle, disposal fences reads,
  and existing lifecycle successors/reconnect/catalog policies remain intact. No second inventory or outcomes map.
- Factory `DesktopSidebarRefreshOrchestrator` consumes the cockpit's same two services via required factory params.
  Project then recent phases return a typed combined outcome. Ordinary project failure still permits recent work;
  unexpected exceptions retain useful local error/stack diagnostics. It has no mutable state or lifecycle owner.
- `DesktopSidebarRefreshCubit` contains only typed presentation state and intent suppression while busy. Neither
  it nor widgets perform inventory sequencing. Closing presentation suppresses late presentation, not service work.
- The footer groups This computer, refresh and Settings. New project and collapse remain at the top; compact home
  remains accessible. Icon/busy semantics, keyboard activation, useful status/truncated hints and retained rows are
  covered. There are no new database/wire contracts or analytics events; inventory analytics keep their policy.

## Focused evidence

All commands below used the pinned Flutter 3.47.4 toolchain. They ran on **uncommitted working trees based on
`a772a85a141b617f0d766d0d6a7d6aa11b654a30`**, before the eventual source commit existed. Receipts include command,
cwd, timestamps, exit status and SHA-256 of each saved working-tree patch. This is not one common-checkpoint matrix.

- 177 distinct focused cases have successful receipts: project behavior/lifetime/winner 94, recent inventory 26,
  desktop workflow/status adapter 9, cockpit 40, provider ownership 1 and mobile project navigation 7.
- Initial core command: 117 successes and two failures in the new project-winner fixtures. The fixtures originally
  admitted the new owner after the waiter had already resumed. They now use a live observer to admit a silent read
  synchronously before resumption; both cases passed in their targeted follow-up. No production workaround was added.
  The later partial-recent-failure case passed separately. Initial command exit 1 is not represented as a passing batch.
- Initial desktop compilation rejected the test's private/non-public `FocusState` assumption. Focus now comes from the
  icon descendant's public `Focus.of` context. UI tests then exposed unnamed icon controls; explicit idle/busy/Settings
  semantics fixed them. Semantics handles now dispose inside `finally`, before Flutter's end-of-test verification.
  The final cockpit command passed all 40 cases, including existing Activity/actions/motion cases.
- Core, desktop-core, desktop and shared UI analyzers passed. Owning DI/localization generators, formatting and
  whitespace checks passed. No production bootstrap, real GUI/helper/bridge or account/preference mutation occurred.

Historical commands and results below use explicit cwd/toolchain. Reproduction on a later tree does not recreate
an earlier failed fixture; the saved working-tree patch receipts identify each original execution checkpoint.

```bash
ROOT=/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant
SDK=/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin
cd "$ROOT"
# Initial core batch: exit 1, 117 successes / two failures.
(cd client/module_core && "$SDK/dart" test --reporter=json \
  test/cubits/project_list/project_list_cubit_test.dart test/services/recent_session_inventory_service_test.dart)
# Corrected winner fixtures: exit 0, two successes; added partial-failure case: exit 0, one success.
(cd client/module_core && "$SDK/dart" test --reporter=json \
  test/cubits/project_list/project_list_cubit_test.dart --name 'headless refresh follows')
(cd client/module_core && "$SDK/dart" test --reporter=json \
  test/services/recent_session_inventory_service_test.dart --name 'waits for every admitted project')
# Desktop-core: exit 0, nine successes.
(cd client/module_desktop_core && "$SDK/dart" test --reporter=json \
  test/orchestration/desktop_sidebar_refresh_orchestrator_test.dart \
  test/cubits/desktop_sidebar/desktop_sidebar_refresh_cubit_test.dart)
# Initial desktop: exit 1 (cockpit compilation), one successful provider case.
(cd client/desktop && "$SDK/flutter" test --no-pub --reporter=json \
  test/core/widgets/desktop_cockpit_cubit_provider_test.dart test/core/widgets/desktop_cockpit_shell_test.dart)
# Final qualified cockpit: exit 0, 40 successes. Earlier corrected/final attempts exited 1; keep their receipts.
(cd client/desktop && "$SDK/flutter" test --no-pub --reporter=json test/core/widgets/desktop_cockpit_shell_test.dart)
# Mobile navigation: exit 0, seven successes.
(cd client/app && "$SDK/flutter" test --no-pub --reporter=json \
  test/features/project_list/project_list_nav_bar_test.dart)
# Each analyzer exited 0. Core/desktop have later qualified receipts; the other two keep their final receipts.
(cd client/module_core && "$SDK/dart" analyze --fatal-infos)
(cd client/module_desktop_core && "$SDK/dart" analyze --fatal-infos)
(cd client/desktop && "$SDK/dart" analyze --fatal-infos)
(cd client/module_app_ui && "$SDK/dart" analyze --fatal-infos)
# Owning generators: each exited 0; no core generator was needed for these method changes.
(cd client/module_desktop_core && "$SDK/dart" run build_runner build)
(cd client/module_app_ui && "$SDK/flutter" gen-l10n)
```

Historical formatter commands ran from `$ROOT` with that SDK and exited 0. At 2026-09-18T23:38:15Z, 14 files were
formatted (nine changed); 23:45:23Z formatted three (one changed); 23:49:57Z formatted three (two changed).
The explicit whitespace check below passed before the source commit at 2026-09-19T00:02:46Z. An earlier bare
`git diff --check` invocation exited 2 without diagnostics; its status is not presented as a successful check.

```bash
cd "$ROOT"
# 23:38:15Z
"$SDK/dart" format \
  client/module_core/lib/src/services/project_inventory_service.dart \
  client/module_core/lib/src/services/recent_session_inventory_service.dart \
  client/module_core/lib/src/services/models/recent_sessions_entry.dart \
  client/module_core/test/services/recent_session_inventory_service_test.dart \
  client/module_core/test/cubits/project_list/project_list_cubit_test.dart \
  client/module_desktop_core/lib/src/orchestration/desktop_sidebar_refresh_orchestrator.dart \
  client/module_desktop_core/lib/src/cubits/desktop_sidebar/desktop_sidebar_refresh_cubit.dart \
  client/module_desktop_core/lib/sesori_desktop_core.dart \
  client/module_desktop_core/test/orchestration/desktop_sidebar_refresh_orchestrator_test.dart \
  client/module_desktop_core/test/cubits/desktop_sidebar/desktop_sidebar_refresh_cubit_test.dart \
  client/desktop/lib/core/widgets/desktop_sidebar.dart client/desktop/lib/core/widgets/desktop_cockpit_shell.dart \
  client/desktop/test/core/widgets/desktop_cockpit_shell_test.dart \
  client/desktop/test/core/widgets/desktop_cockpit_cubit_provider_test.dart
# 23:45:23Z; the chained whitespace check also exited 0 at this checkpoint.
"$SDK/dart" format client/module_core/test/cubits/project_list/project_list_cubit_test.dart \
  client/desktop/lib/core/widgets/desktop_sidebar.dart client/desktop/test/core/widgets/desktop_cockpit_shell_test.dart
git diff --check
# 23:49:57Z
"$SDK/dart" format client/module_core/test/services/recent_session_inventory_service_test.dart \
  client/desktop/lib/core/widgets/desktop_sidebar.dart client/desktop/test/core/widgets/desktop_cockpit_shell_test.dart
# Final pre-commit whitespace check: exit 0.
git diff --check HEAD --
```

Receipt manifests under `/tmp/rose-elephant-controls-`: `initial-tests.json`, `corrected-tests.json`,
`final-verification.json` and `qualified-verification.json`. Counts come from non-hidden JSON `testDone` events,
not declarations or accumulated reruns. The unchanged passing workflow/provider/mobile cases were not rerun merely
for reassurance. Generated registration/localization evidence is `generation.json` with the same prefix.

## Reviewed source checkpoint

Source commit: `96213b62ef51b76a511696ee4ee030d27c584c83`, tree
`447ef59ce1b100ec78ef759d66a87468fa62df38`. Full range: 1,019 lines (843 additions/176 deletions), 24 paths;
402 production, 385 tests, 166 documentation and 66 generated (953 authored lines).
The measurement includes this document and tracker exactly as they existed at that source commit, not this
later approval record. Reproduce with:

```bash
git diff --numstat a772a85a141b617f0d766d0d6a7d6aa11b654a30..96213b62ef51b76a511696ee4ee030d27c584c83 --
```

Implementation architecture review `5716b51b-b3a5-40e3-9a07-82f90bb219c7` approved the full committed range without
findings. Preserved report: `/tmp/rose-elephant-sidebar-refresh-controls-implementation-review.md`, SHA-256
`6444fa2b550aebc4409a7b58053b19e2b58ecdd594efb2af05da8921e27e0900`.
Initial publication `fd702cf2f42a61d3d63fdb61e25ee44317113642` added only the approval record: 1,037 lines
(861 additions/176 deletions), 24 paths; 402 production, 385 tests, 184 documentation and 66 generated.
That checkpoint includes this document before the later feedback corrections below, not those corrections.
No passing executable verification was rerun for that documentation-only publication follow-up.

## PR feedback correction — retirement, not backend cancellation

PR #1545's initial `fd702cf` head passed 12/12 checks. Both automated reviewers identified that removing a recent
entry fenced application but left explicit refresh waiting for obsolete I/O. The owner now completes its existing
receipt on replacement, removal or disposal; terminal driver completions are idempotent. Load/retry callers still
await their actual driver, while explicit refresh follows receipt ownership. No field, owner, timer, subscription,
retry policy or backend cancellation was added. Late responses/errors cannot restore entries or seed unseen state.

Correction plan: `/tmp/rose-elephant-1545-review1-correction-plan.md`, SHA-256
`0a07e8e4c17944697ba7e0598d6bc750ef68f67cefffb6d6441e2fdfdc6188cc`.
Plan review `0aecc971-f530-4a1d-a497-9d4665980abb` approved without findings; preserved report
`/tmp/rose-elephant-1545-review1-plan-review.md`, SHA-256
`f1abb70a4bf52c64debb4a1a8c28ae2cc9dce15bfe7f4f6a7786767b552a2c3a`.
The loading comment now includes retries. The orchestrator deliberately remains fail-fast for unexpected throws;
ordinary relay/API failures already become explicit failure results and still permit recent work. No speculative
recovery after an invariant/programming failure was added.

Follow-up verification ran on an **uncommitted tree based on `fd702cf2f42a61d3d63fdb61e25ee44317113642`**.
The final run passed 30 cases (27 recent inventory, three adapter) and core analysis, both exit 0. These overlap the
original 177-case evidence and must not be added to that count. The first correction run passed 30 cases but its
analyzer exited 1 for `avoid_bang_operator`; the receipt-following loop now handles removal through nullable identity
without a bang or redundant fallback. Both receipts remain under `/tmp/rose-elephant-1545-review1-` as
`verification.json` and `final-verification.json`, with exact cwd/commands/times, saved patches and SHA-256 hashes.
No unchanged passing suites, generators or native probes were repeated.

```bash
cd "$ROOT"
# Final correction commands: each exited 0; test done.success was true.
(cd client/module_core && "$SDK/dart" test --reporter=json \
  test/services/recent_session_inventory_service_test.dart \
  test/cubits/recent_sessions/recent_sessions_adapter_test.dart)
(cd client/module_core && "$SDK/dart" analyze --fatal-infos)
# Four changed Dart files were formatted before the first correction run; zero changed.
"$SDK/dart" format client/module_core/lib/src/services/recent_session_inventory_service.dart \
  client/module_core/lib/src/services/models/recent_sessions_entry.dart \
  client/module_core/test/services/recent_session_inventory_service_test.dart \
  client/module_desktop_core/lib/src/orchestration/desktop_sidebar_refresh_orchestrator.dart
# After the null-safe loop change, this file was formatted again; zero changed. Both checks exited 0.
"$SDK/dart" format client/module_core/lib/src/services/recent_session_inventory_service.dart
git diff --check HEAD --
```

## Rendering and remaining qualification

Four synthetic views passed using the actual sidebar and packaged fonts, with fake state and no production DI:
expanded light, minimum-width dark, compact light and compact dark busy. Images were inspected under
`/tmp/rose-elephant-controls-preview.UKnUUS/`. The first failure screenshot preceded the alert's paint; one extra
fixture frame and an explicit alert-text assertion produced the inspected settled failure image under
`/tmp/rose-elephant-controls-failure-preview.YWCAKu/`. The initial and corrected preview receipts remain separate.
These four views are additional synthetic checks, not part of the 177 tracked focused cases or native qualification.

No permission prompts, bridge stop/takeover, app relaunch/bundle replacement, registration/auth/preferences/database
mutation or desktop app-smoke execution was admitted. Native energy/compositing, live bridge flows and previously
recorded lifecycle/permission/large-text qualification remain outstanding.
