# Runtime refresh, 2026-11-19

Status: completed 2026-11-20. Every step is merged; the remaining verification is listed under final follow-ups.

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
| Cursor | 2026.11.17-f532c45 | 2026.11.19-f005e9d (`cursor.com/install`); 4 package hashes match Cursor's same-host `.sha256` files | date 2026.09.23 | Step 2 (#2841) | Managed install and network-denied ACP initialize on macOS arm64 pass, same result as 2026.11.17; authenticated lifecycle pending |
| Claude Code | 2.1.327 | 2.1.328 (`26fdd001`); npm `latest`; probed archive matches `SHASUMS256.txt` and GitHub digest | 2.1.221 | Step 2 (#2841) | `--help` flags and unauthenticated stream-json initialize pass; live probes pending |
| Hermes Agent | 0.23.2 | 0.23.2 | 0.20.0 | None, already newest | — |
| Pi | 1.5.2 | 1.5.2 | 0.99.0 | None, already newest | — |
| Oh My Pi | 18.22.2 | 19.0.0 (major, `57771ae5`); 8 binaries match `SHA256SUMS.txt` and GitHub digests | 17.2.13 | Step 3 (#2840), follow-ups #2842 and #2861 | Managed install, offline ACP initialize and delete/list probe on macOS arm64 pass; live intent-title and daemon stop probes pass (#2842); Windows stop covered by a CI host test (#2861); authenticated lifecycle pending |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.89 | 1.0.89 (`x.ai/cli/stable`) | 1.0.5 | None, already newest | — |

## Steps

1. Publish this plan (#2838).
2. Cursor 2026.11.19-f005e9d and Claude Code 2.1.328 (#2841).
3. OMP 19.0.0 (#2840).
4. Findings that needed code: OMP tool titles and the shared daemon on POSIX stop (#2842), then the same
   daemon on Windows stop (#2861). Retired together with the 2026-11-20 plan.

## Findings

- **OMP 18.22.2 → 19.0.0** (#2840): `modes/acp` byte-identical; matched copy unchanged.
  - Fixed (#2842): 19.0.0 turns intent tracing off outside its TUI, so ACP tool titles lost the model's intent.
    Sesori now launches OMP with `PI_INTENT_TRACING=1` (harmless on 17.2.13 and 18.x). It overrides a user's
    `tools.intentTracing: false`; the only cost is intent tokens.
  - Fixed (#2842, #2861): one per-user daemon (`__omp_worker_daemon`) hosts LSPs, PTYs, workers and named
    services for every `omp` process of the user. Sesori's stop killed it when Sesori's `omp` had spawned it.
    Stop now skips processes carrying OMP's shared-helper argv markers and their subtrees, on POSIX (#2842) and
    on Windows, where such spawns also leave the kill-on-close job object (#2861). Stop signals descendants
    first and the root last, so shutdown waits for cleanup (#2861, a Codex finding). Services Sesori's OMP starts
    now outlive stop until `omp ps stop`, which is OMP's own persist design.
  - Accepted gap: 18.x's MLX tiny title worker on Apple Silicon has no stable argv marker, so stop still ends it.
  - Track only: `/handoff` became `/compact handoff`; mid-turn "bridge" compaction arrives through the existing
    `_omp/compaction` pair; `ask` accepts a legacy `questions` list; classifier refusals stay out of the
    transcript; `artifact://N` became `local://N.log`.
- **Cursor 2026.11.17-f532c45 → 2026.11.19-f005e9d** (#2841): ACP methods, update kinds and sub-agent strings
  unchanged. Correction: Cursor does publish a same-host `<package>.sha256`; the reference now says so. Track only:
  its self-updater now checks that file.
- **Claude Code 2.1.327 → 2.1.328** (#2841): control-request subtypes, error values and result subtypes unchanged.
  Track only: internal `system/task_list_statuses` frame; `CLAUDE_CODE_DISABLE_DEFERRED_TOOL_RESUME` (not set,
  upstream default kept); SDK sessions now end the turn when closed with a question open.

## Verification still needed (final follow-ups)

Carried to `.plan/completed/runtime-refresh-2026-11-20/PLAN.md`.
