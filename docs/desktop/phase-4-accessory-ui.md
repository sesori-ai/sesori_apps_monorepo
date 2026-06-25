# Phase 4 — Accessory UI (v1.x)

> Goal: extract the accessory screens out of `client/app` (the renamed mobile
> app) into a shared `client/module_app_ui` Flutter library, then wire that full
> UI (projects/sessions/chat) into the desktop window. Per-feature moves keep the
> diffs reviewable and keep `client/app` green.

**Standing acceptance (all Phase 4 PRs):** `client/app` (the mobile product) builds + tests pass + a
mobile release dry-run passes after each PR (release-safety invariant #2). No UI
behaviour change for mobile.

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
  tests pass, **no dependency cycle** `module_app_ui` → `client/app`.

## PR 4.2 — Move voice capture UI
- **Goal:** Move `capabilities/voice/` UI (plugin deps: `record`, `wakelock_plus`).
- **Risk:** Med. **Size:** M.
- **Acceptance:** voice capture works on mobile via the package.

## PR 4.3 — Move login/splash
- **Risk:** Med. **Size:** M.
- **Acceptance:** mobile login/splash unchanged.

## PR 4.4 — Move project_list + session_list
- **Risk:** Med. **Size:** M.
- **Acceptance:** mobile lists unchanged.

## PR 4.5 — Move session_detail + session_diffs + new_session
- **Goal:** Move the heavier session screens. **Split further if >size cap.**
- **Risk:** Med. **Size:** M (split if needed).
- **Acceptance:** mobile session screens unchanged.

## PR 4.6 — Move settings
- **Risk:** Low-Med. **Size:** S-M.
- **Acceptance:** mobile settings unchanged.

## PR 4.7 — Desktop router composition + wire accessory UI into window
- **Goal:** Compose the desktop GoRouter from the shared screens; render the full
  accessory UI in the desktop window via the relay.
- **Risk:** Med. **Size:** M.
- **Acceptance:** desktop shows projects/sessions/chat through the relay.
