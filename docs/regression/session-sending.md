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
  request went out) shows "Couldn't confirm the send. Check “<target>”." with
  Open. The bridge finishes the send regardless. Nothing is archived.
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
| `targetArchived` | Couldn't send: “<target>” is archived. | Including one archived between the pick and the send. |
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

### Target card

- The handoff prompt shows as a card in place of a bubble: "From <source>",
  which opens the source; the first lines of the summary faded out over "Show
  all"; and the transcript's path.
- "Show all" grows the card downward in place and "Show less" folds it back.
  The rows above stay still. A summary that fits shows whole, with no toggle.
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
  deleting the source leaves it, and no age sweep touches it.
- The file starts with the source's title and holds the conversation itself:
  numbered messages by role, text verbatim, one line per tool with its error
  and capped output, and markers for attachments, sub-agents and compactions.
  It leaves out reasoning, step markers, snapshots, patches, agent switches and
  retries. Times are in UTC.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated bridge tests: `session_send_service_test` (refusals before anything is sent, readiness, the summary split and earlier summary exchanges left out, stop, error, timeout and shutdown failures, the not-sent stamp before and after the echo, stale source and target options, a failed transcript write, no text in the log), `session_prompt_service_test` (the stale-option correction), `omp_session_options_service_test` and `omp_plugin_test` (OMP refusing a stale model, mode or thinking level before accepting the send), `cursor_plugin_test` (Cursor refusing the same before accepting the send, and failing the turn when it rejects an option it still lists), `hermes_session_options_service_test` (Hermes refusing a stale model before accepting the send), `deepseek_session_options_test` (DeepSeek refusing a stale model or reasoning level, or a stale model against the session's own list), `send_to_session_handler_test`, `session_transcript_markdown_builder_test`, `prompt_stamp_tracker_test` and `message_handoff_test`. Automated client tests: `session_send_flow_test` (the archive switch, Open and Undo, the pinned question, leaving the page mid-send), `send_session_sheet_test` and `session_search_cubit_test` (the source excluded, Running labels, same-named projects), `transcript_handoffs_test` and `handoff_rows_test` (marker height and Open, folding, card Show all and Show less without moving the rows above), `pending_archive_alerts_test` and `archive_after_send_preference_storage_test`. |
| L3 Release | On a headless iOS simulator against a local bridge: send from a session's menu into a session of another harness; check the loading and Sent alerts, Open, the source marker without a jump when the turn ends, the summary sheet, and the target card with Show all. Repeat with the archive switch on and use Undo. |
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
- A half-written summary reaches the target, or the target receives anything
  after a refusal.
- The transcript includes an earlier send's summary exchange, or transcript
  or summary text shows in the bridge log.
- The source is archived after a refusal, a failure or an unconfirmed send.
- A transcript file outlives a deleted target, or is gone while an archived
  target still names it.
- Show all moves the rows above the card.

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
