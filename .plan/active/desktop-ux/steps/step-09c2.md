# Step 9.c.2a — Sidebar activity and refresh owners

Delivery 16/20; branch `desktop-ux/sidebar-activity-foundation`.
Base: #1526 squash `a6b32359f028151649cc4553297bc60ace1c0383`, tree
`4d52ad1899e1de87690bc3fb4593f66a03eb82b0`.

## Scope

- Add aggregate explicit refresh to the existing recent-session owner while retaining useful loaded data.
- Derive cross-project activity and ordinary rows in a pure Layer-4 desktop projection.
- Expose lower-layer inventory refresh operations and coordinate them in a Layer-3 desktop service.
- Keep the refresh Cubit dependent only on that service boundary and map its result to presentation state.
- Add no Flutter UI, cache, backend request shape, persistence, timer, subscription, project-view claim or
  analytics event.

## Architecture evidence

The scoped plan review `7a64c300-5abd-46c6-8656-b75f8acb882d` rejected foundation placement and
widget-owned orchestration. Its required corrections are reflected in the revised ephemeral plan
(`/tmp/rose-elephant-sidebar-activity-plan.md`, SHA-256
`969ed00036e7a5e8a8128a7f0ce1470553955f1a18bda3b33d7084c12db7b11a`).

Implementation checkpoint A: `9366c1078240a0a21bf9f0559dd7417fadac1102`. Review
`e7bfea4e-0ebc-4ce0-88a8-489447c25eda` rejected its direct Cubit dependencies (report SHA-256
`df0b203935525475ac6b60a10e298b850a910af4416f647f97161eeaa7b9e79b`). Checkpoint B:
`a30e454cb10b0738f10af8159a674db2fa05c75f`, tree `735cc6c782713f05ba8aeb6ad6513c725d350744`.
Review `29fa5fda-f21c-4cca-90d6-0eebb6977f7a` approved the exact base..B range under the reviewed boundary
(report SHA-256 `84823cda7172172b5ffd549ffcc04fc1ce43712131ee69a16f6d563d367734d1`).

PR review then identified a stricter scoped layering violation: B's Layer-4 workflow still depended on peer
Layer-4 Cubits. Final source checkpoint C, `24eca1eadeebdfd266fe255d9b75f9fbaf8de56f`, tree
`4ae1c72e11d4e018abd87a1119db0334d58befed`, applies that finding. Lower-layer project/session operation
contracts are implemented by the existing owners; `DesktopSidebarRefreshService` is Layer 3 and depends only on
those contracts; the Layer-4 refresh Cubit depends only on the service. C also makes superseded explicit session
refreshes await the winning read and requires callers to state the priority-exclusion set explicitly. The earlier
checkpoint-B verification is superseded by the exact-C evidence below.

## Verification

Checkpoint C measures 838 changed lines (724 additions, 114 deletions) across 20 all-path files: 274 production,
320 test, 244 documentation and zero generated lines. The total includes the checkpoint-C version of this file and
every changed path in the range; this later evidence-only correction is outside it. Reproduce the immutable measurement
from the repository root:

```bash
git diff --numstat de6fdfe82ca84b05ce45cdeba6d0a1e48c2bb594..24eca1eadeebdfd266fe255d9b75f9fbaf8de56f --
```

Pinned Dart/Flutter 3.47.4 verification against exact checkpoint C used these commands and working directories:

```bash
cd client/module_core
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test -r expanded \
  test/cubits/recent_sessions/recent_sessions_cubit_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test -r expanded \
  test/cubits/project_list/project_list_cubit_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

cd ../module_desktop_core
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test -r expanded \
  test/cubits/desktop_sidebar/desktop_sidebar_session_projection_test.dart \
  test/cubits/desktop_sidebar/desktop_sidebar_refresh_cubit_test.dart \
  test/services/desktop_sidebar_refresh_service_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

cd ../desktop
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos
```

Results: 20 recent-session cases, 90 project-list cases and 10 desktop-core cases pass; all three analyzers are
clean. Logs: `/tmp/rose-elephant-1533-recent-review-fixes-final.log`,
`/tmp/rose-elephant-1533-project-review-fixes-final.log`, and
`/tmp/rose-elephant-1533-desktop-core-review-fixes-final.log`. No generator was needed; all changed Dart sources were
formatted.

## Boundaries

Series-title metadata receipt: `/tmp/rose-elephant-series-20-title-receipts.json`.
This prerequisite has no user-visible, database, wire, bridge/plugin or generated-file impact.
The local successor owns Flutter composition, localization, regression docs and synthetic renders.
No production DI, app smoke, GUI/helper/bridge, auth/preferences, registration, secure storage or device operation ran.
Native/live qualification remains required and unexecuted.
