# Runtime refresh, 2026-11-23

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-21 refresh (`.plan/completed/runtime-refresh-2026-11-21/PLAN.md`); no earlier
`runtime-refresh-*` plan was still active. Three harnesses released since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-23.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.3.2 | 2.4.1 (npm `latest`, tag `v2.4.1`; 2.4.0 skipped) | PATH 1.14.0; v2 2.0.11 | Step 2 | Pending |
| Antigravity | 1.5.2 | 1.5.2 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.171.0 | 0.171.0 | 0.139.0 | None, already newest | — |
| GitHub Copilot | 1.0.114 | 1.0.114 | 1.0.78 | None, already newest | — |
| Cursor | 2026.11.19-f005e9d | 2026.11.22-e9042b2 | date 2026.09.23 | Step 3 | Pending |
| Claude Code | 2.1.330 | 2.1.330 | 2.1.221 | None, already newest | — |
| Hermes Agent | 0.23.3 | 0.23.3 | 0.20.0 | None, already newest | — |
| Pi | 1.6.0 | 1.6.0 | 0.99.0 | None, already newest | — |
| Oh My Pi | 19.1.0 | 19.1.1 | 17.2.13 | Step 4 | Pending |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.92 | 1.0.92 | 1.0.5 | None, already newest | — |

## Steps

1. Plan, docs-only (this PR).
2. OpenCode 2.3.2 → 2.4.1.
3. Cursor 2026.11.19-f005e9d → 2026.11.22-e9042b2.
4. Oh My Pi 19.1.0 → 19.1.1.
5. Retire this plan and add the dated run to the regression doc's intro.

Steps 2–4 touch separate plugin packages and run in parallel; they share only adjacent rows in
`docs/HARNESS_CAPABILITIES.md` and `docs/regression/plugin-setup-and-lifecycle.md`.
