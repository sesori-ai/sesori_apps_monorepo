# Step 9.c.2a — Sidebar Activity projection and presentation

Delivery 16/21; branch `desktop-ux/sidebar-activity-foundation`.
Base: #1526 squash `a6b32359f028151649cc4553297bc60ace1c0383`, tree
`4d52ad1899e1de87690bc3fb4593f66a03eb82b0`.

## Scope

- Derive every running or live-unseen non-archived session across all current projects in a pure Layer-4 desktop
  projection, preserving project order and session order.
- Present those sessions once in a keyed Activity section with project context, status, selection, navigation and the
  existing action menus.
- Exclude Activity IDs before choosing each project's ordinary three rows plus active selected-session pin while keeping
  `All sessions · N` based on the full active inventory.
- Admit collapsed and offscreen projects through the existing recent-session Cubit. Successful authoritative project
  snapshots are its sole automatic admission trigger; the Flutter sidebar only renders the resulting state.
- Reuse Prego list reconciliation/reduced-motion behavior, stable project/session keys, existing action-only
  `SessionListCubit` scopes, native Apple indicators, useful-only hints and accessibility semantics.
- Add no explicit refresh operation, lower-layer refresh owner, backend request shape, data cache, timer, queue,
  project-view claim, persistence or analytics event.

## Review-driven boundary

The scoped plan review `7a64c300-5abd-46c6-8656-b75f8acb882d` rejected Layer-0 projection placement and widget-owned
refresh sequencing. Earlier implementation checkpoints then tried a Layer-4 orchestrator, Cubit-implemented operation
ports, and a Layer-3 request bus consumed by Cubits. PR thread `PRRT_kwDORscidM6jyatt` correctly found that the bus
still required mounted Layer-4 presentation owners to execute lower-layer operations. Thread
`PRRT_kwDORscidM6jyat1` found that its explicit session-refresh result chain could lose a later winner after a
completed successor left the pending
map. Those refresh additions were removed rather than hidden behind another abstraction.

Current-head thread `PRRT_kwDORscidM6jzTfa` then correctly rejected landing the state-free projection without a
production consumer. The correction retains only the prepared Activity subset. `_SidebarInventory` composes the
projection in `client/desktop`; `DesktopSidebarSessionProjection` remains Flutter/Prego-free in desktop-core. Activity
and ordinary project groups are sibling presentation peers with independent action-only Cubit scopes.

Later current-head threads required two ownership corrections. `PRRT_kwDORscidM6jz6TR` moved automatic all-project
admission out of `_SidebarInventory`: `ProjectListService` publishes successful snapshots without retaining another
inventory, and the pure-Dart `RecentSessionsCubit` owns admission and deduplication. `PRRT_kwDORscidM6jz6TX` keeps an
action Cubit alive only while an admitted mark-seen operation completes, so optimistic removal of the final Activity
row cannot suppress authoritative failure recovery.

Newest current-head threads tightened those fixes. `PRRT_kwDORscidM6j1GZS` requires project-snapshot publication only
for the latest overlapping service read. `PRRT_kwDORscidM6j1OCP` requires a winning snapshot to remove absent recent
entries and fence their pending reads. `PRRT_kwDORscidM6j1OCX` requires delete completion to survive an Activity-group
removal. The correction generation-gates the non-retained project stream, reconciles recent state, drains already
admitted mark/archive/delete operations, and uses the stable sidebar inventory context for follow-up UI while passing
its action Cubit explicitly. Thread `PRRT_kwDORscidM6j1mlL` then exposed the pre-admission interval while confirmation
UI remains open. A short-lived action-scope lease now covers each dialog and response workflow, transferring to the
tracked operation on confirm and releasing on cancel. Explicit refresh execution remains delivery 17/21;
refresh/control presentation remains 18/21.

