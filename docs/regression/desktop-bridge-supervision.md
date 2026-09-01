# Desktop Bridge Supervision

## Capability

The desktop window and tray jointly supervise the local bridge: present live
status, control desired On/Off state, expose diagnostics, coordinate sign-out,
and keep native close/quit behavior safe.

## Required Behavior

- The desktop boots a visible Prego-themed window and eagerly initializes tray
  supervision even while signed out. Exactly one process owns the desktop
  instance lock and activation listener. The macOS tray uses the transparent
  monochrome Sesori mark as a template image so the system renders it legibly
  in both light and dark menu bars.
- A second launch signals the owner, exits without another tray/helper, and
  restores/focuses the owner's window. A killed owner releases the OS lock;
  stale activation metadata cannot block the next launch.
- Desired bridge On/Off state persists under desktop-owned application data.
  Startup restores last-On through the process service after the dispatcher is
  ready; signed-out restore reaches login-required without spawning a helper.
  Launch at login is an idempotent per-user registration that starts the app
  with `--hidden`; disabling it removes the registration rather than merely
  flipping an in-app flag. Development builds resolve the repository helper
  from the desktop executable path when a login service supplies `/` as the
  working directory; packaged-layout resolution remains a distribution-plan
  concern. The supervised helper receives a login-shell-derived executable
  search path, so harnesses installed outside launchd's default PATH remain
  discoverable after autostart. Only PATH is derived for the helper; shell
  variables are not imported or persisted. If the login-shell probe fails, the
  desktop emits no PATH override and preserves the inherited environment
  unchanged while retaining a bounded diagnostic warning.
- A `--hidden` launch stays tray-only when the tray is proven available. The
  macOS runner suppresses the native first ordering and the Flutter window
  adapter applies the hidden state as a fallback. If the tray is unavailable
  or fails to initialize, the window is shown so the app remains reachable.
- On a proven tray host, native close hides the window immediately, including
  during bridge lifecycle work, removes the macOS app from the Dock while it is
  hidden, and Open restores/focuses it and returns it to the Dock. Without a
  usable tray host, close defers safe Quit until active lifecycle work settles
  instead of dropping the request or leaving an invisible process.
- Primary and secondary (right/trackpad) clicks on the tray icon open the same
  typed context menu. The macOS Dock icon is a desktop-owned copy of the
  Sesori Icon Composer asset used by the main client, not the Flutter starter
  icon; keeping the copy local preserves independent shell builds.
- Quit expected-stops the supervised helper before disposing native surfaces or
  terminating the desktop process. A failed stop leaves the app alive.
- Window and tray On/Off actions share one serialized owner. Intent is durable
  before lifecycle work begins: a persistence failure leaves the helper and
  session unchanged, while a failed start or stop leaves the next action
  targeted at retrying that failed operation.
- The signed-in window shows account, process/control status, registration,
  relay state, plugin health, active-session count, takeover/login-required
  states, and recent output after crash give-up.
- Open Logs prepares the owner-only active log through Layer-1 storage, then
  resolves it through the desktop log repository and delegates it to the system
  default application, including before the helper emits its first line.
- Device-local sign-out locks every bridge lifecycle surface, asks the live
  helper to `unregister_and_exit`, waits for that command's expected exit
  without sending a competing shutdown, and independently deletes the GUI's
  persisted account-bound bridge registration (404 is already success). The
  delete attempt has a bounded timeout and is best-effort offline; a confirmed
  deletion clears the local record, while an unconfirmed deletion keeps it for
  a later retry. A different account never submits or clears the record. Local
  tokens are cleared only after a successful helper stop; if stop fails,
  authentication remains intact. Other devices are never logged out.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated desktop startup proves eager tray initialization, Prego theme assembly, signed-out login rendering, and signed-in supervision rendering. No plugin. |
| L2 Routine | Automated cubit/adapter coverage for Open/focus, close-to-hide, no-tray close-to-Quit, ordered Quit, failed-stop/persistence refusal to exit, On/Off recovery, diagnostics launch, durable-Off-before-local-logout, helper unregister command, no-competing-shutdown expected stop, account-bound persisted bridge-id restart, owner-mismatch protection, 404-idempotent deletion, and offline deletion failure; cross-process lock/activation, killed-owner recovery, persisted desired state, and auth-gated startup restoration. No plugin. |
| L3 Release | Client end to end on macOS with a dev-built helper and representative live plugin: browser login/relaunch restore, healthy handshake, phone session round-trip, helper crash/backoff, exit-86 restart, login-required behavior, Off/close/Quit orphan checks, and standalone CLI coexistence. |
| L4 Extended | Client end to end on Windows and Linux, including a Linux StatusNotifier host and a no-host windowed fallback; vary helper startup/stop failures, relay takeover, crash give-up output, and default log-file application availability. |
| L5 Full | Packaged desktop artifacts on every release target, including native tray/window appearance, signing/install behavior, and long-running supervision through repeated sleep, reconnect, restart, hide/show, and relaunch cycles. |

