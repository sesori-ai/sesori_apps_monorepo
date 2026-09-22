# Step 8 — Compact menus open at the pointer

## Scope

- **One pointer input.** `client/module_prego` gains the closed
  `PregoInteractionMode` (`touch`, `pointer`) and the inherited
  `PregoInteractionScope`, whose `of(context)` answers `touch` where no scope
  exists. The desktop app installs one `pointer` scope at its root in
  `app.dart`; the phone installs nothing. It carries no spacing or theme
  values, and in this step only `PregoAnchorMenu` reads it, in one place.
- **Compact menus (D12).** In pointer mode the flat menu ignores `spotlight`
  (no dimming, no lifted row), draws 30-point rows with 16-point icons, an
  8-point panel radius and 4-point panel padding, and shows a trailing shortcut
  label. A secondary click opens it with its top-left corner on the pointer; it
  flips above the pointer only when it does not fit below. A menu opened from a
  button still hangs off its trigger. Every desktop call site inherits the
  look, the composer's agent, model and effort menus included.
- **Placement.** `AnchoredFlatPanel`, shared by `PregoAnchorMenu` and
  `PregoPopover`, takes a required `AnchoredPanelPlacement` (`besideTrigger`,
  `atCorner`). `atCorner` has no gap and only fades in. The menu records the
  position of a secondary-button press on its trigger and clears it when the
  menu's route completes. The corner placement is left-to-right only.
- **Deviation from the plan, forced by the toolchain.** The plan fed a
  `SingleActivator` to Flutter's `LocalizedShortcutLabeler`. In Flutter 3.47
  and `material_ui` 1.2.0 that class is private (`_LocalizedShortcutLabeler`),
  so `PregoMenuItem` takes `required String? shortcutLabel`, formatted by the
  host the way the desktop sidebar already formats its hints ("⌘N" or
  "Ctrl+N"). Shared code still never formats key names or checks the platform.
  Every production call site passes `null` today; step 11 supplies the first
  real label.
- The glass menu path ignores the scope; every current call site is flat.
  No new string, no wire, database or analytics change. The phone is unchanged.

## Automated Evidence

Measured checkpoint: commit `696ef4c7f9dc82b6c8021109de73a43d90df0560` with a
clean working tree, Flutter 3.47.5 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. This file and the tracker row were added afterwards as documentation
only and were not re-measured.

```sh
cd client/module_prego
flutter test --no-pub
flutter analyze --no-pub
cd ../module_app_ui
flutter test --no-pub
flutter analyze --no-pub
cd ../app
flutter test --no-pub
flutter analyze --no-pub
cd ../desktop
flutter test --no-pub
flutter analyze --no-pub
```

- `module_prego`: 321 cases pass. The new "Pointer mode" group proves a
  secondary click drops a compact menu at the pointer with no spotlight, a
  30-point row and the shortcut label; the flip above the pointer near the
  bottom edge; a button press still hanging the menu 8 points below its
  trigger, even after an earlier secondary click; and a shell without a scope
  keeping the spotlight, 54-point rows and no shortcut.
- `module_app_ui`: 385 cases pass. `app`: 774 cases pass. `desktop`: 263 cases
  pass; its smoke test asserts the app installs the pointer scope. All four
  analyzers report no issues. No generated file changed.
- Appearance was checked once in rendered output with the packaged fonts, in
  light and dark, pointer and touch; the images were not kept in the
  repository.
- Architecture review (`architecture-implementation-review`, one run on the
  branch before its rebase onto step 7): approved with no findings. Its one
  functional note, that the glass path does not read the scope, is answered
  above. The rebase changed only one constant list in a test.

## Size

**360 changed lines (311 additions and 49 deletions) across 15 files** at the
measured checkpoint, with no generated lines; 121 are tests and 20 the
regression documents. Reproduce from the root:

```sh
git diff --numstat 96cb027a620d59f59a6e079fff34a091cd73c2e0 696ef4c7f9dc82b6c8021109de73a43d90df0560
```

The base is `git merge-base origin/main 696ef4c7f9dc82b6c8021109de73a43d90df0560`.
The step target was 500; the repository soft cap is 1,500. This file and the
tracker row come on top; final self-inclusive accounting belongs in the PR
body.

## Regression Documents

`desktop-cockpit-shell.md` gains the pointer menus' required behaviour, their
automated coverage, a manual right-click check and their maintenance sources.
`glass-presentation.md` now says spotlights belong to the touch presentation
and lists a desktop menu that dims the window or lifts its row as a failure.
