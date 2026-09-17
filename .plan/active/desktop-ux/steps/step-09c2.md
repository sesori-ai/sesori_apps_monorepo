# Step 9.c.2a — Sidebar activity and refresh owners

Delivery 16/20; branch `desktop-ux/sidebar-activity-foundation`.
Base: #1526 squash `a6b32359f028151649cc4553297bc60ace1c0383`, tree
`4d52ad1899e1de87690bc3fb4593f66a03eb82b0`.

## Scope

- Add aggregate explicit refresh to the existing recent-session owner while retaining useful loaded data.
- Derive cross-project activity and ordinary rows in a pure Layer-4 desktop projection.
- Coordinate project-then-session refresh in a non-Cubit Layer-4 orchestrator.
- Keep the refresh Cubit dependent only on a typed operation boundary and map its result to presentation state.
- Add no Flutter UI, cache, backend request shape, persistence, timer, subscription, project-view claim or analytics event.

## Architecture evidence

The scoped plan review `7a64c300-5abd-46c6-8656-b75f8acb882d` rejected foundation placement and
widget-owned orchestration. Its required corrections are reflected in the revised ephemeral plan
(`/tmp/rose-elephant-sidebar-activity-plan.md`, SHA-256
`401e7af406edb012b71c405a20f5ead633a544c52dca447c172aa1fa5ddbb778`).

Implementation checkpoint A: `9366c1078240a0a21bf9f0559dd7417fadac1102`. Review
`e7bfea4e-0ebc-4ce0-88a8-489447c25eda` rejected its direct Cubit dependencies (report SHA-256
`df0b203935525475ac6b60a10e298b850a910af4416f647f97161eeaa7b9e79b`). Follow-up checkpoint B:
`a30e454cb10b0738f10af8159a674db2fa05c75f`, tree
`735cc6c782713f05ba8aeb6ad6513c725d350744`. Final review
`29fa5fda-f21c-4cca-90d6-0eebb6977f7a` approved the exact base..B range and confirmed the violation
resolved (report SHA-256 `84823cda7172172b5ffd549ffcc04fc1ce43712131ee69a16f6d563d367734d1`).

## Verification

The all-path delivery is 688 changed lines (595 additions, 93 deletions); pinned Dart/Flutter 3.47.4:

- `client/module_core`: 20 recent-session cases pass; `dart analyze --fatal-infos` is clean.
- `client/module_desktop_core`: 10 projection/refresh Cubit/orchestrator cases pass;
  `dart analyze --fatal-infos` is clean.
- Logs: `/tmp/rose-elephant-sidebar-activity-foundation-core.log` and
  `/tmp/rose-elephant-sidebar-activity-foundation-review-fix-final.log`.
- No generator was needed; all changed Dart sources were formatted.

## Boundaries

This prerequisite has no user-visible, database, wire, bridge/plugin or generated-file impact.
The local successor owns Flutter composition, localization, regression docs and synthetic renders.
No production DI, app smoke, GUI/helper/bridge, auth/preferences, registration, secure storage or device operation ran.
Native/live qualification remains required and unexecuted.
