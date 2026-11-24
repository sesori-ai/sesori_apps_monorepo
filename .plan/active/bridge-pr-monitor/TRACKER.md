# Tracker: bridge-pr-monitor

| Step | Title | Status | PR |
|---|---|---|---|
| 1 | 🌱 Raise the plan | Done | #2908 |
| 2 | ⚙️ Tool-group interface and grouped MCP server | In review | |
| 3 | 🌿 Per-group toggles and leaner task text | Not started | |
| 4 | 🚧 Tool host: records, notices and approvals | Not started | |
| 5 | ⚙️ PR monitor package: `gh` API and snapshots | Not started | |
| 6 | ⚙️ PR monitor rules | Not started | |
| 7 | 🚧 Watches: fan-out polling, delivery and restart | Not started | |
| 8 | 🚧 Readiness, auto-merge, feedback and reply | Not started | |
| 9 | ⚙️ `configure_pr_monitor` | Not started | |
| 10 | ⚙️ Guides and skills on Claude Code and Codex | Not started | |
| 11 | ⚙️ Pi deferred tools and instructions; skills on Pi, Oh My Pi, Grok and Copilot | Not started | |
| 12 | ⚙️ Bridge projection, status and app actions | Not started | |
| 13 | ⚙️ App: row mark, composer chip and group toggles | Not started | |
| 14 | ⚙️ App: watched-PR list | Not started | |
| 15 | ⚙️ Sesori tools on OpenCode | Not started | |
| 16 | 🌱 Reconcile regression docs | Not started | |
| 17 | 🌿 Verify and retire | Not started | |

## Notes for later steps

- The owner answered the first round of questions on 2026-11-25; see
  Decisions in `PLAN.md`.
- Step 14 starts by checking what multi-computer knows about other bridges,
  for the `N watched` rows. If N is not available, ask on a review page.
- Step 15 mechanism decided by the owner 2026-11-25: keep OpenCode's shared
  server (no bridge-owned server, no launch-time config). Use the client-MCP
  WebSocket relay; every OpenCode session that calls a Sesori tool —
  including sessions started in OpenCode's own app — gets a token bound to
  its `_meta` session id on first call, so the tools work for all sessions
  with no "is this a Sesori session" detection.
- Step 2 kept the interface to what it uses. Step 3 adds `title` and
  `summary`, step 4 `start`, `dispose`, the host and the
  `sesori_plugin_interface` dependency (update `bridge/AGENTS.md`'s module
  order line, which says "no internal deps"), and step 10 `guide`.
- `test/bridge/sesori_mcp/goldens/tools_list.json` pins `tools/list`. Step 3's
  `update_task` dedupe regenerates it with `SESORI_UPDATE_GOLDENS=1`; its diff
  and size (29,306 bytes pretty-printed before) go in the PR.
- Hermes gets the Sesori MCP from a separate PR outside this plan. The
  verification matrix includes it once that PR lands.
