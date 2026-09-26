# Step 50 — Scheduled auto-resume on session rows

Branch `visual-hierarchy/auto-resume-indicator`.

## What changed

- `sessionScheduledResumeAt` in `module_app_ui` is the one rule: a row is
  scheduled when the view is enabled, its availability is `conditional`
  and its status is `resetKnown`. An unrecognised availability decodes to
  `unknown` and does not count, matching the notice and menu. It returns that status's `continueAt`.
- `SessionScheduledResume` draws a clock and the local time in the row's
  `textXs` secondary style. `sessionScheduledResumeDescription` gives the full
  "Resumes at <date and time>" label.
- The notice's `sessionAutoContinuationLocalTime` became
  `BuildContext.formatDateTime`, which uses the device's date patterns like the
  other list timestamps. Before, it used the app's language and gave US
  12-hour times on en_GB or 24-hour devices. The notice, the chip and the row
  labels all use it. A `SessionTile` caps the resume time at half the row, so
  a 320-point row with large text no longer overflows.
- The shared `SessionTile` (phone and desktop project pages) and both desktop
  sidebar rows (session and Activity) show it in place of the relative time.
  Awaiting input and running keep their precedence. The sidebar's two rows now
  share one trailing-time builder.
- Two English strings, `sessionListResumes` and
  `sessionListResumesAtDescription`, generated through `flutter gen-l10n`.
- No wire, plugin or `docs/HARNESS_CAPABILITIES.md` change.

## Deviations from the plan

- The visible time is compact: "6:22 PM" today, "Sep 26, 6:22 PM" on a later
  day, formatted like a message timestamp (`formatMessageTimestamp`). The full
  date and year do not fit a row, so only the assistive label and sidebar
  tooltip use `formatDateTime`.
- The sidebar row drops the word "Resumes" and shows only the clock and time.
  With the word, the default-width sidebar cut both the title and the time to a
  few characters. The trailing mark is also capped at half the row, so the
  title always keeps the other half.

## Verification

- `module_app_ui` `test/features/session_list`: 53 passed, including new
  `SessionTile` tests for the scheduled row, running and waiting precedence,
  and disabled, unavailable, unknown-availability and `null` views.
- `desktop` `desktop_cockpit_shell_test`: 66 passed, including a new test for
  a scheduled sidebar row, an offer that is not enabled, a running row and an
  older bridge's `null` view, plus one for the Activity row: scheduled while
  unread, and running wins.
- `app` `test/features/session_list`: 58 passed.
- `dart analyze --fatal-infos` is clean in module_app_ui, desktop and app.
- Fixture-only before and after renders for the desktop sidebar and project
  list and the phone project list, dark and light, are in the PR.
