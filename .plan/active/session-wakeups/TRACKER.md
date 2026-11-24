# Session Wake-ups Tracker

| Step | Title | Status | PR |
| --- | --- | --- | --- |
| 1 | 🌱 Plan session wake-ups and scheduled commands | Merged | #2885 |
| 2 | 🚧 Bridge wake-ups, one-shot and repeating | Merged | #2887 |
| 3 | 🚧 Wake-up commands | Merged | #2889 |
| 4 | ⚙️ Scheduled-task commands | In this PR | |
| 5 | ⚙️ Bridge projection of wake-ups and arming | Merged | #2888 |
| 6 | ⚙️ App: wake-up chip, cancel and armed marks | Merged | #2891 |
| 7 | 🌱 Reconcile regression docs | Not started | |
| 8 | 🌿 Verify and retire | Not started | |

## Notes for later steps

- Step 4 adds `scheduled_tasks.command` in its own migration (33 to 34);
  step 3's 32 to 33 bump covers only `session_wake_ups`. Ready to reuse:
  `ScheduledCommandService.run(outputKey: "task-<id>", ...)`, which reserves
  an output folder under `~/.sesori/command-output/<key>/`, runs the command,
  keeps the output for seven days and returns the result block, and whose
  `dispose()` kills running commands at shutdown. Also the public
  `ScheduledTaskChangeDescriptionBuilder.fence`, `inline` and `quoted`
  helpers. Task output keyed `task-<id>` is not deleted with a session; only
  the seven-day sweep removes it.
- Step 3 renamed `ScheduledTaskAgentChange`'s file to
  `agent_approval_change.dart`, under a sealed `AgentApprovalChange` whose
  `WakeUpCommandChange` family `ScheduledTaskAgentService.settle` hands to
  `SessionWakeUpService.applyCommandApproval`.
- Step 4 (for step 7): a stop now kills the whole process tree (SIGSTOP the
  shell, SIGKILL its `ps` descendants, then the shell; `taskkill /T /F` on
  Windows). A child forked between the `ps` listing and the kill can survive.
  Output files open through `FilesystemApi.openOwnerOnlyFileForWriting`. A
  task command runs before each run's prompt, outside the fire lock, and its
  result reaches the agent as a hidden system-context note; a dedicated-worktree
  new-session run runs it in the project folder. Still open: a command a
  shutdown kills loses that notice (for a task, the run stays started with no
  session), and Windows `cmd.exe` quoting and `taskkill /T` are untested.
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
  - `SessionDetailCubit.cancelWakeUp` calls `SessionRepository.cancelWakeUp` directly.
    The plan's app-side `SessionWakeUpService` was dropped: it had no logic of its own
    (client/AGENTS.md feature checklist).
  - No route-not-found message for cancel: an older bridge sends no wake-ups, so the
    chip never shows against it. A stale tap after a downgrade gets the generic
    "could not cancel" notice.

## Verification results

None yet; step 8 records the matrix from `PLAN.md`.
