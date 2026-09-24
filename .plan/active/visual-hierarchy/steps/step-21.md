# Step 21 — Project rows

## What changed

- `module_core` gains `projectPathLabels` (`utils/project_path_labels.dart`):
  each project's path cut to its last two folders, growing one folder at a
  time while a same-named project still ends the same way. A path that grows
  whole keeps its root ("/work/app", "C:/app"); a cut one starts with "…/".
  The phone's project list computes the labels once over every project and
  hands each row its own. `projectShortPath`, which dropped the leading slash,
  is gone.
- The row's status reads "2 running" from `ProjectListLoaded.runningByProjectId`
  (step 12's count) instead of `activityById`, which also counted sessions
  only waiting for input. Unseen activity is a resting sparkle alone; screen
  readers still hear New activity.
- `formatTimestamp` names the month past 30 days: "15 Aug", with the year only
  when it differs.
- Adding a project opens it. `OpenProjectOutcome` is now sealed, and
  `OpenProjectAdded` carries the new `ProjectSummary`; `showAddProjectDialog`
  takes `onProjectAdded`, which the phone's Projects screen, the desktop
  cockpit and the desktop's empty home wire to their open-project route.
- Left for a follow-up PR: `activityById` has no reader left and goes with
  its producer.

## Verification

- `client/module_core` `test/utils/project_path_labels_test.dart` and
  `test/cubits/project_list/project_list_cubit_test.dart` pass.
- `client/module_app_ui` `test/features/project_list` (the add dialog opens
  the added project) and `test/extensions/build_context_x_test.dart` pass.
- `client/app` `test/features/project_list` passes, with the resting-sparkle,
  running-count and leading-slash expectations.
- `client/desktop` `test/features/home`, `test/core/widgets/desktop_cockpit_shell_test.dart`
  and `test/core/routing` pass.
- `dart analyze --fatal-infos` clean in `client/module_core`,
  `client/module_app_ui`, `client/app` and `client/desktop`.
