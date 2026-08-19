# Hermes Model Visibility: Tracker

## Current State

- **Plan slug:** `hermes-model-visibility`
- **Owner review:** pending — plan authored 2026-08-19, awaiting owner approval
- **Current open PR:** none
- **Local successor:** none
- **Next action:** owner approves plan → open plan PR on the fork → implement Step 2

## Delivery

| Done | Step | PR | State |
|---|---|---|---|
| [ ] | 1/5 | pending | Plan PR: add `.plan/active/hermes-model-visibility/{PLAN,TRACKER}.md`. |
| [ ] | 2/5 | pending | Resolve Hermes configured model; `captureSessionConfig` seeds `setProcessDefaults`; unit tests. |
| [ ] | 3/5 | pending | Extend `tool/live_smoke_test.dart` to assert populated session options. |
| [ ] | 4/5 | pending | Update `docs/regression/session-creation-and-options.md` (model surfaced; no switching). |
| [ ] | 5/5 | pending | Live verification on VPS against real `hermes` binary; PR series to fork targeting upstream `main`. |

## Owner Decisions

- **Scope:** surface Hermes's *configured* model for visibility; do **not** add a
  Hermes model *switcher* in v1 (deferred until the ACP surface supports
  `session/set_model`-style contracts). [pending owner confirmation]
- **Model source:** status-probe of `hermes status` (`Model:` / `Provider:`
  lines) is the default; ACP-derived model is a fallback/extension, not v1.
  [pending owner confirmation]

## Root-Cause Evidence

- `hermes_plugin_impl.dart` does not override `captureSessionConfig` (base is a no-op).
- `AcpSessionOptionsService.getSessionOptions()` returns `providers: []` when
  `processDefaults.modelId` is null → empty model picker.
- Cursor (`cursor_plugin_impl.dart:185`) and OMP (`omp_session_options_service.dart:31`)
  populate the tracker via `setProcessDefaults`; Hermes never does.
- Confirmed empty model list for Hermes in the 2026-08-18 iOS E2E
  (recorded in `docs/regression/session-creation-and-options.md`).

## Verification Checklist

- [ ] `dart analyze --fatal-infos` clean in `bridge/sesori_plugin_hermes/`
- [ ] `dart test` green in `bridge/sesori_plugin_hermes/`
- [ ] Live: Hermes new-session options carry a provider with the active model
      (e.g. `deepseek-v4-flash`)
- [ ] `docs/regression/session-creation-and-options.md` updated
