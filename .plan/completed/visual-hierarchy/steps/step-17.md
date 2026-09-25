# Step 17 — Shared activity

Split in two: 17.a moves the projection into `module_core`; 17.b gives the
phone its own session inventory and an Activity group at the top of Projects.

## 17.a What changed

- `DesktopSidebarSessionProjection` moved from `module_desktop_core` to
  `module_core`, beside `recent_sessions_resolvers.dart`, as
  `SessionActivityProjection`, with `SessionActivityGroup` and
  `SessionActivityEntry`. Its tests moved with it. The desktop sidebar and
  Activity popout only change names.
- New outputs arrive with their first consumer: the phone's waiting-first
  order with 17.b, and the home's needs-you, running and recent sections with
  step 18.

## 17.a Verification

- `client/module_core`, `client/module_desktop_core` and `client/desktop`:
  `dart analyze --fatal-infos` is clean.
- `client/module_core` `test/cubits/recent_sessions` passes; the moved tests
  are unchanged apart from names.
- Architecture implementation review: the first round rejected an output
  added ahead of its consumer; it moved to 17.b.

## 17.b What changed

- `SessionActivityProjection.waitingFirst` orders the phone's Activity:
  waiting sessions, then running ones, in project order.
- The phone Projects screen owns a `RecentSessionInventoryService` and a
  `RecentSessionsCubit`, as the desktop shell does, and `ProjectListView`
  renders an Activity group of `ActivityTile` rows above a Projects heading.
  A row opens its session. Nothing shows while no session is in motion.
- `projectListActivity` string added.

## 17.b Verification

- `client/app` `test/features/project_list` and `test/core/routing` pass,
  including the new `project_list_activity_test.dart` (empty, order, open).
- `client/module_core` `test/cubits/recent_sessions` passes with the
  waiting-first test.
- `dart analyze --fatal-infos` clean in `client/app`, `client/module_app_ui`
  and `client/module_core`.
- Light and dark phone renders checked.
- Architecture implementation review: approved in the first round.
