# Sesori Desktop App — Master Plan

> Living document. This is the map: architecture, decisions, invariants, risk
> register, and the PR status index. Per-phase detail lives in `phase-N-*.md`.
> Each PR updates its phase doc's **Findings log** and, if needed, the
> **Plan-deltas** and this index. Keep the **Current pointer** below accurate so
> any session can resume cleanly.

## Current pointer

- **Active phase:** Phase 0 (not started)
- **In-flight PR:** none
- **Branch:** `design-discussion-session` (this plan PR) → feature branches per PR thereafter
- **Next action:** land the plan PR, then start PR 0.1 (workspace rename)

---

## 1. Goal

Ship a downloadable desktop app that installs, runs, and controls the existing
`sesori-bridge` from the OS tray/menu-bar and self-starts at boot — replacing
the terminal/npm install for desktop users. The same app eventually bakes in the
accessory UI (projects/sessions/chat). The headless/VM path (standalone CLI +
systemd) is preserved unchanged.

## 2. Architecture

One installable app per OS contains **two binaries** built from the monorepo at
the **same commit/version**:

```
Sesori.app (.dmg) / Sesori installer (.exe) / Sesori.AppImage
├── Binary B — Flutter GUI ("client" app)         ← tray + window + supervisor + control server
└── Binary A — sesori-bridge (pure Dart)           ← spawned & supervised as a child ("helper")
```

- **Binary A** is the existing `sesori-bridge`, in **two run modes** from one
  library: **standalone** (terminal/systemd, unchanged) and **supervised**
  (launched by the GUI; supervised mode is selected by a `--control-url` flag).
- **GUI ↔ helper** talk over a **GUI-hosted loopback WebSocket control channel**.
  The channel carries ONLY: fresh-token requests, token-stream pushes, status
  pushes, runtime-provisioning progress, and prompts (replace-bridge,
  unregister-and-exit). **No project data.**
- **Control-channel secret is NOT passed in argv.** Command-line arguments are
  inspectable by any other local process/user, and this channel issues bearer
  tokens — so a leaked secret = token theft. The per-spawn secret is delivered
  off-argv (inherited pipe/FD or a stdin handshake at spawn); only the
  loopback URL may be a flag. See ADR A8.
- **Project data** flows phone-style over the relay (`relay.sesori.com`). The
  desktop UI (v1.x) is a relay client like the phone, reusing `module_core`
  transport unchanged.
- This mirrors Tailscale (`Tailscale.app` supervises `tailscaled`; the same
  daemon also runs headless on a server).

### Data flow

- **Login:** GUI owns login+refresh via `module_auth` (sole token authority).
  Poll-based OAuth (browser open + server-side session-token poll) — **no
  localhost redirect / deep link**. `openOAuthBrowser` already covers all 3 OSes.
- **Token:** helper never runs OAuth/refresh. It pulls access tokens from the GUI
  over the control channel (and receives pushed updates), implementing the
  bridge's existing `AccessTokenProvider`/`TokenRefresher` seams.
- **Registration:** helper self-registers its `bridgeId` (using the GUI-supplied
  token) and persists it in a helper-owned store (not `token.json`).
- **Runtime provisioning:** on first run the bridge's `ensureRuntime` phase
  downloads/installs OpenCode, emitting `RuntimeProvisionProgress`. In supervised
  mode these events are teed onto the control channel → GUI shows first-run
  progress. `ProvisionFailed` is non-fatal → **degraded** plugin.
- **Restart:** phone-triggered restart makes the supervised bridge `exit(86)`;
  the GUI respawns. Crash (other non-zero) → backoff respawn. Clean stop → exit 0,
  no respawn.
- **Logout:** GUI sends `unregister-and-exit`; the bridge unregisters its
  `bridgeId` using the current token, exits; the GUI then invalidates tokens.

## 3. Decisions (locked)

