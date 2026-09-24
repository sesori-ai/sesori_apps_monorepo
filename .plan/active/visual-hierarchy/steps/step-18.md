# Step 18 — Desktop home and empty project

Split in two: 18.a turns the home into a composer with the activity sections;
18.b shows the composer in place for a project with no sessions.

## 18.a What changed

- `SessionActivityProjection` gains `needsYou`, `running` and `recent`;
  `waitingFirst` is now `needsYou` then `running`. Recent holds the five
  newest sessions across projects that are neither running nor waiting.
- `NewSessionPageChrome` gains a `footer` that follows the composer.
- With projects, `DesktopHomePane` shows `DesktopHomeStart`: the shared
  `NewSessionView` for a picked project, held in widget state (first listed
  until the user picks another), with a `NewSessionCubit` keyed by that
  project. The footer lists Needs you, Running and Recent as `ActivityTile`
  rows; a row opens its session, and a created session opens in the picked
  project. The "Pick a session from the sidebar" empty state is removed.
- `ActivityTile` is exported and shows a resting sparkle for unread settled
  sessions.

## 18.a Verification

- `client/desktop` `test/core` and `test/features` pass, including new home
  tests: section order and opening, a new pick re-creating the cubit, and a
  created session opening in the picked project.
- `client/module_core` `test/cubits/recent_sessions` passes with the Recent
  test; `client/app` `test/features/project_list` and `test/features/new_session` pass.
- `dart analyze --fatal-infos` clean in `client/desktop`, `client/module_app_ui`
  and `client/module_core`.
- Light home render checked.
- Architecture implementation review: approved in the first round.

## 18.b What changed

- The desktop project page shows the shared `NewSessionView` for its
  project in place of the empty timeline, under the same toolbar, while the
  active list is empty. The header names the project without a picker; a
  created session opens through the page's session callback.
- `DesktopSessionListScreen` resolves the cubit factory and wraps a
  `@visibleForTesting` `DesktopSessionListView`, as the new-session page does.

## 18.b Verification

- `client/desktop` `test/core` and `test/features` pass, including new
  project-page tests: the composer replaces the empty timeline (not under
  Archived), and a created session opens.
- `dart analyze --fatal-infos` clean in `client/desktop`.
