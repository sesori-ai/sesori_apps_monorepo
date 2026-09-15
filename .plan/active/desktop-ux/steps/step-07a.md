# Step 7.a — Shared settings composition

## Delivery boundary

The integrated Settings implementation measured 1,671 changed lines before
final documentation (56 generated; 593 in route-era test replacement).
This preparation extracts shared app information/picker access, desktop copy,
connected-bridge section naming, and native preference commands. Step 7.b owns
the visible modal, tabs, route retirement, keyboard entry and rendering checks.
No temporary route, compatibility shim, new state owner or extra subscription
bridges the split. The prepared consumers are checkpointed locally at
`5c1cd88b7394b5369af2903aad54abf79cab0e7b` for the immediate successor.

Implementation: `dae8e9afa3be8b18ac2995775422aeccda4c7d53`, based on
`42b3f6849164826784f76d39ef59ded74ba204f7`: 352 changed lines, 56 generated.
The current series has 14 PRs; published PR titles and both planning tables were
synchronized without rewriting squash-commit history.

## Evidence

Pinned Flutter 3.47.4 and its bundled Dart SDK; all platform capabilities/auth
are fakes.

- 33 control cases: `dart test --reporter json
  test/cubits/bridge_control/bridge_control_cubit_test.dart` in
  `client/module_desktop_core`. Includes native refresh, refresh/write exclusion,
  failure unlocking, and explicit-value rather than toggle semantics. Executed
  on the integrated checkpoint; Git comparison confirms these source/test files
  are identical in the extracted implementation.
- 5 route-era desktop settings cases and 30 mobile settings cases passed on the
  independently restored preparation tree. Commands: `flutter test --no-pub
  --reporter json test/features/settings/desktop_settings_screens_test.dart` in
  `client/desktop`, and `test/features/settings/settings_screen_test.dart` in
  `client/app`. Two redundant private imports were then removed because the
  picker is now exported; these import-only edits were analyzed, not retested.
- `dart analyze --fatal-infos` passes in desktop core, shared UI, desktop and
  mobile. Localization generation and `git diff --check` pass.
- Fresh architecture implementation review approved the exact frozen range
  above with no findings (run `6f21a7ef-cf2c-42ed-90f8-e5a7bb0f72cf`). It applied
  A1–A13 and B-Client/B-C1–B-C9; the successor modal was explicitly excluded.
  This was read-only review, not additional runtime or test evidence.

No app/bridge/helper was launched, stopped, restarted or taken over; no native
registration, auth/preferences or live bundle was modified. This preparation
has no user-visible or database change. It does not claim modal, native/live,
relaunch, lifecycle or energy coverage; those remain with 7.b/final qualification.
