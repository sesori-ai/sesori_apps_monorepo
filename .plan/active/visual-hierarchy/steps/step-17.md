# Step 17 — Shared activity

Split in two: 17.a moves the projection into `module_core`; 17.b gives the
phone its own session inventory and an Activity group at the top of Projects.

## 17.a What changed

- `DesktopSidebarSessionProjection` moved from `module_desktop_core` to
  `module_core`, beside `recent_sessions_resolvers.dart`, as
  `SessionActivityProjection`, with `SessionActivityGroup` and
  `SessionActivityEntry`. Its tests moved with it. The desktop sidebar and
  Activity popout only change names.
- The projection gains `waitingFirst`: waiting sessions, then running ones,
  in project order, each with its project. The phone passes no deferred
  sessions and no sticky id, and finished unseen sessions stay in their
  lists, as the phone shows today.
- The home's needs-you, running and recent sections come with step 18,
  their first consumer, rather than ahead of it.

## 17.a Verification

- `client/module_core`, `client/module_desktop_core` and `client/desktop`:
  `dart analyze --fatal-infos` is clean.
- `client/module_core` `test/cubits/recent_sessions` passes, including a new
  `waitingFirst` test: waiting across projects first, then running, and a
  finished unseen session left out.
