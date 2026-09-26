# Step 2 — "N steps" and the #1738 revert

## Shipped

- `module_core`: `TranscriptStepKind`, `TranscriptStep.kind`,
  `TranscriptKindCount` and `TranscriptSummary` are gone. The group line reads
  `TranscriptGroupBlock.finishedSteps.length`, which had no other reader to
  keep a summary type for. `TranscriptTurnSummary.failedSteps` had no reader
  outside tests and went too.
- `module_app_ui`: `TranscriptGroupWidget` drops the #1738 lone-step branch;
  any finished step shows the summary, running steps stay below it. The
  summary is one rolling segment, "N steps"; the red failed line is gone.
- Strings: `transcriptSummarySteps` kept with a new description; the six
  per-kind strings and `transcriptSummaryFailed` removed; l10n regenerated.
- Docs: `tools-and-file-changes.md` (group line, #1738 paragraph and kind
  summary text removed, failure signal, L1 row, sources);
  `HARNESS_CAPABILITIES.md` "Tool kinds" no longer claims the summary reads
  the kind (step 3 deletes the section).

## Verification

- `dart analyze --fatal-infos`: `module_core`, `module_app_ui`, `client/app`,
  `client/desktop` — no issues.
- `dart test test/cubits/session_detail/` (`module_core`): pass.
- `flutter test test/features/session_detail/` (`module_app_ui`): pass.
- `flutter test test/features/sessions/desktop_session_detail_screen_test.dart`
  (desktop) and `flutter test test/features/session_detail` (app): pass.
- Before and after screenshots, phone and desktop, from fixture groups:
  `pr-media` branch, `step-timers/n-steps/`.
