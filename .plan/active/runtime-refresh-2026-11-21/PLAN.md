# Runtime refresh, 2026-11-21

Status: active.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-20 refresh (`.plan/completed/runtime-refresh-2026-11-20/PLAN.md`); no earlier
`runtime-refresh-*` plan is still active. Two harnesses released since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-21.

| Harness | Target before | Candidate | Floor (unchanged) | Update |
|---|---|---|---|---|
| OpenCode | 2.3.2 | 2.3.2 | PATH 1.14.0; v2 2.0.11 | None, already newest |
| Antigravity | 1.5.0 | 1.5.2 (registry commit `e29b5bf3`; per-archive `sha256` published for all six ZIPs) | Exact package/server/ACP 1 pair | Step 2 |
| Codex | 0.171.0 | 0.171.0 | 0.139.0 | None, already newest |
| GitHub Copilot | 1.0.114 | 1.0.114 | 1.0.78 | None, already newest |
| Cursor | 2026.11.19-f005e9d | 2026.11.19-f005e9d | date 2026.09.23 | None, already newest |
| Claude Code | 2.1.330 | 2.1.330 | 2.1.221 | None, already newest |
| Hermes Agent | 0.23.3 | 0.23.3 | 0.20.0 | None, already newest |
| Pi | 1.6.0 | 1.6.0 | 0.99.0 | None, already newest |
| Oh My Pi | 19.0.1 | 19.1.0 (minor; `SHA256SUMS.txt` and GitHub digests for all eight binaries) | 17.2.13 | Step 3 |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest |
| Grok Build | 1.0.92 | 1.0.92 | 1.0.5 | None, already newest |

## Steps

1. Plan (this document), docs-only.
2. Antigravity 1.5.0 → 1.5.2: registry commit, package/agent/server facts, six archive hashes checked
   against the registry's `sha256` and independent downloads. Re-probe identity, protocol,
   capabilities and auth methods offline; re-check the client-identity model gate.
3. Oh My Pi 19.0.1 → 19.1.0: eight binary digests. Audit the ACP seam across the minor release,
   especially MCP servers moving into the omp daemon (the shared daemon's markers and stop
   path from #2861), the `ask` tool becoming one HTML-form request (form elicitation), remote
   session model controls, and the removed `google-gemini-cli` provider. Re-run the
   model-restore probe.
4. Retire this plan to `.plan/completed/` with findings and follow-ups; add the dated run to
   the regression doc's intro; fix any skill or reference errors found.

Steps 2 and 3 touch different plugin packages and run in parallel; they share only their own
rows in `docs/HARNESS_CAPABILITIES.md` and `docs/regression/plugin-setup-and-lifecycle.md`.
