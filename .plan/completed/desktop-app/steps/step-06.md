# Step 6 — Tray + bridge control cubit

Date: 2026-08-28.

## Delivered

- Added pure-Dart Layer-0 `SystemTray` models/capability: typed informational,
  separator, and command entries; typed On/Off and Quit commands; and explicit
  initializing/available/unavailable states.
- Added the narrow `DesktopApplicationTerminator` platform seam so Layer-4
  business logic can own Quit ordering without placing lifecycle sequencing in
  the Flutter shell.
- Added `BridgeControlCubit`, constructed by the shell rather than DI. It
  consumes `BridgeProcessService` and `BridgeStatusTracker`, renders bridge
  status plus active-session count, switches the On/Off label from desired
  state, serializes tray commands, and cancels all subscriptions on close.
- Quit now expected-stops the supervised helper first. Process termination and
  tray disposal occur only after stop succeeds; failure is logged and leaves
  the desktop alive with controls restored.
- Added the dumb `tray_manager` adapter, bundled PNG/ICO assets, generated
  platform registration, and an `io.exit` terminator adapter. The tray adapter
  only renders the typed model and translates plugin keys back to commands.
- Linux availability requires positive session-bus ownership of
  `org.kde.StatusNotifierWatcher`; missing host or initialization failure leaves
  the existing window visible. Added the AppIndicator build dependency to CI.
- Wired the cubit above the desktop app. `WindowHost`, Open, and hide/show
  behavior remain intentionally deferred to step 7.
- Updated bridge-connectivity regression behavior and failures. No analytics
  event was added: desktop analytics remains an approved no-op surface and
  there is no event/reporting decision for tray interactions yet.

No database impact. User-visible behavior is the development desktop tray and
its safe windowed fallback.

## Architecture implementation review

Approved 2026-08-28 with B-Client applied and no findings. The reviewer
confirmed that direct Layer-4 dependencies on the plan-approved Layer-0
capabilities are valid; tray policy and Quit ordering stay in the cubit; the
adapter remains dumb; adapters are DI-owned while the cubit is shell-created;
and no speculative step-7 window ownership was introduced.

Residual manual risk: Linux StatusNotifier hosting and Windows tray rendering
still need real-host smoke coverage. Unavailable-state and visible-window
fallback are automated.

## Verification

- `client/module_desktop_core`: analysis clean; all 116 tests passed; 6 focused
  cubit tests cover menu/status updates, both fallback paths, On/Off, ordered
  Quit, and stop-failure refusal to exit.
- `client/desktop`: analysis clean; all 26 tests passed; 7 focused adapter/DI/
  smoke tests cover Linux host evidence, menu translation, platform icon
  selection, termination forwarding, registration, and window fallback.
- Desktop Injectable and Flutter plugin registration regenerated.
- macOS debug application build passed, with both tray assets present in the
  built Flutter asset bundle.
- Dart LSP: 0 diagnostics across 13 affected non-generated Dart files.
- `git diff --check` — clean.
- Change size: 1,047 text changed lines plus two bundled tray assets.
