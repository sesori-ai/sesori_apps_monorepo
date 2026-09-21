# Step 7 — The macOS title bar is unified with the window

## Scope

- **Unified title bar (D8).** On macOS `FlutterWindowHost` hides the native
  title bar and keeps the traffic lights; Windows and Linux keep native
  chrome. `WindowHost` gains three platform-neutral operations, `startDragging`,
  `toggleZoom` and `setBrightness` with a closed `WindowBrightness` value, and
  `FlutterWindowHost` stays the only `window_manager` import.
- **The lights sit on the panel.** `window_manager` cannot move the traffic
  lights, and at their native place they would land on the panel's rounded
  corner. The macOS runner therefore gives the window an empty unified
  `NSToolbar` with no separator, so AppKit itself sets the lights lower and
  further in. The plan's "no custom Swift" limit was lifted by the user for
  this on 2026-09-21; D8 and the step 7 design text in `PLAN.md` now say so.
  In full screen AppKit would draw that toolbar as an opaque bar over the
  content, so the runner hides it on entry and restores it on exit.
- **Geometry.** Expanded, the panel keeps its 8-point inset and leaves 34
  points above its first control for the lights. The lights are wider than the
  rail, so the rail starts 42 points from the window's top, below them. They
  end before the page toolbar's leading control, so the toolbar takes no inset.
- **Moving the window.** Under a hidden title bar Flutter receives every
  press, so `DesktopWindowDragArea` hands presses to the host: the room beside
  the lights and the strip above the rail drag and zoom on a double click, and
  one band at the app root (the height of a page toolbar, drag only) moves the
  window on every screen, signed-out login included. The drag waits for as
  much travel as a tap tolerates, so toolbar buttons keep their clicks.
- **Collapse button.** At the user's request during the live check it moved
  from the panel's top row into the footer, after refresh and settings; the
  rail wraps it below them. The top row is gone on every platform.
- **Brightness.** `DesktopWindowBrightness` pushes the app's effective
  brightness to the native window once per change, on every platform.
- **Found in the live check and fixed here.** The session list's row
  highlights are ink on the nearest `Material`, which was the whole panel, so a
  highlighted row scrolled under the panel's top kept painting there. The list
  now sits on its own clipped transparent `Material`.
- No new string, no wire, database or analytics change. The phone is
  unchanged.

## Automated Evidence

Measured checkpoint: commit `2b57085925d35e72968b93ddf953e03795e9b61f` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. This file and the tracker row were added afterwards as documentation
only and were not re-measured.

```sh
cd client/desktop
flutter test --no-pub
flutter analyze --no-pub
cd ../module_desktop_core
dart test
dart analyze
```

- `desktop`: the full suite, 263 cases, passes. New cases cover the title bar
  style per platform and the three host operations; the drag area (drag once,
  a jiggling click left alone, zoom on a double click, nested areas reaching
  the host once, logged host failures); the brightness push once per effective
  change; the macOS shell geometry expanded and as a rail with drag and zoom on
  both; the clipped list `Material`; and, in the app smoke test run as macOS,
  the brightness pushes and the signed-out window drag.
- `module_desktop_core`: 336 cases pass. Both analyzers report no issues. No
  generated file changed.
- `flutter build macos --debug` compiled the runner with the new Swift.
- Architecture review (`architecture-implementation-review`, one run, before
  the layout switch): approved with no findings. It covered the host
  operations, the two new widgets and the shell wiring. The later changes (the
  runner's toolbar, the panel geometry, the footer button, and the sidebar
  taking the `WindowHost` the shell already resolved) add no class, dependency
  or contract and were not re-reviewed.

## Live macOS Evidence

The plan requires a live check before this PR. On 2026-09-21 the branch ran on
the user's Mac (macOS 27) against their separately running bridge. The user
was given the checklist (traffic lights expanded and with the rail, dragging,
clicks on toolbar buttons, double-click zoom, full screen, and light, dark and
System appearance) and reported everything but full screen good. Full screen
first showed the toolbar as a bar over the content; after the fix above the
user confirmed full screen works. A capture of the app's own window showed the
lights on the panel above New session and the collapse button in the footer.
No image was kept in the repository.

## Size

**772 changed lines (690 additions and 82 deletions) across 16 files** at the
measured checkpoint, with no generated lines; 22 of them are this plan's
`PLAN.md`. Reproduce from the root:

```sh
git diff --numstat 520f24f84c75c36f656aa2372ecaeba75f4a744a 2b57085925d35e72968b93ddf953e03795e9b61f
```

The base is `git merge-base origin/main 2b57085925d35e72968b93ddf953e03795e9b61f`.
The step target was 350; the repository soft cap is 1,500. Tests are 329 of
the lines and the regression document 33. The authored production code grew
past the target because the hidden title bar turned out to need host-driven
drag regions on every screen, which the plan had not measured, and because the
live check added the footer button and the list clip. This file and the
tracker row come on top; final self-inclusive accounting belongs in the PR
body.

## Regression Documents

`desktop-cockpit-shell.md` gains the title bar's required behaviour (the
lights on the panel, the rail below them, the drag and zoom regions, the root
band, full screen, the footer collapse button, the clipped list highlights and
the forced brightness), the matching automated coverage, a manual macOS check,
and `MainFlutterWindow.swift` among its maintenance sources.
