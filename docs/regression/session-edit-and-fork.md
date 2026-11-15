# Session Edit And Fork

## Capability

Every user prompt with text, command card with arguments and agent reply in a
transcript has a message menu, on phone and desktop alike, and so do queued
prompts and the pinned prompt. It holds what can be done with that message:
today Copy and Select text. The menu is client-only; it sends nothing to the
bridge.

The bridge can edit a prompt that opens a turn: `POST /session/rewind` removes
that prompt and every later message from the session's conversation and sends
the edited prompt in its place. Conversation only: files are never restored.
Each harness declares the branching operations it implements in
`PluginMetadata.sessionBranching`; today only Codex declares `rewind`.
Clients offer no Edit yet.

## Required Behavior

### Message menu

- Under a finger or stylus, a long-press of about 0.4 s on a user bubble, a
  command card, a queued prompt or an agent reply opens a flat menu anchored
  to the message. It
  gives a light haptic and keeps the message sharp while the rest of the
  screen blurs back. Under a mouse or trackpad, a secondary click opens the
  compact menu at the pointer, with no blur and no haptic.
- The menu never moves the transcript. While it is open the transcript holds
  still, as when reading history, so a reply streaming in neither grows past
  its cut-out nor carries the message out from under the menu. Opening the
  menu does not bring up the Jump to latest pill; a reader already in history
  keeps theirs. Once it closes, a transcript that was following the latest
  edge follows it again and shows what streamed meanwhile, even when the
  message itself went while the menu was open (a queued prompt delivered).
- The pinned prompt's cut-out matches its bubble or card.
- While some of the message's text is selected, the copy item reads "Copy
  selected text" and copies only the selection. Opening the menu, closing it
  and copying all leave that selection highlighted exactly as it was: a
  shift-click afterwards extends it, and a click elsewhere still clears it. With nothing selected the item reads "Copy" and
  copies the message's Markdown: a user prompt's text or a
  command's arguments, or the reply's text parts joined by blank lines, with
  streamed text as shown. A "Copied to clipboard" alert confirms it. A reply
  with no text has no Copy.
- Select text closes the menu and selects all of the message's text, with the
  selection's handles and toolbar. Tapping elsewhere clears that selection.
- A long-press or right-click on the pinned prompt opens that prompt's menu,
  never the menu of the message under the pin. It has only Copy, which copies
  the whole prompt, not the pin's cut copy; a tap on the pin still jumps to
  the prompt.
- A prompt with only attachments, or a command with no arguments, has no menu:
  there is nothing to copy or select.
- A long-press no longer selects a word. A held primary mouse button on a
  message still drag-selects, and a secondary click wins over the selection
  area's own right-click toolbar.
- Taps, one-finger scrolls, the timestamp peek, a code block's horizontal
  scroll and a pinch to Prompts all behave as before when they move or add a
  finger before the long-press fires.
- A session row's long-press and right-click menu uses the same trigger, and a
  screen reader still offers the row's long-press as an action on the row.
  A click opens the session; holding the mouse button down on a row does
  nothing, with no menu and no highlight, since rows are not selectable text.
- A screen reader offers the pinned prompt's menu as a long-press around the
  pin, which it can still activate to jump.

### Bridge edit route

- The edit runs on the session's lane, so it never interleaves with a send,
  stop or archive of the same session.
- An archived session answers the archived read-only rejection without
  reaching the plugin.
- The request carries a client-generated prompt id. A repeat of an accepted id
  succeeds without reaching the plugin, even after the rewind removed the
  edited message.
- A running session is refused with `sessionBusy`. This and the turn checks
  below run before anything changes, a pending quota auto-continuation
  included.
- The bridge reads the whole stored transcript, backfilling it first when the
  store is behind the backend, and finds the message's turn by the shared
  `splitPromptTurns` rule. A message that does not open a turn (a reply or a
  follow-up) and the first turn are refused with `branchPointUnavailable`.
  First-turn edits arrive with a later step that swaps in a fresh harness
  session.
- A harness that cannot rewind, or whose plugin cannot map the message to a
  native boundary, is refused with `branchPointUnavailable`. The plugin's own
  user-facing sentence travels as the message; transcript text never does.
- Stale prompt options answer `staleSessionOptions` after the options cache is
  invalidated; a plugin refusal answers `refused`.
- Every branch refusal is a 409 `SessionBranchErrorResponse` and leaves the
  transcript untouched; the archived rejection keeps its own shared shape.
- After the plugin accepts, the bridge removes exactly the messages it read
  before the call, by id, from the store and from clients
  (`message.removed`). The edited prompt's echo, captured during the call, is
  never among them.
- When the plugin fails after it may have rewound (anything other than a
  branch-point, stale-options or refusal rejection), the bridge reads the
  harness transcript once and removes, by exact id, the messages it read
  before the call that the harness no longer has, then returns the failure.
  A failure that changed nothing, or a harness read that comes back empty,
  removes nothing.
- An edit with no parts is rejected with 400 before anything changes.

### Codex edit

