# Hermes Agent Harness Plugin: Tracker

## Current State

- **Plan slug:** `hermes-agent-plugin`
- **Implementation base:** current `origin/main` (shallow clone; unshallowed before push)
- **Series state:** Steps 1–6 implemented locally, verified (unit + live E2E), PRs pending
- **Current step:** 1/9, plan PR to open
- **Plan PR:** (pending)
- **Next action:** open the Step 1 plan PR, then the implementation PRs in order

## Locked Decisions

`PLAN.md` is canonical. Execution must not reopen these without the user:

- Hermes support is an **ACP v1 stdio plugin** (`hermes acp`), reusing `sesori_plugin_acp` — not a state.db/transcript direct integration.
- **No managed runtime**: resolve `hermes` on PATH; `ensureRuntime` probes only, never downloads.
- pluginId is the plain string `hermes` (pi/omp precedent).
- **Client branding is IN scope** (user-directed 2026-08-13): `Harness` enum += `hermes`, brand SVGs, `PregoBrandLogo` cases — step 6/9.
- Backend-side session deletion is out of scope (no ACP delete surface); bridge rows are authoritative.
- Min supported ACP adapter version: **0.20.0** (the version verified on 2026-08-13).

## External Dependencies

- `sesori_plugin_acp` base: `AcpPlugin`, `AcpBridgePlugin`, `AcpLaunchSpec`, `AcpProcessFactory`, `AcpApprovalRegistry`, `AcpEventMapper`, `AcpSessionOptionsService` — no base changes expected for Steps 2–5; any base gap found during implementation goes through a prerequisite PR first.
- Hermes side: `hermes acp` requires a configured provider/model (out-of-band `hermes setup` / `hermes model`); plugin detects, never configures.
- Repo clone is shallow (depth 1): unshallow before pushing to avoid upload issues.

## Delivery Steps

| Done | Step | Exact PR title | Target | State |
|---|---|---|---:|---|
| [x] | 1/9 | `🌱 [hermes-plugin] docs: plan Hermes Agent harness support [step 1/9]` | ~1,200-1,500 | Ready for PR |
| [x] | 2/9 | `🌱 [hermes-plugin] feat(hermes): scaffold the ACP plugin package [step 2/9]` | 300-600 | Ready for PR (analyze+tests green) |
| [x] | 3/9 | `⚙️ [hermes-plugin] feat(hermes): add the ACP plugin core [step 3/9]` | 700-1,100 | Ready for PR (tests green) |
| [x] | 4/9 | `⚙️ [hermes-plugin] feat(hermes): add descriptor, runtime probe, and setup [step 4/9]` | 800-1,200 | Ready for PR (tests green) |
| [x] | 5/9 | `⚙️ [hermes-plugin] feat(hermes): register the plugin in the bridge [step 5/9]` | 100-300 | Ready for PR (full suite green) |
| [x] | 6/9 | `⚙️ [hermes-plugin] feat(client): brand the Hermes harness [step 6/9]` | 200-400 | Ready for PR (flutter tests green) |
| [ ] | 7/9 | `⚙️ [hermes-plugin] docs: document Hermes harness behavior [step 7/9]` | 200-500 | Not started |
| [x] | 8/9 | `🚧 [hermes-plugin] test(hermes): live-verify Hermes over ACP [step 8/9]` | 400-800 | Done locally (live E2E PASS 2026-08-13); PR pending |
| [ ] | 9/9 | `🌱 [hermes-plugin] docs: retire the plan [step 9/9]` | 100-300 | Not started |

## Verification Checklist (step 8/9 live gate)

- [ ] `GET /plugin` reports Hermes setup ready, display name `Hermes Agent`, prompt attachments true
- [ ] Missing runtime: `--hermes-bin /definitely/missing/hermes` → runtime missing + action hint; other harnesses stay ready
- [ ] New session: prompt streams and completes; session row appears
- [ ] Tool lifecycle: tool cards progress Running → Done (Hermes tool calls)
- [ ] Permission: a permission-requiring prompt renders a card; Once/Reject behaves
- [ ] History: restart bridge, reopen session → full history replays via `session/load`
- [ ] External session: a Hermes session started outside Sesori appears after enumeration
- [ ] Abort: stopping a long turn returns idle; pending permission clears
- [ ] Idle reap: after idle, respawn + resume works transparently
- [ ] Harness policy: disable/enable from Settings behaves
