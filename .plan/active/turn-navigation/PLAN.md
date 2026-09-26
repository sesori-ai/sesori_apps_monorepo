# Turn Navigation: A Prompts Screen And Sticky Prompts

## Status

- **Plan slug:** `turn-navigation`
- **Created:** 2026-09-26
- **Revised:** 2026-09-26, after the shipped in-place fold was rejected on a
  real device. The fold is being removed and replaced by a separate Prompts
  screen. Steps 1–8 have merged and keep their published titles and numbers;
  the series total is now 18. See
  [Revision 2026-09-26](#revision-2026-09-26-the-fold-becomes-a-prompts-screen)
  and [Superseded Steps](#superseded-steps).
- **Origin:** visual-hierarchy step 37 ("turn navigation: discussion and
  prototypes"). That step was left out of the series and "becomes its own plan
  once the user picks a direction" (`.plan/completed/visual-hierarchy/TRACKER.md`).
  The user picked the direction on 2026-09-25, so this is that plan. Every PR,
  including this first one, uses the `turn-navigation` slug.
- **Series:** eighteen PRs in one phase. The titles are fixed in
  [TRACKER](TRACKER.md#fixed-pr-titles). Later phases are rough intent only.
- **Sources:**
  - The user's review on 2026-09-25 of three local pages:
    - `/tmp/sesori-ux/turn-navigation-3/index.html`, round 3 and the chosen
      one: R5 rows on both shells, the D2 desktop outline;
    - `/tmp/sesori-ux/turn-navigation-2/index.html`, the pinch mechanics;
    - `/tmp/sesori-ux/turn-navigation/index.html`, round 1.

    The pages stay local. The copy this plan needs is recorded under
    [Approved Copy](#approved-copy).
  - Throwaway Flutter spikes (never committed) that supply the gesture and
    sticky evidence below.
  - Three review rounds with the user on 2026-09-26 that settled the Prompts
    screen after the fold was rejected. Its decisions are D24–D31.
  - A fourth round the same day, which settled prompt times and list order:
    D38 and D39.

## Goal

In a long session it is hard to find your own prompts. The goals:

- A pinch opens a separate Prompts screen: a dense, numbered, searchable list
  of your own prompts. Tapping one returns to the transcript at that prompt.
- The prompt of the turn you are reading stays pinned at the top of the
  transcript.

The transcript itself never changes shape. It does not fold, relayout or move.

The client works on the loaded messages. Two bridge changes serve it: an additive
count on the paged-messages response, so prompt numbers can be absolute (D29),
and keeping the ACP prompt instant the bridge already computes and currently
throws away, so the six ACP harnesses get times for the prompts Sesori itself
sent (D38).

## Revision 2026-09-26: The Fold Becomes A Prompts Screen

Steps 4–7 shipped D1's in-place fold: a pinch folded every turn down to its
prompt plus one line, in place, and pinching out unfolded it. The user tried it
on a device and rejected it. In their words the transcript "jumps weirdly",
scrolling gets glitchy, and pinching back out "feels worst" — "definitely
feeling very, very bad".

The cause is structural, not a tuning problem: folding replaces almost every
row of a reversed lazy list, so the list re-estimates extents while a gesture
is still running, and place-keeping then has to chase a layout that is still
settling. No threshold or animation fixes that.

So the fold is removed and the same pinch opens a separate screen instead. The
transcript underneath is untouched: no rows change, no extents are re-estimated,
nothing scrolls. Everything the fold needed in order to keep the reader's place
during a relayout stops being needed.

What survives from steps 2–8:

- the turn model (step 2) — the Prompts screen and the sticky prompt both need
  it;
- the Claude queued-command history fix (step 3) — follow-ups must exist to be
  listed;
- the row registry, `_spanOf` and the convergent `_holdRow`/anchor search
  (step 5) — they now serve the sticky prompt and returning from the Prompts
  screen instead of the fold;
- the pinch recognizer (step 7) — repointed, and narrowed to the pinch-in half;
- the sticky pinned prompt (step 8) — kept unchanged in behaviour, minus its
  "only while unfolded" condition.

What dies: the fold state, the folded stub rows, the fold buttons, the desktop
fold shortcuts, the fold analytics event and their copy, tests and documented
behaviour. See [Architecture 9](#9-removing-the-in-place-fold-step-14).

## Current Behavior

The first three subsections were read at `origin/main` 420f70aa89 on 2026-09-26,
before steps 2–8 merged. They describe the transcript this plan started from and
are still accurate except where steps 2–8 changed it, which
[Architecture](#architecture) records. The last subsection was read at
`origin/main` 264087e172 on 2026-09-26, for this revision.

### The transcript list

`SessionDetailMessageList`
(`client/module_app_ui/lib/src/features/session_detail/widgets/session_detail_message_list.dart`,
845 lines) is shared by phone and desktop.

- It is a reversed, lazy `ListView.builder`: index 0 is the newest row, and
  offset 0 is the bottom edge. The wrappers, from outside in:
  1. `FollowDetachScrollable`. Its `Listener` detaches on pointer scroll and on
     trackpad pan-zoom start. It also shows the jump-to-latest pill.
  2. A `NotificationListener`. It prefetches an older page within 600 px of the
     oldest edge (`_kOlderPagePrefetchExtent`).
  3. `PregoHorizontalDragGestureDetector`. This is the leftward timestamp peek,
     by touch drag or trackpad pan.
- Row ids:
  - A message row uses the message id. A prompt row uses
    `session-detail-prompt-<promptId>`.
  - The synthetic retry-error and working rows come next, then transient prompt
    rows.
  - Each row is a `KeyedSubtree(ValueKey(rowId))`, found through
    `findChildIndexCallback`.
  - `_knownRowIds` decides which agent rows ease in.
- Scrolling away detaches the list. While detached, a `_DetachedSnapshot`
  freezes the rendered messages, and only older-page prefixes merge in.
  Reattaching clears the snapshot.
- The peek keeps the follow state by recording `_revealStartedFollowing` on
  drag-down, before the outer `Listener` detaches. It calls
  `ScrollFollowTracker.suppressDetach()` only when the list was following,
  because `suppressDetach()` re-attaches a detached list.
- `TranscriptBuilder` (`module_core`, pure) runs on every build over the
  rendered messages. It groups tool steps into `TranscriptGroupBlock`s that
  carry a `TranscriptSummary(counts, failedCount)`.
  - Any non-assistant message ends a group, so **a step group never crosses a
    user message**.
  - Automation is a `MessageAssistant` whose sender is not `agent`. It renders
    in its own frame (`SystemMessageCard`) and never joins a group.
  - Cancelled steps count as finished there.
- `hasRenderableUserContent` (`session_detail_resolvers.dart`) hides user
  messages that have no text and no known file.

### History, reloads and the message model

- History loads newest first, 50 messages per page, with a `seq` cursor
  (`POST /session/messages`). Older pages merge by id and are prepended.
- A reload replaces the list, and the cubit bumps `_transcriptGeneration`. A
  silent refresh reconciles the list and drops paged history.
- No revision or "replaced" signal reaches clients.
- Message ids are not stable across a bridge re-import for every harness:
  - Claude's are stable.
  - Codex falls back to positional ids.
  - Pi derives ids from timestamp and ordinal.
  - ACP replays use positional `-h<n>` ids, while the live path uses
    `-t<turn>-…` ids.
- The neutral message types:
  - `MessageUser(promptId?)`;
  - `MessageAssistant(sender: agent | system | unknown)`;
  - `MessageError(errorName, errorMessage)`;
  - `MessageTime(created, completed?)`, which is nullable on every message.
- There is no steer flag, finish reason or abort marker. Claude leaves
  `completed` null.
- When a session goes idle, the bridge's `finalizeOpenToolParts`
  (`chat_history_repository.dart:372`) rewrites stranded pending or running
  tools to `error`.

### Shells

- **Desktop.**
  - `SessionDetailPageChrome(headerBuilder, maxContentWidth: 760)`. The loaded
    view centres a 760 px column (`horizontalInset`), and the composer uses the
    same insets.
  - The toolbar holds Changes (`desktop-session-page-changes`), then More.
  - `_MarkUnreadShortcut` is the page's only shortcut. There is no ⌘−/⌘=
    binding and no platform menu bar.
- **Phone.** The `PregoGlassScaffold` bar holds Close (split view), Changes,
  More and the busy indicator.
- **Turns.** No turn concept exists anywhere, and nothing is stored per turn.

### What happens to a message sent while a turn runs

| Harness | Delivery | Where it lands | After a history re-import |
|---|---|---|---|
| Claude Code | Written with `"priority": "next"` (`claude_stream_client.dart:172`). The CLI takes it at the next tool boundary. | A user message, from the `--replay-user-messages` echo (`mapPromptReplay`), after a tool step. | **Lost** when Claude recorded it only as a `queued_command` attachment, which `claude_history_mapper.dart:176-180` drops. Step 3 fixes this. |
| Codex | `turn/start` while busy steers the active turn (`codex_plugin_impl.dart:1327`). | A user message inside the running turn. | Kept (local samples). |
| Pi | `streamingBehavior: "steer"`. | A user message inside the running turn. | Kept (local samples). |
| OpenCode | Sent to the server at once. | A user message inside the running turn. | Kept (local samples). |
| ACP family: Antigravity, Copilot, Cursor, DeepSeek, Grok, Hermes, OMP | Stop-and-send: the bridge cancels the turn, then sends (`AcpPlugin.cancelsActiveTurnForQueuedInput`, `acp_plugin.dart:261`). | A user message after the cancelled turn. | Kept, as an ordinary prompt. |

Automation:

- **Pi.** `custom` messages are automation, live and after history load.
- **Claude.**
  - Peer messages and unabsorbed task notifications are automation, live and
    after history load. That holds only when they are user records.
  - When Claude recorded them as `queued_command` attachments, they are lost on
    re-import.
  - Local store sample of messages missing after re-import:

    | Message kind | Missing / total |
    |---|---|
    | Prompt follow-ups | 19 / 71 |
    | Task notifications | 37 / 59 |
    | Peer messages | 18 / 256 |

    The existing capability row overstates this; step 3 corrects it.
- **OpenCode.** Task-notification injection is unverified. The capability row
  already says so.
- **Codex and ACP.** No automation is known.

### What the 2026-09-26 revision had to check (verified in code that day)

- **Routing and cubit scope.** The client uses `go_router` with typed routes
  (`client/module_core/lib/src/routing/app_routes.dart`), one router per shell
  (`client/app/lib/core/routing/app_router.dart`,
  `client/desktop/lib/core/routing/desktop_router.dart`), reached only through
  `context.pushRoute`/`goRoute` or the desktop's private `_pushRoute`.
  `SessionDetailCubit` is created by each shell's session screen
  (`client/app/lib/features/session_detail/session_detail_screen.dart:28-47`),
  so a sibling pushed route — the Changes screen is the precedent — does **not**
  see it. This decides the Prompts screen's shape; see
  [Architecture 10](#10-the-prompts-screen-steps-10-and-11).
- **Pinned headers.** No sticky-header package is a dependency. The one
  precedent is `DiffFileHeaderDelegate`
  (`client/module_app_ui/lib/src/features/session_diffs/widgets/diff_file_header_delegate.dart`)
  used as `SliverMainAxisGroup` + `SliverPersistentHeader(pinned: true)` in
  `session_diffs_view.dart:189-208`. A new non-reversed list may use it; the
  transcript may not, which is why step 8 needed an overlay.
- **Search field.** `ListSearchField`
  (`client/module_app_ui/lib/src/widgets/list_search_field.dart`, 69 lines,
  module-internal) already has the clear button and reports every edit with no
  debounce, "the list owns the query and narrows what it has already loaded" —
  exactly D30. Used by the session and project lists.
- **Spine rows.** Nothing reusable exists: no timeline, step-indicator or
  vertical-rail widget anywhere in the client.
- **Timestamp formatting.** `formatMessageTimestamp`
  (`client/module_app_ui/lib/src/extensions/build_context_x.dart:103-114`) is
  the formatter the transcript's timestamp peek uses; day headers stay
  consistent with it.
- **Prompt times per harness.** Grok, Antigravity, Copilot, Cursor, Hermes and
  OMP carry no prompt time on either the live or the re-import path, and
  DeepSeek, Claude, Codex, Pi and OpenCode all do. The six share
  `sesori_plugin_acp`, whose `localUserMessageTime`
  (`bridge/sesori_plugin_acp/lib/src/acp_event_mapper.dart:105`) and
  `messageTimeForNotification` (`:102`) default to `null`; only DeepSeek
  overrides them (`deepseek_event_mapper.dart:24-26`). Copilot, Hermes and OMP
  use `AcpEventMapper` itself; Cursor, Grok and Antigravity subclass it and
  override neither hook. `docs/HARNESS_CAPABILITIES.md`'s "Live timers" section
  already records exactly this split.
- **The bridge computes a prompt instant and throws it away.** The only clock-fed
  `MessageTime` in the bridge today is Claude's synthetic slash-command bubble
  (`bridge/sesori_plugin_claude/lib/src/claude_plugin_impl.dart:733-745`). The ACP
  plugin already computes an instant for every prompt it sends and hands it to
  `localUserMessageTime`, which returns `null` and discards it:
  `mapSentPrompt` (`acp_event_mapper.dart:389`) is called from
  `_markTurnDispatched` (`acp_plugin.dart:1649`) with
  `createdAtMs: DateTime.now().millisecondsSinceEpoch`, and `mapInitialPrompt`
  (`:373`) is called from session creation (`acp_plugin.dart:1064`) with the
  session's own `createdAt`. D38 keeps that instant instead of discarding it.
- **History replay is a different path, and it has no time to keep.**
  `AcpSessionLoader` builds replayed messages from `session/load` and takes its
  times from `AcpReplayMessageTimeResolver`
  (`bridge/sesori_plugin_acp/lib/src/acp_session_loader.dart:11`, `:54`, `:93`),
  which is null for all six harnesses because their protocol carries no message
  time. So a prompt read back from the harness's own history has no instant the
  bridge ever observed, and never will. This is why D38 leaves those prompts
  undated rather than inventing something.
- **The paged-messages contract.** `POST /session/messages`
  (`bridge/app/lib/src/routing/get_session_messages_handler.dart`) answers
  `MessageWithPartsResponse(messages, nextCursor, replayedPromptDefaults,
  awaitingHarnessSync)` from
  `shared/sesori_shared/lib/src/models/sesori/message_with_parts.dart:12-34`,
  shared verbatim by bridge and client. `history_messages`
  (`bridge/app/lib/src/api/database/history/tables/history_messages_table.dart`)
  has `sessionId`, `messageId`, `seq`, `infoJson`, `updatedAt` and **no role
  column**; the role lives inside `infoJson`. No existing field carries a count,
  offset or absolute position: `nextCursor` is the page's oldest `seq`, counts
  every role, and is null on the last page. See
  [Architecture 12](#12-absolute-prompt-numbers-step-15).

## Decisions

User decisions of 2026-09-25, from the review of round 3:

- **D1 R5 chat-native folded turns. SUPERSEDED on 2026-09-26 by D24.** It
  shipped in steps 4–7 and was rejected on a device. Kept here because steps
  4–7 are published history and step 14 removes them.
  - The prompt bubble stays exactly as today.
  - The rest of the turn folds into one line: step count, duration, and the
    first line of the final answer, or a quiet state line where the metadata
    supports one.
  - Pinch in folds every turn and pinch out unfolds them. The turn being read
    stays in place.
  - Ship a lazy first version and iterate.
- **D2 Sticky prompts.** While you read a turn, its opening prompt sticks to
  the top of the transcript.
- **D3 Automation never opens a turn and is never a sticky header.** It joins
  the current turn, using the client's existing classification (sender not
  `agent`). Automation before the first prompt forms a preamble with no header.
- **D4 Follow-ups sent while a turn runs do not open a turn.** Only the opening
  prompt is the sticky header.
- **D5 Turns are derived, never stored.**
  - They are computed deterministically from the client's message list, with no
    stored turn state.
  - Follow-up and automation signals must survive history mapping for every
    harness. Where they do not, the plan fixes the plugin (step 3) or records
    the gap in `docs/HARNESS_CAPABILITIES.md`.
  - A later bridge turn index (F1) must never serve stale boundaries; see Later
    Phases.
- **D6 Desktop D2. PARTLY SUPERSEDED on 2026-09-26.** Its dense R6 index became
  the Prompts screen (D24), which desktop opens from its toolbar and by trackpad
  pinch. The *always-visible* 240 px index pane is deferred to
  [Later Phases](#later-phases-rough-intent-only); see Open Questions. Sticky
  prompts stand.
- **D7 Deck mode** (turn by turn) is a later phase.
- **D8 Phase 1 is client-only, over loaded turns. NARROWED on 2026-09-26 by
  D29.** Everything stays client-only except one additive count on the
  paged-messages response, which absolute numbering cannot be derived without.
  F1 (turn index) and F2 (fetch one turn) remain later phases.

### User decisions of 2026-09-26 (the Prompts screen)

Settled over three review rounds after the device rejection. They are decided;
this plan implements them and does not reopen them.

- **D24 The in-place fold is removed; a pinch opens a separate Prompts screen.**
  - The same pinch gesture opens it. The transcript underneath never folds,
    never relayouts and never moves.
  - A transition animation connects the two.
  - Everything that exists only to serve the in-place fold is removed with it.
- **D25 The list is deliberately unlike the chat.** No bubbles — bubble rows
  were reviewed and rejected for reading too much like the transcript.
  - Row shape "D4 spine": a dot on a vertical line, the prompt text, the time
    on the right.
  - One line per prompt, ellipsised.
  - Sticky day headers.
- **D26 Follow-up prompts appear too, as child rows.** A follow-up absorbed into
  a turn is nested under that turn: more left padding and a distinct, subtler
  spine indicator, so it reads as a child of the turn rather than a peer. The
  user's words: "maybe a slightly different indicator for them or even slightly
  more left padding/etc for the spine to paint more of a 'child' perspective."
- **D27 Tapping a row returns to the transcript at that prompt's place.** A
  follow-up row returns to that follow-up's own message where the transcript can
  address it. It can: the transcript's anchor search is keyed on row ids, and a
  rendered message row's id is its message id, so no fallback to the turn opener
  is needed. See [Architecture 11](#11-returning-to-the-transcript-step-11).
- **D28 Phone entry: a button in the session app bar,** besides the pinch. It
  will be the only visible button left in that bar. The separate in-flight
  `phone-appbar-declutter` branch removes the busy spinner and moves Changes
  into the overflow menu; this plan starts from that bar and does not redo it.
- **D29 Row numbers are absolute and stable, from a new bridge field.**
  - Numbers must never renumber when an older page loads.
  - A new field on the paged-messages response carries how many of the user's
    own messages precede that page.
  - The number counts messages the user sent. Follow-ups have their own rows, so
    the visible numbering has no gaps between them.
  - An older bridge sends no such field: rows then show **no number** and
    everything else works. No shim, and no client-side numbering fallback.
- **D30 A search field replaces the header line; the field *is* the header.**
  - The total prompt count moves out of the top to the end of the list.
  - Search filters only what the app has loaded, and says so: a row at the end
    states the match count within the loaded range and offers "Load earlier
    prompts" to extend it. **Placement adjusted by D39:** the match count stays at
    the end, and "Load earlier prompts" moves to the top, which is the older end of
    a chronological list.
  - No bridge search route and no search index.
  - A matching row **grows** to show the match in context underneath the
    prompt's opening words, with the match highlighted, so the reason for the
    match is visible even when it falls past the one-line cut.
- **D31 No invented times. PARTLY SUPERSEDED on 2026-09-26 by D38.** Nothing is
  invented, on either side of the wire: that half stands and is a guardrail. Its
  other half — "the bridge does not stamp its own time", so the six harnesses
  (Grok, Antigravity, Copilot, Cursor, Hermes, OMP) show no time column and no
  day headers — is replaced by D38, which keeps an instant the bridge genuinely
  observed.

### User decisions of 2026-09-26, round 4 (times and order)

- **D38 The bridge stamps what it can and leaves the rest undated.** Chosen over
  "no times on six harnesses" after the plan found that the bridge already knows
  when it sent each prompt and discards it.
  - For a prompt **Sesori sent**, the ACP plugin keeps the instant it already
    computes, so Grok, Antigravity, Copilot, Cursor, Hermes and OMP get prompt
    times, day headers and the "Working…" timer.
  - For a prompt **read back from the harness's own history** — anything from
    before Sesori attached, or a session started outside Sesori — there is no
    such instant and never will be. Those prompts stay **undated**.
  - So a long session on one of those harnesses shows times on its recent rows
    and an undated group for its older ones. **The user accepted this asymmetry
    knowingly**; it is expected behavior, not a bug and not a gap to close.
  - Still nothing invented: no clock is started on the client, no time is guessed
    from a neighbouring message, and no undated prompt is given a placeholder.
  - Implemented by step 15; see
    [Architecture 16](#16-the-acp-prompt-accept-stamp-step-15).
- **D39 The list keeps the transcript's order, and opens where you were.**
  Chosen over newest-first.
  - **Chronological, exactly like the transcript**: up is earlier, down is later,
    the newest prompt last. A follow-up child therefore sits below its parent,
    which is how it reads in the transcript too.
  - The screen **opens anchored on the prompt you were nearest**, highlighted, so
    the reading position is never lost.
  - Why: the pinch must read as zooming out of what you were reading, not as
    jumping to another screen. A reversed list would make the same gesture feel
    like a different place.
  - Supersedes D34. Its consequences — the undated group at the top, "Load
    earlier prompts" at the top, numbers ascending downward — are in
    [Architecture 10](#10-the-prompts-screen-steps-10-and-11) and
    [Architecture 15](#15-search-step-16).

Defaults this plan adopts for the Prompts screen. **Each is a default the user
may override:**

- **D32 Analytics: `transcript_turns_folded` is replaced.** The fold event's
  last emitter disappears in step 14, so the event goes with it. One
  account-linked adoption event takes its place,
  `transcript_prompts_opened`, with one closed `entry` parameter
  (`session_bar` or `pinch`). It answers the same product question the fold
  event was asked, plus the one the rejection raised: is the pinch discovered
  at all, or does everyone use the button? See [Analytics](#analytics).
- **D33 The Prompts screen is one shared screen in `module_app_ui`, opened by
  each shell.** Desktop opens it from its toolbar and by trackpad pinch, so the
  feature reaches both shells. The always-visible desktop index pane of D6/D18
  is deferred; the screen covers the same need and the pane's extra value on top
  of it is unproven. See Open Questions.
- **D34 Newest prompt first, at the top. SUPERSEDED on 2026-09-26 by D39.** It
  was derived from D30's "at the end of the list" placement rather than decided,
  and the user chose the transcript's order instead. D30's counts stay at the end
  of the list, which is now the bottom; "Load earlier prompts" moves to the top,
  because in chronological order the top is the older boundary it extends.
- **D35 The transition is one focal-point page transition, not a per-row hero.**
  The Prompts screen scales and fades in from the pinch's focal point, or from
  the bar button, over a dimmed transcript, and reverses on the way out.
  Reduced motion gets a plain fade. No shared-element flight of N rows.
- **D36 Numbering base: one nullable int in the loaded state.** The client keeps
  the field from the oldest loaded page and numbers every user message from it.
  Non-renderable user messages still consume a number, so a number can be
  skipped where a message exists but the transcript hides it. Accepted; see
  [Architecture 12](#12-absolute-prompt-numbers-step-15).
- **D37 The desktop fold shortcuts are deleted with the fold, and no shortcut
  replaces them in this phase.** ⌘− and ⌘= mean zoom, not "open a list". A
  Prompts shortcut is an Open Question rather than an invention.

Defaults adopted in the first revision. **Each is a default the user may
override:**

- **D9 One fold state for the whole transcript. SUPERSEDED on 2026-09-26 by
  D24.** Removed in step 14.
  - Tapping a folded turn unfolds every turn and keeps that turn in place. So
    does clicking an index line while folded.
  - The mock's per-turn tap-to-fold is deferred.
  - Why: a global state has no per-id entries to strand when a re-sync changes
    ids, and it is the smallest state.
- **D10 A fold button in the bar on both shells. SUPERSEDED on 2026-09-26 by
  D24 and D28.** The bar gains a Prompts button instead; the fold button and
  ⌘−/⌘= are removed in step 14 (D37).
  - The mocks show "Fold all (or pinch in)" on the phone and "Fold all" on
    desktop.
  - Desktop also gets ⌘− to fold and ⌘= to unfold (Ctrl on Windows and Linux),
    mirroring pinch in and pinch out as zoom out and zoom in. The desktop shell
    chooses these keys; shared code only binds what it is given.
  - The button is also the accessible, gesture-free path, so no custom
    semantics action is added.
- **D11 The turn rule ("rule A").** Messages are read in order, and only
  messages the list renders count. A renderable user message is handled as
  follows:
  - **It continues the current turn** when either:
    - the turn has no agent output yet; or
    - the latest agent output before it (automation skipped) ends in a tool or
      sub-agent step that is pending, running or completed.
  - **It opens a turn** when that output ends in text, reasoning, a
    `MessageError`, or a failed or cancelled step. It also opens a turn when it
    is the first message loaded.
  - Messages before the first opener form a headless leading segment.

  Evidence and refinement:
  - Measured read-only on local Sesori stores and Claude transcripts on
    2026-09-25. Only aggregate counts were kept.
  - Claude:
    - Its queued-prompt records served as ground truth.
    - The rule kept 98% of real follow-ups inside the running turn.
    - It grouped 2.3% of ordinary prompts as follow-ups.
  - Codex, Pi and OpenCode samples are consistent with the rule. The only
    Codex miss is a prompt sent two hours after a stopped turn.
  - Timestamps cannot help: Claude leaves `completed` null, and OMP sends no
    times.
  - The "no agent output yet" clause was added after the measurement. Step 2
    tests it.
- **D12 No "stopped" state in phase 1.**
  - The neutral model has no abort marker.
  - Cancelled steps come only from some plugins and also mean a stopped
    sub-task, so they do not imply a stopped turn.
  - Idle finalization turns a stopped turn's running tools into failed steps.
  - F1 can carry an authoritative outcome, because the bridge sees abort
    requests.
- **D13 Loaded turns only, labelled honestly. PARTLY SUPERSEDED on 2026-09-26.**
  - A partial oldest turn shows what is loaded and says so. Stands.
  - The "Load earlier turns" row becomes the Prompts screen's "Load earlier
    prompts" row (D30).
  - "Turn numbers wait for F1" is superseded by D29: absolute numbering arrives
    from one additive count on the paged-messages response, without F1.
- **D14 One analytics event**, `transcript_turns_folded`. **SUPERSEDED on
  2026-09-26 by D32**; `transcript_prompts_opened` replaces it (see
  [Analytics](#analytics)).
- **D15 The sticky prompt shows only while turns are unfolded. SIMPLIFIED on
  2026-09-26.** With no fold state the condition disappears; the prompt is
  always pinned while its opener is above the top edge. Clamped to three lines,
  and a tap scrolls its prompt to the top. Both stand.
- **D16 A running turn's stub shows "Running · step {n}". SUPERSEDED on
  2026-09-26 by D24**; the stub is removed in step 14. The "Working…" row's
  timer is step-timers' own behavior and is untouched.
- **D17 Follow-ups fold inside their turn. SUPERSEDED on 2026-09-26 by D26**;
  a follow-up now has its own child row on the Prompts screen.
- **D18 The desktop index shows only when the detail area is at least 1,000 px
  wide. DEFERRED on 2026-09-26 with D6's index pane.**

Planning decisions, from code evidence and the spikes:

- **D19 The sticky prompt is an overlay over the existing reversed lazy list.**
  It is not built from slivers. See [Architecture 6](#6-sticky-prompt-step-8).
- **D20 Pinch uses an eager two-pointer scale recognizer.** See
  [Architecture 5](#5-pinch-step-7). Stands; step 13 repoints it and narrows it
  to the pinch-in half.
- **D21 Place-keeping uses a registry of built rows and a convergent
  scroll-to-row helper.** Nothing positions rows by index arithmetic alone.
  Stands, and after step 14 it serves the sticky prompt and returning from the
  Prompts screen instead of the fold.
- **D22 The Claude `queued_command` replay fix is part of this plan.** Without
  it, a re-import moves Claude follow-ups and automation, so turn boundaries
  change after a re-import. The loss is also a user-visible history bug on its
  own.
- **D23 ACP stop-and-send is a harness gap, not a special case.** Client code
  stays harness-neutral, and `docs/HARNESS_CAPABILITIES.md` records that an ACP
  follow-up usually opens a new turn.

## Explicitly Excluded

Out of phase 1:

- Deck mode.
- F1, F2, and any wire or storage change other than D29's additive count. No
  database migration, no new column, no new route.
- Any in-place transcript fold, per-turn or global.
- The mock's alt+↑/↓ prompt stepping on desktop (see Open Questions).
- A keyboard shortcut for the Prompts screen (D37, see Open Questions).
- The always-visible desktop index pane (D6/D18, deferred).
- A bridge search route or search index; searching anything the client has not
  loaded.
- Any client-invented time, any placeholder for an undated prompt, and any
  attempt to give a time to a prompt read back from a harness's own history
  (D31, D38). The bridge stamp of D38 **is** in scope, in step 15.
- Any client-side numbering fallback for an older bridge (D29).
- A phone density switch.
- The "stopped" state.
- A steer flag on the wire, and timestamp heuristics.
- A non-reversed or sliver rebuild of the transcript list.
- A shared-element flight of prompt rows between the two surfaces (D35).
- Claude's live-only `isMeta` user bubbles (see Open Questions).
- The pre-existing gap-or-duplicate hazard when older pages merge after a
  re-import.

## Architecture

Dependencies keep the existing direction
(`Foundation -> API -> Repository -> Service -> Consumer`). The pure turn model
and the pure prompt list model sit in `module_core` next to `TranscriptBuilder`.
The shared widgets are in `module_app_ui`, including the phone bar and the
Prompts screen, both of which the shared `SessionDetailBody` builds.

After step 14 the desktop shell does one thing: it places its toolbar button
through the header builder. It no longer supplies shortcut activators (D37).

Client code uses neutral message fields only, with no harness names or backend
fields. New transcript widgets live in
`client/module_app_ui/lib/src/features/session_detail/widgets/` and the Prompts
screen in `client/module_app_ui/lib/src/features/session_prompts/`, one class per
file, as named below. The registry, the pending anchor and the scroll-to-row
helper stay private to the list state; the Prompts layer's open flag, transition
controller and jump controller stay private to `_SessionDetailBodyState`.

Sections 1–8 describe the first revision, with what survives, what is repointed
and what is removed marked at each heading. Sections 9–16 describe this revision.

### 1. Turn model in `module_core` (step 2)

- New file `client/module_core/lib/src/cubits/session_detail/transcript_turns.dart`,
  exported from `sesori_dart_core.dart` beside `transcript_builder.dart`. Like
  `TranscriptBuilder`, it is pure and stateless.
- Entry point: `const TranscriptTurnBuilder().build({required
  List<MessageWithParts> messages, required Transcript transcript, required
  bool isBusy, required bool hasOlderMessages})`.
  - It returns `TranscriptTurns(turns, turnIndexByMessageId)`, with turns
    oldest first.
  - `TranscriptTurns` also offers `promptTurnFor({required String
    openerMessageId})`.
- It runs on whatever the list renders: the live messages, or the detached
  snapshot. It reads only `hasRenderableUserContent`, message types, the sender
  and part statuses.
- A sealed `TranscriptTurn` carries the ids of the renderable messages it
  covers, in order, plus a summary. Its variants:
  - `TranscriptPromptTurn` adds:
    - `opener`, the opening `MessageWithParts`, so widgets read its text and
      time without another lookup;
    - `duration`, from the opener's `created` to the latest
      `completed ?? created` in the turn. It is null only when a needed time is
      missing.
  - `TranscriptPartialTurn` is the leading segment while `hasOlderMessages` is
    true: its opener may be on a page that has not loaded.
  - `TranscriptPreamble` is the leading segment once the whole history is
    loaded.

  The two segment variants carry no duration.
- The rule is D11.
  - The "ends in" test uses the last content part of the latest agent message
    that has one: non-empty text or reasoning, a tool, a sub-agent or a file.
  - A file, or a step whose status the client does not know, ends in an
    answer. A sub-agent without its own status counts as a step in progress.
  - It reads `ToolStatus` directly, because `TranscriptStepStatus` folds
    cancelled into finished.
  - "No agent output yet" keeps a follow-up only in a turn that has an opener.
    Before the first opener, a user message opens a turn unless the leading
    segment's agent output ends mid-step, so automation first never absorbs
    the first prompt.
- `TranscriptTurnSummary`, shared by every variant, holds:
  - `steps`: every step in the turn's step groups, running steps included.
  - `outcome`, a sealed type. A finished turn's outcome comes from how the
    turn ends, that is its last agent output or `MessageError`. Automation
    and follow-ups are skipped.
    - running: the newest turn while `isBusy`.
    - failed: the turn ends in a `MessageError`, carrying the first line of
      `errorMessage`, or in a failed tool or sub-agent step, with no excerpt.
    - done: every other ending. A turn that ends in text carries that text's
      first non-empty line. A turn that ends in a step, a file or no output
      carries none, so earlier narration is never shown as the answer. A
      cancelled last step is done without an excerpt, because there is no
      stopped state (D12).

    Streaming text is not read.
- Tests (`client/module_core/test/cubits/session_detail/transcript_turns_test.dart`):
  - every D11 branch;
  - automation between a tool step and a user message;
  - automation first, with and without older pages;
  - hidden user messages;
  - the summary fields, running and failed;
  - each ending: a final answer, narration then a step, a failed last step
    and a cancelled last step;
  - determinism: the same input gives the same output.

### 2. Claude follow-ups and automation survive history load (step 3)

Claude records a follow-up sent during a turn, a mid-turn peer message, and
some task notifications only as an `attachment` record of type
`queued_command`, with the command mode `prompt` or `task-notification` and an
origin such as `peer`. `_mapTranscriptRecord`
(`claude_transcript_catalog_repository.dart:307-397`) turns it into a
`ClaudeTranscriptContextRecord`, and the history mapper drops those.

The fix:

- Add a typed `ClaudeTranscriptQueuedCommandRecord` in
  `claude_transcript_record.dart`.
  - It is parsed before the generic context kinds.
  - Its fields come from the attachment on the generated DTO. Change the DTO
    source and regenerate it; never hand-edit the generated file.
- The history mapper maps the record at its transcript position through the
  paths the live frames already use:
  - `_content.userMessage` with the attachment's origin kind, so peer messages
    stay automation;
  - the existing task-notification path for that mode.
- The message id must equal the id the live path used, so that a re-import
  replaces the message instead of duplicating it.
  - Planned id: the attachment's `source_uuid` when present, else the record's
    `uuid`.
  - The step first confirms this against captured live frames from a current
    CLI (2.1.276 and later write `source_uuid`) and from an older CLI. It
    records the result in `steps/step-03.md`.
- Tests:
  - fixture lines for each mode, through the production parser and mapper;
  - a live/replay parity test: the same follow-up yields the same id, role,
    origin and relative position.
- Docs:
  - Correct the Claude automation row in `docs/HARNESS_CAPABILITIES.md`.
    Today's row says history load keeps peer attribution; that is true only
    for user records.
  - Add a short note to `docs/regression/session-history-and-recovery.md`.
- Already imported sessions regain these messages on their next re-import. No
  mapper version exists to force one, and the damage is a missing message in an
  old transcript. Accepted.

### 3. Fold state, folded rows and fold controls (steps 4 and 6)

**This section describes what steps 4 and 6 shipped. Step 14 removes all of it.**
It is kept because that code is on `main` and step 14's diff is defined against
it. Read it with [Architecture 9](#9-removing-the-in-place-fold-step-14).

Step 4 adds the state and the folded rows but no control, so nothing changes
for users until place-keeping (step 5) exists. Step 6 adds the controls.

- **Fold state (step 4).** It is session page state, so `SessionDetailCubit`
  owns it.
  - `SessionDetailLoaded` gains `required bool transcriptFolded`, with no
    default, so the compiler flags any construction site that would reset the
    fold by leaving it out.
  - The cubit keeps a private `_transcriptFolded` field and seeds every loaded
    state it builds with it in `_buildLoadedState`
    (`session_detail_cubit.dart:2939`), as it already does for
    `isUpdatingAutoContinuation`. A full reload emits
    `SessionDetailState.loading()` first, so the field carries the state
    across it. Copies of a loaded state keep it on their own. The two load
    failures that re-emit the state from before the load seed it again too,
    as they do `isUpdatingAutoContinuation`.
  - One intent, `setTranscriptFolded({required bool folded})`, is the single
    entry point for every control. It updates the field and, while loaded,
    emits the switched state. A request that changes nothing emits nothing.
    From step 6 it also reports the analytics event.
  - Widgets observe the state and dispatch the intent directly. The bars
    already read `SessionDetailCubit`. In step 4 `SessionDetailLoadedView`
    passes only `state.transcriptFolded` to `SessionDetailMessageList`. Step 5
    adds the intent as the list's fold callback, passed as `loadOlderMessages`
    is today, together with the stub tap that first calls it. No notifier or
    setter is forwarded, and `SessionDetailHeaderBuilder` is unchanged.
  - Only render-derived layout signals stay widget-local: the row registry,
    the pending anchor, and the sticky and current-turn values.
  - Each session page creates its own cubit, so the state resets with the page
    and another session starts unfolded.
- **Folded rows.** `SessionDetailMessageList` takes `transcriptFolded` and
  runs the turn model in `build`, after `TranscriptBuilder`. When folded:
  - each prompt turn renders its unchanged prompt row plus one stub row
    `session-detail-turn-<openerMessageId>`;
  - the leading segment renders as one stub row `session-detail-turn-head`;
  - the retry-error, working and transient prompt rows stay as they are.
- **Switching.**
  - A fold switch resets `_knownRowIds`, so stub rows never ease in as new
    rows.
  - The switch is instant. There is no fold animation, so reduced motion needs
    nothing extra.
- **`TranscriptTurnStub`** (new widget, `transcript_turn_stub.dart`):
  - renders the one line from [Approved Copy](#approved-copy) in the
    step-group summary style;
  - exposes the same text to semantics;
  - becomes tappable in step 5.

#### Fold controls (step 6)

The first step that exposes folding. Place-keeping (step 5) has already
merged, so the controls need no interim follow rule.

- **Fold buttons.** Each bar builds its own button in its own style. It reads
  `transcriptFolded` from the cubit state and calls `setTranscriptFolded`.
  - The phone: a `PregoButtonsIconGlass` in `SessionDetailBody`'s bar actions,
    shown on a loaded session.
  - The desktop: the shell's header builder places a toolbar button between
    Changes and More, keyed `desktop-session-page-fold`.
- **Desktop shortcuts.** Platform key policy stays in the shell.
  - `SessionDetailPageChrome` gains two required `SingleActivator` fields,
    `foldActivator` and `unfoldActivator`.
  - `DesktopSessionDetailScreen` builds them with the same platform check as
    `_MarkUnreadShortcut`: ⌘− and ⌘= on macOS, Ctrl elsewhere.
  - `SessionDetailBody` binds whatever activators the chrome supplies to the
    cubit's intent, through `CallbackShortcuts`.
  - `module_app_ui` gains no platform branch.
- **Analytics.** `transcript_turns_folded` lands here, with the first control
  (see [Analytics](#analytics)).
- **Docs.** Add a "Transcript turn boundaries" section to
  `docs/HARNESS_CAPABILITIES.md`:
  - ✅ for Claude, Codex, Pi and OpenCode (step 3 has already restored
    Claude's history parity);
  - 🚫 for the ACP family (stop-and-send, D23).

  The regression document starts here too; see
  [Regression Coverage](#regression-coverage).

### 4. Keeping the reader's turn in place (step 5)

**Mostly survives.** The registry, `_spanOf`, `_topEdgeTurn`, `_holdRow` and the convergent
`_stepAnchor` search all stay: the sticky prompt measures with them every frame,
and returning from the Prompts screen jumps with them. Only the fold-specific
entry points go in step 14 (`_holdTurn`, `_unfoldAt`, `_turnAt`, the `folded`
parameter of `_firstRowOf`, and the `didUpdateWidget` fold branch). The anchor
rules below stop applying to fold switches and apply to a jump instead.

- **Row registry.**
  - Each row is wrapped in a `TranscriptRowReporter`
    (`transcript_row_reporter.dart`, keyed like the row). It takes
    `onMount({required String rowId, required BuildContext context})` and
    `onUnmount({required String rowId})` callbacks from the list state.
  - The list keeps a private `Map<String, BuildContext>`.
  - Only built rows are present, so every scan is bounded by the viewport plus
    the cache extent. The spike used exactly this.
- **Top-edge turn.** Computed on demand: find the registered row that crosses
  the top edge (below `topInset`) and map it to its turn through the turn
  model.
- **Scroll-to-row helper.** Two private methods on the list state.
  - Nothing existing reaches an unbuilt row, so none is reused whole. The
    transcript has no search. Jump to latest (`animateToEdge` and
    `scheduleJumpToEdge()` on `ScrollFollowTracker`) only reaches the edge. The
    diffs view's reveal needs a built target, and no positioned-list package
    is a dependency. The helper reuses that reveal's two passes to settle.
  - The target row is built: measure it, then `jumpTo` the offset that puts its
    top at the requested distance below the top edge. Check once more on the
    next frame, because lazy extents are estimates. This is the two-pass
    precedent in `session_diffs_view.dart:364-381`.
  - The target row is not built: search toward it from the built rows. Each
    attempt resolves the target's index from its row id and compares it with
    the registered rows' indices to pick the direction. It jumps until the
    built row nearest the target has just scrolled out of the viewport on the
    side away from the target, then retries on the next frame. That row stays
    in the cache extent, and the list lays out rows in order from it, so the
    viewport fills with the rows after it and no jump passes over the target.
    No index-share estimate is used: rows vary too much in height for an index
    to predict an offset.
  - **Termination.** The rows between the nearest built row and the target
    are finite, bounded by the loaded rows. Every attempt builds at least the
    next of them, so their count strictly falls. It cannot grow meanwhile: older
    pages add rows only beyond the oldest row, and the detached snapshot
    freezes the newest end, where synthetic rows shift every index alike. So
    the search ends with the target built, or earlier when its row id
    disappears. It needs no attempt cap.
  - The helper needs no `detach()`. Each `jumpTo` ends a scroll, and the
    tracker then detaches the list, or follows again within its 20 px
    tolerance of the latest edge. A step that finds the list following ends
    the anchor, except the first, so a tap while following still anchors.
- **Anchor rules.**
  - The anchor is the top-edge turn (button or shortcut) or the tapped turn
    (stub), even while following (user decision in step 6). A switch that
    moves the list stops following until the reader scrolls back down.
  - If the anchor's opener row is on screen, it keeps its distance from the top
    edge.
  - If the reader is mid-turn (the opener is above the edge), the opener lands
    at the top edge.
- **Capture.** Every switch goes through the cubit's intent.
  - Triggers inside the list (stub tap here, then pinch and index click) set
    the pending anchor for their turn, then dispatch the intent through the
    list's callback. They do this only when the fold state actually changes.
    This step adds that callback, `onTranscriptFoldedChanged`, which
    `SessionDetailLoadedView` binds to `setTranscriptFolded`.
  - The list sees the switch in `didUpdateWidget`, when `transcriptFolded`
    changes. That runs before the new layout, so when no anchor is pending it
    captures the top-edge turn from the last frame's layout. That covers the
    buttons and the shortcuts of step 6.
  - A post-frame pass then restores the anchor.
- **Pending anchor.** One nullable target. It clears once its row settles, or
  when its row id disappears.
- **Stub tap.** Unfolds every turn and anchors on the tapped turn (D9).

### 5. Pinch (step 7)

**Repointed by step 13.** The recognizer, its arena behavior, its thresholds and
its follow-state rules all stand. Step 13 changes only what a pinch means and
narrows it to pinch-in; see
[Architecture 13](#13-pinch-opens-the-prompts-screen-step-13). The spike table
below is still the evidence for the recognizer choice.

- **The recognizer.**
  - `TranscriptPinchDetector` (`transcript_pinch_detector.dart`, in
    `module_app_ui`, because its thresholds are transcript-specific and it has
    one consumer) wraps the list inside `FollowDetachScrollable`.
  - It hosts a private `ScaleGestureRecognizer` subclass for touch and
    trackpad:
    - it has a very large touch slop, so a one-pointer pan never wins;
    - it accepts the arena as soon as a second touch pointer lands;
    - a trackpad pan-zoom uses the stock scale acceptance.
  - It applies the thresholds once per gesture and reports four events:
    - the first pointer's arrival;
    - pinch start;
    - a fold or unfold request, with its focal point;
    - pinch end.
  - The list state owns the follow-state and anchor logic.
- **Spike evidence** (Flutter test harness, iOS, Android and macOS variants,
  400×800 reversed list):

  | Scenario | Eager two-pointer recognizer | Plain `ScaleGestureRecognizer` |
  |---|---|---|
  | Pinch in, horizontal | Folds (scale 0.33), no scroll | Folds |
  | Pinch in, symmetric vertical | Folds (0.40), no scroll | Folds |
  | Pinch in, one finger still, vertical | Folds (0.50), no scroll | **Missed**: vertical drag wins |
  | Pinch out, diagonal | Unfolds (3.33) | Unfolds |
  | One-finger scroll, tap | Unaffected | Unaffected |
  | Trackpad pinch | Folds (0.60) | Folds |
  | Trackpad scroll | Unaffected | Unaffected |
  | Two-finger touch scroll | **Swallowed**: no scroll | Scrolls |

  The eager recognizer reports `onStart` twice for one gesture, so start
  handling must be idempotent.
- **Thresholds.** Fold once at a scale of 0.8 or less, and unfold once at 1.25
  or more. At most one switch per gesture.
- **Anchor.** The turn under the focal point, found through the registry, with
  the section 4 rules.
- **Follow state.**
  - A pinch that switches holds the turn under the fingers even while
    following, and stops following, like a button or shortcut switch (decision
    delegated by the user, 2026-09-26: an explicit gesture on a place wins over
    following). The rules below only keep a pinch that never reaches a
    threshold from changing the follow state.
  - A trackpad pinch begins with a pan-zoom start, which `FollowDetachScrollable`
    treats as a scroll and so detaches.
  - Following the peek's `_revealStartedFollowing` precedent, the list records
    `following` when the detector reports its first pointer. The detector sits
    inside the outer `Listener`, so this happens before that `Listener` runs.
  - Only if the list was following does it call `suppressDetach()` on pinch
    start and `releaseDetachSuppression()` at the end.
  - A pinch while reading history leaves the follow state alone.
  - A touch pinch never detaches, because the scrollable loses the arena.
- **Not exercised in the spike; checked in this step.** The one-finger peek,
  the trackpad horizontal peek, and a code block's one-finger horizontal
  scroll.
- A pinch switches through the same cubit intent, so the step 6 analytics
  event already covers it.

### 6. Sticky prompt (step 8)

- **Why an overlay.**
  - A spike with a native `PinnedHeaderSliver` in a reversed
    `CustomScrollView` shows the header pinning at the **bottom** edge.
  - With the header first, prompt 1 sits at 560–600 px of a 600 px viewport.
    With the header last, prompt 2 is not built at all.
  - A non-reversed list would change following and anchoring for every
    session. So the header is an overlay over the list the app already has.
- **Tracking.**
  - After each frame in which the list scrolled or laid out, a post-frame pass
    runs the step 5 top-edge computation. It publishes a
    `ValueNotifier<TranscriptStickyPosition?>`.
  - `TranscriptStickyPosition` (`transcript_sticky_position.dart`) is a small
    immutable value: `openerMessageId` and `pushOffset`.
  - The value is non-null only while the header shows, which needs three
    things: the transcript is unfolded; the top-edge turn is a prompt turn; and
    that turn's opener row is above the top edge or not built. Step 14 drops the
    first condition, leaving two.
  - The push offset is the next opener's top minus the header height, clamped
    to [−height, 0]. So the next prompt pushes the header out.
- **Spike results** (600 px viewport, 40 px header, one turn with 30 answer
  rows):

  | Scroll offset | Sticky header |
  |---|---|
  | 0, 40, 90 | Newest turn, offset 0 |
  | 100 | None: its prompt is visible |
  | 120 | Previous turn, offset −20: being pushed |
  | 150 | Previous turn, offset 0 |
  | 1,600 and 2,400 | The long turn, offset 0, with its prompt row not built |

- **The overlay.** `TranscriptStickyPromptOverlay`
  (`transcript_sticky_prompt_overlay.dart`).
  - Inputs: the `ValueListenable<TranscriptStickyPosition?>`, the
    `TranscriptTurns`, `topInset`, and the list's `onJumpToTurn`.
  - The list places it in a `Positioned` at `topInset` over the list. Only this
    overlay reads the sticky value.
  - It looks up the opener through `promptTurnFor`. It shows the opener's text
    clamped to three lines in the user bubble style, or the first attachment's
    name when there is no text.
  - While pinned, it is one labelled, actionable semantics node: a button
    labelled with the text it shows, with the hint from
    [Approved Copy](#approved-copy), whose tap action is the jump below. It is
    never excluded, because in a long turn the opener row is not built, and
    the overlay is then the only place the prompt and its jump exist.
  - A tap calls `onJumpToTurn`, which puts the opener at the top edge.
- **`onJumpToTurn`.** The overlay is its first caller, so this step adds the
  list's one private callback,
  `onJumpToTurn({required String openerMessageId})`, which step 9 also hands
  to the index.
  - Folded: unfold, anchored on that turn.
  - Unfolded: scroll the opener to the top edge.
- A one-frame lag is accepted. Move to a render object only if a device shows
  the lag.

### 7. Desktop index pane (old step 9)

**Dropped; never implemented.** This section planned an always-visible 240 px
`TranscriptTurnIndexPane` beside
the transcript, with asymmetric list and composer insets. It never shipped: no
`steps/step-09.md` was written and no code exists. The Prompts screen (D24, D33)
covers the same need on both shells, and an always-visible pane on top of it
would duplicate the list, re-introduce the asymmetric-inset layout work, and add
a second place to keep in sync with the scroll.

It is therefore dropped from the series and recorded under
[Later Phases](#later-phases-rough-intent-only) as an optional addition, with an
Open Question for the user, since it came from D6. Nothing else depends on it.

### 8. Re-sync, replacement and id changes (all steps)

Turns are recomputed from the rendered messages on every build, so no turn
state can go stale. What outlives a build is small and global:

- the fold flag, held by the cubit;
- one pending anchor;
- the sticky value (step 8) and the current top-edge opener id (step 11), both
  republished after every frame that scrolled or laid out;
- the registry, which mirrors the mounted rows.

How each kind of re-sync behaves:

- **Full reload.**
  - The list is torn down and rebuilt at the latest turn, following, as today.
  - The fold state survives in the cubit, which seeds the new loaded state
    with it.
  - The registry refills as rows mount. The sticky header and index recompute
    after the first frame.
- **Silent refresh or re-import with new ids.**
  - While following, the next build re-derives everything.
  - While detached, the snapshot holds until reattach, as today.
  - A pending anchor whose row id disappeared is dropped.
  - The index and sticky header follow the new rows after the next frame.
- **Older page.**
  - A partial leading segment joins its opener when that page arrives.
  - A first-loaded user message that followed an unloaded tool step becomes a
    follow-up. So boundaries can change once, only at the old edge.
- **F1 later.** See the revision rule under Later Phases.
- **The Prompts screen.** It reads the same loaded messages through the same
  cubit, so every re-sync above reaches it on the next build. It holds no copy
  of the list. Its own state is the query string, the scroll offset, the anchor id
  it opened with and the open flag. A row whose message id disappears simply stops
  being listed; if it was the row the reader tapped, the jump ends with no move
  (section 11), and if it was the anchored row, the highlight goes with it and
  nothing scrolls.

### 9. Removing the in-place fold (step 14)

The inventory below was read from the merged diffs of steps 4–7 on 2026-09-26.
Step 14 is almost entirely deletion. Every item is confirmed to have no
surviving reader once steps 11–13 have landed.

**Dies whole:**

- `transcript_turn_stub.dart` (88 lines) and its test (93 lines).
- The fold state: `_transcriptFolded` and `setTranscriptFolded` in
  `session_detail_cubit.dart`, `SessionDetailLoaded.transcriptFolded` and its
  regenerated freezed output, the two props on
  `session_detail_loaded_view.dart`, and the `"transcript fold"` cubit test
  group (~74 lines).
- `TranscriptTurnsFoldedEvent` and its `transcriptTurnsFolded` factory in
  `product_analytics_event.dart`, its line in
  `deferred_product_analytics_candidates.dart`, and its test lines. Step 11 has
  already added `transcript_prompts_opened` (D32), so no window exists in which
  the plan has no adoption signal.
- The fold controls: the phone bar button in `session_detail_body.dart`, the
  `foldActivator`/`unfoldActivator` fields on `SessionDetailPageChrome`, the
  `CallbackShortcuts` wrapper, the `_PageFocus` widget (38 lines, added only so
  ⌘−/⌘= beat the composer to focus, with no other consumer), and the desktop
  screen's `_foldShortcut`/`_unfoldShortcut` and toolbar button.
- The folded branches in `session_detail_message_list.dart`: the two props, the
  `didUpdateWidget` fold branch, the stub row ids and `_stubRowIdFor`, the
  folded branches of `_firstRowOf` and `rowTurns`, and the stub row in
  `_buildRow`.
- The fold-only place-keeping entry points: `_holdTurn`, `_unfoldAt`, and
  `_jumpToTurn`'s folded branch.
- ARB keys `transcriptTurnSteps`, `transcriptTurnRunning`,
  `transcriptTurnRunningStep`, `transcriptTurnFailed`,
  `transcriptTurnPartlyLoaded`, `transcriptTurnBeforeFirstPrompt`,
  `transcriptFoldAll`, `transcriptUnfoldAll`, with their generated mirrors.
- The fold and pinch-to-fold test regions in
  `session_detail_message_list_test.dart`, the desktop screen test's fold
  regions, and the body test's fold region. One paging test
  (`"folding a transcript shorter than the screen loads the older page"`) is
  rewritten rather than deleted, because paging is still the behavior under
  test.

**Explicitly kept, because a live reader depends on it:**

- `transcript_turns.dart` and its 543-line test. `TranscriptActivityBuilder`
  (step-timers, shipped) reads the newest turn's opener time for the "Working…"
  row, and the sticky prompt calls `promptTurnFor`.
- `transcript_row_reporter.dart`, `_rowContexts`, `_spanOf`, `_topEdgeTurn`,
  `_holdRow`, `_stepAnchor` and `_TurnAnchor`. The sticky prompt measures and
  jumps with them, and so does returning from the Prompts screen.
- ARB keys `transcriptTurnSeconds`, `transcriptTurnMinutes`,
  `transcriptTurnHours`: step-timers moved them into
  `transcript_duration_formatter.dart` for the "Working…" row. Their names are
  now misleading; renaming them is not this step's business.
- `ScrollFollowTracker.suppressDetach`/`releaseDetachSuppression`, shared with
  the timestamp peek.
- `desktopShortcutHint`/`desktopShortcutLabel`, shared with the sidebar.
- `docs/HARNESS_CAPABILITIES.md`'s "Transcript turn boundaries" section: it
  describes the turn rule, which survives.

**Turn-model members that lose their last reader.** `TranscriptPromptTurn.
duration`, `TranscriptTurnSummary.steps` and `TranscriptTurnOutcome` are read
only by the stub. The D25 row shows a dot, the
text and the time, so the Prompts screen does not revive them. Step 14 re-checks
this against the tree at implementation time — the active `step-timers` plan is
adding readers to the same model — and deletes whatever is genuinely dead,
with its tests. If that pushes the step past its target, the trim lands as
step 14.b rather than growing the removal PR.

**Documentation.** Step 14 strips the fold and pinch-to-fold behavior from
`docs/regression/transcript-turn-navigation.md` (the capability paragraph, the
fold/control/pinch/place-keeping bullets, the fold clauses of L2–L4, the
fold-specific failure signals and limitations, and the stale Sources entries)
rather than leaving tombstones, and removes the fold cross-reference sentences
step 6 added to `session-history-and-recovery.md` and
`tools-and-file-changes.md`. The `session-turns.md` cross-reference is about
turn boundaries and is re-worded, not removed.

### 10. The Prompts screen (steps 10 and 11)

#### Why it is a layer in the session page, not a pushed route

The Changes screen is a pushed `go_router` route, and that was the obvious
template. It does not work here:

- `SessionDetailCubit` is created by each shell's session screen, so a sibling
  pushed route does not see it.
- The screen must list exactly what the transcript has loaded, and "Load earlier
  prompts" (D30) must extend **the transcript's** loaded range, so that tapping
  any listed prompt can land on a row the transcript actually has (D27). A
  route with its own load path would list prompts the transcript cannot reach,
  which needs F2.
- Hoisting the cubit above both routes would either share it across sessions
  (the phone's session shell is per project) or mean a keyed-provider refactor
  of the session shells. That is a large change to working code for no user
  benefit.

So the Prompts screen is a full-bleed layer inside the session page, owned by
`_SessionDetailBodyState`:

- `SessionDetailBody` returns a `Stack`: today's `PregoGlassScaffold`, then the
  Prompts layer above it when open. The layer covers the bar and the composer,
  so it reads as a screen.
- Open state is one `bool` in `_SessionDetailBodyState`. It is deliberately not
  cubit state: only this widget reads it, and it must not survive the page.
- A `PopScope` closes the layer on the system back gesture before the route
  pops, so back means "back to the transcript".
- The transcript keeps its exact scroll offset, follow state and built rows
  while covered. This is what makes the guardrail true by construction rather
  than by tuning.
- Desktop uses the same `SessionDetailBody`, so the layer covers the desktop
  detail pane and nothing else. One implementation, both shells (D33).

Consequences, accepted: the screen has no URL and no deep link, and the route
analytics listener does not see it, which is why D32's event is an explicit
action event.

#### The prompt list model (step 10)

New pure file
`client/module_core/lib/src/cubits/session_detail/transcript_prompt_list.dart`,
exported beside `transcript_turns.dart`. Like the turn model it is stateless and
runs over what the list renders.

- Entry point: `const TranscriptPromptListBuilder().build({required
  List<MessageWithParts> messages, required TranscriptTurns turns, required
  int? userMessagesBefore})`.
  - It needs `messages`, not `turns` alone. `TranscriptTurn` carries its
    messages as **ids only** and only `TranscriptPromptTurn` carries a message
    object (`opener`), so a follow-up's text and time are not reachable through
    `turns`. `TranscriptTurnBuilder` also drops non-renderable user messages
    outright (`if (!message.hasRenderableUserContent) continue;`), so the
    messages D36 says still consume a number are not in `turns` either.
  - The caller is the same widget that already runs `TranscriptTurnBuilder` over
    the rendered messages, so `messages` is in hand and nothing new is fetched.
  - `turns` supplies only the classification: which user message opened a turn
    and, for a follow-up, which opener it belongs to
    (`turnIndexByMessageId` and each turn's ids).
- It returns `TranscriptPromptList(entries, hasTimes, promptCount)` with entries
  **oldest first, in the transcript's own order** (D39). The newest prompt is the
  last entry, and a follow-up sits directly below the opener it belongs to.
- A sealed `TranscriptPromptEntry` with two variants, so a child row cannot
  carry opener-only data and vice versa:
  - `TranscriptPromptOpener(messageId, text, createdAt?, dayKey?, number?)`;
  - `TranscriptPromptFollowUp(messageId, text, createdAt?, dayKey?, number?,
    openerMessageId)`.
- The builder walks `messages` **oldest first**, so numbering and the list order
  are the same single pass:
  - every role-`user` message advances the number, renderable or not;
  - a renderable one becomes an entry, a follow-up when `turns` puts it inside a
    turn it did not open and an opener otherwise;
  - nothing is reversed at the end: the walk order **is** the list order (D39).
  Messages before the first opener become openers, because before the first
  opener there is no turn to be a child of.
- `text` is the first non-empty line of the user message's text, or the first
  attachment's name, or the existing "Attachment" string — the same resolution
  the sticky overlay already does. Step 11 extracts that shared resolver rather
  than writing a third copy; `transcript_sticky_prompt_overlay.dart`'s `_textOf`
  is the second copy and step 8's review already noted it waits for a third
  caller.
- `hasTimes` is false only when **no** listed entry has a `createdAt`. Then the
  screen shows no time column and no day headers: that is a session nothing ever
  timed, such as an ACP session Sesori never sent a prompt to (D38).
- **A mixed list is normal, not an edge case** (D38). On the six ACP harnesses the
  prompts Sesori sent are timed and the ones read back from the harness's own
  history are not, so one session routinely holds both. `hasTimes` is then true,
  the time column exists, and an undated row simply leaves its time cell empty.
  Nothing is invented to fill it.
- **Grouping is decided in the model, never inferred by the view.** Every entry
  carries `dayKey`, the local calendar day of its `createdAt`:
  - a timed entry gets its own day;
  - an untimed follow-up inherits its opener's `dayKey`, because it belongs to
    that turn;
  - an untimed opener gets `null`.

  The view groups by `dayKey` in list order and puts the `null` group **first**,
  at the top, under the "No date" header (D38, D39). It sits at the top because
  undated prompts are the older ones — they were read back from the harness's own
  history, before Sesori was attached — and in chronological order older means
  higher. So a long session on one of the six harnesses reads: "No date" at the
  top, then the earliest dated day, down to "Today" at the bottom. That is the
  expected shape, not a defect.
- `number` is null unless `userMessagesBefore` is non-null
  ([Architecture 12](#12-absolute-prompt-numbers-step-15)).
- Tests: openers and follow-ups in order; a turn with several follow-ups; a
  hidden user message contributing no entry but advancing the number; messages
  before the first opener as openers; `hasTimes` false with no times and true
  with one; an untimed follow-up inheriting its opener's day and an untimed
  opener getting a null `dayKey`; **oldest-first ordering matching the message
  list, with each follow-up directly after its opener**; a mixed list of undated
  older entries and timed newer ones; determinism.

#### The screen (step 11)

New feature directory
`client/module_app_ui/lib/src/features/session_prompts/`, following the Changes
screen's shape but simpler: **one shared view and no chrome type.** The Changes
screen needs a `sealed SessionDiffsChrome` because the phone gives it a glass bar
and the desktop a header builder; the Prompts layer draws its own header on both
shells — its header is the search field (D30) — so no shell-specific variant
exists and none is added. Files:

- `session_prompts_view.dart` — the layer. A non-reversed `CustomScrollView`, in
  the transcript's order: earlier above, later below (D39). Top to bottom:
  - a pinned `SliverPersistentHeader` holding the search field (step 16 fills
    it; step 11 ships it as the title row so the header's height never changes
    under the reader);
  - from step 16, "Load earlier prompts" as the **first** scrolling sliver: it
    extends the older end of the list, which is now the top, so it must sit
    there or it points the wrong way (D39);
  - the `null`-`dayKey` group first when one exists, under the "No date" header
    (D38);
  - then one `SliverMainAxisGroup` per day, **oldest day first**, each with a
    pinned `SliverPersistentHeader` day header and a `SliverList` of rows,
    modelled on `session_diffs_view.dart:189-208` and `DiffFileHeaderDelegate`;
  - when `hasTimes` is false, one flat `SliverList` and no day headers;
  - a final sliver: the total prompt count (D30), and from step 16 the match
    count. D30's "end of the list" is the bottom, which is where both stay.
- `widgets/prompt_spine_row.dart` — the D4 spine row. A fixed-width leading
  column draws a 1 px vertical rail with a dot on it, then the number, then the
  one-line ellipsised text, then the time. A follow-up row indents the rail and
  draws the subtler child indicator (D26). An undated row leaves the time cell
  empty (D38). The row's height is **fixed** in the unsearched state — one clipped
  line plus fixed padding, from one shared `promptRowExtent(TextScaler)` helper —
  which is what lets the opening anchor below be computed arithmetically. No
  `CustomPainter`: a `Stack` of a 1 px `Container` and a small dot is enough, and
  nothing reusable exists to extend.
- `widgets/prompt_day_header.dart` and its `SliverPersistentHeaderDelegate`,
  with a fixed extent as `DiffFileHeaderDelegate` requires.
- Day grouping and the time column use `formatMessageTimestamp`'s conventions so
  the screen and the transcript's timestamp peek agree.

Entry points:

- **Phone.** A `PregoButtonsIconGlass` in `session_detail_body.dart`'s bar
  actions, on a loaded session. After `phone-appbar-declutter` it is the only
  visible bar button besides the overflow and the archive-flow close (D28). That
  branch currently has no committed change, so step 11 adds the button to the
  bar as it stands and does not depend on the declutter landing first.
- **Desktop.** The shell's header builder places a toolbar button, keyed
  `desktop-session-page-prompts`, where the fold button is today.
- **The seam the desktop button needs.** The fold button needed none, because it
  called `cubit.setTranscriptFolded` and the fold lived in the cubit. The Prompts
  open flag deliberately does not, so the shared typedef must carry the callback:
  `SessionDetailHeaderBuilder`
  (`session_detail_body.dart:21-31`, today `context`, `title`, `isBusy`,
  `onShowDiffs`, `session`) gains `required VoidCallback? onShowPrompts`,
  mirroring `onShowDiffs` exactly. `_SessionDetailBodyState` supplies it when it
  calls the builder; `DesktopSessionDetailScreen._buildToolbar` consumes it. Both
  change in step 11, in lockstep, as an internal contract with no external
  consumers.
- The phone button, the desktop button and (from step 13) the pinch all call the
  one open method on `_SessionDetailBodyState`.

Analytics: `transcript_prompts_opened` with `entry: session_bar` here, and
`entry: pinch` from step 13. See [Analytics](#analytics).

#### Opening anchored on the prompt you were reading (step 11)

D39's second half: the screen opens at the prompt you were nearest, highlighted,
so the pinch reads as zooming out of what you were reading. Three small pieces,
all reusing what already exists:

- **Which prompt.** The opener of the turn at the transcript's top edge — the same
  turn the sticky prompt names, so the highlighted row is the prompt the transcript
  was showing above it. `_topEdgeTurn` is already computed in the post-frame pass
  that publishes the sticky value ([Architecture 6](#6-sticky-prompt-step-8)),
  after every frame that scrolled or laid out.
- **The seam.** `_SessionDetailBodyState` owns a `ValueNotifier<String?>` holding
  that opener id, passed through `SessionDetailLoadedView` to the list, which
  **writes** it in that same post-frame pass. It mirrors `TranscriptJumpNotifier`
  in the opposite direction: one nullable value, one writer, one reader, read by
  the body when it opens the layer. All three entry points go through the one open
  method, so all three anchor alike. The focal point keeps only its transition job
  (D35), so `_turnAt` still loses its last caller in step 13.
- **Where the list starts.** The view's `ScrollController` gets an
  `initialScrollOffset` computed from the entries above the anchor — their fixed
  row extent plus each day header's fixed extent — clamped to the scroll range and
  offset so the row sits just below the pinned header. The arithmetic is exact
  because both extents are fixed and the query is always empty on open, so step
  16's grown rows cannot be in play. No `ensureVisible`, no lazy-row search, no
  animation: the list is already there on the first frame, which is also what keeps
  the opening transition from sliding content under the reader.
- **The highlight.** `PromptSpineRow` takes one bool; the anchored row draws a
  subtle background tint while the screen is open. No pulse, no timer, nothing that
  moves.
- **Nothing to anchor.** An empty list, or an anchor that is not in the list, opens
  at the newest end with no highlight. One null check, not a fallback path.

### 11. Returning to the transcript (step 11)

Tapping a row closes the layer and scrolls the transcript to that message.

- The transcript's anchor machinery is keyed on **row ids**, and a rendered
  message row's id is its message id (`_holdRow({required String rowId, required
  double top})` and `_stepAnchor` in `session_detail_message_list.dart`). So a
  follow-up row addresses its own message exactly; no fallback to the turn
  opener is needed, and D27's "if it can only address the turn" branch does not
  arise. Step 11 confirms this against the code before building on it.
- Step 8's `_jumpToTurn({required String openerMessageId})` becomes
  `_jumpToMessage({required String messageId})`, which the sticky overlay also
  calls with its opener id. One helper, two callers, no widening of behavior.
- **The seam.** `_SessionDetailBodyState` owns a `TranscriptJumpNotifier`
  (`transcript_jump_notifier.dart`, `module_app_ui`), a `ChangeNotifier` holding
  one nullable pending message id. It is passed through
  `SessionDetailLoadedView`, which only forwards it, to
  `SessionDetailMessageList`, which listens, consumes the id and clears it. This
  mirrors `ScrollFollowTracker.scheduleJumpToEdge()`, the existing precedent for
  asking the list to move; the `Notifier` suffix names its role, and no authored
  `*Controller` class exists in these packages. A plain widget prop cannot work:
  tapping the same prompt twice must jump twice.
- **One owner.** `_SessionDetailBodyState` owns the layer, its open flag, the
  transition controller and this notifier. `SessionDetailLoadedView` owns none of
  them and only forwards the notifier to the list; the list owns only the
  consumption of a pending id.
- The jump reuses the convergent search, so an unbuilt target is reached, and a
  vanished row id ends the pending jump with no move.
- A jump stops following, exactly as the sticky prompt's tap already does.

### 12. Absolute prompt numbers (step 15)

**The field.** `MessageWithPartsResponse` gains
`required int? userMessagesBefore`: how many messages of role `user` in this
session are older than the oldest message in this page.

- Nullable, not defaulted. There is no honest default: `0` would claim the page
  starts the session. A dated compatibility comment sits on the field:
  `// COMPATIBILITY 2026-09-26 (v1.9.1): older bridges omit this count, so the
  client shows no prompt numbers. Retire when every supported bridge sends it.`

**Where the query lives.** All database code stays in `api/database/`, so the
count is a new DAO method, not SQL inside a repository:

- `ChatHistoryDao.countUserMessagesBefore({required String sessionId, required
  int seq})` in
  `bridge/app/lib/src/api/database/history/chat_history_dao.dart`, using
  `customSelect` over
  `SELECT COUNT(*) AS c FROM history_messages WHERE session_id = ? AND seq < ?
  AND json_extract(info_json, '$.role') = 'user'`. `history_messages` has no role
  column, so the role is read out of `infoJson`; JSON1 is available in the
  bundled sqlite3. Typed Drift has no `json_extract`, which is why this one
  statement is raw — and it is raw **in the DAO**, where the only other
  `customSelect` in `bridge/app/lib/src` already sits
  (`api/database/database.dart`; the chat-history DAO has none today).
  **No migration, no new column, no new index.**
- `ChatHistoryRepository` calls the DAO and threads the value through
  `ChatHistoryPage`. `_assemblePage` gains `required int? userMessagesBefore` and
  computes nothing itself: it receives neither a `sessionId` nor a database handle
  today, and it should not gain either. Its two callers supply the value:
  - `getSessionMessages` calls `countUserMessagesBefore` with its own `sessionId`
    and `messageRows.first.seq`, then passes the result in;
  - `getSessionMessagesWithSyncState` gets it from the DAO's existing
    `getPageRowsWithSyncState`, which is extended to return the count **from
    inside the transaction it already opens**, alongside the rows it reads there.
    One snapshot, so the count and the page cannot disagree. Counting outside
    that transaction would let a concurrent backfill shift it by one.
- **When no query runs.** The count is `0` when the read has no `limit` (the
  whole session, so nothing precedes it) and when the page is empty (there is no
  page for anything to precede). Only a limited, non-empty page costs a query.
- Cost: a covering scan of that session's rows once per limited page fetch, not
  per frame. Accepted. If a very long session ever shows latency, the escape
  hatch is a real `role` column with an index — which *is* a migration, and is
  out of scope here.
- Every assembly site must set it, including the ones that are easy to miss: the
  two repository read paths above, `getArchivedSessionMessages` (which reads
  `ArchivedMessageDto`s in memory, each carrying `seq` and the full `Message`, so
  it counts there with no SQL and no DAO call), `_storedOnlyPage`'s empty-page
  early return, and the three read sites in
  `chat_history_service.getSessionMessages`. The `ChatHistoryPage` and
  `SessionMessagesPage` typedefs carry it between them.
- Automation is role `assistant` with a non-`agent` sender, so it is not
  counted. Restored Claude queued commands (step 3) are user records and are.

**The client.** `SessionDetailLoaded` gains
`required int? userMessagesBeforeOldest`, set from the page the client most
recently fetched at the oldest end: the initial load, a refresh, or an older
page. Since older pages only ever arrive in strictly older order, that value is
always the oldest loaded page's.

- Numbering rule: an entry's number is
  `userMessagesBeforeOldest + (count of role-`user` messages before it in the
  loaded list) + 1`, computed oldest-first inside the prompt list model.
- **Why it is stable.** For an older page P and the current base B,
  `base(P) + userMessagesIn(P) == B`. So prepending P gives P's messages the
  numbers below B and leaves every already-numbered message exactly where it
  was. Step 15 asserts this in a test that loads three pages and compares the
  numbers before and after each load.
- Non-renderable user messages consume a number but show no row, so a number can
  be skipped (D36). Accepted: the alternative is teaching the bridge the client's
  renderability rule, which would put a client display policy into the bridge.
- `null` base means no row shows a number and everything else works (D29).
  **Deliberately not added:** the client could infer a base of 0 whenever the
  oldest loaded page reports `nextCursor == null`, which would number fully
  loaded sessions even against an older bridge. That is a shim for an older peer
  and the user declined it.

**Compatibility.** This is a client↔bridge wire contract, so both directions
matter. A newer bridge sending the field to an older app: unknown JSON keys are
ignored, nothing changes. A newer app against an older bridge: the field is
absent, the base is null, numbers are hidden. No behavior other than the numbers
depends on it.

### 13. Pinch opens the Prompts screen (step 13)

- `TranscriptPinchDetector` keeps its recognizer, its arena behavior and its
  thresholds. Its `onFoldRequested({folded, focalPoint})` becomes
  `onPinchIn({focalPoint})`, and the `_kUnfoldScale` half goes: on the
  transcript there is nothing to pinch out of. At most one open request per
  gesture, as before.
- The focal point is no longer used to anchor a turn — the transcript does not
  move — so `_turnAt` loses its only caller. It is passed to the transition
  instead (D35): the layer grows from where the fingers were.
- The follow-state rules of [Architecture 5](#5-pinch-step-7) stay exactly as
  they are: a pinch that reaches the threshold no longer needs to hold a turn in
  place, but a trackpad pinch still detaches through the outer `Listener`, and a
  pinch that opens nothing must still leave the follow state alone. The existing
  `suppressDetach`/`releaseDetachSuppression` pairing is kept.
- No pinch gesture is added to the Prompts screen. Exit is the tap, the back
  gesture and the header's close affordance.
- The step's pinch tests are the step 7 tests rewritten for the new outcome, not
  new ones: the same platform variants, the same one-finger-still case, the same
  unaffected one-finger scroll, peek and nested horizontal scroll.

### 14. The transition (step 12)

- One `AnimationController` in `_SessionDetailBodyState`, ~220 ms to match
  `buildSessionPaneTransitionPage`'s duration.
- Forward: the layer fades in while scaling up from about 0.96 around the entry
  focal point — the pinch's focal point, or the bar button's centre — over a
  transcript that dims slightly. Reverse on the way out, including on a row tap,
  so the list appears to fall back into the transcript.
- Reduced motion (`context.isReducedMotion`, already used by
  `buildSessionPaneTransitionPage`) gets a plain cross-fade with no scale.
- The transcript is not rebuilt, resized or scrolled by any of this. Only opacity
  and, at most, a transform on the already-laid-out subtree.

### 15. Search (step 16)

- The pinned header's title row becomes `ListSearchField`. The field *is* the
  header (D30): the total count moves to the last sliver.
- One `String` of state in the view. `ListSearchField` reports every edit with no
  debounce, which is its documented contract, and the filter is a substring pass
  over the already-built entry list — no index, no async, no bridge call.
- Matching is case-insensitive over the user message's **full** text, not the
  one-line excerpt, which is why a match can fall past the cut.
- A matching row **grows**: under the ellipsised opening words it shows a short
  window of the full text around the first match, with the match highlighted.
  The window is a fixed number of characters either side, clipped at the text's
  ends, and the row stays a single extra line. Non-matching rows are filtered
  out, so the spine stays continuous.
- Day headers keep grouping whatever rows remain, still oldest day first with the
  "No date" group above them; a day with no match contributes no group.
- The last sliver states the honest scope: the match count within the loaded
  range. Newly loaded entries are filtered by the same query on the next build,
  so the count grows in place.
- **"Load earlier prompts" is the first scrolling sliver, not the last** (D39).
  It shows while `olderMessagesCursor != null`, calls the cubit's existing
  `loadOlderMessages` and is disabled while `isLoadingOlderMessages`. In
  chronological order the older boundary is the top, so a control that loads
  earlier prompts belongs there; putting it under the newest prompt would point
  the wrong way.
- Newly loaded prompts are **prepended** above it, so without a correction the
  reader's rows would move down by the added extent. Every added row and header has
  the same fixed extent as the ones already there, so the view adds that extent to
  its offset in the same frame and what the reader is looking at stays put. This is
  the one place on this screen where content could jump, so it is the one place the
  step measures a row's position across a load.

### 16. The ACP prompt accept stamp (step 15)

D38, and the smallest change in the plan: one hook stops discarding a value the
bridge already computes.

**The change.** `AcpEventMapper.localUserMessageTime({required int createdAtMs})`
(`bridge/sesori_plugin_acp/lib/src/acp_event_mapper.dart:105`) returns
`PluginMessageTime(created: createdAtMs, completed: null)` instead of `null`, and
its doc comment stops calling the value backend-authoritative: the base now
answers with the instant the bridge itself observed, and a harness override
replaces it with a backend time when it has one.

- Both callers already pass a real instant:
  `mapSentPrompt` (`:389`) from `_markTurnDispatched`
  (`bridge/sesori_plugin_acp/lib/src/acp_plugin.dart:1649`), and
  `mapInitialPrompt` (`:373`) from session creation (`acp_plugin.dart:1064`).
- It reaches all six harnesses at once with no per-plugin work: Copilot, Hermes
  and OMP construct `AcpEventMapper` itself, and Cursor, Grok and Antigravity
  subclass it without overriding this hook.
- **It makes DeepSeek's override obsolete.** `DeepSeekEventMapper`
  (`bridge/sesori_plugin_deepseek/lib/src/deepseek_event_mapper.dart:24-26`)
  returns exactly the new base value, so step 15 deletes it, as AGENTS.md
  requires. Its `messageTimeForNotification` override stays: that one carries a
  real backend time. The test fake at
  `bridge/sesori_plugin_acp/test/acp_turn_serialization_test.dart:65` overrides
  the hook only to make it non-null and goes with it.
- **Not touched.** `messageTimeForNotification` (`:102`) still returns `null` for
  the six: assistant-message times are a different gap and no harness sends them.
  `AcpSessionLoader`'s `messageTimeResolver` also stays as it is, which is
  precisely why history-read prompts stay undated (D38).

**What the stamp means, exactly.** The instant the bridge dispatched the prompt,
not the instant the user pressed send; for a prompt that waited behind a running
turn those differ by however long the queue held it. Accepted: no reader can see
the difference in a day header or a time column, and threading
`AcceptedPromptsRepository`'s own `acceptedAt`
(`bridge/app/lib/src/repositories/accepted_prompts_repository.dart:21`) through the
queue into the plugin is real machinery for an invisible gain.

**A forced re-import can undo it.** `replaceSessionMessages` matches replayed rows
against retained live ones and "the imported row remains authoritative for replay
metadata" (`bridge/app/lib/src/repositories/chat_history_repository.dart:445-462`),
so a stamped prompt the harness also reports in its own history can come back
undated and join the "No date" group — the shape D38 already accepts. Nothing is
added to prevent it: a correct row losing its time is cosmetic, and defending it
means changing the history merge.

**Client work: none.** The prompt list model already carries per-entry `createdAt`
and `dayKey`, already groups undated entries and already keeps `hasTimes` for the
fully untimed case. The stamp only changes which of those paths a session takes.

**Documentation.** Step 15 rewrites the Grok/Antigravity/Copilot/Cursor/Hermes/OMP
row of `docs/HARNESS_CAPABILITIES.md`'s "Live timers" section, which today says
"❌ Not implemented… A bridge-side prompt stamp is planned". It becomes: implemented
for prompts Sesori sent, from the bridge's own dispatch instant; not available for
prompts read back from the harness's own history, because the ACP protocol carries
no message time. "Working…" always has a timer, since a running turn's prompt is
always one Sesori sent. The row is not touched before the code lands: step 11
records the state at step 11, and step 15 updates the same row when the stamp
ships.

## Approved Copy

The copy comes from the chosen round-3 mock, recorded here because the page
stays local.

- `{n}` counts steps.
- `{duration}` reads like "1m 02s".
- Steps 4, 6 and 8 added these strings to `app_en.arb`. Review may polish
  the wording, but not the meaning.
- **Every folded-stub and fold-button row below is removed by step 14.** Only
  the sticky-prompt row survives. The Prompts screen's copy is the second table.

| Element | Copy |
|---|---|
| Folded stub, done | "› {n} steps · {duration} — {first line of the final answer}". Use "1 step" and "No steps". Drop the dash and excerpt when there is no text. When the duration is null, drop it and the " · " before it: "› 3 steps — {excerpt}", or "› 3 steps". |
| Folded stub, running | Running glyph, then "Running · step {n}". Before the first step, plain "Running". The mock's live clock is dropped (D16). |
| Folded stub, failed | Error glyph, then "Ended with an error · {first line of the error message}" |
| Folded stub, partial segment | Planning copy, not in the mock: "Earlier turn, partly loaded · {n} steps" |
| Folded stub, preamble | Planning copy: "Before the first prompt · {n} steps" |
| Fold button | "Fold all turns" / "Unfold all turns". On desktop the tooltip adds the shortcut. |
| Sticky prompt, screen readers | Planning copy: the label is the text it shows; the tap hint is "Jump to this prompt". |
| Desktop index (dropped) | Never implemented; the pane is deferred. |

The mock's "Stopped by you" line is not shown in phase 1 (D12).

### Prompts screen copy (steps 11, 15 and 16)

Planning copy, not from a mock. Review may polish the wording, not the meaning.

| Element | Copy |
|---|---|
| Entry button | Tooltip and screen-reader label "Prompts". |
| Screen title, before search lands (step 11) | "Prompts" |
| Search field hint (step 16) | "Search prompts" |
| Total count, last row | "{n} prompts loaded". Use "1 prompt loaded". |
| Match count, last row while searching | "{n} matches in the prompts loaded so far". Use "1 match in the prompts loaded so far", and "No matches in the prompts loaded so far". |
| Load earlier | "Load earlier prompts", at the top of the list (D39). |
| Day header | The date, in `formatMessageTimestamp`'s conventions: "Today", "Yesterday", then the date. Oldest day at the top. |
| Undated day header | "No date", above every dated day (D38). |
| Follow-up row, screen readers | The row's text, prefixed "Follow-up:" so a child row is not read as a peer. |
| Row, screen readers | The number where there is one, the text, and the time where there is one, as one button labelled with them; the tap hint is the existing "Jump to this prompt". |
| No prompts yet | "No prompts in this session yet" |

## Analytics

Checked against `.opencode/skills/add-analytics/SKILL.md`.

**Step 6 shipped `transcript_turns_folded`** (no parameters, reported from
`SessionDetailCubit.setTranscriptFolded` on every unfolded→folded switch). Its
only emitter disappears with the fold, so step 14 removes the event, its factory,
its deferred-candidate line and its test lines. It is not kept as a tombstone;
Git history holds it.

**Step 11 replaces it** (D32):

- **The event.** One account-linked adoption event,
  `transcript_prompts_opened`, with one closed parameter `entry`, whose values
  are `session_bar` and `pinch`, modelled on `SessionDiffViewedEvent`'s
  `change_state`. It is sent once each time the Prompts screen opens.
- **The decisions it informs.** Whether prompt navigation is used enough to
  justify F1, F2, deck mode and more navigation surfaces — the same question the
  fold event was asked — and, new after the rejection, whether the pinch is
  discovered at all or everyone uses the button. That second question is exactly
  why the parameter exists; without it the plan cannot tell a discovered gesture
  from an undiscovered one.
- **The seam.** The authoritative outcome is the screen actually opening, which
  `_SessionDetailBodyState` owns. Cubits are the analytics consumer layer, so the
  open path reports through the cubit's existing `_reportProductEvent`
  (`session_detail_cubit.dart:2506`) with a new intent that takes the entry
  point. The bar button, the desktop toolbar button and the pinch all go through
  the one open path, so none can open the screen without reporting.
- **When.** Step 11 defines the event with both `entry` values and emits
  `session_bar`; step 13 emits `pinch`. The closed set is complete from the
  start, so the model is not edited twice.
- **Not tracked.** Closing the screen, a row tap, search queries or match counts,
  "Load earlier prompts", and whether a row was an opener or a follow-up. No
  content, ids, numbers, counts or timings are reported.
- **Desktop.** Nothing is sent: the desktop's `AnalyticsClient` is the no-op
  one, the same limit the desktop-sign-in plan accepted. So the `entry`
  parameter's pinch value reports from the phone only, which is where the
  gesture question matters.
- **Follow-up.** The curated warehouse transform lives in the private
  `sesori_analytics_platform` repository. Raise both the new event and the
  removed one there when steps 11 and 14 merge; this plan does not claim it.

## Security And Privacy

- Three bridge changes in this phase: the Claude mapping fix (step 3), which reads
  records already on disk and maps them to the same neutral messages the live
  path emits, D29's count (step 15), and D38's prompt stamp (step 15). The count
  is an integer derived from rows the same response already returns messages from;
  it exposes no new data to the client and no data at all to anything else. The
  stamp is an instant the bridge already computed in the same call and then
  discarded, so it reveals nothing that was not already local; it says when a
  prompt was sent, never what it said.
- The Prompts screen, the sticky header and the search excerpt show only text
  the transcript already shows, to the same authenticated client.
- Search runs entirely in the client's memory. No query text leaves the device,
  and nothing is persisted: the query lives in one widget's state for as long as
  the screen is open.
- The analytics event carries no content, ids, counts or timing — only a closed
  entry-point value.
- This plan's evidence kept only aggregate counts from local stores. No
  content, paths or ids were recorded.

## Complexity Budget

Mutable parts after step 14, counting what this revision adds and what it
removes. One leaves and seven arrive; each has one owner and one reader.

Kept from steps 5–8:

1. **The row registry `Map<String, BuildContext>`** (step 5). Still the only
   reliable way to find built rows, now for the sticky header and the jump.
2. **The pending anchor**: one nullable target (step 5).
3. **Per-gesture pinch fields** (step 7): triggered-this-gesture,
   started-following and detach-suppressed.
4. **The sticky `ValueNotifier<TranscriptStickyPosition?>`** (step 8), read only
   by the overlay.

Removed by step 14:

- The fold flag in `SessionDetailCubit` and `SessionDetailLoaded`.

Added by steps 11–16:

5. **The Prompts open flag**: one `bool` in `_SessionDetailBodyState`, read only
   by that widget's own `build`.
6. **The `TranscriptJumpNotifier`**: one `ChangeNotifier` with one nullable
   message id, written by the layer's owner and consumed by the list.
7. **The transition `AnimationController`** (step 12), owned by the same state.
8. **`SessionDetailLoaded.userMessagesBeforeOldest`**: one nullable int, written
   only where a page is merged (step 15).
9. **The query string** in the Prompts view's state (step 16).
10. **The current top-edge opener `ValueNotifier<String?>`** (step 11), written by
    the list in the post-frame pass it already runs and read only when the layer
    opens, to anchor the list (D39).
11. **The Prompts view's `ScrollController` and the anchor id it opened with**
    (step 11), both owned by the view: the controller for the opening offset and
    for correcting the offset when earlier prompts are prepended (step 16), the id
    only so one row draws the highlight. Neither is written again while the screen
    is open.

Never added:

- The old step 9's index-pane `ScrollController` — the pane is dropped. Its
  current-turn `ValueNotifier` does arrive, in a smaller form and with a different
  reader: one nullable opener id for the opening anchor (item 10), not a pane
  kept in sync with the scroll.
- A second load path, a prompt cache, a search index, or any stored prompt data.
- A cubit for the Prompts screen. It reads the session cubit it already sits in.
- A route, an `AppRouteDef` value, a route allowlist entry, or route analytics.
- A per-turn or persisted fold state, and a fold scope or notifier.
- Timestamp heuristics, an invented time, or any placeholder for an undated
  prompt. The bridge stamp is added (D38), but it only keeps an instant the bridge
  already had; it holds no new state.
- A database column, index or migration.
- A client-side numbering fallback.
- A search debounce: `ListSearchField` documents that the list narrows what it
  already has, and the filter is a substring pass over a list already in memory.
- A sliver or non-reversed rebuild of the transcript.
- The stopped state, a semantics custom action, alt+↑/↓, and a phone density
  switch.

## Cleanup Assessment

The first revision found no cleanup, because folding only added. This revision is
mostly cleanup, and it is the largest single item in the series.

- **Step 14 is the cleanup PR.** The Prompts screen supersedes the in-place fold
  outright, so the fold's state, rows, controls, shortcuts, gesture meaning,
  analytics event, copy, tests and documented behavior are removed in one
  coherent PR, listed in
  [Architecture 9](#9-removing-the-in-place-fold-step-14). Approximately 1,050
  lines come out: ~285 production, ~580 test, ~105 localization and generated
  localization, ~85 documentation. Removing what this change makes obsolete needs
  no approval.
- **Deferred within the plan, with a reason.** The removal lands one PR *after*
  step 13 rather than inside it, because step 13 must give the pinch its new
  destination before the old one disappears, and because the two together would
  put a gesture change and a 1,000-line deletion in one review.
- **Turn-model members** (`duration`, `steps`, `TranscriptTurnOutcome`) lose
  their last reader with the stub. Step 14 deletes
  whatever is still dead when it runs, or lands the trim as step 14.b if it
  pushes the PR past target.
- **Not removed, with reasons:** the turn model, the row registry and anchor
  search, the three duration ARB keys, the peek's detach suppression and the
  desktop shortcut-hint helpers — each has a live reader named in
  [Architecture 9](#9-removing-the-in-place-fold-step-14).
- **Two small removals caused by the new work.** Step 11 extracts the shared
  prompt-text resolver that step 8's review flagged as duplicated, because step 11
  is its third caller. Step 15's prompt stamp (D38) makes
  `DeepSeekEventMapper.localUserMessageTime` and the ACP test fake's override of
  the same hook identical to the base, so both go in that PR
  ([Architecture 16](#16-the-acp-prompt-accept-stamp-step-15)). Nothing else in
  steps 10–16 makes existing code obsolete.

Each step re-checks this for its own diff.

## Proportionality And Accepted Risk

Evidence levels:

- **Observed.** Rule A, measured on local stores; the Claude replay loss, seen
  in local stores; the ACP stop-and-send, read from code; **the fold's bad feel,
  observed by the user on a real device**, which is the strongest evidence in this
  plan and the reason for the revision.
- **Synthetic.** The gesture and sticky behavior come from 56 spike tests in
  Flutter's test harness. Real-device checks are named per step.
- **Read from code on 2026-09-26.** The six untimed harnesses, the absence of a
  role column and of any existing count field, the routing and cubit-scope facts
  that decide the screen's shape, and the fold-removal inventory. Re-read the same
  day for round 4: the discarded ACP prompt instant and its two callers, which
  plugins override the hook, the replay path's separate time resolver, and the
  history merge's "imported row is authoritative" rule.

Accepted:

- About 2% of ordinary Claude prompts that follow a completed tool step join
  the previous turn, so a follow-up row is occasionally nested under the wrong
  turn. The row still exists, with its own number and time, and tapping it still
  lands on it; only its indentation is wrong.
- The partial oldest turn, and a one-time boundary change when an older page
  loads.
- Two-finger touch scrolling no longer scrolls the transcript.
- The existing gap-or-duplicate hazard when older pages merge after a
  re-import.
- Numbers are hidden entirely against an older bridge, rather than partly
  guessed.
- A number is skipped where a user message exists but the transcript hides it.
- **A mixed timed/undated list on the six ACP harnesses** (D38): recent prompts
  carry times and day headers, older ones read back from the harness's own history
  sit in the "No date" group at the top. The user accepted this asymmetry
  knowingly. A session Sesori never sent a prompt to still has no time column at
  all.
- The stamp is the dispatch instant, so a prompt that queued behind a running turn
  is stamped when it left the queue, not when it was sent.
- A forced history re-import can return a stamped prompt to the undated group.
- Search sees only the loaded range, and says so on screen.
- One `COUNT(*)` with `json_extract` per page fetch, unindexed.
- The screen has no URL and no deep link.
- A jump to a distant prompt moves about one cache-extended viewport per frame,
  so a long jump shows brief motion — unchanged from step 8's sticky tap.
- ACP follow-ups open a new turn. A live ACP follow-up after a running tool can
  also move to a new turn once idle finalization marks that tool failed.
- Claude's live-only `isMeta` bubbles can open a bogus turn live, for example
  an interrupt marker after text.
- OpenCode task-notification injection stays unverified.
- Already imported Claude sessions regain dropped follow-ups only on their next
  re-import.
- The sticky header can lag by one frame.
- A jump to a distant turn moves about one cache-extended viewport per frame,
  so a long jump shows brief motion.
- The jump-to-latest pill can flash briefly when a trackpad pinch starts while
  following. The peek has the same flash.

## Regression Coverage

Each step updates the documents for the behavior it ships, in its own PR.
Steps 4 and 5 ship nothing users can reach, so they change none.

| Step | Document changes |
|---|---|
| 3 | `session-history-and-recovery.md`: the Claude fix, as [Architecture 2](#2-claude-follow-ups-and-automation-survive-history-load-step-3) says. |
| 6 | Creates `docs/regression/transcript-turn-navigation.md` and adds it to the Feature Index: capability, required behavior, levels L1–L5, exploration guidance, failure signals, known limitations and sources, for folding, its controls and place-keeping. Adds the cross-references from `session-turns.md` (busy follow-ups), `session-history-and-recovery.md` (paging, re-import) and `tools-and-file-changes.md` (step groups, jump to latest), and the `docs/HARNESS_CAPABILITIES.md` section. |
| 7 | Pinch, including its follow-state rules. |
| 8 | The sticky prompt, including its screen reader node. |
| 11 | Rewrites the capability paragraph around the Prompts screen and adds its required behavior, levels, exploration guidance, failure signals and limitations, including the transcript's order, the opening anchor and the undated group (D38, D39). Adds the `docs/HARNESS_CAPABILITIES.md` prompt-times note for the state at this step: the six ACP harnesses still show no times. |
| 12 | The transition, including reduced motion. |
| 13 | Pinch opens the screen; the fold clauses of pinch go in step 14. |
| 14 | Removes the fold and pinch-to-fold behavior from `transcript-turn-navigation.md` and the fold cross-references in `session-history-and-recovery.md` and `tools-and-file-changes.md`, and re-words the `session-turns.md` one. No tombstones. |
| 15 | Prompt numbers, their stability across an older page, and the no-number case against an older bridge. Cross-reference from `session-history-and-recovery.md` for the new response field. The ACP prompt stamp: which prompts get a time, which stay undated, and the "Working…" timer arriving on the six harnesses — in the regression document and in the `docs/HARNESS_CAPABILITIES.md` "Live timers" row that step 11 left saying otherwise. |
| 16 | Search, the grown match row, and "Load earlier prompts" at the top of the list with no jump when earlier prompts arrive. |
| 17 | Reconciles every document with what shipped. |
| 18 | Records the L3 result. |

Failure signals, each added by the step that ships the behavior:

- step 6 (removed again by step 14): the reading position jumps on fold or
  unfold;
- step 6, kept: turns split differently after a re-import;
- step 7 (rewritten by step 13): a pinch scrolls or a scroll folds;
- step 8: a follow-up or automation shows as a sticky prompt;
- step 11: **the transcript moves, reflows or loses its place when the Prompts
  screen opens or closes**; a follow-up is listed as a peer instead of a child, or
  above its parent; a tap lands on the wrong prompt or on nothing; the screen opens
  at the end of the list instead of at the prompt that was being read; a
  fully untimed session shows a day header or an empty time column; the "No date"
  group appears below a dated day;
- step 13: a pinch scrolls the transcript, opens the screen twice, or a
  one-finger scroll or peek opens it;
- step 15: a number changes when an older page loads; numbers appear against a
  bridge that sends no count; a prompt Sesori sent through an ACP harness has no
  time; a prompt read back from a harness's history shows one;
- step 16: a filtered row shows no reason for its match; the match count claims
  more than the loaded range; the rows under the reader move when earlier prompts
  load.

**Highest level: L3 Release.** The boundary was client end to end; after step 15
it runs through the real bridge, because the numbers come from a bridge query and
degrade against an older bridge. It covers every supporting production plugin for
turn grouping and one of the six ACP harnesses, on the release-target client
platform plus macOS for the desktop behavior.

Required matrix, recorded now; any reduction needs the user's acceptance in
this file before retirement:

| Platform | Coverage |
|---|---|
| iOS phone, real device (release target) | On a session of three or more pages: a pinch in opens the Prompts screen and **the transcript behind it has not moved when the screen closes** — check the same row is at the same place. The bar button opens it too. **The screen opens on the prompt that was under the reader, highlighted and on screen, from both entry points.** Openers and follow-up child rows in the transcript's order, each child below its parent, with numbers ascending down the screen and no renumbering after "Load earlier prompts". Sticky day headers while scrolling, oldest day at the top. "Load earlier prompts" is at the top, and the rows already on screen do not move when it loads. Tapping an opener and tapping a follow-up each land on that message. Search: a match whose reason is past the one-line cut shows the grown excerpt, the match count names the loaded range, and "Load earlier prompts" extends it. The transition in and out, and again with Reduce Motion on. The sticky prompt appears mid-turn, is pushed out by the next prompt, clamps a long prompt, and scrolls to it on tap. One-finger scroll, the timestamp peek and a code block's horizontal scroll are unaffected. VoiceOver reads the rows, the follow-up prefix, the entry button and the pinned prompt. `transcript_prompts_opened` arrives with both entry values. |
| macOS desktop | Trackpad pinch opens the screen, while following and while reading history, and the transcript is where it was on the way back. The toolbar button. The same list order, opening anchor, numbering, day headers, tap-to-return and search checks. Trackpad scroll and the trackpad peek are unaffected. No fold shortcut does anything. |
| Android phone | Pinch and the bar button open the screen; a list, tap-to-return and sticky prompt smoke check. |
| Windows and Linux desktop | The toolbar button, a list and tap-to-return smoke check. |
| Bridge plus client | A session with more than one page: the numbers match the prompts actually sent, counted independently, and do not change as pages load. One archived (read-only) session, whose pages come from the audit file rather than the database. A current app against a bridge built before step 15: no numbers, everything else works. |
| Plugins (live plugin plus client) | A follow-up sent while a turn runs: with Claude, Codex, Pi and OpenCode it stays inside the running turn and is listed as its child. With one ACP plugin (the stop-and-send base is shared) it opens a new turn, as the capability doc records. Claude and Pi automation is never listed and is never a sticky prompt. After a forced Claude history re-import, follow-ups, peer messages and task notifications are still present, with the same ids and order. With one of the six ACP harnesses (D38): a session Sesori prompts through shows times and day headers for those prompts; a session with history from before Sesori attached shows those older prompts in the "No date" group at the top, and the same session shows both at once; a session Sesori has never prompted shows no time column at all; and "Working…" now ticks. Run together with `session-turns.md`'s busy-send check. |

Automated coverage in the steps:

- the turn model (step 2) and the prompt list model (step 10);
- Claude parser and mapper parity (step 3);
- widget tests for the pinch arena with touch and trackpad variants (steps 7 and
  13), and sticky push-out and semantics (step 8);
- widget tests for the Prompts screen (step 11): the row shapes, child
  indentation, day headers with the oldest day and the "No date" group at the top,
  the fully untimed case, a mixed timed/undated list, the screen opening with the
  top-edge prompt highlighted and visible and with no anchor to find,
  tap-to-return to an opener and to a follow-up including an unbuilt row, and the
  transcript's scroll offset being unchanged across open and close;
- the transition, including reduced motion (step 12);
- the response field, the numbering rule and its stability across three page
  loads, on both the database and archived paths, plus the no-field case
  (step 15);
- the ACP prompt stamp (step 15): the base mapper stamps a sent prompt and the
  initial prompt, a harness override still wins, and the replay path still
  produces no time;
- search filtering, the grown excerpt, the match count, "Load earlier prompts" at
  the top, and a row keeping its position across a prepend (step 16);
- the analytics event and its closed parameter (step 11), and the fold event's
  removal (step 14).

## Delivery Rules

- **Order.** Steps run in order, with the parallelism below.
  - Steps 1–8 have merged. Their order rules are history.
  - Step 10 is pure and may run beside step 9's review.
  - Steps 12, 13 and 15 all need step 11 and may run in parallel: the
    transition, the pinch and the numbers touch different files.
  - **Step 14 must follow step 13.** The pinch must have its new destination
    before its old one is deleted, so no PR ships a gesture that does nothing.
  - Step 16 needs step 15, because a matching row shows its number in the grown
    state and both change the same slivers.
  - Step 17 needs every behavior step; step 18 needs step 17.
- **Per-step evidence.** Each step verifies this plan's claims before editing.
  It writes its evidence to `steps/step-NN.md` in its own PR, and updates the
  documents for the behavior it ships (see
  [Regression Coverage](#regression-coverage)).
- **Visuals.** Steps 6–8 and 11–16 show before and after screenshots, or a short
  recording for gestures, transitions and scrolling. Steps 12 and 13 need a
  recording, not stills. Use fixture sessions only, and never show a real path,
  prompt, transcript or account name: the repository is public.
- **Architecture implementation review** for steps 2 to 8 and 10 to 15: new
  classes, the ownership of the Prompts layer and the jump controller in step 11,
  the new wire field and its plumbing in step 15, and the removal's blast radius
  in step 14. Step 16 is ordinary widget logic inside an existing screen and does
  not need it; steps 9, 17 and 18 are documentation.
- **Size.** Targets are in the tracker. Step 13 (gesture) and step 12
  (transition) aim lowest. Step 14 is the largest and is almost all deletion; if
  it exceeds its target, the turn-model trim moves to 14.b rather than growing
  the PR.
- **Checks.** Run `dart analyze --fatal-infos` per touched package, with the
  pinned Flutter 3.47.5 first on `PATH`.

## Steps

**Step 1 — this plan.**

**Step 2 — turn model.** [Architecture 1](#1-turn-model-in-module_core-step-2).
Verify:

- the `module_core` tests listed there;
- `dart analyze --fatal-infos` in `module_core`.

No user-visible change.

**Step 3 — Claude follow-ups and automation survive history load.**
[Architecture 2](#2-claude-follow-ups-and-automation-survive-history-load-step-3).
Verify:

- Confirm the live ids first, as described there, and record them.
- Parser and mapper fixture tests for each mode, and the live/replay parity
  test.
- A live-plugin check with the headless bridge and the debug server: a Claude
  session with a follow-up, a peer message and a task notification keeps them,
  with the same ids and order, after a forced re-import.
- Analyze `sesori_plugin_claude`.

**Step 4 — render folded turns from the session fold state.**
[Architecture 3](#3-fold-state-folded-rows-and-fold-controls-steps-4-and-6).
No control exposes folding yet, so nothing changes for users. Verify with
cubit and widget tests:

- the intent switches the state, and a request that changes nothing emits
  nothing;
- the fold state survives a full reload, and another session's cubit starts
  unfolded;
- the folded row layout per turn: prompt plus stub, the leading-segment stub,
  and unchanged synthetic rows;
- the stub copy for each outcome and segment, including plain "Running" for a
  running turn with no step yet, and a done stub with a null duration, which
  drops it and its separator, with and without an excerpt;
- no rows ease in on a switch.

Also analyze `module_core` and `module_app_ui`.

**Step 5 — keep the reader's turn in place.**
[Architecture 4](#4-keeping-the-readers-turn-in-place-step-5). There is still
no control, so the tests switch through the cubit's intent and the stub tap.
Verify with widget tests:

- a switch mid-turn puts the opener at the top edge;
- a switch with the opener on screen keeps it within 1 px;
- a stub tap unfolds and anchors;
- an anchor on an unbuilt row behind several very tall rows is reached and
  settles within 1 px, from above and from below;
- a vanished row id ends the anchor.

**Step 6 — fold and unfold every turn from the bar and the keyboard.**
[Fold controls](#fold-controls-step-6), the first step that exposes folding.
Verify:

- widget tests for the phone bar button and the desktop header button: each
  shows the state and switches it;
- the shortcuts: the body binds whatever activators the chrome supplies, and
  the desktop screen builds meta activators on macOS and control elsewhere;
- the analytics event test, and a cubit test: a fold reports the event once,
  and an unfold or a repeated fold reports nothing;
- by hand: the toolbar and shortcuts on macOS and the fold button on iOS keep
  the reader's turn in place, with a short recording.

Also before and after screenshots on phone and desktop, the documents listed
under [Regression Coverage](#regression-coverage), and analyze `module_core`,
`module_app_ui`, `client/app` and `client/desktop`.

**Step 7 — pinch.** [Architecture 5](#5-pinch-step-7). Verify:

- Widget tests with iOS, Android and macOS variants:
  - pinch in folds once, and pinch out unfolds once;
  - one-finger scroll, tap, the touch and trackpad peek, and a nested
    horizontal scroll are unaffected;
  - a switching pinch while following holds the turn under the fingers and
    stops following, one below the thresholds leaves following alone, and a
    pinch while reading stays detached;
  - the focal-point anchor.
- **A real iPhone pinch and a real macOS trackpad pinch**, recorded.
- Pinch in the regression document.

**Step 8 — sticky prompt.** [Architecture 6](#6-sticky-prompt-step-8). Verify
with widget tests:

- the header appears when the opener leaves the top edge;
- the next opener pushes it out, with the push offsets;
- it hides when folded and for headless segments;
- the three-line clamp;
- a tap scrolls to the opener;
- while pinned it is a labelled button whose tap action jumps to the opener,
  also when the opener row is not built.

Also a real iPhone scroll through a long turn for visible lag, screenshots,
and the sticky prompt in the regression document.

**Steps 1–8 have merged.** Their evidence is in `steps/step-02.md` to
`steps/step-08.md`.

### Superseded steps

Recorded honestly rather than rewritten:

| Step | What happened |
|---|---|
| 4 | Shipped the fold state and folded rows. **Removed by step 14**, except the three duration ARB keys, which step-timers took over. |
| 5 | Shipped place-keeping. **Mostly survives**: the registry and anchor search now serve the sticky prompt and the return jump. Its fold-specific entry points go in step 14. |
| 6 | Shipped the fold controls and the fold analytics event. **Removed by step 14.** |
| 7 | Shipped pinch-to-fold. **Repointed by step 13**, which keeps the recognizer and drops the fold meaning and the pinch-out half. |
| 8 | Shipped the sticky pinned prompt. **Kept.** A follow-up PR renders its Markdown and makes only the bubble tappable; nothing in steps 9–18 touches that work. |
| old 9 | The always-visible desktop index pane. **Never implemented and dropped**; see [Architecture 7](#7-desktop-index-pane-old-step-9). Its branch name `turn-navigation/desktop-index` is released. |
| old 10 | Retirement. **Renumbered to step 18.** |

**Step 9 — this revision.** Replaces the in-place fold with the Prompts screen
across `PLAN.md` and `TRACKER.md`. Documentation only: no code, no regression
document change yet, and no Dart or Flutter suite is run.

**Step 10 — the prompt list model.**
[Architecture 10](#10-the-prompts-screen-steps-10-and-11), "The prompt list
model". Verify:

- the `module_core` tests listed there;
- `dart analyze --fatal-infos` in `module_core`.

No user-visible change.

**Step 11 — the Prompts screen.**
[Architecture 10](#10-the-prompts-screen-steps-10-and-11) and
[Architecture 11](#11-returning-to-the-transcript-step-11). Verify:

- Confirm first, and record, that a rendered follow-up row's id is its message
  id and that `_holdRow` reaches it, so D27 needs no turn fallback.
- Widget tests: the row shapes and the child indentation; the transcript's order,
  with each follow-up below its opener; sticky day headers, oldest day first, with
  the "No date" group above them; the fully untimed case with no time column and no
  day headers, and a mixed list where only some rows have a time; the opening
  anchor — the top-edge prompt is highlighted and on screen, and an empty list or
  an unknown anchor opens at the newest end with no highlight; the total count row;
  opening and closing the layer leaves the transcript's scroll offset and follow
  state unchanged; tapping an opener and tapping a follow-up each reach that
  message, including when its row is not built; a vanished row id ends the jump
  with no move; the system back gesture closes the layer instead of leaving the
  page; the entry button on the phone bar and on the desktop toolbar.
- The analytics event test and a cubit test: one event per open, with the
  `session_bar` value.
- By hand on iOS and macOS, with screenshots.
- The regression document sections listed under
  [Regression Coverage](#regression-coverage), and the
  `docs/HARNESS_CAPABILITIES.md` prompt-times note.
- Analyze `module_core`, `module_app_ui`, `client/app` and `client/desktop`.

**Step 12 — the transition.** [Architecture 14](#14-the-transition-step-12).
Verify with widget tests that the transition runs to completion in both
directions, that reduced motion removes the scale, and that the transcript is not
rebuilt or scrolled by it. Also a short recording on a real iPhone and on macOS.

**Step 13 — pinch opens the Prompts screen.**
[Architecture 13](#13-pinch-opens-the-prompts-screen-step-13). Verify:

- The step 7 pinch tests rewritten for the new outcome, with the same iOS,
  Android and macOS variants: a pinch in opens the screen once per gesture,
  including with one finger held still; a pinch out does nothing; one-finger
  scroll, taps, the touch and trackpad peek and a nested horizontal scroll are
  unaffected; a pinch that opens nothing leaves the follow state alone, and a
  pinch while reading history stays detached.
- The analytics event with the `pinch` value.
- **A real iPhone pinch and a real macOS trackpad pinch**, recorded. This step
  does not close until both have been checked on real hardware, because a device
  is what rejected the last gesture.
- Pinch in the regression document.

**Step 14 — remove the in-place fold.**
[Architecture 9](#9-removing-the-in-place-fold-step-14). Verify:

- the suites that covered the fold still pass after their fold regions are
  removed, and the rewritten paging test still proves paging;
- the sticky prompt's own tests pass unchanged apart from the deleted
  "hides while folded" case;
- `grep` finds no remaining reference to `transcriptFolded`,
  `setTranscriptFolded`, `transcript_turns_folded`, the deleted ARB keys or the
  fold shortcuts anywhere, including documentation;
- the regression and cross-referenced documents carry no fold tombstone;
- analyze `module_core`, `module_app_ui`, `client/app` and `client/desktop`.

No new user-visible behavior; the fold's controls and gesture meaning disappear.

**Step 15 — absolute prompt numbers and the ACP prompt stamp.**
[Architecture 12](#12-absolute-prompt-numbers-step-15) and
[Architecture 16](#16-the-acp-prompt-accept-stamp-step-15). The two changes share
one PR because they are the series' only bridge work, they are the only two things
the bridge owes a prompt row, and they need the same live headless-bridge check on
the same harnesses. Verify:

- Bridge tests, against the DAO method and then through the repository: the count
  on a first page, a middle page, the last page, an unlimited read and an empty
  page; a session whose only messages are assistant ones; the archived path; and
  that the count ignores automation.
- ACP mapper tests: `mapSentPrompt` and `mapInitialPrompt` stamp
  `time.created` from the `createdAtMs` they are given; a subclass override still
  wins; `AcpSessionLoader` still produces no time without a resolver. Confirm
  first, and record, that no plugin other than DeepSeek overrode
  `localUserMessageTime`, then delete DeepSeek's override and the ACP test fake's.
- Client tests: numbering from the base; numbers unchanged across three older-page
  loads; no numbers when the field is absent; a hidden user message consuming a
  number.
- Regenerate with `make -C shared codegen`, `make -C bridge codegen` and
  `make -C client codegen`; never hand-edit generated output.
- A live check with the headless bridge: numbers on a multi-page session match a
  hand count, and a current app against a pre-step-15 bridge shows none. On one of
  the six ACP harnesses, a prompt sent through Sesori carries a time and appears
  under a day header, prompts from that session's own earlier history stay in the
  "No date" group, and "Working…" ticks.
- Analyze `bridge/app`, `sesori_plugin_acp`, `sesori_plugin_deepseek`,
  `sesori_shared`, `module_core` and `module_app_ui`.

**Step 16 — search.** [Architecture 15](#15-search-step-16). Verify with widget
tests:

- the field filters as it is typed and clears;
- a match past the one-line cut grows the row and highlights the match;
- day headers keep only the days that still have rows;
- the match count names the loaded range, and "Load earlier prompts", at the top
  of the list, calls the cubit's loader and is disabled while it runs;
- newly loaded prompts join the current filter, arrive above the control, and
  leave a row that was on screen at the same offset.

Also screenshots and the regression document.

**Step 17 — reconcile the documents.** Reconcile
`docs/regression/transcript-turn-navigation.md`, its cross-references and
`docs/HARNESS_CAPABILITIES.md` with what actually shipped across steps 10–16,
and remove anything stale. Documentation only.

**Step 18 — verify and retire.** Run L3 over the matrix recorded above, record
the result in `steps/step-18.md`, and move the plan to `.plan/completed/`.

## Later Phases (rough intent only)

- **F1 bridge turn index.**
  - A read-only route. Per turn it returns: the opener id and `seq` range, a
    prompt preview, the attachment count, step, failed and cancelled counts, an
    error flag with a preview, the answer excerpt, and an outcome that can say
    "stopped" because the bridge sees abort requests.
  - An older bridge answers 404, and the client keeps "loaded turns only".
  - **Revision rule, so an index is never stale:**
    - Keep a per-session monotonic revision in `history_sync_state`.
    - Bump it in the same transaction as every row write: replace, upsert,
      delete, `finalizeOpenToolParts`, purge and archive.
    - Return it with pages and with the index.
    - Build the index from the same snapshot, after the freshness check and
      backfill.
    - Cache it by (session, revision), never by `seq`.
    - Writes that mark a session stale force the freshness check.
    - The client drops its index on a revision change or a list replacement
      (`_transcriptGeneration`).
  - This changes the client-bridge contract, so the compatibility rules apply.
- **F2 fetch one turn.** An optional range on the messages request, merged by
  id. It would let the Prompts screen list and reach a prompt the transcript has
  not loaded, which is the one thing the loaded-range limitation costs.
- **A full-session prompt list** on top of F1 or F2: search and numbering over
  the whole session instead of the loaded range, which would retire the
  "in the prompts loaded so far" wording.
- **Deck mode.** Turn by turn, entered from an open turn.
- **Possibly:**
  - the always-visible desktop index pane (old step 9, D6/D18), if the Prompts
    screen proves the need for a persistent one;
  - a keyboard shortcut and alt+↑/↓ prompt stepping on desktop;
  - a phone density switch for very long sessions.

## Open Questions

Where the agreed design meets the code, these are the points the plan could not
settle on its own. None of them blocks step 10.

1. **The Prompts screen is a layer in the session page, not a pushed route.**
   The user asked for "a separate Prompts screen"; it behaves like one, but it is
   not a `go_router` route, because a pushed route cannot see
   `SessionDetailCubit` and so cannot share the transcript's loaded range, which
   D27 and D30 both require. Consequences: no URL, no deep link, and no route
   analytics. Flagged rather than decided around silently; say so if a real route
   matters more than the shared range.
2. **The always-visible desktop index pane** (D6, D18, old step 9) is dropped in
   favour of the screen. Do you still want a persistent pane beside the
   transcript on wide desktop windows, on top of the Prompts screen?
3. **No keyboard shortcut for the Prompts screen** (D37). ⌘− and ⌘= die with the
   fold. Do you want a shortcut, and which keys?
4. **Claude's live-only `isMeta` user bubbles** (image placeholders, skill
   notices, interrupt markers) are dropped on history load. They would appear as
   Prompts rows live and vanish after a reload. Fix separately, as its own PR?
5. Can the Windows and Linux rows of the matrix run on real machines?
6. Defaults D9–D18 that survive: D11 (the turn rule), D12 (no stopped state) and
   D19–D23 stand unless you say otherwise. D32–D37 are this revision's defaults
   and are equally open, except D34, which D39 superseded. D38 and D39 are the
   user's own decisions and are settled.

Answered in round 4, kept here so the record is complete: list order (D39,
chronological and anchored) and prompt times (D38, the bridge stamps what it can
and leaves the rest undated).

## Plan Review Record

**`architecture-plan-review`, 2026-09-26 (first version): rejected** with
concrete, non-vague findings, four must-fix and three optional. All seven were
applied directly, without re-review, as AGENTS.md allows.

1. The sticky value could not drive the index highlight: it is empty while an
   opener is visible and whenever the transcript is folded. Applied: a separate
   current-turn value that only the index reads (Architecture 7 and 8).
2. Desktop key policy was hard-coded in `module_app_ui`. Applied: the desktop
   shell supplies both activators through `SessionDetailPageChrome`
   (Architecture 3, D10).
3. `duration` sat on the summary that every variant shares. Applied: it moved
   to `TranscriptPromptTurn` (Architecture 1).
4. New classes were unnamed and unplaced, and other widgets called the list's
   private helper. Applied: `TranscriptRowReporter`, `TranscriptPinchDetector`
   (in `module_app_ui`), `TranscriptStickyPosition`,
   `TranscriptStickyPromptOverlay` and `TranscriptTurnIndexPane`, each in its
   own file. The list composes them through explicit inputs and
   `onJumpToTurn`. The registry, the pending anchor and the scroll-to-row
   helper stay private to the list state.
5. Optional: one fold entry point. Applied in a different form. Every control
   calls the body's single setter, which reports analytics. The review
   suggested a nullable anchor parameter on that setter. Instead, triggers
   inside the list set the list's private pending anchor first, and the list's
   listener captures the top-edge turn otherwise (Architecture 4). The planned
   `TranscriptFoldScope` was dropped: the listenable and the setter are passed
   explicitly.
6. Optional: step 5 joined the architecture implementation review list.
7. Optional: the architecture intro now says the shared body builds the phone
   bar, and the desktop shell places its button and supplies the activators.

**`architecture-plan-review`, 2026-09-26 (this revision, the Prompts screen):
rejected** with six must-fix findings and one accuracy note, all concrete. All
seven were applied directly, without re-review, as AGENTS.md allows.

1. Step 10's entry point could not produce its output. `TranscriptTurn` carries
   a `MessageWithParts` opener but only message **ids** for everything else, and
   `TranscriptTurnBuilder` drops non-renderable user messages, so a follow-up's
   text and time — and D36's hidden-message numbering — were unreachable from
   `turns` alone. Applied: the builder also takes the rendered
   `List<MessageWithParts>`, walks it oldest-first for text, time and numbering,
   and uses `turns` only to classify openers and follow-ups (Architecture 10).
2. The per-page user-message count was placed in `ChatHistoryRepository` as raw
   SQL, which breaks the rule that database code lives in `api/database/`, and
   `_assemblePage` has neither a `sessionId` nor a database handle to run it
   with. The claim that the chat-history DAO already uses `customSelect` was
   also wrong. Applied: the count is a new `ChatHistoryDao`
   method; the repository calls it and threads the value through
   `ChatHistoryPage`; the snapshot path returns it from inside the transaction it
   already opens; the `customSelect` precedent is corrected to
   `api/database/database.dart` (Architecture 12).
3. The desktop toolbar button had no seam, and the chrome type was left
   conditional. Applied: `SessionDetailHeaderBuilder` gains `onShowPrompts`
   beside `onShowDiffs`, both shells updated in lockstep by step 11, and no new
   chrome field — the Prompts layer draws its own header on both shells
   (Architecture 10).
4. PLAN and TRACKER named different owners for the layer. Applied:
   `_SessionDetailBodyState` owns the layer, the open flag, the transition
   controller and the jump notifier; `SessionDetailLoadedView` only forwards.
   The TRACKER guardrail now says the same.
5. `TranscriptJumpController` used a suffix the conventions do not mandate.
   Applied: renamed `TranscriptJumpNotifier` in `transcript_jump_notifier.dart`,
   following `ScrollFollowTracker.scheduleJumpToEdge()`.
6. Day grouping was undefined for an untimed opener. Applied: every entry
   carries a `dayKey`; a timed entry gets its own day, an untimed follow-up
   inherits its opener's, an untimed opener gets none, and the null group renders
   under a "No date" header (Architecture 10). Round 4 then moved that group to
   the **top** of the list, where D39's chronological order puts older prompts.
7. Accuracy note: the shipped `TranscriptTurnSummary` has only `steps` and
   `outcome`. Applied: the invented `failedSteps` member is gone from
   Architecture 1, the Architecture 9 removal inventory and the cleanup
   assessment.

Neither revision was re-reviewed after its fixes; this record does not claim
either passed.

**Codex review of the merged plan, PR #1753, 2026-09-26:** ten findings, all
valid. Nine are applied here. The excerpt rule is applied in #1754.

1. P1, fold state in the cubit. Applied: `SessionDetailCubit` holds the fold
   state and its single intent, which reports analytics. This supersedes item
   5's body setter and the forwarded listenable (Architecture 3).
2. P1, folding after Claude parity. Applied: step 4 needs step 3 (Delivery
   Rules, tracker).
3. P2, regression docs per step. Applied: steps 6 to 9 each update the
   documents, step 10 reconciles them, and the docs-only step is gone
   (Regression Coverage).
4. P1, sticky semantics. Applied: while pinned, the prompt is a labelled button
   that jumps to its opener (Architecture 6, Approved Copy).
5. P1, convergent jump. Applied: a directional search from the built rows with
   a stated termination argument, reusing the diffs view's two-pass settle
   (Architecture 4).
6. P2, place-keeping before any control. Applied: step 4 ships no control, and
   the controls move to a new step 6 after place-keeping (Architecture 3,
   Steps).
7. P2, analytics with the first control. Applied: the event lands in step 6
   (Analytics).
8. P2, running before the first step. Applied: plain "Running" (D16, Approved
   Copy, step 4 tests).
9. P2, folded copy without a duration. Applied: the done row drops it and its
   separator (Approved Copy, step 4 tests).
