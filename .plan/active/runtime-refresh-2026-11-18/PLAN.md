# Runtime refresh, 2026-11-18

Status: active.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-17 refresh (`.plan/completed/runtime-refresh-2026-11-17/PLAN.md`); eight harnesses
released again since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-18.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.3.0 | 2.3.2 (npm `@opencode/cli`) | PATH 1.14.0; v2 2.0.11 | Step 2 | Pending |
| Antigravity | 1.5.0 | 1.5.0 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.169.0 | 0.170.0 (npm `@openai/codex`) | 0.139.0 | Step 3 | Pending |
| GitHub Copilot | 1.0.113 | 1.0.114 (npm `@github/copilot`) | 1.0.78 | Step 4 | Pending |
| Cursor | 2026.11.13-eacade1 | 2026.11.17-f532c45 (`cursor.com/install`) | date 2026.09.23 | Step 5 | Pending |
| Claude Code | 2.1.326 | 2.1.327 (npm `latest`) | 2.1.221 | Step 4 | Pending |
| Hermes Agent | 0.23.2 | 0.23.2 | 0.20.0 | None, already newest | — |
| Pi | 1.5.2 | 1.5.2 | 0.99.0 | None, already newest | — |
| Oh My Pi | 18.22.0 | 18.22.2 (GitHub `v18.22.2`) | 17.2.13 | Step 4 | Pending |
| DeepSeek | adapter 0.2.4 (dsh 0.2.2-rc.4) | adapter 0.2.5 over dsh `next` 0.2.2-rc.5 | 0.1.5 | Steps 6–7 | Pending |
| Grok Build | 1.0.88 | 1.0.89 (`x.ai/cli/stable`) | 1.0.5 | Step 5 | Pending |

## Steps

1. Publish this plan.
2. OpenCode 2.3.2: release-range audit, pin and asset digests, regenerated v2 models and SSE events,
   offline checks.
3. Codex 0.170.0: release-range audit, pin and asset digests, offline checks.
4. Copilot 1.0.114, Claude Code 2.1.327 and OMP 18.22.2: release-range audit, pins and managed asset
   digests, offline initialize checks.
5. Cursor 2026.11.17-f532c45 and Grok Build 1.0.89: release-range audit, pins and digests, offline checks.
6. DeepSeek adapter: move `sesori-ai/sesori-deepseek-acp` to dsh 0.2.2-rc.5 and release `v0.2.5`.
7. Pin the DeepSeek consumer to adapter 0.2.5 from the published assets.
8. Findings that need code get their own PRs. Reconcile the plan table, capability and regression docs
   (including the regression intro's dated run list), apply skill corrections, then retire this plan.

Steps 2–5 and 6 run in parallel. Implementation PRs leave this plan and the regression intro's dated run
list to step 8, so they do not conflict with each other.

## Findings

Filled in per step.

## Verification still needed (final follow-ups)

Carried from 2026-11-17 and still open: authenticated lifecycles for Copilot, Cursor, OMP, Antigravity, Grok
and DeepSeek; non-macOS-arm64 hosts; a live OpenCode turn with provider credentials; the Claude Code
compaction-rewind and side-question probes; the Grok `_x.ai/yolo_mode_changed`, `session/history_tree` and
`session/import` probes; a real DeepSeek content-refused turn.
