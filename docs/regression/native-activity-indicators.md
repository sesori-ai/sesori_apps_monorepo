# Native Activity Indicators

## Capability

`PregoActivityIndicator` renders the shared busy spinner and `PregoAiLoader`
the AI-activity sparkle shown on active and unread session and project rows.
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
steps, and stops its timer while the app is not visible (paused, hidden, or
detached; an unfocused but visible window keeps spinning). The sparkle
keeps its animated Flutter fallback there. Reduced motion and disabled tickers
replace the native views with static Flutter frames (the spinner rests on one
stepped frame; the sparkle is a hollow working mark or a solid unread mark), the spinner owns loading-spinner semantics on every
platform, and the sparkle stays decorative.
The sparkle matches Figma `2506:20093`: a 14px Tabler glyph in a 20px slot,
including its font baseline offset. Working stays hollow and turns clockwise
once every two seconds. An observed working → unread change fills through pale
blue into brand blue and eases the rotation into place in 700ms, with Figma's
small overshoot. It finishes once; initially unread rows are already solid.
A new turn interrupts the finish from the displayed angle and fill. Opening a
read thread removes the status mark through the existing row state rules.

Apple views retain their renderer through working/unread changes and receive
`setLoading` on a per-view channel; both the loop and completion use Core
Animation, without continuous Flutter frames. Native and Flutter renderers
share the same geometry, colours, timing, and per-row initial phase. Theme
changes rebuild the native palette. Reduced motion and disabled TickerMode
settle immediately, retaining the hollow/solid state distinction. Caller-owned
outline mode and explicit colours remain available for Deep Scan.

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

## Failure Signals

Material failure signals: a native-platform spinner or sparkle driving
continuous Flutter frame production again; the stepped spinner registering a
ticker, scheduling frames between its eight steps per second, or keeping its
timer alive while the app is paused, hidden, or detached; a native indicator branch
reappearing on Android and degrading scroll; crashes,
frozen or corrupted scene rendering, or leaked native views when an indicator
scrolls out of view, is inserted and removed repeatedly, or composes with
glass and blur; an indicator ignoring a requested colour or a theme switch — product surfaces
request no brand tint, so every spinner shows its platform's natural colour
for the app's resolved brightness (native views receive that brightness and
surfaces that invert the page ask for the opposite natural grey) while the
tint capability stays available;
sparkles in a list rotating in lockstep despite distinct phases; the native
sparkle motion visibly diverging from the Flutter fallback; completion
restarting on rebuild or looping after work ends; a visible angle/fill jump
when another turn starts during completion; a stale native loading state after
a row update; reduce motion still animating or making working look unread.

## Sources

- `client/module_prego/lib/components/loaders/prego_activity_indicator.dart`
- `client/module_prego/lib/components/loaders/prego_ai_loader.dart`
- `client/module_prego/darwin/theme_prego/Sources/theme_prego/ThemePregoPlugin.swift`
- `client/module_prego/test/components/prego_activity_indicator_test.dart`
- `client/module_prego/test/components/prego_ai_loader_test.dart`

## Simulator Review

Run from `client/app`:

```sh
flutter run -d <simulator-id> -t test/playbook/thread_state_motion_playbook.dart
```

The preview uses production indicators at 20px and 4× detail, plus actual
`SessionTile` rows. Inspect light and dark appearance; finish a turn and restart
during its settle; toggle reduced motion while working and finishing. Scroll
the list beneath the blurred header and toggle the list repeatedly to exercise
native clipping, insertion, disposal, and reattachment. Verify the regular loop
still produces no continuous Flutter frames on iOS/macOS.
