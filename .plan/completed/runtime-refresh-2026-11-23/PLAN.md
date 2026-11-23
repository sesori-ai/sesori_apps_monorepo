# Runtime refresh, 2026-11-23

Status: completed 2026-11-23. Every step is merged; the remaining verification is listed under follow-ups.

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
| OpenCode | 2.3.2 | 2.4.1 (npm `latest`, tag `v2.4.1` `6f051405`; 2.4.0 `44aed4fd` audited too); six tarballs match npm integrity and an independent `npm pack` | PATH 1.14.0; v2 2.0.11 | Step 2 (#2879) | Production managed install, sandboxed `serve`: `/api/info` 2.4.1, 401 without the password, `server.connected`, every list Sesori reads decodes through the regenerated models, clean TERM exit on macOS arm64 |
| Antigravity | 1.5.2 | 1.5.2 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.171.0 | 0.171.0 | 0.139.0 | None, already newest | — |
| GitHub Copilot | 1.0.114 | 1.0.114 | 1.0.78 | None, already newest | — |
| Cursor | 2026.11.19-f005e9d | 2026.11.22-e9042b2 (the only build `cursor.com/install` names); four packages match Cursor's same-host `.sha256` files | date 2026.09.23 | Step 3 (#2880) | Production managed install, `--version`, network-denied `initialize` and `session/list` identical to 2026.11.19-f005e9d on macOS arm64 |
| Claude Code | 2.1.330 | 2.1.330 | 2.1.221 | None, already newest | — |
| Hermes Agent | 0.23.3 | 0.23.3 | 0.20.0 | None, already newest | — |
| Pi | 1.6.0 | 1.6.0 | 0.99.0 | None, already newest | — |
| Oh My Pi | 19.1.0 | 19.1.1 (`31ffee51`); 8 binaries match `SHA256SUMS.txt`, GitHub digests and independent downloads | 17.2.13 | Step 4 (#2878) | Managed install, offline ACP initialize, `session/new`, list, delete and model-restore probes identical to 19.1.0 on macOS arm64; MCP requests stay in `omp acp`; no leftover processes |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.92 | 1.0.92 | 1.0.5 | None, already newest | — |

## Steps

1. Plan, docs-only (#2877).
2. OpenCode 2.3.2 → 2.4.1 (#2879).
3. Cursor 2026.11.19-f005e9d → 2026.11.22-e9042b2 (#2880).
4. Oh My Pi 19.1.0 → 19.1.1 (#2878).
5. Retire this plan and add the dated run to the regression doc's intro (this PR).

## Findings

### OpenCode 2.4.0 and 2.4.1

- Fixed in #2879: 2.4.0 renamed the sub-agent report envelope from `<subagent …>` to
  `<background-result kind="subagent" …>` (same attributes). The parser accepts both; the old tag
  carries a compatibility marker until the v2 minimum reaches 2.4.0. The regenerated models only
  gain an optional `Model.Info.experimental.speed`.
- Not applicable: the event, permission, question-form and session schemas Sesori reads, and the
  `aborted` stopped-turn error, are unchanged. Plugins load in the background again, so a cold
  model list can start empty; Sesori already rereads on `model.updated`. Tool renames
  (`generate_image`/`generate_video`), the new `machine` table and other `<background-result>`
  kinds don't affect Sesori.
- Track only: automations are on by default (an agent can schedule prompts or shell commands),
  Copilot inside OpenCode no longer reads `GITHUB_TOKEN`, version-following plugins self-update,
  mid-tool progress for late joiners, and a new `provider.chatgpt-workspace-limit` error type.
- Asked on a review page: background-job status and cancel (`experimental.job.updated` /
  `experimental.job.cancel`), and fast mode through service-tier speeds, which need the opt-in
  `experimental.model_speeds` flag.

### Cursor 2026.11.22-e9042b2

Pin-only; no code change. Cursor published no changelog entry, so the audit diffed the darwin/arm64
bundles: all 33 ACP methods, stop reasons, update kinds, sub-agent frames and every string Sesori
matches are unchanged, and there is still no `$/cancel_request`. Track only: login now uses
device-bound (DPoP) sessions and `status` treats a session whose key left the credential store as
logged out; prompt `resource_link`s into a credential store are no longer read; saved sub-agent
state falls back to a stored summary, which may bear on child-transcript loading.

### Oh My Pi 19.1.1

Pin-only; no code change. `modes/acp/` is byte-identical between the tags and every matched string
is unchanged. OMP now also reads the `supported` list on a `-32022` MCP error; Sesori's `-32601`
still leads to the normal handshake. Track only: stricter `ask` form validation, `provider/id@upstream`
model ids in session files (visible in the accepted model-restore error), billing failures and
stalls now rotate accounts or fall back, queued follow-ups survive a discarded reply, restored
sessions report background jobs with an unknown outcome.

## Follow-ups

Carried over; each needs credentials, a live client or another host:

- OpenCode: provider turns, a live 2.4 sub-agent report, the plugin's own event-stream handling,
  history parity, reconnect, upgrade from v1, other platforms.
- Cursor: a logged-in check on the new DPoP login (setup status after sign-in), session
  load/replay, model and mode, sub-agents and cleanup, other platforms.
- OMP: authenticated lifecycle and cleanup, live tool-title check, live daemon stop with a named
  service, busy-window probes, a live `ask` round trip, other platforms including native
  Windows ARM64.
- Earlier runs' outstanding verification remains in
  `.plan/completed/runtime-refresh-2026-11-21/PLAN.md` and
  `.plan/completed/runtime-refresh-2026-11-20/PLAN.md`.
