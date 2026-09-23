# Step 10 — Status and diff colours

## What changed

- `DiffTheme` derives every colour from `PregoColors` instead of hard-coded
  hex values per brightness.
  - An added or removed line has a 10% tint of `fgSuccessPrimary` or
    `fgErrorPrimary`, and a 2-point bar of the same colour at its left edge.
  - The tint and the bar belong to the row, so they run the full height of a
    wrapped line. The gutter no longer has its own fill, which removes the
    notches (FC2). The bar paints over the gutter's first 2 points, so the layout keeps its old widths.
  - Hunk and file headers use `bgSecondary` and `borderSecondary`. Line
    numbers use `textQuaternary`, the +/- marker `textTertiary`, code
    `textPrimary`, and the chevron `fgTertiary`.
- The file header's pastel badge is a plain coloured letter in the code style:
  A is success, D is error, M is warning (FC3). The file name and counts use
  the code style (CD6 leftovers from step 9).
- Zero counts are left out, and the minus sign is "−" on both file headers and
  the page subtitle (FC1). The subtitle string keeps only "N files changed",
  and the counts are composed in code.
- Remaining raw colours (CD5):
  - PR status green and amber use `fgSuccessPrimary` and `fgWarningPrimary`.
    Merged purple stays raw, with a comment: no Prego token means "merged".
  - `kStatusAmber` is removed. The "Awaiting input" label uses
    `textWarningPrimary`, like the desktop sidebar.
  - The skipped-file placeholder uses tertiary text instead of `Colors.grey`.
  - Left as they are: the logo art, the macOS window dots, the onboarding's
    native-style switch and its shadows, and the transparent window colour.

## Verification

- `client/module_app_ui`: `dart analyze --fatal-infos` is clean and all tests
  pass. The line test checks tint and bar for added, removed and context rows
  in light and dark. The file test checks the "−" sign, a hidden zero side,
  and the plain letter.
- `client/app`: analyze is clean; `test/features/session_diffs`,
  `test/features/session_list` and `test/core/widgets/session_split` pass.
- `client/desktop`: analyze is clean.
