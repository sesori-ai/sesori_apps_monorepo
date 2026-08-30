# Step 13 — ⚙️ Desktop becomes a relay client

Date: 2026-08-30.

## Delivered

- Registered the desktop shell's missing shared relay prerequisites: a
  singleton `RelayCryptoService`, a local log-backed `FailureReporter`, and a
  route-source boundary for the pre-router shell.
- `DesktopFailureReporter` keeps handled failures observable through the
  existing application logger. It retains the original error and stack trace,
  bounded operation/event context, and fatal/reason metadata while reducing
  opaque information arguments to type/shape metadata so SSE properties cannot
  put prompt, transcript, or source content into a future crash-report seam.
- Rooted the existing shared `ConnectionService` before the desktop widget tree
  and let its auth-state listener own relay connect/reconnect behavior. No
  second reconnect driver was added.
- Constructed `ConnectionOverlayCubit` and `SseToastCubit` at the desktop root,
  added a root connection-banner host, and added a navigator-overlay Prego toast
  listener for backend `tui.toast.show` events. The desktop home now shows the
  desktop relay-client state separately from the supervised helper's relay
  status.
- Added the route-less desktop source required by `SseToastCubit`. Until the
  Step 14 router exists, app-wide toasts remain visible and session-attributed
  toasts are withheld without inventing a session identity. Push/local
  notification-open capabilities remain unbound because the current desktop
  shell has no notification surface.
- Added focused DI, reporter, route-source, banner, toast-listener, home, auth
  gate, and startup smoke coverage.

No database schema, persisted-data format, or wire-contract change. The desktop
shell now activates the already-shared relay transport and root event surfaces.

## Architecture implementation review

Pending the required implementation review for the new desktop DI/platform
boundary and root relay-client composition.

## Verification

- `client/desktop`: `dart analyze --fatal-infos` clean; full `flutter test`
  passed (56 tests).
- Desktop DI resolves `RelayCryptoService`, `FailureReporter`, `RouteSource`,
  `ConnectionService`, and `RegisteredBridgesService`; cubits remain
  shell-constructed rather than DI-registered.
- Focused widget coverage verifies bridge-offline and relay-lost banners,
  retry delegation, backend toast presentation on the navigator overlay, and
  the separate desktop relay-client status row.
- Dart LSP diagnostics and `git diff --check` are clean.
- Native desktop build/CI verification remains pending for the Step 13 PR.

## Handoff

Step 12 merged in PR #1215 on 2026-08-30. After this step merges, Step 14
creates `module_app_ui`, moves the shared localization/context foundation, and
replaces the temporary route-less desktop source and shell-owned connection
banner with the shared adaptive UI/router foundation. MT gate B remains the
user-run daily-driver checkpoint.
