# Transcript Turn Navigation

## Capability

A session transcript reads as turns: a prompt, the agent's steps and its
answer. While reading, the latest prompt or steer above the top edge stays
pinned there. A Prompts screen, opened by a button or a pinch, lists every
prompt of the session in the transcript's order, opens on the one being read and
returns to any prompt with one tap, loading the transcript through it when it
is not loaded yet. Phone and desktop derive the same turns and prompt list from
the loaded messages and the bridge's prompt index; turns and the list are never
stored or sent to the bridge.

## Required Behavior

- A rendered user message continues the current turn while that turn has no
  agent output yet, or while the latest agent output before it (automation
  skipped) ends in a pending, running or completed tool or sub-agent step. It
  opens a new turn after text, reasoning, an error, or a failed or cancelled
  step, and when it is the first message loaded. Automation never opens a
  turn. Messages before the first opening prompt form one leading segment.
- A pinch in opens the Prompts screen, by touch or trackpad, at most once per
  gesture, at a scale of 0.8 or less; a pinch out on the transcript does
  nothing. A second finger
  makes a touch gesture a pinch at once, even with one finger held still, so
  two fingers on a touch screen never scroll the transcript. One-finger
  scrolling, taps, the timestamp peek (finger or trackpad), a code block's
  horizontal scroll and trackpad scrolling are unaffected. A pinch never moves
  the transcript and leaves following as it was: a reader following the latest
  edge keeps following, and one reading history stays detached.
- The latest user message above the top edge, a turn's opening prompt or a
  steer (a follow-up sent while the turn runs) alike, stays pinned at the top
  of the transcript as a header that compacts with the scroll. A steer pins,
  compacts, hands over, is pushed out and glides back exactly as a prompt does.
  Apart from the tall message below, each message shows as exactly one bubble,
  tracking the scroll in the same
  frame with no pop or lag. As a message's own bubble reaches the pin line its
  top stops there while its bottom keeps travelling with the rows, so the
  bubble squeezes to about three lines of its text, then holds that height; a
  message of three lines or fewer just pins whole. The pin takes over where it
  and the bubble are pixel-identical, its Markdown rendered as the real bubble
  renders it, and the bubble underneath stops painting. A message taller than
  the rows between the pin line and the composer stays readable to its last
  line: it scrolls on as an ordinary row, its top passing under the bar, until
  only about three lines of it are left below the pin line, and only then pins
  those last lines, pixel-identical where it takes over; its cut top edge fades
  in as the scroll continues, while the rest of its bubble scrolls on above the
  pin line. A reversed scroll retraces every step. A
  soft page-coloured halo shows only while rows slide under the compacted
  bubble, and the pin line never clips it. The next user message, never an
  answer or automation, pushes the pinned one up and out, step for step with
  the scroll. Only the end of a
  pasted document is built, so pinning it costs no more than pinning a
  sentence, and nothing in the pinned bubble takes a press or a
  scroll of its own: a press anywhere on it glides to its message, and a remote
  image stays named rather than fetched. So pinning a message neither contacts
  the host it names nor pages history the reader never asked for. Automation is
  never pinned, and nothing is pinned over the messages before the first user
  message, except below. A tap on
  the bubble glides back to that message, whose bubble grows back to full height
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
- When the loaded messages start inside a turn whose prompt is not loaded, and
  the bridge sent the prompt index, that prompt pins above them in the same
  bubble, showing the index's preview: the start of its text, up to 300
  characters, cut at the compact height. The pin fades in as the index
  arrives, and it stays while a refresh fetches the index again. A tap loads
  the transcript through that prompt, showing a spinner beside the pin only
  after about 150 ms, then glides back to it as for a loaded prompt. A failure
  shows a popup naming why ("Couldn't open this prompt", no longer in the
  session, the transcript refreshed, or "Update the bridge" for an older
  bridge) and keeps the pin. Once the prompt loads, by the tap or by scrolling
  back, its pin crossfades from the preview to its own copy, the bubble easing
  between the two sizes, so a long prompt that pins its end changes visibly
  but never snaps. Without an index nothing pins there.
