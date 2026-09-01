# Native Activity Indicators

`PregoActivityIndicator` renders the shared busy spinner and `PregoAiLoader`
the twinkling AI-activity sparkle shown on active session and project rows.
On iOS and macOS both render through `theme_prego` platform views animated by
Core Animation outside Flutter's frame pipeline, so an otherwise-static screen
schedules no Flutter frames. Android is deliberately all-Flutter for both
indicators: hybrid-composition platform views idle Flutter on a static screen
but wreck Android scroll performance on-device, and the sparkle lives in
scrolling list rows. On Android, web, and the remaining desktop platforms the
spinner is `PregoSteppedActivityIndicator`: a derivative of the iOS eight-tick
indicator at the native medium size, stepped by a plain timer instead of a
ticker. Its picture only changes when the active tick advances, so it repaints
exactly eight times per second, registers no ticker, schedules no frame between
steps, and pauses its timer while the app is not in the foreground. The sparkle
keeps its animated Flutter fallback there. Reduced motion and disabled tickers
replace the native views with static Flutter frames (the spinner rests on one
stepped frame; the sparkle rests on its solid keyframe, matching its
`animate: false` still), the spinner owns loading-spinner semantics on every
platform, and the sparkle stays decorative.
The sparkle's native renderer duplicates the Dart painter's geometry,
keyframes, and 1.4s period, including the per-row phase stagger passed at
creation.

Material failure signals: a native-platform spinner or sparkle driving
continuous Flutter frame production again; the stepped spinner registering a
ticker, scheduling frames between its eight steps per second, or keeping its
timer alive while the app is in the background; a native indicator branch
reappearing on Android and degrading scroll; crashes,
frozen or corrupted scene rendering, or leaked native views when an indicator
scrolls out of view, is inserted and removed repeatedly, or composes with
glass and blur; an indicator ignoring its requested colours or theme switches;
sparkles in a list twinkling in lockstep despite distinct phases; the native
sparkle keyframes visibly diverging from the Flutter fallback; reduce motion
still animating.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: the owning widget test suite proves per-platform widget selection, creation parameters, semantics role, the reduced-motion and disabled-ticker fallbacks, and that the stepped spinner schedules one repaint per step, none between, no ticker, and nothing while the app is backgrounded. |
| L2 Routine | Client end to end (release-target client platform): a screen with a spinning indicator renders correctly while the app shows no continuous Flutter UI/raster work attributable to the spinner; list scrolling stays smooth with indicators on screen. |
| L3 Release | Client end to end: repeat on the alternate mobile platform and macOS desktop (include a session list with working-session sparkles on iOS and macOS); scroll an indicator through a list, insert and remove it repeatedly, and overlap it with glass/blur without crashes or scene corruption. |
| L4 Extended | Client end to end: toggle system reduce motion mid-spin; background and foreground the app while an indicator is animating. |
| L5 Full | No additional coverage. |

## Exploration Guidance

- Prefer real loading states (session list refresh, solid-button loading,
  session detail) over synthetic screens.
- Judge the power invariant by per-thread CPU, not visual smoothness: an idle
  screen with a native spinner must produce no continuous Flutter frames.
- Judge the scroll invariant on-device: this capability was scoped away from
  Android precisely because hybrid-composition platform views produced heavy
  frame drops while scrolling there.

## Maintenance Sources

- `client/module_prego/lib/components/loaders/prego_activity_indicator.dart`
- `client/module_prego/lib/components/loaders/prego_ai_loader.dart`
- `client/module_prego/darwin/theme_prego/Sources/theme_prego/ThemePregoPlugin.swift`
- `client/module_prego/test/components/prego_activity_indicator_test.dart`
- `client/module_prego/test/components/prego_ai_loader_test.dart`
