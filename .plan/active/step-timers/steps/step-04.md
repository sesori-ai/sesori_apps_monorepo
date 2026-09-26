# Step 4 — duration format, ticking time and "Working…"

## Shipped

- `module_core`: `TranscriptActivityBuilder` returns the sealed
  `TranscriptActivity`, either `TranscriptActivityWorking({sinceMs})` or
  `TranscriptActivityIdle`. `sinceMs` is the running prompt turn's opener
  `time.created`. The builder takes only the inputs this step reads:
  transcript, turns, `isBusy`, retry message and whether text streams. Step 5
  adds `messages`, `children` and `childStatuses` together with the sub-agent
  variant that reads them.
- `module_app_ui`:
  - `TranscriptDurationFormatter.format` gives "42s", "1m 02s" and
    "1h 05m 12s", and clamps a negative input to 0s.
  - `TranscriptElapsedTime` has one `Timer` that fires on each whole elapsed
    second and rebuilds only its text.
  - `TranscriptWorkingRow(sinceMs:)` reads "Working… · 1m 43s". Its semantic
    label carries the time as of the build.
  - `TranscriptTurnStub` uses the formatter.
  - `SessionDetailMessageList` renders the activity in `_kWorkingRowId`.
  - `clock` is now a direct dependency (already used by `module_prego` and
    desktop).
- `transcriptTurnHours` becomes "{hours}h {minutes}m {seconds}s"; the
  descriptions of the three duration strings are updated and l10n
  regenerated.
- Docs:
  - `tools-and-file-changes.md`: the Working timer, the duration format, a
    failure signal, the L1 row and the sources.
  - `transcript-turn-navigation.md`: durations, and the timed Working row under
    the folded running turn.
  - `HARNESS_CAPABILITIES.md`: new "Live timers" section.

## Claude live prompt time

A live Claude prompt carries a time.

- A headless `claude -p --input-format stream-json --output-format
  stream-json --verbose --replay-user-messages` turn on CLI 2.1.281
  (2026-09-26) echoed the prompt as a `user` frame with `isReplay: true` and a
  `timestamp` (`2026-09-26T10:41:18.859Z`).
- `ClaudeUserMessage` parses `timestamp`, and `ClaudeEventDispatcher` maps it
  to the user message's `time.created` (`_messageTime(message.timestamp)`). So
  "Working…" ticks for a live Claude turn.
- Slash commands already get a synthetic time at dispatch.
- The CLI frame was checked directly, not through a running bridge and app.
  The mapping between the two is covered by code, and the full path stays in
  the step-7 L3 matrix (Claude row).

## Verification

- `dart analyze --fatal-infos`: `module_core`, `module_app_ui`, `client/app`,
  `client/desktop`. No issues.
- `dart test test/cubits/session_detail` (`module_core`, including the new
  `transcript_activity_test.dart`): pass.
- `flutter test test/features/session_detail` (`module_app_ui`, including
  `transcript_elapsed_time_test.dart` for the formatter, ticker and row, the
  stub copy, and the folded running turn with the timed Working row): pass.
- Before and after renders, phone and desktop, and a ticking GIF, all from
  fixture data: `pr-media` branch, `step-timers/working-timer/`.
