# Step 2 — Tool details and desktop page fades

## What changed

- `tool_part_widget.dart`: the shell panel and the long-output Show more ease
  open and shut over 200 ms (ease-out, growing down from the row) through one
  private `_AnimatedDisclosure`. Under reduced motion it renders the child
  with no `AnimatedSize` at all, because a zero-duration `AnimatedSize`
  re-dirties itself during its own layout.
- Expanding a historical shell command now scrolls it into view after the
  panel has grown (`AnimatedSize.onEnd`), not before. A one-shot flag makes
  only the user's own expand scroll, never a later resize of an open panel.
- `desktop_router.dart`: the shell's pane navigator gets a scoped
  `PageTransitionsTheme` whose one builder fades the incoming page in over
  150 ms, or switches at once under `prefersReducedMotion`.

## Deviation from the plan text

The plan said "one fade page builder" for the routes. A theme-level
`PageTransitionsBuilder` on the pane navigator does the same with less code:
routes keep `builder:`, so `ModalRoute.canPopOf` inside pages and the route
table tests are unchanged, and only the main pane is affected. The settings
window's own navigator and root dialogs keep their current motion.

## Verification

- `client/module_app_ui`: `tool_part_widget_test.dart` (18 passed), including
  intermediate heights at 100 ms for shell expand and collapse and for Show
  more, and a reduced-motion open with no `AnimatedSize` in the tree.
  `dart analyze --fatal-infos`: no issues.
- `client/desktop`: `desktop_router_test.dart` (14 passed), including the
  150 ms fade at half opacity with the old page still shown, and the instant
  reduced-motion switch. `dart analyze --fatal-infos lib test/core`: no issues.
- Regression docs: `tools-and-file-changes.md`, `navigation-transitions.md`.

## Review round 1

- Fixed: `context.isReducedMotion` read only `MediaQuery.disableAnimations`,
  which misses iOS Reduce Motion. It now delegates to `prefersReducedMotion`,
  which uses null-safe lookups so synthetic route-test contexts still resolve
  to "no preference". Every shared-UI caller gains iOS Reduce Motion.
  Verified: module_app_ui tool, message list, bubble and image viewer tests
  (110 passed), app routing, onboarding and bridge-offline tests (59 passed),
  module_prego (330 passed), desktop router (14 passed); analyzers clean.
- Declined: the reverse fade duration (the framework's
  `reverseTransitionDuration` returns `transitionDuration`), the
  replace-driven new-session change (an in-place continuation, now stated in
  `navigation-transitions.md`), and a 120-character table-row limit that the
  regression docs do not follow.

## Review round 2

- Fixed: collapsing the shell panel removed its details at once and left a
  blank area to shrink, because `AnimatedSize` only resizes around the new
  child. The panel now runs on its own controller through a `SizeTransition`
  and stays mounted until it has closed; completion of the user's expand
  replaces the one-shot reveal flag. Show more keeps `AnimatedSize`, where the
  grey output box fills the shrinking area. Verified: `tool_part_widget_test.dart`
  (19 passed), including the panel still present mid-collapse and gone after,
  and both reduced-motion sources opening and closing in one frame;
  `dart analyze --fatal-infos` clean.

## Review round 3

- Fixed: the shell panel's close ran `Curves.easeOut` backwards, so it started
  slowly and sped up into the end. It now closes on `Curves.easeIn`, which
  run backwards decelerates like the open. Verified: `tool_part_widget_test.dart`
  (19 passed), now asserting that both directions are past halfway at half
  time; `dart analyze --fatal-infos` clean.
