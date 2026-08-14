# Hermes Agent Harness Plugin

## Status

- **Plan slug:** `hermes-agent-plugin`
- **Status:** Step 1/9 plan PR open
- **Plan date:** 2026-08-13
- **Plan delivery:** this document and `TRACKER.md` are Step 1/9
- **Implementation base:** `origin/main`
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Delivery:** one planning PR, four bridge PRs, one client branding PR, one regression-doc PR, one verification PR, one retirement PR — nine in total

## Goal

Add **Hermes Agent** (Nous Research) as a monitored and controllable coding backend in Sesori, alongside OpenCode, Codex, Cursor, and Claude Code. Users with the Hermes CLI installed can then see live Hermes sessions, stream turns, replay history, answer permission prompts, and send prompts from the phone app — through the existing relay/bridge path, with no new client surface.

## Why ACP

Hermes ships a **standard ACP v1 server** (`hermes acp`, adapter protocol version 0.20.0, `PROTOCOL_VERSION = 1`). Sesori already has a mature ACP plugin base (`sesori_plugin_acp`) that Cursor and Oh My Pi are built on. The Hermes adapter therefore reduces to a Cursor-style thin plugin: a launch spec that spawns `hermes acp` over stdio, a policy layer, and a descriptor. No new transport, protocol, or client work.

### Verified Hermes ACP surface (2026-08-13, `hermes acp --version` → 0.20.0)

`initialize` advertises `load_session`, `session_capabilities {fork, list, resume}`, `prompt_capabilities {image}`; server implements `initialize`, `authenticate` (provider + `hermes-setup` terminal method), `session/new`, `session/load` (history replay via `session/update` notifications), `session/resume`, `session/list`, `session/cancel`, `session/prompt`, `session/request_permission` (via approval callback). It does **not** implement `session/close`, `session/set_config_option`, or `elicitation/create`.

### How the gaps are handled

- `session/close` absent → the ACP base only calls close when the agent advertises `closeSession` (Hermes does not) and otherwise tears the session down locally. Safe.
- `set_config_option` / elicitation absent → base `applyTurnSelection` is a no-op and `supportsFormElicitation` returns false; permissions flow through `session/request_permission`, which the base approval registry handles.
- No managed runtime → the plugin resolves `hermes` on PATH (direct-CLI posture, like Cursor without its managed install). `ensureRuntime` is a probe, never a download.

## Architecture

```
Phone ── relay ── bridge ── sesori_plugin_hermes ── spawns ── hermes acp (stdio JSON-RPC)
                        └── AcpPlugin (base): sessions, prompts, permissions,
                            projects derived from session cwd, SSE events
```

New package `bridge/sesori_plugin_hermes/` (name `hermes_plugin`), modeled on `sesori_plugin_cursor`:

| File | Responsibility |
|---|---|
| `lib/hermes_plugin.dart` | package export (`HermesPlugin`, `HermesPluginDescriptor`, `HermesBinary`) |
| `lib/src/hermes_binary.dart` | `defaultBinary = "hermes"`; builds `AcpLaunchSpec(command: hermes, args: ["acp"])`; env passthrough (auth via configured provider) |
| `lib/src/hermes_identity.dart` | pluginId `hermes`, displayName `Hermes Agent`, provider id `hermes` |
| `lib/src/hermes_plugin_impl.dart` | `HermesPlugin` extends `AcpPlugin`; policy getters below |
| `lib/src/runtime/hermes_plugin_descriptor.dart` | const descriptor: `--hermes-bin` option, runtime probe, `inspectSetup`, `start` |
| `lib/src/runtime/hermes_runtime_manifest.dart` | `minPathVersion` gate (0.20.0 — the adapter version verified) |
| `test/…` | descriptor availability/setup tests + plugin tests with `FakeAcpProcess` |

### `HermesPlugin` policy (extending `AcpPlugin`)

