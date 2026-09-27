# Step 12 — The Transition

Branch `turn-navigation/prompts-transition`. Architecture 14, "The transition",
and D40.

## Plan Claims Checked

- Step 11 left `_openPrompts({required Offset origin})` with the origin unused,
  and `TranscriptJumpNotifier.jumpTo` returning a future that the list
  completes when the jump lands. Step 12 turns the origin into the scale's
  alignment and closes the layer through the transition once that future
  completes, so a row tap still never shows the transcript moving.
- `context.isReducedMotion` is the check `buildSessionPaneTransitionPage` uses,
  and 220 ms is that page's duration.
- The step 11 `PopScope` already blocks the route's own iOS back swipe while
  the layer is up, so the layer's edge swipe has no competitor.

## Scope Delivered

- One `AnimationController` (220 ms) in `_SessionDetailBodyState`. Opening
  fades the layer in while it scales up from 0.96 around the entry point, over a
  transcript dimmed by up to 20 % black. Closing reverses it: through the close
  button, back, and a row tap after the jump lands. With reduced motion the
  layer only fades.
- The layer is removed when the controller is dismissed. While it leaves it
  ignores taps, so a second row tap cannot move the transcript under a fading
  screen.
- The iOS edge swipe (D40): a 20 pt strip, plus the left safe-area inset, along
  the layer's left edge. While the finger is down, the layer moves right pixel
  for pixel with no scale or fade and casts a shadow. The dim follows the same
  value. On release, the swipe closes when it is past halfway or flung right
  faster than one screen width a second; otherwise it springs back. Either way,
  the controller's spring carries the finger's velocity. The only new state is
  one `_swiping` flag; the drag offset is the controller's value.
- The transcript is only dimmed by an overlay. It is never rebuilt, resized or
  scrolled by the transition.

## Deviations

- The drag offset is not a separate field. It is the controller's value while
  `_swiping` is set, so the swipe and the transition cannot disagree about where
  the layer is, and a released swipe settles on the same controller.
- The swipe starts once the touch slop is crossed. The layer then trails the
  finger by the slop instead of jumping to it, as a route's back swipe does.
- The fade runs over the first 55 % of the opening, and the last 55 % of the
  closing, while the scale runs throughout. This keeps the two screens'
  overlap brief.
- Not recorded on a real iPhone or on macOS: the device automation servers were
  unavailable. The PR's recordings are frame sequences from a throwaway
  widget render with fixture data. Each frame was inspected, and the layer's
  position and opacity were logged per frame.

## Evidence

Flutter 3.47.5:

- `dart analyze --fatal-infos` is clean in `module_app_ui` and `client/app`.
- These tests pass:
  - `client/app` `session_detail_body_test.dart` (148), including the new
    "its transition" group:
    - open and close grow in and out over a dim, and the transcript's rect,
      offset and element do not change;
    - reduced motion, and Android's removed animations, are a plain fade (the
      controller preserves its duration under the latter);
    - the iOS swipe follows the finger, springs back, closes past halfway and
      on a flick, and leaves the transcript unmoved;
    - an Android swipe does nothing.
  - `module_app_ui` `test/features/session_detail` and
    `test/features/session_prompts` (416).
  - `client/desktop` `test/` (337).
- Frame logs (16 ms steps, 393 pt wide):
  - Opening: opacity 0 → 1 by about 130 ms, and the scale settles by 220 ms.
  - Closing: opacity reaches 0 by about 130 ms, and the layer is removed at
    about 230 ms.
  - A swipe released at rest at 114 pt springs back to 0 in 14 frames, with no
    overshoot.
  - A swipe released at 243 pt slides out to 392 pt and is then removed, so no
    visible pop.
- `architecture-implementation-review` over `origin/main...HEAD`: approved on
  the first pass, with no findings.
