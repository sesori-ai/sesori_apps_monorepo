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