- The edit maps the message to its native turn from the rollout's
  `UserMessage` items, resumes the thread if needed, calls
  `thread/revert {beforeTurnId}`, then starts the edited turn with the same
  prompt id. History follows the reverted rollout as soon as the edit is
  accepted.
- Refused with a plain reason without changing the conversation: a runtime without
  `thread/revert` (for example 0.139.0), a legacy non-paginated thread, an
  ephemeral thread, an id the rollout does not have, a follow-up steered into
  a running turn, and an attachment or option the turn cannot take.
- If `turn/start` fails after the revert, the bridge reconcile above removes
  the reverted messages; the edit still fails and the client keeps its text.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Message menu, automated widget tests: under touch, a long-press opens the spotlit menu with a light haptic and no word selection, while a tap and a drag open nothing; under a pointer, a secondary click opens the menu at the click with no spotlight, sees the drag selection made before it, keeps the selection toolbar shut, and a held primary button opens nothing; Copy copies the Markdown or the selection and shows its alert; Select text selects the whole message; under a pointer, a selection survives the menu opening and closing, a shift-click afterwards extends it, and the item reads Copy selected text and copies only it; the reply's Markdown joins its text parts; a long-press on the pinned prompt copies that whole prompt, not the reply under it, and a screen reader reaches that menu; an open menu holds a streaming reply still and the list follows again once it closes, even when the item went meanwhile. Bridge edit route, automated bridge tests with a fake rewind plugin: a later-turn edit removes exactly the read messages and keeps the echo captured during the call; a repeated prompt id succeeds without a second rewind; busy, non-opener, first-turn, no-rewind harness, plugin branch-point, stale-options and archived refusals reach the right code before any change; a partial store backfills before validation; the route answers a refusal with a 409 `SessionBranchErrorResponse`; a failed resend after the harness rewound removes exactly the dropped messages, and a failure that changed nothing removes none. Codex plugin tests against a fake app-server: resume, revert and `turn/start` order with the prompt id; history follows the reverted rollout; steered, unknown-id, attachment and revert-error refusals happen before any revert. |
| L3 Release | On a headless iOS simulator and on macOS: long-press and right-click a prompt and a reply, Copy each, and use Select text, while text streams and while reading history; the transcript must not move. On macOS, drag-select part of a reply, right-click it, and check the highlight stays through the menu; hold the mouse down on a session row and check nothing happens. The edit route is not included until clients offer Edit. |
| L4 Extended | Long-press a message near the screen's edges and at the largest text size; open the menu during a pinch, a peek and a code-block scroll. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Try messages that are only an image, a command with no arguments, a reply
that is only tool steps, and a reply still streaming. Try a long-press with a
slight finger drift, and a right-click with a selection that spans two
messages. Long-press a pinned prompt over a reply, and a pin whose prompt is
not loaded yet.

## Failure Signals

- The transcript scrolls, jumps or stops following when the menu opens or
  closes.
- A long-press selects a word or shows the selection toolbar instead of the
  menu, or a right-click shows the selection toolbar.
- Copy copies the wrong message, stale streaming text, or the whole message
  while a part of it was selected.
- Select text leaves nothing selected, or the selection vanishes as the menu
  closes.
- A tap, scroll, peek, pinch or code-block scroll opens the menu.
- An edit removes the edited prompt's echo, or leaves a removed message on
  screen until reload.
- A retried edit rewinds twice.
- A refusal changes the transcript, or its message carries transcript text.
- A Codex edit whose resend failed leaves the reverted messages on screen.
- An edit reaches the plugin while the session runs or after it was archived.

## Known Limitations

- Select text selects the whole message, not the word under the press:
  Flutter has no public API to select a word at a point.
- A pinned prompt that is not loaded yet has no menu, since only its start is
  known; a long-press on it reaches the message under the pin.
- A long-press tooltip inside a message no longer shows, because the menu
  takes the long-press first.
- Only Codex implements rewind; every other harness refuses the edit.
- The first turn cannot be edited yet.
- An edit the plugin refuses keeps the attachment files the bridge saved for
  it, as a refused send does.

## Sources

- `client/module_prego/lib/interactions/prego_context_menu.dart`
- `client/module_prego/lib/components/prego_readable_selection_area.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/transcript_message_menu.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/session_detail_message_list.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/user_message_card.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/queued_message_bubble.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/transcript_sticky_prompt_overlay.dart`
- `client/module_app_ui/lib/src/features/session_list/session_tile.dart`
- `bridge/sesori_plugin_interface/lib/src/session_rewind_plugin_api.dart`
- `bridge/app/lib/src/routing/rewind_session_handler.dart`
- `bridge/app/lib/src/services/session_prompt_service.dart`
- `bridge/app/lib/src/services/chat_history_service.dart`
- `bridge/sesori_plugin_codex/lib/src/services/codex_session_service.dart`
- `bridge/sesori_plugin_codex/lib/src/repositories/codex_message_repository.dart`
- `shared/sesori_shared/lib/src/models/sesori/session_branch_error_response.dart`
