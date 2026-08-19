# Surface the Hermes Configured Model in Sesori (Model Visibility)

## Status

- **Plan slug:** `hermes-model-visibility`
- **Status:** active (plan authored; awaiting owner approval before implementation)
- **Plan date:** 2026-08-19
- **Owner issue:** `eexxio/sesori_apps_monorepo#1` — "Hermes harness: cannot see/select the models provided by the Hermes integration"
- **Implementation base:** current `origin/main` (`983d5b44`)
- **Delivery:** small PR series (plan PR first, then implementation PRs)

## Goal

When a user creates a new session for the **Hermes Agent** harness in Sesori, the
new-session screen's model picker is currently **empty** — the user cannot see
which model the session will run, or choose one. Make Hermes surface its models
so the picker shows the **active model** (visibility) **and lets the user pick a
different model** (switching), per owner decision 2026-08-19 ("both").

Non-goal: as owner approved, switching is in scope, but only within what Hermes's
ACP surface supports (verify; see Scope below). Hermes remains authoritative over
its model config — Sesori reads the available models and issues the switch, it
does not claim to own/install models.

## Current Context (verified against `origin/main`, 2026-08-19)

- `bridge/sesori_plugin_hermes/lib/src/hermes_plugin_impl.dart` is a policy-only
  `AcpPlugin` subclass. Its doc comment states *"Version 1 uses Hermes's
  configured model/mode rather than exposing a picker."* It does **not** override
  `captureSessionConfig` (base `AcpPlugin.captureSessionConfig` is a no-op).
- `bridge/sesori_plugin_acp/lib/src/acp_session_options_service.dart`
  `getSessionOptions()` synthesizes a single `PluginProvider` (with one
  `PluginModel`) **only when** `_configurationTracker.processDefaults.modelId`
  is non-null. When the tracker has no model, `providers:` is `[]`.
- `AcpSessionConfigurationTracker.processDefaults` is populated exclusively via
  `setProcessDefaults(modelId:…, providerId:…)`. Callers today: the **Cursor**
  plugin (`cursor_plugin_impl.dart:185`) and the **OMP** plugin
  (`omp_session_options_service.dart:31`). **Hermes never calls it.**
- The client model picker (`client/module_core/lib/src/utils/model_filter/`)
  renders sections only from `ProviderInfo` models where `isAvailable` is true;
  an empty provider set renders an empty picker (confirmed in the 2026-08-18 iOS
  E2E — "the new-session screen populated no model list for Hermes").
- Hermes's configured model/provider is reported by `hermes status` as
  `Model:` / `Provider:` lines (see skill `references/hermes-acp-surface.md`;
  e.g. `Model: deepseek-v4-flash` / `Provider: OpenCode Go`). The ACP
  `initialize` handshake advertises the configured `AuthMethodAgent` but no
  explicit model catalog, so the model is not currently threaded into the
  configuration tracker.

## Root Cause

The model-picker data path in the base ACP stack is fully wired: override
`captureSessionConfig` → `setProcessDefaults` → `AcpSessionOptionsService`
synthesizes a provider → client renders the model. Every menu-bearing harness
(Cursor, OMP) walks this path. Hermes is policy-only and never populates the
tracker, so `providers:` stays `[]` and the picker has nothing to show.

## Proposed Approach

Add a minimal override in the Hermes plugin that captures the Hermes-configured
model into the configuration tracker, mirroring OMP's simpler pattern (no
separate catalog service, plus switching via the Hermes ACP surface):

1. Extend the Hermes plugin to record the Hermes-configured model/provider
   (visibility) and to enumerate the models Hermes can run (catalog for the
   picker).
2. Override `captureSessionConfig` to call
   `_configurationTracker.setProcessDefaults(modelId: …, providerId: …)` and seed
   the provider catalog, so the picker shows the active model.
3. **Switching:** the plugin must (a) list the available Hermes models and (b)
   apply a user-selected model, mirroring Cursor's `applyTurnSelection` override
   that issues `session/set_model` / `session/set_config_option` before a turn.
   **Verify Hermes's exact ACP model surface first** (see Step R below) — the
   upstream plan asserts Hermes implements `session/set_model`,
   `session/set_mode`, and `session/set_config_option`; confirm the payload shape
   against the real Hermes source before building.
4. Add unit tests (parser, capture, catalog, switch) + a live smoke check, and
   update the regression corpus (`docs/regression/session-creation-and-options.md`)
   which currently claims "no model list for Hermes."

### Where models come from (decision — RESOLVED by research, see "Research" below)

- **Active model + catalog (visibility):** use Hermes's ACP `session/new` (and
  resume/fork) response `models` field directly — `SessionModelState` with
  `availableModels[]` (each `ModelInfo`: `modelId` = `provider:model`, `name`,
  `description`) and `currentModelId`. This is Hermes's *same* inventory used by
  `hermes model` / the TUI / dashboard (via `hermes_cli.inventory`); no separate
  `hermes status` probe needed for the catalog. If no models are advertised,
  capture a no-op.
- **Switching:** issue ACP `session/set_model` with `{modelId: <chosen>, sessionId: ...}`
  (id is the encoded `provider:model`, resolved by Hermes via `parse_model_input`).

## Research (Step R — verified 2026-08-19 against Hermes source
`~/.hermes/hermes-agent`, shell v0.20.4)

Confirmed from `acp_adapter/server.py` and the `acp` Python package
(`venv/.../site-packages/acp`):

- Hermes **implements the full model surface over stock ACP**: wire methods
  `session/set_model`, `session/set_mode`, `session/set_config_option` (mapping
  in `acp/meta.py` `AGENT_METHODS`).
