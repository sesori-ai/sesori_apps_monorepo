# Step 14.b — Trim The Turn Model

Branch `turn-navigation/turn-model-trim`, published as PR 15/19. Architecture 1
and Architecture 9, "Turn-model members that lose their last reader".

## Plan Claims Checked

- `git grep` outside `.plan` finds no reader of `TranscriptTurnOutcome`, its
  `Running`/`Failed`/`Done` variants, `TranscriptTurnSummary`,
  `TranscriptTurn.summary` or `TranscriptPromptTurn.duration` other than
  `transcript_turns.dart` and its own test. The stub that read them went in
  step 14.
- `TranscriptTurnBuilder.build`'s `transcript` and `isBusy` parameters fed only
  the summary (step counts and the running outcome), so they go with it.
- Still read, so kept:
  - `TranscriptPromptTurn.opener`: the sticky prompt, the Prompts jump,
    `TranscriptPromptListBuilder` and the "Working…" row's start time;
  - `promptTurnFor` and `turnIndexByMessageId`: the sticky prompt, the
    Prompts jump and the prompt list's follow-up children;
  - the turn variants and the follow-up rule;
  - `firstNonBlankLine`: the prompt list's row text.
- `TranscriptTurn.messageIds` has no production reader, but it is not fed by
  the removed members and the turn-rule tests describe every split with it,
  so it stays.

## Scope Delivered

- `transcript_turns.dart` loses the outcome and summary types, `summary`,
  `duration`, `_summaryOf`, `_endingIn` and `_durationOf`.
- `build` takes only `messages` and `hasOlderMessages`. The session body no
  longer builds a transcript just to compute the prompt list's turns; the
  message list still builds its transcript for the activity row.
- The summary test group is deleted. The determinism test compares kinds and
  message positions only, and the test helpers lose the time and error-text
  parameters that only the deleted tests used.
- No generated file, localization or document changed. No behavior changed.

## Evidence

Flutter 3.47.5:

- `dart analyze --fatal-infos` is clean in `module_core`, `module_app_ui`,
  `client/app` and `client/desktop`.
- These tests pass:
  - `module_core` `test/cubits/session_detail` (320);
  - `module_app_ui` `test/features/session_detail` (385);
  - `client/app` `session_detail_body_test.dart` (148).
- `dart format -l 120` leaves the touched files unchanged.
