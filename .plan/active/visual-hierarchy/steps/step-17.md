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
