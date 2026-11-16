# Session Sending

## Capability

A live root session can be sent into another session, on any harness and
across harnesses. The source's own agent writes a handoff summary in a normal
turn. The bridge saves the source's whole transcript as a Markdown file for
the target, then prompts the target with the summary and the file's path. The
source's turn folds into a one-line marker; the target shows the handoff as a
card. Optionally the source is archived once the target accepts.

Clients send through `POST /session/send-to-session`. It is one long request
that answers once the target has accepted the handoff prompt, or with a
refusal code. No harness offers a native merge, so the bridge core builds the
feature the same way for every plugin. `docs/HARNESS_CAPABILITIES.md`
("Sending a session into another") records how each harness's agent treats
the file and what a prompt to a running target does.

## Required Behavior

### Menu entry

- "Send to another session…" is in the shared session menu, after Mark as read
  or unread and before Archive. That menu backs four surfaces: the phone's
  session row and session page, and the desktop sidebar row and session page.
- Only a live root session offers it. Archived and sub-agent sessions don't.

### Busy source

- A source that is running gets no sheet. A warning alert says "“<source>” is
  still working. Send it when it finishes." and offers Stop for 8 s. Stop stops
  the source; a stop that fails shows "Couldn't stop “<source>”". The user then
  opens the menu again to send.

### Send sheet

- "Send to another session" opens as a bottom sheet under touch and a dialog
  under a pointer. It holds a "To" row ("Choose a session" until one is
  picked), an "Archive this session after sending" switch and a Send button
  that stays disabled until a target is picked.
- The switch is on by default and remembers its last value for the next send.
  It is read before the sheet opens, so it never flips while the sheet slides
  in.
- With the switch on, sending a pinned source first asks the archive
  confirmation for a pinned session. Cancel keeps the sheet open with its
  choice. The archive after the send then asks nothing more.
- Leaving the sheet sends nothing.

### Session picker

- The "To" row opens "Choose a session": a popover under a pointer or on a
  wide layout, otherwise a bottom sheet at 70 % height that keeps its search
  field still while matches narrow. Each opening starts with a blank search.
- With a blank search it lists the newest sessions of every project. Typing
  in "Search sessions" filters the loaded rows at once, then shows the
  bridge's answer. "No sessions match" shows when nothing does.
- The source never lists. Each row shows the session's title over its project
  name, with the project's path only when two listed projects share a name.
- A running session adds what a send does to it, from its plugin's declared
  busy-prompt handling: "Running" where the prompt steers into the running
  turn, and "Running: sending stops its current turn" where it stops the turn.
  A bridge that could not list its plugins shows "Running" for every running
  session.

### Sending and its outcome

- Send closes the sheet and shows a loading alert: "Sending to “<target>”.
  “<source>” is writing a summary first." The outcome replaces it when the
  bridge answers, whichever page the user is on by then.
- Sent: "Sent to “<target>”" with Open, which opens the target in its project.
  With the archive switch on, the alert reads "Sent to “<target>”. Archived
  “<source>”." and offers Open and Undo for the five-second Undo window.
- A bridge without the route (its route-not-found 404) shows "Update Sesori on
  this computer to send sessions." with the bridge-update action.
- No answer (the 16-minute request timeout or a dropped connection after the
  request went out, typically a phone left in the background while the source
  writes) is not a final answer yet. The bridge finishes the send regardless,
  so the app reads the newest messages of both sessions every 10 s, failing
  quietly while it is offline, for up to 15 minutes:
  - The target holding a handoff prompt from the source written after the
    source's newest request for the target, with that request still marked
    sent, shows the Sent alert (an earlier send's prompt doesn't count)
    above, and archives the source when the switch was on, as a direct answer
    would.
  - The source's newest request for the target marked not sent shows
    "Couldn't send “<source>”"; the reason was in the lost answer.
  - When neither shows in time, "Couldn't confirm the send. Check
    “<target>”." with Open. Nothing is archived. Only one of these outcomes
    ever shows for a send.
  - Moving to another computer meanwhile stops the reads and shows nothing.
