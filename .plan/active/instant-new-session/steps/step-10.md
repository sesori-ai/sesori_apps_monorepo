# Step 10/13: Close the step 8 composer review gaps

This step fixes the #1873 composer findings. Finding 2 was fixed in 9/13
(#1881), and findings 7 and 8 were declined; `step-09.md` gives the reasons.

| # | Finding | Fix |
|---|---|---|
| 1 | Option pills open while sending | `AgentModelButtons.readOnly` keeps the pills in place, without a caret, and opens nothing. The session screen's launch composer is read-only too, until the session loads (D9) |
| 3 | Caret and composing range lost at handoff | `UnsentComposer.selection` carries the caret or selection, reported by `PromptInput.onSelectionChanged`. The swap waits while the keyboard is still composing a word, so no composing range needs carrying |
| 4 | Swap while an image pick or paste is pending | `PromptInput.onBusyChanged` reports one signal: voice, a pending pick or paste, or composition. `setVoiceBusy` became `setComposerBusy` |
| 5 | Voice policy in the view | Gone with 4. The view's `VoiceInputCubit` listener is removed, and the view only forwards the boolean |
| 6 | Two send intents | `NewSessionCubit.submit` picks between creating and queueing a follow-up, and `canSubmit` replaces the two gates. `createSession` and `queueFollowUp` are now private |

## Evidence

- `module_core`: the new-session cubit tests pass. They cover `submit` before
  and while sending, the selection in the handoff, and the busy hold. The
  session-detail tests pass.
- `module_app_ui`: the session-detail widget tests pass. A new `PromptInput`
  test covers the handed-over caret, the selection report, and busy during a
  pending pick and a composing word.
- `app`: the new-session, session-detail and agent-pill tests pass. A new test
  checks that a read-only agent pill opens no picker.
- `desktop`: the new-session, home and session-list tests pass.
- `dart analyze --fatal-infos` is clean on `module_core`, `module_app_ui`,
  `app` and `desktop`.
