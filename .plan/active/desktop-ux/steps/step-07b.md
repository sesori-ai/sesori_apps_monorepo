# Step 7.b — Root-overlay activity and notification focus

Ordinal 9/15; branch `desktop-ux/overlay-navigation`.

## Boundary and delivery

Extracted from accepted #1501 review findings instead of expanding its 1,725-line
diff. Root popups already exist before the Settings modal, so this prerequisite
is independently useful. #1501 is temporarily closed with its published branch
and review history preserved; merge main forward and reopen it as step 7.c.
Its large-text rail and evidence/name corrections remain there. No force push.

An immutable containing-route scope feeds the existing session activity owner;
its single combined gate controls both viewed-session and activity analytics.
The shell supplies Flutter's root-route currentness without replacing the nested
page. Both existing route adapters implement `dismissPopups` on their existing
readiness/serialization queue. Desktop attention requests dismissal after account
validation and before its same-session early return. Pages/Back stacks survive;
another-session open still uses the existing typed stack. Failures retain local
error/stack logs and later queued navigation can continue.

No persistent fields, mutable business state, subscriptions, polling, alternate
owners, wire changes, database changes or new analytics event. Mobile's internal
adapter contract updates in lockstep; its notification policy is unchanged.

## Revision-scoped verification

Base: `cd4c1412359ef8962cb019d97dc7fed73835e1c8`.

| Revision / tree | Evidence retained |
|---|---|
| `d9a9e82e3d43acc54b3be3908dcecc390c58e5fb` / `ad6fa7879bffddae45e516bcb37b253ec6240bfe` | All 97 focused cases passed. Retain shared UI 4, core 8 and desktop-core 30 plus those three analyzers. Desktop/mobile analyzers reported broad popup type-annotation infos, fixed next. |
| `ad0c3852c80449c3cf3e64a09a192afecaf0836d` / `a9b31fcf70c9f49ae103c1e734d9c7de2a6ea26e` | Generic popup predicates follow the existing Escape-policy pattern. Desktop 17 and mobile 38 cases rerun; both analyzers clean. Other packages unchanged and not rerun. |

**97 distinct cases**, not 152 accumulated executions. Commands use pinned
Flutter 3.47.4 / bundled Dart, with cwd below `client/`:

| Cwd | Command |
|---|---|
| `desktop` | `flutter test --no-pub --reporter json test/core/platform/desktop_route_dispatcher_test.dart test/core/routing/desktop_router_test.dart` |
| `module_app_ui` | `flutter test --no-pub --reporter json test/features/session_detail/session_detail_activity_owner_test.dart` |
| `app` | `flutter test --no-pub --reporter json test/core/routing/app_route_test.dart` |
| `module_core` | `dart test --reporter json test/routing/notification_open_dispatcher_test.dart` |
| `module_desktop_core` | `dart test --reporter json test/services/desktop_attention_service_test.dart` |

Each of those five packages: `dart analyze --fatal-infos`. Logs and parsed case
summaries: `/tmp/rose-elephant-overlay-*-{tests,analyze}*.log` and
`/tmp/rose-elephant-overlay-{test,analyze,final}-summary.json`.
Tests use real root dialogs/nested navigators and the registered shell boundary,
but inert bodies and fake services. They prove same-session element/Back retention,
different-session replacement, no-popup safety, auth rejection, readiness and
failure ordering. No production-DI smoke, real app/helper/bridge, native registration,
authentication or preference mutation was run. Native/live/L3 gaps remain unchanged.

## Review and size

Architecture plan review approved with no required changes, child
`9dc6302a-2c30-43c9-a9cd-1341df7026ea`, workflow
`2fccec63-7cfa-46c1-ab64-be8c56a0e585`. Its complete report is retained as
`overlay-navigation-plan-review.md` in that workflow's output directory.
Frozen implementation review **approved**, with no findings, for the full range
`cd4c1412359ef8962cb019d97dc7fed73835e1c8..ad0c3852c80449c3cf3e64a09a192afecaf0836d`:
child `3f17b834-be19-4911-a175-34f78d9756b2`, A1–A13 and B-Client. It excludes
later documentation and does not establish general correctness or native QA.
The bound output held only an acknowledgement. The complete original report was
recovered from that child's session write at line 115, inspected and hash-verified;
no session/acknowledgement was edited. Retained copy:
`/tmp/rose-elephant-overlay-architecture.md`; provenance beside it as
`rose-elephant-overlay-architecture-provenance.json`. SHA256:
`fc933b6b1ded4affa445759e34f00c4bb9fa23dfc17d0879ab2b12100426b2b9`.

Count all added/deleted lines, including documentation and tests, using
`git diff --numstat cd4c1412359ef8962cb019d97dc7fed73835e1c8 <snapshot>`.
The prerequisite target is 700 lines; immutable publication totals belong in the
PR body. No generated files change.
