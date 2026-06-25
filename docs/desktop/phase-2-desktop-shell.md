# Phase 2 — Desktop Shell + Supervisor (functional internal MVP)

> Goal: build `client/desktop` — the Flutter GUI that logs in, supervises the
> bridge helper, shows tray control + status, autostarts, and renders first-run
> provisioning progress. End state: download-and-run app that logs in, runs the
> bridge, the phone connects.

**Standing acceptance (all Phase 2 PRs):** after merge `dart pub get` +
`mobile/app` build/test stay green (release-safety invariant #4); desktop-only
deps are platform-scoped and don't enter mobile builds.

**Per-PR template:** Goal · Scope · Risk · Review-size · Acceptance · DoD ·
Aristotle verdicts · Findings log · Plan-deltas.

---

## PR 2.1 — `client/desktop` package + builds on 3 OSes
- **Goal:** New package; `main_desktop.dart`; empty window; DI bootstrap reusing
  `module_core`/`module_auth` (3-phase order). Builds on macOS/Windows/Linux.
- **Risk:** Med. **Size:** M.
- **Acceptance:** `flutter build macos/windows/linux` succeeds; app launches to a
  placeholder; mobile build unaffected.

## PR 2.2 — Desktop platform adapters
- **Goal:** Desktop `SecureStorage` + `UrlLauncher` adapters + DI registration.
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** secure storage read/write works on each desktop OS.

## PR 2.3 — Login reuse (`AuthManager` browser-poll OAuth)
- **Goal:** Wire login via `configureAuthDependencies` + exported interfaces
  (`OAuthFlowProvider`/`AuthSession`); browser-open + server poll (no deep link).
  **No direct `AuthManager` import.**
- **Risk:** Med. **Size:** M.
- **Acceptance:** can log in via browser; auth state observed via interfaces.

## PR 2.4 — Relay connection + bridge online/offline
- **Goal:** Connect to the relay as a client; show bridge online/offline.
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** relay connects with the auth token; status reflects bridge
  presence.

## PR 2.5 — `ControlChannelServer` + `ControlMessageDispatcher` + token responder
- **Goal:** GUI-hosted loopback WS host + per-spawn secret; dispatcher routes
  inbound (token req → `AuthTokenProvider`, status/progress → tracker, prompts →
  cubit). Tested against a fake helper client.
- **Risk:** Med. **Size:** M.
- **Acceptance:** a fake helper connects with the secret, requests + receives a
  token; bad secret rejected.

## PR 2.6 — `BridgeProcessService`: spawn/kill/path + control flags
- **Goal:** Spawn the bridge binary (path resolution dev + packaged) passing
  `--control-url`/`--control-secret`; kill; monitor exit. Layer-3 service over a
  Layer-2 `BridgeProcessRepository` over a Layer-1 process API (mirrors
  `HostProcessCommandExecutor`). No exit-code state machine yet.
- **Risk:** High (process lifecycle, cross-platform spawn). **Size:** M.
- **Acceptance:** spawns + connects to the control server; clean kill.

## PR 2.7 — Exit-code state machine
- **Goal:** 86→respawn (no backoff), 0→stop (no respawn), other→crash backoff +
  give-up + tray surfacing; GUI "expected exit" flag for GUI-initiated kills.
  Isolated state-machine tests.
- **Risk:** High. **Size:** M.
- **Acceptance:** each exit class drives the correct action; give-up after N rapid
  crashes surfaces an error.

## PR 2.8 — Spike: bundled bridge runtime-ownership + `--hidden` contention
- **Goal:** Run the bridge from a **fake bundle layout**; confirm it does NOT trip
  its runtime-ownership guard (`unsupportedPackageRuntimeMessage`) and that
  single-live contention under `--hidden` is handled (pairs with PR 1.12). Pulled
  forward to avoid discovering this at notarization (Phase 3).
- **Risk:** Med. **Size:** S-M.
- **Acceptance:** bundled-path launch succeeds; contention resolved without silent
  abort.

## PR 2.9 — Tray menu + reusable control cubit
- **Goal:** `SystemTray` (`tray_manager`) menu: On/Off toggle (→
  `BridgeProcessService`), status line (← `BridgeStatusTracker`), Open/Quit.
  `BridgeControlCubit` holds the toggle/status logic (reused later by the popover).
- **Risk:** Med. **Size:** M.
- **Acceptance:** tray works on 3 OSes; toggle starts/stops the bridge; status
  updates live.

## PR 2.10 — `WindowHost` single window + v1 window contents
- **Goal:** `window_manager` single window (show/hide/focus). v1 window contents:
  connection/account status, login/logout, on/off, check-for-update, quit.
- **Risk:** Med. **Size:** M.
- **Acceptance:** window opens/focuses from tray; contents reflect live state.

## PR 2.11 — Autostart + `--hidden` boot + macOS login-item detection
- **Goal:** `LaunchAtLogin` (`launch_at_startup`) registration with `--hidden`;
  detect hidden launch → tray-only (macOS may need a `SMAppService` shim).
- **Risk:** Med. **Size:** M.
- **Acceptance:** reboot → tray returns hidden (no window).

## PR 2.12 — GUI single-instance + persist on/off & last-state
- **Goal:** `DesktopInstanceService` single-instance lock (second launch focuses
  first); persist on/off + last-state; respawn bridge if last-on.
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** second launch focuses first; last-on respawns bridge on boot.

## PR 2.13 — Logout coordination (GUI side)
- **Goal:** On logout: send `unregister-and-exit` → wait for helper exit → kill if
  needed → invalidate tokens. Pairs with PR 1.11.
- **Risk:** Med. **Size:** S-M.
- **Acceptance:** logout unregisters the bridge before token invalidation.

## PR 2.14 — Desktop `FailureReporter` impl
- **Goal:** Crash/error reporting for the tray app (decide Crashlytics vs other
  vs no-op).
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** errors are reported/recorded per the chosen impl.

## PR 2.15 — E2E integration
- **Goal:** Run GUI+helper together: spawn → control handshake → token push/pull →
  relay connect → trigger 86 → respawn → logout → unregister.
- **Risk:** Med. **Size:** M.
- **Acceptance:** the full happy path passes as an automated/scripted test.

## PR 2.16 — First-run provisioning progress UI + degraded state
- **Goal:** Render `RuntimeProvisionProgress` (download bar/status) from the
  control channel on first run; show a **degraded** state when `ProvisionFailed`
  (relay/phone still up). Status model in `BridgeStatusTracker` gains
  `provisioning`/`degraded`.
- **Risk:** Med. **Size:** M.
- **Acceptance:** first run shows download progress; provision failure shows a
  degraded-but-running state.
