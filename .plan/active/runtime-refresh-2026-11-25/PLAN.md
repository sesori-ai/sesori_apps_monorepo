# Runtime refresh, 2026-11-25

Status: active.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-24 refresh (`.plan/completed/runtime-refresh-2026-11-24/PLAN.md`); no earlier
`runtime-refresh-*` plan was still active. Three harnesses released since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-25.

| Harness | Target before | Candidate | Floor (unchanged) | Update |
|---|---|---|---|---|
| OpenCode | 2.4.1 | 2.4.1 | PATH 1.14.0; v2 2.0.11 | None, already newest |
| Antigravity | 1.5.2 | 1.5.2 | Exact package/server/ACP 1 pair | None, already newest |
| Codex | 0.172.0 | 0.172.0 (`rust-v0.172.0`, npm `latest`) | 0.139.0 | None, already newest |
| GitHub Copilot | 1.0.115 | 1.0.115 (`v1.0.115`, npm `latest`) | 1.0.78 | None, already newest |
| Cursor | 2026.11.22-e9042b2 | 2026.11.22-e9042b2 | date 2026.09.23 | None, already newest |
| Claude Code | 2.1.331 | 2.1.332 (`v2.1.332`, npm `latest`) | 2.1.221 | Step 2 |
| Hermes Agent | 0.23.4 | 0.23.4 (`v0.23.4`) | 0.20.0 | None, already newest |
| Pi | 1.6.0 | 1.6.1 (`v1.6.1`, npm `latest`) | 0.99.0 | Step 3 |
| Oh My Pi | 19.1.1 | 19.2.0 (`v19.2.0`) | 17.2.13 | Step 4 |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest |
| Grok Build | 1.0.92 | 1.0.92 (`x.ai/cli/stable`) | 1.0.5 | None, already newest |

## Steps

1. Plan, docs-only.
2. Claude Code 2.1.331 → 2.1.332.
3. Pi 1.6.0 → 1.6.1.
4. Oh My Pi 19.1.1 → 19.2.0.
5. Retire this plan and add the dated run to the regression doc's intro.

Steps 2–4 touch separate plugin packages and run in parallel. They share only adjacent rows in
`docs/HARNESS_CAPABILITIES.md` and `docs/regression/plugin-setup-and-lifecycle.md`, so when an
earlier PR lands, the later one merges `main` in.

## Findings

Filled in by each step.

## Follow-ups

Filled in at retirement.
