# Step 3 — Keep Claude Follow-ups And Queued Automation After History Load

Branch `turn-navigation/claude-history`. Architecture 2.

## Plan Claims Checked

- Claude persists a command queued while a turn runs as an `attachment` record
  of type `queued_command`, not as a `user` record. Confirmed on native Claude
  Code 2.1.281 captures and in the local transcripts:
  - a follow-up has command mode `prompt` and no origin;
  - a peer message has command mode `prompt`, `origin.kind: peer` and
    `isMeta: true`;
  - a task outcome has command mode `task-notification` and no origin. All
    139 such prompts in the sample are whole `<task-notification>` envelopes;
  - a coordinator command has `isMeta` and `origin.kind: coordinator`.
- `_mapTranscriptRecord` made it a `ClaudeTranscriptContextRecord`, which the
  history mapper drops. A re-import then deleted the row the live path had
  stored, because `replaceSessionMessages` keeps a live-only row only when it
  changed after the last import.
- Live ids. With `--replay-user-messages` the CLI echoes the command as a user
  frame when the model receives it: after the running tool's result and
  before the next assistant message, which is the attachment's place in the
  transcript. The frame's uuid is the attachment's `source_uuid`, or the
  record's own `uuid` when `source_uuid` is absent. Its timestamp is the
  record's.
  - Native 2.1.281 captures: the echo uuid equals `source_uuid`, which differs
    from the record uuid.
  - Local Sesori store: 317 live-captured rows are queued commands in their
    transcript. 295 carry the `source_uuid` (CLI 2.1.257 to 2.1.281) and 22 the
    record uuid where `source_uuid` is absent (CLI 2.1.237 to 2.1.273). None
    contradicts the rule, and every row's `time.created` equals the record
    timestamp.
  - `source_uuid` is not a version cut at 2.1.276, as the plan assumed:
    2.1.257 to 2.1.273 write it for some commands only. The rule reads the
    field, so it needs no version.
- The live task-outcome frame carries `origin.kind: task-notification`, but the
  attachment carries only the command mode. The two share one vocabulary, so a
  record without an origin takes its kind from the command mode.

## Scope Delivered

- `claude_transcript_record_dto.dart`: an `attachment` field holding the new
  `ClaudeTranscriptAttachmentDto`, regenerated with build_runner.
- `claude_transcript_record.dart`: `ClaudeTranscriptQueuedCommandRecord`.
- `claude_transcript_catalog_repository.dart` parses a `queued_command`
  attachment before the generic context kinds. Other attachments stay context
  records.
- `claude_history_mapper.dart` maps the record at its transcript position
  through the user-record path, now shared as `_userTurn`. A task outcome
  folds into a known task or becomes an Automation step, and anything else
  goes through `userMessage` with its origin kind. Sidechain, other-session and
  non-peer `isMeta` commands stay hidden, as user records do.
- Tests: `bridge/sesori_plugin_claude/test/claude_queued_command_history_test.dart`.
  Each test maps one turn live, with the echo frame through
  `ClaudeEventDispatcher`, and from the transcript, with the attachment
  through the production parser and `ClaudeHistoryMapper`. It then compares
  ids, order, message info and parts for:
  - a follow-up;
  - an older CLI's follow-up without `source_uuid`, with text and an image;
  - a peer message;
  - a task outcome no task absorbs;
  - a task outcome folded into its Agent tile;
  - the hidden cases.
- Behavior change for step 9: reloaded and re-imported Claude sessions show
  these messages, and a background task whose outcome was queued no longer
  shows cancelled after a reload.

## Measurements

Local transcripts, counts only. Full sample of 112 root transcripts, main's
mapper against this branch:

| Kind | Queued | Before | After |
|---|---|---|---|
| Follow-ups | 106 | none shown | 106 user messages |
| Peer messages | 317 | none shown | 317 Automation messages |
| Task outcomes | 102 | none shown | 27 Automation steps, 75 folded into their tile |

Messages rise from 14,610 to 15,060. No other message changes id, order, kind
or tool ids. 24 task tiles go from cancelled to completed, and 5 from
completed to error, for background tasks that failed, as live shows them.

The plan's method, rows missing from the Sesori store in sessions it knows:

| Kind | Missing today | Plan's count | After this step |
|---|---|---|---|
| Follow-ups | 19 / 72 | 19 / 71 | all 19 shown |
| Task outcomes | 38 / 60 | 37 / 59 | 5 Automation steps, 33 folded into their tile |
| Peer messages | 18 / 260 | 18 / 256 | all 18 shown |

The totals grew slightly because sessions ran after planning. Store order is
not evidence of live order: main's re-import reinserted the rows it retained
by their enqueue time, one place early in 40 cases.

## Deviation

- The branch is `turn-navigation/claude-history`, not the tracker's
  `turn-navigation/claude-queued-commands`.
- The live-plugin check with the headless bridge and the debug server was not
  run. The bridge signs in to a Sesori account before it starts the debug
  server (`ensureAuthenticated`), and this step ran unattended. The evidence
  in its place:
  - the native captures under Manual;
  - the 317 live-captured store rows, 242 of them peer messages, which were
    not captured natively;
  - the full-sample measurement.

  The plan's L3 plugin matrix still runs a forced re-import in step 10.

Size: 891 changed lines against the 700-line target. Production code is 173
authored and 213 generated lines. The test file is 337 lines, because the
formatter puts each fixture field on its own line. The rest is 26 lines of
docs and this file.

## Automated Evidence

Toolchain: Dart 3.13.4 from Flutter 3.47.5. `dart analyze --fatal-infos` is
clean in `sesori_plugin_claude`.

| Command | Result |
|---|---|
| `dart test` in `bridge/sesori_plugin_claude` | 381 passed (6 new) |
| The `queued_command` parse disabled | 5 of the 6 new tests fail; the hidden-case test passes |

## Review

No `architecture-implementation-review`. The change stays inside the Claude
plugin's transcript parsing and history mapping. No shared model, plugin
interface, persisted contract or wire contract changes.

## Manual

Native Claude Code 2.1.281 on haiku, in a scratch directory with
`--replay-user-messages`:

- a follow-up sent during a slow Bash;
- a background Bash that finished while a foreground Bash ran.

Their live frames and transcripts went through the production parser and
mappers. Ids, order, message info and parts matched, and the queued task
outcome folded into its Bash tile on both paths. The scratch sessions were
deleted afterwards.
