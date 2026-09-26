# Transcript Turn Navigation

## Capability

A session transcript reads as turns: a prompt, the agent's steps and its
answer. A reader folds every turn to one line to skim a long session and
unfolds them again without losing their place. Phone and desktop derive the
same turns from the loaded messages; turns and the fold are never stored or
sent to the bridge.

## Required Behavior

- A rendered user message continues the current turn while that turn has no
  agent output yet, or while the latest agent output before it (automation
  skipped) ends in a pending, running or completed tool or sub-agent step. It
  opens a new turn after text, reasoning, an error, or a failed or cancelled
  step, and when it is the first message loaded. Automation never opens a
  turn. Messages before the first opening prompt form one leading segment.
- One fold state covers the whole transcript. A page opens unfolded; the fold
  survives a full reload and ends with the page, so another session opens
  unfolded.
- Folded, each turn keeps its prompt bubble unchanged, and the rest becomes
  one line: "› {n} steps · {duration} — {first line of the final answer}" when
  done, dropping whatever is unknown; a sparkle and "Running · step {n}"
  ("Running" before the first step) while it runs; an error glyph and "Ended
  with an error · {first line}" when it failed. The leading segment reads
  "Earlier turn, partly loaded" while older pages remain and "Before the first
  prompt" once the start is loaded. Follow-ups and automation fold inside
  their turn. The "Working…" row, a retry row and unsent prompts stay as they
  are. Screen readers read each line as shown.
- The phone bar and the desktop toolbar (between Changes and More) carry one
  button on a loaded session: "Fold all turns" while unfolded, "Unfold all
  turns" while folded. The desktop tooltip adds the shortcut: ⌘− folds and ⌘=
  unfolds on macOS, Ctrl+− and Ctrl+= elsewhere, while focus is in the session
  page; they are inert elsewhere. Tapping a folded line unfolds every turn.
- A switch is instant, with no animation, so reduced motion needs nothing.
  While the reader follows the latest edge, a switch keeps following.
  Otherwise the turn at the top edge (button or shortcut) or the tapped turn
  stays put: a prompt on screen keeps its distance from the top edge, and from
  mid-turn the prompt lands at the top edge.
- Scrolling up while folded loads older pages as it does unfolded. A partial
  leading segment joins its prompt when that page arrives.
- Each switch from unfolded to folded reports `transcript_turns_folded` with
  no parameters from the phone; the desktop reports nothing. Unfolding and the
  control used are not reported.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated, no plugin: every branch of the turn rule, the leading segment, summaries and determinism; the fold state across reload and per page; the event once per fold and never on unfold or a repeated fold; folded rows and lines; holding the top-edge turn, a tapped turn and far turns not yet built, and following through a switch; both buttons and the desktop shortcuts per platform. |
| L3 Release | Client end to end on the release-target phone and on macOS, on a session of three or more pages: the button and ⌘−/⌘= from mid-turn and from a prompt on screen keep the reader's turn in place; a line tap unfolds at its turn; a switch while following keeps following; a running turn's line; paging older turns while folded; screen readers read the lines and the button; `transcript_turns_folded` arrives. Android, Windows and Linux: the button, and Ctrl+−/Ctrl+= on the desktops. Live plugin plus client, every supporting production plugin: a follow-up sent while a turn runs stays in that turn, or opens one where `docs/HARNESS_CAPABILITIES.md` says so; Claude and Pi automation stays inside its turn; a forced Claude re-import keeps follow-ups, peers and task outcomes in their turns. |
| L4 Extended | Switch while text streams and while an older page loads; fold, then reopen the session and open another. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Vary where the reader is: mid-turn, a prompt near the top edge, the latest
edge, far back after paging. Vary turn shapes: a long prompt, no steps, a
running or failed turn, follow-ups and automation mid-turn, a session that
starts with automation. Vary the control between the buttons, both shortcuts
and a line tap, and repeat the same control twice.

## Failure Signals

- The reading position jumps on fold or unfold, or a switch while following
  leaves the latest edge.
- Turns split differently after a re-import or reload than live, or a
  follow-up leaves its running turn on a harness the capability matrix marks
  supported.
- Automation opens a turn; a line shows narration as the answer or "step 0".
- The fold resets on reload, carries into another session, or rows ease in.
- A button shows the other state, a shortcut fires outside the session page or
  with the other platform's modifier, or types into the composer.
- A fold reports no event, an unfold or repeated fold reports one, or the
  event carries a parameter.

## Known Limitations

- The rule reads loaded messages only. About 2% of ordinary Claude prompts that
  follow a completed tool step join the previous turn, and a boundary can move
  once, at the old edge, when an older page loads.
- ACP follow-ups open a new turn (stop-and-send). Live, one sent after a running
  tool can move to a new turn once idle finalization marks that tool failed.
  Claude's live-only `isMeta` bubbles can open a bogus turn live.
- Claude sessions imported before the queued-command fix regain dropped
  follow-ups only on their next re-import.
- A folded running turn shows its "Running · step {n}" line with the "Working…"
  row below it, so two sparkles turn at once.
- Folding from one of the last few turns can clamp the list at the latest
  edge. The list then follows, so the next unfold lands at the end of the
  latest turn instead of the reader's turn.
- A far target is reached one cache-extended viewport a frame, so a long hold
  shows brief motion. Folded, older pages load after less scrolling, because
  the prefetch threshold is in pixels.

## Sources

- `client/module_core/lib/src/cubits/session_detail/transcript_turns.dart` and
  `client/module_core/test/cubits/session_detail/transcript_turns_test.dart`
- `setTranscriptFolded` in
  `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`
  and its tests in `session_detail_cubit_test.dart` beside the turn tests
- `session_detail_message_list.dart`, `transcript_turn_stub.dart` and
  `session_detail_body.dart` under
  `client/module_app_ui/lib/src/features/session_detail/widgets/`, with their
  tests
- `client/desktop/lib/features/sessions/desktop_session_detail_screen.dart` and
  its test
- `client/app/test/features/session_detail/widgets/session_detail_body_test.dart`
- `.plan/active/turn-navigation/PLAN.md`
