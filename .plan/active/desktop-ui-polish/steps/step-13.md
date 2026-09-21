# Step 13 — Centre the new session page and share its header

## Scope

- **Shared header (D14, D20).** `NewSessionHeader` in `module_app_ui` shows the
  heading "What should we work on?" and a project selector. The selector opens
  only when another project exists. `NewSessionView` builds it on both shells
  and takes the project name, the offered projects and a selection callback.
  Its `subtitle` input is gone, because the selector names the project.
- **Desktop page.** `NewSessionPageChrome` carries the desktop toolbar and the
  column width. Under it the header, the harness chooser, the input, Dedicated
  workspace and Refresh options form one centred column that scrolls as a
  whole. The route keys the screen by project, so choosing another project
  builds a fresh `NewSessionCubit`. The desktop passes the cockpit's project
  list.
- **Phone page.** The header sits above the options under the glass bar, and
  hides while the keyboard is open so the options stay in view while typing.
  The composer stays anchored above the keyboard. The phone route holds no
  project inventory, so `NewSessionProjectsCubit` in `module_core` lists the
  projects once through `ProjectListService`; a failure is logged and the page
  names only the current project. Choosing a project replaces the route.
- `projectDisplayName` in `module_app_ui` replaces the project tile's and the
  desktop sidebar's separate name fallbacks. One new string. No wire, database
  or analytics change.

## Deviations From The Plan

- The step was first built with the heading and selector inside the desktop
  package. The D20 amendment of 2026-09-21 moved them into the shared view
  before publication, and added the phone adoption to this step.
- Two phone layout tests used a 400 pt tall surface that left no room for the
  header; they now use 560 pt. Their assertions are unchanged.

## Automated Evidence

Measured checkpoint: commit `a13bd10141c4aa2070b79590e72faa285a7b6631` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. This file and the tracker row were added afterwards as documentation
only and were not re-measured.

```sh
cd client/module_core
flutter test --no-pub test/cubits/new_session/new_session_projects_cubit_test.dart
dart analyze --fatal-infos
cd ../module_app_ui
flutter test --no-pub
dart analyze --fatal-infos
cd ../app
flutter test --no-pub
dart analyze --fatal-infos
cd ../desktop
flutter test --no-pub
dart analyze --fatal-infos
```

- `module_core`: the new cubit case proves the listed projects are offered and
  a failed listing leaves the list empty.
- `module_app_ui`: 394 cases pass.
- `app`: 775 cases pass. A new case proves the phone shows the heading and that
  choosing another project replaces the route with that project's page.
- `desktop`: 276 cases pass. A new case proves the toolbar sits above a centred
  width-capped column and that choosing a project reports it; the route key
  per project is asserted.
- All four analyzers report no issues. From `client/module_app_ui`,
  `flutter gen-l10n` exited 0. Nothing generated was edited by hand.
- `architecture-implementation-review` approved the first, desktop-only shape
  of this step with no findings. The review of the shared shape is recorded in
  the PR body.

## Size

**590 changed lines (497 additions and 93 deletions) across 18 files** at the
measured checkpoint; 9 are generated, 145 are tests and 13 the regression
documents. Reproduce from the root:

```sh
git diff --numstat b131508e175e98abbf6151e18851b14b3b74832b a13bd10141c4aa2070b79590e72faa285a7b6631
```

The step target was 600; the repository soft cap is 1,500. This file and the
tracker row come on top.

## Regression Documents

`session-creation-and-options.md` records the shared heading and project
selector on both shells, and the phone's keyboard behaviour.
`desktop-cockpit-shell.md` records the desktop toolbar and centred column.