- A refusal shows its own error text (below). Any other failure shows
  "Couldn't send “<source>”". Neither archives anything.
- When the app has switched to another computer before the answer, nothing
  shows.
- Analytics: see [Analytics](analytics.md) (`session_sent_to_session`).

### Refusals

The bridge answers a send that did not happen with 409 and a
`SendToSessionErrorResponse` code; a missing session answers 404.

| Code | Shown | When |
|---|---|---|
| `sameSession` | Couldn't send: a session can't be sent into itself. | The ids match. |
| `sourceArchived` | Couldn't send: “<source>” is archived. | |
| `targetArchived` | Couldn't send: “<target>” is archived. | Including one archived between the pick and the send, or while the summary is written. |
| `sourceNotRoot` | Couldn't send: “<source>” is a sub-agent's session. | |
| `sourceEmpty` | Couldn't send: “<source>” has nothing to send yet. | The source has no messages. |
| `sourceBusy` | Couldn't send: “<source>” is still working. | It started a turn after the menu was opened. |
| `sourceAwaitingInput` | Couldn't send: “<source>” is waiting for your answer. | A pending permission or question. |
| `sourceUnavailable` | Couldn't send: “<source>” didn't respond. | Its running backend can't report statuses, it refused the summary request, or the bridge is shutting down. |
| `sourceOptionsUnavailable` | Couldn't send: “<source>” uses a model or setting that's no longer available. Send it a message with another model, then try again. | The source's saved options are stale and the bridge's correction could not fix them. |
| `summaryStopped` | Couldn't send: the summary was stopped. | The user stopped the source, archive stopped it, or the bridge shut down. |
| `summaryFailed` | Couldn't send: the summary failed. | The summary turn ended in an error. |
| `summaryTimedOut` | Couldn't send: the summary took too long. | No summary within 15 minutes. |
| `summaryMissing` | Couldn't send: the summary came back empty. | |
| `transcriptUnavailable` | Couldn't send: “<source>”'s conversation couldn't be read. | The history could not be read or the file could not be saved. |
| `targetRefused` | Couldn't send: “<target>” didn't accept it. Or "Couldn't send: <reason>" with the harness's own reason. | |
| `targetOptionsUnavailable` | Couldn't send: “<target>” uses a model or setting that's no longer available. Send it a message with another model, then try again. | As for the source. |
| `unknown` | Couldn't send “<source>” | A code from a newer bridge. |

### Bridge flow

- Validation comes first, in this order: the ids differ, both sessions exist
  and are unarchived, the source is a root, and it has messages.
- Inside one reservation of the source, the bridge refuses a source that is
  busy, retrying or awaiting input, then sends the summary request as a normal
  prompt with the source's remembered prompt defaults. A backend that is not
  running counts as idle. The reservation ends with the send, so the user can
  still stop the turn or answer its questions while the summary is written.
- The request asks the agent for the goal, what was done and decided, the
  current state, open questions, next steps and the files that matter, as the
  summary only and without tools.
- The bridge waits up to 15 minutes for the turn to end, then refreshes the
  source's history and splits it at the request. The transcript is every
  message before the request, without the summary exchanges of earlier sends.
  The summary is the agent's reply text after it, up to the next user message.
  A stop, archive or shutdown mid-summary fails the send, so a half-written
  summary never reaches the target.
- The bridge saves the transcript, then prompts the target with its own
  remembered prompt defaults. The prompt names the source's title, harness and
  directory, quotes the summary, and gives the transcript's path, to read only
  for details the summary leaves out.
