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
  and let its auth-state listener own relay connect/reconnect behavior. The
  signed-in destination signals `DesktopRelayConnectionService` through the
  auth-gate intent for token-only local restores that intentionally remain
  `AuthInitial`; the connection overlay remains stream-derived and issues no
  transport commands.
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

Approved with no blocking findings. The review covered the desktop DI/platform
boundary, root relay-client composition, shell-owned cubits and presentation,
route-less behavior, privacy-preserving failure reporting, client layering, and
Step 13 scope. The reviewer returned `Merge verdict: OK`. A follow-up Codex P1
found that the token-only trigger had been placed on the projection cubit; it
was moved to the desktop auth/connection coordination service and auth-gate
intent before the follow-up push.

## Verification

- `client/desktop`: `dart analyze --fatal-infos` clean; full `flutter test`
  passed (57 tests).
- `client/module_desktop_core`: `dart analyze --fatal-infos` clean; full
  `dart test` passed (183 tests).
- Desktop DI resolves `RelayCryptoService`, `FailureReporter`, `RouteSource`,
  `ConnectionService`, and `RegisteredBridgesService`; cubits remain
  shell-constructed rather than DI-registered.
- Focused coverage verifies bridge-offline and relay-lost banners, retry
  delegation, backend toast presentation on the navigator overlay, the
  token-only signed-in destination handoff through the auth/connection
  coordinator, DI registration, and the separate desktop relay-client status
  row.
- Dart LSP diagnostics and `git diff --check` are clean.
- `asdf exec flutter build macos` completed successfully (`Sesori.app`,
  55.3 MB); the Step 13 PR's 13/13 CI checks also passed the Windows/Linux
  native build jobs.

## Post-step supervision hardening

The follow-up keeps app Quit from rewriting the persisted bridge intent: an
explicit Bridge Off action and coordinated logout still persist Off, while Quit
only performs the expected helper stop. It adds a typed Take Over action for
local bridge contention and relay displacement; the action persists On, does
one stop-and-respawn, and accepts only replacement prompts from the fresh
helper. The desktop also supplies a login-shell-derived PATH override to the
supervised helper, without importing shell variables or granting macOS Full
Disk Access. Genuine Full Disk Access remains a user permission for the process
that actually runs the bridge.

## Handoff

Step 12 merged in PR #1215 on 2026-08-30, and Step 13 merged in PR #1216 on
2026-08-31. The desktop relay-client implementation is complete. MT gate B
remains the user-run daily-driver checkpoint; after its outcome is recorded,
Step 14 creates `module_app_ui`, moves the shared localization/context
foundation, and replaces the temporary route-less desktop source and
shell-owned connection banner with the shared adaptive UI/router foundation.
