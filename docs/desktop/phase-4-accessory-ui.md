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

**Per-PR template:** Goal · Scope · Risk · Review-size · Acceptance · DoD ·
Aristotle verdicts · Findings log · Plan-deltas.

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
- **Acceptance:** voice capture works on mobile via the seams; no service/API
  logic lands in `module_app_ui`; no cycle.

## PR 4.3 — Move login/splash
- **Goal:** Push DI/routing out of `splash_screen.dart`/login screens, then move.
- **Risk:** Med. **Size:** M.
- **Acceptance:** mobile login/splash unchanged; no cycle.

## PR 4.4 — Move project_list + session_list
- **Goal:** Decouple app DI/routing, then move.
- **Risk:** Med. **Size:** M.
- **Acceptance:** mobile lists unchanged; no cycle.

## PR 4.5 — Move session_detail + session_diffs + new_session
- **Goal:** Decouple app DI/routing/app-owned widgets, then move the heavier
  session screens. **Split further if >size cap.**
- **Risk:** Med. **Size:** M (split if needed).
- **Acceptance:** mobile session screens unchanged; no cycle.

## PR 4.6 — Move settings
- **Goal:** Decouple app DI/routing out of `settings_screen.dart`, then move.
- **Risk:** Low-Med. **Size:** S-M.
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
- **Acceptance:** desktop shows projects/sessions/chat through the relay; the
  bridge-offline state offers "start the bridge" (drives `BridgeProcessService`),
  not a CLI-install/reconnect prompt; mobile offline UX unchanged; no
  `module_app_ui` import of `client/app`, `client/desktop`, or
  `module_desktop_core`.
