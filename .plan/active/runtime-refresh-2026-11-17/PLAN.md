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
| GitHub Copilot | 1.0.112 | 1.0.113 (`16604af5`); 6 archives match `SHA256SUMS.txt` and GitHub digests | 1.0.78 | Step 2 (this PR) | Managed install and offline ACP initialize on macOS arm64 pass; authenticated lifecycle pending |
| Cursor | 2026.11.13-eacade1 | 2026.11.13-eacade1 | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.325 | 2.1.326 (`bc1e8a88`); npm `latest`; probed archive matches `SHASUMS256.txt` and GitHub digest | 2.1.221 | Step 2 (this PR) | `--help` flags and unauthenticated stream-json initialize pass; live side-question and compaction-rewind probes pending |
| Hermes Agent | 0.23.1 | 0.23.2 | 0.20.0 | Step 3 | Pending |
| Pi | 1.5.2 | 1.5.2 | 0.99.0 | None, already newest | — |
| Oh My Pi | 18.21.0 | 18.22.0 (`3e8cff3b`); 8 binaries match `SHA256SUMS.txt` and GitHub digests | 17.2.13 | Step 2 (this PR) | Managed install, offline ACP initialize and credential-free delete/new list probes on macOS arm64 pass; busy window and authenticated lifecycle pending |
| DeepSeek | adapter 0.2.3 (dsh 0.2.2-rc.3) | adapter 0.2.4 (dsh `next` 0.2.2-rc.4) | 0.1.5 | Steps 4–5 | Pending |
| Grok Build | 1.0.77 | 1.0.88 (`x.ai/cli/stable`) | 1.0.5 | Step 3 | Pending |

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

## Verification still needed (final follow-ups)

Carried from 2026-11-16 and still open: authenticated lifecycles for Copilot, Cursor, OMP, Antigravity, Grok
and DeepSeek; non-macOS-arm64 hosts; a live OpenCode 2.3.0 turn with provider credentials.
