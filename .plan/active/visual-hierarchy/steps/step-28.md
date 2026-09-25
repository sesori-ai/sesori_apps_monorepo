# Step 28 — Filtered rows

## What changed

- `PregoAnimatedSliverList` animates a row's entry only when the row lands in
  a window that covers the list's visible extent. The window is an upper
  bound: rows taller than the minimum leave some off-screen rows in it, and
  those still animate. Other inserted rows enter at full size and build
  lazily as they scroll in. Before, every inserted row entered at zero height,
  so they all fit in the first frame and the list built every one of them.
- The visible extent comes from the list's last layout. The first visible
  index is the last built row starting at or above the scroll offset. The row
  count is the remaining paint extent divided by `kMinInteractiveDimension`,
  because rows are tap targets and none is shorter. A list that has not been
  laid out animates every row, as before. In a shrink-wrapped
  `PregoAnimatedList` the extent is unbounded, so every row there still
  animates.
- The same window applies to removals: an off-screen row leaves at once
  instead of running a transition nobody sees.

## Deviations

- **Removals use the window too.** The plan names inserts only. Hundreds of
  off-screen rows each ran a 260 ms exit, and the frame where they all finished
  cost 8–11 ms. It costs one line. A row removed above a scrolled list now
  leaves at once instead of sliding, which moves the visible rows in one step.
- **The frame gain is modest; the build count is the clear measure.** Other
  per-frame costs remain, such as `SliverAnimatedList` creating one controller
  for every insert. Removing those would mean replacing `SliverAnimatedList`,
  which is outside this step.

## Measurements

Local profile benchmark (`flutter run --profile -d macos`, the desktop session
list panel with 300 fixture sessions). It taps Running, All, Unread, All,
700 ms apart. The worst UI-thread build time in ms for the frame after each
tap, over two runs:

| Tap | Before | After |
|---|---|---|
| Running (rows leave) | 11.7, 14.1 | 11.9, 13.8 |
| All (200 rows enter) | 21.3, 17.5 | 18.7, 19.2 |
| Unread (rows leave) | 12.6, 15.0 | 12.8, 14.3 |
| All (240 rows enter) | 25.9, 25.6 | 14.1, 15.4 |
| Frame where exits finish (Running, Unread) | 10.9 and 10.2, 7.8 and 10.7 | 8.4 and 7.6, 8.1 and 8.2 |

The widget test's list of 100 rows at 80 px in a 600 px view built all 100
rows on the first frame before this change, and builds 20 after it.

## Verification

- `module_prego` `test/components/` passes (305 tests). The new test checks
  that at most 30 of 100 inserted rows build in the first frame, that
  visible rows are mid-transition, and that row 13 enters at full height. It
  fails without the change (100 rows built).
- `module_app_ui` `test/features/session_list` and `test/features/project_list`
  pass (73 tests). The desktop `desktop_cockpit_shell_test` passes (64 tests).
- `dart analyze --fatal-infos` is clean in module_prego.
- No architecture review: the change is method logic inside one widget.
- No regression-doc change: visible rows animate as before.
