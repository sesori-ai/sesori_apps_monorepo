# Step 7 — Pinch To Fold And Unfold Turns On Touch And Trackpad

Branch `turn-navigation/pinch`. Architecture 5.

## Plan Claims Checked

- A plain `ScaleGestureRecognizer` loses a one-finger-still vertical pinch to
  the list's vertical drag, as the spike found. With the eager second-finger
  acceptance removed, every touch pinch test fails.
- `FollowDetachScrollable`'s `Listener` detaches on a trackpad pan-zoom start.
  The detector is inside it, so its recognizer sees the first pointer first,
  and the list records the follow state before the detach. Without the
  suppression, the below-threshold trackpad test fails on every platform.
- The list already holds a turn through `_holdTurn`, so a pinch needs no new
  anchor code: it sets the pending anchor for the turn under the focal point,
  then calls the list's fold callback, as a stub tap does.

## Scope Delivered

- `TranscriptPinchDetector` (`transcript_pinch_detector.dart`) wraps the list
  inside `FollowDetachScrollable`. Its private recognizer accepts when a
  second touch pointer lands and has an endless pan slop, so a pan alone
  never wins. A trackpad pinch wins through the stock scale-factor
  acceptance. It switches at most once per gesture, at 0.8 or 1.25, and
  reports the first pointer, pinch start, the fold request with its focal
  point, and the gesture end.
- The list keeps two per-gesture fields: started-following and
  detach-suppressed. The once-per-gesture flag lives in the detector.
- Holding follows the recorded decisions: a switching pinch holds the turn
  under the fingers even while following and stops following, like the
  buttons. A pinch that never switches leaves following alone. A pinch while
  reading history stays detached.
- The regression document covers pinch.

## Deviation

- One addition to the planned recognizer: a lone touch pointer gives the
  gesture up after 8 px of travel. Without this, the recognizer stays in the
  arena, and a small vertical drag no longer detaches the list at once.
  Three existing tests caught this. The 8 px matches the timestamp peek's
  pending rejection slop. A pinch whose first finger travels more than 8 px
  before the second lands scrolls instead.
- The endless pan slop also applies to trackpad pan-zoom, so a trackpad pan
  never counts as a pinch. Trackpad acceptance still uses the stock
  scale-factor check.

## Automated Evidence

Toolchain: Dart 3.13.4 from Flutter 3.47.5. `dart analyze --fatal-infos` is
clean in `module_app_ui`. `dart format -l 120` leaves the touched files
unchanged.

| Command | Result |
|---|---|
| `flutter test test/features/session_detail/` in `client/module_app_ui` | 353 passed |

New pinch tests each run on iOS, Android and macOS:

- a touch pinch folds once and unfolds once;
- a vertical pinch with one finger held still folds;
- a trackpad pinch folds and unfolds;
- a pinch below the thresholds, touch and trackpad, switches nothing,
  scrolls nothing and leaves following alone;
- a trackpad pinch while following holds the turn under the fingers and
  stops following;
- a touch pinch while reading history holds the turn under the fingers, not
  the top-edge turn, and stays detached.

These existing tests now also run on iOS, Android and macOS:

- a small drag detaches at once;
- the finger peek and the trackpad peek;
- a code block's touch and trackpad horizontal scroll;
- a folded-line tap.

Size: about 580 changed lines against the 600-line target. About 60 of them
are re-indentation, because the list gained one more wrapper.

## Review

`architecture-implementation-review` over `origin/main...HEAD` approved with no
findings.

## Manual

- **Pending, for the user:** the real-iPhone pinch and the real macOS trackpad
  pinch the tracker requires, with a recording.
  - No tool available here can send a two-finger touch to the iOS simulator.
    `mobile-mcp` and `idb` send single touches only, and the `agent-device`
    server did not connect.
  - The macOS desktop app was not launched, to avoid the user's running
    desktop app and its bridge.
  - The PR has no recording for the same reason.
- To check:
  - pinch in and out on a long session, while following and while reading
    history;
  - a one-finger-still vertical pinch;
  - one-finger scroll, the peek and a code block's horizontal scroll;
  - on macOS, trackpad scroll and the trackpad peek.
