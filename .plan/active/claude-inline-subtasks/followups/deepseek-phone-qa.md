# DeepSeek phone QA handoff

Date: 2026-09-08. Scope: the user's phone-only verification before Codex;
macOS desktop explicitly deferred. These results do not retire the overall
harness plan or claim the unexecuted desktop matrix.

## Target

- Scoped-stop consumer #1370 merged at `c88d4ade82`.
- Live QA found a shared IOSink crash; #1379 fixed it and merged at
  `c436d3d4ae`. Final input checks ran on that merged source.
- Real Flutter iOS simulator, auth/relay, isolated bridge slot, and published
  DeepSeek adapter 0.1.4. Simulator and bridge account matched; YOLO disabled
  through the phone and verified against local bridge settings.
- `test-oai` was tried first and produced real permission requests. Its invalid
  sandbox arguments prevented reliable descendant setup, so the authorized
  Flash fallback was used for nested work and question checks.

## Observed coverage

| Scenario | Result |
|---|---|
| Pending permission | With the real sheet open, atomic Stop through the bridge API returned a handled ACK; permission rejection and idle followed, sheet disappeared, and the probe file was absent. This was not a phone Stop-button test. |
| Phone confirmation/Cancel | Main plus two nested sub-agents counted; Cancel left all three controlled background jobs alive. |
| Phone main-only keep | Next confirmation reported main done while descendants remained active. |
| Independent resident scope | Resumed an existing child independently, started its grandchild, then stopped only the child's own main turn. Confirmation verified main not running with a running descendant. Ancestor Stop from the phone settled root, child, and grandchild idle without exiting bridge or native runtime. |
| Subsequent prompt | After the corrected Stop, a new prompt produced the expected assistant marker and returned idle without a session error. |
| Pending question | Open real question sheet disappeared after API Stop; captured question rejection preceded idle. |
| Later input during Stop | Submitted a new prompt after the Stop request was written but before its response headers arrived (12 ms before response observation). Both requests returned HTTP 200 and Stop acknowledged complete handling. The new, distinct question remained visible and usable on the phone. |
| Answer after Stop | Selected and submitted an answer to that later question on the phone. Pending questions became empty; assistant acknowledged the selected answer; Stop control disappeared. |

The first ordinary nested-stop attempt used jobs close to natural expiry and
was not counted as definitive process-cancellation evidence. The independent
scope rerun used longer jobs and verified bridge/native process survival plus
actual session settlement, not merely vanished process IDs.

## Boundaries and follow-ups

- Root-owned background shell jobs can remain after agent-turn cancellation.
  This is separate from stopping descendant agents; no claim that Stop kills
  every background OS process. Owned QA jobs were cleaned up explicitly.
- The permission sheet showed a generic tool label and opaque call ID instead
  of useful command context. Permission cancellation passed; complete permission
  presentation did not. Keep that UX issue as a separate follow-up.
- Timing evidence proves one real later-input interleaving, not every possible
  network schedule. Package tests additionally cover frame ordering, reused
  question IDs, held responses, and partial failure.
- Desktop remains untested by explicit user choice. All pre-existing desktop,
  standalone bridge, and another session's QA slot were preserved. Owned QA
  processes stopped; simulator shut down and retained.

Private screenshots, HTTP timing records, and logs remain in local QA artifact
directories. Raw logs/transcripts must be reviewed and redacted before sharing.
File-watch/stream-trigger timing probes were inconclusive; the successful HTTP
write/response-timed probe and phone observations above are the evidence.

## Handoff

The requested phone stop/input checks are complete. Continue with Codex typed
prompt parsing (step 3/6), then inline subtask tiles (step 4/6); its metadata
and child-session foundations already merged in #1263, #1273, and #1280. Do not mark remaining harness coverage or the
whole plan complete on the strength of this phone-only handoff.
