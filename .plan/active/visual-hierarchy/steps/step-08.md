# Step 8 — Blue and the email form

## What changed

- Desktop primary buttons use the inverse pill (`.primaryAlt`), as the phone
  already did. The two buttons are New session on the project page and the
  bridge popover's Take over.
- The desktop Archived toggle turns blue (`.primary`) while on. Before, it
  used the inverse pill and would have looked like New session. D5: blue
  means on.
- The tool output's "Show more" is primary text instead of brand blue (secondary fails 4.5:1 on the dark recessed block).
  Step 31 removes this control.
- The "Jump to latest" pill uses the `bgSurface3` surface with primary text.
  It was a brand fill. Its Material arrow becomes Tabler's `arrow_down`.
- `PregoInputField` drops `isRequired` and its brand asterisk; the three
  callers (email login, harness settings, bridge settings) passed `true` only
  to draw it. The placeholder uses `textTertiary`, not `textPlaceholder`.
- The question banner turns amber in step 14.

## Verification

- `module_prego`: `prego_input_field_test.dart` passes. It asserts the label
  has no asterisk and the placeholder is tertiary.
- `module_app_ui`: `test/features/session_detail` and `test/features/settings`
  pass.
- `app`: `test/features/login` and `test/features/settings` pass. The email
  sheet test asserts plain labels.
- `desktop`: `test/features/sessions` and `test/core` pass. The Archived
  toggle test expects `.primary` while on.
- `dart analyze --fatal-infos` is clean on `lib` in all four packages.
