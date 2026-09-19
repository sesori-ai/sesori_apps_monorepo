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

Commands, from this worktree's corresponding package directories (`SDK` is the pinned toolchain's `bin`):

```bash
# client/module_core — initial batch; retain its 117 successful cases, not its failed overall status
"$SDK/dart" test --reporter=json test/cubits/project_list/project_list_cubit_test.dart \
  test/services/recent_session_inventory_service_test.dart
# client/module_core — corrected winner fixtures and added partial-failure case
"$SDK/dart" test --reporter=json test/cubits/project_list/project_list_cubit_test.dart \
  --name 'headless refresh follows'
"$SDK/dart" test --reporter=json test/services/recent_session_inventory_service_test.dart \
  --name 'waits for every admitted project'
# client/module_desktop_core — nine cases
"$SDK/dart" test --reporter=json test/orchestration/desktop_sidebar_refresh_orchestrator_test.dart \
  test/cubits/desktop_sidebar/desktop_sidebar_refresh_cubit_test.dart
# client/desktop — initial combined command produced the successful provider receipt
"$SDK/flutter" test --no-pub --reporter=json test/core/widgets/desktop_cockpit_cubit_provider_test.dart \
  test/core/widgets/desktop_cockpit_shell_test.dart
# client/desktop — final standalone cockpit command passed all 40 cases
"$SDK/flutter" test --no-pub --reporter=json test/core/widgets/desktop_cockpit_shell_test.dart
# client/app — seven cases
"$SDK/flutter" test --no-pub --reporter=json test/features/project_list/project_list_nav_bar_test.dart
# each owning module named above, excluding app (no app source changes)
"$SDK/dart" analyze --fatal-infos
```

Receipt manifests under `/tmp/rose-elephant-controls-`: `initial-tests.json`, `corrected-tests.json`,
`final-verification.json` and `qualified-verification.json`. Counts come from non-hidden JSON `testDone` events,
not declarations or accumulated reruns. The unchanged passing workflow/provider/mobile cases were not rerun merely
for reassurance. Generated registration/localization evidence is `generation.json` with the same prefix.

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
