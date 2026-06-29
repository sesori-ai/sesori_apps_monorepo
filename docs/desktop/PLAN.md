# Sesori Desktop App — Master Plan

> Living document. This is the map: architecture, decisions, invariants, risk
> register, and the PR status index. Per-phase detail lives in `phase-N-*.md`.
> Each PR updates its phase doc's **Findings log** and, if needed, the
> **Plan-deltas** and this index. Keep the **Current pointer** below accurate so
> any session can resume cleanly.

## Current pointer

- **Last completed phase:** Phase 1 — PR 1.2 Control-protocol Freezed DTOs in `sesori_shared` (`ControlMessage` + `ControlProvisionProgress` mirror)
- **Branch:** one feature branch per PR, cut from `main`

> **Advance this pointer to the PR you just raised.** There is no separate
> "in-flight" field: when you open a PR, set **Last completed phase** above to
> that PR and mark its §9 row ☑. PRs squash-merge one at a time, so the pointer
> (and the §9 index) read true the moment that PR merges. Do this for every PR
> as you progress.
>
> **How to resume (derive the next action — do NOT ask first).** When told to
> "continue with the next phase/PR", resolve it deterministically:
> 1. The next action is the **first ☐ in the PR status index (§9)**, read
>    top-to-bottom. Phases and the PRs within them are strictly ordered and are
>    completed in order (a later phase depends on earlier phases existing).
> 2. **Read the prior Findings logs / Plan-deltas first** — this file plus the
>    relevant `phase-N-*.md` — an earlier PR may have recorded a decision, delta,
>    naming choice, or gotcha that affects the next PR.
> 3. **The session worktree/branch name is NOT authoritative** and may not match
>    the plan — e.g. a branch named `…-phase-2` while the first ☐ is still in
>    Phase 1. The plan always wins; never infer the phase/PR from the branch name.
> 4. **Default scope = one PR per session** (matches "one feature branch per
>    PR"). Implement the single next PR, run both Aristotle gates (§5), open it,
>    then stop unless the user says otherwise.
>
> **Keep the plan true.** If a PR reveals that an assumption here was wrong — a
> locked decision (§3), release-safety invariant (§4), component design (§6),
> or ADR (§7) no longer holds — fix it in the **same PR**: record it in the phase
> doc's **Plan-deltas** and amend the affected section above. A stale plan is
> worse than none.
>
> **Track every deferral in the plan — always.** Whenever a PR defers work to a
> later stage (a known gap, a follow-up, a reviewer point answered with "PR X
> handles this"), record it in the **same PR** in BOTH: (a) the owning later
> PR's **Acceptance** in its phase doc, and (b) the §8 risk register. A deferral
> that lives only in a PR reply, commit message, or chat is **not tracked** and
> will be lost — those are not the plan.

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
  unregister-and-exit). **No project data.** Status summaries are health/counts
  only; session/project names and message content stay off this channel.
- **Control-channel secret is NOT passed in argv.** Command-line arguments are
  inspectable by any other local process/user, and this channel issues bearer
  tokens — so a leaked secret = token theft. The per-spawn secret is delivered
  off-argv (inherited pipe/FD or a stdin handshake at spawn); only the
  loopback URL may be a flag. See ADR A8.
- **Project data** flows phone-style over the relay (`relay.sesori.com`). The
  desktop accessory UI (v1.x) is a relay client like the phone, reusing
  `module_core` transport unchanged. Lean v1 control/status uses the control
  channel only and does not resolve `ConnectionService`.
- This mirrors Tailscale (`Tailscale.app` supervises `tailscaled`; the same
  daemon also runs headless on a server).

### Client workspace shape

Desktop-specific process supervision does **not** live in the Flutter shell and
does **not** live in shared `module_core`. The client workspace graph is:

```
client/app ───────────────→ module_app_ui ─┐
     │                                      │
     └──────────────────────────────────────┴→ module_core → module_auth → sesori_shared
     │
     └→ module_prego

client/desktop ───────────→ module_app_ui ─┐
     │                                      │
     ├──────────────────────────────────────┴→ module_core → module_auth → sesori_shared
     │
     └→ module_desktop_core ─────────────────→ module_core
     │                         │
     │                         └→ sesori_shared
     └→ module_prego
```

- `client/desktop` is a Flutter product shell: DI, presentation, routing/window
  composition, and concrete platform adapters only.
- `client/module_desktop_core` is a pure Dart desktop business module: bridge
  process supervision, control-channel orchestration, desktop repositories,
  trackers, services, and cubits.
- `module_core` owns shared relay/auth seams and stays unaware of desktop-only
  tray/process/bundled-helper concerns.
- `module_app_ui` is introduced in Phase 4. It may depend on `module_core`,
  `module_prego`, and `sesori_shared`, but it must never import `client/app`,
  `client/desktop`, or `module_desktop_core`. Product-specific behavior enters
  through injected callbacks/strategies composed by the product shell.
- Product shells may import `module_prego` directly for shell-owned
  presentation. `module_desktop_core` may import `sesori_shared` directly for
  control-protocol DTOs.

### Data flow

- **Login:** GUI owns login+refresh via `module_auth` (sole token authority).
  Poll-based OAuth (browser open + server-side session-token poll) — **no
  localhost redirect / deep link**. The browser is opened through a **desktop
  `UrlLauncher` adapter** (the bridge's `openOAuthBrowser` lives in the bridge
  workspace and must NOT be imported by `client/desktop`).
- **Token:** helper never runs OAuth/refresh. It pulls access tokens from the GUI
  over the control channel (and receives pushed updates), implementing the
  bridge's existing `AccessTokenProvider`/`TokenRefresher` seams. If the GUI is
  logged out or cannot supply a token, the supervised path surfaces an
  auth-required state/prompt and avoids crash-loop respawn.
- **Registration:** helper self-registers its `bridgeId` (using the GUI-supplied
  token) and persists it in a helper-owned storage file (not `token.json`).
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
| 2 | Desktop accessory UI **reuses the relay** like the phone (v1.x); lean v1 control/status uses the control channel only; loopback project-data path is a later optimization. |
| 3 | GUI **supervises the bridge binary** as a child process. |
| 4 | **GUI is the sole token authority**; helper is token-provided (no helper OAuth/refresh → no rotation race). |
| 5 | Control channel = **GUI-hosted loopback WebSocket** + per-spawn secret. |
| 6 | **Native tray menu + single main window** for v1; control logic in a reusable cubit/service. |
| 7 | GUI **autostarts tray-only** (`--hidden`) and **respawns the bridge if last-on**. |
| 8 | Restart via **exit-code sentinel `86`**; crash→backoff respawn; **self-update off** when bundled; **GUI single-instance**. |
| 9 | **Dev ID/notarized .dmg + signed Windows installer + Linux AppImage**, self-update via **Sparkle/WinSparkle/zsync**, GitHub-fed. |
| 10 | **Separate desktop shell, desktop core module, and shared UI library.** |
| 11 | New client packages live in the (renamed) **`client/`** workspace. |
| 12 | **Unified shared version**; desktop bundles the same-commit bridge. |
| 13 | **Fully signed** on all three OSes (procure a Windows code-signing cert). |
| 14 | **Lean v1**: install + control + login + signed + self-update + first-run provisioning UI. Baked-in accessory UI deferred to v1.x. |
| 15 | Desktop business logic lives in **`client/module_desktop_core`**; `client/desktop` is a Flutter shell only and `module_core` remains desktop-process-free. |

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
   `client/app` (the mobile product) build/test stay green (desktop-only deps are platform-scoped). Once `client/desktop` / `module_desktop_core` exist, each desktop PR also runs the relevant desktop analyze/test/build gates for the packages it touches.
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
- **Every implementation PR** runs through `aristotle-plan-review` before coding
  **and** `aristotle-impl-review` before opening — the architecture gate is
  per-PR, never per-phase (a later PR in a phase must not bypass it).

## 6. Component design (Aristotle-aligned)

### Bridge side (supervised mode; gated by `--control-url`)

| Component | Layer / dir | Role |
|---|---|---|
| `ControlChannelClient` | Layer 0 `bridge/app/lib/src/.../foundation/` (target layer, not the legacy nested tree) | loopback WS client; connect/reconnect; send/receive |
| `ControlSecretApi` | Layer 1 `api/` | reads the per-spawn secret off-argv (first stdin line); sent as the control-channel WS `Authorization: Bearer` upgrade header (PR 1.1) |
| `ControlChannelLossListener` | Layer 4 `control/` | ADR A9 grace-period process exit on sustained control-channel loss; injected `exitProcess` (PR 1.1). `control/` is part of the core layered bridge app, not a self-contained subsystem. |
| Control-protocol Freezed DTOs | `shared/sesori_shared` | pure wire types (incl. provision-progress mirror) |
| `ControlChannelTokenService` | Layer 3 `services/` | implements `auth/` `AccessTokenProvider`/`TokenRefresher`; pull + push token stream over injected `ControlChannelClient`. Kept out of the self-contained `auth/` subsystem so `auth/` does not import core `foundation/`. |
| `BridgeControlMessageDispatcher` | Layer 4 | routes inbound control msgs (token push → token service, restart → handoff, logout → unregister-and-exit) |
| `BridgeIdentityStorage` (file API + reader) | **inside the `auth/` subsystem** | persist `bridgeId` separately from `token.json`; kept within `auth/` (which is self-contained, outside the core layer hierarchy) so auth code doesn't depend back on top-level `repositories/`. Injected from the composition root. |
| supervised auth bootstrap | composition root | short-circuit `BridgeRuntimeAuthService.ensureAuthenticated` (no stdin); keep an equivalent `logAuthenticatedUser` |
| restart change | `orchestrator`/runner seam | `handleRestartHandoff()` → `exit(86)` instead of `spawnSuccessor()` |

Supervised-vs-standalone is chosen **once at the composition root**
(`bridge_runtime_runner.dart`), which wires either `TokenManager` (+ interactive
auth) or the control-channel service (+ bootstrap). `ControlChannelClient` is
constructed at the root and **injected** into `ControlChannelTokenService` (no
internal `new`).

### Desktop GUI side (`client/desktop` shell + `module_desktop_core` business module)

| Component | Layer | Role |
|---|---|---|
| `ControlChannelServer` | `module_desktop_core` Layer 0 | GUI-hosted loopback WS host + per-spawn secret; inbound-as-stream + `send`; loopback-only, bad secrets rejected, one authenticated helper per spawn |
| process API (mirrors `HostProcessCommandExecutor`) | `module_desktop_core` Layer 1 | spawn/kill/monitor a long-lived child |
| `BridgeProcessRepository` | `module_desktop_core` Layer 2 | wraps the process API and owns the expected-exit marker / atomic expected-stop operation used by process and update services |
| `BridgeStatusTracker` / `BridgePromptTracker` | `module_desktop_core` Layer 2 | hold status/pending-prompt state as stream/snapshot; written by the dispatcher, read by the cubit/service |
| `BridgeProcessService` | `module_desktop_core` Layer 3 | bridge child lifecycle: authenticated spawn gating, repository calls, exit-code/backoff decisions, and respawn/stop side effects. It reads expected-exit state from `BridgeProcessRepository`; it does not own that marker. |
| `DesktopInstanceRepository` | `module_desktop_core` Layer 2 | wraps the single-instance lock API/storage boundary |
| `DesktopInstanceService` | `module_desktop_core` Layer 3 | GUI single-instance lock orchestration, persisted on/off + last-state, focus-first behavior; it does not start the bridge directly |
| `DesktopStartupOrchestrator` | `module_desktop_core` Layer 4 | composes `DesktopInstanceService` + `BridgeProcessService` to restore a last-on bridge at boot without same-layer service dependencies |
| `AppUpdateApi` | `module_desktop_core` Layer 1 | dumb staging/apply boundary over the Layer-0 `AppUpdater` adapter |
| `AppUpdateRepository` | `module_desktop_core` Layer 2 | wraps `AppUpdateApi` staging/apply operations so services do not own OS-update transport details |
| `DesktopUpdateService` | `module_desktop_core` Layer 3 | update-apply policy using lower-layer repositories/APIs only: perform the repository-owned expected-stop operation, stage/apply through `AppUpdateRepository`, relaunch, and restore last-on through desktop-instance repository semantics |
| `ControlMessageDispatcher` | `module_desktop_core` Layer 4 | subscribes to `ControlChannelServer`'s inbound stream and writes **down** into Layer-2 trackers / token seam: token req → `AuthTokenProvider`; status/progress → `BridgeStatusTracker`; prompts → `BridgePromptTracker`. It depends only downward; it does NOT touch the cubit/UI. |
| `BridgeControlCubit` | `module_desktop_core` Layer 4 | toggle on/off (→ service), expose status + prompts (← trackers) for tray + window |
| `SystemTray` / `WindowHost` / `LaunchAtLogin` / `AppUpdater` | `module_desktop_core` Layer 0 capability interfaces; `client/desktop` impls | wrap `tray_manager` / `window_manager` / `launch_at_startup` / `auto_updater`; adapters stay dumb |
| desktop `SecureStorage` / `UrlLauncher` / `FailureReporter` impls | `client/desktop` Layer 0 adapters | platform adapters for `module_core` seams |

Auth: `client/desktop` registers `module_auth` via `configureAuthDependencies(getIt)`
and wires `configureCoreDependencies(getIt)` before
`configureDesktopCoreDependencies(getIt)`. Outside that DI call, the shell must
not import `module_auth` types directly; `module_desktop_core` consumes auth
seams through `module_core` interfaces, not `AuthManager` internals.

## 7. Architecture decision records (ADR)

| ADR | Decision | Rationale |
|---|---|---|
| A1 | Out-of-process supervised child (not in-process isolate) | crash isolation; reuse bridge lifecycle; sandbox boundary |
| A2 | macOS **not** sandboxed (Developer ID, not MAS) | the bridge spawns `git`/`opencode`/`ps` |
| A3 | Single token authority (GUI), helper token-provided | eliminates cross-process refresh-rotation race |
| A4 | Control-protocol DTOs in `sesori_shared` | only shared point between bridge + client workspaces; pure data |
| A5 | `ControlChannelServer` name kept (vs Aristotle's `Listener`) | `Listener` implies one-way subscription; this is a duplex socket host; `Server` is now an explicit transport-host suffix and `DebugServer` is the precedent |
| A6 | `bridgeId` persistence = a small file-backed storage **inside `auth/`** (no Dao) | one string; no DB/migration; keeps it within the self-contained auth subsystem so auth code doesn't depend on top-level `repositories/` |
| A7 | First-run provisioning UI is **v1** | first launch downloads OpenCode; user must see progress |
| A8 | Control-channel secret delivered **off-argv** (inherited FD/pipe or stdin handshake), not `--control-secret` | argv is readable by other local processes/users; this channel issues bearer tokens, so an argv-leaked secret = token theft |
| A9 | Helper exits on **control-channel loss** after a short grace period | if the GUI crashes/force-quits, the OS does not reliably kill the child; the helper must not linger invisibly with a live token |
| A10 | Desktop uninstall touches **only desktop-owned state** | `token.json` + managed runtime live under the shared Sesori data root used by the standalone CLI; deleting them would break/log-out the terminal bridge |
| A11 | GUI login opens the browser via a **desktop `UrlLauncher` adapter** | the bridge's `openOAuthBrowser` is bridge-workspace-only; `client/desktop` must not import bridge internals |
| A12 | Token push must drive **RelayClient re-auth/reconnect**, not just emit on a stream | `RelayClient` reads the token once in `connect()`; an open socket stays on the old JWT until reconnect |
| A13 | GUI keeps a **readable copy of `bridgeId`** + a GUI-side unregister fallback | logout can happen with the helper off/crashed/unreachable; otherwise the registration leaks |
| A14 | `ControlMessageDispatcher` is **Layer 4** and depends only **downward** on Layer-2 trackers / token seams (`BridgeStatusTracker`, `BridgePromptTracker`, `AuthTokenProvider`); the cubit reads those same trackers | avoids both a same-level dispatcher↔tracker or dispatcher↔cubit dependency and an upward dependency — the dispatcher writes trackers, the cubit reads trackers, so all edges point downward |
| A15 | Module-core platform prerequisites are registered **before resolving the module_core services that need them** | `LoginCubit` needs `LifecycleSource`; `ConnectionService` later needs `RelayCryptoService`/`FailureReporter`. Lean v1 does not resolve `ConnectionService`; Phase 4 must register relay prerequisites before accessory UI uses it. |
| A16 | `SystemTray` stays a **dumb Layer-0 adapter**; the Layer-4 cubit drives it and consumes the service/tracker | a platform adapter must not depend on process lifecycle or status state from higher layers — that reverses dependency direction |
| A17 | The helper emits a **`registered` control event with `bridgeId`**; the GUI persists it on receipt | gives the GUI a readable id for the offline-unregister fallback (A13) before any crash/stop |
| A18 | `DesktopUpdateService` **stops the helper (repository-owned expected-exit, suppress respawn) before staging/apply**, restores last-on after relaunch | a running child can't be replaced (Windows) and respawn-during-apply risks mixed-version/failed updates; `AppUpdater` stays a dumb Layer-0 adapter behind a Layer-1 `AppUpdateApi` and Layer-2 `AppUpdateRepository`, and the service avoids same-level service dependencies |
| A19 | Desktop offline/onboarding uses a **desktop seam** that starts the supervised helper, not mobile `reconnectBridge()`/`BridgeInstall` CLI prompts | on desktop the app *is* the bridge; the shared mobile actions don't start the helper |
| A20 | Desktop business logic lives in **`module_desktop_core`** | keeps `client/desktop` a Flutter shell and prevents `module_core` from inheriting tray/process/bundled-helper concerns |
| A21 | Desktop relay-client connection is deferred until accessory UI | lean v1 needs login/control/status only; resolving relay transport early adds platform prerequisites and test surface without user-visible v1 value |

## 8. Open risks & lead-time register

| Item | Status | Owner | Notes |
|---|---|---|---|
| Windows code-signing cert | **OPEN — lead time** | TBD | blocks PR 3.4 (signed Windows); EV clears SmartScreen faster |
| Control-channel secret bootstrap (off-argv) | OPEN | TBD | ADR A8; designed in PR 1.1 / PR 2.6 |
| Orphaned helper on GUI crash | OPEN | TBD | ADR A9; parent-loss policy in PR 1.1 |
| Supervised restart replays `--control-url` (no stdin secret) | OPEN — until PR 1.7 | TBD | PR 1.1 gap; PR 1.7 makes supervised restart `exit(86)` not `spawnSuccessor()`. Unreachable pre-GUI; successor fails closed (`ControlSecretApi` timeout → exit 1) |
| Uninstall vs shared CLI state | OPEN | TBD | ADR A10; scope cleanup in PR 3.11 |
| RelayClient live re-auth on token push | RESOLVED in PR 1.5 | TBD | ADR A12; Orchestrator subscribes to `AccessTokenProvider.tokenStream` and re-auths only when the token differs from `RelayClient.lastAuthedToken` (funnels into the existing reconnect path). Service cache writes are ordered by issue-sequence (newest-issued wins, push outranks in-flight pulls); a signed-out `token_response` invalidates the cache and defers reconnect, and a refresh failure with no safe cached token also defers. Connection-level tests added. |
| Standalone `TokenManager` keeps in-memory token after logout deletes the store | OPEN | TBD | Pre-existing (predates PR 1.5): `TokenManager.accessToken` returns its seeded in-memory token even after the on-disk store is deleted, so a standalone relay reconnect can re-auth with it. Supervised mode is already safe (control-channel service invalidates on sign-out). Needs a storage-aware validity / logout-invalidation path inside `TokenManager` / the `auth/` subsystem. |
| Desktop relay client / `ConnectionService` deferral | OPEN — deferred to Phase 4 | TBD | ADR A21; lean v1 control/status must not resolve relay transport. PR 4.7 owns desktop relay prerequisites and accessory-UI connection acceptance. |
| `core/widgets` not pure leaf UI | OPEN | TBD | `connection_overlay.dart` imports app DI/routing/go_router; PR 4.1 must refactor + declare deps first |
| CI secrets (Dev ID, notarization key, EdDSA appcast, GPG) | OPEN | TBD | PR 3.0b |
| Flutter multi-window viability (v2 popover) | OPEN | TBD | de-risk with a spike before Phase 5 popover |
| macOS login-item arg detection (`--hidden`) | OPEN | TBD | `SMAppService` may need a shim |
| OpenCode presence | **RESOLVED** | — | bridge now auto-provisions via `ensureRuntime`; residual = first-run progress UX + degraded handling (PRs 1.13, 2.16) |
| `bundled bridge` runtime-ownership guard | OPEN | TBD | spike in PR 2.8 (avoid discovering at notarization) |

## 9. PR status index

Legend: ☐ pending · ◐ in-progress · ☑ done. Sizes: **S** ≤150 LOC · **M** 150–350 · **L** (rename only, mechanical).

### Phase 0 — Rename → `phase-0-rename.md`
- ☑ 0.1 `mobile/`→`client/` everywhere (atomic) — **Med-High / L**

### Phase 1 — Bridge supervised mode → `phase-1-bridge-supervised.md`
- ☑ 1.1 `--control-url` + off-argv secret bootstrap + `ControlChannelClient` skeleton — Low-Med / M
- ☑ 1.2 Control-protocol Freezed DTOs (incl. provision-progress mirror) — Low / S-M
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
- ☐ 2.1 `client/module_desktop_core` + `client/desktop` packages + builds on 3 OSes — Med / M
- ☐ 2.2 Desktop platform adapters (module_core + module_desktop_core prerequisites) — Low-Med / S-M
- ☐ 2.3 Login reuse (`AuthManager` browser-poll OAuth) — Med / M
- ☐ 2.4 Control status/prompt trackers baseline (no relay client yet) — Low-Med / S-M
- ☐ 2.5a Re-export `AuthTokenProvider` from `module_core` (seam) — Low / S
- ☐ 2.5 `ControlChannelServer` + `ControlMessageDispatcher` + token responder — Med / M
- ☐ 2.6 `BridgeProcessService`: spawn/kill/path + expected-stop boundary — High / M
- ☐ 2.7 Exit-code state machine (86/0/other + backoff) — High / M
- ☐ 2.8 Spike: bundled bridge runtime-ownership + `--hidden` contention — Med / S-M
- ☐ 2.9 Tray menu + reusable control cubit — Med / M
- ☐ 2.10 `WindowHost` single window + v1 window contents — Med / M
- ☐ 2.11 Autostart + `--hidden` boot + macOS login-item detection — Med / M
- ☐ 2.12 GUI single-instance + persist on/off & last-state — Low-Med / S-M
- ☐ 2.13 Logout coordination (GUI: unregister→kill→invalidate) — Med / S-M
- ☐ 2.14 Desktop `FailureReporter` impl — Low-Med / S-M
- ☐ 2.15 E2E integration (spawn→handshake→token→helper relay auth→restart→logout; local fakes) — Med / M
- ☐ 2.16 First-run provisioning progress UI + degraded state — Med / M

### Phase 3 — Packaging / signing / self-update (= v1) → `phase-3-packaging.md`
- ☐ 3.0a macOS no-sandbox + hardened-runtime + spawn-child entitlements — Med / S-M
- ☐ 3.0b CI secrets provisioning (config + docs) — Low / S
- ☐ 3.1 `_reusable-desktop-build.yml` macOS leg (unsigned) — High / M
- ☐ 3.2 macOS codesign + notarize + staple — High / M
- ☐ 3.3 Windows leg: build + bundle + installer (unsigned) — High / M
- ☐ 3.4 Windows code signing (needs cert) — Med / S-M
- ☐ 3.5 Linux AppImage + bundle + **mandatory** GPG signing — Med-High / M
- ☐ 3.6 Update-apply policy (stop helper first) + rollback + update UX — Med / M
- ☐ 3.7 macOS self-update (Sparkle) + EdDSA + appcast — High / M
- ☐ 3.8 Windows self-update (WinSparkle) + appcast — High / M
- ☐ 3.9 Linux self-update (zsync/AppImageUpdate) — Med-High / M
- ☐ 3.10 Release-pipeline integration (non-blocking) + `make bump-version` + changelog — Med / M
- ☐ 3.11 Uninstall + login-item/token cleanup — Low-Med / S-M

### Phase 4 — Accessory UI (v1.x) → `phase-4-accessory-ui.md`
- ☐ 4.1 Create `client/module_app_ui` + move shared widgets/extensions/l10n — Med / M
- ☐ 4.2 Voice: move only real UI; keep services behind module_core seams — Med / M
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
