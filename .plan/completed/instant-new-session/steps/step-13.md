# Step 13/14: Close the launching-row review deferrals

The step 11 deferrals (`step-11.md`), picked up before coverage.

| Finding | Outcome |
|---|---|
| Codex `PRRT_kwDORscidM6p7z1Q` (and #1896 `PRRT_kwDORscidM6qAPJB`): a newer launch resolving above a still-waiting older one | Fixed in `resolveHeldLaunchSessions`. A newer launch whose session is in place but for older launches still waiting, or named with their sessions still on their way (#1902 cubic `qBds8`), keeps its row until those land or fail, then takes its own row's place, rather than being placed as an ordinary change by the next sessions update. The create timeout bounds the wait only while an older create is still pending; an older session that is named but not yet in the list is settled by the next list update. When an older row goes as an ordinary change, the resolver passes again, so a newer row already in place takes it at once (#1902 Codex `qBtO0`). Resolver test fails without the fix |
| Codex `PRRT_kwDORscidM6p6jgb`: launch-row reconciliation in `SessionListFilteredContent` widget state | Moved into `SessionListLaunchRowsCubit` (module_core), which subscribes to `SessionLaunchService` and is given the active list's sessions (null while loading or Archived) by the widget through a `BlocListener`, the pushed-input pattern of `ProjectLaunchRowsCubit`, so it depends on no cubit or cubit state. The architecture implementation review ran once and its one finding (do not take `SessionListState`) was applied. The widget's launch and list subscriptions and `_launchRows` are gone; the list now reads `SessionLaunchService` from context instead of `SessionLaunchCubit` |
| Codex `PRRT_kwDORscidM6p7z1f`, cubic `p6XdO`/`p6Xde`: a launch failure alert replaces an open archive Undo alert | Kept as a known limitation. The step 11 rationale was wrong: the archive is not restorable, it commits when the Undo window ends, as the archive document already says. That document's Known Limitations now names a background creation failure as one such alert. No test pins it; it is a limitation, not a guarantee |

The #1896 wave-4 behaviours (a session first waiting on the user gives way to its
Needs you row at once; unread and set-aside changes re-resolve the rows) are now
in `projects-and-sessions.md` and `desktop-cockpit-shell.md`.

Evidence: `module_core` launch resolver and `SessionListLaunchRowsCubit` tests;
`module_app_ui` session-list and launch-row widget tests; `app` core,
session-list and project-list tests; `desktop` feature and core tests (the
desktop list tests caught the cubit reading the latest launch value instead of
each update); `dart analyze --fatal-infos` clean on `module_core`,
`module_app_ui`, `app` and `desktop`.