- The phone bar and the desktop toolbar carry a "Prompts" button, before the
  menu, on a loaded session. It covers the session page with the Prompts
  screen: a "Search prompts" field with a "Close prompts" button, then one row
  per loaded prompt in the transcript's order, each follow-up indented below its
  opener with a smaller, lighter dot on the same rail. A row shows its number,
  one line of the prompt's text, or its first attachment's name, and its time
  of day where the prompt carries one, never repeating the date its header
  names. Timed rows sit under sticky day headers ("Today",
  "Yesterday", then the date), oldest day first, with a "No date" group above
  them for undated prompts; a session with no timed prompt shows no headers and
  no times. The list ends with "{n} prompts loaded"; an empty session with no
  earlier page reads "No prompts in this session yet".
- While the session has earlier messages, the app also asks the bridge for the
  session's prompt index, after each load and refresh. Once it arrives the list
  holds every prompt of the session, unloaded ones included with their number,
  time and first line, ends with "{n} prompts" ("{n} matches" while searching)
  and has no "Load earlier prompts". A refresh drops the index until it is fetched again: a screen
  opened meanwhile lists the loaded prompts, and an open screen keeps its rows
  until the new index joins them. Without one — an older bridge or a failed request — the list
  stays the loaded prompts only, as below.
- A tap on an unloaded row loads the transcript from that prompt to the loaded
  part. After 150 ms its row shows a spinner; once the messages land the screen
  closes onto the prompt exactly as for a loaded row. A tap on another row
  meanwhile replaces the target; another tap on the same row sends no second
  load. While the spinner shows, screen readers hear the row as "Loading". A
  failed load shows a notice at the bottom of the list, which taps pass
  through, and moves nothing: "Couldn't open this prompt…" for an error, "The
  session just refreshed…" when a refresh dropped the load, "This prompt is no
  longer in the session" when the loaded range lacks it, and "Update the bridge
  to open earlier prompts" for a bridge without the route.
  Closing the screen cancels the jump, not the load.
- A prompt's number is its place among all of the session's user messages,
  loaded or not, counted by the bridge from its own history: the first prompt
  is 1, and a user message the list hides still takes a number. Loading older
  pages never changes a number already shown. A bridge that sends no count
  leaves every row unnumbered.
- For ACP harnesses the bridge stamps a prompt it sends with the instant it
  dispatched it, or created the session for a first prompt, so its row and
  "Working…" carry that time; a prompt read back from the harness's own
  history stays undated.
- The screen opens with the prompt the transcript's pin names already on
  screen just below its day header, with no visible scroll, or at the prompt
  just below when the top edge shows the messages before the first prompt. That
  row keeps a subtle tint for as long as the screen is open, the same with
  reduced motion. With no such prompt it opens at the newest end with nothing
  tinted.
- The screen keeps the prompts it opened with until an older page lands, from
  its own "Load earlier prompts" or from a load the transcript already had
  running as it opened. That lists the transcript's prompts afresh, with the
  rows on screen kept in place. Before then, a new prompt arriving or another
  transcript change does not move or add rows.
- While the session has earlier messages and no prompt index, "Load earlier
  prompts" heads the list.
  It loads the transcript's next older page, is disabled while that runs or
  while the transcript refreshes, and disappears once the session's start has
  loaded. At a large text size or a narrow width its label wraps and shows
  whole, also under Bold Text and platform spacing overrides. The page's
  prompts arrive below it, above the rows already there, and the rows on
  screen stay exactly where they were, also when the control disappears in
  the same load, unless the list cannot scroll that far: one shorter than the
  screen, or a last page smaller than the control loaded from the very top.
- Typing in the search field filters the rows as it is typed, ignoring case,
  over each loaded prompt's whole text and each unloaded prompt's preview. Each remaining row grows by one line showing
  the words around its first match, the match highlighted, so a match past the
  row's first line still shows why it matched, in any script and at any text
  size; an excerpt never splits a code point (surrogate pair). Rows that no
  longer match fold away, keeping their excerpt while typing
  goes on, and returning rows unfold, over about 200 ms (at once with reduced
  motion); day headers fold with their last row, so only days with a match keep
  a header. The row being read — the tinted one while on screen, else the top
  one showing below the pinned day header — or the nearest remaining row after
  it stays where it was throughout;
  only a list too short to fill the screen settles against its ends. Clearing
  the search unfolds everything the same way, also after a search that matched
  nothing, which brings the rows back around the row that was being read. The
  list then ends with "{n} matches" over every prompt once the prompt index has
  arrived, and without one with "{n} matches in the prompts loaded so far"
  ("No matches…" when none, in both). Earlier prompts loaded during a search
  join the filter. The desktop focuses the field
  on opening; the phone waits for a tap. Escape closes the screen, also while
  typing and after a click outside the field, and the search is not kept.
