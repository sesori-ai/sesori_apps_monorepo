# Desktop Bridge Supervision

## Capability

The desktop window and tray jointly supervise the local bridge: present live
status, control desired On/Off state, expose diagnostics, coordinate sign-out,
and keep native close/quit behavior safe.

## Required Behavior

- The desktop boots a visible Prego-themed window and eagerly initializes tray
  supervision even while signed out.
- On a proven tray host, native close hides the window and Open restores and
  focuses it. Without a usable tray host, close performs safe Quit instead of
  leaving an invisible process.
- Quit expected-stops the supervised helper before disposing native surfaces or
  terminating the desktop process. A failed stop leaves the app alive.
- Window and tray On/Off actions share one serialized owner. A failed start or
  stop leaves the next action targeted at retrying that failed operation while
  preserving authoritative desired state.
- The signed-in window shows account, process/control status, registration,
  relay state, plugin health, active-session count, takeover/login-required
  states, and recent output after crash give-up.
- Open Logs resolves the rotating log path through the desktop log repository
  and delegates it to the system default application.
- Device-local sign-out expected-stops the helper before clearing local tokens.
  If helper stop fails, authentication remains intact; other devices are never
  logged out.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated desktop startup proves eager tray initialization, Prego theme assembly, signed-out login rendering, and signed-in supervision rendering. No plugin. |
| L2 Routine | Automated cubit/adapter coverage for Open/focus, close-to-hide, no-tray close-to-Quit, ordered Quit, failed-stop refusal to exit, On/Off recovery, diagnostics launch, and helper-stop-before-local-logout. No plugin. |
| L3 Release | Client end to end on macOS with a dev-built helper and representative live plugin: browser login/relaunch restore, healthy handshake, phone session round-trip, helper crash/backoff, exit-86 restart, login-required behavior, Off/close/Quit orphan checks, and standalone CLI coexistence. |
| L4 Extended | Client end to end on Windows and Linux, including a Linux StatusNotifier host and a no-host windowed fallback; vary helper startup/stop failures, relay takeover, crash give-up output, and default log-file application availability. |
| L5 Full | Packaged desktop artifacts on every release target, including native tray/window appearance, signing/install behavior, and long-running supervision through repeated sleep, reconnect, restart, hide/show, and relaunch cycles. |

## Exploration Guidance

Vary signed-in versus signed-out startup, tray present versus absent, bridge On
versus Off, and whether close occurs during a lifecycle transition. Exercise
both clean and failed helper teardown before Quit or sign-out. Kill the helper
at different handshake phases and inspect the status and bounded recent output.

## Failure Signals

- No tray or command subscriptions until a signed-in screen reads the cubit.
- Close hides the only surface when no tray host exists, Open shows without
  focusing, or a native close bypasses helper teardown.
- Quit or sign-out clears auth or exits while a supervised helper remains alive.
- A failed On/Off action presents or executes the opposite operation instead of
  retrying the failed action.
- Window and tray disagree on desired state, status, or active-session count.
- Takeover, login-required, or crash give-up is rendered as healthy/connected,
  recent crash output is absent, or Open Logs bypasses the owned rotating path.
- The desktop theme lacks Prego colors, typography, or design-system extension.

## Known Limitations

- The current development shell starts visible and is not yet single-instance;
  hidden login startup and activation ownership are later plan slices.
- Device-local sign-out stops the helper but does not yet perform persisted
  bridge-registration deletion; coordinated unregister/offline fallback remains
  a later plan slice.
- Real Linux StatusNotifier and Windows tray/window appearance require host
  smoke coverage; automated tests prove translation and fallback behavior.

## Sources

- `client/module_desktop_core/lib/src/cubits/bridge_control/`
- `client/module_desktop_core/lib/src/orchestration/desktop_logout_orchestrator.dart`
- `client/desktop/lib/core/platform/flutter_window_host.dart`
- `client/desktop/lib/features/home/desktop_home.dart`
- `.plan/active/desktop-app/PLAN.md`
