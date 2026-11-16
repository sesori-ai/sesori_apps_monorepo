# Side Questions

## Capability

A side question asks the session's harness something about the session
without touching it. The answer comes from what the session already knows: it
runs no tools, leaves a running main turn alone and never reaches the main
transcript or the harness's own session files. Questions and answers live in
side chats: a session can hold several, and each passes its earlier exchanges
to the harness as history.

The bridge serves `POST /session/side-chats` (a session's stored side chats)
and `POST /session/side-question` (ask, in a new or an existing side chat). It
stores each answered exchange in `side_chat_exchanges`; a refused or failed
ask is not stored. Each plugin answers through `SideQuestionPluginApi`. Claude
Code and Codex answer natively; see the Side questions section of
[HARNESS_CAPABILITIES.md](../HARNESS_CAPABILITIES.md) for the seams, versions
and every other harness. Bridge logs never contain question or answer text.

Clients read `PluginListResponse.supportsSideQuestions` and the harness's
declaration into a `SideQuestionAvailability`: `available`,
`bridgeUpdateRequired`, `harnessUnsupported` or `unresolved`.

## Required Behavior

### Bridge

- An ask runs while the main turn streams and does not queue, delay or
  interrupt it. The main turn's messages, the Claude Code `.jsonl` and the
  Codex rollout never contain the question or answer.
- A follow-up passes the side chat's earlier exchanges, oldest first, as
  history. Codex puts them in its 4,000-byte prompt and trims the oldest text
  first.
- An answer is stored with its question and optional notice and returned with
  its side chat id. A refusal (`harnessUnsupported`, `harnessUpdateRequired`,
  `noTurnYet`, `tooLong`, `noAnswer`) and a failure store nothing. A refusal
  reason from a newer bridge reads as `unknown` on an older app.
- Closing the client while an ask waits does not cancel it: the answer is
  still stored. Claude Code's ask ends with a cancel after Sesori's 3-minute
  wait.
- Side chats list newest first, each titled by its first question. An
  archived session keeps its side chats readable and refuses a new ask.
  Deleting a session deletes its side chats.

### Entry points

- The composer's options pill holds a side-question button beside `+` and
  `/`, on phone and desktop. On a phone it folds behind the chevron while
  typing, like its neighbours. Sub-agent sessions have no button.
- On a session that is not `available` the button still shows, and a tap
  answers with the reason: "Update Sesori on this computer to ask side
  questions." for an older bridge, or "<Harness> can't answer side questions
  in Sesori yet." While `unresolved` it holds its place, disabled.
- Typing "/btw " (any letter case) at the start of the composer, on an
  `available` session, enters side-question mode. The prefix leaves the field
  with the caret after the remaining text; the strip above the input shows a
  "Side question" label with ✕ and the field's border darkens, eased, without
  the transcript moving. ✕, or Backspace in an empty field, returns to the
  normal composer with the text kept; picking a command or an attachment also
  leaves the mode.
- Send in the mode sends no prompt. It clears the composer and opens the sheet
  or panel on a new side chat asking the text.
- The `/` picker lists "btw: ask a side question" first for an empty query and
  after the matching commands once a search is typed. Picking it enters the
  mode and keeps the field's text. While a command or images are staged,
  neither way enters the mode and the row is hidden.
- On a session that is not `available`, "/btw " is plain text sent to the
  harness and the picker has no btw row.
- A restored draft comes back as plain text, never in the mode.
- An archived session with stored side chats shows a "Side chats (N)" link in
  its archived notice, fading in without moving the notice's text. It opens the
  newest chat read-only. With none, a failed listing or an older bridge, there
  is no link.

### Phone sheet

- The sheet rests at half or full height (below the status bar), follows the
  finger while dragged, and on release snaps by position and velocity: up to
  full, down to half, and down from half closes it. Reduced motion changes
  height without the spring.
- The scrim is light at half height and deepens toward full; a tap on it
  closes the sheet. The session page stays mounted, streaming and at its
  scroll position.
- The keyboard lifts the sheet's input. A keyboard already closing as the
  sheet opens slides away beneath it, and the composer behind stays where it
  was while the sheet is open and as it closes, with no creep or dip.

### Desktop panel

- The panel floats over the session page's trailing edge and slides in by
  transform; the transcript and composer neither move nor reflow, and the page
  beside it keeps taking clicks, scrolls and typing. Escape and its close
  button close it, and switching sessions closes it. A `/btw` question
  replaces an open panel's chat with a new one asking it. See
  [desktop-cockpit-shell.md](desktop-cockpit-shell.md) for focus, the
  connection pill and pushed pages.

### Side chat

- The header reads "Side question", or a reopened chat's first question.
  "Earlier (n)" opens this session's earlier side chats in place, newest first;
  "New" starts a new chat.
- A question is a compact bubble and its answer renders as transcript Markdown,
  with Copy; a notice is a small caption.
- While waiting it shows "Thinking…", then the whole answer at once. A refusal
  or failure replaces that row in place with its reason and Retry, and the
  question stays in the field.
- A new exchange slides in at the bottom; the list follows only a reader
  already at the bottom.
- Closing the sheet or panel while waiting, then reopening the chat, shows the
  answer.
- An archived session's chats are read-only: "This session is archived. Its
  side chats are read-only." replaces the input.
- Each ask reports one `side_question_asked`; see [analytics.md](analytics.md).

## Regression Levels

| Level | Additional coverage |
| --- | --- |
| L1 Smoke | Not included. |
| L2 Routine | Automated: bridge route, repository and migration tests (`side_question_handlers_test`, `side_chat_repository_test`, `side_chat_exchanges_migration_test`) cover the routes, refusals, storage, history order, archived read-only and delete cascade; Claude Code (`claude_stream_client_test`, `claude_side_answer_mapper_test`) and Codex (`codex_side_questions_test`, `codex_side_question_prompt_builder_test`) plugin tests against fakes; client `side_chat_cubit_test`, `session_detail_side_question_test`, `side_chat_view_test`, `prego_detent_sheet_test`, `side_chat_keyboard_hold_test`, `command_picker_test` and `desktop_session_detail_screen_test`; one `side_question_asked` per ask with bounded parameters. |
| L3 Release | Live Claude Code and Codex: ask while the main turn streams and check it finishes normally; a follow-up uses the history; an ask after a cold resume answers; the `.jsonl` and the rollout are unchanged, and an over-budget Codex history is trimmed. On a headless iOS simulator, against Claude Code and Codex: both entries (button, and "/btw " with ✕ back keeping the text, and the picker row); sheet heights and drag; ask during streaming and follow up; reopen an earlier chat; close while waiting and reopen to see the answer; no main-transcript jump; the tap reason on an unsupported harness and on an older bridge. On macOS: the panel slides in without the transcript moving, answers a question and a follow-up, and closes on Escape and on a session switch. |
| L4 Extended | Very long questions and answers, the largest text size, a reopened chat with many exchanges, and an ask on a session with no turn yet. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Ask while the main turn is mid-tool-call and while it streams a long reply.
Close and reopen the sheet repeatedly while an answer is pending. Type "/btw"
without the space, "/BTW " and "/btw " in the middle of text. Send from the
mode with the keyboard up, and drag the sheet while the keyboard is open.

Setup: two bridges signed in to the same account share a bridge id, so the
second replaces the first (close code 4007). To check the update reason
against an older bridge, give it its own dev account or stop the current
bridge first.

## Failure Signals

- The main turn is interrupted, delayed or queued by an ask.
- Side question or answer text shows in the main transcript, the harness's
  session file or the bridge log.
- An ask runs a tool.
- An answer is lost after closing the sheet or panel while waiting.
- The main transcript scrolls or jumps when the sheet or panel opens, closes or
  receives an answer, or the composer behind the sheet creeps or dips.
- A tap on the side-question button, or on Send in the mode, does nothing.
- "/btw " is sent to the harness as a prompt on an `available` session, or
  composer text is lost when leaving the mode.
- A refused or failed ask is stored, or loses the typed question.
- An archived session accepts a new ask, or a deleted session leaves side
  chats behind.

## Known Limitations

- Only Claude Code and Codex answer side questions. Other harnesses answer the
  button tap with the reason; a fork-based fallback is a later phase.
- Answers never stream: every harness returns the whole answer at once.
- On Claude Code, a mid-turn ask sends the model the running turn's prompt
  as well. A non-Claude model behind a proxy sometimes answers that prompt
  instead of the question (see HARNESS_CAPABILITIES.md). Run the mid-turn
  Claude Code check with a real Claude model before reading such an answer
  as a Sesori failure.
- The side chat input takes no voice, attachments or commands.

## Sources

- `docs/HARNESS_CAPABILITIES.md`
- `shared/sesori_shared/lib/src/models/sesori/side_chat.dart`
- `bridge/sesori_plugin_interface/lib/src/side_question_plugin_api.dart`
- `bridge/sesori_plugin_interface/lib/src/models/plugin_side_question.dart`
- `bridge/app/lib/src/routing/ask_side_question_handler.dart`
- `bridge/app/lib/src/routing/get_side_chats_handler.dart`
- `bridge/app/lib/src/services/side_question_service.dart`
- `bridge/app/lib/src/repositories/side_chat_repository.dart`
- `bridge/app/lib/src/api/database/tables/side_chat_exchanges_table.dart`
- `bridge/sesori_plugin_claude/lib/src/api/claude_stream_client.dart`
- `bridge/sesori_plugin_claude/lib/src/repositories/mappers/claude_side_answer_mapper.dart`
- `bridge/sesori_plugin_codex/lib/src/services/codex_side_question_prompt_builder.dart`
- `client/module_core/lib/src/foundation/models/side_question_availability.dart`
- `client/module_core/lib/src/cubits/side_chat/side_chat_cubit.dart`
- `client/module_core/lib/src/repositories/side_chat_repository.dart`
- `client/module_prego/lib/components/surfaces/prego_detent_sheet.dart`
- `client/module_app_ui/lib/src/features/side_chat/show_side_chat_sheet.dart`
- `client/module_app_ui/lib/src/features/side_chat/side_chat_view.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/command_picker.dart`
- `client/desktop/lib/features/sessions/desktop_side_chat_panel.dart`
