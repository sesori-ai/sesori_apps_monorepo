# Step 9.c.2b.1 — Scoped recent-session inventory ownership

Delivery 17/22; branch `desktop-ux/sidebar-refresh-ownership`.
Base: #1533 squash `d530a19ec993b295a058f6ff0ae0316bb5ef0bd5`, tree
`d50ffff0e019ed579d2e362f6b83b185ffef2268`.

## Scope and ownership

`RecentSessionInventoryService` replaces the business owner formerly inside `RecentSessionsCubit`.
The service performs reads, retains the immutable inventory, admits/removes winning project snapshots,
patches live state, and owns pending-read identity and lifecycle-generation fences without a mounted Cubit.
The Cubit seeds from the service's current value, mirrors subsequent snapshots, and delegates retry.
Its close cancels only its subscription; it neither stops service work nor clears retained data.

The service is an injectable factory, not a singleton. `DesktopCockpitCubitProvider` resolves one instance
through an outer `RepositoryProvider`, creates its adapter eagerly before initial project publication, and disposes
that instance with the signed-in cockpit. A replacement consumer sees the same retained data; a new cockpit gets an
empty inventory. Shell wiring adds no subscriptions, repository calls, admission logic, or refresh policy.
The entry variants move to service models; presentation resolvers and the desktop projection stay at Layer 4.

The same two maps and six event subscriptions move with their owner. One seeded BehaviorSubject replaces Bloc's
inventory storage. There is no second inventory, request bus, upward callback, timer, queue, retry policy, account
reset machine, view claim, backend rule, transport/persistence contract, or analytics event.
Old Cubit business methods/model paths are removed rather than shimmed. Core DI is regenerated from annotations.

## Split and review

The lower-owner delivery splits at its two existing inventories: this slice moves recent ownership and its consumer;
9.c.2b.2 / 18/22 moves project ownership and the typed desktop workflow. Controls remain 9.c.2c / 19/22.
The series now has 22 PRs. Existing published Git history stays intact; current PR title metadata follows the tracker.
Published-title receipts: `/tmp/rose-elephant-series-22-title-receipts.json`.

Plan: `/tmp/rose-elephant-recent-inventory-ownership-plan.md`, SHA-256
`c9328407dc7aa97b35180c06db98d1e7d7e5d6329300a74132a2b2a0aadffcbf`.
Architecture plan review `46845cb8-150d-481a-a6c0-d9589a9bf170` approved without findings.
Report: `/tmp/rose-elephant-recent-inventory-plan-review.md`, SHA-256
`a44b51357a7d9985d5c49e5838161da3f6a80ae6fd8b7df7f8b58e2383904ef3`.
Architecture implementation review `e6a2807d-c60c-44f9-8032-a016d19180b2` approved all 19 changed paths without
findings at source `538ba831a45145ca3be7d3b9037ab4fc00449849`, tree
`0a401b6ed7e43a7fabf5a8fbca71d1292477c75a`. Report:
`/tmp/rose-elephant-recent-inventory-implementation-review.md`, SHA-256
`37d1691e64dd667ed0715be0351ee07eb677fb75a3ff6c3cec724a8af9f4d2fe`.

That source measures 1,112 changed lines (701 additions, 411 deletions) across 19 paths:
498 production, 273 tests, 329 documentation, and 12 generated lines. The following publication-evidence commit
is outside that immutable source measurement. Target: ≤1,200 all-path lines.

```bash
git diff --numstat d530a19ec993b295a058f6ff0ae0316bb5ef0bd5..538ba831a45145ca3be7d3b9037ab4fc00449849 --
```

## Verification commands

All tests use fake collaborators and owned test state. No production DI/bootstrap or app smoke test runs.
Pinned Dart/Flutter 3.47.4; working directory:
`/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.

```bash
SDK=/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin
(cd client/module_core && "$SDK/dart" run build_runner build --delete-conflicting-outputs)
(cd client/module_core && "$SDK/dart" test --reporter=json \
  test/services/recent_session_inventory_service_test.dart \
  test/cubits/recent_sessions/recent_sessions_adapter_test.dart \
  test/services/project_list_service_test.dart)
(cd client/module_core && "$SDK/dart" test --reporter=json test/services/recent_session_inventory_service_test.dart)
(cd client/desktop && "$SDK/flutter" test --no-pub --reporter=json \
  test/core/widgets/desktop_cockpit_cubit_provider_test.dart \
  test/core/widgets/desktop_cockpit_shell_test.dart)
(cd client/module_desktop_core && "$SDK/dart" test --reporter=json \
  test/cubits/desktop_sidebar/desktop_sidebar_session_projection_test.dart)
(cd client/app && "$SDK/flutter" test --no-pub --reporter=json \
  test/features/session_list/session_tile_menu_test.dart)
(cd client/module_core && "$SDK/dart" analyze --fatal-infos)
(cd client/module_desktop_core && "$SDK/dart" analyze --fatal-infos)
(cd client/desktop && "$SDK/dart" analyze --fatal-infos)
(cd client/app && "$SDK/dart" analyze --fatal-infos)
git diff --check
```

All 77 focused cases pass: 21 inventory, 3 adapter, 6 project service, 38 desktop (37 cockpit plus 1 provider),
2 projection, and 7 mobile menu cases. The inventory cases run without a Cubit. Adapter cases cover current replay,
immediate/live mirroring, retry delegation, independent close, and replacement consumers. The fake-backed provider
case verifies eager admission, one instance per scope, disposal, and an empty replacement inventory.
The initial provider fixture mixed Flutter's fake and real async zones; the corrected desktop command exits 0.
Inventory stream assertions skip the new service's retained replay when awaiting the next publication; its standalone
21-case rerun passes. Four owning/affected analyzers pass. Core generation changes only the factory registration.

## Boundaries

Internal refactor only: no intended user-visible or database change. Explicit refresh and its winning-result API
remain the next slice; no unused public refresh API is introduced here. Native/live qualification remains outstanding.
No real app, bridge/helper, auth/preferences, secure storage, device, registration,
or production database operation ran.
