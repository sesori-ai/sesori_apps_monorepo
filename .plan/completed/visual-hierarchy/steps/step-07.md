# Step 7 — Desktop page header

## What changed

- `DesktopPageToolbar` loses its leading slot. It takes an optional
  `breadcrumb` (label and action) and an optional `status` widget:
  - the breadcrumb is 14 regular tertiary, followed by a tertiary chevron;
  - the status widget sits in the sidebar's 28pt status column;
  - the title is 16 bold primary.
- No page toolbar has a back arrow, so every toolbar starts at the same left
  edge.
- The shell binds Cmd/Ctrl+[: it pops a pushed page and does nothing on a page
  reached from the sidebar. The old `_popRoute` helper sent a non-pushed page
  home; it only served the removed back arrow, so it is gone.
- New session and session pages show the project as the breadcrumb (falling
  back to "Sessions" when the route has no name). It opens the project's
  sessions page. The new session page keeps `onBack` for the shared view's
  abort path.
- The session page:
  - the status slot shows the sidebar's glyphs: the running sparkle, and the
    amber awaiting glyph while a question or permission is pending;
  - the separate busy spinner is gone;
  - Mark as unread moves from a toolbar button to the top of the more menu,
    labelled ⇧⌘U or Ctrl+Shift+U.
- The sidebar's private `_SessionSignals` becomes `DesktopSessionSignals`, so
  the toolbar shares it.

## Verification

- `client/desktop`: every test outside the untracked throwaway files passes.
  New or changed tests:
  - the breadcrumb, status slot and title styles and order;
  - the breadcrumb opens the project;
  - Mark as unread from the menu shows its shortcut and leaves the page;
  - Cmd/Ctrl+[ pops a pushed child and does nothing on a direct page;
  - both breadcrumbs open the project's sessions in the router test.
- `client/module_app_ui`: `test/features/session_list` passes.
- `dart analyze --fatal-infos` is clean on desktop `lib` and the touched tests,
  and on module_app_ui `session_list`.
