# Step 11 — Control-content audit and regression reconciliation

Delivery 21/22; branch `desktop-ux/regression-docs`; target at most 600 all-path changed lines.
Base: #1549 squash `201cdcc51205edd88d615618894c2dafd8e75df6`, tree
`eb9bccd00af1d2548e1999b7a550089f7e1dc6e7`. The predecessor's accepted head and merge record remain in `step-10.md`.

## Delivered corrections

- A title-only `PregoNavTitle` returns its single-line Text directly, letting the toolbar constrain it instead of
  introducing an unconstrained-height Column child. Requested text scaling and ellipsis remain unchanged;
  a nonempty subtitle retains its two-line layout. This corrects step 7.c's reproduced 250% toolbar overflow.
- Existing desktop app-update guidance moves from Bridge to General, after launch-at-login. Compiled destination
  selection, external opening, source/package-manager guidance and distribution behavior are unchanged.
- General stops offering Voice/Text selection: `DesktopComposerPresentationScope` explicitly declares voice unsupported
  and fixes text-first input, so the preference was ineffective here. Mobile preference UI, stored values and
  bootstrap owners remain untouched. This refines the original General/input design against actual capability.
- Minimum-window tests visit every Settings tab at 100%, 200% and 250%, retain the requested scaler and opener,
  and require a hit-testable Close control. They load the actual packaged text font for meaningful geometry.

No production class/file, public contract, DI owner, business workflow, lifecycle trigger, persistence or wire shape
is introduced or moved. These are localized presentation changes; architecture reviewers are not invoked.
No new analytics event is justified by regrouping existing controls or removing an ineffective preference.

## Rendered-content audit

The audit inspected production widgets, not only option lists. Typed fake owners supplied state; package-prefixed
Satoshi, icon and Material fonts were loaded. Popover boundaries include the root Navigator so overlays are captured.
The renderer uses a Linux widget-test variant; it does not exercise a Linux desktop or macOS native views.

- Sidebar: New project remains prominent; Activity identifies project context and excludes ordinary duplicates.
  The separated This computer/refresh/Settings footer retains local scope. Narrow labels truncate, compact icons
  remain recognizable, busy feedback and failure notices retain useful rows. Shortcut/hint behavior stays as in step 10.
- Local popover: entity heading and status are distinct. Off offers Start Bridge; stopped crash offers Retry despite
  retained On; contention offers Take Over; displaced running state offers Take Over plus quieter Stop Bridge.
  Logs/configuration are secondary. Quit and OS startup are not misleading local-bridge actions.
- Settings: General owns app appearance/startup/updates/support; Harnesses owns runtime management; Bridge explicitly
  separates potentially remote connected configuration from This computer diagnostics. Notifications owns desktop
  attention; Account owns identity, analytics preference and supervised logout. No mobile navigation menu is copied.
- Large text: title-only toolbars stay bounded without reducing scale. At 560 × 480 and 250%, long rail labels wrap
  heavily and require scrolling; Close remains reachable. This is usable scaling, not a claim of native visual polish.
- First-run file access: rendered copy explains the agent benefit, optional scope and restart consequence. Open System
  Settings is the next action and Not now is quieter; neither claims permission was granted. No native action was run.

Eight regression contracts were reconciled: cockpit, desktop supervision, connectivity, projects/sessions,
account/onboarding, notifications, desktop distribution and voice input. Mobile banners/CLI guidance remain distinct
from desktop pill/supervised recovery. Voice's contradictory desktop preference-navigation requirement now matches
its existing mobile-only capability. Existing feature-index entries suffice; no duplicate document was added.

## Verification and execution checkpoints

All commands below ran from this existing worktree, not from a later-created commit:

```bash
ROOT=/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant
SDK=/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin
cd "$ROOT"
"$SDK/dart" format client/desktop/lib/features/settings/desktop_general_settings_screen.dart \
  client/desktop/test/features/settings/desktop_settings_screens_test.dart
(cd client/desktop && "$SDK/flutter" test --no-pub --reporter=json \
  test/features/settings/desktop_settings_screens_test.dart)
(cd client/desktop && "$SDK/dart" analyze --fatal-infos)
(cd client/module_prego && "$SDK/flutter" test --no-pub --reporter=json \
  test/components/prego_nav_title_test.dart)
(cd client/module_prego && "$SDK/dart" analyze --fatal-infos)
```

Latest relevant receipts: **25 desktop Settings cases** and **three Prego title cases**, both owning analyzers clean.
Counts use non-hidden `testDone` events, including macOS/Windows and null/empty-subtitle variants. They are not native
platform passes. Earlier runs overlap these 28 distinct cases and must not be added to them.

- Prego: `/tmp/rose-elephant-controls-audit-qualified-verification.json`, uncommitted base `201cdcc`.
  Patch `/tmp/rose-elephant-controls-audit-qualified-checkpoint.patch`, SHA-256
  `8188fd0c23b394fdb641c619cc338f5b8411b166eeb5b4944076b946e376d76c`.
  Three cases ran `2026-09-19T06:42:09.528Z`–`06:42:11.951Z`; analysis finished `06:42:26.614Z`, both exit 0.
