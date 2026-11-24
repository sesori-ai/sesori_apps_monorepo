# Session Wake-ups Tracker

| Step | Title | Status | PR |
| --- | --- | --- | --- |
| 1 | 🌱 Plan session wake-ups and scheduled commands | Merged | #2885 |
| 2 | 🚧 Bridge wake-ups, one-shot and repeating | Merged | #2887 |
| 3 | 🚧 Wake-up commands | In this PR | |
| 4 | ⚙️ Scheduled-task commands | Not started | |
| 5 | ⚙️ Bridge projection of wake-ups and arming | Not started | |
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

## Verification results

None yet; step 8 records the matrix from `PLAN.md`.
