# Phase 2 — Desktop Shell + Supervisor (functional internal MVP)

> Goal: build `client/desktop` — the Flutter GUI that logs in, supervises the
> bridge helper, shows tray control + status, autostarts, and renders first-run
> provisioning progress. End state: download-and-run app that logs in, runs the
> bridge, the phone connects.

**Standing acceptance (all Phase 2 PRs):** after merge `dart pub get` +
`client/app` (the mobile product) build/test stay green (release-safety invariant #4); desktop-only
deps are platform-scoped and don't enter mobile builds. Once `client/desktop` and
`client/module_desktop_core` exist, every Phase 2 PR also runs the relevant
desktop/module-desktop-core analyze, test, and build gates for the packages it
touches.

**Per-PR template:** Goal · Scope · Risk · Review-size · Acceptance · DoD ·
Aristotle verdicts · Findings log · Plan-deltas.

---

## PR 2.1 — `client/module_desktop_core` + `client/desktop` packages + builds on 3 OSes
- **Goal:** New pure-Dart `module_desktop_core` package plus new Flutter
  `client/desktop` package; `main_desktop.dart`; empty window; DI bootstrap
  reusing `module_core`/`module_auth` (platform → auth → core → desktop-core
  order). Builds on macOS/Windows/Linux.
- **Risk:** Med. **Size:** M.
- **Acceptance:** `module_desktop_core` analyzes/tests as an empty module;
  `flutter build macos/windows/linux` succeeds; app launches to a placeholder;
  mobile build unaffected; no bridge process business logic lands in
  `client/desktop`.

## PR 2.2 — Desktop platform adapters (module_core + module_desktop_core prerequisites)
- **Goal:** Register desktop implementations before any DI slice resolves the
  services that need them. Early login requires `SecureStorage`, `UrlLauncher`,
  `LifecycleSource`, a desktop `OAuthDeviceDescriptorProvider`, and a desktop
  `http.Client`. Lean v1 does **not** resolve `ConnectionService`;
  `RelayCryptoService`/`FailureReporter` must be registered before Phase 4
  accessory UI resolves relay transport, and a no-op `FailureReporter` may still
  land here if the package-level DI resolver eagerly requires it. Desktop-core
  capability interfaces (`SystemTray`, `WindowHost`, `LaunchAtLogin`,
  `AppUpdater`) are introduced with no-op or fakeable adapters only when the
  corresponding Phase 2 slice first uses them.

  | Interface / dependency | Owned by | Desktop implementation timing |
  |---|---|---|
  | `SecureStorage` | `module_auth`/`module_core` seam | PR 2.2 |
  | `UrlLauncher` | `module_core` seam | PR 2.2 |
  | `LifecycleSource` | `module_core` seam | PR 2.2 |
  | `OAuthDeviceDescriptorProvider` | `module_auth` DI prerequisite | PR 2.2 before `configureAuthDependencies` |
  | `http.Client` | `module_auth` DI prerequisite | PR 2.2 before `configureAuthDependencies` |
  | `RelayCryptoService` / `FailureReporter` | `module_core` relay prerequisites | before any desktop `ConnectionService` resolution; no later than PR 4.7 |
  | `SystemTray` / `WindowHost` / `LaunchAtLogin` / `AppUpdater` | `module_desktop_core` seams | introduced by the Phase 2 PR that first uses each capability |

- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** secure storage read/write works per OS; auth DI resolves with
  the desktop `http.Client` and `OAuthDeviceDescriptorProvider`; `LoginCubit` can
  be constructed from dependencies resolved through `get_it` with no
  missing-registration errors, but the cubit itself is not registered in DI;
  desktop-core adapters used by this PR resolve through DI; no relay
  `ConnectionService` resolution is required before Phase 4.

## PR 2.3 — Login reuse (browser-poll OAuth)
- **Goal:** Wire login via `configureAuthDependencies` + exported interfaces
  (`OAuthFlowProvider`/`AuthSession`); server-poll OAuth (no deep link). The
  browser is opened via the **desktop `UrlLauncher` adapter** (PR 2.2) — the
  bridge's `openOAuthBrowser` is bridge-workspace-only and must NOT be imported
  (ADR A11). **No direct `AuthManager` import.**
- **Risk:** Med. **Size:** M.
- **Acceptance:** can log in via the system browser; auth state observed via
  interfaces; no import of bridge internals.

## PR 2.4 — Control status/prompt trackers baseline (no relay client yet)
- **Goal:** Add `BridgeStatusTracker` and `BridgePromptTracker` in
  `module_desktop_core` Layer 2. They expose stream/snapshot state for the v1
  control window and tray, default to offline/no-prompt before the helper
  connects, and contain only health/count/provisioning data — no project/session
  names or message content. The desktop relay client stays deferred to Phase 4.
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** trackers are pure Dart, push-based, testable without Flutter,
  and do not resolve `ConnectionService`; v1 UI can render bridge offline from the
  tracker baseline before the control channel is available.

## PR 2.5a — Re-export `AuthTokenProvider` from `module_core` (seam, precursor)
- **Goal:** `sesori_dart_core` re-exports `AuthSession`/`OAuthFlowProvider` but
  **not** `AuthTokenProvider` (verified). The desktop dispatcher lives in
  `module_desktop_core`, while `client/desktop` may only import `sesori_auth` for
  the `configureAuthDependencies` DI call, so desktop core needs a `module_core`
  seam to consume the token provider with typed DI. Add the `AuthTokenProvider`
  re-export to the `module_core` barrel.
- **Risk:** Low. **Size:** S. (Mobile-product change — keep `client/app` green.)
- **Acceptance:** `module_core` exposes `AuthTokenProvider`; mobile build + tests
  green.

## PR 2.5 — `ControlChannelServer` + `ControlMessageDispatcher` + token responder
- **Goal:** GUI-hosted loopback WS host + off-argv per-spawn secret.
  `ControlChannelServer` (`module_desktop_core` Layer 0) exposes an inbound
  message stream + `send`.
  `ControlMessageDispatcher` (**Layer 4** consumer/orchestrator) subscribes to
  that stream and writes **down** into Layer-2 trackers / token seams: token req →
  `AuthTokenProvider` (via the `module_core` re-export from PR 2.5a — **not** a
  direct `module_auth` import in source), status/progress → `BridgeStatusTracker`,
  prompts → `BridgePromptTracker`. The cubit reads those trackers. All deps point
  downward — the dispatcher touches neither the cubit (no L4↔L4) nor a peer
  service as a same-level dep (ADR A14). Tested against a fake helper.
- **Risk:** Med. **Size:** M.
- **Acceptance:** a fake helper connects with the secret, requests + receives a
  token; loopback-only bind; per-spawn secret rotated; bad secret rejected; only
  one authenticated helper is accepted per spawn; null/unavailable token returns a
  structured auth-required response; prompts/status surface via trackers; no
  dispatcher→cubit dependency and no same-level dispatcher↔service edge; no direct
  `module_auth` import in non-DI source.

## PR 2.6 — `BridgeProcessService`: spawn/kill/path + expected-stop boundary
- **Goal:** Spawn the bridge binary (path resolution dev + packaged) passing
  `--control-url` + the **off-argv** control secret (ADR A8); kill; monitor exit.
  Layer-3 service over a Layer-2 `BridgeProcessRepository` over a Layer-1 process
  API (mirrors `HostProcessCommandExecutor`). `BridgeProcessRepository` owns the
  expected-exit marker and exposes an atomic expected-stop operation so update
  logic can suppress respawn without depending on `BridgeProcessService`. No
  exit-code state machine yet.
  The service refuses to spawn while the GUI is unauthenticated; the cubit/window
  surfaces login-required instead of starting a helper that will immediately fail.
- **Scope note:** guard against invalid/non-positive PIDs (`pid <= 0`) at the
  process-API entry point so platform tools (e.g. Windows `tasklist` PID filter)
  don't throw on bad input — consistent cross-platform behaviour.
- **Risk:** High (process lifecycle, cross-platform spawn). **Size:** M.
- **Acceptance:** authenticated start spawns + connects to the control server;
  unauthenticated start yields login-required without spawning; clean kill; secret
  not visible in `ps`/argv; non-positive PIDs handled gracefully.

## PR 2.7 — Exit-code state machine
- **Goal:** Keep exit-code/backoff decisions in `BridgeProcessService`, because
  respawn/stop/give-up policy is process lifecycle business logic. Mapping:
  86→respawn (no backoff), 0→stop (no respawn), repository-marked expected stop
  →stop (no respawn), auth-required clean exit→stop with login-required state,
  other→crash backoff + give-up + tray surfacing. Isolated state-machine tests
  exercise the service with fake `BridgeProcessRepository` inputs.
- **Risk:** High. **Size:** M.
- **Acceptance:** each exit class drives the correct action; give-up after N rapid
  crashes surfaces an error; exit policy does not live in a Layer-2 tracker.

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
  adapter must not depend on higher-layer process/status state — that reverses
  dependency direction). The
  **Layer-4 `BridgeControlCubit`** in `module_desktop_core` owns the wiring: it
  consumes the service + tracker, builds the menu model, pushes it to
  `SystemTray`, and handles tray click events (On/Off → `BridgeProcessService`,
  Open/Quit). Reused later by the popover.
