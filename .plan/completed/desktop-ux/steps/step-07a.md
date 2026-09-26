# Step 7.a — Shared settings composition

## Delivery boundary and size

This preparation extracts shared app information/picker access, desktop copy,
connected-bridge section naming, and native preference commands. Step 7.b owns
the modal, tabs, route retirement, keyboard entry and rendering checks. No
interim route, compatibility shim, state owner or subscription bridges the split.
The concrete successor is checkpointed at `5c1cd88b7394b5369af2903aad54abf79cab0e7b`.

All totals below include generated lines, and include every tracked file in the
named snapshot. Base/merge base: `42b3f6849164826784f76d39ef59ded74ba204f7`.

| Snapshot | Additions | Deletions | Total | Generated / authored |
|---|---:|---:|---:|---:|
| Integrated `5c1cd88b7394b5369af2903aad54abf79cab0e7b` | 946 | 724 | 1,670 | 56 / 1,614 |
| Extracted implementation `dae8e9afa3be8b18ac2995775422aeccda4c7d53` | 258 | 94 | 352 | 56 / 296 |
| Initial published head `d71479ecfa12bc5e576e153802975e9c190b1784` | 309 | 94 | 403 | 56 / 347 |

Reproduce the rows, then sum the first two columns across all paths:

```bash
git diff --numstat 42b3f6849164826784f76d39ef59ded74ba204f7 5c1cd88b7394b5369af2903aad54abf79cab0e7b
git diff --numstat 42b3f6849164826784f76d39ef59ded74ba204f7 dae8e9afa3be8b18ac2995775422aeccda4c7d53
git diff --numstat 42b3f6849164826784f76d39ef59ded74ba204f7 d71479ecfa12bc5e576e153802975e9c190b1784
```

Generated paths are the two
`client/module_app_ui/lib/src/l10n/app_localizations*.dart` files. The 403 adds
51 documentation lines to the 352-line extraction; it is not the same snapshot.
The earlier 1,671-line working-tree estimate included one unused import removed
before the integrated commit. Final self-inclusive accounting lives in the PR
body so evidence updates do not recursively invalidate a claimed final size.
Published PR titles and planning tables now share the 14-PR total; squash-commit
history was not rewritten.

## Evidence and provenance

Pinned Flutter 3.47.4 and its bundled Dart SDK; platform/auth capabilities are fakes.
Counts are distinct cases, not sums of reruns.

- **33 control cases** pass at `3a6bc1f0a1f7107977ba81b1bbb30560464deabe`,
  tested tree `153fdb982374960d7682b29fe55208a1037446f2`. From
  `client/module_desktop_core`: `dart test --reporter json
  test/cubits/bridge_control/bridge_control_cubit_test.dart` and
  `dart analyze --fatal-infos`. The review fix preserves busy/idle snapshots,
  removes the redundant intermediate emission, and retains initialization's
  menu refresh. These reruns supersede, rather than add to, the original 33.
- The original control source/test equivalence is reproducible with:

  ```bash
  git diff --exit-code 5c1cd88b7394b5369af2903aad54abf79cab0e7b \
    dae8e9afa3be8b18ac2995775422aeccda4c7d53 -- \
    client/module_desktop_core/lib/src/cubits/bridge_control/bridge_control_cubit.dart \
    client/module_desktop_core/test/cubits/bridge_control/bridge_control_cubit_test.dart
  ```

  This proves only those files are equal, not whole-tree test equivalence.
- **5 desktop + 30 mobile settings cases** passed on the independently restored,
  uncommitted preparation tree. Its whole-tree hash was **not captured**; these
  are not claimed as final-head reruns. Commands: `flutter test --no-pub
  --reporter json test/features/settings/desktop_settings_screens_test.dart` in
  `client/desktop`, and `test/features/settings/settings_screen_test.dart` in
  `client/app`. Two redundant private imports were subsequently removed;
  those import-only edits were analyzed, not retested. Shared UI, desktop and
  mobile analyzers passed after the relevant edits. GitHub checks also passed
  12/12 at published head `d71479ecfa12bc5e576e153802975e9c190b1784`
  (tree `5912bb9dd7f1f1084d5f78c4ad806ad7a0820598`).
- Localization generation and whitespace/link validation pass. Fresh read-only
  architecture review approved base through `dae8e9afa3be8b18ac2995775422aeccda4c7d53`
  with no findings (run `6f21a7ef-cf2c-42ed-90f8-e5a7bb0f72cf`, A1–A13 and
  B-Client/B-C1–B-C9). The routine snapshot fix above has separate test evidence;
  neither it nor the successor modal is claimed inside that frozen review.

No app/bridge/helper was launched, stopped, restarted or taken over; no native
registration, auth/preferences or live bundle was modified. No user-visible or
database change lands here. Modal, native/live, relaunch, lifecycle and energy
coverage remain with 7.b/final qualification.
