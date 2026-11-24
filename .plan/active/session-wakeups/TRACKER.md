# Session Wake-ups Tracker

| Step | Title | Status | PR |
| --- | --- | --- | --- |
| 1 | 🌱 Plan session wake-ups and scheduled commands | Merged | #2885 |
| 2 | 🚧 Bridge wake-ups, one-shot and repeating | Merged | #2887 |
| 3 | 🚧 Wake-up commands | In this PR | |
| 4 | ⚙️ Scheduled-task commands | Not started | |
| 5 | ⚙️ Bridge projection of wake-ups and arming | Merged | #2888 |
| 6 | ⚙️ App: wake-up chip, cancel and armed marks | Not started | |
| 7 | 🌱 Reconcile regression docs | Not started | |
| 8 | 🌿 Verify and retire | Not started | |

## Notes for later steps

- Step 4: migration 32 to 33 already added `scheduled_tasks.command`
  (nullable text), so step 4 needs no schema bump for it. Ready to reuse:
  `ScheduledCommandService.run(outputKey: "task-<id>", ...)`, which runs the
  command, keeps its output under `~/.sesori/command-output/<key>/` for seven
  days and returns the result block; `PromptUploadRepository.reserveFolder`;
  and the public `ScheduledTaskChangeDescriptionBuilder.fence`, `inline` and
  `quoted` helpers. Task output keyed `task-<id>` is not deleted with a
  session; only the seven-day sweep removes it.
- Step 3 renamed `ScheduledTaskAgentChange`'s file to
  `agent_approval_change.dart`, under a sealed `AgentApprovalChange` whose
  `WakeUpCommandChange` family `ScheduledTaskAgentService.settle` hands to
  `SessionWakeUpService.applyCommandApproval`.
- Known gaps from step 3: a timeout kills the shell, not processes it started
  in the background; a shutdown does not wait for a running command, so that
  time is lost; Windows `cmd.exe` quoting is untested.
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

## Verification results

None yet; step 8 records the matrix from `PLAN.md`.
