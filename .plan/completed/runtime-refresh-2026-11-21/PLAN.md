# Runtime refresh, 2026-11-21

Status: completed 2026-11-21. Every step is merged; the remaining verification is listed under follow-ups.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-20 refresh (`.plan/completed/runtime-refresh-2026-11-20/PLAN.md`); no earlier
`runtime-refresh-*` plan was still active. Two harnesses released since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-21.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.3.2 | 2.3.2 | PATH 1.14.0; v2 2.0.11 | None, already newest | — |
| Antigravity | 1.5.0 | 1.5.2 (registry commit `e29b5bf3`; no 1.5.1 was published); 6 ZIPs match the registry's per-archive `sha256` and independent downloads | Exact package/server/ACP 1 pair | Step 2 (#2874) | Production install, network-denied validator initialize (protocol 1, same four auth methods, capabilities unchanged), `--version` on macOS arm64; 1.5.0 pairs now rejected as the exact-pair policy expects |
| Codex | 0.171.0 | 0.171.0 | 0.139.0 | None, already newest | — |
| GitHub Copilot | 1.0.114 | 1.0.114 | 1.0.78 | None, already newest | — |
| Cursor | 2026.11.19-f005e9d | 2026.11.19-f005e9d | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.330 | 2.1.330 | 2.1.221 | None, already newest | — |
| Hermes Agent | 0.23.3 | 0.23.3 | 0.20.0 | None, already newest | — |
| Pi | 1.6.0 | 1.6.0 | 0.99.0 | None, already newest | — |
| Oh My Pi | 19.0.1 | 19.1.0 (`a7135b8f`); 8 binaries match `SHA256SUMS.txt`, GitHub digests and independent downloads | 17.2.13 | Step 3 (#2875) | Managed install, offline ACP initialize, `session/new`, delete/list and model-restore probes identical to 19.0.1 on macOS arm64; no leftover processes |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.92 | 1.0.92 | 1.0.5 | None, already newest | — |

## Steps

1. Plan, docs-only (#2873).
2. Antigravity 1.5.0 → 1.5.2 (#2874).
3. Oh My Pi 19.0.1 → 19.1.0 (#2875).
4. Retire this plan and add the dated run to the regression doc's intro (this PR).

## Findings

### Antigravity 1.5.2

Pin-only; no code change. The client-identity model gate (`client_info.py`), stop-reason mapping,
initialize handler, slash commands and all 38 upstream strings Sesori matches are unchanged.
Track only, from packaged source and not verified live:

- A session's chosen model is saved and restored on cold `session/load`; Sesori already reads
  the model from load responses, so the app should show the real model after a bridge restart.
- Stop no longer streams the rest of the turn's text (the earlier "context canceled" assistant
  text is gone), and a pending question now ends silently. There is still no permission-request
  withdrawal or timeout.
- The server now applies the workspace's `AGENTS.md` and `GEMINI.md` as user rules and enforces
  `.aiexclude`. This is upstream agent behaviour, like other harnesses reading their own project
  rule files; Sesori's isolated profile limits it to project files.
- The available-commands update now follows the session response. New Gemini 4 models and
  quota/admin features require business sign-in, which Sesori does not offer.

### Oh My Pi 19.1.0

Pin-only; no code change. Not applicable to ACP: MCP servers moving into the omp daemon (ACP
sessions keep client MCP servers inside `omp acp` with `enableMCP: false`; no daemon starts,
and nothing remains after SIGTERM), the single HTML-form `ask` request and remote model controls
(both RPC/collab only; ACP form bridge unchanged). OMP now sends `server/discover` to MCP servers
first; Sesori's `-32601` reply triggers the normal handshake fallback. Track only: the removed
`google-gemini-cli` provider (sessions saved on it hit the accepted model-restore limitation),
Antigravity quota reported as 429, shorter tool titles, rarely used tools as `bash` commands,
the provider stream watchdog raised from 5 to 15 minutes, failed retries kept out of the
transcript. The model-restore failure keeps its exact `-32603` shape.

Reference correction (in #2875): OMP's ACP `session/list` and `session/load` read only the
default session folder, so earlier probes that passed `--session-dir` could never see a listed
session. Launched as the plugin does, a fresh `session/new` lists with `messageCount` 0 and no
title, which confirms the plugin's empty-untitled-session filter is still needed.

## Follow-ups

Carried over; each needs credentials, a live client or another host:

- Antigravity: native installs on macOS x64, Linux and Windows; personal OAuth, the signed-in
  model list and gate; sessions, history, images; live check of cold-load model restore and of
  Stop during a pending question.
- OMP: authenticated lifecycle and cleanup, live tool-title check, live daemon stop with a named
  service, busy-window probes, a live `ask` round trip, other platforms including native
  Windows ARM64.
- Earlier runs' outstanding verification remains in
  `.plan/completed/runtime-refresh-2026-11-20/PLAN.md`.
