# Step 3 — One modal entry point

## What changed

- `module_prego` gains `prego_modal.dart`. `showPregoModal` presents content
  under a fixed title: the existing `showPregoBottomSheet` under a touch
  `PregoInteractionScope`, a centred dialog under a pointer one.
  `PregoModalWidth` sets the dialog width: 440 for forms, 520 for requests,
  560 for the folder browser, 640 for reading.
- `showPregoModalRoute` with `PregoModalSurface` serves modals whose header
  follows their content: question, reasoning, and the folder browser.
  `PregoActionSheet` becomes a request-wide dialog under pointer, so the
  permission request needs no change of its own.
- The dialog frame has a title, an optional subtitle and Back, and Close. It
  uses the phone sheet's surface and the settings window's border and radius.
  It opens with the stock dialog fade, and at once under
  `prefersReducedMotion`.
- Every `showPregoBottomSheet` call in `module_app_ui` and `app` moves to it,
  except the two pickers step 4 replaces. So do the four raw
  `showModalBottomSheet` presenters: add project, question, permission and
  reasoning.
- Desktop production code is unchanged. The settings tests now install the
  pointer scope that the desktop shell installs, so they exercise the dialogs.

## Deviations from the plan text

- There are two entry points, not one. `showPregoModal` covers a fixed title.
  `showPregoModalRoute` with `PregoModalSurface` covers a title that changes
  while the modal is open, which a fixed-title builder cannot express.
- The dialog is painted in the phone sheet's `bgSecondary`, not the settings
  window's `bgSurface1`. Sheet content draws its tiles and fields in
  `bgSurface1`, and those would merge into a `bgSurface1` frame.
- Dialogs open on the root navigator. The harness settings sheets were
  already there, above the settings window, whose Close already pops
  everything above it. The question, permission and reasoning sheets used to
  stay inside the main pane. As dialogs they cover the window, as modal
  dialogs do.

## Verification

- `client/module_prego`: `prego_modal_test.dart` (7 passed) covers:
  - the touch sheet;
  - the pointer dialog's width, centring, surface and Close;
  - a dialog opened from a dialog, where Esc closes only the top one;
  - a non-dismissible dialog ignoring the scrim, and Esc under the stock
    dialog handling. The desktop shell's Esc still closes it, as it closed
    the sheet before;
  - the reduced-motion open;
  - the action sheet as a request-wide dialog;
  - a modal surface as the touch sheet.

  The package suite passed (337), and `dart analyze --fatal-infos` is clean.
- `client/module_app_ui` and `client/app`: the phone sheet tests pass
  untouched, and `dart analyze --fatal-infos` is clean.
- `client/desktop`: `desktop_settings_screens_test.dart` (25 passed) now runs
  under the pointer scope. Esc first leaves the text field, then closes the
  dialog, then the settings window. Close removes the authentication dialog
  without cancelling upstream auth. `dart analyze --fatal-infos` is clean.
- The rename, new folder, question and permission dialogs were rendered at
  1280 × 800 in both themes for a visual check. The renders are not committed.
- Regression docs: `navigation-transitions.md`,
  `questions-and-permissions.md`, `desktop-cockpit-shell.md`.
- Architecture review: rejected once, for a `width` parameter on
  `showPregoModal` that no production call used. It is removed; widths live
  on `PregoModalSurface`.
- Size: about 614 changed lines before this file, against a ≤ 600 target.
  About 190 of them are the new shared tests.
- Review round 1: the action sheet's dialog now shares the sheet's
  scroll-all flow. `prego_action_sheet_test.dart` gained the desktop's
  560 × 480 minimum window at 3x text, which overflowed by 12 px before the
  fix and keeps every action reachable after it.