| # | Decision |
|---|----------|
| 1 | **Hybrid library**: one bridge library → one binary, two run modes (standalone / supervised). |
| 2 | Desktop UI **reuses the relay** like the phone (v1); loopback data path is a later optimization. |
| 3 | GUI **supervises the bridge binary** as a child process. |
| 4 | **GUI is the sole token authority**; helper is token-provided (no helper OAuth/refresh → no rotation race). |
| 5 | Control channel = **GUI-hosted loopback WebSocket** + per-spawn secret. |
| 6 | **Native tray menu + single main window** for v1; control logic in a reusable cubit/service. |
| 7 | GUI **autostarts tray-only** (`--hidden`) and **respawns the bridge if last-on**. |
| 8 | Restart via **exit-code sentinel `86`**; crash→backoff respawn; **self-update off** when bundled; **GUI single-instance**. |
| 9 | **Dev ID/notarized .dmg + signed Windows installer + Linux AppImage**, self-update via **Sparkle/WinSparkle/zsync**, GitHub-fed. |
| 10 | **Separate desktop package + extract a shared UI library.** |
| 11 | Both new packages live in the (renamed) **`client/`** workspace. |
| 12 | **Unified shared version**; desktop bundles the same-commit bridge. |
| 13 | **Fully signed** on all three OSes (procure a Windows code-signing cert). |
| 14 | **Lean v1**: install + control + login + signed + self-update + first-run provisioning UI. Baked-in accessory UI deferred to v1.x. |

## 4. Release-safety invariants (MUST hold at every merged PR)

**Every merged PR must leave `main` able to cut a CLI (bridge) release and a
mobile release.**

1. **Bridge/CLI stays releasable** — all supervised-mode work is **additive and
   gated by `--control-url`**, and **never touches the relay protocol or
   standalone defaults**. Each Phase 1 PR asserts standalone behaviour is
   unchanged.
2. **Mobile stays releasable** — Phase 0 (rename) acceptance includes a **mobile
   release-pipeline dry-run**. After the rename the mobile app lives at
   `client/app`, so every later gate is phrased against the **mobile product**
   (path `client/app`, NOT `mobile/app`); each Phase 4 extraction PR keeps
   `client/app` building, tests green, and a release dry-run passing.
3. **Desktop CI is non-blocking** for CLI/mobile releases until desktop is
   stable. The existing all-or-nothing release `finalize` must **not** gate on
   desktop legs (a desktop build failure can never abort a CLI/mobile release).
   Folding desktop into the release gate is a later, deliberate decision.
4. **Workspace integrity** — after each desktop PR, `dart pub get` +
   `client/app` (the mobile product) build/test stay green (desktop-only deps are platform-scoped).
5. **`make bump-version` stays backward-compatible** — bumps CLI+mobile even
   while desktop is mid-development; before Phase 3, releases ship no desktop
   artifact.

## 5. Coding conventions for new code

- Follow the strict layered architecture (see root + workspace `AGENTS.md`).
- **Error handling (per updated repo rule):** swallow-and-continue must log;
  catch-all should generally log; **do NOT double-log a failure already
  surfaced** (rethrow / typed throw / explicit failure return like
  `ProvisionFailed`); pass the error as the logger argument
  (`Log.w("msg", error, stackTrace)`), never string-interpolated.
