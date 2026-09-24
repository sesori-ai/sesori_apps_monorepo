# Step 22 — Session subtitle, composer tools and code blocks

Landed in three PRs: 22.a (#1657), 22.c (#1658) and 22.b (#1660).

## What changed

- 22.a: `SessionInteractionState.available` and `blocked` carry the harness
  `displayName`, and the session page subtitle read "Claude Code · Haiku".
  `SessionDetailLoaded.agent` is gone. The subtitle itself was later removed
  at the user's request (the composer's model pill already names the model);
  `displayName` stays for step 30's "Sending to <harness>…".
- 22.c: `ComposerOptionsAccordion` takes `isTyping` and folds the composer
  tools away as typing starts.
- 22.b: fenced code blocks, tool output and the Shell panel share one raised
  inset (`bgSurface4`, `PregoRadius.xs`, no border), visible on the grey page
  in both themes. A code block over 12 lines shows its first 12 under a fade
  and an "Open all N lines" button, which opens the whole block, selectable,
  through `showPregoModal` (a new `PregoModalWidth.code` dialog on desktop, a
  sheet on the phone). The Shell toggle's hover is a small rounded rectangle.

## Verification

- 22.a: module_core session interaction calculator and cubit tests,
  module_app_ui and app session detail body tests pass.
- 22.c: the composer options accordion test covers folding on typing.
- 22.b: `client/module_app_ui` `test/features/session_detail` and
  `test/widgets` (new `code_block_test.dart`) and `client/module_prego` tests
  pass.
- `dart analyze --fatal-infos` clean in every touched package.
