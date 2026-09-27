# Transcript Turn Navigation

## Capability

A session transcript reads as turns: a prompt, the agent's steps and its
answer. A reader folds every turn to one line to skim a long session and
unfolds them again without losing their place. While reading unfolded, the
prompt of the turn being read stays pinned at the top. A Prompts screen lists
every loaded prompt in the transcript's order, opens on the one being read and
returns to any prompt with one tap. Phone and desktop derive the same turns and
prompt list from the loaded messages; turns, the fold and the list are never
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
- Unfolded, the prompt that opened the turn being read stays pinned at the top
  of the transcript as a header that compacts with the scroll. Each prompt shows
  as exactly one bubble, tracking the scroll in the same frame with no pop or
  lag. As a prompt's own bubble reaches the pin line its top stops there while
  its bottom keeps travelling with the rows, so the bubble squeezes to about
  three lines of its text, then holds that height; a prompt of three lines or
  fewer just pins whole. The pin takes over where it and the bubble are
  pixel-identical, its Markdown rendered as the real bubble renders it, and the
  bubble underneath stops painting. A reversed scroll retraces every step. A
  soft page-coloured halo shows only while rows slide under the compacted
  bubble, and the pin line never clips it. The next turn's prompt pushes the
  pinned one up and out, step for step with the scroll. Only the start of a
  pasted prompt is built, so pinning a pasted document costs no more than
  pinning a sentence, and nothing in the pinned bubble takes a press or a
  scroll of its own: a press anywhere on it glides to its prompt, and a remote
  image stays named rather than fetched. So pinning a prompt neither contacts
  the host it names nor pages history the reader never asked for. Only an
  opening prompt is pinned, never a follow-up or automation, and nothing is
  pinned while folded or over the messages before the first prompt. A tap on
  the bubble glides back to that prompt, whose bubble grows back to full height
  as it lands at the top edge, which stops following like any jump; with
  reduced motion it jumps there instead. A tap on the band beside the bubble
  does nothing, and a drag or a wheel that starts anywhere on the band still
  scrolls. Screen readers find the bubble as a button labelled with the prompt's
  words as the row renders them — emphasis markers, backticks, table pipes and
  link targets resolved, not read out as source; an image named as the row names
  it, by its alt text or by the same generic name the mention falls back to; and
  each list item, table cell and paragraph on a line of its own — or the
  attachment's name when the prompt has no text, with the hint "Jump to this
  prompt", also when the prompt's own row is far above and not built, and find no
  action on the band around it.
- The phone bar and the desktop toolbar carry a "Prompts" button, before the
  fold button, on a loaded session. It covers the session page with the
  Prompts screen: a "Prompts" title with a "Close prompts" button, then one row
  per loaded prompt in the transcript's order, each follow-up indented below its
  opener with a smaller, lighter dot on the same rail. A row shows one line of
  the prompt's text, or its first attachment's name, and its time of day where
  the prompt carries one, never repeating the date its header names. Timed rows sit under sticky day headers ("Today",
  "Yesterday", then the date), oldest day first, with a "No date" group above
  them for undated prompts; a session with no timed prompt shows no headers and
  no times. The list ends with "{n} prompts loaded"; an empty session reads "No
  prompts in this session yet".
- The screen opens with the prompt the transcript's pin names already on
  screen just below its day header, with no visible scroll, or at the prompt
  just below when the top edge shows the messages before the first prompt. That
  row keeps a subtle tint for as long as the screen is open, the same with
  reduced motion. With no such prompt it opens at the newest end with nothing
  tinted.
- The screen keeps the prompts it opened with: an older page or a new prompt
  arriving while it is open does not move or add rows.