- **Naming alignment with `sesori_bridge_foundation`** (landed on main): mirror
  `CommandExecutor`/`HostProcessCommandExecutor`, `PlatformTarget`,
  `SemanticVersion`, `BinaryDownloadClient`, `ChecksumValidator`,
  `ArchiveExtractor` for analogous desktop primitives (separate workspace → mirror
  the pattern, don't import bridge foundation).
- Every PR runs through `aristotle-impl-review` before opening; the first
  implementation plan per phase runs through `aristotle-plan-review`.

## 6. Component design (Aristotle-aligned)

### Bridge side (supervised mode; gated by `--control-url`)

| Component | Layer / dir | Role |
|---|---|---|
| `ControlChannelClient` | Layer 0 `bridge/app/lib/src/.../foundation/` (target layer, not the legacy nested tree) | loopback WS client; connect/reconnect; send/receive |
| Control-protocol Freezed DTOs | `shared/sesori_shared` | pure wire types (incl. provision-progress mirror) |
| `ControlChannelTokenService` | Layer 3 `auth/` | implements `AccessTokenProvider`/`TokenRefresher`; pull + push token stream |
| `BridgeControlMessageDispatcher` | Layer 4 | routes inbound control msgs (token push → token service, restart → handoff, logout → unregister-and-exit) |
| `BridgeIdentityFileApi` (L1) + `BridgeIdentityRepository` (L2) | `api/` + `repositories/` | persist `bridgeId` separately from `token.json` |
| supervised auth bootstrap | composition root | short-circuit `BridgeRuntimeAuthService.ensureAuthenticated` (no stdin); keep an equivalent `logAuthenticatedUser` |
| restart change | `orchestrator`/runner seam | `handleRestartHandoff()` → `exit(86)` instead of `spawnSuccessor()` |

Supervised-vs-standalone is chosen **once at the composition root**
(`bridge_runtime_runner.dart`), which wires either `TokenManager` (+ interactive
auth) or the control-channel service (+ bootstrap). `ControlChannelClient` is
constructed at the root and **injected** into `ControlChannelTokenService` (no
internal `new`).

### Desktop GUI side (`client/desktop`, reusing `module_core`/`module_auth`/`module_prego`/`module_app_ui`)

| Component | Layer | Role |
|---|---|---|
| `ControlChannelServer` | Layer 0 | GUI-hosted loopback WS host + per-spawn secret; inbound-as-stream + `send` (precedent: `DebugServer`) |
| `ControlMessageDispatcher` | Layer 4 | routes inbound: token req → `AuthTokenProvider`; status/progress → `BridgeStatusTracker`; prompts → cubit/UI |
| process API (mirrors `HostProcessCommandExecutor`) | Layer 1 | spawn/kill/monitor a long-lived child |
| `BridgeProcessRepository` | Layer 2 | wraps the process API |
| `BridgeProcessService` | Layer 3 | bridge child lifecycle: spawn (control flags), exit-code state machine (86/0/other + backoff), single supervised-bridge guard |
| `BridgeStatusTracker` | Layer 3 | status (relay/plugin health, provisioning, degraded, active sessions) from control events; stream/snapshot |
| `BridgeControlCubit` | Layer 4 | toggle on/off (→ service), expose status (← tracker) for tray + window |
| `DesktopInstanceService` | Layer 3 | GUI single-instance lock (separate from process supervision) |
| `SystemTray` / `WindowHost` / `LaunchAtLogin` / `AppUpdater` | Layer 0 capability interfaces + desktop impls | wrap `tray_manager` / `window_manager` / `launch_at_startup` / `auto_updater` |
| desktop `SecureStorage` / `UrlLauncher` / `FailureReporter` impls | Layer 0 adapters | platform adapters for the desktop shell |

Auth: `client/desktop` registers `module_auth` via `configureAuthDependencies(getIt)`
and consumes only the exported interfaces (`AuthTokenProvider`/`OAuthFlowProvider`/`AuthSession`) — **no direct `AuthManager` import**.

## 7. Architecture decision records (ADR)

| ADR | Decision | Rationale |
|---|---|---|
| A1 | Out-of-process supervised child (not in-process isolate) | crash isolation; reuse bridge lifecycle; sandbox boundary |
| A2 | macOS **not** sandboxed (Developer ID, not MAS) | the bridge spawns `git`/`opencode`/`ps` |
| A3 | Single token authority (GUI), helper token-provided | eliminates cross-process refresh-rotation race |
| A4 | Control-protocol DTOs in `sesori_shared` | only shared point between bridge + client workspaces; pure data |
| A5 | `ControlChannelServer` name kept (vs Aristotle's `Listener`) | `Listener` implies one-way subscription; this is a duplex socket host; `DebugServer` precedent |
| A6 | `bridgeId` persistence = file API + thin repo (no Dao) | one string; no DB/migration needed |
| A7 | First-run provisioning UI is **v1** | first launch downloads OpenCode; user must see progress |
| A8 | Control-channel secret delivered **off-argv** (inherited FD/pipe or stdin handshake), not `--control-secret` | argv is readable by other local processes/users; this channel issues bearer tokens, so an argv-leaked secret = token theft |
| A9 | Helper exits on **control-channel loss** after a short grace period | if the GUI crashes/force-quits, the OS does not reliably kill the child; the helper must not linger invisibly with a live token |
| A10 | Desktop uninstall touches **only desktop-owned state** | `token.json` + managed runtime live under the shared Sesori data root used by the standalone CLI; deleting them would break/log-out the terminal bridge |

## 8. Open risks & lead-time register

| Item | Status | Owner | Notes |
|---|---|---|---|
| Windows code-signing cert | **OPEN — lead time** | TBD | blocks PR 3.4 (signed Windows); EV clears SmartScreen faster |
| Control-channel secret bootstrap (off-argv) | OPEN | TBD | ADR A8; designed in PR 1.1 / PR 2.5 |
| Orphaned helper on GUI crash | OPEN | TBD | ADR A9; parent-loss policy in PR 1.1 |
| Uninstall vs shared CLI state | OPEN | TBD | ADR A10; scope cleanup in PR 3.11 |
| CI secrets (Dev ID, notarization key, EdDSA appcast, GPG) | OPEN | TBD | PR 3.0b |
| Flutter multi-window viability (v2 popover) | OPEN | TBD | de-risk with a spike before Phase 5 popover |
| macOS login-item arg detection (`--hidden`) | OPEN | TBD | `SMAppService` may need a shim |
| OpenCode presence | **RESOLVED** | — | bridge now auto-provisions via `ensureRuntime`; residual = first-run progress UX + degraded handling (PRs 1.13, 2.16) |
| `bundled bridge` runtime-ownership guard | OPEN | TBD | spike in PR 2.8 (avoid discovering at notarization) |

## 9. PR status index

Legend: ☐ pending · ◐ in-progress · ☑ done. Sizes: **S** ≤150 LOC · **M** 150–350 · **L** (rename only, mechanical).

### Phase 0 — Rename → `phase-0-rename.md`
- ☐ 0.1 `mobile/`→`client/` everywhere (atomic) — **Med-High / L**

### Phase 1 — Bridge supervised mode → `phase-1-bridge-supervised.md`
- ☐ 1.1 `--control-url` + off-argv secret bootstrap + `ControlChannelClient` skeleton — Low-Med / M
- ☐ 1.2 Control-protocol Freezed DTOs (incl. provision-progress mirror) — Low / S-M
- ☐ 1.3 Supervised auth bootstrap (short-circuit `ensureAuthenticated`) — Med / M
- ☐ 1.4 Token provider **pull** over channel (+ timeout/GUI-down) — Med / M
- ☐ 1.5 Token-stream **push** → relay client — Med / S-M
- ☐ 1.6 Supervised registration + `bridgeId` out of `token.json` — Med / M
- ☐ 1.7 Exit-code restart (`86`) + bypass successor-spawn — Med / S-M
- ☐ 1.8 Disable self-update + reconcile when supervised — Low / S
- ☐ 1.9 Re-home prompts/Console → control events — Med / M
- ☐ 1.10 Status push (relay/plugin/active sessions) — Low / S-M
- ☐ 1.11 `unregister-and-exit` control command — Low / S-M
- ☐ 1.12 Single-live precedence under supervised `--hidden` — Med / M
- ☐ 1.13 Tee `RuntimeProvisionProgress` → control channel — Low / S-M

### Phase 2 — Desktop shell + supervisor → `phase-2-desktop-shell.md`
- ☐ 2.1 `client/desktop` package + builds on 3 OSes — Med / M
- ☐ 2.2 Desktop platform adapters (SecureStorage, UrlLauncher) — Low-Med / S-M
- ☐ 2.3 Login reuse (`AuthManager` browser-poll OAuth) — Med / M
- ☐ 2.4 Relay connection + bridge online/offline — Low-Med / S-M
- ☐ 2.5 `ControlChannelServer` + `ControlMessageDispatcher` + token responder — Med / M
- ☐ 2.6 `BridgeProcessService`: spawn/kill/path + control flags — High / M
- ☐ 2.7 Exit-code state machine (86/0/other + backoff) — High / M
- ☐ 2.8 Spike: bundled bridge runtime-ownership + `--hidden` contention — Med / S-M
- ☐ 2.9 Tray menu + reusable control cubit — Med / M
- ☐ 2.10 `WindowHost` single window + v1 window contents — Med / M
- ☐ 2.11 Autostart + `--hidden` boot + macOS login-item detection — Med / M
- ☐ 2.12 GUI single-instance + persist on/off & last-state — Low-Med / S-M
- ☐ 2.13 Logout coordination (GUI: unregister→kill→invalidate) — Med / S-M
- ☐ 2.14 Desktop `FailureReporter` impl — Low-Med / S-M
- ☐ 2.15 E2E integration (spawn→handshake→token→relay→restart→logout) — Med / M
- ☐ 2.16 First-run provisioning progress UI + degraded state — Med / M

### Phase 3 — Packaging / signing / self-update (= v1) → `phase-3-packaging.md`
- ☐ 3.0a macOS no-sandbox + hardened-runtime + spawn-child entitlements — Med / S-M
- ☐ 3.0b CI secrets provisioning (config + docs) — Low / S
- ☐ 3.1 `_reusable-desktop-build.yml` macOS leg (unsigned) — High / M
- ☐ 3.2 macOS codesign + notarize + staple — High / M
- ☐ 3.3 Windows leg: build + bundle + installer (unsigned) — High / M
- ☐ 3.4 Windows code signing (needs cert) — Med / S-M
- ☐ 3.5 Linux AppImage + bundle (+ optional GPG) — Med-High / M
- ☐ 3.6 macOS self-update (Sparkle) + EdDSA + appcast — High / M
- ☐ 3.7 Windows self-update (WinSparkle) + appcast — High / M
- ☐ 3.8 Linux self-update (zsync/AppImageUpdate) — Med-High / M
- ☐ 3.9 Failed-update/rollback handling + update UX — Med / M
- ☐ 3.10 Release-pipeline integration (non-blocking) + `make bump-version` + changelog — Med / M
- ☐ 3.11 Uninstall + login-item/token cleanup — Low-Med / S-M

### Phase 4 — Accessory UI (v1.x) → `phase-4-accessory-ui.md`
- ☐ 4.1 Create `client/module_app_ui` + move shared widgets/extensions/l10n — Med / M
- ☐ 4.2 Move voice capture UI — Med / M
- ☐ 4.3 Move login/splash — Med / M
- ☐ 4.4 Move project_list + session_list — Med / M
- ☐ 4.5 Move session_detail + session_diffs + new_session (split if needed) — Med / M
- ☐ 4.6 Move settings — Low-Med / S-M
- ☐ 4.7 Desktop router composition + wire accessory UI into window — Med / M

### Phase 5 — Polish (v2) → `phase-5-polish.md`
- ☐ 5.1 Multi-window spike (throwaway) — Med / S-M
- ☐ 5.2 Frameless popover window (sliced during planning) — Med / M+
- ☐ 5.3 Richer settings — Low-Med / M

> Note: OpenCode onboarding/detection was REMOVED from Phase 5 — the bridge now
> auto-provisions OpenCode at startup (main #322).
