# Step 4 — Show Running And Failed Compaction In The Transcript

Branch `compaction-progress/app`. Client only: `module_core` and
`module_app_ui`. No wire or database change. Phone and desktop share
`SessionDetailMessageList`, so both get the row. No plugin emits `running` or
`failed` before step 5, apart from the bridge's step-3 sweep that fails a
stranded running compaction.

## Scope Delivered

- `CompactionPartWidget` takes `state`, `sinceMs` (the message's
  `time.created`, passed through `AssistantMessageCard` and
  `SystemMessageCard`) and `streamingText`.
  - Running: sparkle, shimmering "Compacting context", and a ticking
    `TranscriptElapsedTime` (none without `sinceMs`). The newest streamed words
    show under it in `TranscriptLatestWords`.
  - Completed: fold icon, "Context compacted", and "· freed 142k tokens" and
    "· auto" when reported (manual is not named). Tapping opens the summary.
  - Failed: alert icon in `textSecondary`, "Compaction failed" and the error
    on one line. Semantics read the whole error. The row is inert.
  - P9 settle: one `TextButton` and one `AnimatedSwitcher` in every state, so
    the row keeps its element and height. Only the icon cross-fades and the
    words fold inside `TranscriptPresenceColumn`. Reduced motion is instant.
- `TranscriptActivityBuilder` returns idle while a compaction runs, including
  in the sub-agents branch (P8). "Working…" returns once it settles.
- `_streamedText` and `resolvePartContent` return a running compaction's
  summary as base text (P5). Completed stays non-streamable.
- `_LatestWords` and `ReasoningPartCard.latestWords` became the shared
  `TranscriptLatestWords`. `TranscriptTokenCountFormatter` is new (P12).
- Four `app_en.arb` strings with generated localization output.
- Regression doc: `tools-and-file-changes.md`.

## Deviation

- The timer does not use tabular figures. Satoshi's tabular "1" renders as
  another glyph style. The time ends the line, as in the "Working…" row, so
  its changing width moves nothing.

## Evidence

Dart 3.13.4 from Flutter 3.47.5-stable first on `PATH`.

- `module_app_ui`: `dart analyze --fatal-infos` no issues;
  `flutter test test/features/session_detail/` 410 passed. Covers the fake
  clock timer and its once-read semantics, no timer without `sinceMs`, the
  strip, the in-place settle (same switcher state, same height, mid-fade), the
  word fold, the reduced-motion settle, the summary tap only when completed
  with a summary, the details, the failed note and its semantics, the formatter
  table, the step-row layout of all three states, the unchanged reasoning
  strip, and a message-list test where a running compaction replaces
  "Working…" and settles in the same element.
- `module_core`: `dart analyze --fatal-infos` no issues;
  `dart test test/cubits/session_detail/` 341 passed, including the activity
  rule and a running compaction in the streamed-part buffer table.
- No `client/app` or `client/desktop` test renders the row.

## Size

817 changed lines against `origin/main`: 779 authored (this file included),
38 generated localization output.
