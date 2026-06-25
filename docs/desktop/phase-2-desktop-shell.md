# Phase 2 — Desktop Shell + Supervisor (functional internal MVP)

> Goal: build `client/desktop` — the Flutter GUI that logs in, supervises the
> bridge helper, shows tray control + status, autostarts, and renders first-run
> provisioning progress. End state: download-and-run app that logs in, runs the
> bridge, the phone connects.

**Standing acceptance (all Phase 2 PRs):** after merge `dart pub get` +
`client/app` (the mobile product) build/test stay green (release-safety invariant #4); desktop-only
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

## PR 2.2 — Desktop platform adapters (ALL module_core prerequisites)
- **Goal:** Register desktop implementations for **every** `module_core` platform
  prerequisite the early login/relay slices need — not just `SecureStorage` +
  `UrlLauncher`, but also `LifecycleSource` (login) and `RelayCryptoService` +
  `FailureReporter` (relay). `LoginCubit`/`ConnectionService` constructors require
  these, so deferring `FailureReporter` to PR 2.14 would let the package build but
  fail at `get_it` resolution. Use no-op/desktop impls where a full one isn't
  ready yet (PR 2.14 later replaces the `FailureReporter` no-op with the real one).
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** secure storage read/write works per OS; `get_it` resolves
  `LoginCubit` + `ConnectionService` with no missing-registration errors.

## PR 2.3 — Login reuse (browser-poll OAuth)
- **Goal:** Wire login via `configureAuthDependencies` + exported interfaces
  (`OAuthFlowProvider`/`AuthSession`); server-poll OAuth (no deep link). The
  browser is opened via the **desktop `UrlLauncher` adapter** (PR 2.2) — the
  bridge's `openOAuthBrowser` is bridge-workspace-only and must NOT be imported
  (ADR A11). **No direct `AuthManager` import.**
- **Risk:** Med. **Size:** M.
- **Acceptance:** can log in via the system browser; auth state observed via
  interfaces; no import of bridge internals.

## PR 2.4 — Relay connection + bridge online/offline
- **Goal:** Connect to the relay as a client; show bridge online/offline.
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** relay connects with the auth token; status reflects bridge
  presence.

## PR 2.5a — Re-export `AuthTokenProvider` from `module_core` (seam, precursor)
- **Goal:** `sesori_dart_core` re-exports `AuthSession`/`OAuthFlowProvider` but
  **not** `AuthTokenProvider` (verified). The desktop dispatcher is app-level and
  may only import `sesori_auth` for the `configureAuthDependencies` DI call, so it
  needs a `module_core` seam to consume the token provider with typed DI. Add the
  `AuthTokenProvider` re-export to the `module_core` barrel.
- **Risk:** Low. **Size:** S. (Mobile-product change — keep `client/app` green.)
- **Acceptance:** `module_core` exposes `AuthTokenProvider`; mobile build + tests
  green.

## PR 2.5 — `ControlChannelServer` + `ControlMessageDispatcher` + token responder
- **Goal:** GUI-hosted loopback WS host + off-argv per-spawn secret.
  `ControlChannelServer` (Layer 0) exposes an inbound message stream + `send`.
  `ControlMessageDispatcher` (**Layer 4** consumer/orchestrator) subscribes to
  that stream and writes **down** into Layer-3 sinks: token req →
  `AuthTokenProvider` (via the `module_core` re-export from PR 2.5a — **not** a
  direct `module_auth` import in source), status/progress → `BridgeStatusTracker`,
  prompts → `BridgePromptTracker`. The cubit reads those trackers. All deps point
  downward — the dispatcher touches neither the cubit (no L4↔L4) nor a peer
  Layer-3 service as a same-level dep (ADR A14). Tested against a fake helper.
- **Risk:** Med. **Size:** M.
- **Acceptance:** a fake helper connects with the secret, requests + receives a
  token; bad secret rejected; prompts/status surface via trackers; no
  dispatcher→cubit dependency and no same-level dispatcher↔service edge; no direct
  `module_auth` import in non-DI source.

## PR 2.6 — `BridgeProcessService`: spawn/kill/path + control flags
- **Goal:** Spawn the bridge binary (path resolution dev + packaged) passing
  `--control-url` + the **off-argv** control secret (ADR A8); kill; monitor exit.
  Layer-3 service over a Layer-2 `BridgeProcessRepository` over a Layer-1 process
  API (mirrors `HostProcessCommandExecutor`). No exit-code state machine yet.
- **Scope note:** guard against invalid/non-positive PIDs (`pid <= 0`) at the
  process-API entry point so platform tools (e.g. Windows `tasklist` PID filter)
  don't throw on bad input — consistent cross-platform behaviour.
- **Risk:** High (process lifecycle, cross-platform spawn). **Size:** M.
- **Acceptance:** spawns + connects to the control server; clean kill; secret
  not visible in `ps`/argv; non-positive PIDs handled gracefully.

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
- **Goal:** Keep `SystemTray` (`tray_manager`) a **dumb Layer-0 adapter**: it
  renders menu items + exposes click events through its interface; it knows
  **nothing** about `BridgeProcessService`/`BridgeStatusTracker` (a Layer-0
  adapter must not depend on Layer-3 — that reverses dependency direction). The
  **Layer-4 `BridgeControlCubit`** owns the wiring: it consumes the service +
  tracker, builds the menu model, pushes it to `SystemTray`, and handles tray
  click events (On/Off → `BridgeProcessService`, Open/Quit). Reused later by the
  popover.
- **Risk:** Med. **Size:** M.
- **Acceptance:** tray works on 3 OSes; toggle starts/stops the bridge; status
  updates live; `SystemTray` has no dependency on Layer-3 classes.

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

## PR 2.13 — Logout coordination (GUI side) + offline unregister fallback
- **Goal:** On logout with a **live** helper: send `unregister-and-exit` → wait
  for exit → kill if needed → invalidate tokens (pairs with PR 1.11). But logout
  can also happen with the **bridge off, crashed, or the control channel
  unreachable** — and `bridgeId` is helper-owned, so the GUI would otherwise have
  nothing to unregister and the registration would leak. So the GUI keeps a
  **readable copy of `bridgeId`** — persisted on the GUI side from the
  `registered` control event (PR 1.2/1.10) as soon as the helper registers, so a
  later crash/stop can't leave the GUI with nothing to delete — and a
  **GUI-side unregister fallback** **before** invalidating tokens (ADR A13).
  The DELETE must go **through a `module_core` seam, not a direct auth-API call**:
  `module_core`'s `BridgeApi`/`BridgeRepository` currently cover only
  `GET /auth/bridges`, so add a `deleteBridge(id)` method on `BridgeApi` +
  `BridgeRepository` and have the GUI call that (app code must not call auth APIs
  or import the auth HTTP client directly). This `module_core` addition is a
  precursor sub-step of this PR.
- **Risk:** Med. **Size:** M.
- **Acceptance:** logout unregisters the bridge before token invalidation in
  **both** the live-helper and helper-absent/crashed paths; the GUI calls the
  `module_core` `BridgeRepository.deleteBridge` seam (no direct auth-API/HTTP
  import in app code); no leaked registration; mobile build stays green.

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