- Final General correction: `/tmp/rose-elephant-controls-audit-general-verification.json`, same uncommitted base.
  Executable patch `/tmp/rose-elephant-controls-audit-general-checkpoint.patch`, SHA-256
  `8f7d6be6477b9d0fa8e0b57d72162fc7c4a14e88e47e28cca0cac0a201e6b6f8`.
  The 25-case suite ran `2026-09-19T06:53:27.756Z`–`06:53:34.850Z`; analysis finished `06:53:52.456Z`, exit 0.
  Only desktop presentation/tests changed after the Prego checkpoint; its passing evidence remains applicable.
  Final formatting processed the two changed desktop files, zero changes, exit 0.

Logs share each receipt prefix with `-desktop-tests.log`, `-desktop-analyze.log`, `-prego-tests.log` or
`-prego-analyze.log`, plus captured stderr. Checkpoints exclude later documentation edits.

### Failed attempts retained

- `/tmp/rose-elephant-controls-audit-overflow-repro.json`: test-only 250% reproduction,
  exit 1 on both platform variants.
- `...-verification.json`: Prego's three cases passed; the initial desktop suite exited 1, 20 passed/five failed.
  The Close semantics finder was ambiguous; it now selects the actual hit-testable labeled icon button.
- `...-tabs.json`: corrected minimum-window finder, two passed/four failed. Ahem's uniform glyph advances overflowed
  the bridge interval value at larger scales. Packaged-font renders established that this was not a production row
  defect; tests now load Satoshi instead of changing row layout or reducing text scale.
- `...-final-verification.json`: desktop's 25 cases and analysis passed; Prego analysis failed `unnecessary_import`.
  Removing the redundant test import led to the qualified Prego run above. No failure receipt was overwritten.

In those abbreviated names, `...` means `/tmp/rose-elephant-controls-audit`, not an unspecified log location.

## Synthetic render evidence

Ignored fixtures are under `client/desktop/.dart_tool`; commands use the desktop cwd and the same SDK:

```bash
cd "$ROOT/client/desktop"
"$SDK/flutter" test --no-pub --reporter=json .dart_tool/control_audit_general_preview_test.dart
"$SDK/flutter" test --no-pub --reporter=json .dart_tool/control_audit_preview_test.dart
SIDEBAR_PREVIEW_DIR=/tmp/rose-elephant-controls-audit-sidebar.j9pi2ils \
  "$SDK/flutter" test --no-pub --reporter=json .dart_tool/sidebar_controls_preview_test.dart
"$SDK/flutter" test --no-pub --reporter=json .dart_tool/control_audit_popover_preview_test.dart
"$SDK/flutter" test --no-pub --reporter=json .dart_tool/control_audit_access_preview_test.dart
```

All captures below were opened and inspected; later General/Bridge images supersede their earlier versions:

- `/tmp/rose-elephant-controls-audit-general.y9yi13dk/`: final General light/dark after removing the dead picker.
- `/tmp/rose-elephant-controls-audit-settings.nn1d2yu0/`: Bridge ordinary and 250% minimum-window after regrouping.
  Its earlier General capture is superseded by the directory above.
- `/tmp/rose-elephant-controls-audit-previews.0fxwglzf/`: unchanged Harnesses, Notifications and Account views,
  including minimum-window 250% Account. Its General/Bridge captures are superseded.
- `/tmp/rose-elephant-controls-audit-sidebar.j9pi2ils/`: expanded light, narrow dark failure, compact light/dark busy.
- `/tmp/rose-elephant-controls-audit-popovers.endpn9jx/`: Off, crash, contention and displaced-running controls.
- `/tmp/rose-elephant-controls-audit-access.ljsp4tc3/`: ordinary light and constrained dark optional-access cards.
  Earlier step-8 PNG paths were unavailable, so the unchanged fake-only fixture was regenerated for this audit.

Receipts: `...-previews.json`, `...-qualified-verification.json`, `...-general-verification.json` and `...-access.json`.
The latest render batches passed: General two images plus one reused pure configuration case; Bridge regrouping
three images plus that same configuration case; sidebar four; popover four; access two. These are separate render
probes, not extra product-test coverage. An optional contact-sheet helper lacked Pillow; originals were inspected.

## Remaining qualification

No real GUI/helper launch, bridge operation, production DI/bootstrap, app-smoke test, secure-storage prompt,
registration, production preference/auth/database write, OS screen capture or relaunch occurred.
The recorded locked-GUI, profile-AOT and device-tool limitations remain; no new native failure is inferred.
Native keyboard/accessibility/compositing/energy, relaunch persistence, FDA grant/deny/focus and helper inheritance,
login items, packaged startup/termination, live session actions and mobile backup/restore remain unqualified.
Step 12 must record these boundaries honestly; this audit neither retires the plan nor waives its final matrix.