- **Risk:** Med. **Size:** M.
- **Acceptance:** tray works on 3 OSes; toggle starts/stops the bridge; status
  updates live; `SystemTray` has no dependency on desktop-core services,
  trackers, or cubits.

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
- **Goal:** `DesktopInstanceService` over `DesktopInstanceRepository` (which wraps
  the lock/storage boundary) owns single-instance lock orchestration (second
  launch focuses first) and persists on/off + last-state. A Layer-4
  `DesktopStartupOrchestrator` composes `DesktopInstanceService` and
  `BridgeProcessService` to restore a last-on bridge, so the instance service
  does not call a peer service or duplicate bridge spawn/auth/backoff policy.
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** second launch focuses first; last-on respawns bridge on boot
  through `DesktopStartupOrchestrator`; no Layer-3 service depends on a peer
  Layer-3 service.

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
- **Goal:** Run GUI+helper together with local fakes: spawn → control handshake →
  token push/pull → helper relay connect/authenticate against a fake relay →
  trigger 86 → respawn → logout → unregister. Use fake auth/token/control/relay
  boundaries; do not depend on external Sesori services.
- **Risk:** Med. **Size:** M.
- **Acceptance:** the full happy path passes as an automated/scripted test using
  local fakes; the helper proves it can authenticate to the fake relay with the
  GUI-supplied token before restart/logout; failures are deterministic in CI.

## PR 2.16 — First-run provisioning progress UI + degraded state
- **Goal:** Render `RuntimeProvisionProgress` (download bar/status) from the
  control channel on first run; show a **degraded** state when `ProvisionFailed`
  (relay/phone still up). Status model in `BridgeStatusTracker` gains
  `provisioning`/`degraded`.
- **Risk:** Med. **Size:** M.
- **Acceptance:** first run shows download progress; provision failure shows a
  degraded-but-running state.
