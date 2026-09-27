# Step 14 — Remove The In-Place Fold

Branch `turn-navigation/remove-fold`. Architecture 9, "Removing the in-place
fold".

## Plan Claims Checked

- `transcriptFolded`, `setTranscriptFolded`, the fold activators, the fold
  buttons, `TranscriptTurnStub` and the `transcript_turns_folded` event had no
  reader left once the pinch opened the Prompts screen (step 13). The eight
  fold-only ARB keys had no other caller.
- `_PageFocus` is not fold-only. Its focus claim is what lets the desktop
  shell's Shift+Cmd/Ctrl+U (mark unread) work before the composer is focused,
  so it stays and now wraps the page directly.
- `_topEdgeTurn`, `_rowTurns` and `_firstRowOf` served only the fold switch and
  the unfold-on-jump, so they go with it. The jump and the glide key rows by
  message id.
- The turn model's `TranscriptTurnOutcome` variants, `TranscriptTurnSummary`,
  `summary` and `duration` fed only the stub lines and are now dead. Trimming
  them would push this PR past target, so that trim lands as step 14.b.

## Scope Delivered

- `SessionDetailLoaded.transcriptFolded` and the cubit's fold state and
  setter are gone; `session_detail_state.freezed.dart` is regenerated.
- The list lost its fold props, stub rows, turn-row ids and the fold hold.
  The sticky prompt and the Prompts jump are unchanged.
- The phone fold button, the desktop fold button and ⌘−/⌘= (Ctrl+−/Ctrl+=)
  are gone, with the `CallbackShortcuts` that bound them.
- `transcriptTurnsFolded` and its deferred-candidate entry are removed.
- The eight fold ARB keys are removed and the localizations regenerated.
- The fold test regions are deleted. The paging test is rewritten to shrink
  the transcript below the screen, so it still proves that a layout change
  without a scroll loads the older page. The sticky prompt's tests are
  unchanged apart from the deleted "hides while folded" case.
- The desktop fold-shortcut test became a mark-unread-before-focus test,
  covering the `_PageFocus` claim that survives.
- `transcript-turn-navigation.md` no longer describes the fold, and the fold
  cross-references in `projects-and-sessions.md`,
  `session-history-and-recovery.md` and `tools-and-file-changes.md` are
  removed.

## Deviations

- `_PageFocus` is kept (above).
- The turn-model trim is deferred to step 14.b, which makes the series 19
  steps as the tracker allows.
- No real-device check: nothing new is visible, only the fold controls are
  gone.

## Evidence

Flutter 3.47.5:

- `dart analyze --fatal-infos` is clean in `module_core`, `module_app_ui`,
  `client/app` and `client/desktop`.
- These tests pass:
  - `module_app_ui` `test/features/session_detail` (380);
  - `module_core` session detail, analytics, state defaults and services
    tests (982);
  - `client/app` `session_detail_body_test.dart` (147);
  - `client/desktop` `desktop_session_detail_screen_test.dart` (13).
- Mutation check: changing the list's `ScrollMetricsNotification` depth filter
  from `0` to `-1` makes the rewritten paging test fail.
- `git grep` outside `.plan` finds no `transcriptFolded`,
  `setTranscriptFolded`, `transcript_turns_folded`, deleted ARB key, fold
  activator or fold shortcut.
