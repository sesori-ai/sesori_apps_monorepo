# Transcript Turn Navigation

## Capability

A session transcript reads as turns: a prompt, the agent's steps and its
answer. A reader folds every turn to one line to skim a long session and
unfolds them again without losing their place. While reading unfolded, the
prompt of the turn being read stays pinned at the top. Phone and desktop
derive the same turns from the loaded messages; turns and the fold are never
stored or sent to the bridge.

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
  their turn. Durations read "42s", "1m 02s" or "1h 05m 12s". The running
  line has no clock; the "Working…" row under it ticks the time since the
  prompt ("Working… · 1m 43s") where the prompt carries a time. The
  "Working…" row, a retry row and unsent prompts stay as they are. Screen readers read each line as shown.
- The phone bar and the desktop toolbar (between Changes and More) carry one
  button on a loaded session: "Fold all turns" while unfolded, "Unfold all
  turns" while folded. The desktop tooltip adds the shortcut: ⌘− folds and ⌘=
  unfolds on macOS, Ctrl+− and Ctrl+= elsewhere, while focus is in the session
  page; they are inert elsewhere. Tapping a folded line unfolds every turn.
- A pinch in folds and a pinch out unfolds, by touch or trackpad, at most once
  per gesture: at a scale of 0.8 or less, or 1.25 or more. A second finger
  makes a touch gesture a pinch at once, even with one finger held still, so
  two fingers on a touch screen never scroll the transcript. One-finger
  scrolling, taps, the timestamp peek (finger or trackpad), a code block's
  horizontal scroll and trackpad scrolling are unaffected.
- A switch is instant, with no animation, so reduced motion needs nothing.
  The turn at the top edge (button or shortcut), the tapped turn or the turn
  under the pinching fingers stays put,
  even while the reader follows the latest edge: a prompt on screen keeps its
  distance from the top edge, and from mid-turn the prompt lands at the top
  edge, as far as the list can scroll. A switch that moves the list stops
  following until the reader scrolls back down. A pinch that switches nothing
  leaves following alone, and a pinch while reading history stays detached.
- Unfolded, while the prompt that opened the turn at the top edge is above the
  edge, that prompt is pinned at the top of the transcript: the user bubble's
  style with its Markdown rendered as the real bubble renders it, cut at about
  three lines of that text, or the first attachment's name when it has no text.
  The cut holds whatever a prompt contains — a code fence, a table or an image
  never makes the pinned row taller — at any width and text scale, so the
  transcript beneath never shifts. Only the start of the prompt is built, so
  pinning a pasted document costs no more than pinning a sentence. Nothing in
  the row is pressable and nothing in it scrolls: a remote image is named in
  plain text rather than fetched or offered as a button, a fenced block is a
  still picture of its first lines with no copy or open-all control, and a link
  reads as ordinary text with no underline and no link colour. So pinning
  a prompt neither contacts the host it names nor pages history the reader never
  asked for. The transcript's own bubble keeps the button that opens such an
  image, its links stay underlined and openable, and its own code blocks stay
  copyable and scrollable.
  The next turn's prompt pushes it out as it
  reaches it. Only an opening prompt is pinned, never a follow-up or
  automation, and nothing is pinned while folded or over the messages before
  the first prompt. A tap on the bubble puts that prompt at the top edge, which
  stops following like any jump; a tap on the faded band beside the bubble does
  nothing, and a drag or a wheel that starts anywhere on the band still
  scrolls. Screen readers find the bubble as a button labelled with the prompt's
  words as the row renders them — emphasis markers, backticks and link targets
  resolved, not read out as source — or the attachment's name when it has no
  text, with the hint "Jump to this prompt", also when the prompt's own row is
  far above and not built, and find no action on the band around it.
- Scrolling up while folded loads older pages as it does unfolded. A partial
  leading segment joins its prompt when that page arrives.
- Each switch from unfolded to folded reports `transcript_turns_folded` with
  no parameters from the phone; the desktop reports nothing. Unfolding and the
  control used are not reported.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated, no plugin: every branch of the turn rule, the leading segment, summaries and determinism; the fold state across reload and per page; the event once per fold and never on unfold or a repeated fold; folded rows and lines; holding the top-edge turn, a tapped turn and far turns not yet built, while following and after a clamp at the latest edge; both buttons and the desktop shortcuts per platform; touch and trackpad pinch per platform (iOS, Android, macOS): once per gesture, one finger held still, below the thresholds, the turn under the fingers while following and while reading history, and one-finger scroll, peek and nested horizontal scroll unaffected; the pinned prompt appearing as its prompt leaves the top edge, pushed out by the next one, hidden while folded and before the first prompt, cut at three lines at a narrow width and at a large text scale and with a table, a code fence and an image in the prompt, a remote image named rather than fetched or made a control, only the opening of a pasted document built, a fence the cut leaves open still a code block, a pinned fence a still preview with no control and no older page requested, a pinned link ordinary text rather than an underlined affordance, every block pinned with nothing pressable and nothing scrollable, the bubble's semantics label the prompt's words rather than its Markdown, the band carrying no semantics action beside the bubble's, and jumping to its prompt on a tap on the bubble and through its semantics button, also when that prompt is not built, while a tap beside the bubble does nothing and a drag on the band still scrolls. |
