# Step 6 — The sidebar floats as an elevated panel

## Scope

- **Depth delimits (D7).** `DesktopCockpitShell` wraps the sidebar, expanded or
  as the rail, in an 8-point margin at the window's top, bottom and start
  edges, clips it to 14-point corners, and draws a hairline border over it and
  the design system's `shadows.lg` under it. The pages already paint the base
  surface (`bgSurface1`, the scaffold background), so the lighter panel reads
  as raised in both themes; the dark theme's shadow tokens are transparent by
  design, so there the border and the lighter surface carry the depth.
- **No divider.** The `VerticalDivider` presentation is deleted. The 8-point
  gap between the panel and the main pane is the resize handle while the
  sidebar is expanded: the same gestures and tooltip, a resize cursor and no
  visible line. The fixed-width rail has no handle.
- **Geometry.** The keyed sidebar box is still the panel itself, so the width
  bounds (200–420) and the 56-point rail keep their meaning; the main pane
  starts 16 points past the panel's width. `DesktopSidebar.panelMargin` is the
  one constant behind the shell's margin and the rail popout's placement:
  `DesktopSidebarActivityPopout` takes a required `railStart` so the popout
  still opens beside the rail, not over it. The panel clips the footer's
  border. The connection pill stays centred over the main pane, which moved as
  a whole; nothing about it needed to change.
- No new string, no wire, database or analytics change. The phone is
  unchanged.

## Automated Evidence

Measured checkpoint: commit `245f7b0dd1952d1d7449593f98be380c351a691d` with a
clean working tree, Flutter 3.47.4 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. This file and the tracker row were added afterwards as documentation
only and were not re-measured.

```sh
cd client/desktop
flutter test --no-pub
flutter analyze --no-pub
```

- `desktop`: the full suite, 253 cases, passes. The new shell case proves the
  panel's rectangle expanded (8, 8, 268, 592 in the 800 × 600 test window) and
  collapsed (8, 8, 64, 592), the resize handle filling exactly the gap between
  panel and main pane and disappearing beside the rail, the main pane starting
  one margin past the panel, and no `VerticalDivider` anywhere. The
  every-width case now expects the main pane to be the window minus the panel
  and two margins at 560, 900 and 1,400 points. The rail popout case now
  requires the popout to start past the rail's real trailing edge; without
  `railStart` it would start exactly on that edge and fail.
- `flutter analyze` reports no issues. No generated file changed.
- Appearance was checked once in rendered output with the packaged fonts and
  real shadows, in light and dark, expanded and as the rail; the images were
  not kept in the repository.
- Architecture review: not run. The step adds no class, file, dependency, DI
  registration, lifecycle, or wire or persisted contract. Its only signature
  changes are inside the desktop shell's own widgets: the constant
  `DesktopSidebar.panelMargin` and the required `railStart` parameter on
  `DesktopSidebarActivityPopout`, whose single caller is the sidebar. That is
  presentation within one package, which the repository's review rules
  exclude.

## Size

**123 changed lines (91 additions and 32 deletions) across 5 files** at the
measured checkpoint, with no generated lines. Reproduce from the root:

```sh
git diff --numstat 0f5d4611366b813f87571755393a93219bdde0e4 245f7b0dd1952d1d7449593f98be380c351a691d
```

The base is `git merge-base origin/main 245f7b0dd1952d1d7449593f98be380c351a691d`.
The step target was 450; the repository soft cap is 1,500. This file and the
tracker row come on top; final self-inclusive accounting belongs in the PR
body.

## Regression Documents

`desktop-cockpit-shell.md` opens its required behaviour with the floating
panel's pixel invariants (insets, corners, border, shadow, the 16-point
main-pane offset, the resize gap and the rail's lack of one), and gains the
matching automated coverage, a light/dark manual check, and failure signals
for a divider, square corners, a handle beside the rail and a popout over the
rail.
