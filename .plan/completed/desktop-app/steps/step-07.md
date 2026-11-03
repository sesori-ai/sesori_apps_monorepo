# Step 7 — Window + Prego shell + supervision controls

Date: 2026-08-28.

## Delivered

- Added the pure-Dart Layer-0 `WindowHost` and a dumb `window_manager`
  adapter. Native initialization runs before `runApp`, installs close
  interception, sizes/centers the visible window, and emits typed close events.
- Extended `BridgeControlCubit` as the shared tray/window owner: tray Open
  restores and focuses the window; close hides immediately with a proven tray,
  while no-tray close defers safe Quit until lifecycle work settles.
- Exposed one reactive window state for process, desired/toggle action,
  control/registration/relay/plugin/session status, and crash give-up output.
  Failed starts and stops remain directly retryable from both surfaces.
- Added a Layer-2 log-resource repository and Open Logs action through the
  existing platform `UrlLauncher`; Layer-1 prepares the empty owner-only file
  even before first helper output, and the shell never reads storage directly.
- Added `DesktopLogoutOrchestrator` as the named Layer-4 cross-service owner.
  It marks a Layer-2 logout tracker so all lifecycle surfaces stay locked from
  expected stop through local token clearing, shares concurrent logout calls,
  and refuses logout when stop fails. `AuthGateCubit` delegates while
  `module_auth` owns the generation fence for every in-flight auth result.
- Added Prego-owned light/dark `ThemeData` assembly and adopted it in desktop.
- Replaced the signed-in placeholder with account, On/Off, detailed status,
  active sessions, recent crash output, Open Logs, and coordinated sign-out.
- Removed the obsolete placeholder and added the desktop-supervision regression
  document. No analytics event was added: desktop analytics remains a no-op
  surface with no approved tray/window reporting decision.

No database or transport impact. User-visible behavior is the first functional
desktop supervision window and safe tray-first close/open behavior.

## Architecture implementation review

Approved twice on 2026-08-28 with B-Client applied and no findings. The final
review confirmed the review-driven Layer-2 logout tracker is the correct seam
between independent Layer-4 owners, while close deferral stays in the cubit and
empty-log preparation stays Layer 1. The initial review also confirmed window,
theme, shell-rendering, DI, and dumb-adapter boundaries.

## Verification

- `client/module_desktop_core`: analysis clean; all 130 tests passed.
- `client/module_prego`: analysis clean; all 247 tests passed.
- `client/desktop`: analysis clean; all 32 tests passed.
- `client/app`: downstream analysis clean after the shared Prego addition.
- Desktop-core and desktop Injectable output regenerated; Flutter platform
  registration and workspace lock regenerated with Dart 3.13.2.
- macOS debug application build passed with `window_manager` integration.
- Dart LSP: 0 diagnostics across 26 initial and 9 feedback-affected Dart files.
- `git diff --check` — clean.
- Change size: about 1.7k text changed lines; the review-driven lifecycle fixes
  account for the documented soft-cap overage.

## Remaining manual gate

MT gate A remains user-run and pending after this PR: real macOS browser login,
session restore, phone round-trip, token authority, crash/backoff, exit-86
restart, login-required, Off/Quit orphan checks, and standalone CLI coexistence.
