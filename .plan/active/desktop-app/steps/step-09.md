# Step 9 — Autostart + hidden boot

Date: 2026-08-30.

## Delivered

- Added the pure-Dart Layer-0 `LaunchAtLogin` capability and a desktop shell
  adapter. macOS writes/removes a single per-user LaunchAgent plist, Linux
  writes/removes a single XDG autostart desktop entry (honoring
  `XDG_CONFIG_HOME`), and Windows owns one
  `HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run` value. Each
  registration launches the current desktop executable with `--hidden`; repeat
  enable operations are idempotent and disable removes stale registrations.
  macOS disable removes the plist without booting out the currently running
  app, so disabling autostart cannot terminate the app before coordinated
  bridge shutdown completes.
  The adapter owns these small OS registrations directly because the available
  `launch_at_startup` macOS backend does not forward launch arguments and would
  add an extra Swift package integration for this dev-build step.
- Added the tray/window launch-at-login control. The cubit reads the OS-backed
  state, exposes an On/Off status and command in the tray and window, serializes
  registration changes with the other lifecycle actions, and leaves the state
  retryable after a failed operation.
- Added exact `--hidden` argument parsing. Hidden startup initializes the native
  window without showing it, keeps it tray-only when the tray is available, and
  shows it when tray initialization is unavailable or fails. Normal launches
  remain visible.
- Extended the native window capability with an explicit initial visibility
  parameter and regenerated desktop Injectable output.

No database or relay/control-wire impact. Login registration is per-user OS
state and is separate from the desktop-owned bridge desired-state file.

## Architecture implementation review

The implementation review approved the Step 9 working tree with no findings.
It confirmed Layer-0 `LaunchAtLogin` ownership, independent desktop platform
registration, `WindowHost`/`BridgeControlCubit` lifecycle direction, hidden-boot
fallback ownership, and DI boundaries.

## Verification

- `client/desktop`: `flutter analyze --fatal-infos` clean; full Flutter suite
  passed (45 tests).
- `client/module_desktop_core`: `dart analyze --fatal-infos` clean; full pure
  Dart suite passed (157 tests).
- Adapter tests cover macOS plist content/hidden argument and safe removal,
  Linux XDG content/idempotence and `XDG_CONFIG_HOME`, stale registrations,
  and Windows registry command/error behavior; launch-argument parsing and
  hidden-window fallback are covered separately.
- Clean macOS application build passed.
- Manual reboot/login Gate B coverage remains pending; the user-run gate will
  verify hidden tray startup, disable persistence, and no-tray visible fallback.
