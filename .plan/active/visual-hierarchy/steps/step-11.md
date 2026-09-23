# Step 11 — One icon set and sentence case

Split in two PRs: 11.a moves every icon to Tabler and adds the lint; 11.b
changes Title Case strings to sentence case.

## 11.a — What changed

- Every Material `Icons.` glyph in production code is now its Tabler
  equivalent: 42 distinct glyphs across 27 files. Filled Material variants map
  to `TablerSolid` (error, check_circle, check_box, cancel, circle); the rest
  map to `TablerRegular`. Chevrons are Tabler everywhere.
- New `no_slop_linter` warning `avoid_material_icons`. It reports
  `Icons.<name>` when `Icons` is Material's class, and skips test files.
- Tests that looked up a glyph use the same Tabler names. Test-only fixture
  icons (mail, delete, more, info, task) stay Material, because the lint skips
  tests.
- The X brand stays on `TablerRegular.brand_twitter`. The bundled font has no
  `brand_x`, and an SVG would not fit the `IconData` parameters of the two
  call sites (the settings row and the onboarding help menu). Revisit if the
  Tabler font is updated.

## 11.a — Verification

- `shared/no_slop_linter`: analyze is clean and all tests pass, including the
  new rule test (reports Material `Icons`, allows Tabler and another `Icons`
  class).
- `dart analyze --fatal-infos` is clean in module_prego, module_app_ui, app
  and desktop, with the new rule active.
- All module_prego and module_app_ui tests pass. In app, `test/features`,
  `test/components` and `test/core` pass; in desktop, `test/features` and
  `test/core` pass.

## 11.b — What changed

- 25 Title Case strings in `app_en.arb` are sentence case, for example
  "Add project", "Connection lost", "Log out", "File changes", "Start bridge",
  "Terms of service" and "AI notifications".
- Names keep their capitals: Sesori, GitHub, Apple, Google, Git, X, Windows
  PowerShell, and the macOS "Full Disk Access" and "System Settings".
- 17 tests that matched the old wording use the new strings. Older plan and
  regression docs that name an action in prose are unchanged.

## 11.b — Verification

- `flutter gen-l10n` regenerated the English localizations.
- All module_app_ui and app tests pass; desktop `test/features` and
  `test/core` pass, before and after merging 11.a.
