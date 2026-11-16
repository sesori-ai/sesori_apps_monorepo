# Interrupted And Stopped Turns Tracker

| Step | Status | PR |
| --- | --- | --- |
| 1 Raise the plan | Merged | #2635 |
| 2 Stopped line: wire kind, client line, Pi and OpenCode | Merged | #2646 |
| 3 Stopped on ACP harnesses and omp | Merged | #2668 |
| 4 Stopped on Claude Code and Codex | Merged | #2667 |
| 5 Bridge records interrupted turns | Merged | #2651 |
| 6 Interrupted line, Continue and list label | Merged | #2673 |
| 7 Reconcile regression docs and harness rows | In PR | |
| 8 Verify and retire | Not started | |

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
