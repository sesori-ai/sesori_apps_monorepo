# Step 10 — Contextual desktop keyboard shortcuts

Delivery 20/22; branch `desktop-ux/shortcuts-title-bar`.
Base: #1545 squash `354e67ea5c8d9c513326c1c82c48b7597060acae`, tree
`2378cc6638d5a630f43140ead186df28b60e387c`. Target: at most 600 all-path changed lines.

## Delivered behavior

- Cmd+N on macOS, Ctrl+N on Windows/Linux: open the existing typed New Session route for the current route's project.
  Preserve its nullable display name. With no project context, do nothing; home does not advertise an unusable shortcut.
- Cmd/Ctrl+B: call the existing sidebar toggle. Automatic narrow-window collapse remains a no-op, matching the disabled
  control, and widening restores the unchanged user choice. Ordinary toggles retain existing persistence.
- Cmd/Ctrl+, continues to open Settings through its existing router callback.
  All three bindings ignore held-key repeats.
- The cockpit admits keyboard input without requiring a child control to focus first. Focused editors remain focused
  during layout changes; root popups retain their own focus. New Session returns to the retained opener with one Back.
- Platform-specific hints identify the available shortcuts. Only the selected project's New session button advertises N;
  other project buttons retain their ordinary tooltips. Settings keeps its existing concise accessible icon name.

The router and cockpit remain presentation adapters over existing route callbacks and Cubit intents. There are no new
production classes/files, mutable fields, inventories, subscriptions, timers, persistence schemas, DI registrations or
backend/wire contracts. Architecture review is not invoked for these localized presentation changes. No obsolete
business artifacts were found. No new analytics event is justified: these are alternate inputs to existing outcomes.

## Optional native chrome omitted

D12 permits omitting hidden macOS title-bar integration. This delivery leaves native chrome untouched on every platform:
protected-session constraints prevent safe drag, traffic-light and relaunch/restore qualification.
No native flag, dormant switch, drag region or toolkit failure is invented. This is a scope choice,
not a claim that native qualification passed.
The final matrix still requires native keyboard, window, live bridge and packaged checks for the delivered behavior.

## Focused verification

All runs below used the same **uncommitted** executable tree based on `354e67ea...`, not a later-created source commit.
The checkpoint patch is `/tmp/rose-elephant-shortcuts-test-checkpoint.patch`, SHA-256
`b668ff06b811b9e063c0f7c000e5e3c8250d145c42b6cadef9ab4ba8ff6cc654`.
`/tmp/rose-elephant-shortcuts-verification.json` records exact cwd, argv, timestamps, statuses and executed cases.

```bash
ROOT=/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant
SDK=/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin
cd "$ROOT"
(cd client/module_app_ui && "$SDK/flutter" gen-l10n)
"$SDK/dart" format \
  client/desktop/lib/core/routing/desktop_router.dart \
  client/desktop/lib/core/widgets/desktop_cockpit_shell.dart \
  client/desktop/lib/core/widgets/desktop_sidebar.dart \
  client/desktop/test/core/routing/desktop_router_test.dart \
  client/desktop/test/core/widgets/desktop_cockpit_shell_test.dart
(cd client/desktop && "$SDK/flutter" test --no-pub --reporter=json \
  test/core/routing/desktop_router_test.dart \
  test/core/widgets/desktop_cockpit_shell_test.dart \
  test/features/settings/desktop_settings_screens_test.dart)
(cd client/desktop && "$SDK/dart" analyze --fatal-infos)
(cd client/module_app_ui && "$SDK/dart" analyze --fatal-infos)
```

- Localization generation and formatting exited 0; format processed five files and changed two tests.
  Generation receipts: `/tmp/rose-elephant-shortcuts-generation.json` and associated l10n/format logs.
- Tests ran `2026-09-19T05:33:14.966Z`–`05:33:25.300Z`, exit 0: **85 cases** from non-hidden `testDone` events.
  Router: 18; cockpit: 44; Settings: 23. Counts include loops and platform variants, not only source declarations.
- New routing cases cover project/no-project context, named/unnamed projects, wrong modifiers, focused draft retention,
  root-popup precedence, held-key repeats and single-Back return across macOS/Windows/Linux variants.
- New layout cases cover initially focusless content, text-field focus, repeats, correct modifiers,
  two persisted toggles, narrow-window no-op/widening restoration and hints across all three desktop variants.
  A separate case checks that an unselected project's tooltip does not claim N.
  Existing Settings entry, modal and retention cases also passed.
- Desktop analysis exited 0 at `05:33:42.866Z`; shared-UI analysis exited 0 at `05:34:01.507Z`.
  These commands are not rerun for later documentation-only changes.
- Logs: `/tmp/rose-elephant-shortcuts-desktop-tests.log`, `-desktop-analyze.log` and `-app-ui-analyze.log`,
  each under the same `/tmp/rose-elephant-shortcuts` prefix, with corresponding `.stderr` files.

Publication validation covers whitespace, added Markdown's 120-character/120-byte limit, plan links and all-path churn.
The executable diff matches the recorded checkpoint; initial Markdown validation identified six lines for wrapping.
Final validation is recorded in `/tmp/rose-elephant-shortcuts-final-validation.json`. Publication measurement and
source/tree identity are in the PR body and `/tmp/rose-elephant-shortcuts-publication.json` once the commit exists.

No production DI/bootstrap, desktop app-smoke, real app/helper launch, bridge operation, secure-storage prompt,
native registration, real preference/auth/database mutation, screen capture or relaunch occurred. Synthetic tests and
platform variants do not establish native or live qualification. Steps 11 and 12 retain that final handoff.
