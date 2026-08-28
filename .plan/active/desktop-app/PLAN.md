# Desktop App — Supervisor + Cockpit

## Status

- **Plan slug:** `desktop-app`
- **Status:** Active — step 4/22 (exit-code state machine + prompt answers)
- **Plan date:** 2026-08-28
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Current implementation base:** `main`
- **Delivery:** 22-step PR series titled
  `<emoji> [desktop-app] <description> [step <x>/22]`
- **Architecture plan review:** performed 2026-08-28 (approve-with-fixes); all
  six findings applied to this document (process-repository boundary, bridgeId
  persistence, named send/logout owners, `tokenUpdate` deletion, instance
  Layer-1 storage, theme-assembly ownership)
- **Supersedes:** the paused desktop plan formerly in `docs/desktop/`
  (PLAN.md + phase docs), deleted by step 1. Git history preserves it; the
  still-valid decisions are carried into this document.

## Goal

Ship the Sesori desktop app as both the **supervisor** of the local bridge
(tray/menu-bar control, autostart, login, lifecycle) and the **cockpit** (the
full client UI — harness management, projects, sessions, chat — rendered in the
desktop window as a relay client). End state of this plan: a dev-built desktop
app the team runs as its daily bridge and client on macOS, with Windows/Linux
building in CI.

**Explicitly out of scope (follow-up plan):** distribution — packaging,
signing, notarization, installers, self-update, release-pipeline legs, store or
download channels, and all certificate work for every OS. Step 22 retires this
plan and initiates a `desktop-distribution` follow-up plan; distribution
decisions are deliberately not discussed until then.

## Where this plan starts from (verified 2026-08-28)

The prior plan delivered, and verification confirmed intact and green on
current `main`:

- **Bridge supervised mode (complete).** `--control-url` + stdin secret,
  `ControlChannelClient`, control DTOs in `sesori_shared`,
  `ControlChannelTokenService` (GUI is sole token authority),
  `BridgeControlMessageDispatcher`, `ControlPromptService`,
  `ControlUnregisterService`, `ControlStatusNotifier`, `BridgeIdStorage`,
  `ControlChannelLossListener`, `SupervisedExitCode { restart(86),
  authRequired(87), bridgeContention(88) }`, self-update disabled when
  supervised, mode-agnostic single-live precedence, relay takeover close code
  4007, and the `tool/dev_control_host.dart` harness. Wired once at
  `bridge/app/lib/src/runtime/bridge_runtime_runner.dart`; 107 control tests
  pass. End-to-end manually verified in the prior plan's MT-1.
- **Client desktop packages (partial, dormant).** `client/desktop` (shell:
  platform adapters, login via shared `LoginCubit`, `AuthGate`) and
  `client/module_desktop_core` (`ControlChannelServer`,
  `ControlMessageDispatcher` with token responder, `BridgeStatusTracker`,
  `BridgePromptTracker`, `AuthGateCubit`). All analyze `--fatal-infos` clean
  with passing tests. The control channel is registered but nothing starts
  it — that is exactly where this plan resumes.
- **Desktop CI** (`.github/workflows/desktop-ci.yml`): analyze + test + 3-OS
  build matrix, path-gated, non-blocking for CLI/mobile releases.

This delivered code is kept, not reworked. The only bridge-side behavior
change in this plan is step 5 (status semantics + dead-protocol removal).

## Why the old plan was superseded

- Its first-run story is dead: `ensureRuntime` is now contractually read-only;
  harness installs are per-plugin, on demand, over the relay management API
  with SSE progress. The control-channel provisioning tee never carries a
  download anymore, and a control-channel-only "lean v1" can no longer onboard
  anyone.
