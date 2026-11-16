# Interrupted And Stopped Turns Tracker

| Step | Status | PR |
| --- | --- | --- |
| 1 Raise the plan | Merged | #2635 |
| 2 Stopped line: wire kind, client line, Pi and OpenCode | Merged | #2646 |
| 3 Stopped on ACP harnesses and omp | Merged | #2668 |
| 4 Stopped on Claude Code and Codex | Merged | #2667 |
| 5 Bridge records interrupted turns | Merged | #2651 |
| 6 Interrupted line, Continue and list label | Merged | #2673 |
| 7 Reconcile regression docs and harness rows | Merged | #2696 |
| 8 Verify and retire | Merged | this PR |

Dependencies: 2←1; 3←2; 4←2; 5←1; 6←2,5; 7←3,4,6; 8←7.

Follow-ups outside the numbered steps, both merged:

- #2675: a stopped turn's live-only rows (Codex's streamed reply, the live Stopped row) stay across re-imports while
  the replay holds the turn's prompt, so Stopped persists after a reload on the ACP harnesses and OMP too.
- #2690: the bridge's prompt index splits turns at a bridge stop, as the transcript does.

## Product questions

All answered (round 1, 2026-11-15).

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |
| Stop mid-reply: grey Stopped, fading in, no jump (omp, Claude Code, Codex, OpenCode, Hermes) | Pass, with the debug-build stall below | 2026-11-15 |
| Stop mid-reply (Pi) | Pass on a re-run: stopped 0.4 s into the reply, the 300 streamed characters stay above the Stopped line live, in the store and in Pi 1.5.2's own record. The first run's Fail was a finder bug: it matched the prompt's own "Once upon a time", so it stopped 2.5 s in, before Pi had any response, and Pi correctly recorded an empty aborted reply | 2026-11-16 |
| Stopped after reload: app relaunch and three bridge restarts (all six) | Pass; Pi's re-run keeps the story text and one Stopped line after a bridge restart | 2026-11-16 |
| `kill -9` mid-turn, restart (omp, Claude Code): Interrupted line, label, Continue sends "Continue where you left off.", opening clears the label | Pass | 2026-11-16 |
| SIGTERM mid-turn, restart (omp, Claude Code): Interrupted, no live Stopped | Pass | 2026-11-16 |
| OpenCode 2.2.6 shared service still busy after `kill -9`: no Interrupted | Pass: the running row was adopted and no interruption was recorded, then or once the turn finished | 2026-11-16 |

Run on main 358ff32458 with the headless iOS simulator for slot 3 and live harnesses through the local test proxy;
the Pi re-run used main 047ef3a1f1 on slot 2. Pi 1.5.2 records an empty aborted reply only for a stop before its
response starts; once text streams, its aborted record keeps it.
The stopped row's arrival causes a 120-230 ms frame stall in debug builds, the same heavy turn-end rebuild #2646 saw,
which hides the fade on most harnesses (it shows mid-frame on OpenCode and Hermes). Release frame timing cannot be
measured on the simulator, so only the steady-frame widget tests cover it.

OMP's worker broker and tool subprocesses survive a SIGTERM (and all harness children survive a kill -9); found during
verification, handled outside this series.

## Review record

- 2026-11-15 architecture plan review: rejected with nine specific findings, all applied directly without re-review,
  as the plan-maker rules allow: a `RunningTurnListener` with a signal-phase shutdown fence instead of writes in
  `SessionEventService`; one `SessionInterruptionUpdated` mutation for resolution, view and send, with a stored
  acknowledgement instead of a clock comparison; the OpenCode 2 finished-while-down case accepted as a risk; a DAO and
  repository for both tables; named resolver collaborators, a per-plugin status read and every-readiness semantics;
  projection in `SessionViewService.enrichMany`; re-anchoring inside the history replacement; a plugin-interface
  `PluginErrorKind`, corrected live/replay pairing and reload tests; transcript decisions in a `module_core`
  calculator and `continueInterruptedTurn()`. Step 2 also gets an implementation review.

## Decisions log

- 2026-11-15: Q1 A (Interrupted line, Continue, list label; no auto-continue) and Q3 A (grey Stopped line on every
  harness, persistence where the harness records the stop) applied.
- #2675: Stopped also persists after a reload where the harness records no stop, through the bridge's chat history.
