# Step 50 — Scheduled auto-resume on session rows

Branch `visual-hierarchy/auto-resume-indicator`.

## What changed

- `sessionScheduledResumeAt` in `module_app_ui` is the one rule: a row is
  scheduled when the view is enabled, its availability is not `unavailable`
  and its status is `resetKnown`. It returns that status's `continueAt`.
- `SessionScheduledResume` draws a clock and the local time in the row's
  `textXs` secondary style. `sessionScheduledResumeDescription` gives the full
  "Resumes at <date and time>" label, formatted by the notice's
  `sessionAutoContinuationLocalTime`.
- The shared `SessionTile` (phone and desktop project pages) and both desktop
  sidebar rows (session and Activity) show it in place of the relative time.
  Awaiting input and running keep their precedence. The sidebar's two rows now
  share one trailing-time builder.
- Two English strings, `sessionListResumes` and
  `sessionListResumesAtDescription`, generated through `flutter gen-l10n`.
- No wire, plugin or `docs/HARNESS_CAPABILITIES.md` change.

## Deviations from the plan

- The visible time is compact: "6:22 PM" today, "Sep 26, 6:22 PM" on a later
  day. The notice's helper always writes the full date and year, which does
  not fit a row. The assistive label and sidebar tooltip use that helper.
- The sidebar row drops the word "Resumes" and shows only the clock and time.
  With the word, the default-width sidebar cut both the title and the time to a
  few characters. The trailing mark is also capped at half the row, so the
  title always keeps the other half.

## Verification

- `module_app_ui` `test/features/session_list`: 53 passed, including new
  `SessionTile` tests for the scheduled row, running and waiting precedence,
  and disabled, unavailable and `null` views.
- `desktop` `desktop_cockpit_shell_test`: 65 passed, including a new test for
  a scheduled sidebar row, an offer that is not enabled, a running row and an
  older bridge's `null` view.
- `app` `test/features/session_list`: 58 passed.
- `dart analyze --fatal-infos` is clean in module_app_ui, desktop and app.
- Fixture-only before and after renders for the desktop sidebar and project
  list and the phone project list, dark and light, are in the PR.
