# Step 29 — Failed archive and Undo

## What changed

- `PendingArchiveAlerts` no longer shows an archive failure while an Undo
  window is open. It holds the failure in one flag and shows it when the
  window closes: when the window ends, or when Undo is pressed. The alert says
  "Failed to archive session" and does not name the session, so one flag is
  enough for several held failures.
- The flow that reaches this: archive A, then archive B inside A's window.
  That commits A, and B's Undo alert shows. Before, A's failure arrived during
  B's window and replaced B's Undo alert through the single-slot presenter.
  B then committed when its window ended, and the user had no way to undo it.
- The listener now reacts to every window change instead of only to a new
  open window. It offers Undo on an open window and shows a held failure on
  idle. Archiving a third session inside B's window passes through idle on
  the way to the next window. The idle branch reads the cubit's current window
  and keeps the failure held while a window is open again.
- The Undo button dismisses its alert before it calls `undo()`. The order is
  easier to read. The dismissal also targets the Undo alert whatever the
  listener's timing, never the failure that `undo()` releases.
- Both apps mount this widget, so the change covers phone and desktop.

## Deviations

- The failure waits for the Undo window, not for the alert to close. Closing
  the alert early with its X leaves the window open, so a held failure can wait
  up to five seconds after that. The plan's "when the toast closes" meant the
  Undo offer ending, and the window is the state the cubit owns.
- A refused cleanup is unchanged. Its alert is a dialog, not the popup slot,
  so it never replaced an Undo alert.

## Verification

- `module_app_ui` `test/widgets/pending_archive_alerts_test.dart` passes
  (7 tests). The three new tests fail A while B's Undo shows. They check the
  failure after B's window ends, after Undo, and after a third archive's
  window. Each fails without its part of the change.
- The desktop `desktop_cockpit_shell_test` passes (64 tests).
- `dart analyze --fatal-infos` is clean in module_app_ui.
- No architecture review: the change is method logic inside one widget.
- `docs/regression/session-archiving-and-deletion.md` records the held
  failure, a failure signal, and the narrowed known limitation.
