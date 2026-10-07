# Step 10/13: Close the step 8 composer review gaps

This step fixes the #1873 composer findings. Finding 2 was fixed in 9/13
(#1881), and findings 7 and 8 were declined; `step-09.md` gives the reasons.
The fixes measured about 1,100 lines together with 9/13, so they were split.

| # | Finding | Fix |
|---|---|---|
| 1 | Option pills open while sending | `AgentModelButtons.readOnly` |
| 3 | Caret and composing range lost at handoff | `UnsentComposer.selection` |
| 4 | Swap while an image pick or paste is pending | `PromptInput.onBusyChanged` |
| 5 | Voice policy in the view | Gone with 4 |
| 6 | Two send intents | `NewSessionCubit.submit` |

1. `AgentModelButtons.readOnly` wraps each control in `IgnorePointer`. The pills
   keep their size, caret and look, so nothing shifts at Send, and take no
   taps, hover cursor, keyboard focus or assistive actions. The session screen's launch
   composer is read-only too, until the session loads (D9).
2. `UnsentComposer.selection` carries the caret or selection as base and
   extent, so a backward selection keeps its active end. `PromptInput`
   reports it through `onSelectionChanged`. The swap waits while the keyboard
   is still composing a word, so no composing range needs carrying.
3. `PromptInput.onBusyChanged` reports one signal: voice, a pending pick or
   paste, or composition. It stays silent once the composer is unmounted.
   `setVoiceBusy` became `setComposerBusy`, and the cubit holds a success or a
   failure while the composer is busy, so a failed create no longer resets the
   composer under a pending pick.
4. The view's `VoiceInputCubit` listener is removed; the view only forwards the
   boolean.
5. `NewSessionCubit.submit` picks between creating and queueing a follow-up,
   and `canSubmit` replaces the two gates. `createSession` and `queueFollowUp`
   are now private.

## Evidence

- `module_core`: the new-session cubit tests pass. They cover `submit` before
  and while sending, the selection in the handoff, the busy hold of a success,
  and a failure held until a pending pick settles. The session-detail tests
  pass.
- `module_app_ui`: the session-detail widget tests pass. A `PromptInput` test
  covers the handed-over backward selection, the selection report, busy during
  a pending pick and a composing word, and silence after unmount.
- `app`: the new-session, session-detail and agent-pill tests pass. A test
  checks that a read-only agent pill keeps its rect and opens no picker.
- `desktop`: the new-session, home and session-list tests pass.
- `dart analyze --fatal-infos` is clean on `module_core`, `module_app_ui`,
  `app` and `desktop`.
