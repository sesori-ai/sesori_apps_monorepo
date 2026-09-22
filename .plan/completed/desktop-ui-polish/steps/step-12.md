# Step 12 — Archive with Undo and compact alerts

## Scope

- **Cleanup flow (D13).** `SessionListActionDispatcher` takes a required sealed
  `SessionCleanupFlow`. `SessionCleanupSheets` is the phone and keeps today's
  sheets. `SessionCleanupImmediate` is the desktop: it carries the archive
  callback, offers **Archive** and **Archive, keep worktree** as separate
  entries for a session with a worktree, and asks first only for a running
  session. Delete asks in a compact centred alert whose default is Cancel,
  then runs the dispatcher's existing delete operation.
- **Undo window.** `PendingSessionArchiveCubit` in `module_desktop_core`
  depends on `SessionRepository` only. Its state composes a sealed window,
  idle or open with the session and the worktree choice, and the ids whose
  archive is in flight or done. Outcomes, committed, refused or failed, are
  one-shot stream events. A second archive commits the open window first.
  Closing the cubit cancels the timer and sends nothing.
- **Desktop wiring.** The cockpit shell creates the cubit with
  `BlocProvider(create:)` and wraps its child in `DesktopPendingArchiveAlerts`,
  the one place that shows the Archived alert with Undo for the whole window,
  the refusal alert, and the error alert. The refusal alert defaults to
  keeping the worktree; either choice archives at once with no second Undo.
  The router passes `SessionCleanupImmediate` and leaves the archived
  session's page.
- **Hidden sessions.** The sidebar projection, the Activity popout, the
  project page and its chip counts hide the cubit's hidden ids.
  `SessionListContent` takes a required `hiddenSessionIds`, applied only to
  unarchived sessions; the phone passes an empty set. The project page
  refreshes when an archive for its project commits.
- Eight new strings. `fake_async` joins `module_desktop_core`'s dev
  dependencies. No wire, database or analytics change.

## Deviations From The Plan

- The plan gave `immediate` a delete-confirmation callback. The compact delete
  alert lives in the shared dispatcher's part file `session_cleanup_alerts.dart`
  instead, because it needs nothing from the desktop and sits beside the
  delete operation it precedes.
- The running-session confirmation also lives in the dispatcher, which already
  holds the list state that says whether the session is running, rather than
  in the desktop archive callback.

## Automated Evidence

Measured checkpoint: commit `b8fec8514675c35d85dde6cc9e68dcaa6a1549f8` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. The suites last ran on the step's tree before its final rebase, which
brought in only step 11's one-line review fix in `module_core`. This file and
the tracker row were added afterwards as documentation only and were not
re-measured.

```sh
cd client/module_desktop_core
dart test
dart analyze
cd ../module_app_ui
flutter test --no-pub
flutter analyze --no-pub
cd ../app
flutter test --no-pub
flutter analyze --no-pub
cd ../desktop
flutter test --no-pub
flutter analyze --no-pub
```

- `module_desktop_core`: 341 cases pass. Five new cubit cases use `fake_async`
  to prove the window commits when it ends, Undo sends nothing, a second
  archive commits the first and its late refusal leaves the second window
  intact, a failure returns the session, and closing sends nothing.
- `module_app_ui`: 394 cases pass. Three new cases prove the sheets flow still
  opens the archive sheet, the immediate flow archives an idle session without
  asking, and a running session is confirmed first with Cancel archiving
  nothing.
- `desktop`: 275 cases pass. New cases cover the Undo alert, the refusal alert
  and error alert, and a session leaving the project page and its counts at
  once and returning on Undo.
- `app`: 774 cases pass, which covers the unchanged phone sheets. All four
  analyzers report no issues.
- From `client/module_app_ui`, `flutter gen-l10n` exited 0. Nothing generated
  was edited by hand.
- `architecture-implementation-review` ran once through a sub-agent over this
  step's commits and approved them with no findings.

## Size

**1,108 changed lines (1,067 additions and 41 deletions) across 39 files** at
the measured checkpoint; 76 are generated, 422 are tests and 21 the regression
documents. Reproduce from the root:

```sh
git diff --numstat b79fbe7dbd86c97cd5191d4f54f662373706b038 b8fec8514675c35d85dde6cc9e68dcaa6a1549f8
```

The step target was 900; the repository soft cap is 1,500. The overage is the
test coverage for the timer and both cleanup flows; no clean split exists,
because the cubit, the flow and the desktop wiring only work together. This
file and the tracker row come on top; final self-inclusive accounting belongs
in the PR body.

## Regression Documents

`session-archiving-and-deletion.md` gains the desktop Undo flow, the refusal
alert and the compact delete alert. `popup-alerts.md` records an alert with an
action and its own duration. `desktop-cockpit-shell.md` records where a
session being archived is hidden.
