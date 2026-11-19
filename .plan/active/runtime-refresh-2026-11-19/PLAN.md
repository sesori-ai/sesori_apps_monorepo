# Runtime refresh, 2026-11-19

Status: active.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-18 refresh (`.plan/completed/runtime-refresh-2026-11-18/PLAN.md`); three harnesses
released again since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-19.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.3.2 | 2.3.2 | PATH 1.14.0; v2 2.0.11 | None, already newest | — |
| Antigravity | 1.5.0 | 1.5.0 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.170.0 | 0.170.0 | 0.139.0 | None, already newest | — |
| GitHub Copilot | 1.0.114 | 1.0.114 | 1.0.78 | None, already newest | — |
| Cursor | 2026.11.17-f532c45 | 2026.11.19-f005e9d (`cursor.com/install`) | date 2026.09.23 | Step 2 | Pending |
| Claude Code | 2.1.327 | 2.1.328 (GitHub and npm `latest`) | 2.1.221 | Step 2 | Pending |
| Hermes Agent | 0.23.2 | 0.23.2 | 0.20.0 | None, already newest | — |
| Pi | 1.5.2 | 1.5.2 | 0.99.0 | None, already newest | — |
| Oh My Pi | 18.22.2 | 19.0.0 (major) | 17.2.13 | Step 3 | Pending |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.89 | 1.0.89 (`x.ai/cli/stable`) | 1.0.5 | None, already newest | — |

## Steps

1. Publish this plan.
2. Cursor 2026.11.19-f005e9d and Claude Code 2.1.328: release-range audit, pins and digests, offline checks.
3. OMP 19.0.0: major-release audit of `modes/acp` and everything Sesori reads, pin and managed asset
   digests, offline initialize and lifecycle probes.
4. Findings that need code get their own PRs. Reconcile the plan table, capability and regression docs
   (including the regression intro's dated run list), apply skill corrections, then retire this plan.

Steps 2 and 3 run in parallel. Implementation PRs leave this plan and the regression intro's dated run list
to step 4. If their regression-doc rows conflict, merge `main` into the later PR.

## Findings

Filled in as steps land.

## Verification still needed (final follow-ups)

Carried from 2026-11-18 (`.plan/completed/runtime-refresh-2026-11-18/PLAN.md`): authenticated lifecycles,
non-macOS-arm64 hosts, the live OpenCode, Claude Code, Grok and DeepSeek probes listed there.