| L3 Release | Client end to end on the release-target phone and on macOS, on a session of three or more pages: the button and ⌘−/⌘= from mid-turn and from a prompt on screen keep the reader's turn in place; a line tap unfolds at its turn; a fold and unfold from one of the last turns returns to the turn at the top edge; a real-device pinch in and out on the phone and a macOS trackpad pinch, while following (the turn under the fingers stays and following stops) and while reading history (it stays detached), with one-finger scroll, the peek and a code block's horizontal scroll unaffected; a running turn's line; the pinned prompt through a long turn with no visible lag, pushed out by the next prompt, its Markdown rendered and cut with no change of height as the pinned turn changes, and jumping on a tap on the bubble; paging older turns while folded; screen readers read the lines, the button and the pinned prompt, whose action jumps to it; `transcript_turns_folded` arrives. Android, Windows and Linux: the button, and Ctrl+−/Ctrl+= on the desktops. Live plugin plus client, every supporting production plugin: a follow-up sent while a turn runs stays in that turn, or opens one where `docs/HARNESS_CAPABILITIES.md` says so; Claude and Pi automation stays inside its turn and is never pinned; a forced Claude re-import keeps follow-ups, peers and task outcomes in their turns. |
| L4 Extended | Switch while text streams and while an older page loads; fold, then reopen the session and open another. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Vary where the reader is: mid-turn, a prompt near the top edge, the latest
edge, far back after paging. Vary turn shapes: a long prompt, no steps, a
running or failed turn, follow-ups and automation mid-turn, a session that
starts with automation. Vary the control between the buttons, both shortcuts,
a line tap and a pinch, and repeat the same control twice. Pinch slowly and
fast, horizontally and vertically, with one finger still, over a prompt, an
answer and a folded line, and on a trackpad while text streams.

## Failure Signals

- The reading position jumps on fold or unfold, including from the latest
  edge, or a switch snaps back to the latest edge.
- Turns split differently after a re-import or reload than live, or a
  follow-up leaves its running turn on a harness the capability matrix marks
  supported.
- Automation opens a turn; a line shows narration as the answer or "step 0".
- A pinch scrolls the transcript or switches twice; a one-finger scroll,
  a peek or a trackpad scroll folds; a pinch that switches nothing detaches
  the list, or a pinch while reading history re-attaches it.
- A follow-up or automation shows as the pinned prompt; the pinned prompt
  shows while its prompt is on screen, lags visibly behind a scroll, covers
  the next prompt instead of being pushed out, or swallows a scroll.
- The pinned row shows Markdown source, changes height as it renders or as the
  pinned turn changes, or a tap beside the bubble jumps.
- The pinned row fetches a remote image, or offers a control — an open-image
  button, a copy icon, an open-all link — or looks like one, such as an
  underlined link, while a press jumps to the prompt instead; a scroll that pins
  a long pasted prompt stalls; pinning a prompt that contains a code block loads
  an older page.
- A screen reader or switch control finds an action on the band beside the
  pinned bubble, or reads the pinned bubble's label as Markdown source:
  `**bold**`, backticks or a whole URL instead of the prompt's words.
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
  row below it, so two sparkles turn at once. Only the "Working…" row shows a
  time.
- A far target is reached one cache-extended viewport a frame, so a long hold
  shows brief motion. Folded, older pages load after less scrolling, because
  the prefetch threshold is in pixels.
- Two-finger touch scrolling no longer scrolls the transcript; it pinches. A
  trackpad pinch that starts while following can flash the jump-to-latest
  pill for a frame, as the trackpad peek does. A trackpad gesture that neither
  pinches nor scrolls leaves the list detached, as before pinch existed.
- The pinned prompt's cut is approximate: Markdown blocks have their own
  metrics, so the last visible line can be part of a block rather than a whole
  line of text. Only the prompt's first few thousand characters are rendered
  there, far more than three lines can show, so a construct that needs a later
  line — a link reference definition — reads as source in the pinned row only.
  The semantics label is read from that same rendered prefix, so a screen reader
  hears the start of a pasted document and reaches the rest by activating the
  button; a prompt that renders no words at all, such as one image, is read out
  as its source rather than left unlabelled.
  The pinned prompt can trail a scroll by one frame, and while pinned it covers
  the top of the rows beneath it.

## Sources

- `client/module_core/lib/src/cubits/session_detail/transcript_turns.dart` and
  `client/module_core/test/cubits/session_detail/transcript_turns_test.dart`
- `setTranscriptFolded` in
  `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`
  and its tests in `session_detail_cubit_test.dart` beside the turn tests
- `session_detail_message_list.dart`, `transcript_turn_stub.dart`,
  `transcript_pinch_detector.dart`, `transcript_sticky_prompt_overlay.dart`
  and `session_detail_body.dart` under
  `client/module_app_ui/lib/src/features/session_detail/widgets/`, with their
  tests
- The preview's rendering rules in `client/module_app_ui/lib/src/`:
  `widgets/markdown_styles.dart` (preview stylesheet and builders),
  `widgets/code_block.dart` (`CodeBlockPreview`),
  `features/session_detail/widgets/user_prompt_markdown_image.dart` and
  `utils/markdown_plain_text.dart`
- `client/desktop/lib/features/sessions/desktop_session_detail_screen.dart` and
  its test
- `client/app/test/features/session_detail/widgets/session_detail_body_test.dart`
- `.plan/active/turn-navigation/PLAN.md`
