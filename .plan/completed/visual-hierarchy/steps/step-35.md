# Step 35 — One modal entry point, enforced

Landed as #1686 (`⚙️ Lint direct modal presenters and move alerts to showPregoModal`), squash commit `07ed1e8953`.

## What changed

- `no_slop_linter` gained `avoid_raw_modal_presenters`. It flags direct calls
  to the SDK presenters from `flutter`, `material_ui` and `cupertino_ui`:
  `showDialog`, `showModalBottomSheet`, `showBottomSheet`,
  `showAdaptiveDialog`, `showGeneralDialog`, `showRawDialog`,
  `showCupertinoDialog`, `showCupertinoModalPopup` and `showCupertinoSheet`.
  Test files are exempt.
- The allowed exceptions carry reasoned `// ignore:` comments: the Prego
  presenters themselves, the desktop settings window and the desktop command
  palette. The last two are full-window overlays, not sheets or dialogs.
- Eight `module_app_ui` alerts moved from Material `AlertDialog` to
  `showPregoModal`: a sheet on touch and the Prego dialog on pointer. Their
  return values and keys are unchanged.
- Non-dismissible modals hide their close button, and `PregoButtonsSolid`
  activates on Enter and Space when it has keyboard focus.

## Deviations from the plan

- The plan said the alerts would move to "one `module_prego` alert entry
  point". They use `showPregoModal` directly with `PregoSheetActions` or
  stacked buttons, so no separate alert API was added.
- Route-type construction is not linted; only the presenter calls are.

## Verification

- `no_slop_linter` rule tests: 2 passed.
- `desktop` `desktop_settings_screens_test`: 25 passed.
- `module_app_ui` (the session_list, project_list and abort-scope tests and
  `test/widgets`): 141 passed.
- `app` session_list tests: 58 passed.
- `dart analyze --fatal-infos` is clean in module_prego, module_app_ui, app
  and desktop.
