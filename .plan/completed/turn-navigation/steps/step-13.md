# Step 13 — Pinch Opens The Prompts Screen

Branch `turn-navigation/prompts-pinch`. Architecture 13, "Pinch opens the
Prompts screen", with Architecture 5 and Architecture 14 (D35).

## Plan Claims Checked

- `_turnAt` had one caller, the pinch's fold handler, so it goes with it.
  `_holdTurn`, `_spanOf`, `_rowTurns` and `_topEdgeTurn` still serve the fold
  controls and the jump, and stay until step 14.
- `_openPrompts` already turned a global origin into the scale's alignment
  (step 12), so the pinch's global focal point feeds it unchanged.
- A touch or trackpad gesture keeps delivering to the targets it hit when it
  began, so the layer that appears mid-pinch takes none of the rest of that
  pinch. The detector's once-per-gesture flag keeps the rest from opening it
  again.

## Scope Delivered

- `TranscriptPinchDetector` keeps its recognizer, its arena behaviour and its
  0.8 threshold. `onFoldRequested({folded, focalPoint})` became
  `onPinchIn({focalPoint})`, and the 1.25 pinch-out half went, so a pinch out
  does nothing.
- The list forwards `onPinchIn` through `SessionDetailLoadedView` to
  `_SessionDetailBodyState`. There it calls the one open path with
  `entry: pinch` and the focal point as the transition's origin. The bar and
  toolbar buttons call the same path with `entry: session_bar`.
- The follow-state rules and the `suppressDetach`/`releaseDetachSuppression`
  pairing are unchanged. A pinch no longer moves the list, so nothing releases
  the suppression early; it ends with the gesture, as a pinch that switched
  nothing did before.
- The step 7 pinch tests are rewritten for the new outcome, with the same
  iOS, Android and macOS variants and no new tests. The one-finger scroll,
  peek and code-block tests that share those variants are untouched and pass.
- `docs/regression/transcript-turn-navigation.md` replaces the pinch-to-fold
  and pinch-to-unfold clauses.

## Deviations

- The touch-pinch tests check that the pinch opened the screen once, not its
  exact focal point. A test pinch moves one finger at a time, so the focal
  point at the threshold sits a few pixels off the centre. The trackpad tests
  check the exact focal point.
- Not checked on a real iPhone or a real macOS trackpad. The plan requires
  both before this step closes, so they are pending the user's check.

## Evidence

Flutter 3.47.5:

- `dart analyze --fatal-infos` is clean in `module_app_ui`, the only package
  whose code changed.
- These tests pass:
  - `module_app_ui` `test/features/session_detail` (408), including the
    rewritten "a pinch" group (7 tests × 3 platforms);
  - `client/app` `session_detail_body_test.dart` (148).
