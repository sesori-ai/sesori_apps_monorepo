# Session Edit And Fork

## Capability

Every user prompt and agent reply in a transcript has a message menu, on phone
and desktop alike. It holds what can be done with that message: today Copy and
Select text. The menu is client-only; it sends nothing to the bridge.

## Required Behavior

- Under a finger or stylus, a long-press of about 0.4 s on a user bubble, a
  command card or an agent reply opens a flat menu anchored to the message. It
  gives a light haptic and keeps the message sharp while the rest of the
  screen blurs back. Under a mouse or trackpad, a secondary click opens the
  compact menu at the pointer, with no blur and no haptic.
- The menu never moves the transcript. The message stays where it was, and
  following the latest edge or reading history is left as it was.
- Copy copies the text selected inside the message when there is some.
  Otherwise it copies the message's Markdown: a user prompt's text or a
  command's arguments, or the reply's text parts joined by blank lines, with
  streamed text as shown. A "Copied to clipboard" alert confirms it. A reply
  with no text has no Copy.
- Select text closes the menu and selects all of the message's text, with the
  selection's handles and toolbar. Tapping elsewhere clears that selection.
- A long-press no longer selects a word. A held primary mouse button still
  drag-selects, and a secondary click wins over the selection area's own
  right-click toolbar.
- Taps, one-finger scrolls, the timestamp peek, a code block's horizontal
  scroll and a pinch to Prompts all behave as before when they move or add a
  finger before the long-press fires.
- A session row's long-press and right-click menu uses the same trigger, and a
  screen reader still offers the row's long-press as an action on the row.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated widget tests: under touch, a long-press opens the spotlit menu with a light haptic and no word selection, while a tap and a drag open nothing; under a pointer, a secondary click opens the menu at the click with no spotlight, sees the drag selection made before it, keeps the selection toolbar shut, and a held primary button opens nothing; Copy copies the Markdown or the selection and shows its alert; Select text selects the whole message; the reply's Markdown joins its text parts. |
| L3 Release | On a headless iOS simulator and on macOS: long-press and right-click a prompt and a reply, Copy each, and use Select text, while text streams and while reading history; the transcript must not move. |
| L4 Extended | Long-press a message near the screen's edges and at the largest text size; open the menu during a pinch, a peek and a code-block scroll. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Try messages that are only an image, a command with no arguments, a reply
that is only tool steps, and a reply still streaming. Try a long-press with a
slight finger drift, and a right-click with a selection that spans two
messages.

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

## Known Limitations

- Select text selects the whole message, not the word under the press:
  Flutter has no public API to select a word at a point.
- Opening the menu clears an on-screen selection's highlight, because the menu
  takes the focus. Copy still copies what was selected.
- A long-press tooltip inside a message no longer shows, because the menu
  takes the long-press first.

## Sources

- `client/module_prego/lib/interactions/prego_context_menu.dart`
- `client/module_prego/lib/components/prego_readable_selection_area.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/transcript_message_menu.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/session_detail_message_list.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/user_message_card.dart`
- `client/module_app_ui/lib/src/features/session_list/session_tile.dart`
