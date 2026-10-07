# Step 6b — Stream OpenCode v1 Compaction Into The Live Row

Branch `compaction-progress/opencode-v1`. This covers the bridge OpenCode v1
adapter (`bridge/sesori_plugin_opencode`, outside `lib/src/v2/`). There is no
client, wire or database change, because step 4's row already renders each
state.

## Scope Delivered

- `MessagePartMapper.mapSummaryPart` maps the text of a `summary: true`
  assistant message onto a compaction part with the same id, in the state of
  its message:
  - **running:** `running(summary)` while `time.completed` is null, with empty
    text read as none.
  - **completed:** `completed(summary, freedTokens: null, trigger)`, where the
    compaction marker's `auto` maps `true`→auto, `false`→manual, unknown→none.
  - **failed:** `failed(error)` when the message carries an error, with the
    message text normalized by the shared `openCodeError` helper.
- `AssistantMessageMapper.map(keepsCompactionParts:)` keeps an errored summary
  message with written summary text an assistant message, so the failure note
  replaces the turn error. A summary that errors before writing text keeps its
  empty text part as plain (hidden) text and stays an error message, on both
  paths.
- REST: `OpenCodeRepository.getMessages` reads each marker's `auto` in a
  pre-pass and passes it to `PluginModelMapper.mapMessageWithParts`.
- Live: `SummaryMessageTracker` records the 16 most recent summary messages
  (with their text parts, which are not capped separately; OpenCode writes
  one per summary attempt) and the 16 most recent marker `auto` flags. The
  plugin hands `SseEventMapper.map` the `SummaryMessage` value (in
  `models/summary_message.dart`) its event belongs to. The row starts with the
  summary's first text part. When a summary message's `message.updated` shows
  it finished, the mapper re-emits its recorded text parts in the settled
  state, after the message itself. The strip needs no new code: v1 text deltas
  already target the part id.
- The settle relies on OpenCode v1.18.35's `SessionProcessor`
  (`packages/opencode/src/session/processor.ts`). `text-end` and, for an
  interrupted stream, `cleanup()` both send the full text part through
  `updatePart` before `cleanup()` sets `time.completed` and calls
  `updateMessage`. `halt()` sets the error before that cleanup runs.
  `compaction.ts` may later set an overflow error on the finished message;
  the re-emission then moves the row from completed to failed. The client
  upserts a part by id in place (`SessionDetailCubit._onPartUpdated`), so an
  identical re-emission changes nothing.
- Docs:
  - `HARNESS_CAPABILITIES.md`: the OpenCode v1 compaction row records the live
    row, the strip, the failure note, the auto-only trigger, no freed count and
    the outage limit.
  - `tools-and-file-changes.md`: the v1 live row and its limits, plus the
    qCrXY wording from #1904. A row stranded by a stream outage settles only on
    a later ordinary read once the session is idle; stored-only reads and
    busy or retrying sessions skip that sweep. Coverage now lists the v1 tests.
  - `session-turns.md`: v1 manual-compaction prompt settlement and the
    failed-summary versus error-message rule.

## Deviations And Accepted Limits

- **No reconnect recovery on v1.** The tracker survives an SSE reconnect, so a
  compaction that runs across one keeps its row. A compaction whose summary
  message was announced during the outage shows its text as plain text on the
  live stream. Recovering it would need a fetch for every unknown part, so it
  is documented instead of built.
- **Reload after that outage.** A later read that reloads the transcript from
  OpenCode maps the summary to the compaction row in its stored state. A row
  still running then settles through the idle sweep.
- **Stranded by an outage.** On v1, as on v2, a compaction that ends while the
  stream is down stays running until a later ordinary read once the session is
  idle.
- **A summary that never finishes.** If OpenCode dies mid-compaction, its
  message stays unfinished. Each ordinary read once the session is idle runs
  `ChatHistoryService._sweepUnlessTurnRunning`, and its `_endUnfinishedPart`
  turns the running compaction part into failed.
- **No freed count on v1.** The summary message's `tokens` is the usage of the
  summary call itself.
- **Older apps (Q5)** behave as recorded for 6a.

## Evidence

Dart 3.13.4 from Flutter 3.47.5-stable first on `PATH`, measured on commit
`5a0322e093`. Wave 2's `16e4ad4e48` only moved `openCodeError`; it was re-checked
in the plugin with the same results. Later commits touch only this file.

- **cwd `bridge/`:** `dart analyze --fatal-infos` found no issues.
- **cwd `bridge/sesori_plugin_opencode`:** `dart analyze --fatal-infos` found
  no issues, and `dart test` passed all 610 tests. The new tests cover:
  - live mapping in the plugin stream: the summary text runs, then settles
    completed with trigger auto from its marker when its message finishes;
  - the mapper's failed settle: an errored finished summary message stays an
    assistant message and its row settles as "Fixture failure", while one
    whose text is empty becomes the error message with its text hidden;
  - REST mapping for running, completed (auto, manual, unknown trigger) and
    failed summary messages;
  - an errored summary message without parts, or with only empty text,
    keeping its error message.
- **Formatting:** `dart format` was applied only to the touched files, with no
  changes outside this step's hunks.
- **PR media:** none. The row is step 4's, already shown for 6a under
  `compaction-progress/opencode/` on `pr-media`.

## Reviews

- **`architecture-implementation-review` of `origin/main...48920ecc4c`:**
  rejected with two findings, both applied directly. The mapper now takes the
  `SummaryMessage` value instead of the tracker, and the tracker returns an
  unmodifiable snapshot of its text parts.
- **PR wave 1 (Codex and cubic):**
  - Fixed:
    - `SummaryMessage` moved to a neutral model file;
    - an empty failed summary keeps the error message;
    - doc wording for the row start, the reload after an outage, SSE
      ordering, the tracker's cap and this evidence.
  - Declined, with the code above cited:
    - stale text on settle;
    - a summary that never finishes;
    - duplicate re-emission.
- **PR wave 2:** cubic found nothing. Codex's one finding was applied:
  `openCodeError` moved to `models/open_code_error.dart`, so
  `MessagePartMapper` no longer imports its peer `AssistantMessageMapper`.

## Size

About 700 changed lines against `origin/main`: about 250 of production
code, 300 of tests, 35 of docs and 110 of this file. Nothing is generated.