- A tap on a row closes the screen, once the transcript has landed beneath it,
  with the transcript on that message: an
  opener or a follow-up on the pin line, where it pins, also when
  its row was not built and when it arrived after the reader scrolled away. A prompt gone meanwhile moves
  nothing. The close button, the system back gesture (Android's predictive back
  once committed) and the desktop's ⌘[ or Ctrl+[ close the screen without
  leaving the page and with the transcript unmoved; ⌘[ leaves a pushed page
  only once the screen is closed. While open, the
  covered transcript takes no focus and screen readers skip it. Screen readers
  read each row as one button: its number where known, the text ("Follow-up:
  {text}" for a follow-up) and its time, with the hint "Jump to this prompt".
- The screen grows in from the button or the pinching fingers that opened it,
  fading in and scaling up slightly over a lightly dimmed transcript, and
  shrinks back into the same place when it closes, by every way out except the
  iOS edge swipe: the close button, Escape, back, predictive back, ⌘[ or
  Ctrl+[, and a row tap, where it leaves only once the transcript has landed.
  A pinch out shrinks it toward the fingers instead. None of them pops the
  screen away. With reduced motion it only fades. The transcript under it
  never moves, scrolls or rebuilds.
- A pinch out on the Prompts screen, by touch or trackpad, closes it in step
  with the fingers: the screen shrinks toward them and fades as they spread.
  On release the spread is carried 0.1 s ahead at its current speed: past a
  scale of 1.25 it finishes closing, short of it it springs back open. The
  slight slide of fingers lifting off a phone's glass only nudges that
  projection, so a wide spread still closes. One-finger scrolling, row taps, a
  pinch in and the search field, including its text selection, are unaffected.
- On iOS a drag from the screen's left edge moves the Prompts screen with the
  finger, lightening the dim as it goes. Let go past halfway or with a flick
  and it slides off and closes; let go earlier and it springs back. Elsewhere
  the edge does nothing.
- Each opening from the phone bar reports `transcript_prompts_opened` with
  `entry: session_bar`, and each opening by a pinch with `entry: pinch`; the
  desktop reports nothing. Closing and row taps are
  not reported.
- A partial leading segment joins its prompt when an older page arrives.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated, no plugin: see [automated checks](#automated-checks-l2). |
| L3 Release | Client end to end and live plugin plus client: see [release checks](#release-checks-l3). |
| L4 Extended | Open the Prompts screen and return from it while text streams and while an older page loads. |
| L5 Full | No additional coverage. |

### Automated checks (L2)

Touch and trackpad cases run per platform (iOS, Android, macOS).

- Turns: every branch of the turn rule, the leading segment and determinism.
- Pinch on the transcript: the Prompts screen opens once per gesture on a pinch
  in and never on a pinch out, also with one finger held still, and not below
  the threshold; the transcript stays unmoved, still following while following
  and still detached while reading history; one-finger scroll, the peek and a
  nested horizontal scroll are unaffected.
- The pinned message, through a slow scroll both ways over short and long
  prompts:
  - one bubble per message, never moving against the scroll and appearing or
    leaving only at the screen's edges;
  - taking over exactly where it covers its bubble, its halo unclipped by the
    pin line;
  - compacted to three lines at a narrow width and at a large text scale, while
    a short prompt pins whole;
  - hidden before the first prompt;
  - a steer pinning, taking over exactly, compacting, pushed out by the next
    user message as a prompt is, and gliding back on a tap;
  - a message taller than the screen scrolling as a row with its last line
    shown below the pin line until three lines are left, then pinning its end
    exactly over its bubble, its cut top fading in;
  - rendered as its bubble with a table and a code block; only the end of a
    pasted document built; a fence the cut leaves open reopened as a code
    block; a pinned code block requesting no older page.
- The pinned bubble's semantics: its label is the prompt's words rather than
  its Markdown; an image-only prompt is spoken as the row names it, with and
  without alt text; a list, a table and a struck word are spoken as the row lays
  them out; the band carries no semantics action beside the bubble's.
- The unloaded prompt's pin: its preview over a range that starts mid-turn; its
  fade-in as the index arrives, kept through a refetch; a tap loading through
  it with the spinner only after the delay, the crossfade into the loaded copy
  and the glide back; a failed load's popup with the pin kept; the pin's entry
  chosen from the rendered range (`TranscriptPromptListBuilder.pinAbove`).
- A tap on the pinned bubble glides to its prompt, never turning back, and lands
  with the pin grown to full height; with reduced motion it jumps instead; its
  semantics button does the same, also when that prompt is not built; a tap
  beside the bubble does nothing, and a drag on the band still scrolls.
- The Prompts screen's list: rows, indentation, day headers and the "No date"
  group, the untimed case, the count and empty rows, the row semantics, and
  both entry buttons.
- The opening anchor: the prompt the pin names, and the one below when the top
  edge is before the first prompt; its tint through a scroll away and back, with
  and without reduced motion; an unknown anchor.
- Search:
  - filtering as typed and clearing, with the reader's row still through the
    fold, also when a row hidden beneath the pinned day header folds away;
  - a search that matched nothing returning the reader's row when cleared;
  - a folding row keeping its excerpt as typing goes on;
  - the grown row and its highlighted match, the match and the count fitting
    at a large text size on a narrow phone, and an excerpt never splitting a
    code point (surrogate pair);
  - day headers only for days with a match, and the match count;
  - Escape closing, also after a click outside the field, and the desktop's
    focused field.
- "Load earlier prompts": at the top, calling the loader, disabled while
  loading and while the transcript refreshes; its wrapped label shown whole
  at a large text size and under a platform letter-spacing override; earlier
  prompts joining the filter below it with the reader's row
  still, also when the control disappears; a page the transcript was already
  loading as the screen opened joining it.
- The prompt index: fetched after a load and a refresh only while earlier
  messages exist, kept null on failure, an older index dropped on refresh; the
  merge of indexed, unloaded and unindexed loaded prompts; the full count and
  no "Load earlier prompts" with an index.
- A tap on an unloaded row: the spinner only after the delay, the move once
  loaded, a second tap replacing the first, and the older-bridge notice.
- The load-through response decoding off the calling isolate.
- Numbers and times: prompt numbers from the bridge's count kept through three
  older pages with hidden user messages and automation; no numbers without a
  count; the bridge's count for every page read (snapshot, stored-only,
  unlimited, empty and archived); the ACP dispatch stamp on sent and first
  prompts, a harness override, and undated history replay.
- Returning: a jump landing an opener and a follow-up on the pin line, an
  unbuilt row and a prompt that arrived while detached; a vanished id; back and
  the close button leaving the transcript unmoved.
- The transition: in and out, its scale and dim, the plain fade with reduced
  motion, and the transcript unmoved through it.
- The iOS edge swipe: following the finger, springing back from a short
  release, closing from a long one and from a flick, and doing nothing off iOS.
- Pinch out on the screen: following the fingers, closing past halfway,
  springing back short of it, closing on a quick short spread and by trackpad,
  and closing for realistic touch (fingers landing close together and 64 ms
  apart over a row, drifting, then sliding back a pixel as they lift);
  a second pinch during a spring-back moving nothing; one-finger scroll, a
  pinch in and the search field's selection unaffected.
- Every way out: the close button, Escape, back, predictive back, a row tap and
  the pinch out each run the transition backwards; the desktop's back shortcut
  (Ctrl+[ in the routine test, ⌘[ on macOS) closes what a page has open before
  leaving it.
- The analytics event per opening, with its entry.

### Release checks (L3)

On the release-target phone and on macOS, on a session of three or more pages:

- A real-device pinch in on the phone and a macOS trackpad pinch open the
  Prompts screen growing from the fingers, while following (following
  continues) and while reading history (it stays detached), with the transcript
  where it was on the way back. A pinch out on the transcript does nothing; a
  pinch out on the screen closes it in step with the fingers or springs back.
  One-finger scroll, the peek and a code block's horizontal scroll are
  unaffected.
- The pinned message through short and long prompts and steers, both ways, with
  no lag, pop or jump: compacting and pushed out by the next user message step
  for step with the scroll, a pasted prompt taller than the screen read to its
  last line before its end pins, its halo only over sliding rows, and gliding
  back on a tap on the bubble.
- The Prompts screen from the phone bar and the macOS toolbar: opening on the
  prompt being read with no visible scroll, its numbers matching the prompts'
  places in the session after paging back to the start, and a tap landing an
  opener, a follow-up and a far prompt.
- On a session of several hundred prompts, the screen listing all of them
  before any paging, and a tap on the oldest loading it and landing on it, with
  the spinner only on a slow link and the screen still scrolling smoothly while
  the response decodes. Against a bridge released before the prompt index, the
  list showing the loaded prompts with "Load earlier prompts".
- Typing a search, clearing it and loading earlier prompts with nothing under
  the reader jumping.
- Escape and ⌘[ closing on macOS, back and close leaving the transcript
  unmoved, and every way out but the iOS edge swipe shrinking the screen back.
- The transition in and out, and again with Reduce Motion on, with nothing
  jumping. On the iPhone, an edge swipe that follows the finger, springs back
  when let go early and closes past halfway or on a flick.
- Screen readers read the Prompts button, the pinned prompt, whose action jumps
  to it, and the Prompts rows. `transcript_prompts_opened` arrives.

On Android, Windows and Linux: the Prompts button and screen.

Live plugin plus client, every supporting production plugin:

- A follow-up sent while a turn runs stays in that turn, or opens one where
  `docs/HARNESS_CAPABILITIES.md` says so.
- A prompt sent to an ACP harness shows its time on the Prompts screen and in
  "Working…".
- Claude and Pi automation stays inside its turn and is never pinned.
- A forced Claude re-import keeps follow-ups, peers and task outcomes in their
  turns.

## Exploration Guidance

Vary where the reader is: mid-turn, a prompt near the top edge, the latest
edge, far back after paging. Vary turn shapes: a long prompt, no steps, a
running or failed turn, follow-ups and automation mid-turn, a session that
starts with automation. Open the Prompts screen by
its button and by a pinch, from mid-turn, before the first prompt and while text streams,
on sessions with and without prompt times and across midnight, and return to an
opener, a follow-up and a prompt far above. On iOS, swipe it away slowly
and fast, stopping short and reversing mid-drag. Pinch it out slowly and
quickly, stopping short, spreading and closing again mid-gesture, and lifting
one finger before the other. Pinch slowly and
fast, horizontally and vertically, with one finger still, over a prompt and an
answer, and on a trackpad while text streams.

## Failure Signals

- Turns split differently after a re-import or reload than live, or a
  follow-up leaves its running turn on a harness the capability matrix marks
  supported.
- Automation opens a turn.
- A pinch scrolls or moves the transcript, or opens the Prompts screen twice;
  a pinch out, a one-finger scroll, a peek or a trackpad scroll opens it; the
  screen grows from somewhere other than the fingers; a pinch detaches a
  following list, or a pinch while reading history re-attaches it.
- Automation shows as the pinned prompt, or a steer above the top edge is not
  the one pinned; a message shows two
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
  a prompt the transcript has not loaded while the bridge sent no index; shows
  day headers out of order or "No date" below them.
- With an index, a range that starts mid-turn pins nothing or a prompt other
  than the one that opened that turn; its pin pops in, blinks out during a
  refresh, or snaps from the preview to the loaded prompt instead of
  crossfading; a tap on it moves the transcript after a failure, shows its
  spinner at once on a fast load, or loads without gliding back.
- With an index, a prompt of the session is missing or listed twice; a tap on
  an unloaded row lands elsewhere, shows its spinner at once on a fast load,
  moves the transcript after a failure or after the screen closed, or a
  replaced tap still lands; an older bridge shows anything but the loaded
  prompts.
- A prompt's number changes when an older page loads, skips or repeats against
  the session's prompts, or starts at 1 on a page that is not the session's
  start; a prompt sent to an ACP harness shows no time.
- The Prompts rows move while the screen is open; the transcript's jump shows
  after the screen closes.
- Typing, clearing or opening the search moves the row being read; rows pop
  in or out instead of folding; a filtered row shows no reason for its match;
  a day header stays over no rows; the match count claims more than the loaded
  range; the rows under the reader move when earlier prompts load or when
  "Load earlier prompts" disappears; the control stays enabled while loading
  or refreshing, or its wrapped label is clipped.
- The Prompts screen pops in or out, jumps mid-transition, scales under
  reduced motion, or the transcript moves or reflows behind it. The iOS edge
  swipe does not track the finger, the screen snaps instead of following or
  springing back, or the session underneath moves. A pinch out on the screen
  lags the fingers, snaps instead of finishing or springing back, springs back
  from a wide spread on a phone (the lift-off slide read as a flick), or takes a
  one-finger scroll, a row tap or a selection in the search field; a way out
  other than the iOS edge swipe removes the screen without shrinking it back.
- A Prompts row tap closes the screen with the transcript elsewhere, or does
  nothing; back or ⌘[ leaves the page instead of closing the screen; closing moves
  the transcript; the covered transcript takes focus or is read out.
- An opening of the Prompts screen reports no `transcript_prompts_opened` or
  the wrong `entry`.

## Known Limitations

- The rule reads loaded messages only. About 2% of ordinary Claude prompts that
  follow a completed tool step join the previous turn, and a boundary can move
  once, at the old edge, when an older page loads.
- ACP follow-ups open a new turn (stop-and-send). Live, one sent after a running
  tool can move to a new turn once idle finalization marks that tool failed.
  Claude's live-only `isMeta` bubbles can open a bogus turn live.
- Claude sessions imported before the queued-command fix regain dropped
  follow-ups only on their next re-import.
- A far target is reached one cache-extended viewport a frame, so a long hold
  shows brief motion.
- Two-finger touch scrolling no longer scrolls the transcript; it pinches. A
  trackpad pinch that starts while following can flash the jump-to-latest
  pill for a frame, as the trackpad peek does. A trackpad gesture that neither
  pinches nor scrolls leaves the list detached, as before pinch existed.
- The compacted prompt's three lines are approximate: Markdown blocks have
  their own metrics, so the last visible line can be part of a block rather
  than a whole line of text. The pinned bubble shows its controls — a code
  block's copy icon, an underlined link, an open-image button — as the bubble
  does, but a press on them glides to the prompt. Only a message's last ten
  thousand or so characters are rendered there, from the start of a line and
  with a code fence the cut lands in opened again, far more than three lines
  can show, so a construct that needs an earlier line — a link reference
  definition, or a list or quote the cut lands in — reads differently in the
  pinned row only. A message that long always pins its end, even on a screen
  tall enough to show it whole, and where its bubble renders short — mostly a
  collapsed code block, say — the pinned end can differ from the bubble's at
  the takeover. Whether a message pins its start or its end depends on whether
  it fits below the pin line, so a keyboard or window-height change can switch
  a pinned message between the two. While a long message's end is pinned, its
  own bubble above the pin line stays in the tree, so screen readers still find
  it. The semantics label is read
  from the message's first few thousand characters, so a screen reader hears
  the start of a pasted document and reaches the rest by activating the
  button. A prompt that renders no words at all — nothing but a horizontal rule,
  say — is read out as its own short source rather than left unlabelled.
  While pinned, the prompt covers the top of the rows beneath it. A glide to
  a prompt far above aims at an estimate that sharpens as rows are built, so
  its speed can bend on the way; it still lands exactly.
- An unloaded prompt is searched by its preview only. A bridge released before
  the prompt index lists and searches only what the transcript has loaded, and
  "Load earlier prompts" pages back one transcript page at a time. The "Update
  the bridge" notice for an unloaded tap has no link to update instructions. An
  older bridge sends
  no user message count, so its rows carry no numbers. Loading through a far
  prompt decodes the response off the UI isolate, but the relay envelope of a
  whole-session response still decodes on it (about 170 ms on a Mac for a
  10,000-message session). On Grok, Antigravity,
  Copilot, Cursor, Hermes and OMP a prompt read back from the harness's own
  history carries no time.

## Sources

- The turn rule shared with the bridge:
  `shared/sesori_shared/lib/src/transcript/prompt_turns.dart` and
  `shared/sesori_shared/test/transcript/prompt_turns_test.dart`
- `client/module_core/lib/src/cubits/session_detail/transcript_turns.dart` and
  `client/module_core/test/cubits/session_detail/transcript_turns_test.dart`
- `session_detail_message_list.dart`,
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
- The user message count: `countUserMessagesBefore` in
  `bridge/app/lib/src/api/database/history/chat_history_dao.dart`,
  `bridge/app/lib/src/repositories/chat_history_repository.dart` and
  `bridge/app/test/bridge/services/chat_history_pagination_test.dart`
- The ACP prompt stamp: `localUserMessageTime` in
  `bridge/sesori_plugin_acp/lib/src/acp_event_mapper.dart` and
  `bridge/sesori_plugin_acp/test/acp_event_mapper_test.dart`
- The prompt index and load-through: `transcript_prompt_list.dart` and
  `session_detail_cubit.dart` under
  `client/module_core/lib/src/cubits/session_detail/`,
  `client/module_core/lib/src/repositories/session_repository.dart`,
  `client/module_core/lib/src/api/client/relay_http_client.dart`, and their
  tests
- `.plan/active/turn-navigation/PLAN.md` and
  `.plan/active/transcript-history/PLAN.md`
