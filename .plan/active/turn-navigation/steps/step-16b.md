# Step 16.b — Pinch Out Closes The Prompts Screen

Branch `turn-navigation/pinch-out-closes`, published as PR 18/20. D43 and
Architecture 13.

## Plan Claims Checked

- Every way out of the Prompts screen was traced to its code:
  - the header's close button, Escape (`SessionPromptsView`'s
    `CallbackShortcuts`), Android back and committed predictive back (the
    body's `PopScope`, whose `onPopInvokedWithResult` runs with `didPop: false`)
    and a row tap (after the jump lands) already called `_closePrompts`, which
    reverses the transition controller;
  - the desktop's ⌘[ or Ctrl+[ called `GoRouter.pop`, which skips `PopScope`:
    on a pushed child session it left the page with the screen open, and on a
    page reached from the sidebar it did nothing. It now goes through the router
    delegate's `popRoute`, which asks the deepest navigator's `maybePop` first;
  - the iOS edge swipe slides the layer off (D40) and stays as it is.
- The layer also disappears if the page leaves its loaded state. That is not a
  way out the reader takes, so it is unchanged.
- `ScaleGestureRecognizer` reports `onEnd` with a scale velocity on every
  pointer change, and the next update restarts from a scale of 1. So the pinch
  out settles at its first end, and lifting one finger before the other cannot
  undo it. A trackpad pinch reports absolute scale and ends once.
- `AnimationController.animateBack` and `animateTo` run the remaining fraction of
  the duration, so a release finishes from wherever the fingers left it.

## Scope Delivered

- Interactive, not a threshold trigger: the recognizer already reports a
  continuous scale and a release velocity, and the transition controller is
  already driven by hand for the edge swipe, so following the fingers costs one
  progress callback and one release decision.
- `TranscriptPinchDetector` takes a sealed `TranscriptPinch`: `TranscriptPinchIn`
  keeps the transcript's callbacks; `TranscriptPinchOut` reports the start's
  focal point (the screen may refuse a pinch, which then reports nothing
  more), the progress (spread past a scale of 1, reaching 1 at 1.5×)
  and whether a release closes (progress 0.5, scale 1.25, or an outward scale
  velocity of at least 1/s). The recognizer is unchanged.
- `SessionDetailBody` wraps the layer in the detector. A pinch out moves the
  transition's origin to the fingers, sets the controller to `1 - progress`
  drawn linearly (shrinking and fading), and on release finishes with
  `animateBack` or springs back with `animateTo`, both ease-out. One nullable
  enum names the gesture driving the controller (edge swipe or pinch out) in
  place of the edge swipe's boolean. Reduced motion stays a fade.
- The desktop shell's go-back shortcut asks the page first, through
  `routerDelegate.popRoute()`.
- The plan (D43, Architectures 5, 10, 13 and 14, the regression table, the L3
  matrix and the step), the tracker and the regression document.
- No generated file, localization, analytics or wire change. No GIF: the device
  servers were unreachable from this session.

## Deviations

- The desktop back shortcut fix was not named in the request's path list as a
  bug; the audit found it, and D43 requires every way out to reverse the
  transition, so it ships here.

## Evidence

Flutter 3.47.5:

- `dart analyze --fatal-infos` is clean in `module_app_ui`, `client/app` and
  `client/desktop`.
- These tests pass:
  - `module_app_ui` `test/features/session_detail` and
    `test/features/session_prompts` (409), including the step 13 pinch tests;
  - `client/app` `session_detail_body_test.dart` (173), with new tests on the
    iOS, Android and macOS variants: a pinch out following the fingers and
    closing, springing back short of halfway, a second pinch during that
    spring-back moving nothing, a quick short spread, a trackpad pinch both
    ways, scroll, pinch in and the search field's selection
    unaffected, every way out but the edge swipe reversing the transition, and
    Android predictive back;
  - `client/desktop` `test/core` (234), including ⌘[ closing what a page has
    open before leaving a direct page and a pushed child.
- `dart format -l 120` leaves the touched files unchanged.