Architecture plan review `878b3d10-d3a4-48ad-9876-2d842f4ccccf` rejected the first correction draft for leaving the
duplicate expansion trigger and underspecifying lifecycle/action-menu composition. All valid findings were applied
directly without another review. Revised plan:
`/tmp/rose-elephant-1533-activity-consumer-plan.md`, SHA-256
`a893e5a3120356e2b4688e1c2c7ce55e43cc5f1163ec1fca5f61a56625aa8832`.
Review report SHA-256: `a5e9543041d35bb6604171ec30c496d8e54d64e6ac7a9673541d0ab6657a3834`.

The latest focused correction plan is `/tmp/rose-elephant-1533-review-corrections-plan.md`, SHA-256
`fdec952c74323fe93f0daf5043cfb49629abefdcac9258618fc863f8ae1ed309`. Reviews
`fcdadab0-2c2e-495c-8236-f444907c2463` and `e0607827-77e7-45d3-a51e-e8aab32f4b2e` approved the earlier revisions.
Review `196e83e2-5386-45db-8ef8-1e63bd4287cb` approved the confirmation-lifecycle revision without findings. Latest
report: `/tmp/rose-elephant-1533-dialog-lease-architecture-plan-review.md`, SHA-256
`4be4e6c1351f13dd7c00e89c2afb40b3e6b4f43136dba7e49f3501bc4f871b48`.

Final source checkpoint: `9a172e0984320def3bb09da28b6ccf8e4ee6c22c`, tree
`0af04ba677b385c6068f174c148c6cad78fd8263`. It measures 1,586 all-path changed lines (1,380 additions,
206 deletions) across 27 files: 755 production, 409 tests, 401 documentation and 21 generated lines. The later
publication-evidence correction is outside that immutable measurement. The modest soft-cap overage keeps the
review-required dialog lifetime fix with the Activity action owner it corrects; no independently valid split exists.

```bash
git diff --numstat de6fdfe82ca84b05ce45cdeba6d0a1e48c2bb594..9a172e0984320def3bb09da28b6ccf8e4ee6c22c --
```

## Verification

Pinned Dart/Flutter 3.47.4:

```bash
cd client/module_app_ui
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/flutter gen-l10n
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/flutter test \
  test/features/session_list/session_list_content_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/flutter analyze --fatal-infos

cd ../module_core
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test -r expanded \
  test/services/project_list_service_test.dart \
  test/cubits/recent_sessions/recent_sessions_cubit_test.dart \
  test/cubits/session_list/session_list_cubit_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

cd ../module_desktop_core
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart test -r expanded \
  test/cubits/desktop_sidebar/desktop_sidebar_session_projection_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

cd ../desktop
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/flutter test \
  test/core/widgets/desktop_cockpit_shell_test.dart
/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin/dart analyze --fatal-infos

git diff --check
```

Results: 37 desktop cockpit/sidebar cases, 4 session-list presentation cases, 2 projection cases and 93 focused
module-core cases pass (5 project-list service, 20 recent-session and 68 session-list). Module-app-ui, module-core,
module-desktop-core and desktop analyzers are clean. The 11 app session-split cases that failed under the
discarded DI constructor change passed after its removal at checkpoint `888e67c21e9`; those unchanged inputs were not
rerun after the Activity-only desktop composition.

The ignored production-widget fixture passed four synthetic Linux variants and each image was inspected: expanded
light, 200-pixel dark, compact light and compact dark. Output:
`/tmp/rose-elephant-sidebar-activity-consumer-preview-final.1cDuCK/`. These prove bounded synthetic rendering only,
not native macOS behavior, native indicator efficiency or user approval.

## Boundaries

Series-title metadata receipt: `/tmp/rose-elephant-series-21-title-receipts.json` (updated title verification follows
publication). This delivery has user-visible sidebar presentation and generated localization impact, but no database,
wire, backend, bridge/plugin or analytics impact. 9.c.2b owns lower-layer refresh execution; 9.c.2c owns explicit
refresh presentation and compact control cleanup. No app smoke, GUI/helper/bridge, auth/preferences, registration,
secure storage or device operation ran. Native/live qualification remains required and unexecuted.