- Its aggregate plugin-health rule ("healthy iff every eligible plugin is
  ready") predates the setup-aware world: with ~10 bundled harnesses and 1–2
  installed, the tray would read degraded forever.
- Its v1 (tray-only app, session UI deferred, packaging first) no longer
  matches the product: the vision doc defines the desktop window as the client
  UI, and the shared-UI groundwork it planned (leaf-widget extraction) has
  since happened into `module_prego`.
- Its process (four tracking surfaces, per-PR ceremony) predates the current
  `.plan/<slug>/` convention and had drifted; its file pointers predate the
  bridge source-tree flatten.

## Locked decisions

| # | Decision |
|---|---|
| D1 | One product: supervisor + cockpit. No "lean v1" tray-only release. The window is the client UI; onboarding (harness setup/install/login) happens in it. Distribution ships in the follow-up plan. |
| D2 | Cockpit UI = **shared adaptive screens** in a new `client/module_app_ui` package, extracted slice-by-slice from `client/app`. Screens stay adaptive (the existing `session_split` two-pane shell is the precedent), so wide/tablet/landscape mobile and desktop render from the same code. Desktop-only chrome (tray, supervision views, window management, future popover) stays in `client/desktop` / `module_desktop_core`. Desktop forks a screen only where surfaces genuinely differ (existing desktop login is the precedent). |
| D3 | Window data path = **relay**, exactly like the phone (E2E encrypted; internet required even for a same-machine bridge — accepted). A loopback local data path stays a recorded future consideration in `docs/ROADMAP.md` (the bridge `DebugServer` is the precedent), not work in this plan. |
| D4 | The control channel stays a **supervision umbilical only**: token authority, supervision prompts, status (relay/registration/aggregate plugin health/session count), lifecycle sentinels. Product data and per-plugin detail never enter it — that is the relay management API's job. |
| D5 | The old plan is canceled: `docs/desktop/` deleted, pointers repointed, still-valid content carried here. |

### Carried architecture decisions (from the superseded plan, still valid)

| Ref | Decision |
|---|---|
| C1 | Out-of-process supervised child; GUI spawns and supervises the bridge; standalone/headless path unchanged and first-class (gated by `--control-url`). |
| C2 | GUI is the sole token authority; helper pulls tokens over the channel and never runs OAuth/refresh. |
| C3 | Control channel = GUI-hosted loopback WebSocket; per-spawn secret delivered off-argv (stdin), never in argv. |
| C4 | Control-protocol DTOs live in `shared/sesori_shared`; no project data, session names, or message content on the channel. |
| C5 | Restart = exit 86 (GUI respawns, no backoff); auth-required = exit 87 (stop + login-required state, no thrash); same-machine contention = exit 88 (stop + "another bridge is running" + Take-over action = plain respawn answering the fresh replace prompt with accept); clean stop = 0 (no respawn); other = crash backoff + give-up. |
| C6 | Helper exits on sustained control-channel loss (grace period) so a crashed GUI never leaves an invisible bridge with a live token. GUI-crash → bridge-down until relaunch is an accepted trade (no watchdog). |
| C7 | Tokens supplied over the channel drive relay re-auth only on auth-identity change (JWT userId), not on same-user rotation. Token flow is pull-on-demand (incl. forced refresh after 401); there is no push path. |
| C8 | GUI persists a readable `bridgeId` copy from the `registered` event and keeps a server-side unregister fallback for logout with a dead/absent helper. Desktop logout is device-local: targeted bridge delete + local token clear; never account-wide token invalidation or `/auth/revoke`. |
| C9 | Cross-machine relay displacement keys on close code 4007 (reason-string fallback), long takeover backoff, `takenOver` status push; Take over = plain respawn. Single-slot relay semantics are current reality; Stage C multi-bridge stays outside this plan. |
| C10 | `SystemTray`/`WindowHost`/`LaunchAtLogin` are dumb Layer-0 adapters in `module_desktop_core` with shell implementations; Layer-4 cubits drive them. Tray availability on Linux requires **positive evidence** (a StatusNotifier host present), not merely successful init — stock GNOME initializes AppIndicators it never shows. Without that evidence: windowed mode, and never boot hidden. |
| C11 | Desktop uninstall/reset (distribution plan) may touch only desktop-owned state; `token.json` and the managed runtime roots are shared with the standalone CLI. Desktop-namespaced GUI state from day one. |
| C12 | `module_desktop_core` layering: `foundation` → `api` → `repositories`/`trackers` → `services` → `control`/`cubits`; dispatchers write down into trackers; cubits read trackers; no same-layer service deps (Layer-4 orchestrators compose services). Cubits are shell-constructed, not DI-registered. |
| C13 | Desktop mirrors `sesori_bridge_foundation` primitives (process executor, download/checksum/archive) as patterns; it never imports bridge-workspace code (each side opens browsers/URLs through its own adapter). |

Legacy `ADR A*` identifiers still cited in code comments and tests map here
(the superseded plan's docs were deleted): A4→C4, A8→C3, A9→C6, A11→C13,
A13→C8, A22→C9.

## Architecture

```
client/app ──────────────┐
client/desktop ──────────┼→ module_app_ui → module_core → module_auth → sesori_shared
     │                   │        │
     │                   └────────┴→ module_prego (design system)
     └→ module_desktop_core ─→ module_core, sesori_shared
```

- `module_app_ui` (new, step 14): shared Flutter feature screens + l10n +
  context extensions. Theme assembly is owned terminally by `module_prego`
  (design system); both shells and `module_app_ui` consume it. May depend on
  `module_core`,
  `module_prego`, `sesori_shared`, and direct UI packages. Must never import
  `client/app`, `client/desktop`, or `module_desktop_core`. Shell-owned
  behavior (routing targets, install/onboarding actions, platform
  capabilities) enters through injected strategies/callbacks.
- Two desktop connections, cleanly split: the **control channel** (loopback,
  supervision) and the **relay client** (product data, `ConnectionService`
  resolved from step 13). The desktop never introduces a second reconnect
  driver; it inherits `ConnectionService` semantics as-is.
- Supervision status in the tray/window comes from the control channel and
  works with the relay down; product UI (management, sessions) comes from the
  relay and requires internet, mirrored truthfully in connection states.

## Steps

Sizes are soft-capped at 1,500 changed lines; steps 1, 2, 14, 17, 18 record
expected overages below. Any step that ships or
materially changes user-facing behavior updates the directly affected
`docs/regression/` feature document in the same PR; step 21 is final
reconciliation only, never the first write.

### M1 — Supervision core (supervision stack only; no mobile risk — step 2 touches `sesori_shared`/bridge for the `shutdown` command)

**Step 1 — 🌿 Raise plan; supersede and delete the old desktop plan** *(this
PR)*. Add `.plan/active/desktop-app/` (PLAN.md, TRACKER.md). Delete
`docs/desktop/`. Repoint references: `docs/ROADMAP.md` (Stage A detail +
"paused" note + add the loopback data path to the deferred list per D3),
`docs/VISION.md`, `client/AGENTS.md`, `client/README.md`,
`client/desktop/AGENTS.md`, `client/module_desktop_core/AGENTS.md`,
`.github/workflows/desktop-ci.yml` header comment. Truth-up drift found in
verification: stale docstrings in `control_status_notifier.dart` /
`control_channel_client.dart`, and `bridge/app/AGENTS.md` calling `control/` a
"Subsystem" (it is part of the core layered app). Docs/comments only — no
behavior change. *Overage: ~3.1k deleted doc lines, mechanical.*

**Step 2 — 🚧 Bridge process primitives.** `module_desktop_core` Layer 1
process API (spawn/kill/exit stream/stdout+stderr streams; non-positive-PID
guard), Layer 2 `BridgeProcessRepository` — the **single Layer-2 boundary over
the process API**: spawn, graceful-signal/kill, exit stream, raw stdio
hand-off, the expected-exit marker, and the atomic expected-stop operation
(mark + graceful stop together, with a bounded grace deadline and a kill
fallback that preserves the marker — a helper that hangs in teardown can
never block Off/Quit or leave an orphan). The graceful half is a
control-channel `shutdown` command **added by this step** (sealed
`ControlMessage.shutdown` in `sesori_shared` + the bridge dispatcher route to
the graceful exit-0 path — `unregister_and_exit` minus the unregister),
because Windows has no catchable SIGTERM, so a signal cannot be the primary
mechanism; a POSIX signal remains the secondary path when the channel is
down. The contract must exist before the repository consumes it, so the
protocol addition lives here, not in step 5. The **whole atomic operation
lives in the repository**, which sends the `shutdown` frame itself over the
injected control seam (the same blessed direct-seam pattern the delivered
dispatcher and bridge-side services use): mark, send, bounded wait, kill-tree
fallback — one Layer-2 owner, so no upward or same-layer dependency is needed
(`ControlCommandService` owns only conversational sends; see step 4). The grace deadline strictly exceeds
the bridge's own bounded shutdown (phase budgets + backstop slack + emergency
disposal cap) so the fallback never preempts the helper's plugin disposal,
and the kill terminates the helper's process tree/group, not just its PID —
otherwise backend processes outlive a forced stop. Services never call the process API
directly
(mirrors the `AppUpdater → AppUpdateApi → AppUpdateRepository` precedent in
this package's docs). Plus Layer 2
`BridgeProcessLogTracker` (drains child pipes — an undrained pipe blocks the
child — keeps a last-N ring buffer as snapshot/stream) over Layer 1
`BridgeProcessLogStorage` (append + size-capped rotation under desktop-owned
app data; on POSIX the log directory is 0700 and files 0600, preserved across
rotation/replacement — helper output carries paths/identifiers/errors,
mirroring the bridge's data-directory hardening; a storage write failure is
caught and logged **rate-limited** by the tracker — a persistently unwritable
disk must not turn every helper line into a warning — and never stops the
drain). Pure Dart, fully unit-tested. *Overage: ~1.8k changed lines including
generated control-union code and focused process, repository, storage, and
pipe-drain test suites; the atomic stop and non-blocking log contracts land as
one cohesive boundary.*

**Step 3 — 🚧 `BridgeProcessService` (Layer 3): the channel comes alive.**
Collaborators (all lower-layer): `BridgeProcessRepository` (all process
operations), `BridgeProcessLogTracker` (attach), `ControlChannelServer`
(start/stop per spawn), and the `module_core`-re-exported `AuthSession` seam
for authenticated-spawn gating (signed-out start → login-required state, no
spawn). Starts the control server per spawn (fresh secret/port), spawns the
bridge through the repository with `--control-url` + secret via stdin,
attaches the log tracker, observes the repository's exit stream. Spawn is
transactional: any failure after the server starts (missing helper path,
attach/monitor error) stops the control server, expected-stops any created
child, resets service state, and surfaces the original error before a retry
is allowed. Clean stop = the repository's atomic expected-stop. The shell bootstrap resolves and starts
the delivered `ControlMessageDispatcher` (the single long-lived inbound
subscription to `ControlChannelServer.events`) before any spawn — without it
the helper's first `token_request` goes unread. Bridge
binary resolution for dev builds (explicit configured path with a
repo-sensible default); bundled-layout resolution is distribution-plan scope.
First real GUI↔helper handshake since the prior plan's wire verification.

**Step 4 — 🚧 Exit-code state machine + prompt answers.** Shared
`BridgeSupervisedExitCode` drives both products: 86→immediate respawn;
87→stop with login-required —
and a successful sign-in restarts a helper whose desired state was On (a
manual Off stays off), covered by the state-machine tests;
88→stop with "another bridge is running" + Take-over; 0/expected→stop;
other→bounded backoff → give-up surfacing recent log lines. The crash budget
resets after a stable healthy runtime, and any manual lifecycle action cancels
a pending retry timer (no delayed second helper) — both covered by
state-machine tests. The GUI needs no restart-hang fallback of its own: it
cannot observe phone-triggered restart intent before exit 86, and the bridge
already guarantees the sentinel (the 86 latch at handoff plus the shutdown
coordinator's budgeted backstop with emergency plugin disposal — verified for
the restart path in step 5); exit 86 stays the single restart contract. Adds **`ControlCommandService`** (Layer 3): the
owner of **conversational** GUI→helper sends (`prompt_response` here;
`unregister_and_exit` in step 11). It validates the exact tracked prompt
instance, then sends through the Layer-2 command repository and Layer-1 control
API before clearing `BridgePromptTracker` — cubits never touch the Layer-4
dispatcher, and the dispatcher stays inbound-only. The expected-stop
`shutdown` frame is deliberately NOT here: it belongs to the process
repository's atomic stop operation (step 2), keeping that operation in one
owner. Includes hidden-boot render
policy: contention during a silent autostart surfaces as state, never a modal.
*Overage: ~1.7k changed lines after review-driven lifecycle-race,
per-helper prompt-ownership, and shared exit-contract hardening.*

### M2 — Control surface

**Step 5 — 🌿 Status semantics for the setup-aware world + dead-protocol
removal.** Bridge: `ControlStatusNotifier` maps plugin health as *degraded iff
any eligible plugin reports degraded/failed; healthy otherwise* — dormant,
not-installed, and zero-eligible states are healthy (eligibility is not
residency). Delete dead protocol end-to-end: `ControlMessage.provisionProgress`
+ `ControlProvisionProgress` mirror + `ControlProvisionNotifier`, the never-
sent `ControlMessage.restart`, and `ControlMessage.tokenUpdate` (its only
sender is the dev harness step 12 deletes; token flow is pull-on-demand per
C7) — including the bridge receiver paths
(`ControlChannelTokenService.handleTokenUpdate`, dispatcher route), client
dispatcher branches, and the dev harness, all in the same PR. The new health
rule leaves `ControlPluginHealthState.unavailable` unreachable (the mapper
emits only healthy/degraded; `unknown` stays the init/forward-parse fallback),
so that variant and its client/test branches are deleted too. The dev harness
itself survives until step 12 — step 5 only updates its affected branches.
(The `ControlMessage.shutdown` supervision command was added in step 2, where
its first consumer lives; this step is deletions plus the semantics fix
only.)
Also bridge-side: **verify with a test — no new mechanism** — that the
existing shutdown-coordinator backstop covers the supervised restart path:
exit 86 is latched at handoff, the coordinator arms at shutdown-request, and
its budgeted backstop performs emergency plugin disposal then force-exits
with the latched code even when teardown hangs (this superseded the old
plan's teardown-hang risk; a second watchdog would race the coordinator and
skip disposal). No compatibility
shims: the control channel has never shipped in a public release and both
halves live in this repo.

**Step 6 — ⚙️ Tray.** `SystemTray` Layer-0 interface + `tray_manager` shell
adapter (dumb: renders a menu model, emits clicks); Layer-4
`BridgeControlCubit` consumes `BridgeProcessService` + trackers, builds the
menu (status line, session count, On/Off, Quit — the Open item arrives with
step 7's `WindowHost`, since the dumb tray has no legal window collaborator
before it), and drives the tray.
Tray unavailable → windowed fallback (C10 — on Linux availability means
positive StatusNotifier-host evidence, since init succeeds invisibly on stock
GNOME); Quit = expected-stop then exit, no orphan.

**Step 7 — ⚙️ Window.** `WindowHost` Layer-0 interface + `window_manager`
adapter; close hides, quit matches tray semantics. Prego theme adoption in the
desktop shell via a small theme-assembly helper **added to `module_prego`**
(the terminal owner: `ThemeData` from `PregoColors`/`PregoTextTheme` +
extensions); step 14 converges `client/app` on the same helper. Window
contents v1: account + sign-out — introduces **`DesktopLogoutOrchestrator`**
(Layer 4) with the interim sequence: stop the helper via expected-stop
**before** the local sign-out, so a signed-out GUI never leaves a running
helper holding a usable token (cubits/shell never sequence services
themselves; step 11 extends this same orchestrator with unregister
coordination) — bridge on/off, status (relay /
registration / plugin health / session count / takeover / login-required /
crash give-up with recent log lines), open-logs affordance. Creates
`docs/regression/desktop-bridge-supervision.md`.

> **MT gate A — first real GUI supervision (user-run, after step 7).** Dev
> build on macOS: browser login (interstitial names the desktop device;
> relaunch restores session) · toggle on → handshake → healthy · phone
> round-trips a session through the desktop bridge · token authority holds
> past expiry (no helper `token.json` writes) · kill -9 helper → backoff
> respawn · phone-triggered restart → exit 86 → instant respawn · signed-out
> start → login-required, no spawn, no thrash · toggle off → exit 0, no
> respawn, no orphaned backend processes · terminal CLI coexistence
> (single-live prompt behavior intact; CLI stays logged in).

### M3 — Daily-driver hardening (desktop-only except steps 10–11, which touch mobile-shared auth/core seams)

**Step 8 — ⚙️ Single instance + last-state.** Ordered **before** autostart:
a login-started hidden process plus a manual open must never yield two GUIs
contending for one helper. Layer-1
`DesktopInstanceStorage` (persisted on/off & last-state under desktop-owned
app data) and Layer-1 `DesktopInstanceApi` (instance lock + the **activation
channel**: the lock owner listens on a local socket/pipe; a second launch
signals it and exits — lock + prefs alone cannot make the first instance
focus), both beneath `DesktopInstanceRepository` (Layer 2, aggregates the two
boundaries) under `DesktopInstanceService` (Layer 3), which surfaces a
focus-request stream the window owner consumes. Second launch
focuses the first; stale-lock recovery after a GUI crash. Layer-4
`DesktopStartupOrchestrator` composes instance + process services to restore a
last-on bridge behind the auth gate (no same-layer service deps).

**Step 9 — ⚙️ Autostart + hidden boot.** `LaunchAtLogin` adapter +
registration with `--hidden`; hidden launch → tray-only, but hidden boot
requires an available tray per C10's positive-evidence rule — otherwise the
window shows. Toggling
autostart off genuinely removes the login item; repeated launches don't
accumulate duplicates (single-instance from step 8 already guards the
process level).

**Step 10 — 🚧 `module_auth` logout/rejection hardening (approved refactor
R1).** A logout generation enforced **atomically around every flow result**,
not just checked before token writes: the generation is captured at flow
start and rechecked before each persist **and** each state emission of the
restore/refresh result — token writes (recheck after `saveTokens()`'s awaited
writes, clear on mismatch), the `/auth/me` user save, and the
`AuthAuthenticated` emission (the no-refresh restore path persists a user and
emits authenticated without ever touching token persistence, so a token-only
fence misses it). Alternatively serialize the full restore with logout. Kills
the restore-after-logout re-save race in all its variants. Also `/auth/refresh` 4xx-rejection
distinguished from transport failure (a definitive rejection clears the
persisted tokens/user **before** emitting `unauthenticated`, so a relaunch
cannot restore the revoked account — covered by a relaunch test; offline
stays silent). Remove `AuthGateCubit`'s documented
unconditional post-fence re-clear workaround. Mobile-shared: mobile login /
refresh / logout regression is this step's test focus. Ordered **before** the
logout orchestrator so step 11 can call `logoutCurrentDevice()` directly
without re-creating the cubit's fence.

**Step 11 — ⚙️ Logout coordination + offline unregister fallback.** Add
`deleteBridge(id)` to `module_core` `BridgeApi`/`BridgeRepository`
(`DELETE /auth/bridges/:bridgeId`; 404 = success) — mobile-shared, mobile
stays green. **Establish GUI-side `bridgeId` persistence (C8):** a Layer-1
desktop-owned `BridgeIdStorage` (step-2 storage pattern) written by
`BridgeStatusTracker` on the `registered` event down the existing
dispatcher→tracker path, seeded from disk at startup so a GUI relaunch with a
dead helper still knows what to delete. **`DesktopLogoutOrchestrator`**
(extending the step-7 orchestrator) composes `ControlCommandService`
(`unregister_and_exit` send), `BridgeProcessService` (bounded wait → kill if
needed), `BridgeRepository.deleteBridge` — attempted **always**, not only for
a dead helper: the helper's own unregister failure is swallowed by design and
unacknowledged, so the idempotent persisted-id deletion (404 = success) is
what actually guarantees no leaked registration — and
`AuthSession.logoutCurrentDevice()` (safe against late restores per step 10).
Every network step is best-effort with a bounded timeout; logout always
completes offline, then clears local tokens only (never account-wide).

**Step 12 — ⚙️ Supervised E2E + harness retirement.** Automated integration:
spawn a real (locally built) helper → handshake → token pull → helper
authenticates against a fake relay → restart 86 → respawn → logout →
unregister — deterministic in desktop CI (ephemeral ports, temp dirs,
always-kill cleanup, and a **fake auth registration endpoint** passed through
the helper's configurable auth-backend option, since `ensureRegistered()`
calls the auth backend before relay use — the suite must never touch
production services). The desktop CI job builds the helper itself, and the
`desktop-ci.yml` path filter gains the bridge control/protocol sources and
build inputs it exercises — a bridge-only control regression must trigger
this suite, not skip it. Delete `bridge/app/tool/dev_control_host.dart` (the
real GUI + this suite supersede it).

> **MT gate B — daily driver (user-run, after step 12).** macOS primary
> (Windows/Linux dev-build smoke as machines allow): autostart reboot →
> hidden tray + last-on respawn; disable sticks · second launch focuses ·
> GUI kill -9 → helper self-exits within grace; relaunch restores last-on ·
> logout matrix (helper live / helper dead): bridge leaves the account list,
> phone stays logged in, local tokens cleared · sleep/wake 10+ min → status
> recovers, no duplicate helper · cross-machine takeover: no flip-flop war,
> takeover state + Take-over works. Gate outcome: the desktop app replaces
> the terminal bridge for daily use.

### M4 — Cockpit

**Step 13 — ⚙️ Desktop becomes a relay client.** Register the missing
`module_core` prerequisites in the desktop shell (`RelayCryptoService`, a
**log-backed** `FailureReporter` — recovered failures whose only record is
`recordFailure` must stay observable in local logs, under a privacy-safe
contract: error, stack trace, event type, and operation context are retained
while payload-bearing information arguments are sanitized, since SSE property
values can carry prompt/transcript/source content; remote crash reporting
remains a distribution-plan decision — and the route/notification seams as
the resolved object graph actually requires); resolve `ConnectionService`; window shows truthful relay-client
connection state alongside supervision status (control channel and relay
client coexist; no second reconnect driver). The desktop root also starts the
root provider/listener stack the shared screens assume, mirroring mobile's
root wiring: `ConnectionOverlayCubit` (+ `ConnectionBanner` host) and
`SseToastCubit` (+ toast listener — backend `tui.toast.show` guidance must
not be silently consumed). **Standing rule for every cockpit slice
(15–19):** the slice that first renders a screen also wires, at the desktop
root, every root-level provider/listener that screen watches — a moved
screen may never land ahead of its root wiring.

**Step 14 — ⚙️ Create `module_app_ui` + shared foundations.** New Flutter
package; move `l10n/` (ownership of `l10n.yaml`/codegen) and the
`build_context_x` extensions; `client/app` consumes them from the package and
converges on the `module_prego` theme-assembly helper from step 7 (~70-file
mechanical import churn). The **desktop shell also wires the package here**:
dependency, `localizationsDelegates` + `supportedLocales` on its root app —
`context.loc` throws without them, and step 15's shared screens are the first
desktop consumers — plus the **desktop router skeleton** over the
`module_core` route definitions (replacing the bare `home: AuthGate()`), so
each slice in 15–19 extends routes as its screens land and step 20 is final
composition, not the first router. Desktop CI path filters
gain `client/module_app_ui/**`; mobile CI gains the package's analyze/test.
*Overage: mechanical move churn.*

**Step 15 — 🚧 Settings + harness management slice.** Decouple (DI via
constructor/BlocProvider, navigation via callbacks, shell links/`package_info`
behind injected strategies; notification prefs stay a mobile-injected
section), move settings + harnesses screens to `module_app_ui`, render in the
desktop window: setup states, enable/disable/restart, install with SSE
progress, harness login, idle policy, catalog rescan. The moved surface's
logout action becomes an **injected strategy**: mobile keeps the direct
`SettingsCubit.logout()` behavior; desktop routes it through
`DesktopLogoutOrchestrator` so cockpit sign-out never bypasses helper
stop/unregister. Per the step-13 standing rule, this slice wires the
app-wide preference cubits its screens watch (`AppearanceCubit` above the
`MaterialApp` — theming must react — and `ChatInputModeCubit`, each with its
persisted startup read). **This delivers desktop onboarding.** Mobile
behavior unchanged.

**Step 16 — 🚧 Project list + session list slice + desktop offline strategy.**
Decouple and move both lists (incl. `session_split`). Bridge-offline /
never-registered states act through an injected strategy: mobile keeps CLI
install copy + `reconnectBridge()`; desktop offers **Start the bridge** (drives
`BridgeProcessService`) — never CLI-install copy (refactor R3's in-plan half;
"get the desktop app" phone copy belongs to the distribution plan).

**Step 17 — 🚧 Session detail: transcript slice.** Move the
transcript/rendering half (streaming messages, markdown/code, tool parts,
subtask tiles, queued-prompt rendering, permission/question surfaces) with
decoupling as in step 15. The desktop shell registers the image-action seams
this slice resolves (`ImageSaver`/`ImageClipboard`/`ImageSharer` — the mobile
shell already has desktop-aware `ImageSaver` selection to reuse), or the
affected actions hide behind explicit capabilities — no dead controls, no
missing-registration crashes. Coordinate with the in-flight `claude-inline-subtasks`
series (rebase order agreed at implementation time). *Overage: mechanical move
churn.*

**Step 18 — 🚧 Composer slice + voice/media seams (approved refactor R2's
heavy part).** Relocate voice lifecycle behind `module_core` service seams and
media picking behind a platform seam (recording stays a mobile shell
adapter). The move fixes the existing layer skip rather than enshrining it: a
Layer-2 `VoiceRepository` wraps `VoiceApi`, the relocated transcription
service consumes the repository, and recorder/file/wake-lock stay foundation
capabilities implemented per shell. The desktop shell declares **explicit capability values, never
silent no-ops**: voice unsupported → text-first composer with voice entry
hidden (the `voiceFirst` default must not apply), and attachments use a real
desktop file picker (or the affordance is hidden until one exists) — no
visible control may be dead. Keyboard-visibility becomes a mobile-injected
concern; then move the composer (attachments, pickers, queued prompts). Voice
on mobile must be regression-clean. *Overage: move churn.*

**Step 19 — ⚙️ Diffs + new-session slice.** Decouple and move
`session_diffs` + `new_session` (worktree options included).

**Step 20 — ⚙️ Desktop cockpit composition.** Final composition over the
slice-built router (the skeleton landed in step 14): window
navigation (sidebar/split composition from the adaptive screens), keyboard
basics (Enter-to-send vs newline, Esc dismissal, text selection), and the
supervision surfaces (login-required, crash give-up, takeover) integrated
around the cockpit.

> **MT gate C — cockpit parity + mobile regression (user-run, after step
> 20).** Desktop: manage harnesses end-to-end (install + login a real one) ·
> browse projects/sessions · full chat round-trip incl. a permission answer ·
> diffs · new session (worktree) · bridge-off → Start-the-bridge recovers ·
> internet-down shows truthful offline while supervision still works · window
> ergonomics usable. Mobile (real device, release-target platform): login →
> lists → chat/composer/pickers → voice message → diffs → new session →
> settings + notifications — unchanged after the extraction, release
> pipeline dry-run green.

### Lifecycle closeout

**Step 21 — 🌿 Regression documentation reconciliation.** Final pass over the
per-step updates (each behavior-shipping step already updated its own docs):
complete
`docs/regression/desktop-bridge-supervision.md`; add desktop-client platform
scope to the affected feature docs (expected: account-and-onboarding,
plugin-setup-and-lifecycle, plugin-runtime-installation, projects-and-sessions,
session-creation-and-options, session-turns, questions-and-permissions,
attachments-and-images, diffs-and-source-control, session-archiving-and-
deletion, popup-alerts, navigation-transitions, voice-input (mobile-only
boundary restated), bridge-connectivity, bridge-installation-and-updates
(desktop app as an install path: still distribution-scope — note only));
remove stale references.

**Step 22 — 🌿 Coverage run, retirement, distribution handoff.** Run the
recorded coverage (below), record results in the tracker, move the plan to
`.plan/completed/desktop-app/` — **repointing every live reference step 1
created** (ROADMAP/VISION/client docs/workflow comments: historical links to
the completed path, active-workstream links to the distribution successor) —
and initiate the `desktop-distribution`
follow-up plan (all-platform packaging/signing/updates; its decisions are
discussed then — inputs: C11, the bundled-layout/runtime-ownership question,
release-pipeline gating, per-OS signing/update mechanics preserved in git
history of the superseded `docs/desktop/phase-3-packaging.md`).

## Regression coverage for retirement

- **Level:** L3 (release confidence) for the desktop surface.
- **Boundaries:** client end-to-end (desktop shell ↔ relay ↔ supervised
  bridge ↔ plugin) for cockpit journeys; headless/automated boundaries where
  they fully prove supervision contracts (E2E suite of step 12 counts).
- **Plugins:** representative for supervision and cockpit browsing/chat; for
  harness management journeys, one plugin per declared capability actually
  exercised (one with managed install, one with plugin login).
- **Platforms:** desktop release-target host = **macOS** (dev build). Mobile
  release-target platform regression per MT gate C.
- **Accepted reduction (user-approved via this plan):** Windows and Linux
  desktop L3 journeys are deferred to the `desktop-distribution` plan's
  verification; within this plan they get CI builds plus best-effort dev-build
  smoke at MT gates. GNOME tray-fallback verification rides that smoke.

## Complexity budget

New mutable parts, each justified: child-process handle + exit subscription
and backoff timer/attempt counter (`BridgeProcessService` — the supervisor's
essence); expected-exit marker (`BridgeProcessRepository` — distinguishes
intended stops from crashes); log ring buffer + rotating file (crash
diagnosis; pipe-drain necessity); single-instance lock + persisted
autostart/last-on prefs (daily-driver behavior); GUI-persisted `bridgeId`
copy (offline unregister, C8 — `BridgeIdStorage` + tracker write, step 11);
`module_auth` logout generation (R1 — closes a real race). Deliberately
**not** added: per-plugin control DTOs, a loopback data transport, a
GUI-crash watchdog (C6 trade), a second reconnect driver, any token-push path
(pull-on-demand is the contract; `tokenUpdate` is deleted in step 5),
provisioning UI on the control channel, and any multi-bridge machinery.

## Cleanup assessment

- Step 1: delete `docs/desktop/` (superseded; git history preserves).
- Step 5: delete dead control protocol (`provisionProgress`, `restart`,
  `tokenUpdate`, `ControlProvisionNotifier`, mirror DTOs, bridge receiver
  paths, client dispatcher branches).
- Step 10: delete `AuthGateCubit`'s post-fence re-clear workaround.
- Step 12: delete `bridge/app/tool/dev_control_host.dart`.
- Steps 14–19: moved code is deleted at origin in the same PR (no dual copies).

## Risks and accepted trade-offs

- **GUI crash ⇒ bridge down** until relaunch (C6): accepted; revisit only with
  evidence.
- **Internet required for the cockpit against a same-machine bridge** (D3):
  accepted; supervision keeps working offline; loopback stays a recorded
  future consideration.
- **Single relay slot** (C9): desktop autostart makes two-bridge households
  more common; takeover UX degrades gracefully. Stage C multi-bridge is a
  roadmap decision outside this plan.
- **Extraction regression risk (steps 14–19)** is the plan's main risk:
  mitigated by slice-per-PR with mobile analyze/tests green per step, device
  regression at MT gate C, and the `session_split` adaptive precedent.
- **In-flight UI series overlap** (`claude-inline-subtasks`, drafts touching
  composer/attachments): sequence extraction slices after checking each
  series' state at implementation time; never move a screen mid-flight under
  an active series without rebasing agreement.
- **Windows/Linux verification depth** is limited pre-distribution (recorded
  reduction above).