- A prompt the bridge sends itself, the summary request or the handoff, goes
  through the same stale-option correction as quota continuation: when the
  harness refuses the saved agent, variant or fast mode as stale, the bridge
  rediscovers the catalog, corrects them and sends once more. It never
  replaces the model. Before accepting the prompt, OMP and Cursor refuse a
  model, mode or reasoning level missing from the catalog they last reported,
  Hermes a missing model, and DeepSeek a missing model or reasoning level (only
  the model, against the session's own list, when the project has no catalog).
  That refusal reaches this correction, or fails the send visibly, instead of
  failing the target's turn after the send reported Sent.
- A busy target behaves as a typed prompt does: it steers into the running
  turn or stops it, as the target's plugin declares.
- Logs carry ids, counts, sizes and the transcript path, never prompt,
  summary or transcript text.

### Source marker

- The summary request and the agent's reply never show as messages. The
  turn folds into one centred line: "Writing a summary for <target>…" while
  the agent writes, then "Summary sent to <target> · Open" or "Couldn't send
  to <target>". "another session" stands in for an untitled target.
- The line keeps one height in every state, and only its words and icon
  cross-fade, so nothing around it moves when the turn ends.
- Once the turn has ended, tapping the line opens the agent's reply in a
  "Handoff summary" sheet; Open opens the target.
- A send that did not complete still folds its exchange, as "Couldn't send
  to …", both live and after a reload. A summary request the bridge still
  lists as queued shows as the marker, never as a plain prompt.
- Sending fades the marker in where the request lands, with no "Working…" row
  before it and no jump in the transcript. Stop during the summary changes it
  straight from "Writing a summary…" to "Couldn't send to …", with no
  "Working…" row in between, whether or not the harness echoed the request
  (Codex and Claude both).
- The summary request belongs to the bridge: it is never restored into the
  composer, so one tap on Send can't send it again. The bridge stamps the
  request as not sent when the update leaves it, so a harness reporting the
  request before the send marks it, or an update held behind the stop, still
  never shows it as a bubble.

### Source row in the list

- While a send is in flight, the source's row in the session list shows a
  send glyph in place of the running sparkle, drifting forward and fading on a
  1.2 s loop. Under reduce motion the glyph stands still, with no loop. Its
  meta line cross-fades to "Sending to “<target>”…" ("Session" for an untitled
  target, as in the alerts) and back when the send ends. Waiting for input
  still wins over sending.
- The sending device shows it from the request until its answer, including
  while it reads back an answer it lost. Every other device shows it while the
  source is active, from the bridge's projects summary: each active session
  carries `sending` (the target's title) while the bridge runs a send from it,
  and the bridge sends a fresh summary when a send starts and ends. A bridge
  that predates the field omits it, and the row then shows as running only.
- The row keeps its height and the title its place; only the mark and the
  meta line's words cross-fade.
- When the row goes quiet, the send glyph or sparkle fades out where it stands
  (200 ms), then its room after the title closes over the next 200 ms, so the
  title and, under a pointer, the time ease into the space instead of snapping.
  A mark arriving opens its room first, then fades in. A quiet row reserves no
  room. Under reduce motion the mark comes and goes at once.

### Target card

- The handoff prompt shows as a card in place of a bubble: "From <source>",
  which opens the source; the first lines of the summary faded out over "Show
  all"; and the transcript's path.
- The collapsed summary ends in a fade that fully hides the cut-off line, so
  no sliver of clipped glyphs shows above "Show all". A summary that fits
  shows whole, with no "Show all".
- "Show all" opens the whole summary in a sheet on a phone and a dialog on
  desktop, titled "Handoff summary": the same "From <source>" link, the
  summary rendered as on the card and scrollable, and the selectable
  transcript path. The card never changes height, so the transcript under it
  stays still. The sheet closes by dragging down, the scrim or its close
  button; the dialog by Esc, the scrim or its close button.
- The sheet's "From <source>" closes it and opens the source, as the card's
  link does.
- A source that was archived opens read-only. One that was deleted answers
  the tap with "Couldn't open that session".

### Archive after sending

- With the switch on, the app archives the source once the target accepts the
  handoff (Sent only), through the app's pending archive. It takes the same
  five-second Undo window as Archive, removes a dedicated worktree as Archive
  does, and a page open on the source closes. The window belongs to the app
  shell, so leaving the page neither cancels nor loses it. See
  [Session archiving and deletion](session-archiving-and-deletion.md).

### Transcript file

- The file is saved at
  `~/.sesori/transcripts/<target session id>/<date>-<random>/<source title>.md`,
  with owner-only permissions, or `transcript.md` for an untitled source. It
  belongs to the target: deleting the target removes it, archiving keeps it,
  deleting the source leaves it, and no age sweep touches it. A target that
  refuses the handoff prompt (archived, stale options, or the harness's own
  refusal) has the file removed again, best-effort (a failed removal is
  logged and the file stays); a failure that may follow the target's
  acceptance keeps it.
- The file starts with the source's title and holds the conversation itself:
  numbered messages by role, text verbatim, one line per tool with its error
  and capped output, and markers for attachments, sub-agents and compactions.
  It leaves out reasoning, step markers, snapshots, patches, agent switches and
  retries. Times are in UTC.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated bridge tests: `session_send_service_test` (the source listed as sending until the send ends, also while a second send is refused, and marked in the projects summary; refusals before anything is sent, readiness, the summary split and earlier summary exchanges left out, stop, error, timeout and shutdown failures, the not-sent stamp before and after the echo, the request's marker held until its stored message replaces it, stale source and target options, a target archived during the summary, the transcript removed after a target refusal, a failed transcript write, no text in the log), `session_prompt_service_test` (the stale-option correction), `omp_session_options_service_test` and `omp_plugin_test` (OMP refusing a stale model, mode or thinking level before accepting the send), `cursor_plugin_test` (Cursor refusing the same before accepting the send, and failing the turn when it rejects an option it still lists), `hermes_session_options_service_test` (Hermes refusing a stale model before accepting the send), `deepseek_session_options_test` (DeepSeek refusing a stale model or reasoning level, or a stale model against the session's own list), `send_to_session_handler_test`, `session_transcript_markdown_builder_test`, `prompt_stamp_tracker_test`, `session_repository_test` (the held request listed until released), `orchestrator_emit_bridge_event_test` (a request marked while its update waits goes out stamped), `chat_history_capture_test` (the marked request announced with its text) and `message_handoff_test`. `sesori_sse_event_test` (`sending` on an active session, and its absence from an older bridge). Automated client tests: `sse_event_tracker_test` and `all_sessions_cubit_test` (the bridge's send reaching the row, this device's own send first), `session_send_flow_test` (the archive switch, Open and Undo, the pinned question, leaving the page mid-send), `session_tile_states_test` (the sending row swapping its mark and words in place), `send_session_sheet_test` and `session_search_cubit_test` (the source excluded, Running labels, same-named projects), `transcript_handoffs_test` and `handoff_rows_test` (marker height and Open, folding, an earlier request no longer written once a newer one is queued, card Show all opening the summary sheet or dialog without moving the card, its From link and selectable path, Esc and drag closing), `session_detail_bridge_queue_test` (a bridge-owned request never restored to the composer), `pending_archive_alerts_test` and `archive_after_send_preference_storage_test`. |
| L3 Release | On a headless iOS simulator against a local bridge: send from a session's menu into a session of another harness; check the loading and Sent alerts, Open, the source marker without a jump when the turn ends, the summary sheet, and the target card with Show all opening the summary sheet. Repeat with the archive switch on and use Undo. |
| L4 Extended | Every installed harness as a target, through `POST /session/send-to-session`: ask the target for a detail only the transcript file holds, in Ask mode, and record whether it reads the file and whether it asks (see `docs/HARNESS_CAPABILITIES.md`). A busy source and Stop; Stop during the summary; a running steer target and a running stopTurn target; a pinned source with the switch on; a bridge without the route. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Try an untitled source and target, a source with attachments and sub-agents,
a long summary, a target in another project with the same name, and a target
that starts running while the sheet is open. Stop the source during the
summary, archive the target mid-send, and quit the app while a send is in
flight.

## Failure Signals

- The menu entry shows on an archived or sub-agent session, or is missing on
  one of the four surfaces.
- The picker lists the source, or a running row's label disagrees with what a
  send does to it.
- The sheet's switch flips while it opens, or forgets its last value.
- A pinned source is archived without the confirmation, or asked twice.
- The summary request or reply shows as messages in the source, or the marker
  changes height when the turn ends.
- Sending shows a "Working…" row before the marker, or the transcript jumps as
  the marker appears.
- After Stop during the summary, the request shows as a bubble, live or after
  a reload, returns to the composer, or a "Working…" row shows between
  "Writing a summary…" and "Couldn't send to …".
- A half-written summary reaches the target, or the target receives anything
  after a refusal.
- The transcript includes an earlier send's summary exchange, or transcript
  or summary text shows in the bridge log.
- The source is archived after a refusal, a failure or an unconfirmed send.
- A transcript file outlives a deleted target, or is gone while an archived
  target still names it.
- Show all moves or resizes the card, or the collapsed card shows clipped glyphs between its fade and Show all.
- The source's row keeps its sparkle while a send is in flight (on the
  sending device, or on another device while the source writes), keeps
  "Sending to …" after the send ends, or changes height as it swaps.

## Known Limitations

- The target's agent treats the handoff as a prompt. Every harness checked
  started on the summary's next steps at once, editing files, rather than
  waiting for the user.
- The loading alert closes after the default 3 s, while the summary can take
  minutes; nothing shows between it and the outcome alert, apart from the
  source's marker on its own page.
- The archive after sending runs in the app. If the app closes before the
  bridge answers, the send completes and the source stays unarchived.
- The summary request stays in the harness's own transcript and terminal UI;
  only Sesori folds it.
- An ACP harness that rejects an option its last catalog still lists, or
  before it has reported a catalog, learns that the option is gone only when
  the turn applies it. That rejection fails the target's turn after the send
  reported Sent; the target shows a session error and keeps no handoff.
- Whether the target's agent reads the file, and whether it asks first, is
  the harness's behaviour; `docs/HARNESS_CAPABILITIES.md` records it per
  harness, with the runtimes not yet checked.

## Sources

- `client/module_app_ui/lib/src/features/session_list/session_list_action_dispatcher.dart`
- `client/module_app_ui/lib/src/features/session_list/session_send_flow.dart`
- `client/module_app_ui/lib/src/features/session_list/send_session_sheet.dart`
- `client/module_app_ui/lib/src/features/session_picker/session_picker.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/handoff_marker_row.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/handoff_card.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/handoff_session_link.dart`
- `client/module_app_ui/lib/src/widgets/pending_archive_alerts.dart`
- `client/module_core/lib/src/cubits/session_detail/transcript_handoffs.dart`
- `client/module_core/lib/src/cubits/session_search/session_search_cubit.dart`
- `client/module_core/lib/src/cubits/pending_session_archive/pending_session_archive_cubit.dart`
- `client/module_core/lib/src/repositories/archive_after_send_preference_storage.dart`
- `client/module_core/lib/src/repositories/session_repository.dart`
- `client/module_core/lib/src/repositories/models/send_to_session_result.dart`
- `client/module_core/lib/src/services/session_action_service.dart`
- `client/module_core/lib/src/api/session_api.dart`
- `bridge/app/lib/src/routing/send_to_session_handler.dart`
- `bridge/app/lib/src/services/session_send_service.dart`
- `bridge/app/lib/src/services/session_prompt_service.dart`
- `bridge/app/lib/src/services/session_deletion_service.dart`
- `bridge/app/lib/src/repositories/mappers/session_transcript_markdown_builder.dart`
- `bridge/app/lib/src/repositories/trackers/prompt_stamp.dart`
- `bridge/app/lib/src/orchestrator.dart`
- `bridge/sesori_plugin_claude/lib/src/api/claude_launch_spec.dart`
- `shared/sesori_shared/lib/src/models/sesori/send_to_session_request.dart`
- `shared/sesori_shared/lib/src/models/sesori/send_to_session_error_response.dart`
- `shared/sesori_shared/lib/src/models/sesori/message_handoff.dart`
