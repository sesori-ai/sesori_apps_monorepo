# Runtime refresh, 2026-11-20

Status: active.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-19 refresh (`.plan/active/runtime-refresh-2026-11-19/PLAN.md`, which retires
once its Windows step lands). Six harnesses have released again since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-20.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.3.2 | 2.3.2 | PATH 1.14.0; v2 2.0.11 | None, already newest | — |
| Antigravity | 1.5.0 | 1.5.0 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.170.0 | 0.171.0 (npm) | 0.139.0 | Step 2 | Pending |
| GitHub Copilot | 1.0.114 | 1.0.114 | 1.0.78 | None, already newest | — |
| Cursor | 2026.11.19-f005e9d | 2026.11.19-f005e9d | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.328 | 2.1.330 (GitHub and npm `latest`) | 2.1.221 | Step 3 | Pending |
| Hermes Agent | 0.23.2 | 0.23.3 (GitHub release) | 0.20.0 | Step 4 | Pending |
| Pi | 1.5.2 | 1.6.0 (GitHub and npm) | 0.99.0 | Step 5 | Pending |
| Oh My Pi | 19.0.0 | 19.0.1 | 17.2.13 | Step 3 | Pending |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.89 | 1.0.92 (`x.ai/cli/stable`) | 1.0.5 | Step 4 | Pending |

## Steps

1. Publish this plan.
2. Codex 0.171.0: release-range audit, pin and digests, offline checks.
3. Claude Code 2.1.330 and OMP 19.0.1: release-range audits, pins and digests, offline checks.
4. Hermes Agent 0.23.3 and Grok Build 1.0.92: release-range audits, pins and digests, offline checks.
5. Pi 1.6.0 (minor): release-range audit of the RPC seam, pin and asset digests, offline checks.
6. Findings that need code get their own PRs. Reconcile the plan table, capability and regression docs
   (including the regression intro's dated run list), apply skill corrections, then retire this plan.

Steps 2 to 5 run in parallel. Implementation PRs leave this plan and the regression intro's dated run list
to step 6. If their regression-doc rows conflict, merge `main` into the later PR.

## Findings

Filled in as steps land.
