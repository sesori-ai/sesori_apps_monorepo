# Session Wake-ups Tracker

| Step | Title | Status | PR |
| --- | --- | --- | --- |
| 1 | 🌱 Plan session wake-ups and scheduled commands | Merged | #2885 |
| 2 | 🚧 Bridge wake-ups, one-shot and repeating | Merged | #2887 |
| 3 | 🚧 Wake-up commands | Not started | |
| 4 | ⚙️ Scheduled-task commands | Not started | |
| 5 | ⚙️ Bridge projection of wake-ups and arming | Merged | #2888 |
| 6 | ⚙️ App: wake-up chip, cancel and armed marks | In this PR | |
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

- Step 5 (for step 6):
  - `Session.wakeUps` (soonest first) and `Session.arming` (`unreported`, `notArmed`,
    `armed(name, nextAt)`) are on the wire. `unreported` is also the fallback for an
    unknown kind, so it is the legacy-mark case. The plan's `origin` on `armed` was
    dropped: the owner picked one shared mark, so nothing reads it.
  - An archived session is never armed, though its wake-ups are still listed.
  - `runsCommand` is always false until step 3 sets it from the stored command, in
    `SessionViewService.enrichMany`.
  - `POST /session/wake-up/cancel` takes `CancelSessionWakeUpRequest(sessionId,
    wakeUpId)` and answers with the enriched `Session`, also for an id already gone.
    An older bridge answers route-not-found, but it sends no wake-ups to cancel.
  - The event is `SessionMutationDispatcher.armingUpdated(sessionId)` (named for
    both wake-ups and tasks, not `wakeUpsUpdated`), which republishes the session as
    `session.updated`.

- Step 6 (for step 7):
  - The row mark is `SessionScheduledMarkCalculator` in `module_core` (`armed`, `fromTask`,
    `legacyTask`, `none`). The plan's `resumes(at)` variant was left out: the quota
    auto-continuation resume keeps its own place in the time column, so the two never
    compete for one slot.
  - The composer chip reads `session.wakeUps` directly, like the auto-continuation
    chip reads `session.autoContinuation`; the session detail state carries no mark.
  - Cancel needs no in-flight state: the menu closes on tap and the updated session
    removes the row. No analytics event: cancel volume answers no product question.
  - No route-not-found message for cancel: an older bridge sends no wake-ups, so the
    chip never shows against it. A stale tap after a downgrade gets the generic
    "could not cancel" notice.

## Verification results

None yet; step 8 records the matrix from `PLAN.md`.
