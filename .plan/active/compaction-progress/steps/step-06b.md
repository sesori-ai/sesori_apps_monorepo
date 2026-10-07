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
  message with compaction parts an assistant message, so the failure note
  replaces the turn error. Without text it stays an error message.
- REST: `OpenCodeRepository.getMessages` reads each marker's `auto` in a
  pre-pass and passes it to `PluginModelMapper.mapMessageWithParts`.
- Live: `SummaryMessageTracker` records recent summary messages, their text
  parts and marker `auto` flags, each bounded to 16. The plugin hands
  `SseEventMapper.map` the `SummaryMessage` value its event belongs to. When a
  summary message's `message.updated` shows it finished, the mapper re-emits
  its recorded text parts in the settled state, after the message itself. The
  strip needs no new code: v1 text deltas already target the part id.
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
  message was announced during the outage shows its text as plain text until a
  later transcript read. Recovering it would need a fetch for every unknown
  part, so it is documented instead of built.
- **Stranded by an outage.** On v1, as on v2, a compaction that ends while the
  stream is down stays running until a later ordinary read once the session is
  idle.
- **No freed count on v1.** The summary message's `tokens` is the usage of the
  summary call itself.
- **Older apps (Q5)** behave as recorded for 6a.

## Evidence

Dart 3.13.4 from Flutter 3.47.5-stable first on `PATH`.

- **`bridge/`:** `dart analyze --fatal-infos` found no issues.
- **`bridge/sesori_plugin_opencode`:** `dart analyze --fatal-infos` found no
  issues, and `dart test` passed all 609 tests. The new tests cover:
  - live mapping in the plugin stream: the summary text runs, then settles
    completed with trigger auto from its marker when its message finishes;
  - the mapper's failed settle: an errored finished summary message stays an
    assistant message and its row settles as "Fixture failure";
  - REST mapping for running, completed (auto, manual, unknown trigger) and
    failed summary messages;
  - an errored summary message without parts keeping its error message.
- **Formatting:** `dart format` was applied only to the touched files, with no
  changes outside this step's hunks.
- **PR media:** none. The row is step 4's, already shown for 6a under
  `compaction-progress/opencode/` on `pr-media`.

## Reviews

- **`architecture-implementation-review` of `origin/main...48920ecc4c`:**
  rejected with two findings, both applied directly. The mapper now takes the
  `SummaryMessage` value instead of the tracker, and the tracker returns an
  unmodifiable snapshot of its text parts.

## Size

About 620 changed lines against `origin/main`: 243 of production code, 273
of tests, 31 of docs and about 75 of this file. Nothing is generated.
