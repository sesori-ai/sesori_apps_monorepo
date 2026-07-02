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
touches — **in CI, not just locally**: PR 2.1 creates the desktop PR-CI workflow
that makes this real (mobile CI deliberately excludes `client/desktop/**` since
PR 0.1, and Phase 3's `_reusable-desktop-build.yml` is a release leg, not PR CI).

**Per-PR template:** Goal · Scope · Risk · Review-size · **Regression guide** ·
Acceptance · DoD (incl. PLAN.md §9 row + pointer advanced) · Aristotle verdicts ·
Findings log · Plan-deltas.

> **Regression guide** = the blast radius of the PR: which existing behaviours
> could break, and the quick checks that prove they didn't. For Phase 2 the
> recurring blast radius is the **mobile product** (shared workspace, shared
> modules) and the **standalone bridge** (spawned binary) — each PR lists its
> specifics.

---

## PR 2.1 — `client/module_desktop_core` + `client/desktop` packages + desktop PR CI + builds on 3 OSes
- **Goal:** New pure-Dart `module_desktop_core` package plus new Flutter
  `client/desktop` package; `main_desktop.dart`; empty window; DI bootstrap
  reusing `module_core`/`module_auth` (platform → auth → core → desktop-core
  order). Builds on macOS/Windows/Linux. **Also creates `desktop-ci.yml`**,
  with two GitHub-mechanics constraints designed in from the start:
  - **Required-check-safe triggering:** a workflow-level `paths:` filter cannot
    be a required check — GitHub leaves skipped-required workflows "pending",
    blocking every non-desktop PR. So the workflow triggers on all PRs
    **without** a workflow-level path filter; its first job computes
    changed-path outputs (e.g. `dorny/paths-filter`) for the desktop-relevant
    set — `client/desktop/**`, `client/module_desktop_core/**`, the shared
    packages the desktop build depends on (`client/module_core/**`,
    `client/module_auth/**`, `client/module_prego/**`, `shared/sesori_shared/**`,
    later `client/module_app_ui/**`), and the client workspace root files
    (pubspec/lock/analysis/Makefile) — and the desktop jobs run behind `if:`
    guards on those outputs. A terminal status job always runs (succeeding when
    the desktop jobs were skipped) so the check can be branch-protection
    required without ever blocking a mobile/bridge PR. The shared-package paths
    matter because a shared change can break the desktop build while mobile CI
    stays green (desktop-only API paths).
  - **All three OSes in the PR build matrix:** analyze + `dart test` run once
    (ubuntu; pure Dart), but the `flutter build` leg runs on a
    macos/windows/ubuntu **matrix** — the acceptance "builds on 3 OSes" is only
    real if CI enforces it per PR; a single-OS smoke leg would let Windows/
    Linux-only compile or plugin failures merge unseen until MT-3. Runner cost
    is bounded by the `if:` path gating (only desktop-relevant PRs spin the
    matrix).

  Non-blocking for CLI/mobile releases (invariant #3) but a required check on
  PRs (safe per the wrapper above) — this is what makes the standing acceptance
  enforceable rather than aspirational.
- **Risk:** Med. **Size:** M.
- **Regression guide:** touches the client pub workspace root (`client/pubspec.yaml`
  membership) and CI path filters — the two ways to silently break mobile. Check:
  (1) `dart pub get` from `client/` still resolves with an unchanged mobile
  dependency set (lockfile diff reviewed); (2) mobile CI + release workflows do
  NOT trigger on a desktop-only file (path filters from PR 0.1 still hold; add a
  probe PR/dry-run if unsure); (3) `lint-suppressions.yml` DOES cover the new
  packages; (4) `client/app` build + tests green.
- **Acceptance:** `module_desktop_core` analyzes/tests as an empty module;
  `flutter build macos/windows/linux` succeeds; app launches to a placeholder;
  mobile build unaffected; no bridge process business logic lands in
  `client/desktop`; `desktop-ci.yml` runs analyze/test + the 3-OS build matrix
  on a desktop-relevant PR, reports success (skipped-internally) on a
  non-desktop PR so it is safe as a required check, and does not gate
  CLI/mobile releases.

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
- **Regression guide:** desktop-shell-only code, but it exercises shared DI
  contracts. Check: (1) no changes leak into `module_core`/`module_auth` DI
  registration order (mobile boots unchanged); (2) desktop `SecureStorage`
  works on each OS backend (macOS Keychain, Windows DPAPI/credential store,
  Linux libsecret — including a distro **without** a secret service: fail loudly,
  don't corrupt); (3) repeated app launches don't duplicate registrations
  (`get_it` reset semantics).
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
- **Regression guide:** reuses the shared `AuthManager` OAuth-poll flow — any
  change to it hits mobile login too. Check: (1) `module_auth` source untouched
  (or, if a seam is genuinely needed, mobile login manually re-verified:
  fresh login, token refresh, logout); (2) the desktop OAuth init sends a
  desktop `OAuthClientType`/device descriptor so the confirmation interstitial
  labels the device correctly; (3) auth-state stream drives the desktop UI
  through `module_core` interfaces only (no `module_auth` import outside DI).
- **Acceptance:** can log in via the system browser; auth state observed via
  interfaces; no import of bridge internals.

## PR 2.4 — Control status/prompt trackers baseline (no relay client yet)
- **Goal:** Add `BridgeStatusTracker` and `BridgePromptTracker` in
  `module_desktop_core` Layer 2. They expose stream/snapshot state for the v1
  control window and tray, default to offline/no-prompt before the helper
  connects, and contain only health/count/provisioning data — no project/session
  names or message content. The desktop relay client stays deferred to Phase 4.
- **Risk:** Low-Med. **Size:** S-M.
- **Regression guide:** additive pure-Dart module code; blast radius is the
  future contract, not existing behaviour. Check: (1) nothing resolves
  `ConnectionService`/relay prerequisites (A21 holds); (2) tracker state shape
  matches the PR-1.2 DTO enums incl. `unknown` fallbacks (a newer helper must
  not crash the tracker); (3) mobile untouched.
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
- **Regression guide:** touches the `sesori_dart_core` barrel that every mobile
  file imports. Check: (1) no export-name collision with existing `show` list
  (analyzer catches ambiguous exports — run mobile analyze, not just desktop);
  (2) mobile build + tests green; (3) mobile release path filters treat this as
  a mobile-product change (it is one — the CI gates must run).
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
- **Regression guide:** new desktop-core seam; the contract risk is protocol
  compatibility with the already-shipped bridge side. Check: (1) wire behaviour
  matches PR 1.1–1.5 exactly — secret as `Authorization: Bearer` on the WS
  **upgrade request**, id-correlated `token_response`, non-null-only
  `token_update`, null token for signed-out; verify against a **real locally
  built bridge**, not only the fake helper; (2) unknown/undecodable inbound
  frames warn+skip (forward compat); (3) port is ephemeral (bind :0) — no fixed
  port that could collide; (4) mobile untouched.
- **Acceptance:** a fake helper connects with the secret, requests + receives a
  token; loopback-only bind; per-spawn secret rotated; bad secret rejected; only
  one authenticated helper is accepted per spawn; null/unavailable token returns a
  structured auth-required response; prompts/status surface via trackers; no
  dispatcher→cubit dependency and no same-level dispatcher↔service edge; no direct
  `module_auth` import in non-DI source.

## PR 2.6 — `BridgeProcessService`: spawn/kill/path + expected-stop boundary + helper log capture
- **Goal:** Spawn the bridge binary (path resolution dev + packaged) passing
  `--control-url` + the **off-argv** control secret (ADR A8); kill; monitor exit.
  Layer-3 service over a Layer-2 `BridgeProcessRepository` over a Layer-1 process
  API (mirrors `HostProcessCommandExecutor`). `BridgeProcessRepository` owns the
  expected-exit marker and exposes an atomic expected-stop operation so update
  logic can suppress respawn without depending on `BridgeProcessService`. No
  exit-code state machine yet.
  The service refuses to spawn while the GUI is unauthenticated; the cubit/window
  surfaces login-required instead of starting a helper that will immediately fail.
- **Scope note — helper stdout/stderr MUST be drained, owned by a Tracker over a
  Layer-1 Storage.** The bridge writes `Console`/`Log` output to its pipes; an
  undrained pipe buffer eventually **blocks the child** (classic
  supervised-process deadlock), and discarded output leaves the crash/give-up
  states (PR 2.7) and `FailureReporter` (PR 2.14) with nothing to show.
  Ownership (per §6): a dedicated Layer-2 **`BridgeProcessLogTracker`** in
  `module_desktop_core/lib/src/trackers/` subscribes to the raw stdout/stderr
  streams the Layer-1 process API exposes, drains them, and keeps an in-memory
  last-N ring buffer exposed as snapshot/stream; **file persistence lives below
  it** in a dumb Layer-1 **`BridgeProcessLogStorage`** (`api/`) that appends
  lines and rotates at a size cap under GUI-owned app data (desktop-namespaced;
  never the shared Sesori data root, ADR A10) — the tracker owns derived state,
  the storage owns the file, mirroring the module's Layer-1 `Storage` boundary.
  `BridgeProcessService` attaches the tracker to the child's streams after
  spawn; the process API stays a dumb stream provider and
  `BridgeProcessRepository` keeps ONLY the expected-exit marker. The window gets
  an "open logs" affordance in PR 2.10 (path exposed by the storage).
  **Storage-write failures must not stop the drain:** a throwing append/rotate
  in `BridgeProcessLogStorage` (disk full, permissions) propagates to the
  tracker, which catches and logs it (rate-limited, per the
  swallow-and-continue rule) while pipe draining and the ring buffer keep
  working — an uncaught write error would kill the stream subscription and
  recreate the exact blocked-pipe deadlock this component exists to prevent.
- **Scope note:** guard against invalid/non-positive PIDs (`pid <= 0`) at the
  process-API entry point so platform tools (e.g. Windows `tasklist` PID filter)
  don't throw on bad input — consistent cross-platform behaviour.
- **Risk:** High (process lifecycle, cross-platform spawn). **Size:** M.
- **Regression guide:** first PR that spawns a real bridge from the GUI — the
  blast radius is the **standalone bridge's on-disk state** shared with any
  co-installed CLI. Check: (1) the supervised helper uses the same
  `bridge_id`/managed-runtime roots without corrupting them — afterwards the
  standalone CLI still starts, stays logged in, and reuses its identity; (2) no
  zombie/orphan helper after repeated on/off toggles and after GUI force-kill
  (helper self-exits via A9 grace); (3) secret absent from `ps`/argv/Windows
  `wmic`; (4) chatty helper (verbose logging) does NOT stall — pipes drained,
  log file rotates; (5) kill during startup (pre-handshake) leaves no lock/mutex
  residue that blocks the next spawn.
- **Acceptance:** authenticated start spawns + connects to the control server;
  unauthenticated start yields login-required without spawning; clean kill; secret
  not visible in `ps`/argv; non-positive PIDs handled gracefully;
  `BridgeProcessLogTracker` (ring buffer, drain) over `BridgeProcessLogStorage`
  (rotating file) captures helper output, a chatty helper cannot block on full
  pipes, an injected storage write failure leaves draining + ring buffer alive
  (asserted by test), and neither the process API nor `BridgeProcessRepository`
  owns log state.

## PR 2.7 — Exit-code state machine
- **Goal:** Keep exit-code/backoff decisions in `BridgeProcessService`, because
  respawn/stop/give-up policy is process lifecycle business logic. Mapping:
  86→respawn (no backoff), **87 (auth-required, ADR A23)→stop with
  login-required state (no backoff thrash)**, 0→stop (no respawn),
  repository-marked expected stop→stop (no respawn), other→crash backoff +
  give-up + tray surfacing (give-up shows the last-N helper log lines from the
  PR-2.6 `BridgeProcessLogTracker` snapshot). Isolated state-machine tests
  exercise the service with fake `BridgeProcessRepository` inputs.
- **Risk:** High. **Size:** M.
- **Regression guide:** policy sits on top of PR 2.6's spawn path — the risk is
  runaway respawn behaviour. Check: (1) exit 86 respawns exactly once per exit
  (no double-spawn from racing exit + status events); (2) crash backoff is
  bounded and give-up genuinely stops (leave a crashing fake helper running for
  10+ minutes: bounded attempts, no CPU churn); (3) expected-stop marker
  consumption is atomic — an update-triggered stop can't be misread as a crash
  after a GUI restart; (4) exit 87 shows login-required and does NOT retry until
  auth state changes; (5) a mid-backoff manual "start" cancels the pending
  respawn timer (no double helper).
- **Acceptance:** each exit class drives the correct action; give-up after N rapid
  crashes surfaces an error with recent helper log lines; exit policy does not
  live in a Layer-2 tracker.

---

## MT-2 — Manual checkpoint: first real GUI supervision (user-run)

> Run after PR 2.7. First moment the real GUI supervises the real bridge — do it
> on your daily-driver desktop before investing in tray/window polish. Dev builds
> (`flutter run -d macos/windows/linux`) are fine.

| # | Check | How | Pass looks like |
|---|---|---|---|
| 1 | Login | log in via the system browser from the desktop app | auth completes; interstitial names the desktop device; relogin after app restart is silent (persisted tokens) |
| 2 | Supervised spawn | turn the bridge on from the dev window | helper spawns, control handshake completes, status goes healthy |
| 3 | Phone end-to-end | open the mobile app | phone connects through the desktop-supervised bridge; sessions browse + a question round-trips |
| 4 | Token authority | leave it running past access-token expiry (or force-refresh) | helper keeps working; no auth errors; no `token.json` writes by the helper |
| 5 | Crash respawn | `kill -9` the helper | GUI respawns with backoff; phone recovers |
| 6 | Restart sentinel | trigger restart from the phone | helper exits 86 → instant respawn; phone reconnects |
| 7 | Auth-required | log the GUI out while the helper is off; try to start | login-required state, no spawn, no thrash (exit-87 path if it raced past the gate) |
| 8 | Clean stop | toggle off | helper exits 0; no respawn; no orphaned `opencode serve` (`ps`) |
| 9 | Standalone coexistence | afterwards run the terminal `sesori-bridge` | CLI still logged in; single-live precedence per PR 1.12 (no silent abort) |

- **Aristotle:** n/a (no code). **Findings:** — **Deltas:** —

## PR 2.8 — Spike: bundled bridge runtime-ownership + `--hidden` contention
- **Goal:** Run the bridge from a **fake bundle layout**; confirm it does NOT trip
  its runtime-ownership guard (`unsupportedPackageRuntimeMessage`) and that
  single-live contention under `--hidden` is handled (pairs with PR 1.12). Pulled
  forward to avoid discovering this at notarization (Phase 3).
- **Risk:** Med. **Size:** S-M.
- **Regression guide:** spike — findings land as docs/plan-deltas, not shipped
  code. If it does touch the runtime-ownership guard, re-check: standalone
  managed installs still pass the guard, and npm-installed bridges still refuse
  unsupported layouts with the same message.
- **Acceptance:** bundled-path launch succeeds; contention resolved without silent
  abort.

## PR 2.9 — Tray menu + reusable control cubit + tray-unavailable fallback
- **Goal:** Keep `SystemTray` (`tray_manager`) a **dumb Layer-0 adapter**: it
  renders menu items + exposes click events through its interface; it knows
  **nothing** about `BridgeProcessService`/`BridgeStatusTracker` (a Layer-0
  adapter must not depend on higher-layer process/status state — that reverses
  dependency direction). The
  **Layer-4 `BridgeControlCubit`** in `module_desktop_core` owns the wiring: it
  consumes the service + tracker, builds the menu model, pushes it to
  `SystemTray`, and handles tray click events (On/Off → `BridgeProcessService`,
  Open/Quit). Reused later by the popover.
  **Tray availability is not guaranteed (ADR A24):** stock GNOME hides
  AppIndicators without an extension. The `SystemTray` adapter must report
  init failure/unavailability, and the shell falls back to **windowed mode**
  (window shown, quit-to-quit) instead of a reachable-by-nothing tray app.
- **Risk:** Med. **Size:** M.
- **Regression guide:** first UI wiring over the 2.4–2.7 stack. Check: (1) tray
  menu state can't go stale — it renders from tracker/service streams, and a
  helper crash while the menu is open updates it; (2) on GNOME-without-extension
  the app remains fully usable via the window (A24 fallback); (3) Quit from the
  tray stops the helper (expected-stop, no respawn) and exits the GUI — no
  lingering helper (`ps` check); (4) no `SystemTray` import of services/trackers
  (layer check).
- **Acceptance:** tray works on macOS/Windows/KDE + GNOME-with-extension; on
  GNOME-without-AppIndicator the windowed fallback engages (no unreachable
  hidden app); toggle starts/stops the bridge; status updates live; `SystemTray`
  has no dependency on desktop-core services, trackers, or cubits.

## PR 2.10 — `WindowHost` single window + v1 window contents
- **Goal:** `window_manager` single window (show/hide/focus). v1 window contents:
  connection/account status, login/logout, on/off, check-for-update, **open
  logs** (reveals the PR-2.6 log directory in Finder/Explorer/file manager),
  quit.
- **Risk:** Med. **Size:** M.
- **Regression guide:** window lifecycle interacts with tray-only mode. Check:
  (1) closing the window hides it (app + helper keep running) — it does not quit;
  (2) repeated open/close/focus cycles don't leak windows or crash
  `window_manager`; (3) quit from the window matches tray Quit semantics
  (helper stopped, expected-stop marked); (4) state shown after wake-from-sleep
  is live, not frozen (streams resubscribed if needed).
- **Acceptance:** window opens/focuses from tray; contents reflect live state;
  "open logs" reveals the helper log directory.

## PR 2.11 — Autostart + `--hidden` boot + macOS login-item detection
- **Goal:** `LaunchAtLogin` (`launch_at_startup`) registration with `--hidden`;
  detect hidden launch → tray-only (macOS may need a `SMAppService` shim).
  **Hidden boot requires a live tray (ADR A24):** if tray init fails at a hidden
  launch, show the window instead — never boot invisible-and-unreachable.
- **Risk:** Med. **Size:** M.
- **Regression guide:** touches OS login-item registration — a sticky, per-user
  global. Check: (1) toggling autostart off actually removes the login item
  (macOS System Settings / Windows run key / XDG autostart file inspected); (2)
  reinstalling/relaunching doesn't accumulate duplicate login items; (3) hidden
  boot on a machine where the network is not yet up: helper spawn retries/backs
  off rather than instant give-up; (4) GNOME-without-tray hidden boot shows the
  window (A24); (5) non-hidden manual launch behaviour unchanged.
- **Acceptance:** reboot → tray returns hidden (no window) where a tray exists;
  windowed fallback where it doesn't; autostart can be disabled and stays
  disabled.

## PR 2.12 — GUI single-instance + persist on/off & last-state
- **Goal:** `DesktopInstanceService` over `DesktopInstanceRepository` (which wraps
  the lock/storage boundary) owns single-instance lock orchestration (second
  launch focuses first) and persists on/off + last-state. A Layer-4
  `DesktopStartupOrchestrator` composes `DesktopInstanceService` and
  `BridgeProcessService` to restore a last-on bridge, so the instance service
  does not call a peer service or duplicate bridge spawn/auth/backoff policy.
- **Risk:** Low-Med. **Size:** S-M.
- **Regression guide:** instance locks are the classic "can't start the app
  anymore" foot-gun. Check: (1) after a GUI **crash** (kill -9), the next launch
  acquires the lock (stale-lock recovery) — this is the single most important
  check; (2) second launch focuses the first even when the first is hidden/
  tray-only; (3) last-on restore respects the auth gate (logged-out boot →
  login-required, not a spawn attempt); (4) persisted state survives an app
  update (storage format/namespace stable).
- **Acceptance:** second launch focuses first; last-on respawns bridge on boot
  through `DesktopStartupOrchestrator`; a crashed GUI does not brick subsequent
  launches; no Layer-3 service depends on a peer Layer-3 service.

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
  or import the auth HTTP client directly). The auth server already exposes
  `DELETE /auth/bridges/:bridgeId` (user token, owner-scoped, 404 when already
  revoked — treat 404 as success, matching the bridge's own unregister
  semantics). This `module_core` addition is a precursor sub-step of this PR.
- **"Invalidate tokens" means LOCAL-ONLY — pin this.** Use
  `AuthSession.logoutCurrentDevice()` (clears local token storage). Do **NOT**
  call `invalidateAllSessions()` / `POST /auth/logout` — that bumps the
  user-wide `tokenVersion` and deletes every device push token, silently logging
  out the user's **phone** and breaking other devices' refresh flows. And never
  `/auth/revoke`, which revokes **all** the user's bridges including a laptop
  CLI bridge. Desktop logout = targeted `deleteBridge(bridgeId)` + local token
  clear, nothing account-wide.
- **Offline logout must always complete.** Every network step in the logout
  flow — the live-helper `unregister-and-exit` wait AND the GUI-side
  `deleteBridge` fallback — is **best-effort with a bounded timeout**:
  failures/timeouts are caught and logged, then the flow proceeds to
  `logoutCurrentDevice()` unconditionally (same best-effort posture as the
  PR 3.11 uninstall unregister). A user with no internet, a dead auth server,
  or a wedged helper can still log out; the orphaned server-side registration
  is removable later from the account UI.
- **Risk:** Med. **Size:** M.
- **Regression guide:** the blast radius is **other devices on the account**.
  Check: (1) after desktop logout, the user's phone is still logged in and
  working, and a laptop CLI bridge (different machine) still refreshes fine; (2)
  the account bridge list no longer shows the desktop bridge; (3) logout with the
  helper live: unregister-and-exit → exit 0 observed before token clear; (4)
  logout with the helper crashed/off: fallback `deleteBridge` uses the
  GUI-persisted `bridgeId`, and a stale id (404) still completes logout; (5)
  mobile build green (`module_core` change is mobile-shared).
- **Acceptance:** logout unregisters the bridge before local token invalidation
  in **both** the live-helper and helper-absent/crashed paths; the GUI calls the
  `module_core` `BridgeRepository.deleteBridge` seam (no direct auth-API/HTTP
  import in app code); logout is device-local (phone/other devices unaffected —
  no `tokenVersion` bump); logout completes **offline** (unreachable auth
  server / timed-out unregister is logged and bypassed — asserted by test); no
  leaked registration in the online paths; mobile build stays green.

## PR 2.14 — Desktop `FailureReporter` impl
- **Goal:** Crash/error reporting for the tray app (decide Crashlytics vs other
  vs no-op).
- **Risk:** Low-Med. **Size:** S-M.
- **Regression guide:** reporting must not become a failure mode itself. Check:
  (1) a crash-looping helper doesn't spam unbounded reports (rate-limit/dedupe);
  (2) reports carry no session/project names or message content (same privacy
  line as the control channel); (3) unconfigured/offline reporter degrades to
  logging, never blocks the UI thread or startup.
- **Acceptance:** errors are reported/recorded per the chosen impl.

## PR 2.15 — E2E integration
- **Goal:** Run GUI+helper together with local fakes: spawn → control handshake →
  token push/pull → helper relay connect/authenticate against a fake relay →
  trigger 86 → respawn → logout → unregister. Use fake auth/token/control/relay
  boundaries; do not depend on external Sesori services.
- **Risk:** Med. **Size:** M.
- **Regression guide:** test-only, but process-spawning tests are CI-flakiness
  magnets. Check: (1) deterministic under `desktop-ci.yml` (generous timeouts,
  no fixed ports, temp dirs per run, always-kill cleanup even on failure); (2)
  the suite doesn't leave stray processes on developer machines after ^C; (3)
  runtime kept short enough to stay a required check.
- **Acceptance:** the full happy path passes as an automated/scripted test using
  local fakes; the helper proves it can authenticate to the fake relay with the
  GUI-supplied token before restart/logout; failures are deterministic in CI.

## PR 2.16 — First-run provisioning progress UI + degraded state
- **Goal:** Render `RuntimeProvisionProgress` (download bar/status) from the
  control channel on first run; show a **degraded** state when `ProvisionFailed`
  (relay/phone still up). Status model in `BridgeStatusTracker` gains
  `provisioning`/`degraded`.
- **Risk:** Med. **Size:** M.
- **Regression guide:** extends the 2.4 tracker model consumed by the cubit,
  tray, and window. Check: (1) existing status states (offline/healthy/
  login-required/crashed) still render correctly after the model change; (2) a
  provision-failure leaves the UI showing degraded-but-running (phone still
  works) — not an error dead-end; (3) progress events with unknown variants
  (forward compat `unknown` fallback) don't break the bar; (4) a restart during
  provisioning recovers cleanly.
- **Acceptance:** first run shows download progress; provision failure shows a
  degraded-but-running state.

---

## MT-3 — Manual checkpoint: full internal MVP on 3 OSes (user-run)

> Run at the end of Phase 2 — this is the "functional internal MVP" gate before
> any packaging work. Use dev builds on real machines (macOS + Windows + one
> Linux, ideally GNOME to exercise the A24 fallback). Per-OS columns can pass on
> different days; check the §9 box when all three pass.

| # | Check | How | Pass looks like |
|---|---|---|---|
| 1 | Fresh-machine first run | wipe Sesori state (or a fresh user); launch; log in; turn on | first-run provisioning progress renders (download → ready); bridge goes healthy |
| 2 | Phone end-to-end | connect the phone | projects/sessions/chat + a question round-trip through the desktop bridge |
| 3 | Degraded provisioning | simulate a failed runtime download (block network to the release host) | degraded-but-running state; relay/phone still connect; retry on restart works |
| 4 | Tray + window | exercise every tray item + window control per OS | on/off/status/live updates; GNOME-no-extension → windowed fallback (A24) |
| 5 | Autostart | enable autostart; reboot | returns tray-only (hidden) with a live tray; bridge respawns if last-on; disable-autostart sticks after another reboot |
| 6 | Single instance | launch a second copy (incl. while hidden) | first instance focused; no second tray icon; after kill -9, next launch still works |
| 7 | Crash handling | kill -9 the helper twice, then let a broken helper crash-loop | backoff respawn; give-up surfaces error + recent log lines; "open logs" shows the log file |
| 8 | GUI crash orphan check | kill -9 the **GUI** | helper self-exits within grace (A9); relaunch restores last-on |
| 9 | Update stop boundary | (pre-Sparkle) invoke the expected-stop path via the fake updater/dev hook | helper stops without respawn thrash; last-on restored after relaunch |
| 10 | Logout matrix | logout with helper live, then again with helper off/crashed | bridge gone from account list in both; **phone stays logged in**; local tokens cleared |
| 11 | Cross-machine takeover (1.14) | keep a bridge running on a second machine; start the desktop bridge | old bridge shows takeover state, no flip-flop war; phone follows the desktop bridge |
| 12 | Sleep/wake | sleep the machine 10+ min with bridge on | after wake: helper reconnects to relay; status recovers; no duplicate helper |
| 13 | Standalone coexistence | run the terminal CLI bridge afterwards | CLI still logged in and runnable (shared state intact per A10) |

- **Aristotle:** n/a (no code). **Findings:** — **Deltas:** —
