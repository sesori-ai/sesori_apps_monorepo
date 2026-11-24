# Session Wake-ups Tracker

| Step | Title | Status | PR |
| --- | --- | --- | --- |
| 1 | 🌱 Plan session wake-ups and scheduled commands | Merged | #2885 |
| 2 | 🚧 Bridge wake-ups, one-shot and repeating | In this PR | |
| 3 | 🚧 Wake-up commands | Not started | |
| 4 | ⚙️ Scheduled-task commands | Not started | |
| 5 | ⚙️ Bridge projection of wake-ups and arming | Not started | |
| 6 | ⚙️ App: wake-up chip, cancel and armed marks | Not started | |
| 7 | 🌱 Reconcile regression docs | Not started | |
| 8 | 🌿 Verify and retire | Not started | |

## Notes for later steps

- Step 2 left the command columns out of `session_wake_ups`. Step 3 adds
  `command` and its approval state in a 32 to 33 migration, ideally together
  with step 4's `scheduled_tasks.command`.
- Step 3 (from the Codex review of #2885, now in `PLAN.md` under "Firing and
  delivery"):
  - Before a command runs, commit that it was used: a one-shot deletes its row
    and a repeating one has already advanced. Otherwise a restart after the
    command but before its notice is delivered runs the command again.
  - Before a command runs, check that the session is still active. Today the
    archived or deleted check happens only inside `SessionNoticeService.deliver`,
    after the command. Test an archived command wake-up.
- Step 2's `dropped` outcome keeps a one-shot whose claim never ran, so a
  delivery cut by shutdown or a lane error fires again at the next tick.
  A one-shot dropped after its claim, by a failed send, is gone.

## Verification results

None yet; step 8 records the matrix from `PLAN.md`.
