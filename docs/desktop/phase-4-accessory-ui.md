# Phase 4 — Accessory UI (v1.x)

> Goal: extract the accessory screens out of `client/app` (the renamed mobile
> app) into a shared `client/module_app_ui` Flutter library, then wire that full
> UI (projects/sessions/chat) into the desktop window. Per-feature moves keep the
> diffs reviewable and keep `client/app` green.

**Standing acceptance (all Phase 4 PRs):** `client/app` (the mobile product) builds + tests pass + a
mobile release dry-run passes after each PR (release-safety invariant #2). No UI
behaviour change for mobile. `module_app_ui` may depend on `module_core`,
`module_prego`, `sesori_shared`, and direct Flutter UI dependencies, but it must
never import `client/app`, `client/desktop`, or `module_desktop_core`.

**Per-PR template:** Goal · Scope · Risk · Review-size · **Regression guide** ·
Acceptance · DoD (incl. PLAN.md §9 row + pointer advanced) · Aristotle verdicts ·
Findings log · Plan-deltas.

> **Regression guide** = the blast radius of the PR. For Phase 4 the recurring
> blast radius is **mobile UI behaviour** — every move PR relocates code the
> mobile app renders today, so each guide names the mobile screens/flows to
> manually re-verify on a device (moves rarely have widget-test coverage for the
> coupling being refactored).

---

## PR 4.1 — Create `client/module_app_ui` + move shared leaf UI
- **Goal:** New Flutter library package; move genuinely-shared leaf UI
  (`core/extensions/`, `l10n/`, `status_colors`/`constants`, and the truly
  leaf widgets).
- **Important — `core/widgets/` is NOT all leaf UI.** Verified: e.g.
  `connection_overlay.dart` imports app DI (`../di/injection.dart`) and routing
  (`../routing/app_router.dart`) + `go_router`; several widgets import
  `flutter_markdown_plus`/`flutter_svg`/`vector_graphics`/`sesori_shared`. Moving
  the directory wholesale would create a **package cycle back into `client/app`**
  or fail to resolve imports. So this PR (or a precursor split PR) must first
  **refactor app-coupled widgets** (push DI/routing dependencies out via
  params/callbacks) and **declare the legitimate direct package deps**
  (`go_router`, `flutter_svg`, etc.) in `module_app_ui`'s pubspec.
- **Risk:** Med-High. **Size:** M (split the refactor out if it grows).
- **Regression guide:** the connection overlay + shared widgets render on
  virtually every mobile screen. Check on a device: (1) connection overlay
  states — connecting, bridge-offline banner (never-registered vs registered),
  connection-lost with logout action (`router.goRoute(login)` still fires via
  the injected callback); (2) l10n still resolves (moved `l10n/` regenerates);
  (3) markdown/code-block rendering in a real session; (4) `flutter build ios`
  + `apk` + release dry-run green; (5) desktop CI picks up `module_app_ui`
  paths.
- **Acceptance:** `client/app` consumes the moved code via the package, builds +
  tests pass, **no dependency cycle** `module_app_ui` → `client/app`; mobile
  CI/release path filters include `client/module_app_ui/**` once mobile screens
  depend on the package.

> **Standing rule for every move PR (4.2–4.6):** the package-boundary hazard
> from PR 4.1 applies to **screens too** — current screens (e.g.
> `splash_screen.dart`, `settings_screen.dart`, session-detail widgets) import
> app DI / routing / app-owned widgets directly. **Each move PR must first push
> those couplings out** (DI/routing behind constructor params or callbacks;
> depend on the shared widgets already in `module_app_ui`) and declare the
> screen's legitimate direct package deps, so no move creates a cycle back to
> `client/app` or leaves unresolved relative imports. Every move PR's acceptance
> includes **"no `module_app_ui` → `client/app` cycle."**

## PR 4.2 — Voice: move only real UI; keep services behind module_core seams
- **Goal:** Note that `client/app/lib/capabilities/voice/` is **not UI** — it's
  injectable services/config (`VoiceTranscriptionService` (which calls the
  Layer-1 `VoiceApi` directly), `WakeLockService`, `RecordingFileProvider`,
  `audio_format_config`). So this PR must **not** move that directory into the
  shared UI package (it would drag app/service/platform logic + direct API access
  across the boundary). Instead: identify the actual **voice widgets** (if any)
  to move into `module_app_ui`, and first relocate the voice **lifecycle** behind
  proper `module_core` service/repository + platform seams (recording stays a
  Flutter platform adapter). If there are no shared voice widgets, this PR is just
  the seam relocation.
- **Risk:** Med. **Size:** M.
- **Regression guide:** voice is the most platform-coupled mobile capability.
  Check on **both** iOS and Android devices: record → stop → upload →
  transcription lands in the composer; wake-lock held during recording and
  released after; permission-denied path unchanged; background/interruption
  (incoming call) behaviour unchanged; no `VoiceApi` call moves out of the
  Layer-1 seam.
- **Acceptance:** voice capture works on mobile via the seams; no service/API
  logic lands in `module_app_ui`; no cycle.

## PR 4.3 — Move login/splash
- **Goal:** Push DI/routing out of `splash_screen.dart`/login screens, then move.
- **Risk:** Med. **Size:** M.
- **Regression guide:** splash owns the cold-start routing decision. Check on a
  device: (1) cold start logged-in → home, logged-out → login (splash stays
  local-only — no network calls creep in during the refactor); (2) full OAuth
  login round-trip incl. the browser return; (3) logout → back to login; (4)
  deep-link/notification-tap cold start still routes correctly after splash.
- **Acceptance:** mobile login/splash unchanged; no cycle.

## PR 4.4 — Move project_list + session_list
- **Goal:** Decouple app DI/routing, then move.
- **Risk:** Med. **Size:** M.
- **Regression guide:** these screens host the onboarding/bridge-offline flows.
  Check on a device: (1) never-registered onboarding (install commands view)
  still reachable and rendered from the shell via the injected strategy —
  `BridgeInstall` constants stay app-owned; (2) `reconnectBridge()` action
  works; (3) pull-to-refresh, list navigation → session detail, hidden-project
  handling; (4) live SSE updates still refresh the lists (no polling
  introduced by the decoupling).
- **Acceptance:** mobile lists unchanged; no cycle.

## PR 4.5 — Move session_detail + session_diffs + new_session
- **Goal:** Decouple app DI/routing/app-owned widgets, then move the heavier
  session screens. **Split further if >size cap.**
- **Risk:** Med. **Size:** M (split if needed).
- **Regression guide:** the product's core surface — regressions here are
  user-facing immediately. Check on a device: (1) live chat: streaming message
  updates, markdown/code blocks, tool output collapse; (2) composer: send,
  keyboard stays up on send / dismisses on menu taps (recent fix #353 —
  don't regress it), agent/model/variant pickers; (3) permission-question
  round-trip from a real assistant session; (4) diffs screen renders; (5) new
  session creation incl. worktree options; (6) voice entry point still works
  post-4.2.
- **Acceptance:** mobile session screens unchanged; no cycle.

## PR 4.6 — Move settings
- **Goal:** Decouple app DI/routing out of `settings_screen.dart`, then move.
- **Risk:** Low-Med. **Size:** S-M.
- **Regression guide:** check on a device: notification preference toggles
  persist and still register/unregister the FCM token; logout from settings
  works; account info renders; any platform-conditional rows (iOS vs Android)
  unchanged.
- **Acceptance:** mobile settings unchanged; no cycle.

## PR 4.7 — Desktop router composition + wire accessory UI into window
- **Goal:** Compose the desktop GoRouter from the shared screens; render the full
  accessory UI in the desktop window via the relay. This is the first desktop
  slice that resolves `ConnectionService`; register any remaining relay
  prerequisites (`RelayCryptoService`, `FailureReporter`, lifecycle hooks) before
  wiring shared screens.
- **Desktop offline/onboarding seam:** the shared screens' bridge-offline flow
  calls `ProjectListCubit.reconnectBridge()` (relay reconnect only) and shows
  `BridgeInstall` CLI commands (install `sesori-bridge` in a terminal) — both
  **wrong for desktop**, where the app *is* the bridge and should start the
  supervised helper. Introduce a desktop-specific seam/callback for
  offline/onboarding states so the desktop UI drives `BridgeProcessService` /
  control status (turn the bridge on) instead of showing mobile install/reconnect
  actions. (The shared screens accept this behaviour via injected
  callback/strategy so mobile keeps its current actions.)
- **Risk:** Med. **Size:** M.
- **Regression guide:** first desktop `ConnectionService` resolution — the DI
  blast radius is A15 ordering. Check: (1) desktop boots with relay
  prerequisites registered (`RelayCryptoService`, `FailureReporter`, lifecycle
  hooks) and lean-v1 flows (tray/control/login) still work with the relay
  client now live alongside them; (2) desktop relay connect coexists with the
  control channel (two concurrent connections, no shared-state clash); (3)
  mobile offline/onboarding UX unchanged (the injected strategy defaults to
  mobile behaviour); (4) desktop window resize/keyboard basics on the moved
  screens are usable (phone-shaped assumptions surface here — file follow-ups,
  don't silently ship broken).
- **Acceptance:** desktop shows projects/sessions/chat through the relay; the
  bridge-offline state offers "start the bridge" (drives `BridgeProcessService`),
  not a CLI-install/reconnect prompt; mobile offline UX unchanged; no
  `module_app_ui` import of `client/app`, `client/desktop`, or
  `module_desktop_core`.

---

## MT-5 — Manual checkpoint: accessory UI parity + mobile regression pass (user-run)

> Run after PR 4.7. Two halves: prove the desktop accessory UI is genuinely
> usable, and prove mobile survived the whole extraction phase. The mobile half
> doubles as the pre-release manual pass for the next mobile store release.

**Desktop half (dev build is fine):**

| # | Check | Pass looks like |
|---|---|---|
| 1 | Projects/sessions browse over the relay | lists load, live-update via SSE |
| 2 | Full chat round-trip | send a question from desktop, assistant streams back; permission prompt answerable |
| 3 | Bridge-offline seam | with the helper off: UI offers "start the bridge" and starting it recovers the UI (no CLI-install/reconnect prompt) |
| 4 | Internet-down behaviour | with the local bridge running but internet down: UI shows a truthful offline state (relay unreachable — known v1.x trade, Decision #2) |
| 5 | Window ergonomics smoke | resize, scroll, text selection, Enter-to-send vs newline — usable, no dead-end |

**Mobile half (real devices, both platforms):**

| # | Check | Pass looks like |
|---|---|---|
| 6 | Cold start → login → home | unchanged |
| 7 | Project/session lists + onboarding states | unchanged incl. never-registered install view |
| 8 | Session detail: chat, composer, pickers, diffs, new session | unchanged (the #353 keyboard behaviour included) |
| 9 | Voice message | record → transcribe → send works |
| 10 | Settings + notifications | prefs persist; push still arrives (completion notification) |
| 11 | Connection overlay states | connecting / bridge-offline / connection-lost all render + act correctly |
| 12 | Release dry-run | mobile release pipeline green on the final phase-4 state |

- **Aristotle:** n/a (no code). **Findings:** — **Deltas:** —
