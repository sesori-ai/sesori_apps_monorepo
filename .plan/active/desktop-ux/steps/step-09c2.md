# Step 9.c.2a — Sidebar activity and refresh owners

Delivery 16/20; branch `desktop-ux/sidebar-activity-foundation`.
Base: #1526 squash `a6b32359f028151649cc4553297bc60ace1c0383`, tree
`4d52ad1899e1de87690bc3fb4593f66a03eb82b0`.

## Scope

- Add aggregate explicit refresh while retaining useful loaded project and session data.
- Derive cross-project activity and ordinary rows in a pure Layer-4 desktop projection.
- Own explicit refresh requests below Cubits in DI-registered `InventoryRefreshService`.
- Make project and recent-session Cubits independent consumers of their request streams.
- Register the desktop project-then-session workflow and keep its refresh Cubit dependent only on that boundary.
- Add no Flutter UI, data cache, backend request shape, persistence, timer, registry, project-view claim or
  analytics event.

## Architecture evidence

The scoped plan review `7a64c300-5abd-46c6-8656-b75f8acb882d` rejected foundation placement and
widget-owned orchestration. Implementation checkpoint A, `9366c1078240a0a21bf9f0559dd7417fadac1102`, was then
rejected by review `e7bfea4e-0ebc-4ce0-88a8-489447c25eda` for direct Cubit dependencies (report SHA-256
`df0b203935525475ac6b60a10e298b850a910af4416f647f97161eeaa7b9e79b`). Checkpoint B,
`a30e454cb10b0738f10af8159a674db2fa05c75f`, tree `735cc6c782713f05ba8aeb6ad6513c725d350744`,
was approved for the exact reviewed range by `29fa5fda-f21c-4cca-90d6-0eebb6977f7a` (report SHA-256
`84823cda7172172b5ffd549ffcc04fc1ce43712131ee69a16f6d563d367734d1`).

PR review found two later gaps. Checkpoint C, `24eca1eadeebdfd266fe255d9b75f9fbaf8de56f`, removed direct
Cubit imports, made superseded session refreshes await the winning read, and required explicit priority exclusions.
Codex thread `PRRT_kwDORscidM6jSnwo` then identified that C's operation implementations were still Cubits at runtime,
so the future shell would have to construct a service from higher-layer state owners.

The proportional follow-up plan is `/tmp/rose-elephant-1533-refresh-ownership-followup.md`, SHA-256
`0a772d72332a663d79e20cdc103d9b4d56ab1d2ec369da10af0d9401f5f2145d`. Final source checkpoint D is
`3f707c6ed315d8105c49c385cd51fbcc3c9d9f68`, tree `477e33de70753d7b265296c8184e64dd48f56a16`.
`InventoryRefreshService` now owns explicit typed requests below the Cubits; each inventory Cubit consumes only its
own synchronous request stream and reuses its existing winning-read/application path. `DesktopSidebarRefreshService`
is registered in desktop-core DI and depends only on that lower service. No Cubit implements a refresh-operation port,
and no shell-owned workflow construction remains. Earlier architecture approval covered B, not D; no third
implementation-review sub-agent was invoked beyond the repository's two-pass limit.

## Verification

Checkpoint D measures 1,057 changed lines (937 additions, 120 deletions) across 27 all-path files: 367 production,
381 test, 282 documentation and 27 generated lines. The total includes the checkpoint-D version of this file and every
changed path in the range; this later evidence-only correction is outside it. Reproduce from the repository root:

```bash
git diff --numstat de6fdfe82ca84b05ce45cdeba6d0a1e48c2bb594..3f707c6ed315d8105c49c385cd51fbcc3c9d9f68 --
```

Pinned Dart/Flutter 3.47.4 verification against exact checkpoint D used these commands and working directories:

```bash
cd client/module_core
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart run build_runner build \
  --delete-conflicting-outputs
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test -r expanded \
  test/services/inventory_refresh_service_test.dart \
  test/cubits/recent_sessions/recent_sessions_cubit_test.dart \
  test/cubits/project_list/project_list_cubit_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

cd ../module_desktop_core
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart run build_runner build \
  --delete-conflicting-outputs
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test -r expanded \
  test/cubits/desktop_sidebar/desktop_sidebar_session_projection_test.dart \
  test/cubits/desktop_sidebar/desktop_sidebar_refresh_cubit_test.dart \
  test/services/desktop_sidebar_refresh_service_test.dart \
  test/di/injection_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

cd ../desktop
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos
```

Results: 113 core cases and 11 desktop-core cases pass; all three analyzers are clean. Generated registration places
`InventoryRefreshService` in core DI and `DesktopSidebarRefreshService` in desktop-core DI. Logs:
`/tmp/rose-elephant-1533-core-ownership-followup-final.log` and
`/tmp/rose-elephant-1533-desktop-core-ownership-followup-final.log`.

## Boundaries

Series-title metadata receipt: `/tmp/rose-elephant-series-20-title-receipts.json`.
This prerequisite has no user-visible, database, wire or bridge/plugin impact. Generated impact is limited to DI
registration for the two new service owners. The successor owns Flutter composition, localization, regression docs and
synthetic renders. No app smoke, GUI/helper/bridge, auth/preferences, registration, secure storage or device operation
ran. Native/live qualification remains required and unexecuted.
