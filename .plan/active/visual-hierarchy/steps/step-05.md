# Step 5 — Grey ramp and section headers

## What changed

- `figma_tokens.json` adds two grey primitives, `Gray/430` `#8A8A8A` and
  `Gray/440` `#6A6A6A`. `text-tertiary` now maps to `Gray/440` in light and
  `Gray/430` in dark, instead of `Gray/450` `#5C5C5C` in both. The generated
  files were regenerated, not edited.
- Contrast of tertiary text:
  - dark: 5.3:1 on the page and 5.1:1 on cards, up from about 2.7:1;
  - light: 4.8:1 on the `#F0F0F0` page and 5.3:1 on cards, down from about
    6:1.

  D4 aimed for about 5.0:1 on white in light. The light page is `#F0F0F0`, so
  `#6A6A6A` was chosen to stay above 4.5:1 there.
- Quaternary is unchanged. It has no users, and it already sits below tertiary
  in both themes.
- Section headers take D7:
  - session list date groups: 14 medium tertiary, was 14 regular secondary;
  - `SettingsSection`: 14 medium tertiary, was 16 medium secondary;
  - `DesktopSidebarSectionHeader`: 12 medium tertiary, was 12 bold secondary.
    The desktop is one step smaller.
- Figma: the user needs to mirror the two primitives and the tertiary mapping,
  or the next export reverts them.

## Verification

- `client/module_prego`: the new `prego_text_contrast_test.dart` checks each
  theme on the page and card surfaces. Tertiary must reach at least 4.5:1,
  secondary must contrast more than tertiary, and quaternary less.
  `test/theme` passed (5).
- `client/module_app_ui`: `test/features/settings` and
  `test/features/session_list` passed (84).
- `client/desktop`: `test/core/widgets` passed (78).
- `dart analyze --fatal-infos` is clean in module_prego, module_app_ui and
  desktop.