## Exploration Guidance

Vary signed-in versus signed-out startup, tray present versus absent, bridge On
versus Off, second launch while visible/hidden, owner crash with stale metadata,
and whether close occurs during a lifecycle transition. Exercise
both clean and failed helper teardown before Quit or sign-out. Kill the helper
at different handshake phases and inspect the status and bounded recent output.

## Failure Signals

- No tray or command subscriptions until a signed-in screen reads the cubit.
- A second process creates another tray/helper, fails to focus the owner, or a
  killed owner leaves a lock that bricks future launches.
- Desired Off restores On, last-On never restores, startup bypasses auth gating,
  or bridge restore begins before the control dispatcher owns its event stream.
- Repeated launch-at-login enables create duplicate registrations, disabling
  leaves a stale login item, a login-launched development build cannot find its
  repository helper or its PATH-installed harnesses, `--hidden` startup hides
  the app without a usable tray,
  the macOS window flashes or remains visible during hidden startup, or a normal
  manual launch unexpectedly starts hidden.
- Close hides the only surface when no tray host exists, ignores a close during
  lifecycle work, Open shows without focusing, native close bypasses teardown,
  or the macOS tray icon has an opaque background/wrong light-dark treatment,
  the Dock still shows a hidden window, or secondary tray clicks do nothing.
- Quit or sign-out clears auth or exits while a supervised helper remains alive,
  or an On command can race between logout's helper stop and token clearing.
- Sign-out fails to send the helper unregister command, pre-empts it with a
  competing shutdown, skips the persisted-id fallback, loses the account-bound
  record across a GUI relaunch, submits one account's id with another
  account's token, blocks indefinitely on an offline auth server, or clears
  the record/auth state before deletion/teardown is ordered.
- A failed On/Off action presents or executes the opposite operation instead of
  retrying the failed action.
- Window and tray disagree on desired state, status, or active-session count.
- Takeover, login-required, or crash give-up is rendered as healthy/connected,
  recent crash output is absent, Open Logs targets a nonexistent/bypassed file,
  or a supervised Full Disk Access warning tells the user to authorize only
  Terminal instead of the process running the bridge.
- The desktop theme lacks Prego colors, typography, or design-system extension.

## Known Limitations

- A registration deletion that times out or otherwise fails is retained for a
  later explicitly-triggered logout retry; there is no background retry job.
- The helper's `unregister_and_exit` command has no acknowledgement. The GUI
  therefore always performs its own idempotent deletion attempt after bounded
  process teardown.
- Real Linux StatusNotifier and Windows tray/window appearance require host
  smoke coverage; automated tests prove translation and fallback behavior.
- Non-provisioned/ad-hoc macOS development builds may show one Keychain
  authorization prompt per existing credential item; this is macOS item ACL
  behavior and is separate from the entitlement workaround. Full Disk Access is
  likewise attributed to the process that accesses the protected folder; a
  Terminal grant is not transferred to a separately launched desktop/helper
  process. Stable signing for distributed builds belongs to the later
  desktop-distribution plan.
- Login registration is owned by the current desktop executable path. A
  development build moved or rebuilt at a different path must be re-enabled;
  the dev resolver can locate the repository helper from an executable inside
  the checkout even when launchd changes the working directory. Packaged-path
  migration belongs to the later desktop-distribution plan.

## Sources

- `client/module_desktop_core/lib/src/cubits/bridge_control/`
- `client/module_desktop_core/lib/src/foundation/platform/bridge_process_environment.dart`
- `client/desktop/lib/core/platform/io_bridge_process_environment.dart`
- `client/module_desktop_core/lib/src/orchestration/desktop_logout_orchestrator.dart`
- `client/module_desktop_core/lib/src/api/bridge_id_storage.dart`
- `client/module_core/lib/src/api/bridge_api.dart`
- `client/module_core/lib/src/repositories/bridge_repository.dart`
- `client/desktop/lib/core/platform/flutter_window_host.dart`
- `client/desktop/lib/features/home/desktop_home.dart`
- `.plan/active/desktop-app/PLAN.md`