- `clientName` `sesori-bridge`, `clientVersion` `0.0.0`
- `authMethodId` `null` (use Hermes's first advertised method; `authenticate` succeeds when a provider is configured)
- `initializeCapabilityMeta` `null`
- `supportsFormElicitation` `false`; `serializesPromptsProcessWide` `false`; `failsTurnOnSelectionError` `false`
- `sessionCloseSettlementTimeout` `Duration(seconds: 5)`
- default `AcpApprovalRegistry`, default `AcpEventMapper`, base `AcpSessionOptionsService` (single `hermes` agent; model surfaces from session/update once the config tracker records it)
- `supportsPromptAttachments: true` — Hermes advertises `PromptCapabilities(image: true)`; the phone attachment flow works without extra work

### Descriptor

- `id` `hermes`, `displayName` `Hermes Agent`, `projectOwnership` bridgeDerived, `sessionOptionsScope` plugin
- Option: `--hermes-bin` (bare name `bin`, default `hermes`)
- `ensureRuntime`: no-op when `--hermes-bin` set; otherwise probe `hermes acp --version` on PATH (parse via shared `SemanticVersion`), gate on `minPathVersion`
- `inspectSetup`: probe binary (missing → `PluginSetupRuntimeMissing` with install hint; outdated → unavailable hint); then `hermes status` auth probe — configured `Model:`/`Provider:` line → `PluginSetupReady`, else `PluginSetupAuthenticationRequired` ("configure a model with `hermes setup`/`hermes model`"); probe failures → `PluginSetupUnknown`
- `start`: build `HermesPlugin`, wrap in `AcpBridgePlugin`, eager bounded connect (Cursor pattern), abort rollback
- No `install`/managed-runtime capability (Hermes installs via its own installer; not Sesori's job)

### Registration (activation step)

- `app/lib/src/bridge/runtime/plugin_registry.dart` `knownPlugins` += `HermesPluginDescriptor()`
- `app/pubspec.yaml` dependency on `hermes_plugin`; `bridge/pubspec.yaml` workspace += `sesori_plugin_hermes`; `bridge/Makefile` `MODULES` += `sesori_plugin_hermes`
- Identity: plain `hermes` pluginId (precedent: pi/omp are not in the `Harness` enum)

### Client branding (step 6/9)

The mobile/desktop client is backend-neutral by convention and renders the
harness list, chooser, and settings from the bridge-provided `displayName`
("Hermes Agent" appears automatically). The only per-harness layer is
`PregoBrandLogo` (module_prego), which falls back to a generic plug icon +
raw pluginId for unknown ids. Step 6/9 brands it:

- `shared/sesori_shared` `Harness` enum += `hermes` (no exhaustive switches exist; safe)
- `module_prego/assets/svgs/brands/hermes_{light,dark}.svg` — the official
  Hermes staff mark (traced from the hermes-agent website favicon `⚕` glyph,
  U+2695) in brand blue `#1E3A8A` (light theme) / `#A8C0F0` (dark theme)
- `PregoBrandLogo._assetFor` + `displayNameFor` cases → "Hermes Agent"
- `prego_brand_logo_test.dart` mapping entry + display-name assertion

## Delivery Steps

| Step | PR title | Scope |
|---|---|---|
| 1/9 | `🌱 [hermes-plugin] docs: plan Hermes Agent harness support [step 1/9]` | PLAN.md + TRACKER.md |
| 2/9 | `🌱 [hermes-plugin] feat(hermes): scaffold the ACP plugin package [step 2/9]` | pubspec, analysis_options, export, identity, binary/launch spec |
| 3/9 | `⚙️ [hermes-plugin] feat(hermes): add the ACP plugin core [step 3/9]` | `HermesPlugin` (policy layer) + plugin tests with `FakeAcpProcess` |
| 4/9 | `⚙️ [hermes-plugin] feat(hermes): add descriptor, runtime probe, and setup [step 4/9]` | descriptor, manifest, probe, `inspectSetup`, `start`, descriptor tests |
| 5/9 | `⚙️ [hermes-plugin] feat(hermes): register the plugin in the bridge [step 5/9]` | plugin_registry, app pubspec, workspace pubspec, Makefile |
| 6/9 | `⚙️ [hermes-plugin] feat(client): brand the Hermes harness [step 6/9]` | `Harness` enum += `hermes`, brand SVGs, `PregoBrandLogo` cases, tests |
| 7/9 | `⚙️ [hermes-plugin] docs: document Hermes harness behavior [step 7/9]` | `docs/regression/` feature doc (plugin-setup-and-lifecycle + session-turns touch points) |
| 8/9 | `🚧 [hermes-plugin] test(hermes): live-verify Hermes over ACP [step 8/9]` | live smoke test against the real `hermes acp` (already passing on the dev box); record E2E evidence |
| 9/9 | `🌱 [hermes-plugin] docs: retire the plan [step 9/9]` | move plan to `.plan/completed/`, record E2E outcome |

## Risk and test focus

- **Protocol drift**: Hermes ACP is fast-moving. `minPathVersion` gates it; verification step re-checks the surface.
- **Missing `session/close` / `set_config_option`**: covered by capability negotiation in the base; tests assert no close/set_config calls are attempted.
- **Auth probe heuristics**: `hermes status` parsing is best-effort; `PluginSetupUnknown` fallback keeps setup honest, and connect-time failure degrades the plugin without killing the bridge.
- **Session cleanup**: backend-side deletion of Hermes sessions is out of scope (no ACP delete surface); bridge rows are authoritative, same as Cursor/Claude.
- **Security**: plugin only spawns the user's own `hermes` binary with inherited environment; no new network surface, no managed downloads.

## Expected result

`sesori-bridge` runs Hermes as an eligible, setup-aware harness: ready when a configured Hermes install exists on PATH, runtime-missing when not, and — when enabled — live sessions, streamed turns, history replay, permission cards, and prompt sending from the phone, all through the existing ACP machinery with no client changes.
