# Sesori Desktop App — Master Plan

> Living document. This is the map: architecture, decisions, invariants, risk
> register, and the PR status index. Per-phase detail lives in `phase-N-*.md`.
> Each PR updates its phase doc's **Findings log** and, if needed, the
> **Plan-deltas** and this index. Keep the **Current pointer** below accurate so
> any session can resume cleanly.

## Current pointer

- **Last completed phase:** Phase 1 — PR 1.16 Address MT-1 supervised findings — PR raised as #421 on branch `test-manual-phase-1` (PR 1.15 merged as #390)
- **Next up:** Phase 1 — MT-1 manual checkpoint: bridge supervised mode end-to-end (user-run; see phase doc). This is the last ☐ before Phase 2 and is **user-run** — per resume rule 5, present its checklist and let the user run it; do not implement anything.
- **Branch:** one feature branch per PR, cut from `main`

> **Tracking lives in four places that MUST move together in the same PR.**
> When you open a PR, update ALL of these in that PR's own diff — never in a
> later one, never only in chat/commit message:
> 1. **Current pointer** (above): set **Last completed phase** to the PR you just
>    raised and **Next up** to the following ☐.
> 2. **§9 PR status index**: flip that PR's row ☐ → ☑.
> 3. **Phase doc Aristotle line**: set `impl ☑` for that PR (with the merge ref,
>    e.g. `impl ☑ (merged #352)` once known — a raised-but-unmerged PR may cite
>    the PR number or be filled in on the reconciling pass).
> 4. **Phase doc Findings log / Plan-deltas**: record what shipped and any deltas.
>
> These are not redundant — a reader may consult any one of them first, so if one
> lags they disagree and the plan lies. Partial updates (e.g. Findings written
> but the §9 checkbox and pointer left stale) are exactly how this plan drifted
> before; treat "all four or none" as the rule. **This is part of every PR's DoD**
> (the per-PR template in each phase doc lists it) — not optional bookkeeping: PRs
> 1.3–1.5 shipped without advancing the pointer/index, which broke the resume rule
> below until a plan audit caught it.
>
> **Git history is the ground truth for reconciliation.** If the four surfaces
> ever disagree, the merged PR log wins — reconcile the docs to it, do NOT infer
> progress from the docs alone. `git log --oneline origin/main` shows merged PRs
> with their `(#NNN)` and `(Phase N, PR X.Y)` markers; a PR present there is
> ☑ regardless of what a checkbox says. Before starting work, do this
> reconciliation pass and fix any drift as the first commit.
>
> **How to resume (derive the next action — do NOT ask first).** When told to
> "continue with the next phase/PR", resolve it deterministically:
> 1. The next action is the **first ☐ in the PR status index (§9) whose
>    prerequisites are not blocked**, read top-to-bottom — but only **after** the
>    git-reconciliation pass above, since a ☐ that is actually merged on `main` is
>    done and must be flipped first. Phases and the PRs within them are strictly
>    ordered and are completed in order (a later phase depends on earlier phases
>    existing). A row marked ◐ for an external dependency (e.g. the Windows cert
>    on 3.4) **implicitly blocks every row that depends on it** — skip the blocked
>    row AND its dependents, per that phase's §9 section note (Phase 3's chain-skip
>    rule names the dependent rows), and take the next ☐ outside the blocked set.
>    Never start a row whose dependency is ◐.
> 2. **Read the prior Findings logs / Plan-deltas first** — this file plus the
>    relevant `phase-N-*.md` — an earlier PR may have recorded a decision, delta,
>    naming choice, or gotcha that affects the next PR.
> 3. **The session worktree/branch name is NOT authoritative** and may not match
>    the plan — e.g. a branch named `…-phase-2` while the first ☐ is still in
>    Phase 1. The plan always wins; never infer the phase/PR from the branch name.
> 4. **Default scope = one PR per session** (matches "one feature branch per
>    PR"). Implement the single next PR, run both Aristotle gates (§5), open it,
>    then stop unless the user says otherwise.
> 5. **MT rows are user-run manual checkpoints, not PRs.** When the first ☐ is an
>    `MT-N` row, do not implement anything: present that checkpoint's checklist
>    (in the phase doc) to the user and ask them to run it. Only the user checks
>    an MT box. If the user explicitly says to continue while an MT stays open,
>    later PRs may proceed — but never silently skip past an MT row, and an open
>    MT must be resolved before its phase is called done.
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

**v1 non-goal (explicit):** the supervised bridge runs with **default
configuration** — default relay, default plugin selection, default ports/log
level. Custom bridge flags (`--relay`, plugin choice, `--opencode-port`, …) stay
CLI-only until Phase 5.3 (richer settings). Power users who need custom config
keep the terminal path in v1; that is a decision, not an oversight.

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
  The channel carries ONLY: fresh-token requests/responses, token pushes, status
  pushes, runtime-provisioning progress, prompts (replace-bridge, login-needed),
  the `registered` event (bridgeId, ADR A13/A17), the intentional-restart
  heads-up, and the `unregister-and-exit` command. **No project data.** Status
  summaries are health/counts only; session/project names and message content
  stay off this channel.
- **Control-channel secret is NOT passed in argv.** Command-line arguments are
  inspectable by any other local process/user, and this channel issues bearer
  tokens — so a leaked secret = token theft. The per-spawn secret is delivered
  off-argv (inherited pipe/FD or a stdin handshake at spawn); only the
  loopback URL may be a flag. See ADR A8.
- **Project data** flows phone-style over the relay (`relay.sesori.com`). The
  desktop accessory UI (v1.x) is a relay client like the phone, reusing
  `module_core` transport unchanged. Lean v1 control/status uses the control
  channel only and does not resolve `ConnectionService`. Two consequences are
  accepted for v1.x: the desktop UI needs internet to reach the bridge running
  on the **same machine**, and each desktop client adds relay traffic like
  another phone. The loopback project-data path remains a later optimization
  (Decision #2) — nothing in this plan forecloses it.
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
   unchanged. **Single tracked exception (ADR A22):** PR 1.14 adds one additive
   relay close code (`4007 bridgeReplaced`) and deliberately changes the
   replaced-close reconnect policy; the `sesori_relay_server` change is a
   tracked prerequisite **deployed to production before** the bridge half
   merges, and the bridge keeps a rollout fallback so an older relay never
   breaks it.
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
- **Every pending PR carries a Regression guide** (see the per-PR template in the
  phase docs): the blast radius of the change — which existing behaviours could
  break and the quick checks that prove they didn't. Write it at planning time,
  re-verify it before opening the PR, and extend it when implementation touches
  more than planned.
- **Every PR's DoD includes advancing the plan state**: the §9 row flipped to ☑
  and the Current pointer moved. A PR that ships without this breaks the resume
  rule for the next session.

## 6. Component design (Aristotle-aligned)

### Bridge side (supervised mode; gated by `--control-url`)

| Component | Layer / dir | Role |
|---|---|---|
| `ControlChannelClient` | Layer 0 `bridge/app/lib/src/.../foundation/` (target layer, not the legacy nested tree) | loopback WS client; connect/reconnect; send/receive |
| `ControlSecretApi` | Layer 1 `api/` | reads the per-spawn secret off-argv (first stdin line); sent as the control-channel WS `Authorization: Bearer` upgrade header (PR 1.1) |
| `ControlChannelLossListener` | Layer 4 `control/` | ADR A9 grace-period process exit on sustained control-channel loss; injected `exitProcess` (PR 1.1). `control/` is part of the core layered bridge app, not a self-contained subsystem. |
| Control-protocol Freezed DTOs | `shared/sesori_shared` | pure wire types (incl. provision-progress mirror) |
| `ControlChannelTokenService` | Layer 3 `services/` | implements `auth/` `AccessTokenProvider`/`TokenRefresher`; pull + push token stream over injected `ControlChannelClient`. Kept out of the self-contained `auth/` subsystem so `auth/` does not import core `foundation/`. PR 1.9 re-homes its **inbound** subscription behind `BridgeControlMessageDispatcher` (typed delegate calls); request-correlation state and the `token_request` send path stay inside the service. |
| `BridgeControlMessageDispatcher` | Layer 4 `control/` | owns the **single** inbound subscription + decode of GUI→helper control messages (created in PR 1.9). Routes: `token_response`/`token_update` → token-service delegate, `prompt_response` → prompt-service delegate, `unregister_and_exit` → unregister flow (PR 1.11). `restart` is **helper→GUI only** and is never an inbound command — the GUI restarts the helper by kill+respawn, not by message. |
| `ControlPromptService` | Layer 3 `services/` | supervised-mode user prompts over the injected `ControlChannelClient` (same blessed seam as the token service): owns prompt-class correlation state + ALL prompt-class outbound sends (`prompt_request`); implements the `server/foundation/` `BridgeReplacePrompt` interface so `BridgeInstanceService` asks the GUI instead of a terminal; `announceLoginNeeded()` is the best-effort advisory before the exit-87 sentinel (ADR A23). Unanswerable asks (channel down / timeout / teardown) degrade to `nonInteractive`. |
| `ControlUnregisterService` | Layer 3 `services/` | supervised logout `unregister_and_exit` handler (created in PR 1.11): the dispatcher's third typed delegate. Owns the logout ordering boundary — unregisters the `bridgeId` via the injected `BridgeRegistrationService`, then runs the injected `terminate` (composition-root-wired to the graceful `_shutdownThenExit(code: 0)`). Still terminates if unregister throws (logged) so a stuck bridge can't hang the GUI's logout; the GUI's offline-unregister fallback (ADR A13) cleans up any leak. |
| `BridgeReplacePrompt` | interface in `server/foundation/` | the replace-bridge ask contract with two production implementations: `TerminalPromptRepository` (standalone) and `ControlPromptService` (supervised); keeps the `server/` subsystem free of core-layer imports (mirrors the auth-interface precedent from PR 1.4). |
| `ControlStatusNotifier` | Layer 4 `control/` | owns **all outbound** status-class control sends (created in PR 1.10): observes Layer-0 state streams (relay connection state incl. close code via `RelayClient.connectionState`, plugin health via `BridgePlugin.status`, registration events via the auth seam's `registrations` stream, plus the control channel's own state for a reconnect re-sync) and receives the **active-session summary as a typed delegate feed** from the Orchestrator's SSE pipeline (`handleProjectsSummary` — same shape as `CompletionPushListener.handleSseEvent`; avoids a second Layer-4→Layer-1 derivation path into the plugin). Maps them to `status`/`registered`/takeover pushes over the injected `ControlChannelClient`, deduped. Higher layers (Orchestrator) never call `ControlChannelClient.send` directly. |
| `BridgeIdStorage` (file API + reader) | **inside the `auth/` subsystem** | persist `bridgeId` separately from `token.json`; kept within `auth/` (which is self-contained, outside the core layer hierarchy) so auth code doesn't depend back on top-level `repositories/`. Injected from the composition root. |
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
| `BridgeProcessRepository` | `module_desktop_core` Layer 2 | wraps the process API and owns the expected-exit marker / atomic expected-stop operation used by process and update services — nothing else (log capture is the tracker's job) |
| `BridgeStatusTracker` / `BridgePromptTracker` | `module_desktop_core` Layer 2 | hold status/pending-prompt state as stream/snapshot; written by the dispatcher, read by the cubit/service |
| `BridgeProcessLogTracker` | `module_desktop_core` Layer 2 `trackers/` | owns helper output state: subscribes to the raw stdout/stderr streams the Layer-1 process API exposes, drains them (undrained pipes block the child), keeps the last-N ring buffer exposed as snapshot/stream for the give-up UI (PR 2.7) and `FailureReporter` (PR 2.14), and forwards lines to the injected `BridgeProcessLogStorage` for persistence. Attached to the child's streams by `BridgeProcessService` after spawn. |
| `BridgeProcessLogStorage` | `module_desktop_core` Layer 1 `api/` | dumb file-persistence boundary for the helper log dataset: append lines, rotate at size cap, expose the log directory path (for the PR-2.10 "open logs" action). No decisions, no derived state — a write failure throws to the tracker, which isolates it. |
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
| A6 | `bridgeId` persistence = a small file-backed storage **inside `auth/`** (no Dao) — **implemented as `BridgeIdStorage`** | one string; no DB/migration; keeps it within the self-contained auth subsystem so auth code doesn't depend on top-level `repositories/`. Removing `bridgeId` from `TokenData` also deleted the token↔bridgeId carry-over re-reads; legacy ids are adopted once from `token.json` via an injected `readLegacyBridgeId` seam |
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
| A22 | A bridge displaced by the relay does **NOT** tight-loop reconnect: standalone logs a loud takeover warning and retries only on a long capped backoff; supervised additionally surfaces a takeover state over the control channel and the GUI's "Take over" action is a plain helper respawn. **Detection keys on a dedicated relay close code `4007 bridgeReplaced`** (small relay change shipped with PR 1.14); today's `1000 + reason "replaced"` is only a rollout fallback, because intermediaries may strip/rewrite close **reason strings** while codes survive, and the codebase already keys close semantics on codes (`4006` precedent) | the relay holds a single bridge slot per account and closes the displaced bridge on contact; with today's 1s-reset backoff two always-on bridges (two desktops, or desktop + forgotten systemd bridge) mutually kick each other forever while phones see `bridge_connected` flapping. Desktop autostart (Decision #7) makes this mainstream. Stage C multi-bridge is the real fix — this keeps losing the slot graceful until then |
| A23 | Supervised auth-required exit uses a **dedicated exit-code sentinel `87`** (alongside restart `86`): when the GUI cannot supply a token at bootstrap, the helper emits a `loginNeeded` prompt (best-effort) and exits `87` | the GUI's exit-code state machine (PR 2.7) must distinguish "needs login" from a crash, or it backoff-respawns a helper that can never start; inferring auth-required from a prompt seen shortly before a generic exit is racy — the exit code is the authoritative signal, the prompt is advisory |
| A24 | If the OS tray is unavailable (stock GNOME hides AppIndicators without an extension), the GUI falls back to **windowed mode** and never boots `--hidden` | a tray-only hidden app with no tray icon is running but unreachable; hidden autostart is only safe when a tray icon is actually visible |
| A25 | **Same-machine single-live precedence:** enforcement stays mode-agnostic (startup mutex + live scan + replace ask + SIGTERM→SIGKILL); **explicit confirmation wins** — a terminal "y" or a GUI prompt accept replaces the incumbent regardless of the incumbent's mode (a replaced supervised helper exits 0 via its normal signal teardown = deliberate stop, not a crash); **no answer ⇒ the incumbent wins and the newcomer exits typed** — standalone keeps today's loud abort (exit 1), a supervised newcomer whose contention ends in decline or `nonInteractive` (GUI declined / unreachable / prompt timeout / teardown / unidentifiable mutex holder) exits with the dedicated sentinel **`88` (`SupervisedExitCode.bridgeContention`)**; GUI render/auto-answer policy for a silent `--hidden` autostart and the "Take over" action (plain respawn + accept the fresh replace prompt) live GUI-side (PR 2.7/2.9), not in the bridge | a supervised helper has no stdin, so contention used to resolve `nonInteractive` → generic exit 1 — indistinguishable from a crash, so the GUI's state machine would backoff-respawn into an endless re-prompt loop while the incumbent (e.g. a dev's terminal bridge) keeps getting asked; a typed exit lets the GUI surface "another bridge is running — take over?" exactly once, and keeping the ask/kill mechanics mode-agnostic preserves today's standalone behaviour byte-for-byte |

## 8. Open risks & lead-time register

| Item | Status | Owner | Notes |
|---|---|---|---|
| Windows code-signing cert | **OPEN — lead time, START PROCUREMENT NOW** | TBD | blocks PR 3.4 (signed Windows); EV clears SmartScreen faster. Non-code and parallelizable — do not serialize behind Phase 2; if it slips, ship macOS-first (phase-3 preamble allows per-OS v1). |
| Relay single-slot replace war (cross-machine) | **RESOLVED in bridge PR 1.14 (relay deploy gate open → `sesori_relay_server#7`)** | TBD | Relay keeps ONE bridge slot per account and closed the displaced bridge with 1000/`"replaced"`; the bridge treated that as a generic drop and reconnected on a backoff that resets to 1s — two always-on bridges mutually kick forever, phones see flapping. PR 1.12's mutex only covers same-machine. PR 1.14 (ADR A22) adds `RelayCloseCodes.bridgeReplaced = 4007` + `isBridgeReplaced` detection (code-authoritative, `1000/"replaced"` rollout fallback), a minutes-order takeover backoff in the orchestrator reconnect loop (standalone `Console.warning`), and a `ControlRelayConnectionState.takenOver` status push (supervised). **Relay prerequisite `sesori-ai/sesori_relay_server#7` must be merged AND deployed to prod before the bridge PR merges** — the bridge's `1000/"replaced"` fallback keeps an older relay safe during rollout. Verified in MT-1/MT-3. Stage C multi-bridge dissolves the problem properly. |
| Linux tray availability (GNOME) | OPEN | TBD | `tray_manager` needs AppIndicator; stock GNOME hides tray icons without an extension → tray-only `--hidden` boot = running but unreachable app. PR 2.9 adds windowed fallback, PR 2.11 refuses hidden boot without a tray (ADR A24); verified on GNOME in MT-3/MT-4. |
| GUI crash → helper self-exits (A9) → bridge silently down | OPEN — accepted for v1 | TBD | Login items don't relaunch crashed apps (macOS `SMAppService`, Windows run keys), so a 2am GUI crash kills the bridge until the user notices a missing tray icon. Deliberate v1 trade against orphaned helpers; revisit post-v1 (watchdog / `KeepAlive`-style relaunch) if telemetry (PR 2.14) shows it matters. |
| Control-channel secret bootstrap (off-argv) | OPEN | TBD | ADR A8; designed in PR 1.1 / PR 2.6 |
| Orphaned helper on GUI crash | OPEN | TBD | ADR A9; parent-loss policy in PR 1.1 |
| Supervised restart replays `--control-url` (no stdin secret) | RESOLVED in PR 1.7 | TBD | PR 1.1 gap closed: supervised restart now sets `BridgeRestartService.supervisedRestartRequested` and the runner returns `supervisedRestartExitCode` (86) instead of calling `spawnSuccessor()`, so no `--control-url`-replay successor is ever spawned. GUI-side mapping of 86 → respawn is PR 2.7. |
| Supervised restart stalls if session teardown *hangs* | OPEN → PR 2.7 | TBD | PR 1.7 makes supervised restart return exit 86 on a clean return, a teardown *throw*, and a *throwing* coordinator shutdown. It does NOT cover a teardown await that **hangs** forever inside `OrchestratorSession.run()`/`cancel()`: the runner never reaches the exit path, and the shutdown-coordinator backstop only arms inside `shutdown()` (unreachable while `run()` is stuck), so the process would stall with no exit 86 and the GUI would never see the restart. This is a general session-teardown property (a hang stalls every shutdown path, not just restart; standalone masks it because the successor was already spawned). Fix belongs with Phase 2 process supervision: the GUI kills+respawns a helper that doesn't exit within a grace window after a restart (PR 2.7), and/or a bridge-side teardown watchdog. |
| Uninstall vs shared CLI state | OPEN | TBD | ADR A10; scope cleanup in PR 3.11 |
| RelayClient live re-auth on token push | RESOLVED in PR 1.5 (identity gate fixed post-merge) | TBD | ADR A12; Orchestrator subscribes to `AccessTokenProvider.tokenStream` and re-auths only when the emitted token's **auth identity** (JWT `userId` claim) differs from the one `RelayClient.lastAuthedToken` authenticated with (funnels into the existing reconnect path). PR 1.5's original string-inequality gate flapped the relay on every routine same-user rotation (standalone `TokenManager` emits each refresh; a near-expiry pull during session-metadata generation dropped all phones mid-flight) — the relay validates the JWT once at connect and never re-checks, so same-identity rotation keeps the socket. Unparseable tokens re-auth conservatively. Service cache writes are ordered by issue-sequence (newest-issued wins, push outranks in-flight pulls); a signed-out `token_response` invalidates the cache and defers reconnect, and a refresh failure with no safe cached token also defers. Connection-level tests added. |
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

`MT-N` rows are **manual-testing checkpoints** — user-run verification passes, not
PRs (checklists live in the phase docs; resume rule 5 in the preamble governs
them). Only the user checks an MT box.

### Phase 0 — Rename → `phase-0-rename.md`
- ☑ 0.1 `mobile/`→`client/` everywhere (atomic) — **Med-High / L**

### Phase 1 — Bridge supervised mode → `phase-1-bridge-supervised.md`
- ☑ 1.1 `--control-url` + off-argv secret bootstrap + `ControlChannelClient` skeleton — Low-Med / M
- ☑ 1.2 Control-protocol Freezed DTOs (incl. provision-progress mirror) — Low / S-M
- ☑ 1.3 Supervised auth bootstrap (short-circuit `ensureAuthenticated`) — Med / M
- ☑ 1.4 Token provider **pull** over channel (+ timeout/GUI-down) — Med / M
- ☑ 1.5 Token-stream **push** → relay client — Med / S-M
- ☑ 1.6 Supervised registration + `bridgeId` out of `token.json` — Med / M
- ☑ 1.7 Exit-code restart (`86`) + bypass successor-spawn — Med / S-M
- ☑ 1.8 Disable self-update + reconcile when supervised — Low / S
- ☑ 1.9 `BridgeControlMessageDispatcher` + prompts/Console → control events + auth-required exit `87` — Med / M
- ☑ 1.10 Status push (relay/plugin/active sessions) — Low / S-M
- ☑ 1.11 `unregister-and-exit` control command — Low / S-M
- ☑ 1.12 Single-live precedence under supervised `--hidden` — Med / M
- ☑ 1.13 Tee `RuntimeProvisionProgress` → control channel — Low / S-M
- ☑ 1.14 Relay replaced-close (`4007`) → takeover state, no reconnect war (ADR A22) — Med / S-M
- ☑ 1.15 Dev control-host harness for manual supervised testing (`tool/`) — Low / S
- ☑ 1.16 Address MT-1 supervised findings (provision traffic + update status) — Low / S
- ☐ MT-1 Manual checkpoint: bridge supervised mode end-to-end (see phase doc) — user-run

### Phase 2 — Desktop shell + supervisor → `phase-2-desktop-shell.md`
- ☐ 2.1 `client/module_desktop_core` + `client/desktop` packages + desktop PR CI + builds on 3 OSes — Med / M
- ☐ 2.2 Desktop platform adapters (module_core + module_desktop_core prerequisites) — Low-Med / S-M
- ☐ 2.3 Login reuse (`AuthManager` browser-poll OAuth) — Med / M
- ☐ 2.4 Control status/prompt trackers baseline (no relay client yet) — Low-Med / S-M
- ☐ 2.5a Re-export `AuthTokenProvider` from `module_core` (seam) — Low / S
- ☐ 2.5 `ControlChannelServer` + `ControlMessageDispatcher` + token responder — Med / M
- ☐ 2.6 `BridgeProcessService`: spawn/kill/path + expected-stop boundary + helper log capture — High / M
- ☐ 2.7 Exit-code state machine (86/87/0/other + backoff) — High / M
- ☐ 2.8 Spike: bundled bridge runtime-ownership + `--hidden` contention — Med / S-M
- ☐ 2.9 Tray menu + reusable control cubit + tray-unavailable fallback — Med / M
- ☐ 2.10 `WindowHost` single window + v1 window contents — Med / M
- ☐ MT-2 Manual checkpoint: first real GUI supervision (see phase doc; needs the 2.9/2.10 control surface) — user-run
- ☐ 2.11 Autostart + `--hidden` boot + macOS login-item detection — Med / M
- ☐ 2.12 GUI single-instance + persist on/off & last-state — Low-Med / S-M
- ☐ 2.13 Logout coordination (GUI: unregister→kill→invalidate locally) — Med / S-M
- ☐ 2.14 Desktop `FailureReporter` impl — Low-Med / S-M
- ☐ 2.15 E2E integration (spawn→handshake→token→helper relay auth→restart→logout; local fakes) — Med / M
- ☐ 2.16 First-run provisioning progress UI + degraded state — Med / M
- ☐ MT-3 Manual checkpoint: full internal MVP on 3 OSes (see phase doc) — user-run

### Phase 3 — Packaging / signing / self-update (= v1) → `phase-3-packaging.md`

> Rows are ordered as **per-OS chains, macOS first** (matches the phase-3
> preamble's macOS-first shipping allowance), so the top-to-bottom resume rule
> naturally completes macOS — including its ship gate — before Windows/Linux.
> **Blocked rows skip as a chain, not a row:** if an external dependency blocks
> a row (e.g. the Windows cert for 3.4), mark it ◐ with a §8 note and skip to
> the **next unblocked chain** — every row that depends on the blocked one
> (3.8, 3.11b, MT-4b behind 3.4) is implicitly blocked with it; never start a
> dependent row to "continue".

- ☐ 3.0a macOS no-sandbox + hardened-runtime + spawn-child entitlements — Med / S-M
- ☐ 3.0b CI secrets provisioning (config + docs) — Low / S
- ☐ 3.1 `_reusable-desktop-build.yml` macOS leg (unsigned) — High / M
- ☐ 3.2 macOS codesign + notarize + staple — High / M
- ☐ 3.6 Update-apply policy (stop helper first) + rollback + update UX — Med / M
- ☐ 3.7 macOS self-update (Sparkle) + EdDSA + appcast — High / M
- ☐ 3.10 Release-pipeline integration (non-blocking, **leg-additive**) + `make bump-version` + changelog — Med / M
- ☐ 3.11a In-app "Disconnect & reset" (macOS/Linux mechanism) + best-effort unregister — Low-Med / S-M
- ☐ MT-4a Manual checkpoint: **macOS ship gate** (see phase doc) — user-run
- ☐ 3.3 Windows leg: build + bundle + installer (unsigned) — High / M
- ☐ 3.4 Windows code signing (needs cert — may be ◐-blocked; blocks 3.8/3.11b/MT-4b, skip to Linux chain) — Med / S-M
- ☐ 3.8 Windows self-update (WinSparkle) + appcast leg — High / M
- ☐ 3.11b Windows uninstaller cleanup flow — Low / S
- ☐ MT-4b Manual checkpoint: **Windows ship gate** (see phase doc) — user-run
- ☐ 3.5 Linux AppImage + bundle + **mandatory** GPG signing — Med-High / M
- ☐ 3.9 Linux self-update (zsync/AppImageUpdate) + feed leg — Med-High / M
- ☐ MT-4c Manual checkpoint: **Linux ship gate** (see phase doc) — user-run

### Phase 4 — Accessory UI (v1.x) → `phase-4-accessory-ui.md`
- ☐ 4.1 Create `client/module_app_ui` + move shared widgets/extensions/l10n — Med / M
- ☐ 4.2 Voice: move only real UI; keep services behind module_core seams — Med / M
- ☐ 4.3 Move login/splash — Med / M
- ☐ 4.4 Move project_list + session_list — Med / M
- ☐ 4.5 Move session_detail + session_diffs + new_session (split if needed) — Med / M
- ☐ 4.6 Move settings — Low-Med / S-M
- ☐ 4.7 Desktop router composition + wire accessory UI into window — Med / M
- ☐ MT-5 Manual checkpoint: desktop accessory UI parity + mobile regression pass (see phase doc) — user-run

### Phase 5 — Polish (v2) → `phase-5-polish.md`
- ☐ 5.1 Multi-window spike (throwaway) — Med / S-M
- ☐ 5.2 Frameless popover window (sliced during planning) — Med / M+
- ☐ 5.3 Richer settings — Low-Med / M

> Note: OpenCode onboarding/detection was REMOVED from Phase 5 — the bridge now
> auto-provisions OpenCode at startup (main #322).
