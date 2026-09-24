# Step 6 — Title ladder on the phone

## What changed

- `PregoNavTitle` (the centred bar title): 18 bold primary, and the subtitle is
  12 medium tertiary. Before, the title was 18 medium and the subtitle 16
  medium secondary.
- `PregoNavLeadingTitle` (the bar title beside the back button): 18 bold
  primary. The muted/prominent `PregoNavLeadingTitleEmphasis` switch is gone:
  there is one bar title now. Its line height is 1.15 so the two-line block
  still fits the 54pt bar at 250% text scale.
- `PregoNavSubtitle`: text and icon are tertiary. The status dot is unchanged.
- The large title is 36 bold, was 36 medium. `PregoGlassScaffold.subtitle`, the
  caller-composed row, now also sits under the large title. `subtitleText` is
  inline-only.
- Projects moves from the back-leading bar to the large title. The status row
  under it is unchanged: the machine name, a skeleton while it loads, the
  onboarding's waiting row, and no row when the lookup finds nothing to name.
  Settings already had the large title.
- A two-line bar title caps its text scale (1.25 beside the back button, 1.4
  centred) so it fits the fixed 54pt bar. A title on its own keeps the full
  text scale. Before this step, both two-line blocks overflowed the bar above
  about 130% text.
- File Changes, the only other page with a large title, now uses the inline
  bar title with its totals as the subtitle.
- Desktop pages that use the inline bar (settings) or `PregoNavSubtitle`
  (session detail) pick up the same styles. Step 7 rebuilds the desktop page
  header.
- The formatter re-indented the primary-constructor parameters in three
  touched Prego files. This is formatting only.

## Verification

- `client/app`: `test/components/navigation`, `test/features/project_list`,
  `test/features/session_list`, `test/features/session_diffs`,
  `test/core/widgets/session_split`, `test/core/routing` and `test/playbook`
  pass.
  - The nav tests assert each style's size, weight and colour, and that both
    bar titles fit the 54pt bar at 130% and 250% text, with and without a
    subtitle.
  - The Projects tests assert the large title in the offline, onboarding,
    loading and loaded states.
  - The split-view test asserts File Changes is the bar's inline title.
- `client/module_prego`: all tests pass, including the new
  `prego_glass_scaffold_large_title_test.dart`.
- `client/module_app_ui`: `test/features` passes.
- `client/desktop`: `test/features/settings` and `test/features/sessions` pass.
- `dart analyze --fatal-infos` is clean in module_prego, module_app_ui, app and
  desktop.
