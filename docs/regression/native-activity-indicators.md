# Native Activity Indicators

`PregoActivityIndicator` renders the shared busy spinner. On iOS, macOS, and
Android it renders through a `theme_prego` platform view so the animation runs
outside Flutter's frame pipeline — Core Animation on Apple platforms,
RenderThread on Android via forced hybrid composition — and an otherwise-static
screen schedules no Flutter frames while it spins. Web and the remaining
desktop platforms use the animated Flutter fallback arc. Reduced motion and
disabled tickers replace the native view with a static Flutter arc, and the
widget owns loading-spinner semantics on every platform.

Material failure signals: a native-platform spinner driving continuous Flutter
frame production again; crashes, frozen or corrupted scene rendering, or leaked
native views when a spinner scrolls out of view, is inserted and removed
repeatedly, or composes with glass and blur; a spinner ignoring its requested
colour; reduce motion still animating.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: the owning widget test suite proves per-platform widget selection, creation parameters, semantics role, and the reduced-motion and disabled-ticker fallbacks. |
| L2 Routine | Client end to end (release-target client platform): a screen with a spinning indicator renders correctly while the app shows no continuous Flutter UI/raster work attributable to the spinner. |
| L3 Release | Client end to end: repeat on the alternate mobile platform and macOS desktop; scroll an indicator through a list, insert and remove it repeatedly, and overlap it with glass/blur without crashes or scene corruption. |
| L4 Extended | Client end to end: toggle system reduce motion mid-spin; background and foreground the app while an indicator is animating. |
| L5 Full | No additional coverage. |

## Exploration Guidance

- Prefer real loading states (session list refresh, solid-button loading,
  session detail) over synthetic screens.
- Judge the power invariant by per-thread CPU, not visual smoothness: an idle
  screen with a native spinner must produce no continuous Flutter frames.
- On Android verify the forced hybrid-composition path specifically; the
  default texture-layer platform-view mode recreates the frame-pipeline drain
  this capability exists to remove.

## Maintenance Sources

- `client/module_prego/lib/components/loaders/prego_activity_indicator.dart`
- `client/module_prego/darwin/theme_prego/Sources/theme_prego/ThemePregoPlugin.swift`
- `client/module_prego/android/src/main/kotlin/com/sesori/theme_prego/ThemePregoPlugin.kt`
- `client/module_prego/test/components/prego_activity_indicator_test.dart`
