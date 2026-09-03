# Step 20 slice 1/3 — Desktop window bounds

- **Status:** `done`
- **Complexity:** `⚙️`
- **User value:** Desktop window size and position survive relaunch and remain usable after display changes.
- **Dependencies:** Step 19
- **Pinned implementation range:** `74d84c4ddcd4818ea2b435088f014cdfd5229c9a..34cf314c807259174c99c7649f33256522fbddd9`

## Scope

- Add platform-neutral window bounds, size, move, and resize contracts.
- Persist bounds through the existing desktop-instance storage/repository layers.
- Restore validated, display-clamped bounds before the first explicit show.
- Debounce move/resize persistence and flush the final observation before terminal window disposal.
- Exclude cockpit navigation and attention-notification state from this independently usable slice.

## Implementation Summary

- Added immutable `WindowBounds` and `WindowSize` models plus `moved`/`resized` events to the Layer-0 `WindowHost` capability.
- Extended `DesktopInstanceStorage` and `DesktopInstanceRepository` with typed window-bounds persistence under desktop-owned application data.
- Added `WindowBoundsService` as the Layer-3 owner of persisted-value validation, display selection, usable-work-area clamping, restoration, debounce, retry after failed writes, and final flushing.
- Kept `FlutterWindowHost` as a native adapter for `window_manager` and `screen_retriever`; it applies service-owned bounds before show but owns no persistence policy.
- Routed startup through `DesktopStartupOrchestrator.initializeWindow()` and made terminal Quit await `WindowBoundsService.dispose()` before `WindowHost.dispose()`.
- Kept the existing centered 720×620 fallback and a 560×480 minimum where the selected display can accommodate it; compact work areas receive a display-adjusted native minimum.
- Suppressed MainMenu.xib's first native window ordering on every macOS launch so Dart restores bounds before the first visible show.
- Updated the desktop supervision regression contract and recorded the three-PR Step 20 replacement after closing oversized PR #1265 unmerged.

## Architecture Review

- The first bounded review confirmed restore-before-show, flush-before-host-dispose, persistence layering, and adapter boundaries, but rejected unused focus/visibility state that belonged to the later attention slice.
- Removed `WindowHostState`, `currentState`, `states`, and all adapter/test state machinery while retaining the bounds APIs and consumed move/resize events.
- The second bounded review over the pinned range was **APPROVED** with no findings. It confirmed the prior A5 finding was resolved and all lifecycle and layering invariants remained intact.

## Verification

- `client/module_desktop_core`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 216 tests.
- `client/desktop`: `asdf exec dart analyze --fatal-infos` passes; the full suite passes 97 tests.
- Dart LSP reports zero diagnostics across all 12 changed production Dart files.
- `git diff --check` passes.
- A clean `asdf exec flutter build macos` succeeds (65.7 MB reported by Flutter), and `codesign --verify --deep --strict` accepts the resulting app bundle.
- Real display rearrangement and relaunch ergonomics remain part of user-run MT Gate C after all three Step 20 slices.

### Line-budget reproduction

The implementation head is `34cf314c807259174c99c7649f33256522fbddd9`. The measurement is intentionally
not self-inclusive: it excludes only the later evidence-only commit that updates this section.

```bash
base=$(git merge-base 74d84c4ddcd4818ea2b435088f014cdfd5229c9a 34cf314c807259174c99c7649f33256522fbddd9)
git diff --numstat "$base" 34cf314c807259174c99c7649f33256522fbddd9 \
  | awk '{ additions += $1; deletions += $2 } END { print additions, deletions, additions + deletions }'
# 1016 72 1088
```

The 1,016 additions plus 72 deletions reconcile to 1,088 total changed lines across 25 files, below the 1,500-line soft cap.

## Acceptance

- [x] Valid saved bounds are clamped to a current display and applied before first show.
- [x] Missing, invalid, or undiscoverable bounds use the centered default.
- [x] Compact display work areas reduce the native minimum instead of forcing restored bounds off-screen.
- [x] macOS suppresses the XIB frame until the adapter performs the post-restoration show.
- [x] Move and resize observations debounce persistence, and a failed write does not poison a later write.
- [x] Terminal Quit flushes final bounds before native window disposal.
- [x] The adapter remains policy-free and persistence follows Layer 1 → Layer 2 → Layer 3 ownership.
- [x] Attention-only focus/visibility state is deferred to the slice that consumes it.
- [x] Relevant analyzers, full suites, LSP diagnostics, clean macOS release build, codesign verification, and architecture review pass.
