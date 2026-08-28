# Step 7 — Window + Prego shell + supervision controls

Date: 2026-08-28.

## Delivered

- Added the pure-Dart Layer-0 `WindowHost` and a dumb `window_manager`
  adapter. Native initialization runs before `runApp`, installs close
  interception, sizes/centers the visible window, and emits typed close events.
- Extended `BridgeControlCubit` as the shared tray/window owner: tray Open
  restores and focuses the window; close hides only with a proven tray host;
  no-tray close uses the same expected-stop-before-exit path as tray Quit.
- Exposed one reactive window state for process, desired/toggle action,
  control/registration/relay/plugin/session status, and crash give-up output.
  Failed starts and stops remain directly retryable from both surfaces.
- Added a Layer-2 log-resource repository and Open Logs action through the
  existing platform `UrlLauncher`; the shell never reads Layer-1 storage.
- Added `DesktopLogoutOrchestrator` as the named Layer-4 cross-service owner.
  It expected-stops the helper before local token clearing and refuses logout
  when stop fails. `AuthGateCubit` delegates while retaining its temporary
  in-flight-restore fence until step 10 hardens auth generations.
- Added Prego-owned light/dark `ThemeData` assembly and adopted it in desktop.
- Replaced the signed-in placeholder with account, On/Off, detailed status,
  active sessions, recent crash output, Open Logs, and coordinated sign-out.
- Removed the obsolete placeholder and added the desktop-supervision regression
  document. No analytics event was added: desktop analytics remains a no-op
  surface with no approved tray/window reporting decision.

No database or transport impact. User-visible behavior is the first functional
desktop supervision window and safe tray-first close/open behavior.

## Architecture implementation review

Approved 2026-08-28 with B-Client applied and no findings. The review confirmed
WindowHost/platform-interface direction, pre-render native initialization,
BridgeControlCubit cohesion, Layer-2 log mapping, Layer-4 logout ownership,
Prego theme ownership, shell-only rendering, and dumb adapter boundaries.

## Verification

- `client/module_desktop_core`: analysis clean; all 125 tests passed.
- `client/module_prego`: analysis clean; all 247 tests passed.
- `client/desktop`: analysis clean; all 32 tests passed.
- `client/app`: downstream analysis clean after the shared Prego addition.
- Desktop-core and desktop Injectable output regenerated; Flutter platform
  registration and workspace lock regenerated with Dart 3.13.2.
- macOS debug application build passed with `window_manager` integration.
- Dart LSP: 0 diagnostics across 26 affected non-generated Dart files.
- `git diff --check` — clean.
- Change size: 1,443 text changed lines, under the 1,500-line soft cap.

## Remaining manual gate

MT gate A remains user-run and pending after this PR: real macOS browser login,
session restore, phone round-trip, token authority, crash/backoff, exit-86
restart, login-required, Off/Quit orphan checks, and standalone CLI coexistence.
