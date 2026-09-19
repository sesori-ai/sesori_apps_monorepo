# Step 11 — Control-content audit and regression reconciliation

Delivery 21/22; branch `desktop-ux/regression-docs`; target at most 600 all-path changed lines.
Base: #1549 squash `201cdcc51205edd88d615618894c2dafd8e75df6`, tree
`eb9bccd00af1d2548e1999b7a550089f7e1dc6e7`. The predecessor's accepted head and merge record remain in `step-10.md`.

## Delivered corrections

- A title-only `PregoNavTitle` returns its single-line Text directly, letting the toolbar constrain it instead of
  introducing an unconstrained-height Column child. Single-line leading is 1.2 so the natural 45pt title at 250%
  fits the 54pt bar rather than clipping. Requested scaling/ellipsis and nonempty subtitle leading/layout remain
  unchanged. The review follow-up below corrects the initial size-only check as well as step 7.c's overflow.
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

All pre-review captures below were opened and inspected; later General/Bridge images supersede earlier versions.
The typography follow-up's final minimum-window captures are recorded below, separately from these checkpoints:

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
The pre-review render batches passed: General two images plus one reused pure configuration case; Bridge regrouping
three images plus that same configuration case; sidebar four; popover four; access two. These are separate render
probes, not extra product-test coverage. An optional contact-sheet helper lacked Pillow; originals were inspected.

## Remaining qualification

No real GUI/helper launch, bridge operation, production DI/bootstrap, app-smoke test, secure-storage prompt,
registration, production preference/auth/database write, OS screen capture or relaunch occurred.
The recorded locked-GUI, profile-AOT and device-tool limitations remain; no new native failure is inferred.
Native keyboard/accessibility/compositing/energy, relaunch persistence, FDA grant/deny/focus and helper inheritance,
login items, packaged startup/termination, live session actions and mobile backup/restore remain unqualified.
Step 12 must record these boundaries honestly; this audit neither retires the plan nor waives its final matrix.

## Source and size receipt

Initial source commit: `5b2dbba7425f47b8af3ac30447196ccb5a45187b`, tree
`d2f3e155210b3428342fc20587a8b2ad1adce144`. Its complete range is **408 changed lines**,
336 additions/72 deletions across 18 paths: 60 production, 76 tests, 272 documentation, zero generated.
Reproduce this immutable measurement, which excludes this later receipt:

```bash
git diff --numstat 201cdcc51205edd88d615618894c2dafd8e75df6..5b2dbba7425f47b8af3ac30447196ccb5a45187b --
```

Precommit validation checked whitespace, local Markdown targets and both 120-character/120-byte added-line limits.
It also confirmed the executable diff still matches the final General checkpoint above. Initial wrapping failures
remain in `/tmp/rose-elephant-controls-audit-validation.json`; the corrected result is
`/tmp/rose-elephant-controls-audit-precommit-validation.json`. No unchanged suite was rerun for documentation.

## PR #1550 review follow-up

Initial publication `180288e82e63b25d93ca52045e8b905348a2243c`, tree
`0054f311182c37ed267ae7287d370719dfabe4b3`, measured 424 all-path lines, 352 additions/72 deletions, 18 paths:
60 production, 76 tests, 288 docs, zero generated. CI passed 13/13; Codex completed without findings.
Cubic's two findings were assessed from `/tmp/rose-elephant-1550-review1-feedback.json`:

- Modal-size claim declined: `SizedBox(860, 640)` requests dimensions within the finite constraints passed by
  Center/Padding; at 560 × 480, the material is constrained to 536 × 456. Existing tests assert its actual on-screen
  bounds and hit-testable Close in every tab at all three scales. No responsive-layout workaround is needed.
- Title clipping accepted: the original direct Text fixed RenderFlex overflow but its natural line still measured
  56 pixels in a 54-pixel box. A new independent `TextPainter` height assertion reproduced this for null and empty
  subtitles before the fix. Single-line leading changes from 1.25 to 1.2; nonempty subtitle layout stays at 1.25.
  The test now checks natural line height, requested scaling and the rendered box instead of box size alone.

Execution was on an uncommitted tree based on `180288e`, not the later follow-up commit. Checkpoint
`/tmp/rose-elephant-1550-review1-checkpoint.patch`, SHA-256
`ff8331b0410f8667116a512f480578f8cb65f931fa0c48ec3040028b5651d796`.

```bash
cd "$ROOT"
"$SDK/dart" format client/module_prego/lib/components/navigation/prego_nav_title.dart \
  client/module_prego/test/components/prego_nav_title_test.dart
(cd client/module_prego && "$SDK/flutter" test --no-pub --reporter=json \
  test/components/prego_nav_title_test.dart)
(cd client/module_prego && "$SDK/dart" analyze --fatal-infos)
(cd client/desktop && "$SDK/flutter" test --no-pub --reporter=json \
  test/features/settings/desktop_settings_screens_test.dart --plain-name 'minimum window')
(cd client/desktop && "$SDK/flutter" test --no-pub --reporter=json \
  .dart_tool/control_audit_review1_preview_test.dart --plain-name 'minimum-250')
```

Three Prego cases passed `2026-09-19T07:20:20.714Z`–`07:20:22.990Z`; Prego analysis ended `07:20:37.855Z`, exit 0.
Six minimum-window platform/scale variants passed `07:20:37.855Z`–`07:20:44.401Z`. These nine overlap the original 28.
Two packaged-font 250% Bridge/Account renders passed through `07:20:47.988Z`; both PNGs were inspected under
`/tmp/rose-elephant-1550-title-previews.jkfot2h5/`. These remain synthetic, not native qualification.
Format processed two files with zero changes. Exact receipts: `/tmp/rose-elephant-1550-review1-verification.json`;
Logs share that prefix with `-prego-tests`, `-prego-analyze`, `-minimum-settings` and `-title-preview`,
plus `.log`/`.stderr`.
The expected failing regression (two failures, one pass) remains in `...-review1-repro.json`, `.log` and `.patch`,
where `...` is `/tmp/rose-elephant-1550`. No failure receipt or published history was overwritten.

## Merge record

PR #1550 merged `2026-09-19T07:52:05Z`. Accepted head `c92ced39a99230963ee13f671586ef54e78d131a` differs from
squash `776c4a9ee0c793b99a32c459b3490422039aee32`; both have tree `289e0b747e6c0bf4a1f01995940d2cc92dd1b67b`.
Current-head readiness checks settled 13/13 (11 success, two skipped), Cubic approved and Codex completed without
findings. All three threads were resolved: modal bounds declined with evidence, natural title height corrected,
then rail-scrolling wording clarified. The terminal monitor still reported 13/14 running, not a terminal pass.

Final immutable range: **491 changed lines**, 418 additions/73 deletions, 18 paths:
68 production, 90 tests, 333 docs, zero generated.

```bash
git diff --numstat 201cdcc51205edd88d615618894c2dafd8e75df6..c92ced39a99230963ee13f671586ef54e78d131a --
```

`10b910e4efe7aa52337589ba76d1f900cebfac5d` published the verified typography correction;
`c92ced3` changed only the scrolling sentence in `desktop-cockpit-shell.md`. Executable files remained identical,
so documentation validation ran without rerunning unchanged suites/renders. Receipts:
`/tmp/rose-elephant-1550-review1-wording-validation.json`, `...-c92ced3-ready-assessment.json`, `...-merged.json`,
where `...` is `/tmp/rose-elephant-1550`. This merge does not establish the native/live coverage
in [step 12](step-12.md).
