# Runtime refresh, 2026-11-17

Status: active.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-16 refresh (`.plan/completed/runtime-refresh-2026-11/PLAN.md`); six harnesses
released again since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-17.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.3.0 | 2.3.0 | PATH 1.14.0; v2 2.0.11 | None, already newest | — |
| Antigravity | 1.5.0 | 1.5.0 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.169.0 | 0.169.0 | 0.139.0 | None, already newest | — |
| GitHub Copilot | 1.0.112 | 1.0.113 | 1.0.78 | Step 2 | Pending |
| Cursor | 2026.11.13-eacade1 | 2026.11.13-eacade1 | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.325 | 2.1.326 | 2.1.221 | Step 2 | Pending |
| Hermes Agent | 0.23.1 | **0.23.2** (`v0.23.2` → `ae2a81cc`; from `3b421578`) | 0.20.0 | Step 3, this PR | Tagged-source install prints `0.23.2`; offline ACP initialize (load/list/resume/fork) and empty `session/list` pass on macOS arm64; configured lifecycle pending |
| Pi | 1.5.2 | 1.5.2 | 0.99.0 | None, already newest | — |
| Oh My Pi | 18.21.0 | 18.22.0 | 17.2.13 | Step 2 | Pending |
| DeepSeek | adapter 0.2.3 (dsh 0.2.2-rc.3) | adapter 0.2.4 (dsh `next` 0.2.2-rc.4) | 0.1.5 | Steps 4–5 | Pending |
| Grok Build | 1.0.77 | **1.0.88** (`x.ai/cli/stable`, build `2fe3608f7398`; no published checksums) | 1.0.5 | Step 3, this PR | `grok 1.0.88 (2fe3608f7398)`; offline exact-launch ACP initialize and empty `session/list` pass on macOS arm64, surface identical to 1.0.77; authenticated lifecycle pending |

## Steps

1. Publish this plan.
2. Copilot 1.0.113, Claude Code 2.1.326 and OMP 18.22.0: release-range audit, pins and managed asset digests,
   offline initialize checks.
3. Hermes 0.23.2 and Grok Build 1.0.88: release-range audit, pins, offline checks.
4. DeepSeek adapter: move `sesori-ai/sesori-deepseek-acp` to dsh 0.2.2-rc.4 and release `v0.2.4`.
5. Pin the DeepSeek consumer to adapter 0.2.4 from the published assets.
6. Findings that need code get their own PRs here. Reconcile capability and regression docs, apply skill
   corrections, then retire this plan.

## Findings

Filled in from the step 2–4 audits.

- **Hermes 0.23.1 → 0.23.2** (7,918 commits, 5,211 files; diffed in a blobless clone because the compare
  API caps at 250 commits/300 files). `acp_adapter/gateway_server.py` and `hermes sessions delete` copy are
  unchanged. New `guardrail_blocked` failure copy, recognised in this PR. Track only: edit auto-approval now
  also refuses symlinked `.git`/`.ssh` targets; model switch/resume keep named custom provider routes and
  fail closed on an explicit provider that does not resolve; fast-mode detection now considers provider and
  base URL; terminal failure status lines are marked so chat surfaces drop the duplicate; durable subagents
  and a new primary-login lead on failed turns, which the source attaches only on messaging-gateway and API
  server turns, not the ACP path. No parity cell changes.
- **Grok 1.0.77 → 1.0.88:** release notes are TUI/CLI fixes; initialize surface identical. Track only:
  1.0.84 live model-list updates, 1.0.85 subagent turn-limit handoff and direct replies to unknown slash
  commands, 1.0.88 loaded sessions keep saved model/effort when the first model fetch fails. New binary
  strings `_x.ai/yolo_mode_changed`, `session/history_tree`, `session/import` are unprobed. No parity cell
  changes.

## Verification still needed (final follow-ups)

Carried from 2026-11-16 and still open: authenticated lifecycles for Copilot, Cursor, OMP, Antigravity, Grok
and DeepSeek; non-macOS-arm64 hosts; a live OpenCode 2.3.0 turn with provider credentials.
