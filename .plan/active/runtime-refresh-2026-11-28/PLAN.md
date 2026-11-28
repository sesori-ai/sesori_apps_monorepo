# Runtime refresh, 2026-11-28

Status: active.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-26 refresh (`.plan/completed/runtime-refresh-2026-11-26/PLAN.md`); no earlier
`runtime-refresh-*` plan was still active. Three harnesses released since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-28.

| Harness | Target before | Candidate | Floor (unchanged) | Update |
|---|---|---|---|---|
| OpenCode | 2.4.2 | 2.4.2 (`@opencode/cli` npm `latest`) | PATH 1.14.0; v2 2.0.11 | None, already newest |
| Antigravity | 1.5.2 | 1.5.2 (ACP registry) | Exact package/server/ACP 1 pair | None, already newest |
| Codex | 0.172.0 | 0.172.0 (npm `latest`) | 0.139.0 | None, already newest |
| GitHub Copilot | 1.0.116 | 1.0.117 (npm `latest`) | 1.0.78 | Step 2 |
| Cursor | 2026.11.22-e9042b2 | 2026.11.22-e9042b2 (`cursor.com/install`) | date 2026.09.23 | None, already newest |
| Claude Code | 2.1.332 | 2.1.332 (`v2.1.332`, npm `latest`) | 2.1.221 | None, already newest |
| Hermes Agent | 0.23.4 | 0.23.5 (`v0.23.5`) | 0.20.0 | Step 3 |
| Pi | 1.6.1 | 1.7.0 (`v1.7.0`, npm `latest`) | 0.99.0 | Step 4 |
| Oh My Pi | 19.2.1 | 19.2.1 (`v19.2.1`) | 17.2.13 | None, already newest |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | dsh `next` 0.2.2-rc.5 | 0.1.5 | None, already newest |
| Grok Build | 1.0.92 | 1.0.92 (`x.ai/cli/stable`) | 1.0.5 | None, already newest |

## Steps

1. This plan, docs-only.
2. GitHub Copilot 1.0.116 → 1.0.117.
3. Hermes Agent 0.23.4 → 0.23.5.
4. Pi 1.6.1 → 1.7.0.
5. Retire this plan and add the dated run to the regression doc's intro.

Steps 2–4 touch separate plugin packages and run in parallel.

## Findings

Filled in as the steps land.

## Follow-ups

Carried from earlier runs: see the follow-ups of `.plan/completed/runtime-refresh-2026-11-26/PLAN.md`.