- `session/new` / `session/resume` / `session/fork` each return a `models`
  field = `SessionModelState { availableModels: ModelInfo[], currentModelId }`
  (built by `_build_model_state`, lines 731–977). `ModelInfo` =
  `{ modelId, name, description }`; `modelId` is Hermes-encoded
  `provider:model` (e.g. `opencode-go:deepseek-v4-flash`), `name` =
  `"Provider · model"`.
- `set_session_model(model_id, session_id)` (server.py:2570) resolves
  `provider:model` via `_resolve_model_selection`/`parse_model_input`, rebuilds
  the agent, persists the session, and returns an empty
  `SetSessionModelResponse`. It accepts the same encoded `modelId` the
  `session/new` `models` list exposes.
- ACP request contract: `SetSessionModelRequest {modelId, sessionId}` →
  `SetSessionModelResponse {}`.
- Sesori today: `AcpNewSessionResult` (acp_protocol.dart:185) parses only
  `sessionId`/`modes`/`configOptions` + `raw` — the `models` field is dropped.
  `AcpMethods` (acp_protocol.dart:16) lacks `session/set_model` (it has
  `sessionSetConfigOption` only). `AcpSessionConfigRepository` shows the
  `_client.request` pattern for issuing a config write.
- Conclusion: **both visibility and switching are fully supported over stock
  ACP** — no `~/.hermes/config.yaml` parsing or CLI shell-out required.
  Implementation is confined to `sesori_plugin_hermes` (+ a tiny protocol
  addition for the `session/set_model` method name + a model-write helper).


## File Impact (predicted)

- `bridge/sesori_plugin_acp/lib/src/acp_protocol.dart` — add
  `sessionSetModel` constant + parse the `models` (`SessionModelState`) field
  into `AcpNewSessionResult` (small, ACP-generic).
- `bridge/sesori_plugin_acp/lib/src/acp_session_config_repository.dart` (or a
  Hermes-local repo) — add a `setModel(sessionId, modelId)` that issues
  `session/set_model` via the existing `_client.request` pattern.
- `bridge/sesori_plugin_hermes/lib/src/hermes_plugin_impl.dart` — override
  `captureSessionConfig` (seed `setProcessDefaults` + model catalog from the
  `models` field) and `applyTurnSelection` (issue `session/set_model`).
- `bridge/sesori_plugin_hermes/lib/src/` (new) — Hermes model-state parser
  (catalog DTO) + any model-write service; reuse `AcpSessionOptionsService`.
- `bridge/sesori_plugin_hermes/test/` — parser/capture/switch unit tests.
- `bridge/sesori_plugin_hermes/tool/live_smoke_test.dart` — assert populated
  catalog and a real switch against the live binary.
- `docs/regression/session-creation-and-options.md` — update the Hermes entry.
- `.plan/hermes-model-visibility/` — this plan + tracker.

## Planned Steps

1. Plan PR: add `.plan/active/hermes-model-visibility/{PLAN,TRACKER}.md`
   (this document). Open plan PR against the fork.
2. **R (research):** verify Hermes's exact ACP model surface against the real
   `hermes` binary/source — does `session/set_model` exist, what is its payload,
   and how are available models enumerated (configOptions vs config aliases vs
   CLI)? Record findings; freeze the switch + catalog design.
3. `feat(hermes)`: resolve the Hermes configured model (status-probe parser),
   enumerate available models, and add `captureSessionConfig` that seeds
   `setProcessDefaults` + the catalog. Unit tests: parser, capture, catalog.
4. `feat(hermes)`: add `applyTurnSelection` override that applies a selected
   model via Hermes's ACP set-model path. Unit tests: switch applied, default
   fallback, reject-unselected.
5. `test(hermes)`: extend `tool/live_smoke_test.dart` to assert populated
   options and a real model switch against the live binary.
6. `docs(hermes)`: update `docs/regression/session-creation-and-options.md`
   (models surfaced and switchable within Hermes's ACP surface).
7. Live verification on this VPS (real `hermes` binary), then PR series to the
   fork targeting upstream `main`.

## Verification / Acceptance

- `dart analyze --fatal-infos` clean in `bridge/sesori_plugin_hermes/`.
- `dart test` green in `bridge/sesori_plugin_hermes/`.
- Live: Hermes new-session options yield a provider with the active model
  (e.g. `deepseek-v4-flash` on this VPS).
- Live: selecting a different model in the picker issues the Hermes switch and
  the next turn runs on the selected model.
- `docs/regression/session-creation-and-options.md` reflects surfaced + switchable
  models.

## Risks / Tradeoffs / Open Questions

- **Hermes ACP set-model surface is the critical unknown.** The upstream plan
  asserts `session/set_model` / `set_mode` / `set_config_option` exist; if the
  payload differs or switching is unsupported, the switch half must fall back to
  "read hermes config, write selection, instruct re-init" or be scoped back to
  visibility + documented. Gate Step 4 on Step 2 (research) findings.
- **Scope discipline:** visibility is small; switching is a second, real feature.
  Both are in scope now, but switching is bounded by what Hermes's ACP surface
  supports — do not invent unsupported set-model wire calls.
- **Probe cost:** `hermes status` spawn is cheap but not free; run it lazily at
  capture/ensureRuntime, not per-frame.
- **Catalog source risk:** if Hermes does not advertise an available-model list
  over ACP, enumerating models may require parsing `~/.hermes/config.yaml`
  aliases or a `hermes` CLI `models` command — confirm and record in Step 2.

