# Runtime refresh, 2026-11-28

Status: completed 2026-11-28. Every step is merged; the remaining verification is listed under follow-ups.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-26 refresh (`.plan/completed/runtime-refresh-2026-11-26/PLAN.md`); no earlier
`runtime-refresh-*` plan was still active. Three harnesses released since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-28.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.4.2 | 2.4.2 (`@opencode/cli` npm `latest`) | PATH 1.14.0; v2 2.0.11 | None, already newest | — |
| Antigravity | 1.5.2 | 1.5.2 (ACP registry) | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.172.0 | 0.172.0 (npm `latest`) | 0.139.0 | None, already newest | — |
| GitHub Copilot | 1.0.116 | 1.0.117 (`v1.0.117` `6bf6e8df`, npm `latest`); six assets match GitHub digests, `SHA256SUMS.txt` and independent downloads | 1.0.78 | Step 2 (#2956) | Production managed install on macOS arm64, `GitHub Copilot CLI 1.0.117.`; network-denied, unauthenticated ACP initialize and session/model/mode/config/logout calls identical to 1.0.116 |
| Cursor | 2026.11.22-e9042b2 | 2026.11.22-e9042b2 (`cursor.com/install`) | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.332 | 2.1.332 (`v2.1.332`, npm `latest`) | 2.1.221 | None, already newest | — |
| Hermes Agent | 0.23.4 | 0.23.5 (`v0.23.5` `a428f534`); direct CLI, no managed assets | 0.20.0 | Step 3 (#2954) | Tagged source installed with `uv sync --frozen --extra acp`, `hermes acp --version` 0.23.5; network-denied fresh-home ACP initialize (protocol 1, load/list/resume/fork, `hermes-setup` auth) and empty `session/list` |
| Pi | 1.6.1 | 1.7.0 (`v1.7.0` `fb0fe823`, npm `latest`); six archives match `SHA256SUMS`, GitHub digests and independent downloads | 0.99.0 | Step 4 (#2955) | Production managed install on macOS arm64, `--version` 1.7.0; credential- and network-free RPC `get_state` and logged-out prompt failure identical to 1.6.1 |
| Oh My Pi | 19.2.1 | 19.2.1 (`v19.2.1`) | 17.2.13 | None, already newest | — |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | dsh `next` 0.2.2-rc.5 | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.92 | 1.0.92 (`x.ai/cli/stable`) | 1.0.5 | None, already newest | — |

## Steps

1. Plan, docs-only (#2953).
2. GitHub Copilot 1.0.116 → 1.0.117 (#2956).
3. Hermes Agent 0.23.4 → 0.23.5 (#2954).
4. Pi 1.6.1 → 1.7.0 (#2955).
5. Retire this plan and add the dated run to the regression doc's intro (this PR).

No code change was needed and no parity work came out of this run.

## Findings

### GitHub Copilot 1.0.117

- No fix, parity or probe finding; the unauthenticated ACP surface is unchanged.
- The "Context Size" option (owner: track only, 2026-11-26) is byte-identical to 1.0.116; its ACP
  category is still unverified. Tracked in `docs/HARNESS_CAPABILITIES.md`.
- Track only: Ctrl+C in ACP mode no longer reports a false shutdown error (Sesori sends SIGTERM);
  shared sessions resume when their saved model is gone; background agents continue after a
  restart; MCP tool approval no longer covers same-named built-ins; SDK-only permission-kind
  rename and tool-turn budget.

### Hermes Agent 0.23.5

- The release notes are a roll-up deferring details to 0.24.0, so the audit diffed the tags'
  source. `acp_adapter/` is unchanged and no matched string sits on a changed line, including
  "No session '<id>'. Run: hermes sessions list to find the id."
- Track only: a compressed session's title now comes from its nearest titled segment.
- Not applicable: `sessions list` now hides non-human threads by default (`sessions delete`
  unchanged); the version module skips unusable git; a detached, network-free default-plugin check
  at startup; gateway, dashboard, Desktop and TUI changes.

### Pi 1.7.0

- 781 upstream commits, but only 46 files changed across Pi's `coding-agent`, `agent` and `ai`
  packages. RPC commands and events, session files (format 3), the extension API, startup-dialog
  order, stop reasons and matched error copy are byte-identical to 1.6.1.
- Track only: a new `--agent-dir <dir>` flag (Sesori keeps `PI_CODING_AGENT_DIR`); an invalid
  `models.json` is now a startup warning on stderr in RPC mode, which the plugin only logs;
  install telemetry removed; `!!` output no longer counts toward the compaction estimate.
- Not applicable: interactive terminal resume, TUI fixes, codemode image generation, provider and
  catalog changes.

### Skill and reference (this PR)

- Copilot: verified range now 1.0.112 to 1.0.117.
- Hermes: a roll-up release note means diffing the tags' source.
- Pi: size a release by its three core packages, not the repository's commit count.

## Follow-ups

Carried over; each needs credentials, a live client or another host:

- GitHub Copilot: the authenticated lifecycle, the Context Size option's category and values,
  other platforms.
- Hermes Agent: configured new/prompt/load/replay and persisted deletion, other platforms.
- Pi: the authenticated lifecycle (settlement, retry, compaction, queue, fresh-process reuse),
  other platforms.
- Earlier runs' outstanding verification remains in
  `.plan/completed/runtime-refresh-2026-11-26/PLAN.md` and the plans it lists.