- A tap on a row closes the screen, once the transcript has landed beneath it,
  with the transcript on that message: an
  opener on the pin line, a follow-up just below the pinned prompt, also when
  its row was not built, when the transcript was folded (it unfolds) and when
  it arrived after the reader scrolled away. A prompt gone meanwhile moves
  nothing. The close button and the system back gesture close the screen
  without leaving the page and with the transcript unmoved. While open, the
  covered transcript takes no focus and screen readers skip it. Screen readers
  read each row as one button: its number where known, the text ("Follow-up:
  {text}" for a follow-up) and its time, with the hint "Jump to this prompt".
- The screen grows in from the button that opened it, fading in and scaling
  up slightly over a lightly dimmed transcript, and shrinks back into the same
  place when it closes, also after a row tap, where it leaves only once the
  transcript has landed. With reduced motion it only fades. The transcript
  under it never moves, scrolls or rebuilds.
- On iOS a drag from the screen's left edge moves the Prompts screen with the
  finger, lightening the dim as it goes. Let go past halfway or with a flick
  and it slides off and closes; let go earlier and it springs back. Elsewhere
  the edge does nothing.
- Each opening from the phone bar reports `transcript_prompts_opened` with
  `entry: session_bar`; the desktop reports nothing. Closing and row taps are
  not reported.
- Scrolling up while folded loads older pages as it does unfolded. A partial
  leading segment joins its prompt when that page arrives.
- Each switch from unfolded to folded reports `transcript_turns_folded` with
  no parameters from the phone; the desktop reports nothing. Unfolding and the
  control used are not reported.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated, no plugin: every branch of the turn rule, the leading segment, summaries and determinism; the fold state across reload and per page; the event once per fold and never on unfold or a repeated fold; folded rows and lines; holding the top-edge turn, a tapped turn and far turns not yet built, while following and after a clamp at the latest edge; both buttons and the desktop shortcuts per platform; touch and trackpad pinch per platform (iOS, Android, macOS): once per gesture, one finger held still, below the thresholds, the turn under the fingers while following and while reading history, and one-finger scroll, peek and nested horizontal scroll unaffected; the pinned prompt as one bubble per prompt through a slow scroll both ways over short and long prompts, never moving against the scroll and appearing or leaving only at the screen's edges, taking over exactly where it covers its bubble, its halo unclipped by the pin line, compacted to three lines at a narrow width and at a large text scale while a short prompt pins whole, hidden while folded and before the first prompt, rendered as its bubble with a table and a code block, only the opening of a pasted document built, a fence the cut leaves open still a code block, a pinned code block requesting no older page, the bubble's semantics label the prompt's words rather than its Markdown, an image-only prompt spoken as the row names it with and without alt text, a list, table and struck word spoken as the row lays them out, the band carrying no semantics action beside the bubble's, and gliding to its prompt on a tap on the bubble, never turning back and landing with the pin grown to full height, jumping instead with reduced motion, and through its semantics button, also when that prompt is not built, while a tap beside the bubble does nothing and a drag on the band still scrolls; the Prompts screen's rows, indentation, day headers and "No date" group, the untimed case, the count and empty rows, the opening anchor and its tint through a scroll away and back with and without reduced motion, an unknown anchor, the anchor the pin names folded and unfolded and before the first prompt, a jump to an opener, a follow-up, an unbuilt row, a folded transcript and a prompt that arrived while detached, a vanished id, back and the close button leaving the transcript unmoved, both entry buttons, the row semantics and the event per opening; the screen's transition in and out, its scale and dim, the plain fade with reduced motion, and the transcript unmoved through it; the iOS edge swipe following the finger, springing back from a short release, closing from a long one and from a flick, and doing nothing off iOS. |
| L3 Release | Client end to end on the release-target phone and on macOS, on a session of three or more pages: the button and ⌘−/⌘= from mid-turn and from a prompt on screen keep the reader's turn in place; a line tap unfolds at its turn; a fold and unfold from one of the last turns returns to the turn at the top edge; a real-device pinch in and out on the phone and a macOS trackpad pinch, while following (the turn under the fingers stays and following stops) and while reading history (it stays detached), with one-finger scroll, the peek and a code block's horizontal scroll unaffected; a running turn's line; the pinned prompt through short and long prompts both ways with no lag, pop or jump, compacting and pushed out by the next prompt step for step with the scroll, its halo only over sliding rows, and gliding back on a tap on the bubble; the Prompts screen from the phone bar and the macOS toolbar, opening on the prompt being read with no visible scroll, and a tap landing an opener, a follow-up and a far prompt, with back and close leaving the transcript unmoved; its transition in and out, and again with Reduce Motion on, with nothing jumping; on the iPhone an edge swipe that follows the finger, springs back when let go early and closes past halfway or on a flick; paging older turns while folded; screen readers read the lines, the button and the pinned prompt, whose action jumps to it, and the Prompts rows; `transcript_turns_folded` and `transcript_prompts_opened` arrive. Android, Windows and Linux: the button, and Ctrl+−/Ctrl+= on the desktops. Live plugin plus client, every supporting production plugin: a follow-up sent while a turn runs stays in that turn, or opens one where `docs/HARNESS_CAPABILITIES.md` says so; Claude and Pi automation stays inside its turn and is never pinned; a forced Claude re-import keeps follow-ups, peers and task outcomes in their turns. |
| L4 Extended | Switch while text streams and while an older page loads; fold, then reopen the session and open another. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Vary where the reader is: mid-turn, a prompt near the top edge, the latest
edge, far back after paging. Vary turn shapes: a long prompt, no steps, a
running or failed turn, follow-ups and automation mid-turn, a session that
starts with automation. Vary the control between the buttons, both shortcuts,
a line tap and a pinch, and repeat the same control twice. Open the Prompts
screen from mid-turn, before the first prompt, folded and while text streams,
on sessions with and without prompt times and across midnight, and return to an
opener, a follow-up and a prompt far above. On iOS, swipe it away slowly
and fast, stopping short and reversing mid-drag. Pinch slowly and
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
- A follow-up or automation shows as the pinned prompt; a prompt shows two
  bubbles at once, or its bubble pops, jumps, lags a frame behind the rows or
  moves against the scroll; the pin covers the next prompt instead of being
  pushed out, or swallows a scroll.
- The pinned bubble shows Markdown source, differs from its bubble where it
  takes over, compacts a prompt of three lines or fewer, grows taller than its
  bubble or shorter than three lines, shows its halo while nothing slides under
  it or has it clipped at the pin line, or a tap beside the bubble jumps.
- A tap on the pinned bubble jumps instead of gliding, or glides under reduced
  motion; the pinned bubble fetches a remote image, or a press on a control
  in it acts instead of gliding; a scroll that pins a long pasted prompt
  stalls; pinning a prompt that contains a code block loads an older page.
- A screen reader or switch control finds an action on the band beside the
  pinned bubble, or reads the pinned bubble's label as Markdown source:
  `**bold**`, backticks, table pipes or a whole URL instead of the prompt's
  words, or names an image differently from the mention on screen, or runs two
  list items or table cells into one word.
- The Prompts screen opens scrolled away from the prompt being read, visibly
  scrolls into place, tints a different prompt or loses the tint; lists prompts
  out of the transcript's order, a follow-up above or away from its opener, or
  a prompt the transcript has not loaded; shows day headers out of order or
  "No date" below them.
- The Prompts rows move while the screen is open; the transcript's jump shows
  after the screen closes.
- The Prompts screen pops in or out, jumps mid-transition, scales under
  reduced motion, or the transcript moves or reflows behind it. The iOS edge
  swipe does not track the finger, the screen snaps instead of following or
  springing back, or the session underneath moves.
- A Prompts row tap closes the screen with the transcript elsewhere, or does
  nothing; back leaves the page instead of closing the screen; closing moves
  the transcript; the covered transcript takes focus or is read out.
- The fold resets on reload, carries into another session, or rows ease in.
- A button shows the other state, a shortcut fires outside the session page or
  with the other platform's modifier, or types into the composer.
- A fold reports no event, an unfold or repeated fold reports one, or the
  event carries a parameter. An opening of the Prompts screen reports no
  `transcript_prompts_opened` or the wrong `entry`.

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
- The compacted prompt's three lines are approximate: Markdown blocks have
  their own metrics, so the last visible line can be part of a block rather
  than a whole line of text. The pinned bubble shows its controls — a code
  block's copy icon, an underlined link, an open-image button — as the bubble
  does, but a press on them glides to the prompt. Only the prompt's first few
  thousand characters are rendered there, far more than three lines can show, so a construct that needs a later
  line — a link reference definition — reads as source in the pinned row only.
  The semantics label is read from that same rendered prefix, so a screen reader
  hears the start of a pasted document and reaches the rest by activating the
  button. A prompt that renders no words at all — nothing but a horizontal rule,
  say — is read out as its own short source rather than left unlabelled.
  While pinned, the prompt covers the top of the rows beneath it. A glide to
  a prompt far above aims at an estimate that sharpens as rows are built, so
  its speed can bend on the way; it still lands exactly.
- The Prompts screen lists only
  what the transcript has loaded, with no search, and rows carry no prompt
  numbers. Grok, Antigravity, Copilot, Cursor, Hermes and OMP carry no prompt
  times, so their sessions show no times and no day headers. A prompt that arrived after the
  reader scrolled away lands just below the pinned prompt, where a follow-up
  would, rather than on the pin line.

## Sources

- `client/module_core/lib/src/cubits/session_detail/transcript_turns.dart` and
  `client/module_core/test/cubits/session_detail/transcript_turns_test.dart`
- `setTranscriptFolded` in
  `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`
  and its tests in `session_detail_cubit_test.dart` beside the turn tests
- `session_detail_message_list.dart`, `transcript_turn_stub.dart`,
  `transcript_pinch_detector.dart`, `transcript_sticky_prompt_overlay.dart`,
  `transcript_sticky_layout.dart`, `transcript_prompt_slot.dart`,
  `transcript_laid_out_list_view.dart`,
  `transcript_glide_activity.dart`, `transcript_jump_notifier.dart`,
  `user_message_card.dart`
  and `session_detail_body.dart` under
  `client/module_app_ui/lib/src/features/session_detail/widgets/`, with their
  tests
- The pinned bubble's label in `client/module_app_ui/lib/src/`:
  `features/session_detail/widgets/user_prompt_markdown_image.dart` and
  `utils/markdown_plain_text.dart`
- `client/module_app_ui/lib/src/features/session_prompts/` and
  `client/module_app_ui/test/features/session_prompts/`
- `transcriptPromptsOpened` in
  `client/module_core/lib/src/foundation/models/product_analytics/product_analytics_event.dart`
- `client/desktop/lib/features/sessions/desktop_session_detail_screen.dart` and
  its test
- `client/app/test/features/session_detail/widgets/session_detail_body_test.dart`
- `.plan/active/turn-navigation/PLAN.md`
