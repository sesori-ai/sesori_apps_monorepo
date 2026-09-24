# Step 15 — Settings window

Split in two: 15.a is the window's chrome and pages; 15.b is the bridge popover.

## 15.a What changed

- Pages inside the desktop settings window draw no title bar. The tab rail
  names the page, and one small plain X (tertiary icon button, top-right)
  replaces each page's glass close pill. Escape and outside click still close.
- `SettingsWindowPage` is the bare scrolling page the window hosts;
  `SettingsPageChrome` (own glass bar or in-window) lets the shared Profile
  view serve both the phone and the window. Harness views get a `window`
  presentation that is never routed.
- Tabs use the main sidebar's selected-row fill and 14-point medium labels.
- Bridge's connected-bridge intro is 12-point tertiary text inside its
  section; Pull request refresh shows a chevron after its value.
- General's theme picker is a Light/Dark/System segmented control instead of
  the phone's preview tiles. At large text sizes it drops below its label.

## 15.a Verification

- `client/desktop` (`lib test/core test/features`), `client/module_app_ui`,
  `client/module_core` and `client/app`: `dart analyze --fatal-infos` is clean.
- `client/desktop` `test/core` and `test/features` pass, including every tab at
  560 × 480 through 250% text scale; the first renders caught a theme-row
  overflow at 250%, now fixed.
- `client/module_app_ui` and `client/app` `test/features/settings` pass.
- Rendered every tab in light and dark before and after and compared them.
