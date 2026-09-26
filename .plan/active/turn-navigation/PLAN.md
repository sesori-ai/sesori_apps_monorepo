# Turn Navigation: Folded Turns, Sticky Prompts And Pinch

## Status

- **Plan slug:** `turn-navigation`
- **Created:** 2026-09-26
- **Origin:** visual-hierarchy step 37 ("turn navigation: discussion and
  prototypes"). That step was left out of the series and "becomes its own plan
  once the user picks a direction" (`.plan/completed/visual-hierarchy/TRACKER.md`).
  The user picked the direction on 2026-09-25, so this is that plan. Every PR,
  including this first one, uses the `turn-navigation` slug.
- **Series:** ten PRs in one phase. The titles are fixed in
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

## Goal

In a long session it is hard to find your own prompts. The goals:

- A pinch folds every answer into one line and unfolds it again.
- The prompt of the turn you are reading stays pinned at the top.
- On desktop, a compact index lists the session's turns and jumps to them.

The first phase is client-only. It works on the loaded messages, and the bridge
and plugins learn nothing about turns.

## Current Behavior (origin/main at 420f70aa89, 2026-09-26)

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

## Decisions

User decisions of 2026-09-25, from the review of round 3:

- **D1 R5 chat-native folded turns.**
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
- **D6 Desktop D2.**
  - The same R5 list with sticky prompts.
  - An always-visible compact R6 index on the right: one dense line per turn.
    It follows the scroll, and a click jumps to the turn.
  - Trackpad pinch, plus a toolbar control and a keyboard shortcut.
- **D7 Deck mode** (turn by turn) is a later phase.
- **D8 Phase 1 is client-only, over loaded turns.** F1 (turn index) and F2
  (fetch one turn) are later phases.

Defaults this plan adopts. **Each is a default the user may override:**

- **D9 One fold state for the whole transcript.**
  - Tapping a folded turn unfolds every turn and keeps that turn in place. So
    does clicking an index line while folded.
  - The mock's per-turn tap-to-fold is deferred.
  - Why: a global state has no per-id entries to strand when a re-sync changes
    ids, and it is the smallest state.
- **D10 A fold button in the bar on both shells.**
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
- **D13 Loaded turns only, labelled honestly.**
  - A partial oldest turn shows what is loaded and says so.
  - The desktop index lists loaded prompt turns, under a "Load earlier turns"
    row while older pages remain.
  - Turn numbers wait for F1, because absolute numbering is unknown until then.
- **D14 One analytics event**, `transcript_turns_folded` (see
  [Analytics](#analytics)).
- **D15 The sticky prompt shows only while turns are unfolded.** It is clamped
  to three lines, and a tap scrolls its prompt to the top.
- **D16 A running turn's stub shows "Running · step {n}"** without the mock's
  live clock, so there is no timer. Before the turn's first step it shows
  plain "Running", never "step 0".
- **D17 Follow-ups fold inside their turn.** They do not change the stub.
- **D18 The desktop index shows only when the detail area is at least 1,000 px
  wide** (the 760 px column plus a 240 px pane). Below that, the button and the
  shortcuts still work. The mock says "hide the index below about 1000 px".

Planning decisions, from code evidence and the spikes:

- **D19 The sticky prompt is an overlay over the existing reversed lazy list.**
  It is not built from slivers. See [Architecture 6](#6-sticky-prompt-step-8).
- **D20 Pinch uses an eager two-pointer scale recognizer.** See
  [Architecture 5](#5-pinch-step-7).
- **D21 Place-keeping uses a registry of built rows and a convergent
  scroll-to-row helper.** Nothing positions rows by index arithmetic alone.
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
- F1 and F2, and any other wire or storage change.
- Per-turn fold, and persisting fold state.
- The mock's alt+↑/↓ prompt stepping on desktop (see Open Questions).
- A phone index or density switch.
- A fold animation, and a live clock on the running stub.
- The "stopped" state.
- A steer flag on the wire, and timestamp heuristics.
- A non-reversed or sliver rebuild of the list.
- Claude's live-only `isMeta` user bubbles (see Open Questions).
- The pre-existing gap-or-duplicate hazard when older pages merge after a
  re-import.

## Architecture

Dependencies keep the existing direction. The pure turn model sits in
`module_core` next to `TranscriptBuilder`, and the fold state is
`SessionDetailCubit` state. The shared widgets are in `module_app_ui`,
including the phone bar, which the shared `SessionDetailBody` builds.

The desktop shell does two things:

- it places its toolbar button through the header builder;
- it supplies the shortcut activators with its own platform check.

Client code uses neutral message fields only, with no harness names or backend
fields. New widgets live in
`client/module_app_ui/lib/src/features/session_detail/widgets/`, one class per
file, as named below. The registry, the pending anchor and the scroll-to-row
helper stay private to the list state.

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
  - The "ends in" test uses the last content part of the latest agent message:
    non-empty text or reasoning, a tool, a sub-agent or a file.
  - It reads `ToolStatus` directly, because `TranscriptStepStatus` folds
    cancelled into finished.
- `TranscriptTurnSummary`, shared by every variant, holds:
  - `steps`: every step in the turn's step groups, running steps included.
  - `failedSteps`: the sum of the groups' `failedCount`.
  - `outcome`, a sealed type:
    - running: the newest turn while `isBusy`;
    - failed: the turn's last non-automation message is a `MessageError`.
      Carries the first line of `errorMessage`.
    - done: carries the first non-empty line of the last stored text of the
      turn's agent messages, or null when there is none.

    Streaming text is not read.
- Tests (`client/module_core/test/cubits/session_detail/transcript_turns_test.dart`):
  - every D11 branch;
  - automation between a tool step and a user message;
  - automation first, with and without older pages;
  - hidden user messages;
  - the summary fields, running and failed;
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

Step 4 adds the state and the folded rows but no control, so nothing changes
for users until place-keeping (step 5) exists. Step 6 adds the controls.

- **Fold state (step 4).** It is session page state, so `SessionDetailCubit`
  owns it.
  - `SessionDetailLoaded` gains `@Default(false) bool transcriptFolded`.
  - The cubit keeps a private `_transcriptFolded` field and seeds every loaded
    state it builds with it in `_buildLoadedState`
    (`session_detail_cubit.dart:2939`), as it already does for
    `isUpdatingAutoContinuation`. A full reload emits
    `SessionDetailState.loading()` first, so the field carries the state
    across it. Copies of a loaded state keep it on their own.
  - One intent, `setTranscriptFolded({required bool folded})`, is the single
    entry point for every control. It updates the field and, while loaded,
    emits the switched state. A request that changes nothing emits nothing.
    From step 6 it also reports the analytics event.
  - Widgets observe the state and dispatch the intent directly. The bars
    already read `SessionDetailCubit`, and `SessionDetailLoadedView` passes
    `state.transcriptFolded` and the intent to `SessionDetailMessageList`, as
    it passes `loadOlderMessages` today. No notifier or setter is forwarded,
    and `SessionDetailHeaderBuilder` is unchanged.
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
  - The helper calls `detach()` before moving away from the latest edge.
    Otherwise `scheduleJumpToEdge()`, which runs on every build while
    following, would pull the list back.
- **Anchor rules.**
  - While following, a switch keeps following.
  - Otherwise the anchor is the top-edge turn (button or shortcut) or the
    tapped turn (stub).
  - If the anchor's opener row is on screen, it keeps its distance from the top
    edge.
  - If the reader is mid-turn (the opener is above the edge), the opener lands
    at the top edge.
- **Capture.** Every switch goes through the cubit's intent.
  - Triggers inside the list (stub tap here, then pinch and index click) set
    the pending anchor for their turn, then dispatch the intent through the
    list's callback. They do this only when the fold state actually changes.
  - The list sees the switch in `didUpdateWidget`, when `transcriptFolded`
    changes. That runs before the new layout, so when no anchor is pending it
    captures the top-edge turn from the last frame's layout. That covers the
    buttons and the shortcuts of step 6.
  - A post-frame pass then restores the anchor.
- **Pending anchor.** One nullable target. It clears once its row settles, or
  when its row id disappears.
- **Stub tap.** Unfolds every turn and anchors on the tapped turn (D9).
- **`onJumpToTurn`.** The list builds one private callback,
  `onJumpToTurn({required String openerMessageId})`, and later hands it to the
  sticky overlay and the index.
  - Folded: unfold, anchored on that turn.
  - Unfolded: scroll the opener to the top edge.

### 5. Pinch (step 7)

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
    that turn's opener row is above the top edge or not built.
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
- A one-frame lag is accepted. Move to a render object only if a device shows
  the lag.

### 7. Desktop index pane (step 9)

- **When it shows.** The loaded view already knows `maxContentWidth` (page
  chrome). When the width is at least `maxContentWidth + 240`, it reserves a
  240 px pane at the end:
  - start inset = max(0, (width − 240 − 760) / 2);
  - end inset = start inset + 240.

  The list and the composer take these asymmetric insets. Below the threshold,
  today's symmetric insets apply and no pane shows.
- **Where it renders.** The list draws the pane inside its end inset, clear of
  the scrollbar.
- **The current turn.** The list publishes a second value, a
  `ValueNotifier<String?>` holding the opener id of the prompt turn at the top
  edge.
  - It is computed in the same post-frame pass as the sticky value, in both
    fold modes. A stub row maps to its turn's opener.
  - It is null for partial and preamble segments.
  - The index reads only this value, never the sticky one.
- **The pane.** `TranscriptTurnIndexPane` (`transcript_turn_index_pane.dart`),
  a `StatefulWidget` that owns its `ScrollController`.
  - Inputs: the `TranscriptTurns`, the current-turn
    `ValueListenable<String?>`, the list's `onJumpToTurn`, the nullable
    `onLoadOlderMessages` and `isLoadingOlderMessages`.
- **Lines.**
  - One line per loaded prompt turn, oldest first: the first line of the
    prompt, a running or failed glyph, and the prompt's time.
  - The current turn is highlighted and kept in view through the pane's
    `ScrollController`.
  - A click calls `onJumpToTurn`: while unfolded it puts the opener at the top
    edge; while folded it unfolds and anchors on that turn (D9).
  - Partial and preamble segments get no line.
- **"Load earlier turns".** A top row shown while `onLoadOlderMessages != null`.
  A click loads one older page through that callback, and the row is disabled
  while `isLoadingOlderMessages`.

### 8. Re-sync, replacement and id changes (all steps)

Turns are recomputed from the rendered messages on every build, so no turn
state can go stale. What outlives a build is small and global:

- the fold flag, held by the cubit;
- one pending anchor;
- the sticky value (step 8) and the current-turn value (step 9), both
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

## Approved Copy

The copy comes from the chosen round-3 mock, recorded here because the page
stays local.

- `{n}` counts steps.
- `{duration}` reads like "1m 02s".
- Steps 4, 6, 8 and 9 add these strings to `app_en.arb`. Review may polish
  the wording, but not the meaning.

| Element | Copy |
|---|---|
| Folded stub, done | "› {n} steps · {duration} — {first line of the final answer}". Use "1 step" and "No steps". Drop the dash and excerpt when there is no text. When the duration is null, drop it and the " · " before it: "› 3 steps — {excerpt}", or "› 3 steps". |
| Folded stub, running | Running glyph, then "Running · step {n}". Before the first step, plain "Running". The mock's live clock is dropped (D16). |
| Folded stub, failed | Error glyph, then "Ended with an error · {first line of the error message}" |
| Folded stub, partial segment | Planning copy, not in the mock: "Earlier turn, partly loaded · {n} steps" |
| Folded stub, preamble | Planning copy: "Before the first prompt · {n} steps" |
| Fold button | "Fold all turns" / "Unfold all turns". On desktop the tooltip adds the shortcut. |
| Sticky prompt, screen readers | Planning copy: the label is the text it shows; the tap hint is "Jump to this prompt". |
| Desktop index | Top row "Load earlier turns", with the hint "Older turns appear as their pages load". Each line: the first line of the prompt, a glyph, the time. |

The mock's "Stopped by you" line is not shown in phase 1 (D12).

## Analytics

Checked against `.opencode/skills/add-analytics/SKILL.md`.

- **The event.** One account-linked adoption event,
  `transcript_turns_folded`, with no parameters. It is sent on every switch
  from unfolded to folded, from any control.
- **The decision it informs.** Whether folding is used enough to justify F1,
  F2, deck mode, and more navigation surfaces.
- **The seam.** The skill's reactive-state seam, as a bounded transition
  guard. Cubits are the analytics consumer layer, and the cubit owns the fold
  state. So `SessionDetailCubit.setTranscriptFolded`, the single entry point
  for every control, reports through `_reportProductEvent`
  (`session_detail_cubit.dart:2506`) only when the state changes from
  unfolded to folded. A repeated fold request sends nothing.
- **When.** Step 6, the first step that exposes a fold control, so no control
  ever folds without it.

  The event model is `product_analytics_event.dart`. Test it in
  `product_analytics_event_test.dart` and a cubit test.
- **Not tracked.** Unfolding, which control was used, sticky taps and index
  clicks.
- **Desktop.** Nothing is sent: the desktop's `AnalyticsClient` is the no-op
  one, the same limit the desktop-sign-in plan accepted.
- **Follow-up.** The curated warehouse transform lives in the private
  `sesori_analytics_platform` repository. Raise it there when step 6 merges;
  this plan does not claim it.

## Security And Privacy

- Phase 1 changes no wire contract, storage or bridge behavior. The one
  exception is the Claude mapping fix. That fix reads records already on disk
  and maps them to the same neutral messages the live path emits.
- Stubs, the sticky header and the index show only text the transcript already
  shows. Fold state lives in memory for one page.
- The analytics event carries no content, ids, counts or timing.
- This plan's evidence kept only aggregate counts from local stores. No
  content, paths or ids were recorded.

## Complexity Budget

New mutable parts:

1. **The fold flag in `SessionDetailCubit`** (step 4): one private field that
   seeds `SessionDetailLoaded.transcriptFolded`. One shared state for every
   control on both shells, surviving reloads.
2. **The row registry `Map<String, BuildContext>`** (step 5). It is the only
   reliable way to find built rows for anchors, the sticky header and the index
   highlight.
3. **The pending anchor**: one nullable target (step 5).
4. **Per-gesture pinch fields** (step 7): switched-this-gesture,
   started-following and detach-suppressed.
5. **The sticky `ValueNotifier<TranscriptStickyPosition?>`** (step 8), read
   only by the overlay.
6. **The current-turn `ValueNotifier<String?>`** (step 9), read only by the
   index.
7. **The index pane's `ScrollController`** (step 9).

Deliberately not added:

- Per-turn or persisted fold state.
- A fold scope, an `InheritedWidget` or a widget-owned fold notifier; widgets
  read the cubit state and call its intent.
- A turn cache, a navigation controller, or stored turn data.
- Wire fields, and timestamp heuristics.
- A sliver or non-reversed list.
- A fold animation, and a live-duration ticker.
- The stopped state.
- A semantics custom action.
- alt+↑/↓, and a phone index.

## Cleanup Assessment

No relevant cleanup was found:

- Folding reuses the existing rows and `TranscriptSummary` counts.
- Place-keeping reuses `ScrollFollowTracker` and the diffs view's two-pass
  reveal.
- The pinch sits beside the peek.
- Step 3 extends, rather than replaces, the Claude context records.

Each step re-checks this for its own diff.

## Proportionality And Accepted Risk

Evidence levels:

- **Observed.** Rule A, measured on local stores; the Claude replay loss, seen
  in local stores; and the ACP stop-and-send, read from code.
- **Synthetic.** The gesture and sticky behavior come from 56 spike tests in
  Flutter's test harness. Real-device checks are named per step.

Accepted:

- About 2% of ordinary Claude prompts that follow a completed tool step join
  the previous turn.
- The partial oldest turn, and a one-time boundary change when an older page
  loads.
- Two-finger touch scrolling no longer scrolls the transcript.
- Folded mode prefetches older pages after less scrolling, because the
  threshold is in pixels. It still never loads the whole session up front.
- The existing gap-or-duplicate hazard when older pages merge after a
  re-import.
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
| 9 | The desktop index. |
| 10 | Reconciles every document with what shipped. |

Failure signals, each added by the step that ships the behavior:

- step 6: the reading position jumps on fold or unfold; turns split
  differently after a re-import;
- step 7: a pinch scrolls or a scroll folds;
- step 8: a follow-up or automation shows as a sticky prompt;
- step 9: the index lists a turn that is not loaded.

**Highest level: L3 Release.** The boundary is client end to end. It covers
every supporting production plugin for turn grouping, on the release-target
client platform plus macOS for the desktop behavior.

Required matrix, recorded now; any reduction needs the user's acceptance in
this file before retirement:

| Platform | Coverage |
|---|---|
| iOS phone, real device (release target) | Pinch in and out on a session of three or more pages: the turn under the fingers stays in place. The fold button. A stub tap unfolds at that turn. The sticky prompt appears mid-turn, is pushed out by the next prompt, clamps a long prompt, and scrolls to it on tap. A partial oldest turn, then scrolling up while folded loads older pages. A running turn's stub while following. VoiceOver reads the stubs, the fold button and the pinned prompt, and the pinned prompt's action jumps to it. One-finger scroll, the timestamp peek and a code block's horizontal scroll are unaffected. `transcript_turns_folded` arrives. |
| macOS desktop | Trackpad pinch both ways, while following (it stays following) and while reading history (it stays detached). ⌘− and ⌘=. The toolbar toggle. The index follows the scroll, highlights the current turn, jumps on click (folded and unfolded) and loads earlier turns. Below 1,000 px the index hides. Trackpad scroll and the trackpad peek are unaffected. |
| Android phone | Pinch both ways, the fold button, and a sticky prompt smoke check. |
| Windows and Linux desktop | Ctrl+− and Ctrl+=, the toolbar toggle, and an index smoke check. |
| Plugins (live plugin plus client) | A follow-up sent while a turn runs: with Claude, Codex, Pi and OpenCode it stays inside the running turn, and the turn keeps one sticky prompt. With one ACP plugin (the stop-and-send base is shared) it opens a new turn, as the capability doc records. Claude and Pi automation stays inside its turn and is never a sticky prompt. After a forced Claude history re-import, follow-ups, peer messages and task notifications are still present, with the same ids and order. Run together with `session-turns.md`'s busy-send check. |

Automated coverage in the steps:

- the turn model;
- Claude parser and mapper parity;
- the cubit's fold state and analytics event;
- widget tests for folded rows, place-keeping, the pinch arena with touch and
  trackpad variants, sticky push-out and semantics, the index, and the desktop
  shortcuts.

## Delivery Rules

- **Order.** Steps run in order.
  - Step 3 depends only on this plan and may run beside step 2. Step 4 needs
    it, so no folding ships while a Claude re-import still moves turn
    boundaries.
  - No PR exposes a fold control before place-keeping exists. Steps 4 and 5
    add folding and place-keeping without a control, and step 6 exposes them.
  - Steps 7 and 8 both need step 6, which starts the regression document they
    extend, and may run in parallel.
- **Per-step evidence.** Each step verifies this plan's claims before editing.
  It writes its evidence to `steps/step-NN.md` in its own PR, and updates the
  documents for the behavior it ships (see
  [Regression Coverage](#regression-coverage)).
- **Visuals.** Steps 6–9 show before and after screenshots, or a short
  recording for gestures and scrolling. Use fixture sessions only. Steps 4
  and 5 change nothing users can see.
- **Architecture implementation review** for steps 2 to 9: new classes, the
  fold state in `SessionDetailCubit`, the list-state ownership in step 5, the
  chrome activators and the analytics contract in step 6, and the layout
  insets.
- **Size.** Targets are in the tracker. The list, scroll and gesture steps
  (4–9) stay well under the soft cap, and place-keeping (step 5) aims lowest.
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
  - a trackpad pinch while following stays following, and while reading stays
    detached;
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

**Step 9 — desktop index.** [Architecture 7](#7-desktop-index-pane-step-9).
Verify with widget tests:

- the pane shows at 1,000 px and hides below it;
- the list and composer insets;
- the highlight follows the scroll, folded and unfolded, and clears over a
  partial or preamble segment;
- a click jumps when unfolded, and unfolds and anchors when folded;
- "Load earlier turns" calls the loader;
- only prompt turns are listed.

Also by hand on macOS, screenshots, and the index in the regression document.

**Step 10 — reconcile, verify and retire.** Reconcile the regression and
capability documents with what shipped. Run L3 over the recorded matrix,
record the result in `steps/step-10.md`, and move the plan to
`.plan/completed/`.

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
  id. It unfolds an unloaded turn behind a short skeleton.
- **The full-session desktop index** on top of F1, with turn numbers.
- **Deck mode.** Turn by turn, entered from an open turn. Pinch in returns to
  the list.
- **Possibly:**
  - per-turn fold;
  - alt+↑/↓ prompt stepping;
  - a phone density switch (R6 lines) for very long sessions.

## Open Questions

- Defaults D9–D18 stand until the user overrides them. The ones most worth a
  glance:
  - D9: global fold, with no per-turn tap-to-fold yet;
  - D10: ⌘− and ⌘= on desktop;
  - D12: no stopped state until F1;
  - D16: no live clock on the running stub;
  - D17: follow-ups hidden when folded.
- D2's mock also had alt+↑/↓ to step between prompts on desktop. Add it to
  step 9 (about 60 lines)?
- Claude shows some `isMeta` user records live as user bubbles, for example
  image placeholders, skill notices and interrupt markers. History load drops
  them. Fix that separately, as its own PR?
- Can the Windows and Linux rows of the matrix run on real machines?
- Is one `transcript_turns_folded` event the right signal?

## Plan Review Record

**`architecture-plan-review`, 2026-09-26: rejected** with concrete, non-vague
findings, four must-fix and three optional. All seven were applied directly,
without re-review, as AGENTS.md allows.

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

The revised plan has not been re-reviewed; this record does not claim it
passed.

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
